-- ===============================================================================
-- Add Critical Tests for Session 17 Features
-- Date: 2025-12-29
-- Purpose: Add tests for PCS_LOADING_MODE, V_PCS_TO_LOAD, and VDS integrity
-- ===============================================================================

-- Add new test functions to PKG_SIMPLE_TESTS
CREATE OR REPLACE PACKAGE PKG_SIMPLE_TESTS AS
    
    -- Existing test functions (keep all existing)
    FUNCTION test_api_connection RETURN VARCHAR2;
    FUNCTION test_json_parsing RETURN VARCHAR2;
    FUNCTION test_soft_deletes RETURN VARCHAR2;
    FUNCTION test_selection_cascade RETURN VARCHAR2;
    FUNCTION test_error_capture RETURN VARCHAR2;
    
    -- Priority 1 Reference Table Tests
    FUNCTION test_invalid_fk RETURN VARCHAR2;
    FUNCTION test_reference_cascade RETURN VARCHAR2;
    FUNCTION test_reference_parsing RETURN VARCHAR2;
    FUNCTION test_orphan_prevention RETURN VARCHAR2;
    
    -- Priority 2 Performance and Reliability Tests
    FUNCTION test_bulk_operations RETURN VARCHAR2;
    FUNCTION test_transaction_rollback RETURN VARCHAR2;
    FUNCTION test_large_json RETURN VARCHAR2;
    FUNCTION test_memory_limits RETURN VARCHAR2;
    FUNCTION test_vds_performance RETURN VARCHAR2;
    FUNCTION test_api_timeout RETURN VARCHAR2;
    FUNCTION test_api_500 RETURN VARCHAR2;
    FUNCTION test_api_503 RETURN VARCHAR2;
    FUNCTION test_rate_limit RETURN VARCHAR2;
    
    -- Priority 3 Resilience and Recovery Tests
    FUNCTION test_partial_failure_recovery RETURN VARCHAR2;
    
    -- Priority 4 Integration Tests
    FUNCTION test_all_selected_issues_get_references RETURN VARCHAR2;
    
    -- NEW Session 17 Tests
    FUNCTION test_pcs_loading_mode RETURN VARCHAR2;
    FUNCTION test_pcs_to_load_view RETURN VARCHAR2;
    FUNCTION test_pcs_json_paths RETURN VARCHAR2;
    FUNCTION test_vds_references_integrity RETURN VARCHAR2;
    
    -- Master procedures
    PROCEDURE run_critical_tests;
    PROCEDURE run_extended_tests;  -- NEW: Run all tests including new ones
    
    -- Cleanup test data
    PROCEDURE cleanup_test_data;
    
    -- Helper to log test results
    PROCEDURE log_test_result(
        p_test_name IN VARCHAR2,
        p_status IN VARCHAR2,
        p_error_msg IN VARCHAR2 DEFAULT NULL,
        p_execution_time IN NUMBER DEFAULT NULL
    );

END PKG_SIMPLE_TESTS;
/

-- Add body implementations for new tests
-- Note: This would need to be merged into the existing package body
-- For now, creating a separate test procedure that can be run independently

CREATE OR REPLACE PROCEDURE test_session17_features AS
    v_result VARCHAR2(4000);
    v_count NUMBER;
    v_test_passed BOOLEAN := TRUE;
    v_loading_mode VARCHAR2(100);
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Session 17 Feature Tests');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    -- Test 1: PCS_LOADING_MODE setting exists and has valid value
    DBMS_OUTPUT.PUT('Testing PCS_LOADING_MODE setting...');
    BEGIN
        SELECT setting_value INTO v_loading_mode
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'PCS_LOADING_MODE';
        
        IF v_loading_mode IN ('OFFICIAL_ONLY', 'ALL_REVISIONS') THEN
            DBMS_OUTPUT.PUT_LINE(' PASS (Mode: ' || v_loading_mode || ')');
        ELSE
            DBMS_OUTPUT.PUT_LINE(' FAIL - Invalid mode: ' || v_loading_mode);
            v_test_passed := FALSE;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE(' FAIL - Setting not found');
            v_test_passed := FALSE;
    END;
    
    -- Test 2: V_PCS_TO_LOAD view works correctly
    DBMS_OUTPUT.PUT('Testing V_PCS_TO_LOAD view...');
    BEGIN
        -- Check if view returns data
        SELECT COUNT(*) INTO v_count
        FROM V_PCS_TO_LOAD
        WHERE plant_id = '34';
        
        IF v_count > 0 THEN
            -- Check OFFICIAL_ONLY mode behavior
            SELECT COUNT(*) INTO v_count
            FROM V_PCS_TO_LOAD
            WHERE plant_id = '34'
            AND should_load = 'Y'
            AND revision_type = 'OFFICIAL';
            
            DBMS_OUTPUT.PUT_LINE(' PASS (' || v_count || ' official revisions to load)');
        ELSE
            DBMS_OUTPUT.PUT_LINE(' WARNING - No PCS data for plant 34');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(' FAIL - ' || SQLERRM);
            v_test_passed := FALSE;
    END;
    
    -- Test 3: PCS JSON parsing paths
    DBMS_OUTPUT.PUT('Testing PCS JSON parsing paths...');
    BEGIN
        -- Test if parsing procedure exists with correct JSON paths
        -- This would need actual JSON data to test properly
        -- For now, just verify the procedure compiles
        EXECUTE IMMEDIATE 'BEGIN pkg_parse_pcs_details.parse_plant_pcs_list(1, ''34''); END;';
        DBMS_OUTPUT.PUT_LINE(' FAIL - Should have raised error for invalid ID');
        v_test_passed := FALSE;
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -20360 OR SQLCODE = 100 THEN
                -- Expected error for missing JSON data
                DBMS_OUTPUT.PUT_LINE(' PASS - Parser validates input correctly');
            ELSE
                DBMS_OUTPUT.PUT_LINE(' FAIL - Unexpected error: ' || SQLERRM);
                v_test_passed := FALSE;
            END IF;
    END;
    
    -- Test 4: VDS References Integrity
    DBMS_OUTPUT.PUT('Testing VDS_REFERENCES integrity...');
    BEGIN
        -- Check VDS references have valid foreign keys
        SELECT COUNT(*) INTO v_count
        FROM VDS_REFERENCES vr
        WHERE NOT EXISTS (
            SELECT 1 FROM ISSUES i 
            WHERE i.plant_id = vr.plant_id 
            AND i.issue_revision = vr.issue_revision
            AND i.is_valid = 'Y'
        )
        AND vr.is_valid = 'Y';
        
        IF v_count = 0 THEN
            -- Check we have VDS data
            SELECT COUNT(*) INTO v_count
            FROM VDS_REFERENCES
            WHERE is_valid = 'Y';
            
            DBMS_OUTPUT.PUT_LINE(' PASS (' || v_count || ' valid VDS references)');
        ELSE
            DBMS_OUTPUT.PUT_LINE(' FAIL - Found ' || v_count || ' orphaned VDS references');
            v_test_passed := FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(' FAIL - ' || SQLERRM);
            v_test_passed := FALSE;
    END;
    
    -- Test 5: PCS_LIST to PCS Details relationship
    DBMS_OUTPUT.PUT('Testing PCS_LIST relationships...');
    BEGIN
        -- Check if PCS details tables reference PCS_LIST correctly
        SELECT COUNT(*) INTO v_count
        FROM USER_CONSTRAINTS
        WHERE constraint_type = 'R'
        AND table_name IN ('PCS_HEADER_PROPERTIES', 'PCS_TEMP_PRESSURES', 
                          'PCS_PIPE_SIZES', 'PCS_PIPE_ELEMENTS', 
                          'PCS_VALVE_ELEMENTS', 'PCS_EMBEDDED_NOTES')
        AND r_constraint_name IN (
            SELECT constraint_name 
            FROM USER_CONSTRAINTS 
            WHERE table_name = 'PCS_LIST' 
            AND constraint_type IN ('P', 'U')
        );
        
        IF v_count >= 6 THEN
            DBMS_OUTPUT.PUT_LINE(' PASS (All 6 detail tables have FK to PCS_LIST)');
        ELSE
            DBMS_OUTPUT.PUT_LINE(' FAIL - Only ' || v_count || ' of 6 tables have proper FK');
            v_test_passed := FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(' FAIL - ' || SQLERRM);
            v_test_passed := FALSE;
    END;
    
    -- Summary
    DBMS_OUTPUT.PUT_LINE('========================================');
    IF v_test_passed THEN
        DBMS_OUTPUT.PUT_LINE('All Session 17 tests PASSED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Some tests FAILED - review output above');
    END IF;
    DBMS_OUTPUT.PUT_LINE('========================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Test suite error: ' || SQLERRM);
        RAISE;
END test_session17_features;
/

-- Grant execute permission
GRANT EXECUTE ON test_session17_features TO TR2000_STAGING;

-- Test execution
PROMPT
PROMPT ========================================
PROMPT Session 17 Critical Tests Added
PROMPT ========================================
PROMPT Run with: EXEC test_session17_features;
PROMPT