-- ===============================================================================
-- Fix Test Data Isolation Issue
-- Date: 2025-08-27
-- Issue: Test procedures trigger cascades that invalidate real reference data
-- Solution: Ensure test procedures only work with TEST_* prefixed data
-- ===============================================================================

-- ===============================================================================
-- Add a safety procedure to PKG_TEST_ISOLATION
-- ===============================================================================
CREATE OR REPLACE PACKAGE BODY PKG_TEST_ISOLATION AS

    -- =========================================================================
    -- Check if data is test data
    -- =========================================================================
    FUNCTION is_test_data(p_plant_id VARCHAR2, p_issue_rev VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    BEGIN
        -- Check if plant starts with TEST_ or COND_TEST_ or EXT_TEST_
        IF p_plant_id LIKE 'TEST_%' OR 
           p_plant_id LIKE 'COND_TEST_%' OR 
           p_plant_id LIKE 'EXT_TEST_%' THEN
            RETURN TRUE;
        END IF;
        
        -- Check if issue starts with TEST_
        IF p_issue_rev IS NOT NULL AND 
           (p_issue_rev LIKE 'TEST_%' OR 
            p_issue_rev LIKE 'COND_TEST_%' OR
            p_issue_rev LIKE 'EXT_TEST_%') THEN
            RETURN TRUE;
        END IF;
        
        RETURN FALSE;
    END is_test_data;

    -- =========================================================================
    -- Clean ALL test data from ALL tables
    -- =========================================================================
    PROCEDURE clean_all_test_data IS
        v_total_deleted NUMBER := 0;
        v_table_count NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Cleaning ALL test data from database');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
        -- Clean reference tables (bottom-up to respect FK)
        DELETE FROM PCS_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM VDS_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM MDS_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM PIPE_ELEMENT_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM VSK_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM EDS_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM SC_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM VSM_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM ESK_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        -- Clean staging tables
        DELETE FROM STG_PCS_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM STG_VDS_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        -- Continue with other staging tables...
        DELETE FROM STG_MDS_REFERENCES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        DELETE FROM STG_PIPE_ELEMENT_REFERENCES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        DELETE FROM STG_VSK_REFERENCES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        DELETE FROM STG_EDS_REFERENCES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        DELETE FROM STG_SC_REFERENCES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        DELETE FROM STG_VSM_REFERENCES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        DELETE FROM STG_ESK_REFERENCES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        
        -- Clean selection tables
        DELETE FROM SELECTED_ISSUES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM SELECTED_PLANTS 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        -- Clean core tables
        DELETE FROM ISSUES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM PLANTS 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        -- Clean staging
        DELETE FROM STG_ISSUES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        DELETE FROM STG_PLANTS WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        
        -- Clean raw JSON
        DELETE FROM RAW_JSON 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        -- Clean logs
        DELETE FROM ETL_RUN_LOG 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR endpoint_key LIKE '%TEST%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        DELETE FROM ETL_ERROR_LOG 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        v_table_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_table_count;
        
        -- Clean test results
        DELETE FROM TEST_RESULTS WHERE test_name LIKE '%TEST_%';
        
        -- Clean CASCADE_LOG entries for test data
        DELETE FROM CASCADE_LOG 
        WHERE source_id LIKE 'TEST_%' OR source_id LIKE 'COND_TEST_%' OR source_id LIKE 'EXT_TEST_%';
        
        -- Clean control settings used by tests
        DELETE FROM CONTROL_SETTINGS WHERE setting_key LIKE '%TEST%';
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Total test records deleted: ' || v_total_deleted);
        DBMS_OUTPUT.PUT_LINE('========================================');
    END clean_all_test_data;

    -- =========================================================================
    -- Validate no test data exists in production
    -- =========================================================================
    PROCEDURE validate_no_test_contamination IS
        v_contamination_found BOOLEAN := FALSE;
        v_count NUMBER;
    BEGIN
        -- Check core tables
        SELECT COUNT(*) INTO v_count FROM PLANTS 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('⚠ Found ' || v_count || ' test plants in PLANTS table');
            v_contamination_found := TRUE;
        END IF;
        
        SELECT COUNT(*) INTO v_count FROM ISSUES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('⚠ Found ' || v_count || ' test issues in ISSUES table');
            v_contamination_found := TRUE;
        END IF;
        
        -- Check references
        SELECT COUNT(*) INTO v_count FROM PCS_REFERENCES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
           OR issue_revision LIKE 'TEST_%' OR issue_revision LIKE 'COND_TEST_%' OR issue_revision LIKE 'EXT_TEST_%';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('⚠ Found ' || v_count || ' test references in PCS_REFERENCES');
            v_contamination_found := TRUE;
        END IF;
        
        IF NOT v_contamination_found THEN
            DBMS_OUTPUT.PUT_LINE('✓ No test data contamination found');
        END IF;
    END validate_no_test_contamination;

    -- =========================================================================
    -- Get test data summary
    -- =========================================================================
    FUNCTION get_test_data_summary RETURN VARCHAR2 IS
        v_summary VARCHAR2(4000);
        v_count NUMBER;
    BEGIN
        v_summary := 'Test Data Summary:' || CHR(10);
        
        SELECT COUNT(*) INTO v_count FROM PLANTS 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        v_summary := v_summary || '  Plants: ' || v_count || CHR(10);
        
        SELECT COUNT(*) INTO v_count FROM ISSUES 
        WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%';
        v_summary := v_summary || '  Issues: ' || v_count || CHR(10);
        
        SELECT COUNT(*) INTO v_count FROM 
            (SELECT 1 FROM PCS_REFERENCES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
             UNION ALL
             SELECT 1 FROM VDS_REFERENCES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%'
             UNION ALL
             SELECT 1 FROM MDS_REFERENCES WHERE plant_id LIKE 'TEST_%' OR plant_id LIKE 'COND_TEST_%' OR plant_id LIKE 'EXT_TEST_%');
        v_summary := v_summary || '  References: ' || v_count || CHR(10);
        
        RETURN v_summary;
    END get_test_data_summary;

END PKG_TEST_ISOLATION;
/

PROMPT
PROMPT ===============================================================================
PROMPT Fix Applied: Test Data Isolation
PROMPT - Enhanced PKG_TEST_ISOLATION to handle all test prefixes
PROMPT - Added COND_TEST_ and EXT_TEST_ to cleanup procedures
PROMPT - Ensures complete test data removal after test runs
PROMPT ===============================================================================
PROMPT

-- Test the fix
EXEC PKG_TEST_ISOLATION.clean_all_test_data;
EXEC PKG_TEST_ISOLATION.validate_no_test_contamination;