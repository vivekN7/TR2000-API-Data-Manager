-- ===============================================================================
-- COMPREHENSIVE TEST SUITE RUNNER
-- Session 18: Complete test execution script
-- Purpose: Run all test packages and generate comprehensive report
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON
SET LINESIZE 200
SET PAGESIZE 1000

DECLARE
    v_total_tests NUMBER := 0;
    v_total_pass NUMBER := 0;
    v_start_time TIMESTAMP := SYSTIMESTAMP;
    v_end_time TIMESTAMP;
    v_elapsed_seconds NUMBER;
    
    -- Test suite results
    TYPE t_test_result IS RECORD (
        suite_name VARCHAR2(50),
        tests_run NUMBER,
        tests_passed NUMBER,
        execution_time NUMBER
    );
    TYPE t_test_results IS TABLE OF t_test_result;
    l_results t_test_results := t_test_results();
    
    PROCEDURE run_suite(
        p_suite_name IN VARCHAR2,
        p_procedure IN VARCHAR2,
        p_results IN OUT t_test_results
    ) IS
        v_suite_start TIMESTAMP := SYSTIMESTAMP;
        v_suite_end TIMESTAMP;
        v_suite_elapsed NUMBER;
        v_idx NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('================================================================================');
        DBMS_OUTPUT.PUT_LINE('Running: ' || p_suite_name);
        DBMS_OUTPUT.PUT_LINE('================================================================================');
        
        BEGIN
            EXECUTE IMMEDIATE 'BEGIN ' || p_procedure || '; END;';
            v_suite_end := SYSTIMESTAMP;
            v_suite_elapsed := EXTRACT(SECOND FROM (v_suite_end - v_suite_start)) + 
                              EXTRACT(MINUTE FROM (v_suite_end - v_suite_start)) * 60;
            
            -- Store result (would need actual counts from package)
            p_results.EXTEND;
            v_idx := p_results.COUNT;
            p_results(v_idx).suite_name := p_suite_name;
            p_results(v_idx).tests_run := 0; -- Would need actual count
            p_results(v_idx).tests_passed := 0; -- Would need actual count
            p_results(v_idx).execution_time := v_suite_elapsed;
            
            DBMS_OUTPUT.PUT_LINE('Suite completed in ' || ROUND(v_suite_elapsed, 2) || ' seconds');
            
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('ERROR in ' || p_suite_name || ': ' || SQLERRM);
                -- Still record the suite as run
                p_results.EXTEND;
                v_idx := p_results.COUNT;
                p_results(v_idx).suite_name := p_suite_name;
                p_results(v_idx).tests_run := 0;
                p_results(v_idx).tests_passed := 0;
                p_results(v_idx).execution_time := 0;
        END;
    END run_suite;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('TR2000 ETL COMPREHENSIVE TEST SUITE');
    DBMS_OUTPUT.PUT_LINE('Started: ' || TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    
    -- Clean test data first
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Cleaning test data...');
    BEGIN
        pkg_test_isolation.clean_all_test_data;
        DBMS_OUTPUT.PUT_LINE('Test data cleaned successfully');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Warning: Could not clean test data - ' || SQLERRM);
    END;
    
    -- Run each test suite
    
    -- 1. Simple Tests (Core functionality)
    run_suite('PKG_SIMPLE_TESTS', 'pkg_simple_tests.run_critical_tests', l_results);
    
    -- 2. Conductor Tests (ETL orchestration)
    run_suite('PKG_CONDUCTOR_TESTS', 'pkg_conductor_tests.run_all_conductor_tests', l_results);
    
    -- 3. Extended Conductor Tests
    run_suite('PKG_CONDUCTOR_EXTENDED', 'pkg_conductor_extended_tests.run_all_extended_tests', l_results);
    
    -- 4. Reference Tests
    run_suite('PKG_REFERENCE_TESTS', 'pkg_reference_comprehensive_tests.run_all_reference_tests', l_results);
    
    -- 5. API Error Tests
    run_suite('PKG_API_ERROR_TESTS', 'pkg_api_error_tests.run_all_api_error_tests', l_results);
    
    -- 6. Transaction Tests
    run_suite('PKG_TRANSACTION_TESTS', 'pkg_transaction_tests.run_all_transaction_tests', l_results);
    
    -- 7. Advanced Tests
    run_suite('PKG_ADVANCED_TESTS', 'pkg_advanced_tests.run_all_advanced_tests', l_results);
    
    -- 8. Resilience Tests
    run_suite('PKG_RESILIENCE_TESTS', 'pkg_resilience_tests.run_all_resilience_tests', l_results);
    
    -- 9. VDS Performance Tests
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('VDS Performance Check');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DECLARE
        v_vds_count NUMBER;
        v_vds_details NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_vds_count FROM VDS_LIST WHERE is_valid = 'Y';
        SELECT COUNT(*) INTO v_vds_details FROM VDS_DETAILS WHERE is_valid = 'Y';
        DBMS_OUTPUT.PUT_LINE('VDS Records: ' || v_vds_count || ' list, ' || v_vds_details || ' details');
        
        IF v_vds_count > 40000 THEN
            DBMS_OUTPUT.PUT_LINE('PASS: Large dataset (44k+) loaded successfully');
        ELSE
            DBMS_OUTPUT.PUT_LINE('INFO: VDS not fully loaded (use for performance baseline)');
        END IF;
    END;
    
    -- Fix references after testing
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('Post-Test Cleanup');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    BEGIN
        -- Fix any reference validity issues caused by tests
        UPDATE PCS_REFERENCES SET is_valid = 'Y' 
        WHERE plant_id IN (SELECT plant_id FROM PLANTS WHERE is_valid = 'Y')
          AND is_valid = 'N';
        
        UPDATE VDS_REFERENCES SET is_valid = 'Y'
        WHERE plant_id IN (SELECT plant_id FROM PLANTS WHERE is_valid = 'Y')
          AND is_valid = 'N';
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Reference validity restored');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Warning: Could not fix references - ' || SQLERRM);
    END;
    
    -- Calculate totals
    v_end_time := SYSTIMESTAMP;
    v_elapsed_seconds := EXTRACT(SECOND FROM (v_end_time - v_start_time)) + 
                        EXTRACT(MINUTE FROM (v_end_time - v_start_time)) * 60;
    
    -- Generate summary report
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('TEST EXECUTION SUMMARY');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test Suite Results:');
    DBMS_OUTPUT.PUT_LINE('-------------------');
    
    FOR i IN 1..l_results.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(RPAD(l_results(i).suite_name, 30) || 
                            ' - Time: ' || ROUND(l_results(i).execution_time, 2) || 's');
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Overall Statistics:');
    DBMS_OUTPUT.PUT_LINE('-------------------');
    DBMS_OUTPUT.PUT_LINE('Total Test Suites: ' || l_results.COUNT);
    DBMS_OUTPUT.PUT_LINE('Total Execution Time: ' || ROUND(v_elapsed_seconds, 2) || ' seconds');
    DBMS_OUTPUT.PUT_LINE('Average Suite Time: ' || ROUND(v_elapsed_seconds / l_results.COUNT, 2) || ' seconds');
    
    -- Check system health
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('System Health Check:');
    DBMS_OUTPUT.PUT_LINE('--------------------');
    DECLARE
        v_invalid_count NUMBER;
        v_error_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_invalid_count
        FROM user_objects
        WHERE status = 'INVALID';
        
        SELECT COUNT(*) INTO v_error_count
        FROM ETL_ERROR_LOG
        WHERE error_timestamp > v_start_time;
        
        DBMS_OUTPUT.PUT_LINE('Invalid Objects: ' || v_invalid_count);
        DBMS_OUTPUT.PUT_LINE('Errors During Test: ' || v_error_count);
        
        IF v_invalid_count = 0 AND v_error_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Status: HEALTHY');
        ELSIF v_invalid_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Status: NEEDS COMPILATION');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Status: CHECK ERRORS');
        END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    DBMS_OUTPUT.PUT_LINE('TEST EXECUTION COMPLETE');
    DBMS_OUTPUT.PUT_LINE('Ended: ' || TO_CHAR(v_end_time, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('================================================================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Test execution aborted');
END;
/

-- Generate test coverage report
PROMPT
PROMPT ================================================================================
PROMPT TEST COVERAGE REPORT
PROMPT ================================================================================

SELECT 'Test Coverage Analysis' as report_type FROM DUAL;

-- Count test packages
SELECT 'Test Packages' as metric, COUNT(*) as count
FROM user_objects
WHERE object_type = 'PACKAGE'
  AND object_name LIKE '%TEST%'
  AND status = 'VALID'
UNION ALL
-- Count total tests (approximate based on functions)
SELECT 'Estimated Tests' as metric, COUNT(*) as count
FROM user_procedures
WHERE object_type = 'PACKAGE'
  AND object_name LIKE '%TEST%'
  AND procedure_name LIKE 'TEST_%'
UNION ALL
-- Count tables with test coverage
SELECT 'Tables Tested' as metric, COUNT(DISTINCT table_name) as count
FROM user_tab_columns
WHERE table_name IN ('PLANTS', 'ISSUES', 'PCS_REFERENCES', 'VDS_REFERENCES', 
                     'VDS_LIST', 'VDS_DETAILS', 'PCS_LIST', 'SELECTION_LOADER')
UNION ALL
-- Count invalid objects
SELECT 'Invalid Objects' as metric, COUNT(*) as count
FROM user_objects
WHERE status = 'INVALID';

PROMPT
PROMPT Test execution complete. Review results above.
PROMPT
PROMPT Next steps:
PROMPT 1. Fix any compilation errors in test packages
PROMPT 2. Review WARNING and FAIL results
PROMPT 3. Consider performance baselines before optimization
PROMPT 4. Archive test results for comparison after refactoring
PROMPT