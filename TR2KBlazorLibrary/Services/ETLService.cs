using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;
using TR2KBlazorLibrary.Models;

namespace TR2KBlazorLibrary.Logic.Services
{
    public class ETLService
    {
        private readonly string _connectionString;
        private readonly ILogger<ETLService> _logger;
        private readonly TR2000ApiService _apiService;
        private readonly SelectionService _selectionService;

        public ETLService(
            IConfiguration configuration, 
            ILogger<ETLService> logger,
            TR2000ApiService apiService,
            SelectionService selectionService)
        {
            _connectionString = configuration.GetConnectionString("OracleConnection") 
                ?? throw new InvalidOperationException("Oracle connection string not configured");
            _logger = logger;
            _apiService = apiService;
            _selectionService = selectionService;
        }

        /// <summary>
        /// Run ETL for all active selections
        /// </summary>
        public async Task<EtlRunModel> RunETLAsync(string runType = "MANUAL")
        {
            var runId = await StartEtlRun(runType);
            var runModel = new EtlRunModel { RunId = runId, RunType = runType, StartTime = DateTime.Now };

            try
            {
                // Get active plant selections
                var activePlants = await _selectionService.GetActiveDistinctPlantIdsAsync();
                if (!activePlants.Any())
                {
                    throw new InvalidOperationException("No active plant selections found");
                }

                _logger.LogInformation($"Starting ETL for {activePlants.Count} plants");

                // Process Plants endpoint first
                await ProcessPlantsEndpoint(runId, activePlants);

                // Process Issues endpoint for each plant
                foreach (var plantId in activePlants)
                {
                    await ProcessIssuesEndpoint(runId, plantId);
                }

                // Update run status
                await CompleteEtlRun(runId, "SUCCESS");
                runModel.Status = "SUCCESS";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"ETL run {runId} failed");
                await CompleteEtlRun(runId, "FAILED", ex.Message);
                runModel.Status = "FAILED";
                runModel.Notes = ex.Message;
                throw;
            }

            return runModel;
        }

        /// <summary>
        /// Process Plants endpoint
        /// </summary>
        private async Task ProcessPlantsEndpoint(int runId, List<string> plantIds)
        {
            try
            {
                _logger.LogInformation("Processing Plants endpoint");

                // Fetch data from API
                var apiResponse = await _apiService.GetDataAsync("plants");
                if (!apiResponse.Success || string.IsNullOrEmpty(apiResponse.Data))
                {
                    throw new Exception($"Failed to fetch plants data: {apiResponse.ErrorMessage}");
                }

                // Calculate SHA256 hash
                var responseHash = ComputeSHA256Hash(apiResponse.Data);

                // Check for duplicate
                if (await IsDuplicateResponse(responseHash))
                {
                    _logger.LogInformation("Plants data unchanged (duplicate hash), skipping processing");
                    return;
                }

                // Insert into RAW_JSON
                var rawJsonId = await InsertRawJson("plants", null, null, "plants", apiResponse.Data, responseHash);

                // Call stored procedure to parse and upsert
                await CallStoredProcedure("pkg_parse_plants.parse_plants_json", rawJsonId);
                await CallStoredProcedure("pkg_upsert_plants.upsert_plants");

                _logger.LogInformation("Plants endpoint processed successfully");
            }
            catch (Exception ex)
            {
                await LogError(runId, "plants", null, null, "PARSE_ERROR", ex.Message, ex.StackTrace);
                throw;
            }
        }

        /// <summary>
        /// Process Issues endpoint for a specific plant
        /// </summary>
        private async Task ProcessIssuesEndpoint(int runId, string plantId)
        {
            try
            {
                _logger.LogInformation($"Processing Issues endpoint for plant {plantId}");

                // Fetch data from API
                var apiUrl = $"plants/{plantId}/issues";
                var apiResponse = await _apiService.GetDataAsync(apiUrl);
                if (!apiResponse.Success || string.IsNullOrEmpty(apiResponse.Data))
                {
                    throw new Exception($"Failed to fetch issues data for plant {plantId}: {apiResponse.ErrorMessage}");
                }

                // Calculate SHA256 hash
                var responseHash = ComputeSHA256Hash(apiResponse.Data);

                // Check for duplicate
                if (await IsDuplicateResponse(responseHash))
                {
                    _logger.LogInformation($"Issues data for plant {plantId} unchanged (duplicate hash), skipping");
                    return;
                }

                // Insert into RAW_JSON
                var rawJsonId = await InsertRawJson("issues", plantId, null, apiUrl, apiResponse.Data, responseHash);

                // Call stored procedure to parse and upsert
                await CallStoredProcedure("pkg_parse_issues.parse_issues_json", rawJsonId);
                await CallStoredProcedure("pkg_upsert_issues.upsert_issues");

                _logger.LogInformation($"Issues endpoint for plant {plantId} processed successfully");
            }
            catch (Exception ex)
            {
                await LogError(runId, "issues", plantId, null, "PARSE_ERROR", ex.Message, ex.StackTrace);
                throw;
            }
        }

        /// <summary>
        /// Compute SHA256 hash of a string
        /// </summary>
        private string ComputeSHA256Hash(string input)
        {
            using var sha256 = SHA256.Create();
            var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(input));
            return BitConverter.ToString(bytes).Replace("-", "").ToLower();
        }

        /// <summary>
        /// Check if response hash already exists in RAW_JSON
        /// </summary>
        private async Task<bool> IsDuplicateResponse(string responseHash)
        {
            const string sql = @"
                SELECT COUNT(*) 
                FROM RAW_JSON 
                WHERE response_hash = :responseHash";

            using var connection = new OracleConnection(_connectionString);
            var count = await connection.ExecuteScalarAsync<int>(sql, new { responseHash });
            return count > 0;
        }

        /// <summary>
        /// Insert raw JSON response into RAW_JSON table
        /// </summary>
        private async Task<int> InsertRawJson(string endpointKey, string? plantId, string? issueRevision, 
            string apiUrl, string responseJson, string responseHash)
        {
            const string sql = @"
                INSERT INTO RAW_JSON (
                    endpoint_key, plant_id, issue_revision, api_url, 
                    response_json, response_hash
                ) VALUES (
                    :endpointKey, :plantId, :issueRevision, :apiUrl, 
                    :responseJson, :responseHash
                ) RETURNING raw_json_id INTO :rawJsonId";

            using var connection = new OracleConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("endpointKey", endpointKey);
            parameters.Add("plantId", plantId);
            parameters.Add("issueRevision", issueRevision);
            parameters.Add("apiUrl", apiUrl);
            parameters.Add("responseJson", responseJson);
            parameters.Add("responseHash", responseHash);
            parameters.Add("rawJsonId", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(sql, parameters);
            return parameters.Get<int>("rawJsonId");
        }

        /// <summary>
        /// Call a stored procedure (placeholder - procedures will be added later)
        /// </summary>
        private async Task CallStoredProcedure(string procedureName, params object[] parameters)
        {
            _logger.LogInformation($"Would call stored procedure: {procedureName}");
            // Stored procedures will be implemented in the next task
            await Task.CompletedTask;
        }

        /// <summary>
        /// Start an ETL run and return the run ID
        /// </summary>
        private async Task<int> StartEtlRun(string runType)
        {
            const string sql = @"
                INSERT INTO ETL_RUN_LOG (
                    run_type, start_time, status, initiated_by
                ) VALUES (
                    :runType, SYSTIMESTAMP, 'RUNNING', USER
                ) RETURNING run_id INTO :runId";

            using var connection = new OracleConnection(_connectionString);
            var parameters = new DynamicParameters();
            parameters.Add("runType", runType);
            parameters.Add("runId", dbType: DbType.Int32, direction: ParameterDirection.Output);

            await connection.ExecuteAsync(sql, parameters);
            return parameters.Get<int>("runId");
        }

        /// <summary>
        /// Complete an ETL run
        /// </summary>
        private async Task CompleteEtlRun(int runId, string status, string? notes = null)
        {
            const string sql = @"
                UPDATE ETL_RUN_LOG 
                SET 
                    end_time = SYSTIMESTAMP,
                    status = :status,
                    duration_seconds = EXTRACT(SECOND FROM (SYSTIMESTAMP - start_time)),
                    notes = :notes
                WHERE run_id = :runId";

            using var connection = new OracleConnection(_connectionString);
            await connection.ExecuteAsync(sql, new { runId, status, notes });
        }

        /// <summary>
        /// Log an error to ETL_ERROR_LOG
        /// </summary>
        private async Task LogError(int runId, string endpointKey, string? plantId, string? issueRevision,
            string errorType, string errorMessage, string? errorStack)
        {
            const string sql = @"
                INSERT INTO ETL_ERROR_LOG (
                    run_id, endpoint_key, plant_id, issue_revision,
                    error_type, error_message, error_stack
                ) VALUES (
                    :runId, :endpointKey, :plantId, :issueRevision,
                    :errorType, :errorMessage, :errorStack
                )";

            using var connection = new OracleConnection(_connectionString);
            await connection.ExecuteAsync(sql, new 
            { 
                runId, 
                endpointKey, 
                plantId, 
                issueRevision,
                errorType, 
                errorMessage, 
                errorStack 
            });
        }

        /// <summary>
        /// Get ETL statistics for dashboard
        /// </summary>
        public async Task<EtlStatistics> GetStatisticsAsync()
        {
            const string sql = @"
                SELECT 
                    COUNT(*) AS TotalRuns,
                    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS SuccessfulRuns,
                    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS FailedRuns,
                    SUM(records_processed) AS TotalRecordsProcessed,
                    SUM(records_inserted) AS TotalRecordsInserted,
                    SUM(records_updated) AS TotalRecordsUpdated,
                    SUM(records_invalidated) AS TotalRecordsInvalidated,
                    AVG(duration_seconds) AS AverageRunDuration,
                    MAX(start_time) AS LastRunTime
                FROM ETL_RUN_LOG
                WHERE start_time >= SYSDATE - 30";

            const string errorCountSql = @"
                SELECT COUNT(*) 
                FROM ETL_ERROR_LOG 
                WHERE resolution_status = 'OPEN'";

            const string activeSelectionsSql = @"
                SELECT COUNT(*) 
                FROM SELECTION_LOADER 
                WHERE is_active = 'Y'";

            using var connection = new OracleConnection(_connectionString);
            var stats = await connection.QueryFirstOrDefaultAsync<EtlStatistics>(sql) ?? new EtlStatistics();
            stats.PendingErrors = await connection.ExecuteScalarAsync<int>(errorCountSql);
            stats.ActiveSelections = await connection.ExecuteScalarAsync<int>(activeSelectionsSql);

            return stats;
        }
    }
}