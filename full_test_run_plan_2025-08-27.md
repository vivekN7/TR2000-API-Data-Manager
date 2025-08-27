# Full ETL System Test Run Plan
**Date**: 2025-08-27  
**Purpose**: Complete end-to-end validation of TR2000 ETL system after Task 7 completion

## Prerequisites
- Database connection: `sqlplus TR2000_STAGING/piping@localhost:1521/XEPDB1`
- All Task 7 fixes have been applied
- Two-table selection design (SELECTED_PLANTS, SELECTED_ISSUES) is in place

## Test Execution Steps

### Step 1: Clean Start
```sql
SET SERVEROUTPUT ON SIZE UNLIMITED
-- Remove any test data
EXEC PKG_TEST_ISOLATION.clean_all_test_data;

-- Verify no test contamination
EXEC PKG_TEST_ISOLATION.validate_no_test_contamination;
```

### Step 2: Verify Current State
```sql
-- Check selected plants and issues
SELECT 'PLANTS' as type, plant_id, is_active FROM SELECTED_PLANTS
UNION ALL
SELECT 'ISSUES', plant_id || '/' || issue_revision, is_active FROM SELECTED_ISSUES
ORDER BY 1, 2;

-- Should show:
-- PLANTS: 124 (JSP2), 34 (GRANE)
-- ISSUES: 124/3.3, 34/3.0, 34/4.2
```

### Step 3: Full API Refresh
```sql
SET SERVEROUTPUT ON SIZE UNLIMITED
EXEC refresh_all_data_from_api;
```

Expected output:
- Step 1: Cleaning test data... (0 records)
- Step 2: Refreshing plants... (130 plants)
- Step 3: Processing selected issues... (fetching references for each)
- Step 4: Validating data integrity... (no contamination)
- Step 5: Summary showing loaded records

### Step 4: Run Test Suites
```sql
-- Run critical tests
EXEC PKG_SIMPLE_TESTS.run_critical_tests;
-- Expected: 6/8 PASSED (2 test data failures are OK)

-- Run comprehensive reference tests
EXEC PKG_REFERENCE_COMPREHENSIVE_TESTS.run_all_reference_tests;
-- Expected: 3/3 PASSED
```

### Step 5: Verify Reference Data
```sql
-- Check all reference tables
SELECT 
    table_name,
    COUNT(*) as total,
    COUNT(CASE WHEN is_valid = 'Y' THEN 1 END) as valid,
    COUNT(CASE WHEN is_valid = 'N' THEN 1 END) as invalid
FROM (
    SELECT 'PCS_REFERENCES' as table_name, is_valid FROM PCS_REFERENCES
    UNION ALL SELECT 'SC_REFERENCES', is_valid FROM SC_REFERENCES
    UNION ALL SELECT 'VSM_REFERENCES', is_valid FROM VSM_REFERENCES
    UNION ALL SELECT 'VDS_REFERENCES', is_valid FROM VDS_REFERENCES
    UNION ALL SELECT 'EDS_REFERENCES', is_valid FROM EDS_REFERENCES
    UNION ALL SELECT 'MDS_REFERENCES', is_valid FROM MDS_REFERENCES
    UNION ALL SELECT 'VSK_REFERENCES', is_valid FROM VSK_REFERENCES
    UNION ALL SELECT 'ESK_REFERENCES', is_valid FROM ESK_REFERENCES
    UNION ALL SELECT 'PIPE_ELEMENT_REF', is_valid FROM PIPE_ELEMENT_REFERENCES
)
GROUP BY table_name
ORDER BY table_name;
```

**Expected Results:**
```
PCS_REFERENCES:          76 valid, 0 invalid
VDS_REFERENCES:         588 valid, 0 invalid
MDS_REFERENCES:         254 valid, 0 invalid
PIPE_ELEMENT_REFERENCES: 373 valid, 0 invalid
VSK_REFERENCES:          62 valid, 0 invalid
EDS_REFERENCES:           5 valid, 0 invalid
SC_REFERENCES:            1 valid, 0 invalid
VSM_REFERENCES:           1 valid, 0 invalid
ESK_REFERENCES:           0 (empty from API)
TOTAL:                1,360 valid records
```

### Step 6: Test Cascade Functionality
```sql
-- Test plant cascade
UPDATE SELECTED_PLANTS SET is_active = 'N' WHERE plant_id = '124';
-- Check CASCADE_LOG for event
SELECT * FROM CASCADE_LOG WHERE cascade_type = 'PLANT_TO_ISSUES' ORDER BY cascade_timestamp DESC FETCH FIRST 1 ROW ONLY;
-- Restore
UPDATE SELECTED_PLANTS SET is_active = 'Y' WHERE plant_id = '124';
UPDATE SELECTED_ISSUES SET is_active = 'Y', etl_status = NULL WHERE plant_id = '124';
COMMIT;

-- Test issue cascade
UPDATE ISSUES SET is_valid = 'N' WHERE plant_id = '124' AND issue_revision = '3.3';
-- Check if references cascaded
SELECT COUNT(*) FROM PCS_REFERENCES WHERE plant_id = '124' AND issue_revision = '3.3' AND is_valid = 'Y';
-- Should be 0
-- Restore
UPDATE ISSUES SET is_valid = 'Y' WHERE plant_id = '124' AND issue_revision = '3.3';
EXEC PKG_UPSERT_REFERENCES.upsert_pcs_references('124', '3.3');
COMMIT;
```

### Step 7: Check System Health
```sql
-- Check for invalid objects
SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID';
-- Should return no rows

-- Check for orphaned references
SELECT COUNT(*) as orphaned FROM PCS_REFERENCES pr
WHERE NOT EXISTS (
    SELECT 1 FROM ISSUES i
    WHERE i.plant_id = pr.plant_id
    AND i.issue_revision = pr.issue_revision
    AND i.is_valid = 'Y'
) AND pr.is_valid = 'Y';
-- Should be 0

-- Check API transaction log
SELECT COUNT(*) FROM API_TRANSACTIONS;
-- Should have records from API calls

-- Check cascade log
SELECT COUNT(*) FROM CASCADE_LOG;
-- Should have cascade events logged
```

### Step 8: Final Validation
```sql
-- Summary query
SELECT 
    (SELECT COUNT(*) FROM PLANTS WHERE is_valid = 'Y') as plants,
    (SELECT COUNT(*) FROM ISSUES WHERE is_valid = 'Y') as issues,
    (SELECT COUNT(*) FROM SELECTED_PLANTS WHERE is_active = 'Y') as selected_plants,
    (SELECT COUNT(*) FROM SELECTED_ISSUES WHERE is_active = 'Y') as selected_issues,
    (SELECT SUM(cnt) FROM (
        SELECT COUNT(*) cnt FROM PCS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT COUNT(*) FROM VSK_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT COUNT(*) FROM EDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT COUNT(*) FROM SC_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT COUNT(*) FROM VSM_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT COUNT(*) FROM ESK_REFERENCES WHERE is_valid = 'Y'
    )) as total_references
FROM dual;
```

## Troubleshooting

### If PCS references are marked invalid:
```sql
-- Re-run upsert to restore
EXEC PKG_UPSERT_REFERENCES.upsert_pcs_references('124', '3.3');
```

### If PIPE_ELEMENT has 0 records:
```sql
-- Check staging data
SELECT COUNT(*) FROM STG_PIPE_ELEMENT_REFERENCES;
-- Check for NULL names
SELECT COUNT(*), COUNT(name) FROM STG_PIPE_ELEMENT_REFERENCES;
-- If name is NULL, the JSON parsing needs fixing
```

### If cascade doesn't work:
```sql
-- Check trigger status
SELECT trigger_name, status FROM user_triggers 
WHERE trigger_name IN ('TRG_CASCADE_PLANT_TO_ISSUES', 'TRG_CASCADE_ISSUE_TO_REFERENCES');
```

## Success Criteria
✅ All reference tables have correct data (1,360 total records)  
✅ No invalid database objects  
✅ Cascade functionality working (plant→issues, issues→references)  
✅ No NULL issue_revision in SELECTED_ISSUES  
✅ API_TRANSACTIONS logging calls  
✅ CASCADE_LOG recording events  
✅ No orphaned references  
✅ Test suites passing (except test data expectations)  

## Next Steps
If all tests pass:
1. System is ready for Task 8 (PCS Details)
2. Consider discussion about unused tables (see RESUME.md)
3. Commit any remaining changes

## Tables Requiring Discussion
1. **CONTROL_ENDPOINT_STATE** - Not used, could track retry logic
2. **EXTERNAL_SYSTEM_REFS** - Not used, for future integrations
3. **TEMP_TEST_DATA** - Not used, for mock testing

Should these be removed or kept for future use?