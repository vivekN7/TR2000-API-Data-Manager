using System.Net.Http;
using System.Text.Json;
using System.Linq;
using Microsoft.Extensions.Logging;

namespace TR2KBlazorLibrary.Logic.Services;

public class TR2000ApiService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<TR2000ApiService> _logger;
    private const string BaseUrl = "https://equinor.pipespec-api.presight.com";

    public TR2000ApiService(HttpClient httpClient, ILogger<TR2000ApiService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _httpClient.Timeout = TimeSpan.FromMinutes(5); // Increased timeout for large datasets like VDS
    }

    public async Task<TestConnectionResult> TestConnectionAsync(string endpoint)
    {
        try
        {
            var url = $"{BaseUrl}/{endpoint.TrimStart('/')}";
            _logger.LogInformation("Testing connection to: {Url}", url);

            var response = await _httpClient.GetAsync(url);
            response.EnsureSuccessStatusCode();

            var content = await response.Content.ReadAsStringAsync();
            _logger.LogInformation("API Response (first 500 chars): {Content}", 
                content.Length > 500 ? content.Substring(0, 500) + "..." : content);
                
            var recordCount = CountRecords(content);
            _logger.LogInformation("Parsed record count: {Count}", recordCount);

            return new TestConnectionResult
            {
                Success = true,
                RecordCount = recordCount,
                ResponseTime = TimeSpan.FromMilliseconds(100), // Approximate
                ErrorMessage = null
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Connection test failed for endpoint: {Endpoint}", endpoint);
            return new TestConnectionResult
            {
                Success = false,
                RecordCount = 0,
                ResponseTime = TimeSpan.Zero,
                ErrorMessage = ex.Message
            };
        }
    }

    public async Task<string> FetchDataAsync(string endpoint)
    {
        var url = $"{BaseUrl}/{endpoint.TrimStart('/')}";
        _logger.LogInformation("Fetching data from: {Url}", url);

        var response = await _httpClient.GetAsync(url);
        response.EnsureSuccessStatusCode();

        return await response.Content.ReadAsStringAsync();
    }

    private static int CountRecords(string jsonContent)
    {
        try
        {
            using var document = JsonDocument.Parse(jsonContent);
            var root = document.RootElement;

            // Handle array responses
            if (root.ValueKind == JsonValueKind.Array)
            {
                return root.GetArrayLength();
            }

            // Handle wrapper objects with arrays
            if (root.ValueKind == JsonValueKind.Object)
            {
                var properties = root.EnumerateObject().ToList();
                
                // Special handling for properties endpoint with nested arrays
                // Check for success=true pattern FIRST (same logic as deserializer)
                if (properties.Any(p => p.Name == "success" && p.Value.ValueKind == JsonValueKind.True))
                {
                    // Get all nested arrays that start with "get"
                    var nestedArrays = properties.Where(p => 
                        p.Value.ValueKind == JsonValueKind.Array && 
                        p.Name.StartsWith("get")).ToList();
                    
                    // If there are multiple "get" arrays, count all items
                    if (nestedArrays.Count > 1)
                    {
                        return nestedArrays.Sum(arr => arr.Value.GetArrayLength());
                    }
                    // If there's only one "get" array, return its count
                    else if (nestedArrays.Count == 1)
                    {
                        return nestedArrays[0].Value.GetArrayLength();
                    }
                    else
                    {
                        // No nested arrays, count as single object
                        return 1;
                    }
                }
                
                // Fallback: Look for any array property
                foreach (var property in properties)
                {
                    if (property.Value.ValueKind == JsonValueKind.Array)
                    {
                        return property.Value.GetArrayLength();
                    }
                }
            }

            return 1; // Single object
        }
        catch (Exception)
        {
            return 0;
        }
    }

    public async Task<ApiResponse> GetDataAsync(string endpoint)
    {
        try
        {
            var url = $"{BaseUrl}/{endpoint.TrimStart('/')}";
            _logger.LogInformation("Fetching data from: {Url}", url);

            var response = await _httpClient.GetAsync(url);
            response.EnsureSuccessStatusCode();

            var content = await response.Content.ReadAsStringAsync();
            
            return new ApiResponse
            {
                Success = true,
                Data = content,
                ErrorMessage = null
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to fetch data from endpoint: {Endpoint}", endpoint);
            return new ApiResponse
            {
                Success = false,
                Data = null,
                ErrorMessage = ex.Message
            };
        }
    }
}

public class TestConnectionResult
{
    public bool Success { get; set; }
    public int RecordCount { get; set; }
    public TimeSpan ResponseTime { get; set; }
    public string? ErrorMessage { get; set; }
}

public class ApiResponse
{
    public bool Success { get; set; }
    public string? Data { get; set; }
    public string? ErrorMessage { get; set; }
}