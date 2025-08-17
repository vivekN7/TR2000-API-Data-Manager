using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;
using TR2KBlazorLibrary.Models;
using Dapper;

namespace TR2KBlazorLibrary.Logic.Services
{
    /// <summary>
    /// Simplified Oracle ETL Service that delegates all logic to database
    /// C# only fetches from API and calls stored procedures
    /// </summary>
    public class OracleETLServiceV2
    {
        private readonly string _connectionString;
        private readonly TR2000ApiService _apiService;
        private readonly ApiResponseDeserializer _deserializer;
        private readonly ILogger<OracleETLServiceV2> _logger;

        public OracleETLServiceV2(
            IConfiguration configuration, 
            TR2000ApiService apiService, 
            ApiResponseDeserializer deserializer, 
            ILogger<OracleETLServiceV2> logger)
        {
            _connectionString = configuration.GetConnectionString("OracleConnection") ?? string.Empty;
            _apiService = apiService;
            _deserializer = deserializer;
            _logger = logger;
        }

        /// <summary>
        /// Test Oracle database connection
        /// </summary>
        public async Task<bool> TestConnection()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                // Verify we can query
                var result = await connection.QuerySingleAsync<int>("SELECT 1 FROM DUAL");
                
                _logger.LogInformation("Successfully connected to Oracle database");
                return result == 1;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to connect to Oracle database");
                return false;
            }
        }

        /// <summary>
        /// Load Operators using new orchestrator pattern
        /// </summary>
        public async Task<ETLResult> LoadOperators()
        {
            var result = new ETLResult 
            { 
                StartTime = DateTime.Now, 
                EndpointName = "OPERATORS" 
            };

            try
            {
                // STEP 1: Fetch from API
                _logger.LogInformation("Fetching operators from API...");
                var apiResponse = await _apiService.FetchDataAsync("operators");
                var apiData = _deserializer.DeserializeApiResponse(apiResponse, "operators");
                
                result.ApiCallCount = 1;
                
                if (apiData == null || !apiData.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No data returned from API";
                    return result;
                }

                _logger.LogInformation($"Fetched {apiData.Count} operators from API");

                // STEP 2: Get ETL Run ID
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                // Insert ETL control record
                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSTIMESTAMP, :apiCalls)",
                    new { etlRunId, runType = "OPERATORS", apiCalls = result.ApiCallCount }
                );

                // STEP 3: Bulk insert to staging
                _logger.LogInformation($"Inserting {apiData.Count} records to staging...");
                
                foreach (var row in apiData)
                {
                    await connection.ExecuteAsync(@"
                        INSERT INTO STG_OPERATORS (OPERATOR_ID, OPERATOR_NAME, ETL_RUN_ID)
                        VALUES (:OperatorId, :OperatorName, :EtlRunId)",
                        new 
                        { 
                            OperatorId = Convert.ToInt32(row["OperatorId"]),
                            OperatorName = row["OperatorName"]?.ToString(),
                            EtlRunId = etlRunId
                        }
                    );
                }

                // STEP 4: Call Oracle orchestrator (it does EVERYTHING)
                _logger.LogInformation("Calling Oracle ETL orchestrator...");
                
                using (var cmd = new OracleCommand("SP_PROCESS_ETL_BATCH", connection))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add("p_etl_run_id", OracleDbType.Int32).Value = etlRunId;
                    cmd.Parameters.Add("p_entity_type", OracleDbType.Varchar2).Value = "OPERATORS";
                    
                    await cmd.ExecuteNonQueryAsync();
                }

                // STEP 5: Get results from Oracle
                var controlRecord = await connection.QuerySingleAsync<dynamic>(@"
                    SELECT STATUS, PROCESSING_TIME_SEC,
                           RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED,
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                
                result.EndTime = DateTime.Now;
                result.Message = $"ETL completed: {result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, " +
                               $"{result.RecordsDeleted} deleted, {result.RecordsReactivated} reactivated";

                _logger.LogInformation($"ETL completed successfully: {result.Message}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Load Plants using new orchestrator pattern
        /// </summary>
        public async Task<ETLResult> LoadPlants()
        {
            var result = new ETLResult 
            { 
                StartTime = DateTime.Now, 
                EndpointName = "PLANTS" 
            };

            try
            {
                // STEP 1: Fetch from API
                _logger.LogInformation("Fetching plants from API...");
                var apiResponse = await _apiService.FetchDataAsync("plants");
                var apiData = _deserializer.DeserializeApiResponse(apiResponse, "plants");
                
                result.ApiCallCount = 1;
                
                if (apiData == null || !apiData.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No data returned from API";
                    return result;
                }

                _logger.LogInformation($"Fetched {apiData.Count} plants from API");

                // STEP 2: Get ETL Run ID
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSTIMESTAMP, :apiCalls)",
                    new { etlRunId, runType = "PLANTS", apiCalls = result.ApiCallCount }
                );

                // STEP 3: Bulk insert to staging
                _logger.LogInformation($"Inserting {apiData.Count} records to staging...");
                
                foreach (var row in apiData)
                {
                    await connection.ExecuteAsync(@"
                        INSERT INTO STG_PLANTS (
                            PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, 
                            OPERATOR_ID, COMMON_LIB_PLANT_CODE, ETL_RUN_ID
                        ) VALUES (
                            :PlantId, :PlantName, :LongDescription, 
                            :OperatorId, :CommonLibPlantCode, :EtlRunId
                        )",
                        new 
                        { 
                            PlantId = row["PlantId"]?.ToString(),
                            PlantName = row["PlantName"]?.ToString(),
                            LongDescription = row["LongDescription"]?.ToString(),
                            OperatorId = row.ContainsKey("OperatorId") ? Convert.ToInt32(row["OperatorId"]) : (int?)null,
                            CommonLibPlantCode = row["CommonLibPlantCode"]?.ToString(),
                            EtlRunId = etlRunId
                        }
                    );
                }

                // STEP 4: Call Oracle orchestrator
                _logger.LogInformation("Calling Oracle ETL orchestrator...");
                
                using (var cmd = new OracleCommand("SP_PROCESS_ETL_BATCH", connection))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add("p_etl_run_id", OracleDbType.Int32).Value = etlRunId;
                    cmd.Parameters.Add("p_entity_type", OracleDbType.Varchar2).Value = "PLANTS";
                    
                    await cmd.ExecuteNonQueryAsync();
                }

                // STEP 5: Get results
                var controlRecord = await connection.QuerySingleAsync<dynamic>(@"
                    SELECT STATUS, PROCESSING_TIME_SEC,
                           RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED,
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                
                result.EndTime = DateTime.Now;
                result.Message = $"ETL completed: {result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, " +
                               $"{result.RecordsDeleted} deleted, {result.RecordsReactivated} reactivated";

                _logger.LogInformation($"ETL completed successfully: {result.Message}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Load Issues for selected plants
        /// </summary>
        public async Task<ETLResult> LoadIssuesForSelectedPlants()
        {
            var result = new ETLResult 
            { 
                StartTime = DateTime.Now, 
                EndpointName = "ISSUES" 
            };

            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();

                // Get active plants from loader
                var activePlants = await connection.QueryAsync<string>(@"
                    SELECT PLANT_ID 
                    FROM ETL_PLANT_LOADER 
                    WHERE IS_ACTIVE = 'Y' 
                    ORDER BY LOAD_PRIORITY, PLANT_ID"
                );

                if (!activePlants.Any())
                {
                    result.Status = "NO_PLANTS";
                    result.Message = "No active plants in loader";
                    return result;
                }

                _logger.LogInformation($"Loading issues for {activePlants.Count()} active plants");

                // Get ETL Run ID
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSTIMESTAMP)",
                    new { etlRunId, runType = "ISSUES" }
                );

                int totalRecords = 0;
                int apiCalls = 0;

                // Fetch issues for each plant
                foreach (var plantId in activePlants)
                {
                    try
                    {
                        _logger.LogInformation($"Fetching issues for plant {plantId}...");
                        var endpoint = $"plants/{plantId}/issues";
                        var apiResponse = await _apiService.FetchDataAsync(endpoint);
                        var issuesData = _deserializer.DeserializeApiResponse(apiResponse, endpoint);
                        apiCalls++;

                        if (issuesData != null && issuesData.Any())
                        {
                            foreach (var issue in issuesData)
                            {
                                await connection.ExecuteAsync(@"
                                    INSERT INTO STG_ISSUES (
                                        PLANT_ID, ISSUE_REVISION, USER_NAME, 
                                        USER_ENTRY_TIME, USER_PROTECTED, ETL_RUN_ID
                                    ) VALUES (
                                        :PlantId, :IssueRevision, :UserName,
                                        :UserEntryTime, :UserProtected, :EtlRunId
                                    )",
                                    new
                                    {
                                        PlantId = plantId,
                                        IssueRevision = issue["Revision"]?.ToString(),
                                        UserName = issue["UserName"]?.ToString(),
                                        UserEntryTime = issue.ContainsKey("UserEntryTime") ? 
                                            Convert.ToDateTime(issue["UserEntryTime"]) : (DateTime?)null,
                                        UserProtected = issue["UserProtected"]?.ToString(),
                                        EtlRunId = etlRunId
                                    }
                                );
                                totalRecords++;
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Failed to load issues for plant {plantId}: {ex.Message}");
                    }
                }

                // Update API call count
                await connection.ExecuteAsync(
                    "UPDATE ETL_CONTROL SET API_CALL_COUNT = :apiCalls WHERE ETL_RUN_ID = :etlRunId",
                    new { apiCalls, etlRunId }
                );

                // Call orchestrator
                _logger.LogInformation($"Processing {totalRecords} issues through orchestrator...");
                
                using (var cmd = new OracleCommand("SP_PROCESS_ETL_BATCH", connection))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add("p_etl_run_id", OracleDbType.Int32).Value = etlRunId;
                    cmd.Parameters.Add("p_entity_type", OracleDbType.Varchar2).Value = "ISSUES";
                    
                    await cmd.ExecuteNonQueryAsync();
                }

                // Get results
                var controlRecord = await connection.QuerySingleAsync<dynamic>(@"
                    SELECT STATUS, PROCESSING_TIME_SEC,
                           RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED,
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.ApiCallCount = apiCalls;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                
                result.EndTime = DateTime.Now;
                result.Message = $"Processed {activePlants.Count()} plants: {result.RecordsLoaded} inserted, " +
                               $"{result.RecordsUpdated} updated, {result.RecordsDeleted} deleted";

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Get ETL history
        /// </summary>
        public async Task<List<ETLRunHistory>> GetETLHistory(int maxRows = 10)
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                
                var history = await connection.QueryAsync<ETLRunHistory>(@"
                    SELECT 
                        ETL_RUN_ID as RunId,
                        RUN_TYPE as RunType,
                        STATUS as Status,
                        START_TIME as StartTime,
                        END_TIME as EndTime,
                        PROCESSING_TIME_SEC as ProcessingTimeSeconds,
                        RECORDS_LOADED as RecordsLoaded,
                        RECORDS_UPDATED as RecordsUpdated,
                        RECORDS_DELETED as RecordsDeleted,
                        RECORDS_REACTIVATED as RecordsReactivated,
                        RECORDS_UNCHANGED as RecordsUnchanged,
                        ERROR_COUNT as ErrorCount,
                        API_CALL_COUNT as ApiCallCount,
                        COMMENTS as Comments
                    FROM ETL_CONTROL
                    ORDER BY ETL_RUN_ID DESC
                    FETCH FIRST :maxRows ROWS ONLY",
                    new { maxRows }
                );

                return history.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get ETL history");
                return new List<ETLRunHistory>();
            }
        }

        /// <summary>
        /// Get table statistics
        /// </summary>
        public async Task<List<TableStatus>> GetTableStatuses()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                
                var statuses = await connection.QueryAsync<TableStatus>(@"
                    SELECT 
                        'OPERATORS' as TableName,
                        COUNT(*) as TotalRows,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CurrentRows,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as HistoricalRows,
                        MAX(VALID_FROM) as LastModified
                    FROM OPERATORS
                    UNION ALL
                    SELECT 
                        'PLANTS' as TableName,
                        COUNT(*) as TotalRows,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CurrentRows,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as HistoricalRows,
                        MAX(VALID_FROM) as LastModified
                    FROM PLANTS
                    UNION ALL
                    SELECT 
                        'ISSUES' as TableName,
                        COUNT(*) as TotalRows,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CurrentRows,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as HistoricalRows,
                        MAX(VALID_FROM) as LastModified
                    FROM ISSUES"
                );

                return statuses.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get table statuses");
                return new List<TableStatus>();
            }
        }

        /// <summary>
        /// Deploy the final DDL script
        /// </summary>
        public async Task<bool> DeployFinalDDL()
        {
            try
            {
                _logger.LogInformation("Deploying final SCD2 DDL...");
                
                // Read the DDL file
                var ddlPath = "/workspace/TR2000/TR2K/Ops/Oracle_DDL_SCD2_FINAL.sql";
                if (!System.IO.File.Exists(ddlPath))
                {
                    _logger.LogError("DDL file not found at " + ddlPath);
                    return false;
                }

                var ddlScript = await System.IO.File.ReadAllTextAsync(ddlPath);
                
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();

                // Split by GO or / delimiters and execute each block
                var scriptBlocks = ddlScript.Split(new[] { "\n/\n", "\nGO\n" }, StringSplitOptions.RemoveEmptyEntries);
                
                foreach (var block in scriptBlocks)
                {
                    if (string.IsNullOrWhiteSpace(block) || block.Trim().StartsWith("--"))
                        continue;

                    try
                    {
                        await connection.ExecuteAsync(block);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Block execution warning: {ex.Message}");
                        // Continue with other blocks
                    }
                }

                _logger.LogInformation("DDL deployment completed successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to deploy DDL");
                return false;
            }
        }
    }

    // Supporting classes
    public class ETLResult
    {
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public string EndpointName { get; set; }
        public string Status { get; set; }
        public string Message { get; set; }
        public int RecordsLoaded { get; set; }
        public int RecordsUpdated { get; set; }
        public int RecordsUnchanged { get; set; }
        public int RecordsDeleted { get; set; }
        public int RecordsReactivated { get; set; }
        public int ErrorCount { get; set; }
        public int ApiCallCount { get; set; }
        public double ProcessingTimeSeconds { get; set; }
    }

    public class ETLRunHistory
    {
        public int RunId { get; set; }
        public string RunType { get; set; }
        public string Status { get; set; }
        public DateTime? StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public double? ProcessingTimeSeconds { get; set; }
        public int RecordsLoaded { get; set; }
        public int RecordsUpdated { get; set; }
        public int RecordsDeleted { get; set; }
        public int RecordsReactivated { get; set; }
        public int RecordsUnchanged { get; set; }
        public int ErrorCount { get; set; }
        public int ApiCallCount { get; set; }
        public string Comments { get; set; }
    }

    public class TableStatus
    {
        public string TableName { get; set; }
        public int TotalRows { get; set; }
        public int CurrentRows { get; set; }
        public int HistoricalRows { get; set; }
        public DateTime? LastModified { get; set; }
    }
}