using TR2KBlazorLibrary;

// Create the database with predefined schema
var connectionString = "Data Source=/workspace/TR2000/TR2K/TR2KBlazorUI/TR2KBlazorUI/Data/tr2000_api_data.db";
DatabaseSetup.CreateDatabase(connectionString);