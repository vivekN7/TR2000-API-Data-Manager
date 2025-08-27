-- ===============================================================================
-- Test Isolation Framework
-- Date: 2025-08-27
-- Purpose: Ensure test data NEVER contaminates production data
-- ===============================================================================

-- ===============================================================================
-- CRITICAL RULE: Test data MUST use these prefixes:
-- - Plant IDs: 'TEST_%' 
-- - Issue Revisions: 'TEST_%'
-- This ensures cascade operations don't affect real data
-- ===============================================================================

CREATE OR REPLACE PACKAGE PKG_TEST_ISOLATION AS
    -- Test data prefixes (NEVER change these)
    c_test_plant_prefix CONSTANT VARCHAR2(10) := 'TEST_';
    c_test_issue_prefix CONSTANT VARCHAR2(10) := 'TEST_';
    
    -- Procedure to clean ALL test data from ALL tables
    PROCEDURE clean_all_test_data;
    
    -- Function to check if data is test data
    FUNCTION is_test_data(p_plant_id VARCHAR2, p_issue_rev VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
    
    -- Procedure to validate no test data exists in production
    PROCEDURE validate_no_test_contamination;
    
    -- Function to get test data counts
    FUNCTION get_test_data_summary RETURN VARCHAR2;
    
END PKG_TEST_ISOLATION;
/

CREATE OR REPLACE PACKAGE BODY PKG_TEST_ISOLATION AS

    -- =========================================================================
    -- Check if data is test data
    -- =========================================================================
    FUNCTION is_test_data(p_plant_id VARCHAR2, p_issue_rev VARCHAR2 DEFAULT NULL) RETURN BOOLEAN IS
    BEGIN
        -- Check if plant starts with TEST_
        IF p_plant_id LIKE c_test_plant_prefix || '%' THEN
            RETURN TRUE;
        END IF;
        
        -- Check if issue starts with TEST_
        IF p_issue_rev IS NOT NULL AND p_issue_rev LIKE c_test_issue_prefix || '%' THEN
            RETURN TRUE;
        END IF;
        
        RETURN FALSE;
    END is_test_data;

    -- =========================================================================
    -- Clean ALL test data from ALL tables
    -- =========================================================================
    PROCEDURE clean_all_test_data IS
        v_count NUMBER;
        v_total_deleted NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Cleaning ALL test data from database');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
        -- Clean reference tables
        DELETE FROM PIPE_ELEMENT_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from PIPE_ELEMENT_REFERENCES');
        END IF;
        
        DELETE FROM ESK_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from ESK_REFERENCES');
        END IF;
        
        DELETE FROM VSK_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from VSK_REFERENCES');
        END IF;
        
        DELETE FROM MDS_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from MDS_REFERENCES');
        END IF;
        
        DELETE FROM EDS_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from EDS_REFERENCES');
        END IF;
        
        DELETE FROM VDS_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from VDS_REFERENCES');
        END IF;
        
        DELETE FROM VSM_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from VSM_REFERENCES');
        END IF;
        
        DELETE FROM SC_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from SC_REFERENCES');
        END IF;
        
        DELETE FROM PCS_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from PCS_REFERENCES');
        END IF;
        
        -- Clean staging tables
        DELETE FROM STG_PIPE_ELEMENT_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        DELETE FROM STG_ESK_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        DELETE FROM STG_VSK_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        DELETE FROM STG_MDS_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        DELETE FROM STG_EDS_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        DELETE FROM STG_VDS_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        DELETE FROM STG_VSM_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        DELETE FROM STG_SC_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        DELETE FROM STG_PCS_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        
        -- Clean core tables
        DELETE FROM ISSUES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from ISSUES');
        END IF;
        
        DELETE FROM STG_ISSUES WHERE plant_id LIKE c_test_plant_prefix || '%';
        
        DELETE FROM PLANTS WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from PLANTS');
        END IF;
        
        DELETE FROM STG_PLANTS WHERE plant_id LIKE c_test_plant_prefix || '%';
        
        -- Clean selected plants and issues
        DELETE FROM SELECTED_ISSUES WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from SELECTED_ISSUES');
            v_total_deleted := v_total_deleted + v_count;
        END IF;
        
        DELETE FROM SELECTED_PLANTS WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from SELECTED_PLANTS');
            v_total_deleted := v_total_deleted + v_count;
        END IF;
        
        -- Clean raw JSON
        DELETE FROM RAW_JSON WHERE plant_id LIKE c_test_plant_prefix || '%';
        v_count := SQL%ROWCOUNT;
        v_total_deleted := v_total_deleted + v_count;
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Deleted ' || v_count || ' test records from RAW_JSON');
        END IF;
        
        -- Clean test results that reference test data
        DELETE FROM TEST_RESULTS WHERE test_name LIKE '%TEST_%';
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Total test records deleted: ' || v_total_deleted);
        DBMS_OUTPUT.PUT_LINE('========================================');
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20901, 'Error cleaning test data: ' || SQLERRM);
    END clean_all_test_data;

    -- =========================================================================
    -- Validate no test contamination exists
    -- =========================================================================
    PROCEDURE validate_no_test_contamination IS
        v_contamination_found BOOLEAN := FALSE;
        v_count NUMBER;
    BEGIN
        -- Check all tables for test data
        SELECT COUNT(*) INTO v_count
        FROM PLANTS
        WHERE plant_id LIKE c_test_plant_prefix || '%';
        
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('WARNING: Found ' || v_count || ' test plants in PLANTS table');
            v_contamination_found := TRUE;
        END IF;
        
        SELECT COUNT(*) INTO v_count
        FROM ISSUES
        WHERE plant_id LIKE c_test_plant_prefix || '%'
           OR issue_revision LIKE c_test_issue_prefix || '%';
        
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('WARNING: Found ' || v_count || ' test issues in ISSUES table');
            v_contamination_found := TRUE;
        END IF;
        
        -- Check reference tables
        SELECT COUNT(*) INTO v_count
        FROM PCS_REFERENCES
        WHERE plant_id LIKE c_test_plant_prefix || '%';
        
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('WARNING: Found ' || v_count || ' test records in PCS_REFERENCES');
            v_contamination_found := TRUE;
        END IF;
        
        IF v_contamination_found THEN
            RAISE_APPLICATION_ERROR(-20902, 
                'Test data contamination detected! Run PKG_TEST_ISOLATION.clean_all_test_data() to fix.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✓ No test data contamination found');
        END IF;
    END validate_no_test_contamination;

    -- =========================================================================
    -- Get test data summary
    -- =========================================================================
    FUNCTION get_test_data_summary RETURN VARCHAR2 IS
        v_summary VARCHAR2(4000);
        v_count NUMBER;
        v_total NUMBER := 0;
    BEGIN
        v_summary := 'Test Data Summary:' || CHR(10);
        
        -- Count test data in each table
        SELECT COUNT(*) INTO v_count FROM PLANTS WHERE plant_id LIKE c_test_plant_prefix || '%';
        IF v_count > 0 THEN
            v_summary := v_summary || '  PLANTS: ' || v_count || CHR(10);
            v_total := v_total + v_count;
        END IF;
        
        SELECT COUNT(*) INTO v_count FROM ISSUES WHERE plant_id LIKE c_test_plant_prefix || '%';
        IF v_count > 0 THEN
            v_summary := v_summary || '  ISSUES: ' || v_count || CHR(10);
            v_total := v_total + v_count;
        END IF;
        
        SELECT COUNT(*) INTO v_count FROM PCS_REFERENCES WHERE plant_id LIKE c_test_plant_prefix || '%';
        IF v_count > 0 THEN
            v_summary := v_summary || '  PCS_REFERENCES: ' || v_count || CHR(10);
            v_total := v_total + v_count;
        END IF;
        
        IF v_total = 0 THEN
            v_summary := 'No test data found in database';
        ELSE
            v_summary := v_summary || 'Total test records: ' || v_total;
        END IF;
        
        RETURN v_summary;
    END get_test_data_summary;

END PKG_TEST_ISOLATION;
/

SHOW ERRORS

-- ===============================================================================
-- Create a procedure for full data refresh from API
-- ===============================================================================
CREATE OR REPLACE PROCEDURE refresh_all_data_from_api IS
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Full Data Refresh from API');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    -- Step 1: Clean any test data
    DBMS_OUTPUT.PUT_LINE('Step 1: Cleaning test data...');
    PKG_TEST_ISOLATION.clean_all_test_data();
    
    -- Step 2: Refresh plants
    DBMS_OUTPUT.PUT_LINE('Step 2: Refreshing plants from API...');
    PKG_API_CLIENT.refresh_plants_from_api(v_status, v_msg);
    DBMS_OUTPUT.PUT_LINE('  Status: ' || v_status || ' - ' || v_msg);
    
    -- Step 3: Process selected issues
    DBMS_OUTPUT.PUT_LINE('Step 3: Processing selected issues...');
    FOR rec IN (SELECT plant_id, issue_revision
                FROM SELECTED_ISSUES
                WHERE is_active = 'Y') LOOP
        DBMS_OUTPUT.PUT_LINE('  Processing ' || rec.plant_id || '/' || rec.issue_revision);
        
        -- Refresh issue data (issues are fetched with plants, so just process references)
        
        -- Refresh all references for this issue
        PKG_API_CLIENT_REFERENCES.refresh_all_issue_references(
            rec.plant_id, 
            rec.issue_revision, 
            v_status, 
            v_msg
        );
    END LOOP;
    
    -- Step 4: Validate no contamination
    DBMS_OUTPUT.PUT_LINE('Step 4: Validating data integrity...');
    PKG_TEST_ISOLATION.validate_no_test_contamination();
    
    -- Step 5: Show summary
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Refresh Complete - Summary:');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    FOR rec IN (
        SELECT 'PLANTS' as tbl, COUNT(*) as cnt FROM PLANTS WHERE is_valid = 'Y'
        UNION ALL
        SELECT 'ISSUES', COUNT(*) FROM ISSUES WHERE is_valid = 'Y'
        UNION ALL
        SELECT 'PCS_REFERENCES', COUNT(*) FROM PCS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL
        SELECT 'VDS_REFERENCES', COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL
        SELECT 'MDS_REFERENCES', COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL
        SELECT 'PIPE_ELEMENT_REF', COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
    ) LOOP
        IF rec.cnt > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  ' || RPAD(rec.tbl, 20) || ': ' || rec.cnt || ' records');
        END IF;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('========================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END refresh_all_data_from_api;
/

SHOW ERRORS

PROMPT
PROMPT ===============================================================================
PROMPT Test Isolation Framework Created
PROMPT ===============================================================================
PROMPT
PROMPT Key Commands:
PROMPT   - Clean test data: EXEC PKG_TEST_ISOLATION.clean_all_test_data;
PROMPT   - Check for contamination: EXEC PKG_TEST_ISOLATION.validate_no_test_contamination;
PROMPT   - Full refresh from API: EXEC refresh_all_data_from_api;
PROMPT
PROMPT RULE: All test data MUST use 'TEST_' prefix for plant_id or issue_revision
PROMPT ===============================================================================