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
        /// Get SQL preview for Operators ETL
        /// </summary>
        public ETLSqlPreview GetOperatorsSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load Operators - Complete SCD2 Process",
                Description = "This process implements full SCD Type 2 change tracking for Operators, maintaining complete history of all changes.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Fetch from API",
                        Description = "C# fetches all operators from TR2000 API",
                        SqlStatement = @"-- C# Code (not SQL)
await _apiService.FetchDataAsync('https://equinor.pipespec-api.presight.com/operators');

Returns: 8 operators with OperatorID and OperatorName"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "Get ETL Run ID",
                        Description = "Generate unique identifier for this ETL run",
                        SqlStatement = @"SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL;

-- Insert control record
INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
VALUES (:etlRunId, 'OPERATORS', 'RUNNING', SYSTIMESTAMP, 1);"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Save to RAW_JSON (Audit Trail)",
                        Description = "Store raw API response for audit/forensics/replay",
                        SqlStatement = @"-- C# calls SP_INSERT_RAW_JSON (best-effort, non-critical)
BEGIN
    SP_INSERT_RAW_JSON(
        p_endpoint      => '/operators',
        p_key_string    => 'all-operators',
        p_etl_run_id    => :etlRunId,
        p_http_status   => 200,
        p_duration_ms   => :elapsedMs,
        p_headers_json  => :headers_json,
        p_payload       => :apiResponse  -- Complete JSON from API
    );
END;

-- Purpose: Audit trail, forensics, replay capability
-- Storage: SECUREFILE with COMPRESS MEDIUM (60-80% reduction)
-- Retention: 30 days (auto-purged after each ETL run)
-- If insert fails: ETL continues (non-critical)"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Load to Staging",
                        Description = "Insert API data into staging table (temporary holding area)",
                        SqlStatement = @"-- C# performs bulk insert (8 records)
INSERT INTO STG_OPERATORS (OPERATOR_ID, OPERATOR_NAME, ETL_RUN_ID)
VALUES (:OperatorId, :OperatorName, :EtlRunId);

-- Staging is TEMPORARY - cleared after successful processing
-- No history kept in staging - it's just a landing zone"
                    },
                    new ETLStep
                    {
                        StepNumber = 5,
                        Title = "Call Orchestrator",
                        Description = "Oracle SP_PROCESS_ETL_BATCH handles ALL business logic",
                        SqlStatement = @"BEGIN
    SP_PROCESS_ETL_BATCH(
        p_etl_run_id => :etlRunId,
        p_entity_type => 'OPERATORS'
    );
END;

This orchestrator performs:
1. Deduplication (handles duplicate API data)
2. Validation (checks business rules)
3. SCD2 Processing (5 sub-steps below)
4. Reconciliation (verifies counts)
5. COMMIT (single atomic transaction)"
                    },
                    new ETLStep
                    {
                        StepNumber = 5,
                        Title = "Step 4.1: Handle Deletions",
                        Description = "Mark records as deleted if missing from API (soft delete)",
                        SqlStatement = @"UPDATE OPERATORS o
SET o.VALID_TO = SYSDATE,
    o.IS_CURRENT = 'N',
    o.DELETE_DATE = SYSDATE,
    o.CHANGE_TYPE = 'DELETE'
WHERE o.IS_CURRENT = 'Y'
  AND NOT EXISTS (
    SELECT 1 FROM STG_OPERATORS s
    WHERE s.OPERATOR_ID = o.OPERATOR_ID
      AND s.ETL_RUN_ID = :etlRunId
  );

-- Records are NEVER physically deleted
-- Full history preserved forever
-- Can query deleted records with DELETE_DATE IS NOT NULL"
                    },
                    new ETLStep
                    {
                        StepNumber = 6,
                        Title = "Step 4.2: Handle Reactivations",
                        Description = "Reactivate previously deleted records that return",
                        SqlStatement = @"INSERT INTO OPERATORS (
    OPERATOR_ID, OPERATOR_NAME, SRC_HASH,
    VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
)
SELECT s.OPERATOR_ID, s.OPERATOR_NAME,
       STANDARD_HASH(fields, 'SHA256'),
       SYSDATE, 'Y', 'REACTIVATE', :etlRunId
FROM STG_OPERATORS s
WHERE EXISTS (deleted record) AND NOT EXISTS (current record);

-- Tracks the business scenario of removed then restored data
-- Maintains audit trail of lifecycle"
                    },
                    new ETLStep
                    {
                        StepNumber = 7,
                        Title = "Step 4.3: Detect Unchanged",
                        Description = "Skip records with no changes (performance optimization)",
                        SqlStatement = @"SELECT COUNT(*) INTO v_records_unchanged
FROM STG_OPERATORS s
INNER JOIN OPERATORS o ON o.OPERATOR_ID = s.OPERATOR_ID
WHERE o.IS_CURRENT = 'Y'
  AND STANDARD_HASH(o.fields) = STANDARD_HASH(s.fields);

-- Uses SHA256 hash for efficient change detection
-- Unchanged records are NOT rewritten
-- Reduces database I/O and storage"
                    },
                    new ETLStep
                    {
                        StepNumber = 8,
                        Title = "Step 4.4: Handle Updates",
                        Description = "Create new version for changed records",
                        SqlStatement = @"-- Close old version
UPDATE OPERATORS o
SET o.VALID_TO = SYSDATE, o.IS_CURRENT = 'N'
WHERE o.IS_CURRENT = 'Y' AND [hash changed];

-- Insert new version
INSERT INTO OPERATORS (all_fields, CHANGE_TYPE)
VALUES (new_values, 'UPDATE');

-- Both versions kept: old with IS_CURRENT='N', new with IS_CURRENT='Y'
-- Can query historical state at any point in time"
                    },
                    new ETLStep
                    {
                        StepNumber = 9,
                        Title = "Step 4.5: Handle Inserts",
                        Description = "Add brand new records",
                        SqlStatement = @"INSERT INTO OPERATORS (
    OPERATOR_ID, OPERATOR_NAME, SRC_HASH,
    VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
)
SELECT s.*, SYSDATE, 'Y', 'INSERT', :etlRunId
FROM STG_OPERATORS s
WHERE NOT EXISTS (
    SELECT 1 FROM OPERATORS o
    WHERE o.OPERATOR_ID = s.OPERATOR_ID
);

-- New records start their history
-- VALID_FROM = now, VALID_TO = null
-- IS_CURRENT = 'Y'"
                    },
                    new ETLStep
                    {
                        StepNumber = 11,
                        Title = "Update Control & Commit",
                        Description = "Record metrics and commit transaction",
                        SqlStatement = @"UPDATE ETL_CONTROL
SET RECORDS_UNCHANGED = :unchanged,
    RECORDS_UPDATED = :updated,
    RECORDS_LOADED = :inserted,
    RECORDS_DELETED = :deleted,
    RECORDS_REACTIVATED = :reactivated,
    STATUS = 'SUCCESS',
    END_TIME = SYSTIMESTAMP
WHERE ETL_RUN_ID = :etlRunId;

COMMIT; -- Single atomic commit

-- If ANY error occurs: ROLLBACK everything
-- Error logged via autonomous transaction (survives rollback)
-- Data integrity guaranteed"
                    },
                    new ETLStep
                    {
                        StepNumber = 12,
                        Title = "Post-ETL Cleanup (Automatic)",
                        Description = "Cleanup runs AFTER successful ETL - no DBA required",
                        SqlStatement = @"-- Cleanup executes AFTER COMMIT (non-critical)
BEGIN
    -- Keep only last 10 ETL runs
    DELETE FROM ETL_CONTROL WHERE ETL_RUN_ID < 
        (SELECT MIN(ETL_RUN_ID) FROM last_10_runs);
    
    -- Clean 30-day old error logs
    DELETE FROM ETL_ERROR_LOG WHERE ERROR_TIME < SYSDATE - 30;
    
    -- Clean orphaned staging (safety)
    DELETE FROM STG_* WHERE ETL_RUN_ID < current - 10;
    
    COMMIT; -- Separate commit
EXCEPTION
    WHEN OTHERS THEN
        -- Cleanup errors don't fail ETL
        LOG_ETL_ERROR('Non-critical cleanup error');
END;

-- NO DBA REQUIRED! Runs with your permissions
-- NO SCHEDULED JOBS! Runs after each ETL
-- If cleanup fails, ETL still succeeds"
                    }
                }
            };
        }

        /// <summary>
        /// Get SQL preview for Plants ETL
        /// </summary>
        public ETLSqlPreview GetPlantsSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load Plants - Complete SCD2 Process",
                Description = "This process implements full SCD Type 2 change tracking for Plants (130 records), with foreign key to Operators.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Fetch from API",
                        Description = "C# fetches all plants from TR2000 API",
                        SqlStatement = @"-- C# Code
await _apiService.FetchDataAsync('https://equinor.pipespec-api.presight.com/plants');

Returns: 130 plants with:
- PlantID (e.g., '47')
- PlantName/ShortDescription (e.g., 'AASTA')
- LongDescription (e.g., 'Aasta Hansteen')
- OperatorID (FK to OPERATORS)
- CommonLibPlantCode (e.g., 'AHA')"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "Save to RAW_JSON",
                        Description = "Store raw API response for audit trail",
                        SqlStatement = @"BEGIN
    SP_INSERT_RAW_JSON(
        p_endpoint => '/plants', p_key_string => 'all-plants',
        p_etl_run_id => :etlRunId, p_http_status => 200,
        p_duration_ms => :elapsedMs, p_payload => :apiResponse
    );
END;
-- Compressed storage, 30-day retention, auto-purged"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Load to Staging",
                        Description = "Bulk insert 130 plants to staging",
                        SqlStatement = @"INSERT INTO STG_PLANTS (
    PLANT_ID, PLANT_NAME, LONG_DESCRIPTION,
    OPERATOR_ID, COMMON_LIB_PLANT_CODE, ETL_RUN_ID
) VALUES (
    :PlantId, :PlantName, :LongDescription,
    :OperatorId, :CommonLibPlantCode, :EtlRunId
);

-- Field mappings:
-- PlantName: Uses ShortDescription if PlantName missing
-- All fields nullable except PLANT_ID"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "SCD2 Processing",
                        Description = "PKG_PLANTS_ETL.PROCESS_SCD2 handles all logic",
                        SqlStatement = @"-- Same 5-step process as OPERATORS:
1. DELETE: Mark missing plants as deleted
2. REACTIVATE: Restore previously deleted plants
3. UNCHANGED: Skip if hash matches (most common)
4. UPDATE: New version for changed plants
5. INSERT: Add new plants

-- Key difference: More fields in hash
STANDARD_HASH(
    PLANT_ID || PLANT_NAME || LONG_DESCRIPTION ||
    OPERATOR_ID || COMMON_LIB_PLANT_CODE
)"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Data Integrity",
                        Description = "Validation and error handling",
                        SqlStatement = @"-- Validation checks:
- PLANT_ID required (cannot be null)
- PLANT_NAME max 200 characters
- Foreign key to OPERATORS validated

-- Error handling:
IF validation_failed THEN
    UPDATE STG_PLANTS 
    SET IS_VALID = 'N',
        VALIDATION_ERROR = 'specific error'
    WHERE [failed condition];
    
    -- Record still processed but marked
END IF;

-- Autonomous error logging:
LOG_ETL_ERROR(run_id, source, code, message);
-- This survives even if transaction rolls back"
                    },
                    new ETLStep
                    {
                        StepNumber = 6,
                        Title = "Reconciliation",
                        Description = "Verify data consistency",
                        SqlStatement = @"INSERT INTO ETL_RECONCILIATION (
    ETL_RUN_ID, ENTITY_TYPE, 
    SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
)
SELECT :etlRunId, 'PLANTS',
       (SELECT COUNT(*) FROM STG_PLANTS WHERE IS_VALID='Y'),
       (SELECT COUNT(*) FROM PLANTS WHERE IS_CURRENT='Y'),
       ABS(source - target);

-- Alert if difference > 10%
-- Helps detect data quality issues"
                    }
                }
            };
        }

        /// <summary>
        /// Get SQL preview for Issues ETL
        /// </summary>
        public ETLSqlPreview GetIssuesSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load Issues - Multi-Plant Process",
                Description = "Loads issues for all 130 plants with multiple API calls. Uses ETL_PLANT_LOADER for scope control.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Plant Loader Scope",
                        Description = "Check which plants to process",
                        SqlStatement = @"SELECT PLANT_ID, PLANT_NAME
FROM ETL_PLANT_LOADER
WHERE IS_ACTIVE = 'Y'
ORDER BY LOAD_PRIORITY;

-- ETL_PLANT_LOADER controls scope
-- Without it: 130 plants × N issues = 500+ API calls
-- With it: 3-5 plants × N issues = 30-50 API calls
-- 90% reduction in processing time!"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "API Loop",
                        Description = "Fetch issues for each active plant",
                        SqlStatement = @"FOR each plant IN active_plants LOOP
    -- API call for each plant
    await FetchDataAsync('/plants/{plantId}/issues');
    
    -- Each returns multiple issue revisions
    -- Insert all to staging with same ETL_RUN_ID
END LOOP;

-- Typical: 3-10 issues per plant
-- Total records: 50-500 depending on scope"
                    }
                }
            };
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
        /// Insert raw JSON response to audit table (optional, best-effort)
        /// </summary>
        private async Task InsertRawJson(
            OracleConnection connection, 
            int etlRunId, 
            string endpoint, 
            string keyString,
            string apiResponse,
            int httpStatus = 200,
            int? durationMs = null)
        {
            try
            {
                await connection.ExecuteAsync(@"
                    BEGIN
                        SP_INSERT_RAW_JSON(
                            p_endpoint      => :endpoint,
                            p_key_string    => :keyString,
                            p_etl_run_id    => :etlRunId,
                            p_http_status   => :httpStatus,
                            p_duration_ms   => :durationMs,
                            p_headers_json  => :headers,
                            p_payload       => :payload
                        );
                    END;",
                    new 
                    { 
                        endpoint,
                        keyString,
                        etlRunId,
                        httpStatus,
                        durationMs = durationMs ?? 0,
                        headers = "{\"Content-Type\": \"application/json\"}",
                        payload = apiResponse
                    });
                _logger.LogDebug($"RAW_JSON inserted for {endpoint}");
            }
            catch (Exception ex)
            {
                // Non-critical - log and continue
                _logger.LogWarning($"RAW_JSON insert failed (non-critical): {ex.Message}");
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
                var sw = System.Diagnostics.Stopwatch.StartNew();
                var apiResponse = await _apiService.FetchDataAsync("operators");
                sw.Stop();
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

                // Optional: Insert RAW_JSON for audit trail
                await InsertRawJson(
                    connection, 
                    etlRunId, 
                    "/operators", 
                    "all-operators",
                    apiResponse,
                    200,
                    (int)sw.ElapsedMilliseconds
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
                            OperatorId = Convert.ToInt32(row["OperatorID"]),  // Fixed: OperatorID with capital ID
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
                var sw = System.Diagnostics.Stopwatch.StartNew();
                var apiResponse = await _apiService.FetchDataAsync("plants");
                sw.Stop();
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

                // Optional: Insert RAW_JSON for audit trail
                await InsertRawJson(
                    connection, 
                    etlRunId, 
                    "/plants", 
                    "all-plants",
                    apiResponse,
                    200,
                    (int)sw.ElapsedMilliseconds
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
                            PlantId = row["PlantID"]?.ToString(),  // Fixed: PlantID with capital ID
                            PlantName = row.ContainsKey("PlantName") ? row["PlantName"]?.ToString() : row["ShortDescription"]?.ToString(),  // Use ShortDescription as PlantName
                            LongDescription = row["LongDescription"]?.ToString(),
                            OperatorId = row.ContainsKey("OperatorID") ? Convert.ToInt32(row["OperatorID"]) : (int?)null,  // Fixed: OperatorID with capital ID
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
                    ORDER BY PLANT_ID"
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
                                        IssueRevision = issue["IssueRevision"]?.ToString(),  // Fixed: API returns IssueRevision not Revision
                                        UserName = issue["UserName"]?.ToString(),
                                        UserEntryTime = ParseDateTime(issue.ContainsKey("UserEntryTime") ? issue["UserEntryTime"] : null),
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
                
                try
                {
                    using (var cmd = new OracleCommand("SP_PROCESS_ETL_BATCH", connection))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add("p_etl_run_id", OracleDbType.Int32).Value = etlRunId;
                        cmd.Parameters.Add("p_entity_type", OracleDbType.Varchar2).Value = "ISSUES";
                        
                        await cmd.ExecuteNonQueryAsync();
                    }
                    _logger.LogInformation("Orchestrator completed successfully");
                }
                catch (OracleException oex)
                {
                    _logger.LogError($"Oracle error in orchestrator: {oex.Message} (Code: {oex.Number})");
                    throw;
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
        /// Check if plant loader table exists
        /// </summary>
        public async Task<bool> CheckPlantLoaderTableExists()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                var count = await connection.QuerySingleAsync<int>(@"
                    SELECT COUNT(*) 
                    FROM USER_TABLES 
                    WHERE TABLE_NAME = 'ETL_PLANT_LOADER'"
                );
                return count > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to check plant loader table");
                return false;
            }
        }

        /// <summary>
        /// Create plant loader table
        /// </summary>
        public async Task CreatePlantLoaderTable()
        {
            using var connection = new OracleConnection(_connectionString);
            await connection.ExecuteAsync(@"
                CREATE TABLE ETL_PLANT_LOADER (
                    PLANT_ID VARCHAR2(20) PRIMARY KEY,
                    PLANT_NAME VARCHAR2(200),
                    IS_ACTIVE CHAR(1) DEFAULT 'Y' CHECK (IS_ACTIVE IN ('Y', 'N')),
                    CREATED_DATE DATE DEFAULT SYSDATE,
                    MODIFIED_DATE DATE DEFAULT SYSDATE
                )"
            );
        }

        /// <summary>
        /// Get all plants from database
        /// </summary>
        public async Task<List<Plant>> GetAllPlants()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                var plants = await connection.QueryAsync<Plant>(@"
                    SELECT PLANT_ID as PlantID, 
                           PLANT_NAME as PlantName,
                           LONG_DESCRIPTION as LongDescription,
                           OPERATOR_ID as OperatorID
                    FROM PLANTS 
                    WHERE IS_CURRENT = 'Y'
                    ORDER BY PLANT_NAME"
                );
                return plants.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get all plants");
                return new List<Plant>();
            }
        }

        /// <summary>
        /// Get plant loader entries
        /// </summary>
        public async Task<List<PlantLoaderEntry>> GetPlantLoaderEntries()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                var entries = await connection.QueryAsync<PlantLoaderEntry>(@"
                    SELECT PLANT_ID as PlantID,
                           PLANT_NAME as PlantName,
                           CASE WHEN IS_ACTIVE = 'Y' THEN 1 ELSE 0 END as IsActive,
                           CREATED_DATE as CreatedDate,
                           MODIFIED_DATE as ModifiedDate
                    FROM ETL_PLANT_LOADER
                    ORDER BY PLANT_NAME"
                );
                return entries.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get plant loader entries");
                return new List<PlantLoaderEntry>();
            }
        }

        /// <summary>
        /// Add plant to loader
        /// </summary>
        public async Task AddPlantToLoader(string plantId)
        {
            using var connection = new OracleConnection(_connectionString);
            
            // Get plant details
            var plant = await connection.QuerySingleOrDefaultAsync<Plant>(@"
                SELECT PLANT_ID as PlantID, PLANT_NAME as PlantName
                FROM PLANTS 
                WHERE IS_CURRENT = 'Y' AND PLANT_ID = :plantId",
                new { plantId }
            );
            
            if (plant == null)
                throw new Exception($"Plant {plantId} not found");
            
            // Insert into loader
            await connection.ExecuteAsync(@"
                INSERT INTO ETL_PLANT_LOADER (PLANT_ID, PLANT_NAME, IS_ACTIVE)
                VALUES (:plantId, :plantName, 'Y')",
                new { plantId = plant.PlantID, plantName = plant.PlantName }
            );
        }

        /// <summary>
        /// Toggle plant active status
        /// </summary>
        public async Task TogglePlantActive(string plantId)
        {
            using var connection = new OracleConnection(_connectionString);
            await connection.ExecuteAsync(@"
                UPDATE ETL_PLANT_LOADER 
                SET IS_ACTIVE = CASE WHEN IS_ACTIVE = 'Y' THEN 'N' ELSE 'Y' END,
                    MODIFIED_DATE = SYSDATE
                WHERE PLANT_ID = :plantId",
                new { plantId }
            );
        }

        /// <summary>
        /// Remove plant from loader
        /// </summary>
        public async Task RemovePlantFromLoader(string plantId)
        {
            using var connection = new OracleConnection(_connectionString);
            await connection.ExecuteAsync(@"
                DELETE FROM ETL_PLANT_LOADER 
                WHERE PLANT_ID = :plantId",
                new { plantId }
            );
        }

        /// <summary>
        /// Parse datetime from various formats safely
        /// </summary>
        private DateTime? ParseDateTime(object? value)
        {
            if (value == null) return null;
            
            var dateStr = value.ToString();
            if (string.IsNullOrWhiteSpace(dateStr)) return null;
            
            // Try multiple common formats
            string[] formats = new[] 
            {
                "dd.MM.yyyy HH:mm:ss",
                "dd.MM.yyyy HH:mm",
                "yyyy-MM-dd HH:mm:ss",
                "yyyy-MM-dd HH:mm",
                "MM/dd/yyyy HH:mm:ss",
                "MM/dd/yyyy HH:mm",
                "yyyy-MM-ddTHH:mm:ss",
                "yyyy-MM-ddTHH:mm:ssZ"
            };
            
            foreach (var format in formats)
            {
                if (DateTime.TryParseExact(dateStr, format, 
                    System.Globalization.CultureInfo.InvariantCulture, 
                    System.Globalization.DateTimeStyles.None, out var result))
                {
                    return result;
                }
            }
            
            // Try general parse as fallback
            if (DateTime.TryParse(dateStr, out var fallbackResult))
            {
                return fallbackResult;
            }
            
            _logger.LogWarning($"Could not parse date: {dateStr}");
            return null;
        }

    }
    
    // Note: Using ETLResult, ETLRunHistory, and TableStatus classes from OracleETLService
}