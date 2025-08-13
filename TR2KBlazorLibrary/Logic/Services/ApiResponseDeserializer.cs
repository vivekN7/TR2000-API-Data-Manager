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
                foreach (var property in root.EnumerateObject())
                {
                    if (property.Value.ValueKind == JsonValueKind.Array)
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