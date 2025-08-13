namespace TR2KBlazorLibrary.Logic.Repositories;

public interface IGenericRepository<T> where T : class
{
    // Table verification operations (no dynamic creation)
    Task<bool> TableExistsAsync(string tableName);
    
    // Data operations
    Task<IEnumerable<T>> GetAllAsync(string tableName);
    Task<T?> GetByIdAsync(string tableName, object id);
    Task<int> InsertAsync(string tableName, T entity);
    Task<int> InsertBulkAsync(string tableName, IEnumerable<T> entities);
    Task<int> UpdateAsync(string tableName, T entity, object id);
    Task<int> DeleteAsync(string tableName, object id);
    Task<int> DeleteAllAsync(string tableName);
    
    // Query operations
    Task<IEnumerable<T>> QueryAsync(string sql, object? parameters = null);
    Task<T?> QuerySingleOrDefaultAsync(string sql, object? parameters = null);
    Task<int> ExecuteAsync(string sql, object? parameters = null);
    
    // Utility operations
    Task<int> GetCountAsync(string tableName);
    Task<IEnumerable<string>> GetTableColumnsAsync(string tableName);
}