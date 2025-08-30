# ETL Migration Plan - From Complex to Simple

## Overview
This document provides a step-by-step plan to migrate from the current complex ETL system (with soft-deletes, cascades, and triggers) to a simplified clear-and-load architecture.

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

### 3.2 Create VDS_LIST Table
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

-- Create staging table
CREATE TABLE STG_VDS_LIST AS SELECT * FROM VDS_LIST WHERE 1=0;
```

### 3.3 Populate ETL_FILTER from Current Data
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
```sql
CREATE OR REPLACE PACKAGE PKG_ETL_CONTROL AS
    -- Main ETL procedure
    PROCEDURE run_full_etl;
    
    -- Clear all data tables (not control)
    PROCEDURE clear_all_data_tables;
    
    -- Process single issue
    PROCEDURE process_issue(
        p_plant_id VARCHAR2,
        p_issue_revision VARCHAR2
    );
    
    -- Logging
    PROCEDURE log_etl_run(
        p_status VARCHAR2,
        p_message VARCHAR2
    );
END PKG_ETL_CONTROL;
/
```

### 4.2 PKG_API_CLIENT
```sql
CREATE OR REPLACE PACKAGE PKG_API_CLIENT AS
    -- Fetch reference data
    FUNCTION fetch_references(
        p_plant_id VARCHAR2,
        p_issue_rev VARCHAR2,
        p_ref_type VARCHAR2
    ) RETURN CLOB;
    
    -- Fetch PCS list
    FUNCTION fetch_pcs_list(
        p_plant_id VARCHAR2
    ) RETURN CLOB;
    
    -- Fetch PCS details
    FUNCTION fetch_pcs_details(
        p_plant_id VARCHAR2,
        p_pcs_name VARCHAR2,
        p_revision VARCHAR2
    ) RETURN CLOB;
    
    -- Store in RAW_JSON
    FUNCTION store_raw_json(
        p_endpoint VARCHAR2,
        p_plant_id VARCHAR2,
        p_issue_rev VARCHAR2,
        p_payload CLOB
    ) RETURN NUMBER;
END PKG_API_CLIENT;
/
```

### 4.3 PKG_ETL_PROCESSOR
```sql
CREATE OR REPLACE PACKAGE PKG_ETL_PROCESSOR AS
    -- Parse procedures (one per reference type)
    PROCEDURE parse_pcs_references(p_raw_json_id NUMBER);
    PROCEDURE parse_vds_references(p_raw_json_id NUMBER);
    PROCEDURE parse_mds_references(p_raw_json_id NUMBER);
    PROCEDURE parse_eds_references(p_raw_json_id NUMBER);
    PROCEDURE parse_vsk_references(p_raw_json_id NUMBER);
    PROCEDURE parse_esk_references(p_raw_json_id NUMBER);
    PROCEDURE parse_pipe_element_references(p_raw_json_id NUMBER);
    PROCEDURE parse_sc_references(p_raw_json_id NUMBER);
    PROCEDURE parse_vsm_references(p_raw_json_id NUMBER);
    
    -- Load procedures (STG to final)
    PROCEDURE load_pcs_references(p_plant_id VARCHAR2, p_issue_rev VARCHAR2);
    PROCEDURE load_vds_references(p_plant_id VARCHAR2, p_issue_rev VARCHAR2);
    PROCEDURE load_mds_references(p_plant_id VARCHAR2, p_issue_rev VARCHAR2);
    PROCEDURE load_eds_references(p_plant_id VARCHAR2, p_issue_rev VARCHAR2);
    PROCEDURE load_vsk_references(p_plant_id VARCHAR2, p_issue_rev VARCHAR2);
    PROCEDURE load_esk_references(p_plant_id VARCHAR2, p_issue_rev VARCHAR2);
    PROCEDURE load_pipe_element_references(p_plant_id VARCHAR2, p_issue_rev VARCHAR2);
    PROCEDURE load_sc_references(p_plant_id VARCHAR2, p_issue_rev VARCHAR2);
    PROCEDURE load_vsm_references(p_plant_id VARCHAR2, p_issue_rev VARCHAR2);
    
    -- Load PCS details
    PROCEDURE load_pcs_details(p_plant_id VARCHAR2, p_issue_rev VARCHAR2);
END PKG_ETL_PROCESSOR;
/
```

## Phase 5: Implement Package Bodies

### 5.1 Sample Implementation Pattern
```sql
-- Example: Simple load procedure
PROCEDURE load_pcs_references(p_plant_id VARCHAR2, p_issue_rev VARCHAR2) IS
    v_count NUMBER;
BEGIN
    -- Simple INSERT from staging
    INSERT INTO PCS_REFERENCES (
        reference_guid, plant_id, issue_revision, pcs_name,
        revision, rev_date, status, official_revision,
        revision_suffix, rating_class, material_group,
        historical_pcs, delta, created_date, last_modified_date
    )
    SELECT 
        SYS_GUID(), plant_id, issue_revision, pcs,
        revision, TO_DATE(rev_date, 'YYYY-MM-DD'), status, 
        official_revision, revision_suffix, rating_class,
        material_group, historical_pcs, delta,
        SYSDATE, SYSDATE
    FROM STG_PCS_REFERENCES
    WHERE plant_id = p_plant_id 
      AND issue_revision = p_issue_rev;
    
    v_count := SQL%ROWCOUNT;
    DBMS_OUTPUT.PUT_LINE('Loaded ' || v_count || ' PCS references');
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, 
            'Error loading PCS references: ' || SQLERRM);
END load_pcs_references;
```

## Phase 6: Testing

### 6.1 Basic Functionality Test
```sql
-- 1. Clear everything
EXEC PKG_ETL_CONTROL.clear_all_data_tables();

-- 2. Verify empty
SELECT 'PCS_REFERENCES' as table_name, COUNT(*) as count FROM PCS_REFERENCES
UNION ALL
SELECT 'VDS_REFERENCES', COUNT(*) FROM VDS_REFERENCES;

-- 3. Run full ETL
EXEC PKG_ETL_CONTROL.run_full_etl();

-- 4. Verify data loaded
SELECT plant_id, issue_revision, COUNT(*) as ref_count
FROM PCS_REFERENCES
GROUP BY plant_id, issue_revision;
```

### 6.2 Recovery Test
```sql
-- 1. Start ETL and force failure
-- 2. Verify partial data
-- 3. Run ETL again
EXEC PKG_ETL_CONTROL.run_full_etl();
-- 4. Verify clean reload
```

### 6.3 Compare with Backup
```sql
-- Compare counts with backup
SELECT 'BACKUP' as source, COUNT(*) as pcs_count FROM BACKUP_PCS_REFERENCES
UNION ALL
SELECT 'NEW', COUNT(*) FROM PCS_REFERENCES;
```

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
- [ ] All data from ETL_FILTER is loaded
- [ ] Counts match or exceed backup counts
- [ ] No errors in ETL_RUN_LOG
- [ ] Performance is same or better
- [ ] Recovery from failure works
- [ ] Users can add/remove filters
- [ ] Full ETL completes successfully

## Timeline

### Estimated Duration: 4-5 hours
1. **Backup**: 30 minutes
2. **Drop objects**: 30 minutes
3. **Create new structure**: 30 minutes
4. **Implement packages**: 2 hours
5. **Testing**: 1 hour
6. **Documentation**: 30 minutes

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