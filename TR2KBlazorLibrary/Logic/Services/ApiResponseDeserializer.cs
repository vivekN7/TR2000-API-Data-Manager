using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace TR2KBlazorLibrary.Logic.Services;

public class ApiResponseDeserializer
{
    private readonly ILogger<ApiResponseDeserializer> _logger;

    public ApiResponseDeserializer(ILogger<ApiResponseDeserializer> logger)
    {
        _logger = logger;
    }

    public List<Dictionary<string, object>> DeserializeApiResponse(string jsonResponse, string endpoint)
    {
        try
        {
            using var document = JsonDocument.Parse(jsonResponse);
            var root = document.RootElement;

            // Handle direct arrays
            if (root.ValueKind == JsonValueKind.Array)
            {
                return ParseArray(root);
            }

            // Handle wrapper objects with arrays (TR2000 API format)
            if (root.ValueKind == JsonValueKind.Object)
            {
                // Check if this looks like a TR2000 wrapper (has a single array property starting with "get")
                var properties = root.EnumerateObject().ToList();
                
                // Special handling for properties endpoint with nested arrays
                // Check for success=true pattern FIRST before other logic
                if (properties.Any(p => p.Name == "success" && p.Value.ValueKind == JsonValueKind.True))
                {
                    // Get all nested arrays that start with "get"
                    var nestedArrays = properties.Where(p => 
                        p.Value.ValueKind == JsonValueKind.Array && 
                        p.Name.StartsWith("get")).ToList();
                    
                    // If there are multiple "get" arrays, flatten them all
                    if (nestedArrays.Count > 1)
                    {
                        var result = new List<Dictionary<string, object>>();
                        
                        // For each nested array, add its items with parent context
                        foreach (var arrayProp in nestedArrays)
                        {
                            var arrayName = arrayProp.Name;
                            foreach (var item in arrayProp.Value.EnumerateArray())
                            {
                                var flattenedItem = ParseObject(item);
                                
                                // Add parent object properties for context
                                foreach (var prop in properties)
                                {
                                    if (prop.Value.ValueKind != JsonValueKind.Array && prop.Name != "success")
                                    {
                                        flattenedItem[$"Parent_{prop.Name}"] = ParseValue(prop.Value);
                                    }
                                }
                                
                                // Add array source name for clarity
                                flattenedItem["_Source"] = arrayName;
                                result.Add(flattenedItem);
                            }
                        }
                        
                        return result;
                    }
                    // If there's only one "get" array, parse it and add header fields
                    else if (nestedArrays.Count == 1)
                    {
                        var result = ParseArray(nestedArrays[0].Value);
                        
                        // Add common header fields to each row
                        var headerFields = properties.Where(p => 
                            p.Value.ValueKind != JsonValueKind.Array && 
                            p.Name != "success").ToList();
                        
                        if (headerFields.Any() && result.Any())
                        {
                            _logger.LogInformation($"Adding {headerFields.Count} header fields to {result.Count} rows: {string.Join(", ", headerFields.Select(h => h.Name))}");
                            foreach (var item in result)
                            {
                                foreach (var headerField in headerFields)
                                {
                                    item[headerField.Name] = ParseValue(headerField.Value);
                                }
                            }
                        }
                        
                        return result;
                    }
                    else
                    {
                        // No nested arrays, return single object
                        return new List<Dictionary<string, object>> { ParseObject(root) };
                    }
                }
                
                // Look for the main data array (usually starts with "get" like "getPCS", "getIssues", etc.)
                var mainArrayProperty = properties.FirstOrDefault(p => 
                    p.Value.ValueKind == JsonValueKind.Array && 
                    (p.Name.StartsWith("get") || p.Name == "data" || p.Name == "result"));
                
                if (mainArrayProperty.Value.ValueKind == JsonValueKind.Array)
                {
                    var result = ParseArray(mainArrayProperty.Value);
                    
                    // Add common header fields to each row
                    var headerFields = properties.Where(p => 
                        p.Value.ValueKind != JsonValueKind.Array && 
                        p.Name != "success").ToList();
                    
                    // Log header fields for debugging
                    if (headerFields.Any())
                    {
                        _logger.LogInformation($"Found {headerFields.Count} header fields: {string.Join(", ", headerFields.Select(h => h.Name))}");
                        foreach (var field in headerFields)
                        {
                            _logger.LogInformation($"Header field {field.Name} = {ParseValue(field.Value)}");
                        }
                    }
                    
                    if (headerFields.Any() && result.Any())
                    {
                        foreach (var item in result)
                        {
                            foreach (var headerField in headerFields)
                            {
                                // Add header fields to each row
                                item[headerField.Name] = ParseValue(headerField.Value);
                            }
                        }
                        
                        // Log first item to verify fields were added
                        if (result.Count > 0 && result[0] is Dictionary<string, object> firstItem)
                        {
                            _logger.LogInformation($"First item keys after adding headers: {string.Join(", ", firstItem.Keys.Take(5))}");
                        }
                    }
                    
                    return result;
                }
                
                // Fallback: Look for any array property
                foreach (var property in properties)
                {
                    if (property.Value.ValueKind == JsonValueKind.Array && property.Value.GetArrayLength() > 0)
                    {
                        return ParseArray(property.Value);
                    }
                }
            }

            // Single object response
            return new List<Dictionary<string, object>> { ParseObject(root) };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to deserialize API response for endpoint: {Endpoint}", endpoint);
            return new List<Dictionary<string, object>>();
        }
    }

    private List<Dictionary<string, object>> ParseArray(JsonElement arrayElement)
    {
        var result = new List<Dictionary<string, object>>();

        foreach (var item in arrayElement.EnumerateArray())
        {
            result.Add(ParseObject(item));
        }

        return result;
    }

    private Dictionary<string, object> ParseObject(JsonElement objectElement)
    {
        var result = new Dictionary<string, object>();

        if (objectElement.ValueKind != JsonValueKind.Object)
        {
            return result;
        }

        foreach (var property in objectElement.EnumerateObject())
        {
            result[property.Name] = ParseValue(property.Value);
        }

        return result;
    }

    private object ParseValue(JsonElement element)
    {
        return element.ValueKind switch
        {
            JsonValueKind.String => element.GetString() ?? "",
            JsonValueKind.Number => element.TryGetInt32(out var intVal) ? intVal : element.GetDouble(),
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            JsonValueKind.Null => DBNull.Value,
            JsonValueKind.Array => element.EnumerateArray().Select(ParseValue).ToList(),
            JsonValueKind.Object => ParseObject(element),
            _ => element.ToString()
        };
    }
}