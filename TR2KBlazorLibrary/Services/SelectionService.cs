using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Oracle.ManagedDataAccess.Client;
using TR2KBlazorLibrary.Models;

namespace TR2KBlazorLibrary.Logic.Services
{
    public class SelectionService
    {
        private readonly string _connectionString;
        private readonly ILogger<SelectionService> _logger;

        public SelectionService(IConfiguration configuration, ILogger<SelectionService> logger)
        {
            _connectionString = configuration.GetConnectionString("OracleConnection") 
                ?? throw new InvalidOperationException("Oracle connection string not configured");
            _logger = logger;
        }

        /// <summary>
        /// Get all active selections from SELECTION_LOADER table
        /// </summary>
        public async Task<List<SelectionModel>> GetActiveSelectionsAsync()
        {
            const string sql = @"
                SELECT 
                    selection_id AS SelectionId,
                    plant_id AS PlantId,
                    issue_revision AS IssueRevision,
                    is_active AS IsActiveChar,
                    selected_by AS SelectedBy,
                    selection_date AS SelectionDate,
                    last_etl_run AS LastEtlRun,
                    etl_status AS EtlStatus
                FROM SELECTION_LOADER
                WHERE is_active = 'Y'
                ORDER BY plant_id, issue_revision";

            using var connection = new OracleConnection(_connectionString);
            var results = await connection.QueryAsync<SelectionModel>(sql);
            
            // Convert char to bool for IsActive
            foreach (var result in results)
            {
                result.IsActive = result.IsActiveChar == "Y";
            }
            
            return results.ToList();
        }

        /// <summary>
        /// Save plant selections (without specific issues)
        /// </summary>
        public async Task SavePlantSelectionsAsync(List<string> plantIds)
        {
            if (!plantIds.Any() || plantIds.Count > 10)
            {
                throw new ArgumentException("Must select between 1 and 10 plants");
            }

            using var connection = new OracleConnection(_connectionString);
            await connection.OpenAsync();
            using var transaction = connection.BeginTransaction();

            try
            {
                // First, deactivate existing plant-only selections
                const string deactivateSql = @"
                    UPDATE SELECTION_LOADER 
                    SET is_active = 'N' 
                    WHERE issue_revision IS NULL 
                    AND is_active = 'Y'";
                
                await connection.ExecuteAsync(deactivateSql, transaction: transaction);

                // Insert new plant selections
                const string insertSql = @"
                    MERGE INTO SELECTION_LOADER tgt
                    USING (SELECT :plantId AS plant_id FROM dual) src
                    ON (tgt.plant_id = src.plant_id AND tgt.issue_revision IS NULL)
                    WHEN MATCHED THEN
                        UPDATE SET 
                            is_active = 'Y',
                            selection_date = SYSDATE,
                            selected_by = USER
                    WHEN NOT MATCHED THEN
                        INSERT (plant_id, is_active, selected_by, selection_date)
                        VALUES (src.plant_id, 'Y', USER, SYSDATE)";

                foreach (var plantId in plantIds)
                {
                    await connection.ExecuteAsync(insertSql, new { plantId }, transaction: transaction);
                }

                await transaction.CommitAsync();
                _logger.LogInformation($"Saved {plantIds.Count} plant selections");
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                _logger.LogError(ex, "Failed to save plant selections");
                throw;
            }
        }

        /// <summary>
        /// Save issue selections for specific plants
        /// </summary>
        public async Task SaveIssueSelectionsAsync(List<SelectionModel> selections)
        {
            if (!selections.Any())
            {
                throw new ArgumentException("No selections provided");
            }

            using var connection = new OracleConnection(_connectionString);
            await connection.OpenAsync();
            using var transaction = connection.BeginTransaction();

            try
            {
                // Insert or update issue selections
                const string mergeSql = @"
                    MERGE INTO SELECTION_LOADER tgt
                    USING (SELECT :plantId AS plant_id, :issueRevision AS issue_revision FROM dual) src
                    ON (tgt.plant_id = src.plant_id AND tgt.issue_revision = src.issue_revision)
                    WHEN MATCHED THEN
                        UPDATE SET 
                            is_active = 'Y',
                            selection_date = SYSDATE,
                            selected_by = USER
                    WHEN NOT MATCHED THEN
                        INSERT (plant_id, issue_revision, is_active, selected_by, selection_date)
                        VALUES (src.plant_id, src.issue_revision, 'Y', USER, SYSDATE)";

                foreach (var selection in selections)
                {
                    await connection.ExecuteAsync(mergeSql, 
                        new { plantId = selection.PlantId, issueRevision = selection.IssueRevision }, 
                        transaction: transaction);
                }

                await transaction.CommitAsync();
                _logger.LogInformation($"Saved {selections.Count} issue selections");
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                _logger.LogError(ex, "Failed to save issue selections");
                throw;
            }
        }

        /// <summary>
        /// Remove a selection by ID
        /// </summary>
        public async Task RemoveSelectionAsync(int selectionId)
        {
            const string sql = @"
                UPDATE SELECTION_LOADER 
                SET is_active = 'N' 
                WHERE selection_id = :selectionId";

            using var connection = new OracleConnection(_connectionString);
            var rowsAffected = await connection.ExecuteAsync(sql, new { selectionId });
            
            if (rowsAffected > 0)
            {
                _logger.LogInformation($"Removed selection {selectionId}");
            }
        }

        /// <summary>
        /// Clear all active selections
        /// </summary>
        public async Task ClearAllSelectionsAsync()
        {
            const string sql = @"
                UPDATE SELECTION_LOADER 
                SET is_active = 'N' 
                WHERE is_active = 'Y'";

            using var connection = new OracleConnection(_connectionString);
            var rowsAffected = await connection.ExecuteAsync(sql);
            
            _logger.LogInformation($"Cleared {rowsAffected} active selections");
        }

        /// <summary>
        /// Update ETL status for a selection
        /// </summary>
        public async Task UpdateEtlStatusAsync(int selectionId, string status)
        {
            const string sql = @"
                UPDATE SELECTION_LOADER 
                SET 
                    last_etl_run = SYSTIMESTAMP,
                    etl_status = :status
                WHERE selection_id = :selectionId";

            using var connection = new OracleConnection(_connectionString);
            await connection.ExecuteAsync(sql, new { selectionId, status });
        }

        /// <summary>
        /// Get distinct active plant IDs
        /// </summary>
        public async Task<List<string>> GetActiveDistinctPlantIdsAsync()
        {
            const string sql = @"
                SELECT DISTINCT plant_id 
                FROM SELECTION_LOADER 
                WHERE is_active = 'Y'
                ORDER BY plant_id";

            using var connection = new OracleConnection(_connectionString);
            var results = await connection.QueryAsync<string>(sql);
            return results.ToList();
        }

        /// <summary>
        /// Check if cascade delete is needed when removing a plant
        /// </summary>
        public async Task<int> CascadeDeletePlantSelectionsAsync(string plantId)
        {
            const string sql = @"
                UPDATE SELECTION_LOADER 
                SET is_active = 'N' 
                WHERE plant_id = :plantId 
                AND is_active = 'Y'";

            using var connection = new OracleConnection(_connectionString);
            var rowsAffected = await connection.ExecuteAsync(sql, new { plantId });
            
            if (rowsAffected > 0)
            {
                _logger.LogInformation($"Cascade deleted {rowsAffected} selections for plant {plantId}");
            }
            
            return rowsAffected;
        }

        /// <summary>
        /// Get all plants from database (PLANTS table)
        /// </summary>
        public async Task<List<PlantModel>> GetPlantsFromDatabaseAsync()
        {
            const string sql = @"
                SELECT 
                    plant_id AS PlantId,
                    short_description AS PlantName,
                    long_description AS PlantDescription,
                    area AS Country,
                    is_valid AS IsValidChar
                FROM PLANTS
                WHERE is_valid = 'Y'
                ORDER BY plant_id";

            using var connection = new OracleConnection(_connectionString);
            var results = await connection.QueryAsync<PlantModel>(sql);
            
            // Convert char to bool for IsValid
            foreach (var result in results)
            {
                result.IsValid = result.IsValidChar == "Y";
            }
            
            return results.ToList();
        }

        /// <summary>
        /// Get issues for selected plants from database (ISSUES table)
        /// </summary>
        public async Task<List<IssueModel>> GetIssuesFromDatabaseAsync(List<string> plantIds)
        {
            if (!plantIds.Any())
            {
                return new List<IssueModel>();
            }

            const string sql = @"
                SELECT 
                    issue_id AS IssueId,
                    plant_id AS PlantId,
                    issue_revision AS IssueRevision,
                    issue_name AS IssueName,
                    issue_type AS IssueType,
                    issue_status AS IssueStatus,
                    is_valid AS IsValidChar
                FROM ISSUES
                WHERE plant_id IN :plantIds
                AND is_valid = 'Y'
                ORDER BY plant_id, issue_revision";

            using var connection = new OracleConnection(_connectionString);
            var results = await connection.QueryAsync<IssueModel>(sql, new { plantIds });
            
            // Convert char to bool for IsValid
            foreach (var result in results)
            {
                result.IsValid = result.IsValidChar == "Y";
            }
            
            return results.ToList();
        }

        /// <summary>
        /// Refresh plants data from API and trigger ETL
        /// </summary>
        public async Task<(bool success, string message)> RefreshPlantsDataAsync()
        {
            // This method should be called from ETLService which handles the full flow:
            // 1. Fetch from API
            // 2. Insert into RAW_JSON
            // 3. Call stored procedures
            // For now, we'll just call the stored procedure directly
            // TODO: Refactor to use ETLService.ProcessPlantsEndpoint
            
            using var connection = new OracleConnection(_connectionString);
            await connection.OpenAsync();

            using var command = connection.CreateCommand();
            command.CommandType = CommandType.StoredProcedure;
            command.CommandText = "pkg_etl_operations.run_plants_etl";
            
            command.Parameters.Add("p_status", OracleDbType.Varchar2, 4000).Direction = ParameterDirection.Output;
            command.Parameters.Add("p_message", OracleDbType.Varchar2, 4000).Direction = ParameterDirection.Output;

            try
            {
                await command.ExecuteNonQueryAsync();
                
                var status = command.Parameters["p_status"].Value?.ToString() ?? "UNKNOWN";
                var message = command.Parameters["p_message"].Value?.ToString() ?? "No message";
                
                return (status == "SUCCESS", message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to refresh plants data");
                return (false, ex.Message);
            }
        }

        /// <summary>
        /// Refresh issues data for a specific plant from API and trigger ETL
        /// </summary>
        public async Task<(bool success, string message)> RefreshIssuesDataAsync(string plantId)
        {
            using var connection = new OracleConnection(_connectionString);
            await connection.OpenAsync();

            using var command = connection.CreateCommand();
            command.CommandType = CommandType.StoredProcedure;
            command.CommandText = "pkg_etl_operations.run_issues_etl_for_plant";
            
            command.Parameters.Add("p_plant_id", OracleDbType.Varchar2).Value = plantId;
            command.Parameters.Add("p_status", OracleDbType.Varchar2, 4000).Direction = ParameterDirection.Output;
            command.Parameters.Add("p_message", OracleDbType.Varchar2, 4000).Direction = ParameterDirection.Output;

            try
            {
                await command.ExecuteNonQueryAsync();
                
                var status = command.Parameters["p_status"].Value?.ToString() ?? "UNKNOWN";
                var message = command.Parameters["p_message"].Value?.ToString() ?? "No message";
                
                return (status == "SUCCESS", message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to refresh issues data for plant {plantId}");
                return (false, ex.Message);
            }
        }
    }
}