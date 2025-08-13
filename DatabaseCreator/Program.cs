using Microsoft.Data.Sqlite;

Console.WriteLine("Creating TR2000 SQLite Database...");

var dbPath = "/workspace/TR2000/TR2K/TR2KApp/Data/tr2000_api_data.db";
var connectionString = $"Data Source={dbPath}";

// Delete existing database file if it exists
if (File.Exists(dbPath))
{
    File.Delete(dbPath);
    Console.WriteLine("Deleted existing database file.");
}

// Ensure directory exists
var directory = Path.GetDirectoryName(dbPath);
if (directory != null && !Directory.Exists(directory))
{
    Directory.CreateDirectory(directory);
}

using var connection = new SqliteConnection(connectionString);
connection.Open();

var schema = @"
-- Create ImportLog table for tracking import operations
CREATE TABLE ImportLog (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Endpoint TEXT NOT NULL,
    Status INTEGER NOT NULL,
    StartTime DATETIME NOT NULL,
    EndTime DATETIME,
    RecordsImported INTEGER DEFAULT 0,
    ErrorMessage TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Create operators table (TR2000 API: /operators)
-- Matches exact JSON response: getOperator array with OperatorID and OperatorName
CREATE TABLE operators (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    OperatorID INTEGER NOT NULL,
    OperatorName TEXT NOT NULL,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(OperatorID)
);

-- Create plants table (TR2000 API: /plants)
CREATE TABLE plants (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PlantID INTEGER,
    ShortDescription TEXT,
    LongDescription TEXT,
    OperatorID INTEGER,
    OperatorName TEXT,
    AreaID INTEGER,
    Area TEXT,
    CommonLibPlantCode TEXT,
    Project TEXT,
    InitialRevision TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OperatorID) REFERENCES operators(OperatorID)
);

-- Create pcs table (TR2000 API: /plants/{id}/pcs)
CREATE TABLE pcs (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PCSName TEXT,
    PlantID INTEGER,
    Revision TEXT,
    Status TEXT,
    RevDate TEXT,
    RatingClass TEXT,
    TestPressure TEXT,
    MaterialGroup TEXT,
    DesignCode TEXT,
    LastUpdate TEXT,
    LastUpdateBy TEXT,
    Approver TEXT,
    Notepad TEXT,
    SpecialReqID INTEGER,
    TubePCS TEXT,
    NewVDSSection TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlantID) REFERENCES plants(PlantID)
);

-- Create issues table (TR2000 API: /plants/{id}/issues)
CREATE TABLE issues (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    IssueRevision TEXT,
    PlantID INTEGER,
    Status TEXT,
    RevDate TEXT,
    ProtectStatus TEXT,
    GeneralRevision TEXT,
    GeneralRevDate TEXT,
    PCSRevision TEXT,
    PCSRevDate TEXT,
    EDSRevision TEXT,
    EDSRevDate TEXT,
    VDSRevision TEXT,
    VDSRevDate TEXT,
    VSKRevision TEXT,
    VSKRevDate TEXT,
    MDSRevision TEXT,
    MDSRevDate TEXT,
    ESKRevision TEXT,
    ESKRevDate TEXT,
    SCRevision TEXT,
    SCRevDate TEXT,
    VSMRevision TEXT,
    VSMRevDate TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlantID) REFERENCES plants(PlantID)
);

-- Create indexes for better performance
CREATE INDEX idx_operators_operatorid ON operators(OperatorID);
CREATE INDEX idx_plants_plantid ON plants(PlantID);
CREATE INDEX idx_plants_operatorid ON plants(OperatorID);
CREATE INDEX idx_pcs_plantid ON pcs(PlantID);
CREATE INDEX idx_issues_plantid ON issues(PlantID);
CREATE INDEX idx_importlog_endpoint ON ImportLog(Endpoint);
CREATE INDEX idx_importlog_starttime ON ImportLog(StartTime);
";

using var command = new SqliteCommand(schema, connection);
command.ExecuteNonQuery();

Console.WriteLine($"✅ Database created successfully at: {dbPath}");
Console.WriteLine("Database contains the following tables:");
Console.WriteLine("  - ImportLog (for tracking imports)");
Console.WriteLine("  - operators (TR2000 operators)");
Console.WriteLine("  - plants (TR2000 plants)");
Console.WriteLine("  - pcs (TR2000 pipe class sheets)");
Console.WriteLine("  - issues (TR2000 issues)");
Console.WriteLine("✅ All tables have proper indexes and foreign keys!");

connection.Close();