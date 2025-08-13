using Microsoft.Data.Sqlite;
using System.Text.Json;

Console.WriteLine("=== TR2000 API vs SQLite Schema Comparison ===\n");

// TR2000 API endpoints to analyze
var endpoints = new[]
{
    "operators",
    "plants", 
    "plants/1/pcs",
    "plants/1/issues",
    "plants/2/pcs",
    "plants/2/issues"
};

var apiBaseUrl = "https://tr2000api.equinor.com";
var dbPath = "/workspace/TR2000/TR2K/TR2KBlazorUI/TR2KBlazorUI/Data/tr2000_api_data.db";

Console.WriteLine("🔍 STEP 1: Analyzing TR2000 API Response Structure");
Console.WriteLine("=================================================");

var apiStructures = new Dictionary<string, List<string>>();

using var httpClient = new HttpClient();
httpClient.Timeout = TimeSpan.FromSeconds(30);

foreach (var endpoint in endpoints)
{
    try
    {
        Console.WriteLine($"\n📡 Analyzing endpoint: {endpoint}");
        
        var url = $"{apiBaseUrl}/{endpoint}";
        var response = await httpClient.GetStringAsync(url);
        
        Console.WriteLine($"✅ Response received ({response.Length} characters)");
        
        // Parse the JSON to extract property names
        var properties = ExtractPropertiesFromJson(response);
        apiStructures[endpoint] = properties;
        
        Console.WriteLine($"🔑 Properties found: {string.Join(", ", properties)}");
        
        // Show a sample of the data
        var sampleData = ExtractSampleData(response);
        if (!string.IsNullOrEmpty(sampleData))
        {
            Console.WriteLine($"📋 Sample data: {sampleData}");
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"❌ Error accessing {endpoint}: {ex.Message}");
        apiStructures[endpoint] = new List<string> { "ERROR: " + ex.Message };
    }
}

Console.WriteLine("\n\n🗃️  STEP 2: Analyzing SQLite Database Schema");
Console.WriteLine("=============================================");

var dbStructures = new Dictionary<string, List<(string Name, string Type)>>();

try
{
    using var connection = new SqliteConnection($"Data Source={dbPath}");
    connection.Open();
    
    var tables = new[] { "operators", "plants", "pcs", "issues" };
    
    foreach (var table in tables)
    {
        Console.WriteLine($"\n📊 Analyzing table: {table}");
        
        using var command = new SqliteCommand($"PRAGMA table_info([{table}])", connection);
        using var reader = command.ExecuteReader();
        
        var columns = new List<(string Name, string Type)>();
        
        while (reader.Read())
        {
            var name = reader.GetString(1); // column name
            var type = reader.GetString(2); // column type
            var notNull = reader.GetInt32(3) == 1;
            var pk = reader.GetInt32(5) == 1;
            
            // Skip auto-generated columns for comparison
            if (name != "Id" && name != "CreatedDate" && name != "ModifiedDate")
            {
                columns.Add((name, $"{type}{(notNull ? " NOT NULL" : "")}{(pk ? " PK" : "")}"));
            }
        }
        
        dbStructures[table] = columns;
        
        Console.WriteLine($"🏗️  Columns: {string.Join(", ", columns.Select(c => $"{c.Name}({c.Type})"))}");
    }
}
catch (Exception ex)
{
    Console.WriteLine($"❌ Error reading database: {ex.Message}");
}

Console.WriteLine("\n\n⚖️  STEP 3: COMPARISON RESULTS");
Console.WriteLine("===============================");

// Map endpoints to table names
var endpointToTable = new Dictionary<string, string>
{
    ["operators"] = "operators",
    ["plants"] = "plants",
    ["plants/1/pcs"] = "pcs",
    ["plants/2/pcs"] = "pcs",
    ["plants/1/issues"] = "issues",
    ["plants/2/issues"] = "issues"
};

foreach (var endpoint in endpoints)
{
    if (endpointToTable.TryGetValue(endpoint, out var tableName))
    {
        Console.WriteLine($"\n🔍 Comparing {endpoint} ↔️ {tableName}");
        
        var apiProps = apiStructures.GetValueOrDefault(endpoint, new List<string>());
        var dbCols = dbStructures.GetValueOrDefault(tableName, new List<(string, string)>());
        
        Console.WriteLine($"   API Properties ({apiProps.Count}): {string.Join(", ", apiProps)}");
        Console.WriteLine($"   DB Columns ({dbCols.Count}): {string.Join(", ", dbCols.Select(c => c.Item1))}");
        
        // Find matches
        var matches = apiProps.Where(prop => dbCols.Any(col => col.Item1 == prop)).ToList();
        var missingInDb = apiProps.Where(prop => !dbCols.Any(col => col.Item1 == prop)).ToList();
        var missingInApi = dbCols.Where(col => !apiProps.Contains(col.Item1)).ToList();
        
        if (matches.Any())
            Console.WriteLine($"   ✅ Matches: {string.Join(", ", matches)}");
            
        if (missingInDb.Any())
            Console.WriteLine($"   ⚠️  Missing in DB: {string.Join(", ", missingInDb)}");
            
        if (missingInApi.Any())
            Console.WriteLine($"   ⚠️  Missing in API: {string.Join(", ", missingInApi.Select(c => c.Item1))}");
        
        var matchPercentage = apiProps.Any() ? (matches.Count * 100.0 / apiProps.Count) : 0;
        Console.WriteLine($"   📊 Match Rate: {matchPercentage:F1}%");
    }
}

Console.WriteLine("\n\n📋 FINAL SUMMARY");
Console.WriteLine("================");

foreach (var kvp in endpointToTable.GroupBy(x => x.Value).ToDictionary(g => g.Key, g => g.Select(x => x.Key).ToList()))
{
    var tableName = kvp.Key;
    var relatedEndpoints = kvp.Value;
    
    Console.WriteLine($"\n🏗️  Table: {tableName}");
    Console.WriteLine($"   🔗 Related endpoints: {string.Join(", ", relatedEndpoints)}");
    
    if (dbStructures.TryGetValue(tableName, out var cols))
    {
        Console.WriteLine($"   📋 Schema: {string.Join(", ", cols.Select(c => $"{c.Item1} {c.Item2}"))}");
    }
}

static List<string> ExtractPropertiesFromJson(string json)
{
    var properties = new HashSet<string>();
    
    try
    {
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        
        // Handle different JSON structures
        if (root.ValueKind == JsonValueKind.Array && root.GetArrayLength() > 0)
        {
            var firstItem = root[0];
            AddPropertiesFromElement(firstItem, properties);
        }
        else if (root.ValueKind == JsonValueKind.Object)
        {
            // Look for arrays in wrapper objects
            foreach (var prop in root.EnumerateObject())
            {
                if (prop.Value.ValueKind == JsonValueKind.Array && prop.Value.GetArrayLength() > 0)
                {
                    var firstItem = prop.Value[0];
                    AddPropertiesFromElement(firstItem, properties);
                    break; // Use first array found
                }
            }
            
            // If no arrays found, use root object properties
            if (!properties.Any())
            {
                AddPropertiesFromElement(root, properties);
            }
        }
    }
    catch (Exception ex)
    {
        properties.Add($"JSON_PARSE_ERROR: {ex.Message}");
    }
    
    return properties.ToList();
}

static void AddPropertiesFromElement(JsonElement element, HashSet<string> properties)
{
    if (element.ValueKind == JsonValueKind.Object)
    {
        foreach (var prop in element.EnumerateObject())
        {
            properties.Add(prop.Name);
        }
    }
}

static string ExtractSampleData(string json)
{
    try
    {
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        
        JsonElement? firstItem = null;
        
        if (root.ValueKind == JsonValueKind.Array && root.GetArrayLength() > 0)
        {
            firstItem = root[0];
        }
        else if (root.ValueKind == JsonValueKind.Object)
        {
            foreach (var prop in root.EnumerateObject())
            {
                if (prop.Value.ValueKind == JsonValueKind.Array && prop.Value.GetArrayLength() > 0)
                {
                    firstItem = prop.Value[0];
                    break;
                }
            }
        }
        
        if (firstItem.HasValue && firstItem.Value.ValueKind == JsonValueKind.Object)
        {
            var sampleProps = new List<string>();
            foreach (var prop in firstItem.Value.EnumerateObject())
            {
                var value = prop.Value.ValueKind switch
                {
                    JsonValueKind.String => $"'{prop.Value.GetString()}'",
                    JsonValueKind.Number => prop.Value.ToString(),
                    JsonValueKind.True => "true",
                    JsonValueKind.False => "false",
                    JsonValueKind.Null => "null",
                    _ => prop.Value.ToString()
                };
                sampleProps.Add($"{prop.Name}={value}");
            }
            return string.Join(", ", sampleProps);
        }
    }
    catch
    {
        // Ignore errors in sample extraction
    }
    
    return "";
}