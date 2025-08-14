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
    PlantID TEXT,
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
    PlantID TEXT,
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
    PlantID TEXT,
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

-- Create pcs_references table (TR2000 API: /plants/{id}/issues/rev/{rev}/pcs)
CREATE TABLE pcs_references (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PlantID TEXT,
    IssueRevision TEXT,
    PCS TEXT,
    Revision TEXT,
    RevDate TEXT,
    Status TEXT,
    OfficialRevision TEXT,
    RevisionSuffix TEXT,
    RatingClass TEXT,
    MaterialGroup TEXT,
    HistoricalPCS TEXT,
    Delta TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlantID) REFERENCES plants(PlantID)
);

-- Create sc_references table (TR2000 API: /plants/{id}/issues/rev/{rev}/sc)
CREATE TABLE sc_references (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PlantID TEXT,
    IssueRevision TEXT,
    SC TEXT,
    Revision TEXT,
    RevDate TEXT,
    Status TEXT,
    OfficialRevision TEXT,
    Delta TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlantID) REFERENCES plants(PlantID)
);

-- Create vsm_references table (TR2000 API: /plants/{id}/issues/rev/{rev}/vsm)
CREATE TABLE vsm_references (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PlantID TEXT,
    IssueRevision TEXT,
    VSM TEXT,
    Revision TEXT,
    RevDate TEXT,
    Status TEXT,
    OfficialRevision TEXT,
    Delta TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlantID) REFERENCES plants(PlantID)
);

-- Create vds_references table (TR2000 API: /plants/{id}/issues/rev/{rev}/vds)
CREATE TABLE vds_references (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PlantID TEXT,
    IssueRevision TEXT,
    VDS TEXT,
    Revision TEXT,
    RevDate TEXT,
    Status TEXT,
    OfficialRevision TEXT,
    Delta TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlantID) REFERENCES plants(PlantID)
);

-- Create eds_references table (TR2000 API: /plants/{id}/issues/rev/{rev}/eds)
CREATE TABLE eds_references (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PlantID TEXT,
    IssueRevision TEXT,
    EDS TEXT,
    Revision TEXT,
    RevDate TEXT,
    Status TEXT,
    OfficialRevision TEXT,
    Delta TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlantID) REFERENCES plants(PlantID)
);

-- Create mds_references table (TR2000 API: /plants/{id}/issues/rev/{rev}/mds)
CREATE TABLE mds_references (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PlantID TEXT,
    IssueRevision TEXT,
    MDS TEXT,
    Revision TEXT,
    Area TEXT,
    RevDate TEXT,
    Status TEXT,
    OfficialRevision TEXT,
    Delta TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlantID) REFERENCES plants(PlantID)
);

-- Create vsk_references table (TR2000 API: /plants/{id}/issues/rev/{rev}/vsk)
CREATE TABLE vsk_references (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PlantID TEXT,
    IssueRevision TEXT,
    VSK TEXT,
    Revision TEXT,
    RevDate TEXT,
    Status TEXT,
    OfficialRevision TEXT,
    Delta TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlantID) REFERENCES plants(PlantID)
);

-- Create esk_references table (TR2000 API: /plants/{id}/issues/rev/{rev}/esk)
CREATE TABLE esk_references (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PlantID TEXT,
    IssueRevision TEXT,
    ESK TEXT,
    Revision TEXT,
    RevDate TEXT,
    Status TEXT,
    OfficialRevision TEXT,
    Delta TEXT,
    CreatedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    ModifiedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (PlantID) REFERENCES plants(PlantID)
);

-- Create pipe_element_references table (TR2000 API: /plants/{id}/issues/rev/{rev}/pipe-elements)
CREATE TABLE pipe_element_references (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    PlantID TEXT,
    IssueRevision TEXT,
    ElementType TEXT,
    ElementCode TEXT,
    Description TEXT,
    Reference TEXT,
    Standard TEXT,
    Material TEXT,
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
CREATE INDEX idx_pcs_references_plantid ON pcs_references(PlantID);
CREATE INDEX idx_sc_references_plantid ON sc_references(PlantID);
CREATE INDEX idx_vsm_references_plantid ON vsm_references(PlantID);
CREATE INDEX idx_vds_references_plantid ON vds_references(PlantID);
CREATE INDEX idx_eds_references_plantid ON eds_references(PlantID);
CREATE INDEX idx_mds_references_plantid ON mds_references(PlantID);
CREATE INDEX idx_vsk_references_plantid ON vsk_references(PlantID);
CREATE INDEX idx_esk_references_plantid ON esk_references(PlantID);
CREATE INDEX idx_pipe_element_references_plantid ON pipe_element_references(PlantID);
CREATE INDEX idx_importlog_endpoint ON ImportLog(Endpoint);
CREATE INDEX idx_importlog_starttime ON ImportLog(StartTime);
";

using var command = new SqliteCommand(schema, connection);
command.ExecuteNonQuery();

// Close connection before setting permissions
connection.Close();

// Set proper file permissions for the database
if (OperatingSystem.IsLinux() || OperatingSystem.IsMacOS())
{
    var fileInfo = new FileInfo(dbPath);
    // Set permissions to 666 (read/write for all)
    System.Diagnostics.Process.Start("chmod", $"666 {dbPath}")?.WaitForExit();
    System.Diagnostics.Process.Start("chmod", $"777 {directory}")?.WaitForExit();
}

Console.WriteLine($"✅ Database created successfully at: {dbPath}");
Console.WriteLine("Database contains the following tables:");
Console.WriteLine("  - ImportLog (for tracking imports)");
Console.WriteLine("  - operators (TR2000 operators)");
Console.WriteLine("  - plants (TR2000 plants)");
Console.WriteLine("  - pcs (TR2000 pipe class sheets)");
Console.WriteLine("  - issues (TR2000 issues)");
Console.WriteLine("  - pcs_references (PCS references for issues)");
Console.WriteLine("  - sc_references (SC references for issues)");
Console.WriteLine("  - vsm_references (VSM references for issues)");
Console.WriteLine("  - vds_references (VDS references for issues)");
Console.WriteLine("  - eds_references (EDS references for issues)");
Console.WriteLine("  - mds_references (MDS references for issues)");
Console.WriteLine("  - vsk_references (VSK references for issues)");
Console.WriteLine("  - esk_references (ESK references for issues)");
Console.WriteLine("  - pipe_element_references (Pipe element references)");
Console.WriteLine("✅ All tables have proper indexes and foreign keys!");