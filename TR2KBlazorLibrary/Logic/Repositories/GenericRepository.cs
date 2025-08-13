using System.ComponentModel;
using System.ComponentModel.DataAnnotations.Schema;
using System.Data;
using System.Reflection;
using System.Text;
using Dapper;
using Microsoft.Extensions.Logging;

namespace TR2KBlazorLibrary.Logic.Repositories;

public class GenericRepository<T> : IGenericRepository<T> where T : class
{
    private readonly ISqliteConnectionFactory _connectionFactory;
    private readonly ILogger<GenericRepository<T>> _logger;

    public GenericRepository(ISqliteConnectionFactory connectionFactory, ILogger<GenericRepository<T>> logger)
    {
        _connectionFactory = connectionFactory;
        _logger = logger;
    }

    public async Task CreateTableFromObjectAsync(string tableName, T sampleObject)
    {
        try
        {
            var properties = typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance);
            var columnDefinitions = new List<string>();

            foreach (var property in properties)
            {
                var columnName = property.Name;
                var sqlType = GetSqliteType(property.PropertyType);
                columnDefinitions.Add($"[{columnName}] {sqlType}");
            }

            var createTableSql = $@"
                CREATE TABLE IF NOT EXISTS [{tableName}] (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    {string.Join(",\n                    ", columnDefinitions)},
                    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
                    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP
                )";

            using var connection = await _connectionFactory.GetConnectionAsync();
            await connection.ExecuteAsync(createTableSql);

            _logger.LogInformation("Created table {TableName} with {ColumnCount} columns", tableName, columnDefinitions.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create table {TableName}", tableName);
            throw;
        }
    }

    public async Task<bool> TableExistsAsync(string tableName)
    {
        const string sql = "SELECT name FROM sqlite_master WHERE type='table' AND name=@tableName";
        using var connection = await _connectionFactory.GetConnectionAsync();
        var result = await connection.QuerySingleOrDefaultAsync<string>(sql, new { tableName });
        return !string.IsNullOrEmpty(result);
    }

    public async Task DropTableAsync(string tableName)
    {
        try
        {
            var sql = $"DROP TABLE IF EXISTS [{tableName}]";
            using var connection = await _connectionFactory.GetConnectionAsync();
            await connection.ExecuteAsync(sql);
            _logger.LogInformation("Dropped table {TableName}", tableName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to drop table {TableName}", tableName);
            throw;
        }
    }

    public async Task<IEnumerable<T>> GetAllAsync(string tableName)
    {
        var sql = $"SELECT * FROM [{tableName}]";
        using var connection = await _connectionFactory.GetConnectionAsync();
        return await connection.QueryAsync<T>(sql);
    }

    public async Task<T?> GetByIdAsync(string tableName, object id)
    {
        var sql = $"SELECT * FROM [{tableName}] WHERE Id = @id";
        using var connection = await _connectionFactory.GetConnectionAsync();
        return await connection.QuerySingleOrDefaultAsync<T>(sql, new { id });
    }

    public async Task<int> InsertAsync(string tableName, T entity)
    {
        try
        {
            var properties = typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .Where(p => p.Name != "Id" && p.Name != "CreatedDate" && p.Name != "ModifiedDate" && 
                           !p.GetCustomAttributes<NotMappedAttribute>().Any());

            var columnNames = properties.Select(p => $"[{p.Name}]").ToArray();
            var parameterNames = properties.Select(p => $"@{p.Name}").ToArray();

            var sql = $@"
                INSERT INTO [{tableName}] ({string.Join(", ", columnNames)}) 
                VALUES ({string.Join(", ", parameterNames)})";

            using var connection = await _connectionFactory.GetConnectionAsync();
            var result = await connection.ExecuteAsync(sql, entity);
            
            _logger.LogDebug("Inserted {RowCount} row(s) into {TableName}", result, tableName);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to insert entity into {TableName}", tableName);
            throw;
        }
    }

    public async Task<int> InsertBulkAsync(string tableName, IEnumerable<T> entities)
    {
        var entitiesList = entities.ToList();
        if (!entitiesList.Any()) return 0;

        try
        {
            _logger.LogInformation("InsertBulkAsync: Starting bulk insert of {Count} entities into {TableName}", entitiesList.Count, tableName);
            
            var allProperties = typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance);
            _logger.LogInformation("InsertBulkAsync: All properties of type {TypeName}: {Properties}", 
                typeof(T).Name, 
                string.Join(", ", allProperties.Select(p => p.Name)));
            
            var properties = allProperties
                .Where(p => p.Name != "Id" && p.Name != "CreatedDate" && p.Name != "ModifiedDate" && 
                           !p.GetCustomAttributes<NotMappedAttribute>().Any());

            _logger.LogInformation("InsertBulkAsync: Filtered properties for insert: {Properties}", 
                string.Join(", ", properties.Select(p => p.Name)));

            var columnNames = properties.Select(p => $"[{p.Name}]").ToArray();
            var parameterNames = properties.Select(p => $"@{p.Name}").ToArray();

            var sql = $@"
                INSERT INTO [{tableName}] ({string.Join(", ", columnNames)}) 
                VALUES ({string.Join(", ", parameterNames)})";

            _logger.LogInformation("InsertBulkAsync: Generated SQL: {SQL}", sql);
            
            // Log first entity values for debugging
            if (entitiesList.Any())
            {
                var firstEntity = entitiesList.First();
                var values = properties.Select(p => $"{p.Name}='{p.GetValue(firstEntity)}'");
                _logger.LogInformation("InsertBulkAsync: First entity values: {Values}", string.Join(", ", values));
            }

            using var connection = await _connectionFactory.GetConnectionAsync();
            var result = await connection.ExecuteAsync(sql, entitiesList);
            
            _logger.LogInformation("Bulk inserted {RowCount} row(s) into {TableName}", result, tableName);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to bulk insert {EntityCount} entities into {TableName}", entitiesList.Count, tableName);
            throw;
        }
    }

    public async Task<int> UpdateAsync(string tableName, T entity, object id)
    {
        try
        {
            var properties = typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .Where(p => p.Name != "Id" && p.Name != "CreatedDate" && 
                           !p.GetCustomAttributes<NotMappedAttribute>().Any());

            var setClause = properties.Select(p => $"[{p.Name}] = @{p.Name}").ToArray();

            var sql = $@"
                UPDATE [{tableName}] 
                SET {string.Join(", ", setClause)}, ModifiedDate = CURRENT_TIMESTAMP 
                WHERE Id = @id";

            var parameters = new DynamicParameters(entity);
            parameters.Add("id", id);

            using var connection = await _connectionFactory.GetConnectionAsync();
            var result = await connection.ExecuteAsync(sql, parameters);
            
            _logger.LogDebug("Updated {RowCount} row(s) in {TableName}", result, tableName);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to update entity in {TableName} with id {Id}", tableName, id);
            throw;
        }
    }

    public async Task<int> DeleteAsync(string tableName, object id)
    {
        var sql = $"DELETE FROM [{tableName}] WHERE Id = @id";
        using var connection = await _connectionFactory.GetConnectionAsync();
        var result = await connection.ExecuteAsync(sql, new { id });
        
        _logger.LogDebug("Deleted {RowCount} row(s) from {TableName}", result, tableName);
        return result;
    }

    public async Task<int> DeleteAllAsync(string tableName)
    {
        try
        {
            var sql = $"DELETE FROM [{tableName}]";
            using var connection = await _connectionFactory.GetConnectionAsync();
            var result = await connection.ExecuteAsync(sql);
            
            _logger.LogInformation("Deleted all {RowCount} row(s) from {TableName}", result, tableName);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete all rows from {TableName}", tableName);
            throw;
        }
    }

    public async Task<IEnumerable<T>> QueryAsync(string sql, object? parameters = null)
    {
        using var connection = await _connectionFactory.GetConnectionAsync();
        return await connection.QueryAsync<T>(sql, parameters);
    }

    public async Task<T?> QuerySingleOrDefaultAsync(string sql, object? parameters = null)
    {
        using var connection = await _connectionFactory.GetConnectionAsync();
        return await connection.QuerySingleOrDefaultAsync<T>(sql, parameters);
    }

    public async Task<int> ExecuteAsync(string sql, object? parameters = null)
    {
        using var connection = await _connectionFactory.GetConnectionAsync();
        return await connection.ExecuteAsync(sql, parameters);
    }

    public async Task<int> GetCountAsync(string tableName)
    {
        var sql = $"SELECT COUNT(*) FROM [{tableName}]";
        using var connection = await _connectionFactory.GetConnectionAsync();
        return await connection.QuerySingleAsync<int>(sql);
    }

    public async Task<IEnumerable<string>> GetTableColumnsAsync(string tableName)
    {
        var sql = $"PRAGMA table_info([{tableName}])";
        using var connection = await _connectionFactory.GetConnectionAsync();
        var columnInfo = await connection.QueryAsync(sql);
        return columnInfo.Select(c => (string)c.name);
    }

    private static string GetSqliteType(Type propertyType)
    {
        // Handle nullable types
        var underlyingType = Nullable.GetUnderlyingType(propertyType) ?? propertyType;

        return underlyingType.Name switch
        {
            nameof(String) => "TEXT",
            nameof(Int32) => "INTEGER",
            nameof(Int64) => "INTEGER",
            nameof(Boolean) => "INTEGER",
            nameof(DateTime) => "DATETIME",
            nameof(DateTimeOffset) => "DATETIME",
            nameof(Decimal) => "REAL",
            nameof(Double) => "REAL",
            nameof(Single) => "REAL",
            nameof(Guid) => "TEXT",
            _ => "TEXT" // Default to TEXT for unknown types
        };
    }
}

