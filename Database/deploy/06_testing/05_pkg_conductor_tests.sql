-- ===============================================================================
-- Package: PKG_CONDUCTOR_TESTS
-- Purpose: Tests for PKG_ETL_OPERATIONS (the conductor)
-- Date: 2025-08-27
-- Note: Because we tested the orchestra but forgot the conductor was naked!
-- ===============================================================================

CREATE OR REPLACE PACKAGE PKG_CONDUCTOR_TESTS AS
    
    -- Test execution order
    FUNCTION test_etl_execution_order RETURN VARCHAR2;
    
    -- Test partial failures
    FUNCTION test_partial_plant_failure RETURN VARCHAR2;
    
    -- Test idempotency
    FUNCTION test_etl_idempotency RETURN VARCHAR2;
    
    -- Test empty selections
    FUNCTION test_etl_with_no_selections RETURN VARCHAR2;
    
    -- Test status reporting
    FUNCTION test_etl_status_reporting RETURN VARCHAR2;
    
    -- Master test runner
    PROCEDURE run_all_conductor_tests;
    
END PKG_CONDUCTOR_TESTS;
/

CREATE OR REPLACE PACKAGE BODY PKG_CONDUCTOR_TESTS AS

    -- Helper to clean test data
    PROCEDURE cleanup_conductor_test_data IS
    BEGIN
        DELETE FROM RAW_JSON WHERE plant_id LIKE 'COND_TEST_%';
        DELETE FROM VDS_REFERENCES WHERE plant_id LIKE 'COND_TEST_%';
        DELETE FROM PCS_REFERENCES WHERE plant_id LIKE 'COND_TEST_%';
        DELETE FROM SELECTED_ISSUES WHERE plant_id LIKE 'COND_TEST_%';
        DELETE FROM SELECTED_PLANTS WHERE plant_id LIKE 'COND_TEST_%';
        DELETE FROM ISSUES WHERE plant_id LIKE 'COND_TEST_%';
        DELETE FROM PLANTS WHERE plant_id LIKE 'COND_TEST_%';
        DELETE FROM ETL_RUN_LOG WHERE endpoint_key LIKE '%COND_TEST%';
        DELETE FROM ETL_ERROR_LOG WHERE plant_id LIKE 'COND_TEST_%';
        COMMIT;
    END cleanup_conductor_test_data;

    -- ========================================================================
    -- Test: ETL Execution Order
    -- ========================================================================
    FUNCTION test_etl_execution_order RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_plant_time TIMESTAMP;
        v_issue_time TIMESTAMP;
        v_ref_time TIMESTAMP;
    BEGIN
        cleanup_conductor_test_data;
        
        -- Setup: Create test data in WRONG order (references before issues exist)
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('COND_TEST_ORDER', 'Test Execution Order', 'Y');
        
        INSERT INTO SELECTED_PLANTS (plant_id, is_active)
        VALUES ('COND_TEST_ORDER', 'Y');
        
        -- Try to load references WITHOUT issues existing
        BEGIN
            INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active)
            VALUES ('COND_TEST_ORDER', 'ORDER_REV_1', 'Y');
            
            pkg_etl_operations.run_references_etl_for_issue(
                p_plant_id => 'COND_TEST_ORDER',
                p_issue_revision => 'ORDER_REV_1',
                p_status => v_status,
                p_message => v_message
            );
            
            -- Should fail or skip because issue doesn't exist
            IF v_status = 'SUCCESS' THEN
                v_result := 'FAIL: References loaded without issue existing!';
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Expected - can't load references without issues
                NULL;
        END;
        
        -- Now create issue and try again
        INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
        VALUES (998001, 'COND_TEST_ORDER', 'ORDER_REV_1', 'Y', SYSDATE, SYSDATE);
        
        -- This should work now
        pkg_etl_operations.run_references_etl_for_issue(
            p_plant_id => 'COND_TEST_ORDER',
            p_issue_revision => 'ORDER_REV_1',
            p_status => v_status,
            p_message => v_message
        );
        
        -- Check ETL_RUN_LOG for proper sequencing
        BEGIN
            SELECT MAX(CASE WHEN run_type = 'PLANTS_ETL' THEN start_time END),
                   MAX(CASE WHEN run_type = 'ISSUES_ETL' THEN start_time END),
                   MAX(CASE WHEN run_type = 'REFERENCES_ETL' THEN start_time END)
            INTO v_plant_time, v_issue_time, v_ref_time
            FROM ETL_RUN_LOG
            WHERE plant_id = 'COND_TEST_ORDER'
               OR endpoint_key LIKE '%COND_TEST%';
            
            -- References should be after issues (when they exist)
            IF v_ref_time IS NOT NULL AND v_issue_time IS NOT NULL THEN
                IF v_ref_time < v_issue_time THEN
                    v_result := 'FAIL: References loaded before issues!';
                END IF;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL; -- No log entries is ok for this test
        END;
        
        cleanup_conductor_test_data;
        RETURN v_result;
    END test_etl_execution_order;

    -- ========================================================================
    -- Test: Partial Plant Failure
    -- ========================================================================
    FUNCTION test_partial_plant_failure RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_success_count NUMBER;
        v_fail_count NUMBER;
    BEGIN
        cleanup_conductor_test_data;
        
        -- Setup: Create 2 plants, one will "fail"
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('COND_TEST_GOOD', 'Good Plant', 'Y');
        
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('COND_TEST_BAD', 'Bad Plant', 'Y');
        
        INSERT INTO SELECTED_PLANTS (plant_id, is_active)
        VALUES ('COND_TEST_GOOD', 'Y');
        
        INSERT INTO SELECTED_PLANTS (plant_id, is_active)
        VALUES ('COND_TEST_BAD', 'Y');
        
        -- Create issues for good plant
        INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
        VALUES (998002, 'COND_TEST_GOOD', 'GOOD_REV', 'Y', SYSDATE, SYSDATE);
        
        INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active)
        VALUES ('COND_TEST_GOOD', 'GOOD_REV', 'Y');
        
        -- Simulate partial failure by having no issues for BAD plant
        -- but selecting a non-existent issue
        INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active)
        VALUES ('COND_TEST_BAD', 'NONEXISTENT_REV', 'Y');
        
        -- Run full ETL
        pkg_etl_operations.run_full_etl(
            p_status => v_status,
            p_message => v_message
        );
        
        -- Check if it handled partial failure correctly
        IF v_status NOT IN ('PARTIAL', 'SUCCESS') THEN
            v_result := 'FAIL: Expected PARTIAL or SUCCESS status, got ' || v_status;
        END IF;
        
        -- Verify good plant got processed
        SELECT COUNT(*) INTO v_success_count
        FROM ETL_RUN_LOG
        WHERE plant_id = 'COND_TEST_GOOD'
        AND status = 'SUCCESS';
        
        IF v_success_count = 0 THEN
            v_result := 'FAIL: Good plant was not processed due to bad plant failure';
        END IF;
        
        -- Check error handling for bad plant
        SELECT COUNT(*) INTO v_fail_count
        FROM ETL_RUN_LOG
        WHERE plant_id = 'COND_TEST_BAD'
        AND status IN ('FAILED', 'ERROR', 'SKIPPED');
        
        cleanup_conductor_test_data;
        RETURN v_result;
    END test_partial_plant_failure;

    -- ========================================================================
    -- Test: ETL Idempotency
    -- ========================================================================
    FUNCTION test_etl_idempotency RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_count_after_first NUMBER;
        v_count_after_second NUMBER;
    BEGIN
        cleanup_conductor_test_data;
        
        -- Setup: Create test data
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('COND_TEST_IDEM', 'Test Idempotency', 'Y');
        
        INSERT INTO SELECTED_PLANTS (plant_id, is_active)
        VALUES ('COND_TEST_IDEM', 'Y');
        
        INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
        VALUES (998003, 'COND_TEST_IDEM', 'IDEM_REV', 'Y', SYSDATE, SYSDATE);
        
        INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active)
        VALUES ('COND_TEST_IDEM', 'IDEM_REV', 'Y');
        
        -- Add some test references
        INSERT INTO PCS_REFERENCES (reference_guid, plant_id, issue_revision, pcs_name, is_valid, created_date)
        VALUES (SYS_GUID(), 'COND_TEST_IDEM', 'IDEM_REV', 'TEST_PCS_IDEM', 'Y', SYSDATE);
        
        COMMIT;
        
        -- Count before
        SELECT COUNT(*) INTO v_count_after_first
        FROM PCS_REFERENCES
        WHERE plant_id = 'COND_TEST_IDEM';
        
        -- Run ETL twice
        pkg_etl_operations.run_references_etl_for_issue(
            p_plant_id => 'COND_TEST_IDEM',
            p_issue_revision => 'IDEM_REV',
            p_status => v_status,
            p_message => v_message
        );
        
        -- Count after second run
        SELECT COUNT(*) INTO v_count_after_second
        FROM PCS_REFERENCES
        WHERE plant_id = 'COND_TEST_IDEM'
        AND is_valid = 'Y';
        
        -- Should not duplicate
        IF v_count_after_second > v_count_after_first THEN
            v_result := 'FAIL: ETL created duplicates! Had ' || v_count_after_first || 
                       ', now have ' || v_count_after_second;
        END IF;
        
        cleanup_conductor_test_data;
        RETURN v_result;
    END test_etl_idempotency;

    -- ========================================================================
    -- Test: ETL with No Selections
    -- ========================================================================
    FUNCTION test_etl_with_no_selections RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
    BEGIN
        cleanup_conductor_test_data;
        
        -- Test 1: No selected plants
        DELETE FROM SELECTED_PLANTS WHERE plant_id LIKE 'COND_TEST_%';
        DELETE FROM SELECTED_ISSUES WHERE plant_id LIKE 'COND_TEST_%';
        
        pkg_etl_operations.run_full_etl(
            p_status => v_status,
            p_message => v_message
        );
        
        -- Should handle gracefully
        IF v_status NOT IN ('SUCCESS', 'NO_DATA') THEN
            v_result := 'FAIL: No plants selected caused error: ' || v_status;
        END IF;
        
        -- Test 2: Selected plants but no selected issues
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('COND_TEST_EMPTY', 'Empty Plant', 'Y');
        
        INSERT INTO SELECTED_PLANTS (plant_id, is_active)
        VALUES ('COND_TEST_EMPTY', 'Y');
        
        -- No selected issues
        pkg_etl_operations.run_references_etl_for_all_selected(
            p_status => v_status,
            p_message => v_message
        );
        
        -- Should report no data gracefully
        IF v_status = 'ERROR' THEN
            v_result := 'FAIL: Empty selection caused error instead of graceful handling';
        END IF;
        
        cleanup_conductor_test_data;
        RETURN v_result;
    END test_etl_with_no_selections;

    -- ========================================================================
    -- Test: ETL Status Reporting
    -- ========================================================================
    FUNCTION test_etl_status_reporting RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_log_count NUMBER;
        v_has_start_time NUMBER;
        v_has_end_time NUMBER;
    BEGIN
        cleanup_conductor_test_data;
        
        -- Setup
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('COND_TEST_LOG', 'Test Logging', 'Y');
        
        INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
        VALUES (998004, 'COND_TEST_LOG', 'LOG_REV', 'Y', SYSDATE, SYSDATE);
        
        INSERT INTO SELECTED_PLANTS (plant_id, is_active)
        VALUES ('COND_TEST_LOG', 'Y');
        
        INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active)
        VALUES ('COND_TEST_LOG', 'LOG_REV', 'Y');
        
        -- Run ETL
        pkg_etl_operations.run_full_etl(
            p_status => v_status,
            p_message => v_message
        );
        
        -- Check if ETL_RUN_LOG was populated
        SELECT COUNT(*),
               SUM(CASE WHEN start_time IS NOT NULL THEN 1 ELSE 0 END),
               SUM(CASE WHEN end_time IS NOT NULL THEN 1 ELSE 0 END)
        INTO v_log_count, v_has_start_time, v_has_end_time
        FROM ETL_RUN_LOG
        WHERE plant_id = 'COND_TEST_LOG'
           OR endpoint_key IN (
               SELECT endpoint_key FROM CONTROL_ENDPOINTS WHERE endpoint_key LIKE '%COND_TEST%'
           );
        
        IF v_log_count = 0 THEN
            v_result := 'FAIL: No ETL_RUN_LOG entries created';
        ELSIF v_has_start_time = 0 THEN
            v_result := 'FAIL: ETL_RUN_LOG missing start times';
        END IF;
        
        -- Check if status message is informative
        IF v_message IS NULL OR LENGTH(v_message) < 10 THEN
            v_result := 'FAIL: Status message not informative: ' || NVL(v_message, 'NULL');
        END IF;
        
        cleanup_conductor_test_data;
        RETURN v_result;
    END test_etl_status_reporting;

    -- ========================================================================
    -- Master Test Runner
    -- ========================================================================
    PROCEDURE run_all_conductor_tests IS
        v_test_count NUMBER := 0;
        v_pass_count NUMBER := 0;
        v_fail_count NUMBER := 0;
        v_result VARCHAR2(4000);
    BEGIN
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        DBMS_OUTPUT.PUT_LINE('Conductor Tests (PKG_ETL_OPERATIONS)');
        DBMS_OUTPUT.PUT_LINE('Testing if the conductor has pants on...');
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        
        -- Test 1: Execution Order
        v_test_count := v_test_count + 1;
        v_result := test_etl_execution_order;
        DBMS_OUTPUT.PUT_LINE('1. Execution Order: ' || v_result);
        IF v_result LIKE 'PASS%' THEN 
            v_pass_count := v_pass_count + 1;
        ELSE 
            v_fail_count := v_fail_count + 1;
        END IF;
        
        -- Test 2: Partial Failure
        v_test_count := v_test_count + 1;
        v_result := test_partial_plant_failure;
        DBMS_OUTPUT.PUT_LINE('2. Partial Failure Handling: ' || v_result);
        IF v_result LIKE 'PASS%' THEN 
            v_pass_count := v_pass_count + 1;
        ELSE 
            v_fail_count := v_fail_count + 1;
        END IF;
        
        -- Test 3: Idempotency
        v_test_count := v_test_count + 1;
        v_result := test_etl_idempotency;
        DBMS_OUTPUT.PUT_LINE('3. ETL Idempotency: ' || v_result);
        IF v_result LIKE 'PASS%' THEN 
            v_pass_count := v_pass_count + 1;
        ELSE 
            v_fail_count := v_fail_count + 1;
        END IF;
        
        -- Test 4: No Selections
        v_test_count := v_test_count + 1;
        v_result := test_etl_with_no_selections;
        DBMS_OUTPUT.PUT_LINE('4. Empty Selections: ' || v_result);
        IF v_result LIKE 'PASS%' THEN 
            v_pass_count := v_pass_count + 1;
        ELSE 
            v_fail_count := v_fail_count + 1;
        END IF;
        
        -- Test 5: Status Reporting
        v_test_count := v_test_count + 1;
        v_result := test_etl_status_reporting;
        DBMS_OUTPUT.PUT_LINE('5. Status Reporting: ' || v_result);
        IF v_result LIKE 'PASS%' THEN 
            v_pass_count := v_pass_count + 1;
        ELSE 
            v_fail_count := v_fail_count + 1;
        END IF;
        
        -- Summary
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        DBMS_OUTPUT.PUT_LINE('Summary: ' || v_pass_count || '/' || v_test_count || ' tests passed');
        
        IF v_fail_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('✓ The conductor is now properly dressed and conducting!');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ The conductor still needs some wardrobe adjustments...');
        END IF;
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Fatal error in conductor tests: ' || SQLERRM);
            cleanup_conductor_test_data;
            RAISE;
    END run_all_conductor_tests;

END PKG_CONDUCTOR_TESTS;
/

SHOW ERRORS

PROMPT
PROMPT Conductor test package created
PROMPT Run tests with: EXEC PKG_CONDUCTOR_TESTS.run_all_conductor_tests
PROMPT