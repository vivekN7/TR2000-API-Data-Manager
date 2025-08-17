# Phase 3: Oracle ETL Implementation Plan

## Overview
Transform the TR2000 API Data Manager into a full ETL solution with Oracle database staging capabilities.

## Oracle Connection Details
- **Host**: host.docker.internal (when running from Docker container)
  - Use `localhost` if running directly on host machine
- **Port**: 1521
- **Service/SID**: XEPDB1 (adjust based on your Oracle installation)
- **Schema/User**: TR2000_STAGING
- **Password**: piping
- **Table Prefix**: TR2KSTG_

## Implementation Timeline

### Week 1: Foundation Setup (Days 1-3)
#### Day 1: Oracle Integration
- [ ] Install Oracle.ManagedDataAccess.Core NuGet package
- [ ] Add Oracle connection string to appsettings.json
- [ ] Create OracleETLService class
- [ ] Test basic Oracle connectivity

#### Day 2: Control Tables
- [ ] Create TR2KSTG_ETL_CONTROL table
- [ ] Create TR2KSTG_ETL_ENDPOINT_LOG table
- [ ] Create TR2KSTG_ETL_ERROR_LOG table
- [ ] Implement ETL logging methods

#### Day 3: UI Foundation
- [ ] Create new Blazor page: OracleETL.razor
- [ ] Add navigation menu item
- [ ] Design ETL control panel layout
- [ ] Implement table creation buttons

### Week 2: Master Data Tables (Days 4-7)
#### Day 4: Operators Table
- [ ] Create TR2KSTG_OPERATORS table
- [ ] Implement LoadOperators() method
- [ ] Add UI button and status display
- [ ] Test with 8 operator records

#### Day 5: Plants Table
- [ ] Create TR2KSTG_PLANTS table
- [ ] Implement LoadPlants() method
- [ ] Add cascading load option (load all plants for each operator)
- [ ] Test with 217+ plant records

#### Day 6: Issues Table
- [ ] Create TR2KSTG_ISSUES table
- [ ] Implement LoadIssues() method
- [ ] Add plant-by-plant loading option
- [ ] Handle revision tracking

#### Day 7: Testing & Validation
- [ ] Create validation queries
- [ ] Implement data quality checks
- [ ] Add "Verify Data" buttons
- [ ] Document any issues

### Week 3: Reference Tables (Days 8-11)
#### Day 8: PCS References
- [ ] Create TR2KSTG_PCS_REFERENCES table
- [ ] Create TR2KSTG_SC_REFERENCES table
- [ ] Implement loading methods
- [ ] Test with sample plant/issue combination

#### Day 9: Additional References
- [ ] Create TR2KSTG_VSM_REFERENCES table
- [ ] Create TR2KSTG_VDS_REFERENCES table
- [ ] Create TR2KSTG_EDS_REFERENCES table
- [ ] Create TR2KSTG_MDS_REFERENCES table

#### Day 10: Remaining References
- [ ] Create TR2KSTG_VSK_REFERENCES table
- [ ] Create TR2KSTG_ESK_REFERENCES table
- [ ] Create TR2KSTG_PIPE_ELEMENT_REFERENCES table
- [ ] Test all reference endpoints

#### Day 11: PCS Details
- [ ] Create TR2KSTG_PCS_LIST table
- [ ] Create TR2KSTG_PCS_PROPERTIES table
- [ ] Create TR2KSTG_PCS_TEMP_PRESSURE table
- [ ] Create TR2KSTG_PCS_PIPE_SIZES table

### Week 4: Complex Data & Optimization (Days 12-15)
#### Day 12: Large Datasets
- [ ] Create TR2KSTG_VDS_LIST table (44K+ records)
- [ ] Create TR2KSTG_VDS_SUBSEGMENTS table
- [ ] Implement batch processing
- [ ] Add progress indicators

#### Day 13: Bolt Tension Data
- [ ] Create TR2KSTG_BOLT_TENSION_DATA table
- [ ] Create TR2KSTG_BOLT_TENSION_PRESSURE table
- [ ] Handle CommonLibPlantCode extraction
- [ ] Test all bolt tension endpoints

#### Day 14: ETL Automation
- [ ] Implement "Load All Data" functionality
- [ ] Add scheduling capabilities
- [ ] Create incremental load logic
- [ ] Implement change detection

#### Day 15: Final Testing
- [ ] Full end-to-end ETL test
- [ ] Performance optimization
- [ ] Error handling improvements
- [ ] Documentation update

## Database Table Specifications

### 1. Control Tables

```sql
-- ETL Control Table
CREATE TABLE TR2KSTG_ETL_CONTROL (
    ETL_RUN_ID         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    RUN_DATE           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    RUN_TYPE           VARCHAR2(20),
    STATUS             VARCHAR2(20),
    RECORDS_EXTRACTED  NUMBER,
    RECORDS_LOADED     NUMBER,
    ERROR_COUNT        NUMBER,
    START_TIME         TIMESTAMP,
    END_TIME           TIMESTAMP,
    COMMENTS           VARCHAR2(4000)
);

-- Endpoint Processing Log
CREATE TABLE TR2KSTG_ETL_ENDPOINT_LOG (
    LOG_ID             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ETL_RUN_ID         NUMBER,
    ENDPOINT_NAME      VARCHAR2(100),
    PLANT_ID           VARCHAR2(50),
    API_URL            VARCHAR2(500),
    RESPONSE_TIME_MS   NUMBER,
    RECORD_COUNT       NUMBER,
    STATUS             VARCHAR2(20),
    ERROR_MESSAGE      VARCHAR2(4000),
    PROCESSED_DATE     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Error Log
CREATE TABLE TR2KSTG_ETL_ERROR_LOG (
    ERROR_ID           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ETL_RUN_ID         NUMBER,
    ERROR_DATE         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ERROR_TYPE         VARCHAR2(50),
    ERROR_MESSAGE      VARCHAR2(4000),
    STACK_TRACE        CLOB,
    ENDPOINT_NAME      VARCHAR2(100),
    RECORD_DATA        CLOB
);
```

### 2. Master Data Tables

```sql
-- Operators
CREATE TABLE TR2KSTG_OPERATORS (
    OPERATOR_ID        NUMBER NOT NULL,
    OPERATOR_NAME      VARCHAR2(200),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    PRIMARY KEY (OPERATOR_ID, EXTRACTION_DATE)
);

-- Plants
CREATE TABLE TR2KSTG_PLANTS (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    OPERATOR_ID        NUMBER,
    OPERATOR_NAME      VARCHAR2(200),
    SHORT_DESCRIPTION  VARCHAR2(100),
    PROJECT            VARCHAR2(100),
    LONG_DESCRIPTION   VARCHAR2(500),
    COMMON_LIB_PLANT_CODE VARCHAR2(10),
    INITIAL_REVISION   VARCHAR2(20),
    AREA_ID            NUMBER,
    AREA               VARCHAR2(100),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    PRIMARY KEY (PLANT_ID, EXTRACTION_DATE)
);

-- Issues
CREATE TABLE TR2KSTG_ISSUES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    TIMESTAMP,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    PRIMARY KEY (PLANT_ID, ISSUE_REVISION, EXTRACTION_DATE)
);
```

## UI Mockup - Oracle ETL Page

```
┌─────────────────────────────────────────────────────────────┐
│                 Oracle ETL Management                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ ▼ 1. Database Setup                                         │
│ ┌──────────────────────────────────────────────────────────┐
│ │ Connection Status: ● Connected to TR2000_STAGING         │
│ │                                                          │
│ │ [Create All Tables] [Drop All Tables] [Verify Schema]   │
│ └──────────────────────────────────────────────────────────┘
│                                                              │
│ ▼ 2. Master Data Loading                                    │
│ ┌──────────────────────────────────────────────────────────┐
│ │ Table                Status      Records   Actions       │
│ │ ─────────────────────────────────────────────────────── │
│ │ TR2KSTG_OPERATORS    ✓ Loaded    8         [Reload]     │
│ │ TR2KSTG_PLANTS       ✓ Loaded    217       [Reload]     │
│ │ TR2KSTG_ISSUES       ○ Empty     0         [Load All]   │
│ └──────────────────────────────────────────────────────────┘
│                                                              │
│ ▼ 3. Reference Data Loading                                 │
│ ┌──────────────────────────────────────────────────────────┐
│ │ Select Plant: [Dropdown] Revision: [Dropdown]           │
│ │                                                          │
│ │ □ PCS References     □ VSM References                   │
│ │ □ SC References      □ VDS References                   │
│ │ □ EDS References     □ MDS References                   │
│ │                                                          │
│ │ [Load Selected] [Load All References]                   │
│ └──────────────────────────────────────────────────────────┘
│                                                              │
│ ▼ 4. ETL Run History                                        │
│ ┌──────────────────────────────────────────────────────────┐
│ │ Run ID  Date/Time          Type    Status   Records     │
│ │ ────────────────────────────────────────────────────── │
│ │ 5       2025-08-16 14:30   FULL    SUCCESS  5,234      │
│ │ 4       2025-08-16 14:15   INCR    SUCCESS  125        │
│ │ 3       2025-08-16 14:00   FULL    FAILED   0          │
│ └──────────────────────────────────────────────────────────┘
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Service Architecture

```csharp
// OracleETLService.cs
public class OracleETLService
{
    private readonly string _connectionString;
    private readonly TR2000ApiService _apiService;
    private readonly ILogger<OracleETLService> _logger;
    
    public async Task<bool> TestConnection();
    public async Task<bool> CreateAllTables();
    public async Task<ETLResult> LoadOperators();
    public async Task<ETLResult> LoadPlants(int? operatorId = null);
    public async Task<ETLResult> LoadIssues(string plantId);
    public async Task<ETLResult> LoadReferences(string plantId, string issueRevision, string referenceType);
    public async Task<List<ETLRunHistory>> GetETLHistory(int limit = 10);
    public async Task<Dictionary<string, TableStatus>> GetTableStatuses();
}
```

## Key Design Decisions

1. **Table Naming Convention**: All tables prefixed with `TR2KSTG_`
2. **Incremental Loading**: Each table can be loaded independently
3. **Change Tracking**: Using EXTRACTION_DATE and IS_CURRENT for SCD Type 2
4. **Error Handling**: Comprehensive logging to TR2KSTG_ETL_ERROR_LOG
5. **Performance**: Batch processing for large datasets (VDS with 44K+ records)
6. **UI Feedback**: Real-time progress indicators and status updates
7. **Data Validation**: Verify buttons to check data integrity

## Success Criteria

- [ ] All 31 API endpoints have corresponding Oracle tables
- [ ] Data can be loaded incrementally or in full
- [ ] ETL process is logged and auditable
- [ ] UI provides clear visibility into ETL status
- [ ] Error handling prevents data corruption
- [ ] Performance handles 44K+ VDS records efficiently
- [ ] Change tracking enables historical analysis

## Risk Mitigation

1. **Large Dataset Handling**: Implement pagination and batch processing
2. **Network Timeouts**: Increase HTTP timeout for large endpoints
3. **Oracle Connection Issues**: Implement retry logic with exponential backoff
4. **Data Quality**: Add validation checks before and after loading
5. **Duplicate Prevention**: Use MERGE statements instead of INSERT

## Next Immediate Steps

1. Install Oracle.ManagedDataAccess.Core package
2. Update appsettings.json with connection string
3. Create OracleETLService class
4. Create first table (TR2KSTG_OPERATORS) as proof of concept
5. Create OracleETL.razor page with basic UI
6. Test end-to-end flow with operators data

## Documentation & Training

- Update README with Oracle setup instructions
- Create troubleshooting guide for common issues
- Document ETL best practices
- Provide SQL scripts for manual verification

---

**Last Updated**: 2025-08-16
**Author**: TR2000 Development Team
**Status**: Ready for Implementation