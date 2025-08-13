using Microsoft.Extensions.Logging;
using TR2KBlazorLibrary.Logic.Repositories;
using TR2KBlazorLibrary.Models.DatabaseModels;

namespace TR2KBlazorLibrary.Logic.Services;

public class DataImportService
{
    private readonly TR2000ApiService _apiService;
    private readonly ApiResponseDeserializer _deserializer;
    private readonly IGenericRepository<ImportLog> _importLogRepository;
    private readonly IGenericRepository<Operator> _operatorRepository;
    private readonly IGenericRepository<Plant> _plantRepository;
    private readonly IGenericRepository<PCS> _pcsRepository;
    private readonly IGenericRepository<Issue> _issueRepository;
    private readonly ILogger<DataImportService> _logger;

    public DataImportService(
        TR2000ApiService apiService,
        ApiResponseDeserializer deserializer,
        IGenericRepository<ImportLog> importLogRepository,
        IGenericRepository<Operator> operatorRepository,
        IGenericRepository<Plant> plantRepository,
        IGenericRepository<PCS> pcsRepository,
        IGenericRepository<Issue> issueRepository,
        ILogger<DataImportService> logger)
    {
        _apiService = apiService;
        _deserializer = deserializer;
        _importLogRepository = importLogRepository;
        _operatorRepository = operatorRepository;
        _plantRepository = plantRepository;
        _pcsRepository = pcsRepository;
        _issueRepository = issueRepository;
        _logger = logger;
    }

    public async Task<ImportResult> ImportDataAsync(string endpoint, bool overwriteExisting = true)
    {
        var importLog = new ImportLog
        {
            Endpoint = endpoint,
            Status = ImportStatus.InProgress,
            StartTime = DateTime.UtcNow
        };

        try
        {
            _logger.LogInformation("Starting import for endpoint: {Endpoint}", endpoint);

            // Test connection first
            var testResult = await _apiService.TestConnectionAsync(endpoint);
            if (!testResult.Success)
            {
                throw new InvalidOperationException($"Connection test failed: {testResult.ErrorMessage}");
            }

            // Fetch data from API
            var apiData = await _apiService.FetchDataAsync(endpoint);
            var deserializedData = _deserializer.DeserializeApiResponse(apiData, endpoint);

            // Clear existing data if requested
            if (overwriteExisting)
            {
                await ClearExistingDataAsync(endpoint);
            }

            // Import based on endpoint
            var recordsImported = await ImportDataByEndpointAsync(endpoint, deserializedData);

            importLog.Status = ImportStatus.Completed;
            importLog.RecordsImported = recordsImported;
            importLog.EndTime = DateTime.UtcNow;

            _logger.LogInformation("Import completed for {Endpoint}: {Records} records", endpoint, recordsImported);

            return new ImportResult
            {
                Success = true,
                RecordsImported = recordsImported,
                ErrorMessage = null
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Import failed for endpoint: {Endpoint}", endpoint);
            
            importLog.Status = ImportStatus.Failed;
            importLog.ErrorMessage = ex.Message;
            importLog.EndTime = DateTime.UtcNow;

            return new ImportResult
            {
                Success = false,
                RecordsImported = 0,
                ErrorMessage = ex.Message
            };
        }
        finally
        {
            await _importLogRepository.InsertAsync("ImportLog", importLog);
        }
    }

    private async Task ClearExistingDataAsync(string endpoint)
    {
        var lowerEndpoint = endpoint.ToLower();
        
        // For single plant endpoint, don't clear all plants
        if (System.Text.RegularExpressions.Regex.IsMatch(lowerEndpoint, @"^plants/\d+$"))
        {
            // Don't clear anything for single plant queries
            return;
        }
        
        switch (lowerEndpoint)
        {
            case "operators":
                await _operatorRepository.DeleteAllAsync("operators");
                break;
            case "plants":
                await _plantRepository.DeleteAllAsync("plants");
                break;
            case var e when e.Contains("pcs"):
                await _pcsRepository.DeleteAllAsync("pcs");
                break;
            case var e when e.Contains("issues"):
                await _issueRepository.DeleteAllAsync("issues");
                break;
        }
    }

    public async Task<int> ImportDataByEndpointAsync(string endpoint, List<Dictionary<string, object>> data)
    {
        var lowerEndpoint = endpoint.ToLower();
        
        // Handle operators/{id}/plants endpoint
        if (lowerEndpoint.Contains("operators") && lowerEndpoint.Contains("plants"))
        {
            // Import as plants data
            await EnsureOperatorsExistAsync();
            return await ImportPlantsAsync(data);
        }
        
        // Handle plants/{id} endpoint (single plant)
        if (System.Text.RegularExpressions.Regex.IsMatch(lowerEndpoint, @"^plants/\d+$"))
        {
            // For single plant, don't import to database at all
            // The data is just for display purposes
            return data.Count;
        }
        
        switch (lowerEndpoint)
        {
            case "operators":
                return await ImportOperatorsAsync(data);
            case "plants":
                await EnsureOperatorsExistAsync();
                return await ImportPlantsAsync(data);
            case var e when e.Contains("pcs"):
                await EnsurePlantExistsAsync(ExtractPlantId(endpoint));
                return await ImportPCSAsync(data, ExtractPlantId(endpoint));
            case var e when e.Contains("issues"):
                await EnsurePlantExistsAsync(ExtractPlantId(endpoint));
                return await ImportIssuesAsync(data, ExtractPlantId(endpoint));
            default:
                throw new ArgumentException($"Unknown endpoint: {endpoint}");
        }
    }

    private async Task<int> ImportOperatorsAsync(List<Dictionary<string, object>> data)
    {
        var operators = data.Select(item => new Operator
        {
            OperatorID = Convert.ToInt32(item.GetValueOrDefault("OperatorID", 0)),
            OperatorName = item.GetValueOrDefault("OperatorName", "")?.ToString() ?? ""
        }).ToList();

        await _operatorRepository.InsertBulkAsync("operators", operators);
        return operators.Count;
    }

    private async Task<int> ImportPlantsAsync(List<Dictionary<string, object>> data)
    {
        var plants = data.Select(item => new Plant
        {
            PlantID = Convert.ToInt32(item.GetValueOrDefault("PlantID", 0)),
            ShortDescription = item.GetValueOrDefault("ShortDescription", "")?.ToString(),
            LongDescription = item.GetValueOrDefault("LongDescription", "")?.ToString(),
            OperatorID = Convert.ToInt32(item.GetValueOrDefault("OperatorID", 0)),
            OperatorName = item.GetValueOrDefault("OperatorName", "")?.ToString(),
            AreaID = Convert.ToInt32(item.GetValueOrDefault("AreaID", 0)),
            Area = item.GetValueOrDefault("Area", "")?.ToString(),
            CommonLibPlantCode = item.GetValueOrDefault("CommonLibPlantCode", "")?.ToString(),
            Project = item.GetValueOrDefault("Project", "")?.ToString(),
            InitialRevision = item.GetValueOrDefault("InitialRevision", "")?.ToString()
        }).ToList();

        await _plantRepository.InsertBulkAsync("plants", plants);
        return plants.Count;
    }

    private async Task<int> ImportPCSAsync(List<Dictionary<string, object>> data, int plantId)
    {
        var pcsItems = data.Select(item => new PCS
        {
            PCSName = item.GetValueOrDefault("PCS", "")?.ToString(),
            PlantID = plantId,
            Revision = item.GetValueOrDefault("Revision", "")?.ToString(),
            Status = item.GetValueOrDefault("Status", "")?.ToString(),
            RevDate = item.GetValueOrDefault("RevDate", "")?.ToString(),
            RatingClass = item.GetValueOrDefault("RatingClass", "")?.ToString(),
            TestPressure = item.GetValueOrDefault("TestPressure", "")?.ToString(),
            MaterialGroup = item.GetValueOrDefault("MaterialGroup", "")?.ToString(),
            DesignCode = item.GetValueOrDefault("DesignCode", "")?.ToString(),
            LastUpdate = item.GetValueOrDefault("LastUpdate", "")?.ToString(),
            LastUpdateBy = item.GetValueOrDefault("LastUpdateBy", "")?.ToString(),
            Approver = item.GetValueOrDefault("Approver", "")?.ToString(),
            Notepad = item.GetValueOrDefault("Notepad", "")?.ToString(),
            SpecialReqID = Convert.ToInt32(item.GetValueOrDefault("SpecialReqID", 0)),
            TubePCS = item.GetValueOrDefault("TubePCS", "")?.ToString(),
            NewVDSSection = item.GetValueOrDefault("NewVDSSection", "")?.ToString()
        }).ToList();

        await _pcsRepository.InsertBulkAsync("pcs", pcsItems);
        return pcsItems.Count;
    }

    private async Task<int> ImportIssuesAsync(List<Dictionary<string, object>> data, int plantId)
    {
        var issues = data.Select(item => new Issue
        {
            IssueRevision = item.GetValueOrDefault("IssueRevision", "")?.ToString(),
            PlantID = plantId,
            Status = item.GetValueOrDefault("Status", "")?.ToString(),
            RevDate = item.GetValueOrDefault("RevDate", "")?.ToString(),
            ProtectStatus = item.GetValueOrDefault("ProtectStatus", "")?.ToString(),
            GeneralRevision = item.GetValueOrDefault("GeneralRevision", "")?.ToString(),
            GeneralRevDate = item.GetValueOrDefault("GeneralRevDate", "")?.ToString(),
            PCSRevision = item.GetValueOrDefault("PCSRevision", "")?.ToString(),
            PCSRevDate = item.GetValueOrDefault("PCSRevDate", "")?.ToString(),
            EDSRevision = item.GetValueOrDefault("EDSRevision", "")?.ToString(),
            EDSRevDate = item.GetValueOrDefault("EDSRevDate", "")?.ToString(),
            VDSRevision = item.GetValueOrDefault("VDSRevision", "")?.ToString(),
            VDSRevDate = item.GetValueOrDefault("VDSRevDate", "")?.ToString(),
            VSKRevision = item.GetValueOrDefault("VSKRevision", "")?.ToString(),
            VSKRevDate = item.GetValueOrDefault("VSKRevDate", "")?.ToString(),
            MDSRevision = item.GetValueOrDefault("MDSRevision", "")?.ToString(),
            MDSRevDate = item.GetValueOrDefault("MDSRevDate", "")?.ToString(),
            ESKRevision = item.GetValueOrDefault("ESKRevision", "")?.ToString(),
            ESKRevDate = item.GetValueOrDefault("ESKRevDate", "")?.ToString(),
            SCRevision = item.GetValueOrDefault("SCRevision", "")?.ToString(),
            SCRevDate = item.GetValueOrDefault("SCRevDate", "")?.ToString(),
            VSMRevision = item.GetValueOrDefault("VSMRevision", "")?.ToString(),
            VSMRevDate = item.GetValueOrDefault("VSMRevDate", "")?.ToString()
        }).ToList();

        await _issueRepository.InsertBulkAsync("issues", issues);
        return issues.Count;
    }

    private static int ExtractPlantId(string endpoint)
    {
        // Extract plant ID from endpoints like "plants/1/pcs" or "plants/2/issues"
        var parts = endpoint.Split('/');
        if (parts.Length >= 2 && int.TryParse(parts[1], out var plantId))
        {
            return plantId;
        }
        return 0;
    }

    private async Task EnsureOperatorsExistAsync()
    {
        var existingOperators = await _operatorRepository.GetAllAsync("operators");
        if (!existingOperators.Any())
        {
            _logger.LogInformation("No operators found, importing operators first");
            
            // Import operators first
            var operatorsApiData = await _apiService.FetchDataAsync("operators");
            var operatorsDeserializedData = _deserializer.DeserializeApiResponse(operatorsApiData, "operators");
            await ImportOperatorsAsync(operatorsDeserializedData);
            
            _logger.LogInformation("Operators imported to satisfy foreign key constraint");
        }
    }

    private async Task EnsurePlantExistsAsync(int plantId)
    {
        var existingPlants = await _plantRepository.GetAllAsync("plants");
        var plantExists = existingPlants.OfType<Plant>().Any(p => p.PlantID == plantId);
        
        if (!plantExists)
        {
            _logger.LogInformation("Plant {PlantId} not found, importing operators and plants first", plantId);
            
            // Import operators first (required for plants)
            await EnsureOperatorsExistAsync();
            
            // Then import plants
            var plantsApiData = await _apiService.FetchDataAsync("plants");
            var plantsDeserializedData = _deserializer.DeserializeApiResponse(plantsApiData, "plants");
            await ImportPlantsAsync(plantsDeserializedData);
            
            _logger.LogInformation("Plants imported to satisfy foreign key constraint");
        }
    }

    public async Task<IEnumerable<dynamic>> GetImportedDataAsync(string tableName)
    {
        return tableName.ToLower() switch
        {
            "operators" => await _operatorRepository.GetAllAsync("operators"),
            "plants" => await _plantRepository.GetAllAsync("plants"),
            "pcs" => await _pcsRepository.GetAllAsync("pcs"),
            "issues" => await _issueRepository.GetAllAsync("issues"),
            _ => throw new ArgumentException($"Unknown table: {tableName}")
        };
    }
}

public class ImportResult
{
    public bool Success { get; set; }
    public int RecordsImported { get; set; }
    public string? ErrorMessage { get; set; }
}