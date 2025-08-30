# ETL Simplified Architecture - TR2000 Staging System

## System Philosophy

### Core Principles
1. **Staging/Transformation Only** - This is NOT a master data management system
2. **API is Truth** - The Equinor API is always the source of truth
3. **No Soft-Deletes** - No is_valid columns, no complex cascade logic
4. **Clear-Then-Load** - Always start fresh, no partial updates
5. **Simple Recovery** - If anything fails, just clear and restart

### Why This Approach?
- The API maintains all history and revisions
- We're building a separate master PCS system later
- Complexity was causing bugs (11+ critical issues found)
- Maintenance overhead exceeded benefits
- Simple is reliable

## Architecture Overview

### Three Distinct ETL Processes

#### 1. Reference Data ETL (Issue-based)
```
ETL_FILTER → Clear References → API Calls → Parse → Load
```
Loads reference data (PCS, VDS, MDS, EDS, VSK, ESK, PIPE_ELEMENT, SC, VSM) for specific plant/issue combinations.

#### 2. PCS Details ETL (Reference-dependent)
```
PCS_REFERENCES → Extract Unique PCS → API Calls → Parse → Load Details
```
Loads detailed PCS information based on PCS references already loaded.

#### 3. VDS Catalog ETL (Independent)
```
Manual Trigger → Clear VDS_LIST → API Call → Parse → Load
```
Loads entire VDS catalog (44,000+ items) - completely independent of plant/issue selections.

### Key Components
- **ETL_FILTER**: Control table for reference data loading
- **RAW_JSON**: Audit trail of all API calls
- **STG_* Tables**: Temporary parsing workspace
- **Final Tables**: Clean data ready for use
- **No PLANTS/ISSUES tables**: ETL_FILTER is the only control for references

## Core Tables

### 1. Control Tables
```sql
ETL_FILTER
├── filter_id (PK, auto-generated)
├── plant_id (NOT NULL)
├── plant_name (for reference)
├── issue_revision (NOT NULL)
├── added_date (DEFAULT SYSDATE)
├── added_by_user_id
└── UNIQUE(plant_id, issue_revision)

CONTROL_SETTINGS
├── setting_name (PK)
├── setting_value
├── description
└── last_modified
```

### 2. Audit Table
```sql
RAW_JSON
├── raw_json_id (PK)
├── endpoint
├── plant_id (nullable for VDS)
├── issue_revision (nullable for VDS)
├── pcs_name (nullable, for PCS details)
├── pcs_revision (nullable, for PCS details)
├── payload (CLOB)
├── created_date
└── batch_id
```

### 3. Reference Tables (9 types - Issue-dependent)
- PCS_REFERENCES (links to PCS details)
- VDS_REFERENCES
- MDS_REFERENCES
- EDS_REFERENCES
- VSK_REFERENCES
- ESK_REFERENCES
- PIPE_ELEMENT_REFERENCES
- SC_REFERENCES
- VSM_REFERENCES

### 4. PCS Detail Tables (Reference-dependent)
- PCS_HEADER_PROPERTIES
- PCS_TEMP_PRESSURES
- PCS_PIPE_SIZES
- PCS_PIPE_ELEMENTS
- PCS_VALVE_ELEMENTS
- PCS_EMBEDDED_NOTES

### 5. VDS Catalog Table (Independent)
```sql
VDS_LIST
├── vds_guid (PK)
├── vds_name
├── revision
├── status
├── rev_date
├── description
├── valve_type_id
├── rating_class_id
├── material_group_id
├── end_connection_id
├── bore_id
├── size_range
├── custom_name
├── subsegment_list
├── created_date
└── last_modified_date
```

### 6. Staging Tables (Temporary)
- STG_PCS_REFERENCES
- STG_VDS_REFERENCES
- STG_MDS_REFERENCES
- STG_EDS_REFERENCES
- STG_VSK_REFERENCES
- STG_ESK_REFERENCES
- STG_PIPE_ELEMENT_REFERENCES
- STG_SC_REFERENCES
- STG_VSM_REFERENCES
- STG_VDS_LIST
- STG_PCS_HEADER_PROPERTIES
- STG_PCS_TEMP_PRESSURES
- STG_PCS_PIPE_SIZES
- STG_PCS_PIPE_ELEMENTS
- STG_PCS_VALVE_ELEMENTS
- STG_PCS_EMBEDDED_NOTES

### 7. Control/Logging Tables
- ETL_STATS
- ETL_RUN_LOG
- ETL_ERROR_LOG

## Package Structure

### 1. PKG_ETL_CONTROL
**Purpose**: Orchestrate ETL processes

**Key Procedures:**
- **Reference Data ETL**: Main entry point, clear tables, process issues
- **PCS Details ETL**: Load details for all PCS references  
- **VDS Catalog ETL**: Load entire VDS catalog
- **Utilities**: Logging and error handling

### 2. PKG_API_CLIENT
**Purpose**: Handle all API communications

**Key Functions:**
- **Reference endpoints**: Fetch data for 9 reference types
- **PCS endpoints**: 6 detail endpoints (header, temp/pressure, sizes, elements, valves, notes)
- **VDS endpoint**: Single endpoint for entire catalog
- **RAW_JSON storage**: Store all API responses for audit

### 3. PKG_ETL_PROCESSOR
**Purpose**: Parse JSON and load data

**Key Procedure Groups:**
- **Reference parsing**: JSON to staging for 9 reference types
- **Reference loading**: Staging to final tables
- **PCS Details parsing**: JSON to staging for 6 detail types
- **PCS Details loading**: Staging to final detail tables
- **VDS Catalog**: Parse and load VDS items
- **Utilities**: Extract unique PCS combinations

## Detailed ETL Processes

### Process 1: Reference Data ETL

#### Step 1: User Setup
```sql
-- User adds what they want to load
INSERT INTO ETL_FILTER (plant_id, plant_name, issue_revision, added_by_user_id)
VALUES ('34', 'GRANE', '4.2', 'john.doe');
```

#### Step 2: Run Reference ETL
The main ETL procedure performs these conceptual steps:
1. **Clear all reference tables** - Remove existing data
2. **Process each ETL_FILTER entry** - Loop through configured plant/issue combinations
3. **Log completion** - Record success in ETL_RUN_LOG

#### Step 3: Process Single Issue
For each plant/issue combination, the process:
1. **Loops through 9 reference types** (PCS, VDS, MDS, EDS, VSK, ESK, PIPE-ELEMENT, SC, VSM)
2. **For each reference type:**
   - Fetches data from API endpoint
   - Stores raw response in RAW_JSON for audit
   - Parses JSON to staging tables
   - Loads from staging to final reference tables
3. **Commits after successful processing**

### Process 2: PCS Details ETL

#### Step 1: Extract Unique PCS from References
The PCS details ETL process:
1. **Clears all PCS detail tables** - Start fresh
2. **Extracts unique PCS combinations** - Gets distinct plant_id, pcs_name, and official_revision from PCS_REFERENCES
3. **Processes each unique PCS** - Calls detail endpoints for each combination
4. **Logs completion** - Records success

#### Step 2: Process PCS Details
For each unique PCS combination, the process calls 6 different API endpoints:
1. **Header and Properties** - General PCS information
2. **Temperature/Pressure** - Design conditions
3. **Pipe Sizes** - Size specifications
4. **Pipe Elements** - Material components
5. **Valve Elements** - Valve specifications
6. **Embedded Notes** - Additional documentation

Each endpoint follows the same pattern:
- Fetch data from API
- Store raw JSON response
- Parse to staging table
- Load to final detail table
- Handle errors with rollback

### Process 3: VDS Catalog ETL (Independent)

#### VDS Catalog Load Process
The VDS catalog ETL is completely independent and follows these steps:
1. **Clear VDS_LIST table** - Remove existing catalog
2. **Fetch entire VDS catalog** - Single API call returns 44,000+ items
3. **Store in RAW_JSON** - Audit trail of the large response
4. **Parse to staging** - Extract VDS items to STG_VDS_LIST
5. **Load to final table** - Simple INSERT from staging
6. **Log completion** - Record count and success

Key characteristics:
- **No dependencies** - Can run anytime, independent of other ETL processes
- **Single API call** - One endpoint returns entire catalog
- **Large volume** - Typically 44,000+ items, takes 30+ seconds
- **Simple recovery** - If fails, just run again

## Error Handling Strategy

### Failure Scenarios by Process Type

#### Reference Data ETL Failures
1. **API Call Fails**: 
   - Old data remains (nothing was cleared yet)
   - Fix issue and run again: `EXEC PKG_ETL_CONTROL.run_full_etl();`

2. **Parse/Load Fails**:
   - Partial data in reference tables
   - Run full ETL again (will clear and reload)

#### PCS Details ETL Failures
1. **Missing PCS Reference**:
   - Skip that PCS and continue with others
   - Log error for review

2. **API Call Fails for Specific PCS**:
   - That PCS's details remain empty
   - Can retry just PCS details: `EXEC PKG_ETL_CONTROL.run_pcs_details_etl();`

#### VDS Catalog ETL Failures
1. **API Timeout** (44,000+ items):
   - No data loaded (transaction rolled back)
   - Retry: `EXEC PKG_ETL_CONTROL.run_vds_catalog_etl();`

2. **Partial Load**:
   - Clear and reload: `EXEC PKG_ETL_CONTROL.run_vds_catalog_etl();`

### Recovery Procedures
Recovery is straightforward - just rerun the failed process:
- **Reference Data issues**: Run the reference ETL again
- **PCS Details issues**: Run the PCS details ETL again  
- **VDS Catalog issues**: Run the VDS catalog ETL again

Since each process clears its tables first, rerunning is always safe. For a complete system refresh, run all three processes in sequence.

## What We Eliminated

### Removed Complexity
- ❌ Soft-delete logic (is_valid columns)
- ❌ Cascade triggers
- ❌ Hash duplicate detection  
- ❌ MERGE statements
- ❌ Complex DELETE WHERE conditions
- ❌ PLANTS/ISSUES tables
- ❌ SELECTED_PLANTS/SELECTED_ISSUES tables
- ❌ SELECTION_LOADER table
- ❌ 15+ complex packages
- ❌ 28+ views with is_valid filters
- ❌ 75+ test procedures

### Removed Bugs
- ❌ Soft-delete bug (11 tables affected)
- ❌ Cascade trigger issues
- ❌ Hash detection causing empty staging
- ❌ Plants "mark all invalid" pattern
- ❌ Inconsistent upsert patterns

## Benefits of Simplified Architecture

### Reliability
- **Predictable**: Always matches API exactly
- **Atomic**: All or nothing, no partial states
- **Recoverable**: One recovery pattern for all failures

### Maintainability  
- **Simple**: ~500 lines vs ~5000 lines
- **Consistent**: Same pattern everywhere
- **Understandable**: New developer can learn in 30 minutes

### Performance
- **Fast Clears**: Simple DELETE statements
- **Fast Loads**: Simple INSERT statements
- **No Complex Logic**: No triggers firing, no cascades

## Processing Order and Dependencies

### Execution Sequence
1. **VDS Catalog** (Independent - can run anytime)
   - No dependencies
   - Single API call
   - ~44,000 items

2. **Reference Data** (Issue-based)
   - Depends on ETL_FILTER entries
   - 9 API calls per issue
   - Must complete before PCS details

3. **PCS Details** (Reference-dependent)
   - Depends on PCS_REFERENCES
   - 6 API calls per unique PCS
   - Can run after references loaded

### API Call Volumes
For a typical issue with 100 PCS references:
- **Reference ETL**: 9 API calls (one per reference type)
- **PCS Details ETL**: ~600 API calls (6 endpoints × 100 unique PCS)
- **VDS Catalog ETL**: 1 API call (entire catalog)

Total: ~610 API calls per issue + 1 for VDS catalog

## Summary

The new architecture separates ETL into three distinct processes:

1. **Reference Data ETL**: Issue-based loading controlled by ETL_FILTER
2. **PCS Details ETL**: Loads detailed information for PCS references
3. **VDS Catalog ETL**: Independent catalog load

**Old System**: API → Plants → Issues → Selected → Cascades → Soft-deletes → Complex Data
**New System**: 
- References: ETL_FILTER → API → Clear → Load
- PCS Details: PCS_REFERENCES → API → Clear → Load
- VDS Catalog: Manual → API → Clear → Load

This approach is ideal for a staging system where:
- The API is the source of truth
- Different data types have different update frequencies
- Simplicity and reliability are priorities
- Clear separation of concerns is needed