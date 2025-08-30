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
```sql
PROCEDURES:
-- Reference Data ETL
- run_full_etl()                -- Main entry for references
- clear_all_reference_tables()  -- Clear reference data only
- process_issue()               -- Process single issue

-- PCS Details ETL  
- run_pcs_details_etl()        -- Load details for all PCS references
- clear_all_pcs_details()      -- Clear PCS detail tables only
- process_pcs_details()        -- Process details for one PCS

-- VDS Catalog ETL
- run_vds_catalog_etl()        -- Load entire VDS catalog
- clear_vds_list()             -- Clear VDS_LIST table

-- Utilities
- log_etl_run()                -- Log ETL execution
```

### 2. PKG_API_CLIENT
**Purpose**: Handle all API communications
```sql
FUNCTIONS:
-- Reference endpoints
- fetch_references(plant_id, issue_rev, ref_type) RETURN CLOB

-- PCS endpoints
- fetch_pcs_list(plant_id) RETURN CLOB
- fetch_pcs_header(plant_id, pcs_name, revision) RETURN CLOB
- fetch_pcs_temp_pressures(plant_id, pcs_name, revision) RETURN CLOB
- fetch_pcs_pipe_sizes(plant_id, pcs_name, revision) RETURN CLOB
- fetch_pcs_pipe_elements(plant_id, pcs_name, revision) RETURN CLOB
- fetch_pcs_valve_elements(plant_id, pcs_name, revision) RETURN CLOB
- fetch_pcs_embedded_notes(plant_id, pcs_name, revision) RETURN CLOB

-- VDS endpoints
- fetch_vds_list() RETURN CLOB

PROCEDURES:
- store_raw_json(endpoint, plant_id, issue_rev, pcs_name, pcs_rev, payload)
```

### 3. PKG_ETL_PROCESSOR
**Purpose**: Parse JSON and load data
```sql
PROCEDURES:
-- Reference parsing (JSON → STG)
- parse_pcs_references(raw_json_id)
- parse_vds_references(raw_json_id)
- parse_mds_references(raw_json_id)
- parse_eds_references(raw_json_id)
- parse_vsk_references(raw_json_id)
- parse_esk_references(raw_json_id)
- parse_pipe_element_references(raw_json_id)
- parse_sc_references(raw_json_id)
- parse_vsm_references(raw_json_id)

-- Reference loading (STG → Final)
- load_pcs_references(plant_id, issue_rev)
- load_vds_references(plant_id, issue_rev)
- load_mds_references(plant_id, issue_rev)
- load_eds_references(plant_id, issue_rev)
- load_vsk_references(plant_id, issue_rev)
- load_esk_references(plant_id, issue_rev)
- load_pipe_element_references(plant_id, issue_rev)
- load_sc_references(plant_id, issue_rev)
- load_vsm_references(plant_id, issue_rev)

-- PCS Details parsing
- parse_pcs_header_properties(raw_json_id)
- parse_pcs_temp_pressures(raw_json_id)
- parse_pcs_pipe_sizes(raw_json_id)
- parse_pcs_pipe_elements(raw_json_id)
- parse_pcs_valve_elements(raw_json_id)
- parse_pcs_embedded_notes(raw_json_id)

-- PCS Details loading
- load_pcs_header_properties(plant_id, pcs_name, revision)
- load_pcs_temp_pressures(plant_id, pcs_name, revision)
- load_pcs_pipe_sizes(plant_id, pcs_name, revision)
- load_pcs_pipe_elements(plant_id, pcs_name, revision)
- load_pcs_valve_elements(plant_id, pcs_name, revision)
- load_pcs_embedded_notes(plant_id, pcs_name, revision)

-- VDS Catalog
- parse_vds_list(raw_json_id)
- load_vds_list()

-- Utilities
- extract_unique_pcs_from_references() RETURN pcs_cursor
```

## Detailed ETL Processes

### Process 1: Reference Data ETL

#### Step 1: User Setup
```sql
-- User adds what they want to load
INSERT INTO ETL_FILTER (plant_id, plant_name, issue_revision, added_by_user_id)
VALUES ('34', 'GRANE', '4.2', 'john.doe');
```

#### Step 2: Run Reference ETL
```sql
PROCEDURE run_full_etl IS
BEGIN
    -- 1. Clear all reference tables
    clear_all_reference_tables();
    
    -- 2. Process each entry in ETL_FILTER
    FOR rec IN (SELECT * FROM ETL_FILTER) LOOP
        process_issue(rec.plant_id, rec.issue_revision);
    END LOOP;
    
    -- 3. Log completion
    log_etl_run('REFERENCE_ETL', 'Full reference ETL completed');
END;
```

#### Step 3: Process Single Issue
```sql
PROCEDURE process_issue(p_plant_id VARCHAR2, p_issue_rev VARCHAR2) IS
    l_json CLOB;
    l_raw_id NUMBER;
BEGIN
    -- Fetch and store each reference type
    FOR ref_type IN ('PCS', 'VDS', 'MDS', 'EDS', 'VSK', 'ESK', 
                     'PIPE-ELEMENT', 'SC', 'VSM') LOOP
        
        -- Get from API
        l_json := PKG_API_CLIENT.fetch_references(p_plant_id, p_issue_rev, ref_type);
        
        -- Store in RAW_JSON
        l_raw_id := PKG_API_CLIENT.store_raw_json(
            ref_type, p_plant_id, p_issue_rev, NULL, NULL, l_json);
        
        -- Parse to staging
        CASE ref_type
            WHEN 'PCS' THEN parse_pcs_references(l_raw_id);
            WHEN 'VDS' THEN parse_vds_references(l_raw_id);
            -- ... etc
        END CASE;
        
        -- Load to final table
        CASE ref_type
            WHEN 'PCS' THEN load_pcs_references(p_plant_id, p_issue_rev);
            WHEN 'VDS' THEN load_vds_references(p_plant_id, p_issue_rev);
            -- ... etc
        END CASE;
    END LOOP;
END;
```

### Process 2: PCS Details ETL

#### Step 1: Extract Unique PCS from References
```sql
PROCEDURE run_pcs_details_etl IS
    CURSOR c_pcs IS
        SELECT DISTINCT plant_id, pcs_name, official_revision
        FROM PCS_REFERENCES
        WHERE official_revision IS NOT NULL;
BEGIN
    -- 1. Clear all PCS detail tables
    clear_all_pcs_details();
    
    -- 2. Process each unique PCS
    FOR rec IN c_pcs LOOP
        process_pcs_details(rec.plant_id, rec.pcs_name, rec.official_revision);
    END LOOP;
    
    -- 3. Log completion
    log_etl_run('PCS_DETAILS_ETL', 'PCS details ETL completed');
END;
```

#### Step 2: Process PCS Details
```sql
PROCEDURE process_pcs_details(
    p_plant_id VARCHAR2, 
    p_pcs_name VARCHAR2, 
    p_revision VARCHAR2
) IS
    l_json CLOB;
    l_raw_id NUMBER;
BEGIN
    -- 1. Fetch header and properties
    l_json := PKG_API_CLIENT.fetch_pcs_header(p_plant_id, p_pcs_name, p_revision);
    l_raw_id := PKG_API_CLIENT.store_raw_json(
        'PCS_HEADER', p_plant_id, NULL, p_pcs_name, p_revision, l_json);
    parse_pcs_header_properties(l_raw_id);
    load_pcs_header_properties(p_plant_id, p_pcs_name, p_revision);
    
    -- 2. Fetch temperature/pressure
    l_json := PKG_API_CLIENT.fetch_pcs_temp_pressures(p_plant_id, p_pcs_name, p_revision);
    l_raw_id := PKG_API_CLIENT.store_raw_json(
        'PCS_TEMP_PRESS', p_plant_id, NULL, p_pcs_name, p_revision, l_json);
    parse_pcs_temp_pressures(l_raw_id);
    load_pcs_temp_pressures(p_plant_id, p_pcs_name, p_revision);
    
    -- 3. Fetch pipe sizes
    l_json := PKG_API_CLIENT.fetch_pcs_pipe_sizes(p_plant_id, p_pcs_name, p_revision);
    l_raw_id := PKG_API_CLIENT.store_raw_json(
        'PCS_PIPE_SIZES', p_plant_id, NULL, p_pcs_name, p_revision, l_json);
    parse_pcs_pipe_sizes(l_raw_id);
    load_pcs_pipe_sizes(p_plant_id, p_pcs_name, p_revision);
    
    -- 4. Fetch pipe elements
    l_json := PKG_API_CLIENT.fetch_pcs_pipe_elements(p_plant_id, p_pcs_name, p_revision);
    l_raw_id := PKG_API_CLIENT.store_raw_json(
        'PCS_PIPE_ELEMENTS', p_plant_id, NULL, p_pcs_name, p_revision, l_json);
    parse_pcs_pipe_elements(l_raw_id);
    load_pcs_pipe_elements(p_plant_id, p_pcs_name, p_revision);
    
    -- 5. Fetch valve elements
    l_json := PKG_API_CLIENT.fetch_pcs_valve_elements(p_plant_id, p_pcs_name, p_revision);
    l_raw_id := PKG_API_CLIENT.store_raw_json(
        'PCS_VALVE_ELEMENTS', p_plant_id, NULL, p_pcs_name, p_revision, l_json);
    parse_pcs_valve_elements(l_raw_id);
    load_pcs_valve_elements(p_plant_id, p_pcs_name, p_revision);
    
    -- 6. Fetch embedded notes
    l_json := PKG_API_CLIENT.fetch_pcs_embedded_notes(p_plant_id, p_pcs_name, p_revision);
    l_raw_id := PKG_API_CLIENT.store_raw_json(
        'PCS_EMBEDDED_NOTES', p_plant_id, NULL, p_pcs_name, p_revision, l_json);
    parse_pcs_embedded_notes(l_raw_id);
    load_pcs_embedded_notes(p_plant_id, p_pcs_name, p_revision);
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        log_etl_error('PCS_DETAILS', p_pcs_name || '/' || p_revision, SQLERRM);
        ROLLBACK;
END;
```

### Process 3: VDS Catalog ETL (Independent)

#### Run VDS Catalog Load
```sql
PROCEDURE run_vds_catalog_etl IS
    l_json CLOB;
    l_raw_id NUMBER;
    v_count NUMBER;
BEGIN
    -- 1. Clear VDS_LIST table
    clear_vds_list();
    
    -- 2. Fetch entire VDS catalog (44,000+ items)
    l_json := PKG_API_CLIENT.fetch_vds_list();
    
    -- 3. Store in RAW_JSON
    l_raw_id := PKG_API_CLIENT.store_raw_json(
        'VDS_CATALOG', NULL, NULL, NULL, NULL, l_json);
    
    -- 4. Parse to staging
    parse_vds_list(l_raw_id);
    
    -- 5. Load to final table
    load_vds_list();
    
    -- 6. Get count
    SELECT COUNT(*) INTO v_count FROM VDS_LIST;
    
    -- 7. Log completion
    log_etl_run('VDS_CATALOG_ETL', 'Loaded ' || v_count || ' VDS items');
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        log_etl_error('VDS_CATALOG', 'FULL_LOAD', SQLERRM);
        ROLLBACK;
        RAISE;
END;
```

#### Simple VDS Load Pattern
```sql
PROCEDURE load_vds_list IS
BEGIN
    INSERT INTO VDS_LIST (
        vds_guid, vds_name, revision, status, rev_date,
        description, valve_type_id, rating_class_id,
        material_group_id, end_connection_id, bore_id,
        size_range, custom_name, subsegment_list,
        created_date, last_modified_date
    )
    SELECT 
        SYS_GUID(), vds, revision, status, 
        TO_DATE(rev_date, 'YYYY-MM-DD'),
        description, valve_type_id, rating_class_id,
        material_group_id, end_connection_id, bore_id,
        size_range, custom_name, subsegment_list,
        SYSDATE, SYSDATE
    FROM STG_VDS_LIST;
    
    DBMS_OUTPUT.PUT_LINE('Loaded ' || SQL%ROWCOUNT || ' VDS catalog items');
END;
```

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
```sql
-- For Reference Data issues:
EXEC PKG_ETL_CONTROL.run_full_etl();

-- For PCS Details issues:
EXEC PKG_ETL_CONTROL.run_pcs_details_etl();

-- For VDS Catalog issues:
EXEC PKG_ETL_CONTROL.run_vds_catalog_etl();

-- Nuclear option - reload everything:
BEGIN
    PKG_ETL_CONTROL.run_full_etl();
    PKG_ETL_CONTROL.run_pcs_details_etl();
    PKG_ETL_CONTROL.run_vds_catalog_etl();
END;
/
```

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