# ETL Migration Plan - From Complex to Simple

## Overview
This document provides a step-by-step implementation plan to migrate from the current complex ETL system to the simplified architecture defined in ETL_ARCHITECTURE.md.

## Current System Issues

### Critical Bugs Found
1. **Soft-delete bug**: Affects 11+ tables, deletes valid data when staging is empty
2. **Hash detection bug**: Causes staging to be empty, triggering soft-delete bug
3. **Cascade issues**: Inconsistent patterns, some cascades missing
4. **Plants table pattern**: Marks ALL plants invalid before merge (dangerous)
5. **Inconsistent patterns**: 3 different upsert patterns across tables

### Complexity Metrics
- 15+ packages with complex logic
- 28+ views filtering on is_valid
- 10+ test packages with 75+ procedures
- Multiple cascade triggers
- 5000+ lines of code

## Target Architecture
Implementing 4 separate ETL processes as defined in ETL_ARCHITECTURE.md:
1. **Reference Data ETL** - 9 reference types per issue
2. **PCS_LIST Load** - All PCS for each plant
3. **PCS Details ETL** - 6 endpoints per unique PCS
4. **VDS Catalog ETL** - Independent, 50,000+ items

## Migration Strategy

### Pre-Migration Checklist
- [ ] Backup current database
- [ ] Document current data (what plants/issues are loaded)
- [ ] Save current package definitions (for rollback)
- [ ] Notify users of migration
- [ ] Schedule maintenance window

## Phase 1: Backup Current State

### 1.1 Export Current Data
```sql
-- Create backup tables
CREATE TABLE BACKUP_PCS_REFERENCES AS SELECT * FROM PCS_REFERENCES WHERE is_valid = 'Y';
CREATE TABLE BACKUP_VDS_REFERENCES AS SELECT * FROM VDS_REFERENCES WHERE is_valid = 'Y';
CREATE TABLE BACKUP_MDS_REFERENCES AS SELECT * FROM MDS_REFERENCES WHERE is_valid = 'Y';
-- ... repeat for all reference tables

-- Document what's currently loaded
SELECT plant_id, issue_revision, COUNT(*) as ref_count
FROM PCS_REFERENCES 
WHERE is_valid = 'Y'
GROUP BY plant_id, issue_revision
ORDER BY plant_id, issue_revision;
```

### 1.2 Save Package Code
```bash
# Export all package definitions
sqlplus TR2000_STAGING/piping@localhost:1521/XEPDB1 <<EOF
SPOOL backup_packages.sql
SELECT DBMS_METADATA.GET_DDL('PACKAGE', package_name) 
FROM user_packages;
SPOOL OFF
EXIT
EOF
```

## Phase 2: Drop Unnecessary Objects

### 2.1 Drop All Views (28 total)
```sql
-- Monitoring views
DROP VIEW V_SYSTEM_HEALTH_DASHBOARD;
DROP VIEW V_ETL_PERFORMANCE_STATS;
DROP VIEW V_API_CALL_METRICS;
DROP VIEW V_ETL_ISSUE_LOAD_STATUS;
DROP VIEW V_CASCADE_IMPACT_SUMMARY;
DROP VIEW V_DATA_QUALITY_METRICS;
DROP VIEW V_REFERENCE_TYPE_SUMMARY;
DROP VIEW V_PCS_LOAD_SUMMARY;
DROP VIEW V_VDS_LOAD_STATUS;
DROP VIEW V_REFERENCE_COVERAGE;
DROP VIEW V_ISSUE_REFERENCE_STATS;
DROP VIEW V_PLANT_OVERVIEW;
DROP VIEW V_ETL_CURRENT_SELECTIONS;
DROP VIEW V_ETL_CRITICAL_PATHS;
DROP VIEW VETL_EFFECTIVE_SELECTIONS;
DROP VIEW V_ETL_STATS_SUMMARY;
DROP VIEW V_ETL_RUN_HISTORY;
DROP VIEW V_REFERENCE_CASCADE_STATUS;
DROP VIEW V_ETL_MONITORING_DASHBOARD;

-- Critical views
DROP VIEW VETL_CRITICAL_TABLES;
DROP VIEW VETL_REFERENCE_SUMMARY;
DROP VIEW VETL_SELECTION_CONTROL;
DROP VIEW VETL_LOAD_STATUS;
DROP VIEW VETL_CASCADE_MONITOR;

-- Any remaining views
DROP VIEW V_PCS_DETAILS_SUMMARY;
DROP VIEW V_SELECTION_PLANT_ISSUES;
DROP VIEW V_ACTIVE_ETL_SELECTIONS;
DROP VIEW V_ETL_DATA_SUMMARY;
```

### 2.2 Drop Test Packages
```sql
-- Test packages
DROP PACKAGE PKG_SIMPLE_TESTS;
DROP PACKAGE PKG_CONDUCTOR_TESTS;
DROP PACKAGE PKG_CONDUCTOR_EXTENDED;
DROP PACKAGE PKG_REFERENCE_COMPREHENSIVE;
DROP PACKAGE PKG_API_ERROR_TESTS;
DROP PACKAGE PKG_TRANSACTION_TESTS;
DROP PACKAGE PKG_ADVANCED_TESTS;
DROP PACKAGE PKG_RESILIENCE_TESTS;
DROP PACKAGE PKG_CASCADE_TESTS;
DROP PACKAGE PKG_TEST_UTILS;
```

### 2.3 Drop All Triggers
```sql
-- Cascade triggers
DROP TRIGGER TRG_PLANTS_TO_SELECTION;
DROP TRIGGER TRG_SELECTION_CASCADE;
DROP TRIGGER TRG_ISSUES_TO_SELECTION;
DROP TRIGGER TRG_CASCADE_ISSUE_TO_REFERENCES;

-- ETL tracking triggers
DROP TRIGGER trg_etl_run_to_stats;

-- Any other triggers
SELECT 'DROP TRIGGER ' || trigger_name || ';' 
FROM user_triggers 
WHERE table_name IN ('PLANTS', 'ISSUES', 'SELECTION_LOADER');
```

### 2.4 Drop Complex Packages (to be rebuilt)
```sql
-- Packages to completely rebuild
DROP PACKAGE PKG_CASCADE_MANAGER;
DROP PACKAGE PKG_UPSERT_PLANTS;
DROP PACKAGE PKG_UPSERT_ISSUES;
DROP PACKAGE PKG_UPSERT_REFERENCES;
DROP PACKAGE PKG_UPSERT_PCS_DETAILS;
DROP PACKAGE PKG_PARSE_PLANTS;
DROP PACKAGE PKG_PARSE_ISSUES;
DROP PACKAGE PKG_PARSE_REFERENCES;
DROP PACKAGE PKG_PARSE_PCS_DETAILS;
DROP PACKAGE PKG_API_CLIENT;
DROP PACKAGE PKG_API_CLIENT_REFERENCES;
DROP PACKAGE PKG_API_CLIENT_PCS_DETAILS;
DROP PACKAGE PKG_CONDUCTOR;
DROP PACKAGE PKG_ETL_OPERATIONS;
DROP PACKAGE PKG_TR2000_UTIL;
```

### 2.5 Drop Unnecessary Tables
```sql
-- Drop selection and control tables
DROP TABLE SELECTED_PLANTS CASCADE CONSTRAINTS;
DROP TABLE SELECTED_ISSUES CASCADE CONSTRAINTS;
DROP TABLE SELECTION_LOADER CASCADE CONSTRAINTS;

-- Drop main control tables (ETL_FILTER replaces these)
DROP TABLE PLANTS CASCADE CONSTRAINTS;
DROP TABLE ISSUES CASCADE CONSTRAINTS;

-- Optional: Drop cascade log if not needed
DROP TABLE CASCADE_LOG CASCADE CONSTRAINTS;
```

## Phase 3: Create New Simple Structure

### 3.1 Create ETL_FILTER Table
```sql
CREATE TABLE ETL_FILTER (
    filter_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    plant_id VARCHAR2(50) NOT NULL,
    plant_name VARCHAR2(200),
    issue_revision VARCHAR2(50) NOT NULL,
    added_date DATE DEFAULT SYSDATE,
    added_by_user_id VARCHAR2(100),
    CONSTRAINT uk_etl_filter UNIQUE(plant_id, issue_revision)
);

-- Add comments
COMMENT ON TABLE ETL_FILTER IS 'Single control table for ETL - defines what plant/issues to load';
COMMENT ON COLUMN ETL_FILTER.filter_id IS 'Auto-generated primary key';
COMMENT ON COLUMN ETL_FILTER.plant_id IS 'Plant ID to load data for';
COMMENT ON COLUMN ETL_FILTER.plant_name IS 'Plant name for reference';
COMMENT ON COLUMN ETL_FILTER.issue_revision IS 'Issue revision to load';
COMMENT ON COLUMN ETL_FILTER.added_date IS 'When this filter was added';
COMMENT ON COLUMN ETL_FILTER.added_by_user_id IS 'User who added this filter';

-- Create index for performance
CREATE INDEX idx_etl_filter_plant_issue ON ETL_FILTER(plant_id, issue_revision);
```

### 3.2 Create PCS_LIST Table
```sql
CREATE TABLE PCS_LIST (
    pcs_list_id NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    plant_id VARCHAR2(50) NOT NULL,
    pcs_name VARCHAR2(100) NOT NULL,
    revision VARCHAR2(50),
    status VARCHAR2(50),
    rev_date DATE,
    rating_class VARCHAR2(100),
    test_pressure VARCHAR2(100),
    material_group VARCHAR2(100),
    design_code VARCHAR2(100),
    created_date DATE DEFAULT SYSDATE,
    last_modified_date DATE DEFAULT SYSDATE
);

-- Add indexes
CREATE INDEX idx_pcs_list_plant ON PCS_LIST(plant_id);
CREATE INDEX idx_pcs_list_name ON PCS_LIST(pcs_name);

-- Create staging table (all VARCHAR2 for JSON parsing)
CREATE TABLE STG_PCS_LIST (
    plant_id VARCHAR2(50),
    pcs VARCHAR2(100),
    revision VARCHAR2(50),
    status VARCHAR2(50),
    rev_date VARCHAR2(50),
    rating_class VARCHAR2(100),
    test_pressure VARCHAR2(100),
    material_group VARCHAR2(100),
    design_code VARCHAR2(100)
);
```

### 3.3 Create VDS_LIST Table
```sql
CREATE TABLE VDS_LIST (
    vds_guid VARCHAR2(50) DEFAULT SYS_GUID() PRIMARY KEY,
    vds_name VARCHAR2(100) NOT NULL,
    revision VARCHAR2(50),
    status VARCHAR2(50),
    rev_date DATE,
    description VARCHAR2(500),
    valve_type_id NUMBER,
    rating_class_id NUMBER,
    material_group_id NUMBER,
    end_connection_id NUMBER,
    bore_id NUMBER,
    size_range VARCHAR2(200),
    custom_name VARCHAR2(200),
    subsegment_list VARCHAR2(500),
    created_date DATE DEFAULT SYSDATE,
    last_modified_date DATE DEFAULT SYSDATE
);

-- Add indexes
CREATE INDEX idx_vds_list_name ON VDS_LIST(vds_name);
CREATE INDEX idx_vds_list_status ON VDS_LIST(status);

-- Create staging table (all VARCHAR2 for JSON parsing)
CREATE TABLE STG_VDS_LIST (
    vds VARCHAR2(100),
    revision VARCHAR2(50),
    status VARCHAR2(50),
    rev_date VARCHAR2(50),
    description VARCHAR2(500),
    valve_type_id VARCHAR2(50),
    rating_class_id VARCHAR2(50),
    material_group_id VARCHAR2(50),
    end_connection_id VARCHAR2(50),
    bore_id VARCHAR2(50),
    size_range VARCHAR2(200),
    custom_name VARCHAR2(200),
    subsegment_list VARCHAR2(500)
);
```

### 3.4 Create Additional Staging Tables
```sql
-- All staging tables use VARCHAR2 for all columns
-- Create staging tables for all reference types
CREATE TABLE STG_PCS_REFERENCES (
    plant_id VARCHAR2(50),
    issue_revision VARCHAR2(50),
    pcs VARCHAR2(100),
    revision VARCHAR2(50),
    rev_date VARCHAR2(50),
    status VARCHAR2(50),
    official_revision VARCHAR2(50),
    -- ... other columns as VARCHAR2
);

-- Repeat for all other staging tables
-- STG_VDS_REFERENCES, STG_MDS_REFERENCES, etc.
-- STG_PCS_HEADER_PROPERTIES, STG_PCS_TEMP_PRESSURES, etc.
```

### 3.5 Populate ETL_FILTER from Current Data
```sql
-- Migrate current selections to ETL_FILTER
INSERT INTO ETL_FILTER (plant_id, plant_name, issue_revision, added_by_user_id)
SELECT DISTINCT 
    plant_id,
    CASE 
        WHEN plant_id = '34' THEN 'GRANE'
        WHEN plant_id = '124' THEN 'JSP2'
        ELSE 'Plant ' || plant_id
    END as plant_name,
    issue_revision,
    'MIGRATION' as added_by_user_id
FROM (
    -- Get from current references
    SELECT DISTINCT plant_id, issue_revision 
    FROM PCS_REFERENCES 
    WHERE is_valid = 'Y'
    UNION
    SELECT DISTINCT plant_id, issue_revision 
    FROM VDS_REFERENCES 
    WHERE is_valid = 'Y'
);

-- Verify migration
SELECT * FROM ETL_FILTER ORDER BY plant_id, issue_revision;
```

## Phase 4: Create New Simplified Packages

### 4.1 PKG_ETL_CONTROL
Main orchestration package for all ETL processes:
- **run_full_etl** - Process all entries in ETL_FILTER
- **run_pcs_list_etl** - Load PCS list for all plants
- **run_pcs_details_etl** - Load details for all PCS references
- **run_vds_catalog_etl** - Load entire VDS catalog (separate process)
- **clear_all_data_tables** - Clear all data except control/logging/VDS_LIST
- **clear_vds_list** - Clear VDS catalog (separate)
- **process_issue** - Process single plant/issue combination
- **log_etl_run** - Log execution details

### 4.2 PKG_API_CLIENT
Handles all API communication:

**Reference endpoints:**
- fetch_references(plant_id, issue_rev, ref_type) - 9 reference types
- fetch_pcs_list(plant_id) - All PCS for a plant

**PCS detail endpoints:**
- fetch_pcs_header(plant_id, pcs_name, revision)
- fetch_pcs_temp_pressures(plant_id, pcs_name, revision)
- fetch_pcs_pipe_sizes(plant_id, pcs_name, revision)
- fetch_pcs_pipe_elements(plant_id, pcs_name, revision)
- fetch_pcs_valve_elements(plant_id, pcs_name, revision)
- fetch_pcs_embedded_notes(plant_id, pcs_name, revision)

**VDS endpoint:**
- fetch_vds_list() - No parameters, returns 50,000+ items

**Utility:**
- store_raw_json(endpoint, plant_id, issue_rev, pcs_name, pcs_rev, payload)

### 4.3 PKG_ETL_PROCESSOR
Parses JSON and loads data:

**Reference processing:**
- Parse procedures for each reference type (JSON → STG_*)
- Load procedures for each reference type (STG_* → Final tables)

**PCS processing:**
- parse_pcs_list(raw_json_id)
- load_pcs_list(plant_id)
- Parse/load procedures for all 6 PCS detail types

**VDS processing:**
- parse_vds_list(raw_json_id)
- load_vds_list()

**Utilities:**
- extract_unique_pcs_from_references() - Gets distinct PCS for detail loading

## Phase 5: Implement Package Bodies

### 5.1 Implementation Approach

**Key Principles:**
1. **Clear First** - Always clear target tables before loading
2. **Simple INSERT** - No MERGE, no soft-deletes, just INSERT
3. **Type Conversion** - Convert VARCHAR2 staging data to proper types
4. **Error Logging** - Log all errors to ETL_ERROR_LOG
5. **Atomic Operations** - Use transactions appropriately

**Data Flow Pattern for all processes:**
```
API Call → RAW_JSON → STG_* (VARCHAR2) → Core Tables (typed)
```

**Clear Phase Implementation:**
- Clear all data tables except: ETL_FILTER, CONTROL_SETTINGS, logging tables, RAW_JSON
- VDS_LIST is NOT cleared in main ETL (separate process)
- All staging tables are truncated

## Phase 6: Testing

### 6.1 Test Each ETL Process Separately

**Test Reference Data ETL:**
1. Add test entry to ETL_FILTER
2. Run reference ETL
3. Verify 9 reference types loaded
4. Check RAW_JSON has audit records

**Test PCS_LIST Load:**
1. Run PCS list ETL for configured plants
2. Verify PCS_LIST populated
3. Compare count with API response

**Test PCS Details ETL:**
1. Ensure PCS_REFERENCES has data
2. Run PCS details ETL
3. Verify all 6 detail tables populated
4. Check for any missing PCS

**Test VDS Catalog ETL:**
1. Run VDS catalog ETL (separate)
2. Verify ~50,000 records loaded
3. Check for timeout handling

### 6.2 Recovery Test
1. Simulate failure mid-process
2. Verify system state
3. Re-run same ETL process
4. Confirm clean recovery (no duplicates, no partial data)

### 6.3 Compare with Backup
Compare record counts between old and new systems to ensure no data loss

## Phase 7: Create Simple Monitoring Views

### 7.1 Basic Summary View
```sql
CREATE OR REPLACE VIEW V_ETL_SUMMARY AS
SELECT 
    (SELECT COUNT(*) FROM ETL_FILTER) as filters_active,
    (SELECT COUNT(*) FROM PCS_REFERENCES) as pcs_references,
    (SELECT COUNT(*) FROM VDS_REFERENCES) as vds_references,
    (SELECT COUNT(*) FROM MDS_REFERENCES) as mds_references,
    (SELECT COUNT(DISTINCT plant_id || '|' || issue_revision) FROM PCS_REFERENCES) as issues_loaded,
    (SELECT MAX(created_date) FROM RAW_JSON) as last_api_call,
    (SELECT MAX(run_timestamp) FROM ETL_RUN_LOG WHERE status = 'SUCCESS') as last_successful_run
FROM DUAL;
```

### 7.2 Filter Status View
```sql
CREATE OR REPLACE VIEW V_ETL_FILTER_STATUS AS
SELECT 
    f.plant_id,
    f.plant_name,
    f.issue_revision,
    f.added_date,
    f.added_by_user_id,
    (SELECT COUNT(*) FROM PCS_REFERENCES r 
     WHERE r.plant_id = f.plant_id 
     AND r.issue_revision = f.issue_revision) as pcs_count,
    (SELECT COUNT(*) FROM VDS_REFERENCES r 
     WHERE r.plant_id = f.plant_id 
     AND r.issue_revision = f.issue_revision) as vds_count
FROM ETL_FILTER f
ORDER BY f.plant_id, f.issue_revision;
```

## Phase 8: Cleanup

### 8.1 Drop Backup Tables (after verification)
```sql
-- After confirming new system works
DROP TABLE BACKUP_PCS_REFERENCES;
DROP TABLE BACKUP_VDS_REFERENCES;
-- ... etc
```

### 8.2 Remove is_valid Columns (optional, later)
```sql
-- Can be done in future migration
ALTER TABLE PCS_REFERENCES DROP COLUMN is_valid;
ALTER TABLE VDS_REFERENCES DROP COLUMN is_valid;
-- ... etc
```

## Rollback Plan

If issues arise, rollback is simple:

### Option 1: Restore Packages Only
```sql
-- Run backup_packages.sql created earlier
@backup_packages.sql

-- Recreate PLANTS and ISSUES tables if needed
CREATE TABLE PLANTS AS SELECT * FROM BACKUP_PLANTS;
CREATE TABLE ISSUES AS SELECT * FROM BACKUP_ISSUES;
```

### Option 2: Full Database Restore
```bash
# Restore from database backup
impdp TR2000_STAGING/piping directory=DATA_PUMP_DIR dumpfile=backup.dmp
```

## Success Criteria

### Migration is successful when:
- [ ] ETL_FILTER table created and populated
- [ ] All old complex packages dropped
- [ ] 3 new simplified packages created
- [ ] Reference Data ETL loads 9 types per issue
- [ ] PCS_LIST loads all PCS for configured plants
- [ ] PCS Details ETL loads 6 detail tables
- [ ] VDS Catalog ETL loads 50,000+ items independently
- [ ] Clear phase works correctly (preserves control/logging/VDS_LIST)
- [ ] Recovery from failure works (just re-run)
- [ ] No more soft-delete bugs
- [ ] Performance acceptable for ~600 API calls per issue

## Implementation Checklist

### Phase 1: Backup (30 min)
- [ ] Backup current data (WHERE is_valid = 'Y')
- [ ] Export package definitions
- [ ] Document current ETL_FILTER equivalent data

### Phase 2: Drop Objects (30 min)
- [ ] Drop 28 views
- [ ] Drop test packages
- [ ] Drop triggers
- [ ] Drop old packages
- [ ] Drop PLANTS, ISSUES, SELECTED_* tables

### Phase 3: Create Structure (30 min)
- [ ] Create ETL_FILTER table
- [ ] Create PCS_LIST table
- [ ] Create VDS_LIST table
- [ ] Create all staging tables (VARCHAR2)
- [ ] Populate ETL_FILTER from backup

### Phase 4-5: Implement Packages (2 hours)
- [ ] Create PKG_ETL_CONTROL specification and body
- [ ] Create PKG_API_CLIENT specification and body
- [ ] Create PKG_ETL_PROCESSOR specification and body
- [ ] Implement clear phase logic
- [ ] Implement all parse/load procedures

### Phase 6: Testing (1 hour)
- [ ] Test each ETL process separately
- [ ] Test recovery scenarios
- [ ] Verify data completeness

## Post-Migration Tasks

1. **Update documentation**
2. **Train users on new system**
3. **Monitor for first week**
4. **Remove backup tables after 30 days**
5. **Consider removing is_valid columns in future**

## Notes

### What We're Keeping
- All table structures (just ignoring is_valid)
- RAW_JSON for audit trail
- ETL_RUN_LOG for history
- CONTROL_SETTINGS for configuration

### What We're Removing
- All soft-delete logic
- All cascade triggers
- Hash duplicate detection
- Complex MERGE statements
- PLANTS/ISSUES dependency

### Why This Works
- API is always available
- This is staging, not master data
- Simple is more reliable
- Easier to maintain
- Fewer bugs