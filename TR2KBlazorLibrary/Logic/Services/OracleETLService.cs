using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Oracle.ManagedDataAccess.Client;
using TR2KBlazorLibrary.Models;

namespace TR2KBlazorLibrary.Logic.Services
{
    public class OracleETLService
    {
        private readonly string _connectionString;
        private readonly TR2000ApiService _apiService;
        private readonly ApiResponseDeserializer _deserializer;
        private readonly ILogger<OracleETLService> _logger;
        private readonly IConfiguration _configuration;

        public OracleETLService(IConfiguration configuration, TR2000ApiService apiService, ApiResponseDeserializer deserializer, ILogger<OracleETLService> logger)
        {
            _configuration = configuration;
            _connectionString = configuration.GetConnectionString("OracleConnection") ?? string.Empty;
            _apiService = apiService;
            _deserializer = deserializer;
            _logger = logger;
        }

        public async Task<bool> TestConnection()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                _logger.LogInformation("Successfully connected to Oracle database");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to connect to Oracle database");
                return false;
            }
        }

        public async Task<bool> CreateAllTables()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();

                // Create ETL Control tables first
                await CreateETLControlTables(connection);
                
                // Create Master Data tables
                await CreateMasterDataTables(connection);
                
                // Create Reference tables
                await CreateReferenceTables(connection);
                
                _logger.LogInformation("All tables created successfully");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create tables");
                return false;
            }
        }

        private async Task CreateETLControlTables(OracleConnection connection)
        {
            // ETL Control Table
            string createETLControl = @"
                CREATE TABLE ETL_CONTROL (
                    ETL_RUN_ID         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                    RUN_DATE           DATE DEFAULT SYSDATE,
                    RUN_TYPE           VARCHAR2(20),
                    STATUS             VARCHAR2(20),
                    RECORDS_EXTRACTED  NUMBER,
                    RECORDS_LOADED     NUMBER,
                    ERROR_COUNT        NUMBER,
                    START_TIME         DATE,
                    END_TIME           DATE,
                    COMMENTS           VARCHAR2(4000)
                )";

            await ExecuteNonQuery(connection, createETLControl, "ETL_CONTROL");

            // Endpoint Processing Log
            string createEndpointLog = @"
                CREATE TABLE ETL_ENDPOINT_LOG (
                    LOG_ID             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                    ETL_RUN_ID         NUMBER,
                    ENDPOINT_NAME      VARCHAR2(100),
                    PLANT_ID           VARCHAR2(50),
                    API_URL            VARCHAR2(500),
                    RESPONSE_TIME_MS   NUMBER,
                    RECORD_COUNT       NUMBER,
                    STATUS             VARCHAR2(20),
                    ERROR_MESSAGE      VARCHAR2(4000),
                    PROCESSED_DATE     DATE DEFAULT SYSDATE
                )";

            await ExecuteNonQuery(connection, createEndpointLog, "ETL_ENDPOINT_LOG");

            // Error Log
            string createErrorLog = @"
                CREATE TABLE ETL_ERROR_LOG (
                    ERROR_ID           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                    ETL_RUN_ID         NUMBER,
                    ERROR_DATE         DATE DEFAULT SYSDATE,
                    ERROR_TYPE         VARCHAR2(50),
                    ERROR_MESSAGE      VARCHAR2(4000),
                    STACK_TRACE        CLOB,
                    ENDPOINT_NAME      VARCHAR2(100),
                    RECORD_DATA        CLOB
                )";

            await ExecuteNonQuery(connection, createErrorLog, "ETL_ERROR_LOG");
        }

        private async Task CreateMasterDataTables(OracleConnection connection)
        {
            // Operators Table
            string createOperators = @"
                CREATE TABLE OPERATORS (
                    OPERATOR_ID        NUMBER NOT NULL,
                    OPERATOR_NAME      VARCHAR2(200),
                    ETL_RUN_ID         NUMBER,
                    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
                    IS_CURRENT         CHAR(1) DEFAULT 'Y',
                    PRIMARY KEY (OPERATOR_ID, EXTRACTION_DATE)
                )";

            await ExecuteNonQuery(connection, createOperators, "OPERATORS");

            // Plants Table
            string createPlants = @"
                CREATE TABLE PLANTS (
                    PLANT_ID           VARCHAR2(50) NOT NULL,
                    OPERATOR_ID        NUMBER,
                    OPERATOR_NAME      VARCHAR2(200),
                    SHORT_DESCRIPTION  VARCHAR2(100),
                    PROJECT            VARCHAR2(100),
                    LONG_DESCRIPTION   VARCHAR2(500),
                    COMMON_LIB_PLANT_CODE VARCHAR2(20),
                    INITIAL_REVISION   VARCHAR2(20),
                    AREA_ID            NUMBER,
                    AREA               VARCHAR2(100),
                    ETL_RUN_ID         NUMBER,
                    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
                    IS_CURRENT         CHAR(1) DEFAULT 'Y',
                    PRIMARY KEY (PLANT_ID, EXTRACTION_DATE)
                )";

            await ExecuteNonQuery(connection, createPlants, "PLANTS");

            // Issues Table
            string createIssues = @"
                CREATE TABLE ISSUES (
                    PLANT_ID           VARCHAR2(50) NOT NULL,
                    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
                    USER_NAME          VARCHAR2(100),
                    USER_ENTRY_TIME    DATE,
                    USER_PROTECTED     CHAR(1),
                    ETL_RUN_ID         NUMBER,
                    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
                    IS_CURRENT         CHAR(1) DEFAULT 'Y',
                    PRIMARY KEY (PLANT_ID, ISSUE_REVISION, EXTRACTION_DATE)
                )";

            await ExecuteNonQuery(connection, createIssues, "ISSUES");
        }

        private async Task CreateReferenceTables(OracleConnection connection)
        {
            // PCS References Table
            string createPCSReferences = @"
                CREATE TABLE PCS_REFERENCES (
                    PLANT_ID           VARCHAR2(50) NOT NULL,
                    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
                    PCS_NAME           VARCHAR2(100),
                    PCS_REVISION       VARCHAR2(20),
                    USER_NAME          VARCHAR2(100),
                    USER_ENTRY_TIME    DATE,
                    USER_PROTECTED     CHAR(1),
                    ETL_RUN_ID         NUMBER,
                    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
                    IS_CURRENT         CHAR(1) DEFAULT 'Y',
                    PRIMARY KEY (PLANT_ID, ISSUE_REVISION, PCS_NAME, PCS_REVISION, EXTRACTION_DATE)
                )";

            await ExecuteNonQuery(connection, createPCSReferences, "PCS_REFERENCES");

            // Additional reference tables can be added here as needed
        }

        private async Task ExecuteNonQuery(OracleConnection connection, string sql, string tableName)
        {
            try
            {
                // First check if table exists
                string checkTableExists = @"
                    SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = :tableName";
                
                using (var checkCmd = new OracleCommand(checkTableExists, connection))
                {
                    checkCmd.Parameters.Add(new OracleParameter("tableName", tableName));
                    var exists = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());
                    
                    if (exists > 0)
                    {
                        _logger.LogInformation($"Table {tableName} already exists, skipping creation");
                        return;
                    }
                }

                // Create the table
                using var cmd = new OracleCommand(sql, connection);
                await cmd.ExecuteNonQueryAsync();
                _logger.LogInformation($"Table {tableName} created successfully");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to create table {tableName}");
                throw;
            }
        }

        public async Task<ETLResult> LoadOperators()
        {
            var result = new ETLResult { StartTime = DateTime.Now, EndpointName = "operators" };
            var sqlStatements = new List<string>();
            int etlRunId = 0;
            
            try
            {
                // STEP 1: Fetch data from API FIRST (before any database changes)
                _logger.LogInformation("Step 1: Fetching data from API...");
                var apiResponse = await _apiService.FetchDataAsync("operators");
                var apiData = _deserializer.DeserializeApiResponse(apiResponse, "operators");
                
                if (apiData == null || !apiData.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No data returned from API";
                    return result;
                }
                
                _logger.LogInformation($"Successfully fetched {apiData.Count} operators from API");

                // STEP 2: Open connection with transaction
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                // Start transaction for atomicity
                using var transaction = connection.BeginTransaction();
                
                try
                {
                    // STEP 3: Start ETL run (within transaction)
                    etlRunId = await StartETLRun("FULL", "operators", connection, transaction);
                
                    // STEP 4: Mark existing records as not current
                    string updateSql = @"
                        UPDATE OPERATORS 
                        SET IS_CURRENT = 'N' 
                        WHERE IS_CURRENT = 'Y'";
                    
                    sqlStatements.Add("-- Step 2: Mark existing records as historical (within transaction)");
                    sqlStatements.Add(updateSql);
                    
                    using (var updateCmd = new OracleCommand(updateSql, connection))
                    {
                        updateCmd.Transaction = transaction;
                        var rowsUpdated = await updateCmd.ExecuteNonQueryAsync();
                        _logger.LogInformation($"Marked {rowsUpdated} existing operators as historical");
                    }

                    // STEP 5: Insert new records
                    string insertSql = @"
                        INSERT INTO OPERATORS 
                        (OPERATOR_ID, OPERATOR_NAME, ETL_RUN_ID, IS_CURRENT)
                        VALUES (:operatorId, :operatorName, :etlRunId, 'Y')";

                    sqlStatements.Add("\n-- Step 3: Insert new data from API (within same transaction)");
                    sqlStatements.Add(insertSql.Replace(":operatorId", "<OPERATOR_ID>")
                        .Replace(":operatorName", "<OPERATOR_NAME>")
                        .Replace(":etlRunId", etlRunId.ToString()));

                    int recordsLoaded = 0;
                    foreach (var row in apiData)
                    {
                        using var cmd = new OracleCommand(insertSql, connection);
                        cmd.Transaction = transaction;
                        cmd.Parameters.Add(new OracleParameter("operatorId", row["OperatorID"]));
                        cmd.Parameters.Add(new OracleParameter("operatorName", row["OperatorName"]));
                        cmd.Parameters.Add(new OracleParameter("etlRunId", etlRunId));
                        
                        await cmd.ExecuteNonQueryAsync();
                        recordsLoaded++;
                    }

                    // STEP 6: Complete ETL run (within transaction)
                    await CompleteETLRun(etlRunId, "SUCCESS", recordsLoaded, 0, connection, transaction);
                    
                    // STEP 7: Commit transaction - ALL OR NOTHING!
                    await transaction.CommitAsync();
                    _logger.LogInformation("Transaction committed successfully - all changes saved");
                
                    result.Status = "SUCCESS";
                    result.RecordsLoaded = recordsLoaded;
                    result.EndTime = DateTime.Now;
                    result.Message = $"Successfully loaded {recordsLoaded} operators";
                    result.SqlStatements = sqlStatements;
                    
                    _logger.LogInformation($"Successfully loaded {recordsLoaded} operators to Oracle");
                    return result;
                }
                catch (Exception ex)
                {
                    // ROLLBACK on any error - NO DATA LOSS!
                    await transaction.RollbackAsync();
                    _logger.LogError(ex, "Error during ETL process - transaction rolled back, no data was changed");
                    
                    // Log error to ETL_ERROR_LOG
                    if (etlRunId > 0)
                    {
                        await LogETLError(etlRunId, ex, "operators");
                    }
                    
                    throw; // Re-throw to outer catch
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load operators");
                result.Status = "ERROR";
                result.Message = $"Error: {ex.Message}. No data was modified - transaction was rolled back.";
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        public async Task<ETLResult> LoadPlants(int? operatorId = null)
        {
            var result = new ETLResult { StartTime = DateTime.Now, EndpointName = "plants" };
            var sqlStatements = new List<string>();
            int etlRunId = 0;
            
            try
            {
                // STEP 1: Fetch data from API FIRST
                _logger.LogInformation("Step 1: Fetching plants data from API...");
                List<Dictionary<string, object>> allPlants = new List<Dictionary<string, object>>();
                
                if (operatorId.HasValue)
                {
                    // Load plants for specific operator
                    var apiResponse = await _apiService.FetchDataAsync($"operators/{operatorId}/plants");
                    var apiData = _deserializer.DeserializeApiResponse(apiResponse, $"operators/{operatorId}/plants");
                    if (apiData != null) allPlants.AddRange(apiData);
                }
                else
                {
                    // Load all plants
                    var apiResponse = await _apiService.FetchDataAsync("plants");
                    var apiData = _deserializer.DeserializeApiResponse(apiResponse, "plants");
                    if (apiData != null) allPlants.AddRange(apiData);
                }
                
                if (!allPlants.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No plant data returned from API";
                    return result;
                }
                
                _logger.LogInformation($"Successfully fetched {allPlants.Count} plants from API");

                // STEP 2: Open connection with transaction
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                using var transaction = connection.BeginTransaction();
                
                try
                {
                    // STEP 3: Start ETL run
                    etlRunId = await StartETLRun("FULL", "plants", connection, transaction);
                
                    // STEP 4: Mark existing records as not current
                    string updateSql = @"
                        UPDATE PLANTS 
                        SET IS_CURRENT = 'N' 
                        WHERE IS_CURRENT = 'Y'";
                    
                    sqlStatements.Add("-- Step 2: Mark existing records as historical (within transaction)");
                    sqlStatements.Add(updateSql);
                    
                    using (var updateCmd = new OracleCommand(updateSql, connection))
                    {
                        updateCmd.Transaction = transaction;
                        var rowsUpdated = await updateCmd.ExecuteNonQueryAsync();
                        _logger.LogInformation($"Marked {rowsUpdated} existing plants as historical");
                    }

                    // STEP 5: Insert new records
                    string insertSql = @"
                        INSERT INTO PLANTS 
                        (PLANT_ID, OPERATOR_ID, OPERATOR_NAME, SHORT_DESCRIPTION, PROJECT, 
                         LONG_DESCRIPTION, COMMON_LIB_PLANT_CODE, INITIAL_REVISION, 
                         AREA_ID, AREA, ETL_RUN_ID, IS_CURRENT)
                        VALUES (:plantId, :operatorId, :operatorName, :shortDesc, :project,
                                :longDesc, :commonLib, :initRev, :areaId, :area, :etlRunId, 'Y')";

                    sqlStatements.Add("\n-- Step 3: Insert new plant data from API (within same transaction)");
                    sqlStatements.Add(insertSql.Replace(":plantId", "<PLANT_ID>")
                        .Replace(":operatorId", "<OPERATOR_ID>")
                        .Replace(":operatorName", "<OPERATOR_NAME>")
                        .Replace(":shortDesc", "<SHORT_DESC>")
                        .Replace(":project", "<PROJECT>")
                        .Replace(":longDesc", "<LONG_DESC>")
                        .Replace(":commonLib", "<COMMON_LIB>")
                        .Replace(":initRev", "<INITIAL_REV>")
                        .Replace(":areaId", "<AREA_ID>")
                        .Replace(":area", "<AREA>")
                        .Replace(":etlRunId", etlRunId.ToString()));

                    int recordsLoaded = 0;
                    foreach (var row in allPlants)
                    {
                        using var cmd = new OracleCommand(insertSql, connection);
                        cmd.Transaction = transaction;
                        cmd.Parameters.Add(new OracleParameter("plantId", row.GetValueOrDefault("PlantID", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("operatorId", row.GetValueOrDefault("OperatorID", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("operatorName", row.GetValueOrDefault("OperatorName", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("shortDesc", row.GetValueOrDefault("ShortDescription", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("project", row.GetValueOrDefault("Project", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("longDesc", row.GetValueOrDefault("LongDescription", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("commonLib", row.GetValueOrDefault("CommonLibPlantCode", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("initRev", row.GetValueOrDefault("InitialRevision", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("areaId", row.GetValueOrDefault("AreaID", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("area", row.GetValueOrDefault("Area", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("etlRunId", etlRunId));
                        
                        await cmd.ExecuteNonQueryAsync();
                        recordsLoaded++;
                    }

                    // STEP 6: Complete ETL run (within transaction)
                    await CompleteETLRun(etlRunId, "SUCCESS", recordsLoaded, 0, connection, transaction);
                    
                    // STEP 7: Commit transaction - ALL OR NOTHING!
                    await transaction.CommitAsync();
                    _logger.LogInformation("Transaction committed successfully - all changes saved");
                    
                    result.Status = "SUCCESS";
                    result.RecordsLoaded = recordsLoaded;
                    result.EndTime = DateTime.Now;
                    result.Message = $"Successfully loaded {recordsLoaded} plants";
                    result.SqlStatements = sqlStatements;
                    
                    return result;
                }
                catch (Exception ex)
                {
                    // ROLLBACK on any error
                    await transaction.RollbackAsync();
                    _logger.LogError(ex, "Error during plant ETL - transaction rolled back");
                    
                    if (etlRunId > 0)
                    {
                        await LogETLError(etlRunId, ex, "plants");
                    }
                    
                    throw;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load plants");
                result.Status = "ERROR";
                result.Message = $"Error: {ex.Message}. No data was modified - transaction was rolled back.";
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        public async Task<ETLResult> LoadIssues(string? plantId = null)
        {
            var result = new ETLResult { StartTime = DateTime.Now, EndpointName = "issues" };
            var sqlStatements = new List<string>();
            int etlRunId = 0;
            
            try
            {
                // STEP 1: Fetch data from API FIRST
                _logger.LogInformation("Step 1: Fetching issues data from API...");
                List<Dictionary<string, object>> allIssues = new List<Dictionary<string, object>>();
                
                if (!string.IsNullOrEmpty(plantId))
                {
                    // Load issues for specific plant
                    var apiResponse = await _apiService.FetchDataAsync($"plants/{plantId}/issues");
                    var apiData = _deserializer.DeserializeApiResponse(apiResponse, $"plants/{plantId}/issues");
                    if (apiData != null) allIssues.AddRange(apiData);
                }
                else
                {
                    // Load all issues (by fetching for each plant)
                    // First get all plants
                    var plantsResponse = await _apiService.FetchDataAsync("plants");
                    var plants = _deserializer.DeserializeApiResponse(plantsResponse, "plants");
                    
                    // Then fetch issues for each plant
                    foreach (var plant in plants)
                    {
                        var pid = plant["PlantID"]?.ToString();
                        if (!string.IsNullOrEmpty(pid))
                        {
                            var apiResponse = await _apiService.FetchDataAsync($"plants/{pid}/issues");
                            var apiData = _deserializer.DeserializeApiResponse(apiResponse, $"plants/{pid}/issues");
                            if (apiData != null) 
                            {
                                // Add PlantID to each issue record
                                foreach (var issue in apiData)
                                {
                                    issue["PlantID"] = pid;
                                }
                                allIssues.AddRange(apiData);
                            }
                        }
                    }
                }
                
                if (!allIssues.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No issues data returned from API";
                    return result;
                }
                
                _logger.LogInformation($"Successfully fetched {allIssues.Count} issues from API");

                // STEP 2: Open connection with transaction
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                using var transaction = connection.BeginTransaction();
                
                try
                {
                    // STEP 3: Start ETL run
                    etlRunId = await StartETLRun("FULL", "issues", connection, transaction);
                
                    // STEP 4: Mark existing records as not current
                    string updateSql = @"
                        UPDATE ISSUES 
                        SET IS_CURRENT = 'N' 
                        WHERE IS_CURRENT = 'Y'";
                    
                    if (!string.IsNullOrEmpty(plantId))
                    {
                        updateSql += " AND PLANT_ID = :plantId";
                    }
                    
                    sqlStatements.Add("-- Step 2: Mark existing records as historical (within transaction)");
                    sqlStatements.Add(updateSql);
                    
                    using (var updateCmd = new OracleCommand(updateSql, connection))
                    {
                        updateCmd.Transaction = transaction;
                        if (!string.IsNullOrEmpty(plantId))
                        {
                            updateCmd.Parameters.Add(new OracleParameter("plantId", plantId));
                        }
                        var rowsUpdated = await updateCmd.ExecuteNonQueryAsync();
                        _logger.LogInformation($"Marked {rowsUpdated} existing issues as historical");
                    }

                    // STEP 5: Insert new records
                    string insertSql = @"
                        INSERT INTO ISSUES 
                        (PLANT_ID, ISSUE_REVISION, USER_NAME, USER_ENTRY_TIME, 
                         USER_PROTECTED, ETL_RUN_ID, IS_CURRENT)
                        VALUES (:plantId, :issueRevision, :userName, :userEntryTime,
                                :userProtected, :etlRunId, 'Y')";

                    sqlStatements.Add("\n-- Step 3: Insert new issues data from API (within same transaction)");
                    sqlStatements.Add(insertSql.Replace(":plantId", "<PLANT_ID>")
                        .Replace(":issueRevision", "<ISSUE_REVISION>")
                        .Replace(":userName", "<USER_NAME>")
                        .Replace(":userEntryTime", "<USER_ENTRY_TIME>")
                        .Replace(":userProtected", "<USER_PROTECTED>")
                        .Replace(":etlRunId", etlRunId.ToString()));

                    int recordsLoaded = 0;
                    foreach (var row in allIssues)
                    {
                        using var cmd = new OracleCommand(insertSql, connection);
                        cmd.Transaction = transaction;
                        cmd.Parameters.Add(new OracleParameter("plantId", row.GetValueOrDefault("PlantID", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("issueRevision", row.GetValueOrDefault("IssueRevision", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("userName", row.GetValueOrDefault("UserName", DBNull.Value)));
                        
                        // Handle UserEntryTime as DateTime
                        var userEntryTime = row.GetValueOrDefault("UserEntryTime", DBNull.Value);
                        if (userEntryTime != DBNull.Value && userEntryTime != null)
                        {
                            if (DateTime.TryParse(userEntryTime.ToString(), out var dateTime))
                            {
                                cmd.Parameters.Add(new OracleParameter("userEntryTime", dateTime));
                            }
                            else
                            {
                                cmd.Parameters.Add(new OracleParameter("userEntryTime", DBNull.Value));
                            }
                        }
                        else
                        {
                            cmd.Parameters.Add(new OracleParameter("userEntryTime", DBNull.Value));
                        }
                        
                        cmd.Parameters.Add(new OracleParameter("userProtected", row.GetValueOrDefault("UserProtected", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("etlRunId", etlRunId));
                        
                        await cmd.ExecuteNonQueryAsync();
                        recordsLoaded++;
                    }

                    // STEP 6: Complete ETL run (within transaction)
                    await CompleteETLRun(etlRunId, "SUCCESS", recordsLoaded, 0, connection, transaction);
                    
                    // STEP 7: Commit transaction - ALL OR NOTHING!
                    await transaction.CommitAsync();
                    _logger.LogInformation("Transaction committed successfully - all changes saved");
                    
                    result.Status = "SUCCESS";
                    result.RecordsLoaded = recordsLoaded;
                    result.EndTime = DateTime.Now;
                    result.Message = $"Successfully loaded {recordsLoaded} issues";
                    result.SqlStatements = sqlStatements;
                    
                    return result;
                }
                catch (Exception ex)
                {
                    // ROLLBACK on any error
                    await transaction.RollbackAsync();
                    _logger.LogError(ex, "Error during issues ETL - transaction rolled back");
                    
                    if (etlRunId > 0)
                    {
                        await LogETLError(etlRunId, ex, "issues");
                    }
                    
                    throw;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load issues");
                result.Status = "ERROR";
                result.Message = $"Error: {ex.Message}. No data was modified - transaction was rolled back.";
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        public ETLSqlPreview GetLoadIssuesSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load Issues - SQL Operations",
                Description = "Loads issue revisions with user metadata and maintains history:",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Fetch Data from API",
                        Description = "Call TR2000 API endpoint: GET https://equinor.pipespec-api.presight.com/plants/{plantId}/issues",
                        SqlStatement = "-- No SQL: This step fetches data from the API\n-- Returns JSON with issue revisions for each plant"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "Mark Existing Records as Historical",
                        Description = "Preserves existing data by setting IS_CURRENT to 'N'",
                        SqlStatement = @"UPDATE ISSUES 
SET IS_CURRENT = 'N' 
WHERE IS_CURRENT = 'Y'"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Insert New Issue Records",
                        Description = "Inserts issue revisions with user tracking information",
                        SqlStatement = @"INSERT INTO ISSUES 
(PLANT_ID, ISSUE_REVISION, USER_NAME, USER_ENTRY_TIME, 
 USER_PROTECTED, ETL_RUN_ID, IS_CURRENT, EXTRACTION_DATE)
VALUES (:plantId, :issueRevision, :userName, :userEntryTime,
        :userProtected, :etlRunId, 'Y', SYSDATE)

-- Example with actual values:
-- INSERT INTO ISSUES 
-- VALUES ('34', '1', 'john.doe', '2025-08-15 14:30:00',
--         'N', 123, 'Y', '2025-08-16 10:30:00')"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Important Note",
                        Description = "Issues are plant-specific, so loading all issues requires iterating through all plants",
                        SqlStatement = @"-- For 'Load All': The system will:
-- 1. Fetch all plants
-- 2. For each plant, fetch its issues
-- 3. Aggregate all issues into one transaction
-- This ensures consistency across all plants"
                    }
                }
            };
        }

        // ===================== REFERENCE TABLE LOADING METHODS =====================
        
        public async Task<ETLResult> LoadPCSReferences()
        {
            var result = new ETLResult { StartTime = DateTime.Now };
            var sqlStatements = new List<string>();
            int etlRunId = 0;
            
            try
            {
                _logger.LogInformation("Step 1: Fetching PCS references data from API...");
                
                // Fetch all plants first
                var plantsResponse = await _apiService.FetchDataAsync("plants");
                var plantsData = _deserializer.DeserializeApiResponse(plantsResponse, "plants");
                
                if (plantsData == null || !plantsData.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No plants found";
                    return result;
                }
                
                var allPCSReferences = new List<Dictionary<string, object>>();
                
                // For each plant, fetch its issues first to get issue revisions
                foreach (var plant in plantsData)
                {
                    var plantId = plant.GetValueOrDefault("PlantID", "")?.ToString();
                    if (string.IsNullOrEmpty(plantId)) continue;
                    
                    // Get issues for this plant
                    var issuesResponse = await _apiService.FetchDataAsync($"plants/{plantId}/issues");
                    var issuesData = _deserializer.DeserializeApiResponse(issuesResponse, $"plants/{plantId}/issues");
                    
                    if (issuesData == null) continue;
                    
                    // For each issue revision, get PCS references
                    foreach (var issue in issuesData)
                    {
                        var issueRevision = issue.GetValueOrDefault("IssueRevision", "")?.ToString();
                        if (string.IsNullOrEmpty(issueRevision)) continue;
                        
                        var pcsRefResponse = await _apiService.FetchDataAsync($"plants/{plantId}/issues/rev/{issueRevision}/pcs");
                        var pcsRefData = _deserializer.DeserializeApiResponse(pcsRefResponse, $"plants/{plantId}/issues/rev/{issueRevision}/pcs");
                        
                        if (pcsRefData == null) continue;
                        
                        // Add PlantID and IssueRevision to each record
                        foreach (var pcsRef in pcsRefData)
                        {
                            pcsRef["PlantID"] = plantId;
                            pcsRef["IssueRevision"] = issueRevision;
                            allPCSReferences.Add(pcsRef);
                        }
                    }
                }
                
                if (!allPCSReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No PCS references found";
                    return result;
                }
                
                _logger.LogInformation($"Successfully fetched {allPCSReferences.Count} PCS references from API");
                
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = connection.BeginTransaction();
                
                try
                {
                    // Start ETL run
                    etlRunId = await StartETLRun("REFERENCE", "PCS_REFERENCES", connection, transaction);
                    
                    // Mark existing records as historical
                    string updateSql = "UPDATE PCS_REFERENCES SET IS_CURRENT = 'N' WHERE IS_CURRENT = 'Y'";
                    sqlStatements.Add(updateSql);
                    
                    using (var updateCmd = new OracleCommand(updateSql, connection))
                    {
                        updateCmd.Transaction = transaction;
                        var updated = await updateCmd.ExecuteNonQueryAsync();
                        _logger.LogInformation($"Marked {updated} existing PCS references as historical");
                    }
                    
                    // Insert new records
                    string insertSql = @"
                        INSERT INTO PCS_REFERENCES (
                            PLANT_ID, ISSUE_REVISION, PCS_NAME, PCS_REVISION,
                            USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
                            ETL_RUN_ID, IS_CURRENT, EXTRACTION_DATE
                        ) VALUES (
                            :plantId, :issueRevision, :pcsName, :pcsRevision,
                            :userName, :userEntryTime, :userProtected,
                            :etlRunId, 'Y', SYSDATE
                        )";
                    
                    sqlStatements.Add(insertSql);
                    
                    int recordsLoaded = 0;
                    foreach (var row in allPCSReferences)
                    {
                        using var cmd = new OracleCommand(insertSql, connection);
                        cmd.Transaction = transaction;
                        cmd.Parameters.Add(new OracleParameter("plantId", row.GetValueOrDefault("PlantID", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("issueRevision", row.GetValueOrDefault("IssueRevision", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("pcsName", row.GetValueOrDefault("PCSName", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("pcsRevision", row.GetValueOrDefault("PCSRevision", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("userName", row.GetValueOrDefault("UserName", DBNull.Value)));
                        
                        // Handle UserEntryTime as DateTime
                        var userEntryTime = row.GetValueOrDefault("UserEntryTime", DBNull.Value);
                        if (userEntryTime != DBNull.Value && userEntryTime != null)
                        {
                            if (DateTime.TryParse(userEntryTime.ToString(), out var dateTime))
                            {
                                cmd.Parameters.Add(new OracleParameter("userEntryTime", dateTime));
                            }
                            else
                            {
                                cmd.Parameters.Add(new OracleParameter("userEntryTime", DBNull.Value));
                            }
                        }
                        else
                        {
                            cmd.Parameters.Add(new OracleParameter("userEntryTime", DBNull.Value));
                        }
                        
                        cmd.Parameters.Add(new OracleParameter("userProtected", row.GetValueOrDefault("UserProtected", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("etlRunId", etlRunId));
                        
                        await cmd.ExecuteNonQueryAsync();
                        recordsLoaded++;
                    }
                    
                    // Complete ETL run
                    await CompleteETLRun(etlRunId, "SUCCESS", recordsLoaded, 0, connection, transaction);
                    
                    // Commit transaction
                    await transaction.CommitAsync();
                    _logger.LogInformation("Transaction committed successfully - all PCS references saved");
                    
                    result.Status = "SUCCESS";
                    result.RecordsLoaded = recordsLoaded;
                    result.EndTime = DateTime.Now;
                    result.Message = $"Successfully loaded {recordsLoaded} PCS references";
                    result.SqlStatements = sqlStatements;
                    
                    return result;
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    _logger.LogError(ex, "Error during PCS references ETL - transaction rolled back");
                    
                    if (etlRunId > 0)
                    {
                        await LogETLError(etlRunId, ex, "PCS_REFERENCES");
                    }
                    
                    throw;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load PCS references");
                result.Status = "ERROR";
                result.Message = $"Error: {ex.Message}. No data was modified - transaction was rolled back.";
                result.EndTime = DateTime.Now;
                return result;
            }
        }
        
        public async Task<ETLResult> LoadSCReferences()
        {
            var result = new ETLResult { StartTime = DateTime.Now };
            var sqlStatements = new List<string>();
            int etlRunId = 0;
            
            try
            {
                _logger.LogInformation("Step 1: Fetching SC references data from API...");
                
                // Fetch all plants first
                var plantsResponse = await _apiService.FetchDataAsync("plants");
                var plantsData = _deserializer.DeserializeApiResponse(plantsResponse, "plants");
                
                if (plantsData == null || !plantsData.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No plants found";
                    return result;
                }
                
                var allSCReferences = new List<Dictionary<string, object>>();
                
                // For each plant, fetch its issues first to get issue revisions
                foreach (var plant in plantsData)
                {
                    var plantId = plant.GetValueOrDefault("PlantID", "")?.ToString();
                    if (string.IsNullOrEmpty(plantId)) continue;
                    
                    // Get issues for this plant
                    var issuesResponse = await _apiService.FetchDataAsync($"plants/{plantId}/issues");
                    var issuesData = _deserializer.DeserializeApiResponse(issuesResponse, $"plants/{plantId}/issues");
                    
                    if (issuesData == null) continue;
                    
                    // For each issue revision, get SC references
                    foreach (var issue in issuesData)
                    {
                        var issueRevision = issue.GetValueOrDefault("IssueRevision", "")?.ToString();
                        if (string.IsNullOrEmpty(issueRevision)) continue;
                        
                        var scRefResponse = await _apiService.FetchDataAsync($"plants/{plantId}/issues/rev/{issueRevision}/sc");
                        var scRefData = _deserializer.DeserializeApiResponse(scRefResponse, $"plants/{plantId}/issues/rev/{issueRevision}/sc");
                        
                        if (scRefData == null) continue;
                        
                        // Add PlantID and IssueRevision to each record
                        foreach (var scRef in scRefData)
                        {
                            scRef["PlantID"] = plantId;
                            scRef["IssueRevision"] = issueRevision;
                            allSCReferences.Add(scRef);
                        }
                    }
                }
                
                if (!allSCReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No SC references found";
                    return result;
                }
                
                _logger.LogInformation($"Successfully fetched {allSCReferences.Count} SC references from API");
                
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = connection.BeginTransaction();
                
                try
                {
                    // Start ETL run
                    etlRunId = await StartETLRun("REFERENCE", "SC_REFERENCES", connection, transaction);
                    
                    // Mark existing records as historical
                    string updateSql = "UPDATE SC_REFERENCES SET IS_CURRENT = 'N' WHERE IS_CURRENT = 'Y'";
                    sqlStatements.Add(updateSql);
                    
                    using (var updateCmd = new OracleCommand(updateSql, connection))
                    {
                        updateCmd.Transaction = transaction;
                        var updated = await updateCmd.ExecuteNonQueryAsync();
                        _logger.LogInformation($"Marked {updated} existing SC references as historical");
                    }
                    
                    // Insert new records
                    string insertSql = @"
                        INSERT INTO SC_REFERENCES (
                            PLANT_ID, ISSUE_REVISION, SC_NAME, SC_REVISION,
                            OFFICIAL_REVISION, DELTA,
                            USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
                            ETL_RUN_ID, IS_CURRENT, EXTRACTION_DATE
                        ) VALUES (
                            :plantId, :issueRevision, :scName, :scRevision,
                            :officialRevision, :delta,
                            :userName, :userEntryTime, :userProtected,
                            :etlRunId, 'Y', SYSDATE
                        )";
                    
                    sqlStatements.Add(insertSql);
                    
                    int recordsLoaded = 0;
                    foreach (var row in allSCReferences)
                    {
                        using var cmd = new OracleCommand(insertSql, connection);
                        cmd.Transaction = transaction;
                        cmd.Parameters.Add(new OracleParameter("plantId", row.GetValueOrDefault("PlantID", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("issueRevision", row.GetValueOrDefault("IssueRevision", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("scName", row.GetValueOrDefault("SCName", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("scRevision", row.GetValueOrDefault("SCRevision", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("officialRevision", row.GetValueOrDefault("OfficialRevision", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("delta", row.GetValueOrDefault("Delta", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("userName", row.GetValueOrDefault("UserName", DBNull.Value)));
                        
                        // Handle UserEntryTime as DateTime
                        var userEntryTime = row.GetValueOrDefault("UserEntryTime", DBNull.Value);
                        if (userEntryTime != DBNull.Value && userEntryTime != null)
                        {
                            if (DateTime.TryParse(userEntryTime.ToString(), out var dateTime))
                            {
                                cmd.Parameters.Add(new OracleParameter("userEntryTime", dateTime));
                            }
                            else
                            {
                                cmd.Parameters.Add(new OracleParameter("userEntryTime", DBNull.Value));
                            }
                        }
                        else
                        {
                            cmd.Parameters.Add(new OracleParameter("userEntryTime", DBNull.Value));
                        }
                        
                        cmd.Parameters.Add(new OracleParameter("userProtected", row.GetValueOrDefault("UserProtected", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("etlRunId", etlRunId));
                        
                        await cmd.ExecuteNonQueryAsync();
                        recordsLoaded++;
                    }
                    
                    // Complete ETL run
                    await CompleteETLRun(etlRunId, "SUCCESS", recordsLoaded, 0, connection, transaction);
                    
                    // Commit transaction
                    await transaction.CommitAsync();
                    _logger.LogInformation("Transaction committed successfully - all SC references saved");
                    
                    result.Status = "SUCCESS";
                    result.RecordsLoaded = recordsLoaded;
                    result.EndTime = DateTime.Now;
                    result.Message = $"Successfully loaded {recordsLoaded} SC references";
                    result.SqlStatements = sqlStatements;
                    
                    return result;
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    _logger.LogError(ex, "Error during SC references ETL - transaction rolled back");
                    
                    if (etlRunId > 0)
                    {
                        await LogETLError(etlRunId, ex, "SC_REFERENCES");
                    }
                    
                    throw;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load SC references");
                result.Status = "ERROR";
                result.Message = $"Error: {ex.Message}. No data was modified - transaction was rolled back.";
                result.EndTime = DateTime.Now;
                return result;
            }
        }
        
        public async Task<ETLResult> LoadVSMReferences()
        {
            var result = new ETLResult { StartTime = DateTime.Now };
            var sqlStatements = new List<string>();
            int etlRunId = 0;
            
            try
            {
                _logger.LogInformation("Step 1: Fetching VSM references data from API...");
                
                // Fetch all plants first
                var plantsResponse = await _apiService.FetchDataAsync("plants");
                var plantsData = _deserializer.DeserializeApiResponse(plantsResponse, "plants");
                
                if (plantsData == null || !plantsData.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No plants found";
                    return result;
                }
                
                var allVSMReferences = new List<Dictionary<string, object>>();
                
                // For each plant, fetch its issues first to get issue revisions
                foreach (var plant in plantsData)
                {
                    var plantId = plant.GetValueOrDefault("PlantID", "")?.ToString();
                    if (string.IsNullOrEmpty(plantId)) continue;
                    
                    // Get issues for this plant
                    var issuesResponse = await _apiService.FetchDataAsync($"plants/{plantId}/issues");
                    var issuesData = _deserializer.DeserializeApiResponse(issuesResponse, $"plants/{plantId}/issues");
                    
                    if (issuesData == null) continue;
                    
                    // For each issue revision, get VSM references
                    foreach (var issue in issuesData)
                    {
                        var issueRevision = issue.GetValueOrDefault("IssueRevision", "")?.ToString();
                        if (string.IsNullOrEmpty(issueRevision)) continue;
                        
                        var vsmRefResponse = await _apiService.FetchDataAsync($"plants/{plantId}/issues/rev/{issueRevision}/vsm");
                        var vsmRefData = _deserializer.DeserializeApiResponse(vsmRefResponse, $"plants/{plantId}/issues/rev/{issueRevision}/vsm");
                        
                        if (vsmRefData == null) continue;
                        
                        // Add PlantID and IssueRevision to each record
                        foreach (var vsmRef in vsmRefData)
                        {
                            vsmRef["PlantID"] = plantId;
                            vsmRef["IssueRevision"] = issueRevision;
                            allVSMReferences.Add(vsmRef);
                        }
                    }
                }
                
                if (!allVSMReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No VSM references found";
                    return result;
                }
                
                _logger.LogInformation($"Successfully fetched {allVSMReferences.Count} VSM references from API");
                
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = connection.BeginTransaction();
                
                try
                {
                    // Start ETL run
                    etlRunId = await StartETLRun("REFERENCE", "VSM_REFERENCES", connection, transaction);
                    
                    // Mark existing records as historical
                    string updateSql = "UPDATE VSM_REFERENCES SET IS_CURRENT = 'N' WHERE IS_CURRENT = 'Y'";
                    sqlStatements.Add(updateSql);
                    
                    using (var updateCmd = new OracleCommand(updateSql, connection))
                    {
                        updateCmd.Transaction = transaction;
                        var updated = await updateCmd.ExecuteNonQueryAsync();
                        _logger.LogInformation($"Marked {updated} existing VSM references as historical");
                    }
                    
                    // Insert new records
                    string insertSql = @"
                        INSERT INTO VSM_REFERENCES (
                            PLANT_ID, ISSUE_REVISION, VSM_NAME, VSM_REVISION,
                            OFFICIAL_REVISION, DELTA,
                            USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
                            ETL_RUN_ID, IS_CURRENT, EXTRACTION_DATE
                        ) VALUES (
                            :plantId, :issueRevision, :vsmName, :vsmRevision,
                            :officialRevision, :delta,
                            :userName, :userEntryTime, :userProtected,
                            :etlRunId, 'Y', SYSDATE
                        )";
                    
                    sqlStatements.Add(insertSql);
                    
                    int recordsLoaded = 0;
                    foreach (var row in allVSMReferences)
                    {
                        using var cmd = new OracleCommand(insertSql, connection);
                        cmd.Transaction = transaction;
                        cmd.Parameters.Add(new OracleParameter("plantId", row.GetValueOrDefault("PlantID", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("issueRevision", row.GetValueOrDefault("IssueRevision", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("vsmName", row.GetValueOrDefault("VSMName", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("vsmRevision", row.GetValueOrDefault("VSMRevision", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("officialRevision", row.GetValueOrDefault("OfficialRevision", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("delta", row.GetValueOrDefault("Delta", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("userName", row.GetValueOrDefault("UserName", DBNull.Value)));
                        
                        // Handle UserEntryTime as DateTime
                        var userEntryTime = row.GetValueOrDefault("UserEntryTime", DBNull.Value);
                        if (userEntryTime != DBNull.Value && userEntryTime != null)
                        {
                            if (DateTime.TryParse(userEntryTime.ToString(), out var dateTime))
                            {
                                cmd.Parameters.Add(new OracleParameter("userEntryTime", dateTime));
                            }
                            else
                            {
                                cmd.Parameters.Add(new OracleParameter("userEntryTime", DBNull.Value));
                            }
                        }
                        else
                        {
                            cmd.Parameters.Add(new OracleParameter("userEntryTime", DBNull.Value));
                        }
                        
                        cmd.Parameters.Add(new OracleParameter("userProtected", row.GetValueOrDefault("UserProtected", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("etlRunId", etlRunId));
                        
                        await cmd.ExecuteNonQueryAsync();
                        recordsLoaded++;
                    }
                    
                    // Complete ETL run
                    await CompleteETLRun(etlRunId, "SUCCESS", recordsLoaded, 0, connection, transaction);
                    
                    // Commit transaction
                    await transaction.CommitAsync();
                    _logger.LogInformation("Transaction committed successfully - all VSM references saved");
                    
                    result.Status = "SUCCESS";
                    result.RecordsLoaded = recordsLoaded;
                    result.EndTime = DateTime.Now;
                    result.Message = $"Successfully loaded {recordsLoaded} VSM references";
                    result.SqlStatements = sqlStatements;
                    
                    return result;
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    _logger.LogError(ex, "Error during VSM references ETL - transaction rolled back");
                    
                    if (etlRunId > 0)
                    {
                        await LogETLError(etlRunId, ex, "VSM_REFERENCES");
                    }
                    
                    throw;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load VSM references");
                result.Status = "ERROR";
                result.Message = $"Error: {ex.Message}. No data was modified - transaction was rolled back.";
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        // ===================== PLANT LOADER MANAGEMENT =====================
        
        public async Task<bool> CreatePlantLoaderTable()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                // Check if table exists
                string checkSql = "SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = 'ETL_PLANT_LOADER'";
                using var checkCmd = new OracleCommand(checkSql, connection);
                var exists = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());
                
                if (exists > 0)
                {
                    _logger.LogInformation("ETL_PLANT_LOADER table already exists");
                    return true;
                }
                
                // Create table
                string createSql = @"
                    CREATE TABLE ETL_PLANT_LOADER (
                        PLANT_ID           VARCHAR2(50) NOT NULL,
                        PLANT_NAME         VARCHAR2(200),
                        IS_ACTIVE          CHAR(1) DEFAULT 'Y' CHECK (IS_ACTIVE IN ('Y', 'N')),
                        LOAD_PRIORITY      NUMBER DEFAULT 100,
                        NOTES              VARCHAR2(500),
                        CREATED_DATE       DATE DEFAULT SYSDATE,
                        CREATED_BY         VARCHAR2(100) DEFAULT USER,
                        MODIFIED_DATE      DATE DEFAULT SYSDATE,
                        MODIFIED_BY        VARCHAR2(100) DEFAULT USER,
                        CONSTRAINT PK_ETL_PLANT_LOADER PRIMARY KEY (PLANT_ID)
                    )";
                
                using var createCmd = new OracleCommand(createSql, connection);
                await createCmd.ExecuteNonQueryAsync();
                
                // Create index
                string indexSql = "CREATE INDEX IDX_ETL_PLANT_ACTIVE ON ETL_PLANT_LOADER(IS_ACTIVE, LOAD_PRIORITY)";
                using var indexCmd = new OracleCommand(indexSql, connection);
                await indexCmd.ExecuteNonQueryAsync();
                
                _logger.LogInformation("Successfully created ETL_PLANT_LOADER table");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating ETL_PLANT_LOADER table");
                return false;
            }
        }
        
        public async Task<List<Dictionary<string, object>>> GetAllPlants()
        {
            var plants = new List<Dictionary<string, object>>();
            
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                string sql = @"
                    SELECT PLANT_ID, PLANT_NAME, LONG_DESCRIPTION 
                    FROM PLANTS 
                    WHERE IS_CURRENT = 'Y' 
                    ORDER BY PLANT_NAME";
                
                using var cmd = new OracleCommand(sql, connection);
                using var reader = await cmd.ExecuteReaderAsync();
                
                while (await reader.ReadAsync())
                {
                    plants.Add(new Dictionary<string, object>
                    {
                        ["PlantId"] = reader.GetString(0),
                        ["PlantName"] = reader.IsDBNull(1) ? "" : reader.GetString(1),
                        ["LongDescription"] = reader.IsDBNull(2) ? "" : reader.GetString(2)
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching all plants");
            }
            
            return plants;
        }
        
        public async Task<List<PlantLoaderConfig>> GetPlantLoaderConfigs()
        {
            var configs = new List<PlantLoaderConfig>();
            
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                string sql = @"
                    SELECT 
                        L.PLANT_ID,
                        L.PLANT_NAME,
                        L.IS_ACTIVE,
                        L.LOAD_PRIORITY,
                        L.NOTES,
                        P.LONG_DESCRIPTION,
                        P.OPERATOR_ID
                    FROM ETL_PLANT_LOADER L
                    LEFT JOIN PLANTS P ON L.PLANT_ID = P.PLANT_ID AND P.IS_CURRENT = 'Y'
                    ORDER BY L.LOAD_PRIORITY, L.PLANT_ID";
                
                using var cmd = new OracleCommand(sql, connection);
                using var reader = await cmd.ExecuteReaderAsync();
                
                while (await reader.ReadAsync())
                {
                    configs.Add(new PlantLoaderConfig
                    {
                        PlantId = reader.GetString(0),
                        PlantName = reader.IsDBNull(1) ? "" : reader.GetString(1),
                        IsActive = reader.GetString(2) == "Y",
                        LoadPriority = reader.IsDBNull(3) ? 100 : reader.GetInt32(3),
                        Notes = reader.IsDBNull(4) ? "" : reader.GetString(4),
                        LongDescription = reader.IsDBNull(5) ? "" : reader.GetString(5),
                        OperatorId = reader.IsDBNull(6) ? "" : reader.GetString(6)
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching plant loader configs");
            }
            
            return configs;
        }
        
        public async Task<bool> AddPlantToLoader(string plantId, string plantName, string notes = "")
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                string sql = @"
                    INSERT INTO ETL_PLANT_LOADER (PLANT_ID, PLANT_NAME, NOTES, IS_ACTIVE)
                    VALUES (:plantId, :plantName, :notes, 'Y')";
                
                using var cmd = new OracleCommand(sql, connection);
                cmd.Parameters.Add(new OracleParameter("plantId", plantId));
                cmd.Parameters.Add(new OracleParameter("plantName", plantName));
                cmd.Parameters.Add(new OracleParameter("notes", notes ?? ""));
                
                await cmd.ExecuteNonQueryAsync();
                _logger.LogInformation($"Added plant {plantId} to loader table");
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error adding plant {plantId} to loader");
                return false;
            }
        }
        
        public async Task<bool> TogglePlantActive(string plantId, bool isActive)
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                string sql = @"
                    UPDATE ETL_PLANT_LOADER 
                    SET IS_ACTIVE = :isActive, MODIFIED_DATE = SYSDATE
                    WHERE PLANT_ID = :plantId";
                
                using var cmd = new OracleCommand(sql, connection);
                cmd.Parameters.Add(new OracleParameter("isActive", isActive ? "Y" : "N"));
                cmd.Parameters.Add(new OracleParameter("plantId", plantId));
                
                var rows = await cmd.ExecuteNonQueryAsync();
                _logger.LogInformation($"Toggled plant {plantId} active status to {isActive}");
                return rows > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error toggling plant {plantId} active status");
                return false;
            }
        }
        
        public async Task<bool> RemovePlantFromLoader(string plantId)
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                string sql = "DELETE FROM ETL_PLANT_LOADER WHERE PLANT_ID = :plantId";
                
                using var cmd = new OracleCommand(sql, connection);
                cmd.Parameters.Add(new OracleParameter("plantId", plantId));
                
                var rows = await cmd.ExecuteNonQueryAsync();
                _logger.LogInformation($"Removed plant {plantId} from loader table");
                return rows > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error removing plant {plantId} from loader");
                return false;
            }
        }
        
        // New efficient version that only loads selected plants
        public async Task<ETLResult> LoadPCSReferencesForSelectedPlants()
        {
            var result = new ETLResult { StartTime = DateTime.Now };
            var sqlStatements = new List<string>();
            int etlRunId = 0;
            
            try
            {
                _logger.LogInformation("Step 1: Fetching active plants from loader table...");
                
                // Get active plants from loader table
                var activePlants = await GetPlantLoaderConfigs();
                var activePlantIds = activePlants.Where(p => p.IsActive).Select(p => p.PlantId).ToList();
                
                if (!activePlantIds.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No active plants selected in ETL_PLANT_LOADER table";
                    return result;
                }
                
                _logger.LogInformation($"Loading PCS references for {activePlantIds.Count} selected plants: {string.Join(", ", activePlantIds)}");
                
                var allPCSReferences = new List<Dictionary<string, object>>();
                int apiCallCount = 0;
                int plantIterations = 0;
                int issueIterations = 0;
                
                // Only process selected plants
                foreach (var plantId in activePlantIds)
                {
                    plantIterations++;
                    
                    // Get issues for this plant
                    var issuesResponse = await _apiService.FetchDataAsync($"plants/{plantId}/issues");
                    apiCallCount++;
                    var issuesData = _deserializer.DeserializeApiResponse(issuesResponse, $"plants/{plantId}/issues");
                    
                    if (issuesData == null || !issuesData.Any()) continue;
                    
                    _logger.LogInformation($"Processing {issuesData.Count} issues for plant {plantId}");
                    
                    // For each issue revision, get PCS references
                    foreach (var issue in issuesData)
                    {
                        issueIterations++;
                        var issueRevision = issue.GetValueOrDefault("IssueRevision", "")?.ToString();
                        if (string.IsNullOrEmpty(issueRevision)) continue;
                        
                        var pcsRefResponse = await _apiService.FetchDataAsync($"plants/{plantId}/issues/rev/{issueRevision}/pcs");
                        apiCallCount++;
                        var pcsRefData = _deserializer.DeserializeApiResponse(pcsRefResponse, $"plants/{plantId}/issues/rev/{issueRevision}/pcs");
                        
                        if (pcsRefData == null || !pcsRefData.Any()) continue;
                        
                        // Add PlantID and IssueRevision to each record
                        foreach (var pcsRef in pcsRefData)
                        {
                            pcsRef["PlantID"] = plantId;
                            pcsRef["IssueRevision"] = issueRevision;
                            allPCSReferences.Add(pcsRef);
                        }
                    }
                }
                
                if (!allPCSReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = $"No PCS references found for selected plants";
                    return result;
                }
                
                _logger.LogInformation($"Successfully fetched {allPCSReferences.Count} PCS references from API");
                
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                using var transaction = connection.BeginTransaction();
                
                try
                {
                    // Start ETL run
                    etlRunId = await StartETLRun("REFERENCE", "PCS_REFERENCES", connection, transaction);
                    
                    // Only mark existing records as historical for selected plants
                    string updateSql = $@"
                        UPDATE PCS_REFERENCES 
                        SET IS_CURRENT = 'N' 
                        WHERE IS_CURRENT = 'Y' 
                        AND PLANT_ID IN ({string.Join(",", activePlantIds.Select(id => $"'{id}'"))})";
                    sqlStatements.Add(updateSql);
                    
                    using (var updateCmd = new OracleCommand(updateSql, connection))
                    {
                        updateCmd.Transaction = transaction;
                        var updated = await updateCmd.ExecuteNonQueryAsync();
                        _logger.LogInformation($"Marked {updated} existing PCS references as historical for selected plants");
                    }
                    
                    // Insert new records
                    string insertSql = @"
                        INSERT INTO PCS_REFERENCES (
                            PLANT_ID, ISSUE_REVISION, PCS_NAME, PCS_REVISION,
                            USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
                            ETL_RUN_ID, IS_CURRENT, EXTRACTION_DATE
                        ) VALUES (
                            :plantId, :issueRevision, :pcsName, :pcsRevision,
                            :userName, :userEntryTime, :userProtected,
                            :etlRunId, 'Y', SYSDATE
                        )";
                    
                    sqlStatements.Add(insertSql);
                    
                    int recordsLoaded = 0;
                    foreach (var row in allPCSReferences)
                    {
                        using var cmd = new OracleCommand(insertSql, connection);
                        cmd.Transaction = transaction;
                        
                        // Ensure we have valid values for required fields
                        var plantId = row.GetValueOrDefault("PlantID", "")?.ToString();
                        var issueRevision = row.GetValueOrDefault("IssueRevision", "")?.ToString();
                        var pcsName = row.GetValueOrDefault("PCSName", row.GetValueOrDefault("Name", ""))?.ToString();
                        var pcsRevision = row.GetValueOrDefault("PCSRevision", row.GetValueOrDefault("Revision", ""))?.ToString();
                        
                        // Skip if essential fields are missing
                        if (string.IsNullOrEmpty(plantId) || string.IsNullOrEmpty(issueRevision))
                        {
                            _logger.LogWarning($"Skipping record with missing PlantID or IssueRevision");
                            continue;
                        }
                        
                        // Use default values if PCS fields are missing
                        if (string.IsNullOrEmpty(pcsName)) pcsName = "UNKNOWN";
                        if (string.IsNullOrEmpty(pcsRevision)) pcsRevision = "0";
                        
                        cmd.Parameters.Add(new OracleParameter("plantId", plantId));
                        cmd.Parameters.Add(new OracleParameter("issueRevision", issueRevision));
                        cmd.Parameters.Add(new OracleParameter("pcsName", pcsName));
                        cmd.Parameters.Add(new OracleParameter("pcsRevision", pcsRevision));
                        cmd.Parameters.Add(new OracleParameter("userName", row.GetValueOrDefault("UserName", DBNull.Value)));
                        
                        // Handle UserEntryTime as DateTime
                        var userEntryTime = row.GetValueOrDefault("UserEntryTime", DBNull.Value);
                        if (userEntryTime != DBNull.Value && userEntryTime != null)
                        {
                            if (DateTime.TryParse(userEntryTime.ToString(), out var dateTime))
                            {
                                cmd.Parameters.Add(new OracleParameter("userEntryTime", dateTime));
                            }
                            else
                            {
                                cmd.Parameters.Add(new OracleParameter("userEntryTime", DBNull.Value));
                            }
                        }
                        else
                        {
                            cmd.Parameters.Add(new OracleParameter("userEntryTime", DBNull.Value));
                        }
                        
                        cmd.Parameters.Add(new OracleParameter("userProtected", row.GetValueOrDefault("UserProtected", DBNull.Value)));
                        cmd.Parameters.Add(new OracleParameter("etlRunId", etlRunId));
                        
                        await cmd.ExecuteNonQueryAsync();
                        recordsLoaded++;
                    }
                    
                    // Complete ETL run
                    await CompleteETLRun(etlRunId, "SUCCESS", recordsLoaded, 0, connection, transaction);
                    
                    // Commit transaction
                    await transaction.CommitAsync();
                    _logger.LogInformation("Transaction committed successfully - all PCS references saved");
                    
                    result.Status = "SUCCESS";
                    result.RecordsLoaded = recordsLoaded;
                    result.EndTime = DateTime.Now;
                    result.ApiCallCount = apiCallCount;
                    result.PlantIterations = plantIterations;
                    result.IssueIterations = issueIterations;
                    result.Message = $"Successfully loaded {recordsLoaded} PCS references for {activePlantIds.Count} selected plants. API Calls: {apiCallCount}, Time: {result.FormattedDuration}";
                    result.SqlStatements = sqlStatements;
                    
                    return result;
                }
                catch (Exception ex)
                {
                    await transaction.RollbackAsync();
                    _logger.LogError(ex, "Error during PCS references ETL - transaction rolled back");
                    
                    if (etlRunId > 0)
                    {
                        await LogETLError(etlRunId, ex, "PCS_REFERENCES");
                    }
                    
                    throw;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to load PCS references");
                result.Status = "ERROR";
                result.Message = $"Error: {ex.Message}. No data was modified - transaction was rolled back.";
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        public async Task<Dictionary<string, TableStatus>> GetTableStatuses()
        {
            var statuses = new Dictionary<string, TableStatus>();
            
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();

                var tables = new[] { "OPERATORS", "PLANTS", "ISSUES", "PCS_REFERENCES", "SC_REFERENCES", "VSM_REFERENCES" };
                
                foreach (var tableName in tables)
                {
                    var status = new TableStatus { TableName = tableName };
                    
                    // Check if table exists
                    string checkSql = @"
                        SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = :tableName";
                    
                    using (var checkCmd = new OracleCommand(checkSql, connection))
                    {
                        checkCmd.Parameters.Add(new OracleParameter("tableName", tableName));
                        var exists = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());
                        
                        if (exists > 0)
                        {
                            status.Exists = true;
                            
                            // Get record count
                            string countSql = $"SELECT COUNT(*) FROM {tableName} WHERE IS_CURRENT = 'Y'";
                            using (var countCmd = new OracleCommand(countSql, connection))
                            {
                                status.RecordCount = Convert.ToInt32(await countCmd.ExecuteScalarAsync());
                            }
                            
                            // Get last load time
                            string lastLoadSql = $@"
                                SELECT MAX(EXTRACTION_DATE) 
                                FROM {tableName} 
                                WHERE IS_CURRENT = 'Y'";
                            
                            using (var lastLoadCmd = new OracleCommand(lastLoadSql, connection))
                            {
                                var lastLoad = await lastLoadCmd.ExecuteScalarAsync();
                                if (lastLoad != null && lastLoad != DBNull.Value)
                                {
                                    status.LastLoadTime = Convert.ToDateTime(lastLoad);
                                }
                            }
                        }
                    }
                    
                    statuses[tableName] = status;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get table statuses");
            }
            
            return statuses;
        }

        public async Task<List<ETLRunHistory>> GetETLHistory(int limit = 10)
        {
            var history = new List<ETLRunHistory>();
            
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                string sql = @"
                    SELECT ETL_RUN_ID, RUN_DATE, RUN_TYPE, STATUS, 
                           RECORDS_LOADED, ERROR_COUNT, COMMENTS
                    FROM ETL_CONTROL
                    ORDER BY ETL_RUN_ID DESC
                    FETCH FIRST :limit ROWS ONLY";
                
                using var cmd = new OracleCommand(sql, connection);
                cmd.Parameters.Add(new OracleParameter("limit", limit));
                
                using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    history.Add(new ETLRunHistory
                    {
                        RunId = reader.GetInt32(0),
                        RunDate = reader.GetDateTime(1),
                        RunType = reader.GetString(2),
                        Status = reader.GetString(3),
                        RecordsLoaded = reader.IsDBNull(4) ? 0 : reader.GetInt32(4),
                        ErrorCount = reader.IsDBNull(5) ? 0 : reader.GetInt32(5),
                        Comments = reader.IsDBNull(6) ? null : reader.GetString(6)
                    });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get ETL history");
            }
            
            return history;
        }

        private async Task<int> StartETLRun(string runType, string endpoint, OracleConnection? connection = null, OracleTransaction? transaction = null)
        {
            bool ownConnection = connection == null;
            if (ownConnection)
            {
                connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
            }
            
            string sql = @"
                INSERT INTO ETL_CONTROL 
                (RUN_TYPE, STATUS, START_TIME, COMMENTS)
                VALUES (:runType, 'RUNNING', SYSDATE, :comments)
                RETURNING ETL_RUN_ID INTO :etlRunId";
            
            using var cmd = new OracleCommand(sql, connection);
            if (transaction != null) cmd.Transaction = transaction;
            cmd.Parameters.Add(new OracleParameter("runType", runType));
            cmd.Parameters.Add(new OracleParameter("comments", $"Loading {endpoint}"));
            
            var etlRunIdParam = new OracleParameter("etlRunId", OracleDbType.Int32)
            {
                Direction = ParameterDirection.Output
            };
            cmd.Parameters.Add(etlRunIdParam);
            
            await cmd.ExecuteNonQueryAsync();
            
            var runId = Convert.ToInt32(etlRunIdParam.Value.ToString());
            
            if (ownConnection)
            {
                connection.Dispose();
            }
            
            return runId;
        }

        private async Task CompleteETLRun(int etlRunId, string status, int recordsLoaded, int errorCount, OracleConnection? connection = null, OracleTransaction? transaction = null)
        {
            bool ownConnection = connection == null;
            if (ownConnection)
            {
                connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
            }
            
            string sql = @"
                UPDATE ETL_CONTROL
                SET STATUS = :status,
                    RECORDS_LOADED = :recordsLoaded,
                    ERROR_COUNT = :errorCount,
                    END_TIME = SYSDATE
                WHERE ETL_RUN_ID = :etlRunId";
            
            using var cmd = new OracleCommand(sql, connection);
            if (transaction != null) cmd.Transaction = transaction;
            cmd.Parameters.Add(new OracleParameter("status", status));
            cmd.Parameters.Add(new OracleParameter("recordsLoaded", recordsLoaded));
            cmd.Parameters.Add(new OracleParameter("errorCount", errorCount));
            cmd.Parameters.Add(new OracleParameter("etlRunId", etlRunId));
            
            await cmd.ExecuteNonQueryAsync();
            
            // Clean up old ETL history - keep only last 10 runs
            // Industry standard: Keep recent history for troubleshooting but prevent unbounded growth
            string cleanupSql = @"
                DELETE FROM ETL_CONTROL 
                WHERE ETL_RUN_ID NOT IN (
                    SELECT ETL_RUN_ID FROM (
                        SELECT ETL_RUN_ID 
                        FROM ETL_CONTROL 
                        ORDER BY ETL_RUN_ID DESC
                        FETCH FIRST 10 ROWS ONLY
                    ) RECENT_RUNS
                )";
            
            using (var cleanupCmd = new OracleCommand(cleanupSql, connection))
            {
                if (transaction != null) cleanupCmd.Transaction = transaction;
                try
                {
                    var deleted = await cleanupCmd.ExecuteNonQueryAsync();
                    if (deleted > 0)
                    {
                        _logger.LogInformation($"Cleaned up {deleted} old ETL history records");
                    }
                }
                catch (Exception ex)
                {
                    // Don't fail the ETL if cleanup fails
                    _logger.LogWarning(ex, "Failed to clean up old ETL history");
                }
            }
            
            if (ownConnection)
            {
                connection.Dispose();
            }
        }
        
        private async Task LogETLError(int etlRunId, Exception ex, string endpoint)
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                string sql = @"
                    INSERT INTO ETL_ERROR_LOG 
                    (ETL_RUN_ID, ERROR_TYPE, ERROR_MESSAGE, STACK_TRACE, ENDPOINT_NAME)
                    VALUES (:etlRunId, :errorType, :errorMessage, :stackTrace, :endpoint)";
                
                using var cmd = new OracleCommand(sql, connection);
                cmd.Parameters.Add(new OracleParameter("etlRunId", etlRunId));
                cmd.Parameters.Add(new OracleParameter("errorType", ex.GetType().Name));
                cmd.Parameters.Add(new OracleParameter("errorMessage", ex.Message));
                cmd.Parameters.Add(new OracleParameter("stackTrace", ex.StackTrace ?? "No stack trace"));
                cmd.Parameters.Add(new OracleParameter("endpoint", endpoint));
                
                await cmd.ExecuteNonQueryAsync();
            }
            catch (Exception logEx)
            {
                _logger.LogError(logEx, "Failed to log error to ETL_ERROR_LOG");
            }
        }

        public ETLSqlPreview GetLoadOperatorsSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load Operators - SQL Operations",
                Description = "This process uses SCD Type 2 (Slowly Changing Dimension) to maintain historical data:",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Fetch Data from API",
                        Description = "Call TR2000 API endpoint: GET https://equinor.pipespec-api.presight.com/operators",
                        SqlStatement = "-- No SQL: This step fetches data from the API\n-- Returns JSON with operator list"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "Mark Existing Records as Historical",
                        Description = "Sets IS_CURRENT flag to 'N' for all existing records, preserving them as history",
                        SqlStatement = @"UPDATE OPERATORS 
SET IS_CURRENT = 'N' 
WHERE IS_CURRENT = 'Y'"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Insert New Records",
                        Description = "Inserts fresh data from API with IS_CURRENT = 'Y' and current timestamp",
                        SqlStatement = @"INSERT INTO OPERATORS 
(OPERATOR_ID, OPERATOR_NAME, ETL_RUN_ID, IS_CURRENT, EXTRACTION_DATE)
VALUES (:operatorId, :operatorName, :etlRunId, 'Y', SYSDATE)

-- Example with actual values:
-- INSERT INTO OPERATORS 
-- VALUES (1, 'Equinor Europe', 123, 'Y', '2025-08-16 10:30:00')"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Log ETL Run",
                        Description = "Records the ETL execution details for audit trail",
                        SqlStatement = @"UPDATE ETL_CONTROL
SET STATUS = 'SUCCESS',
    RECORDS_LOADED = 8,
    END_TIME = SYSDATE
WHERE ETL_RUN_ID = :etlRunId"
                    }
                }
            };
        }

        public ETLSqlPreview GetLoadPlantsSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load Plants - SQL Operations",
                Description = "Loads plant data with full operator details and maintains history:",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Fetch Data from API",
                        Description = "Call TR2000 API endpoint: GET https://equinor.pipespec-api.presight.com/plants",
                        SqlStatement = "-- No SQL: This step fetches data from the API\n-- Returns JSON with all plants and their details"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "Mark Existing Records as Historical",
                        Description = "Preserves existing data by setting IS_CURRENT to 'N'",
                        SqlStatement = @"UPDATE PLANTS 
SET IS_CURRENT = 'N' 
WHERE IS_CURRENT = 'Y'"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Insert New Plant Records",
                        Description = "Inserts complete plant information including areas and project details",
                        SqlStatement = @"INSERT INTO PLANTS 
(PLANT_ID, OPERATOR_ID, OPERATOR_NAME, SHORT_DESCRIPTION, PROJECT, 
 LONG_DESCRIPTION, COMMON_LIB_PLANT_CODE, INITIAL_REVISION, 
 AREA_ID, AREA, ETL_RUN_ID, IS_CURRENT, EXTRACTION_DATE)
VALUES (:plantId, :operatorId, :operatorName, :shortDesc, :project,
        :longDesc, :commonLib, :initRev, :areaId, :area, 
        :etlRunId, 'Y', SYSDATE)

-- Example with actual values:
-- INSERT INTO PLANTS 
-- VALUES ('34', 1, 'Equinor Europe', 'Gullfaks', 'GFA',
--         'Gullfaks A', 'GFA', '0', 1, 'North Sea',
--         123, 'Y', '2025-08-16 10:30:00')"
                    }
                }
            };
        }

        public async Task<bool> DropAllTables()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var tables = new[] 
                { 
                    "PCS_REFERENCES",
                    "ISSUES",
                    "PLANTS",
                    "OPERATORS",
                    "ETL_ERROR_LOG",
                    "ETL_ENDPOINT_LOG",
                    "ETL_CONTROL"
                };
                
                foreach (var tableName in tables)
                {
                    try
                    {
                        string sql = $"DROP TABLE {tableName} CASCADE CONSTRAINTS";
                        using var cmd = new OracleCommand(sql, connection);
                        await cmd.ExecuteNonQueryAsync();
                        _logger.LogInformation($"Dropped table {tableName}");
                    }
                    catch (OracleException ex) when (ex.Number == 942) // Table doesn't exist
                    {
                        _logger.LogInformation($"Table {tableName} doesn't exist, skipping");
                    }
                }
                
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to drop tables");
                return false;
            }
        }
    }

    public class ETLResult
    {
        public string Status { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
        public int RecordsLoaded { get; set; }
        public int ErrorCount { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public string EndpointName { get; set; } = string.Empty;
        public List<string> SqlStatements { get; set; } = new List<string>();
        
        // Performance Metrics
        public int ApiCallCount { get; set; }
        public int PlantIterations { get; set; }
        public int IssueIterations { get; set; }
        public double TotalSeconds => EndTime > StartTime ? (EndTime - StartTime).TotalSeconds : 0;
        public double RecordsPerSecond => TotalSeconds > 0 ? RecordsLoaded / TotalSeconds : 0;
        public string FormattedDuration => TotalSeconds > 0 ? $"{TotalSeconds:F2}s" : "N/A";
    }

    public class TableStatus
    {
        public string TableName { get; set; } = string.Empty;
        public bool Exists { get; set; }
        public int RecordCount { get; set; }
        public DateTime? LastLoadTime { get; set; }
    }
    
    public class PlantLoaderConfig
    {
        public string PlantId { get; set; } = string.Empty;
        public string PlantName { get; set; } = string.Empty;
        public bool IsActive { get; set; }
        public int LoadPriority { get; set; }
        public string Notes { get; set; } = string.Empty;
        public string LongDescription { get; set; } = string.Empty;
        public string OperatorId { get; set; } = string.Empty;
    }

    public class ETLRunHistory
    {
        public int RunId { get; set; }
        public DateTime RunDate { get; set; }
        public string RunType { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public int RecordsLoaded { get; set; }
        public int ErrorCount { get; set; }
        public string? Comments { get; set; }
    }

    public class ETLSqlPreview
    {
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public List<ETLStep> Steps { get; set; } = new List<ETLStep>();
    }

    public class ETLStep
    {
        public int StepNumber { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string SqlStatement { get; set; } = string.Empty;
    }
}

public static class DictionaryExtensions
{
    public static object GetValueOrDefault(this Dictionary<string, object> dict, string key, object defaultValue)
    {
        return dict.TryGetValue(key, out var value) ? value ?? defaultValue : defaultValue;
    }
}