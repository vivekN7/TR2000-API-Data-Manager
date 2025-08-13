using Microsoft.Data.Sqlite;

namespace TR2KBlazorLibrary.Logic.Repositories;

public interface ISqliteConnectionFactory
{
    SqliteConnection GetConnection();
    Task<SqliteConnection> GetConnectionAsync();
    void InitializeDatabase();
    Task InitializeDatabaseAsync();
}