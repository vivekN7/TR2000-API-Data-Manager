using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace TR2KBlazorLibrary.Logic.Repositories;

public class SqliteConnectionFactory : ISqliteConnectionFactory
{
    private readonly string _connectionString;
    private readonly ILogger<SqliteConnectionFactory> _logger;
    private bool _databaseInitialized = false;
    private readonly object _initLock = new object();

    public SqliteConnectionFactory(IConfiguration configuration, ILogger<SqliteConnectionFactory> logger)
    {
        _logger = logger;
        var connectionString = configuration.GetConnectionString("TR2000Database");
        
        if (string.IsNullOrEmpty(connectionString))
        {
            throw new InvalidOperationException("TR2000Database connection string is not configured");
        }

        _connectionString = connectionString;
    }

    public SqliteConnection GetConnection()
    {
        EnsureDatabaseInitialized();
        var connection = new SqliteConnection(_connectionString);
        connection.Open();
        
        // Temporarily disable foreign key constraints for debugging
        using var pragmaCommand = new SqliteCommand("PRAGMA foreign_keys = OFF", connection);
        pragmaCommand.ExecuteNonQuery();
        
        return connection;
    }

    public async Task<SqliteConnection> GetConnectionAsync()
    {
        await EnsureDatabaseInitializedAsync();
        var connection = new SqliteConnection(_connectionString);
        await connection.OpenAsync();
        
        // Temporarily disable foreign key constraints for debugging  
        using var pragmaCommand = new SqliteCommand("PRAGMA foreign_keys = OFF", connection);
        await pragmaCommand.ExecuteNonQueryAsync();
        
        return connection;
    }

    public void InitializeDatabase()
    {
        lock (_initLock)
        {
            if (_databaseInitialized) return;

            try
            {
                // Just verify the database file exists and is accessible
                using var connection = new SqliteConnection(_connectionString);
                connection.Open();
                
                // Verify tables exist by checking one of them
                using var command = new SqliteCommand("SELECT name FROM sqlite_master WHERE type='table' AND name='operators'", connection);
                var result = command.ExecuteScalar();
                
                if (result == null)
                {
                    throw new InvalidOperationException("Database tables not found. Please run DatabaseCreator to create the database with predefined schema.");
                }

                _databaseInitialized = true;
                _logger.LogInformation("Database verification successful - using predefined schema");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to verify database");
                throw;
            }
        }
    }

    public async Task InitializeDatabaseAsync()
    {
        if (_databaseInitialized) return;

        try
        {
            // Just verify the database file exists and is accessible
            using var connection = new SqliteConnection(_connectionString);
            await connection.OpenAsync();
            
            // Verify tables exist by checking one of them
            using var command = new SqliteCommand("SELECT name FROM sqlite_master WHERE type='table' AND name='operators'", connection);
            var result = await command.ExecuteScalarAsync();
            
            if (result == null)
            {
                throw new InvalidOperationException("Database tables not found. Please run DatabaseCreator to create the database with predefined schema.");
            }

            _databaseInitialized = true;
            _logger.LogInformation("Database verification successful - using predefined schema");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to verify database");
            throw;
        }
    }

    private void EnsureDatabaseInitialized()
    {
        if (!_databaseInitialized)
        {
            InitializeDatabase();
        }
    }

    private async Task EnsureDatabaseInitializedAsync()
    {
        if (!_databaseInitialized)
        {
            await InitializeDatabaseAsync();
        }
    }

}