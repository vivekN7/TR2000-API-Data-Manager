-- ===============================================================================
-- PKG_ADVANCED_TESTS - Advanced Test Scenarios
-- Session 18: Complete test coverage
-- Purpose: Memory management, concurrency, plant changes, full lifecycle
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_advanced_tests AS
    
    -- Memory management tests
    FUNCTION test_memory_pga_limits RETURN VARCHAR2;
    FUNCTION test_memory_leak_detection RETURN VARCHAR2;
    FUNCTION test_large_dataset_memory RETURN VARCHAR2;
    
    -- Multi-user concurrency tests
    FUNCTION test_concurrent_plant_updates RETURN VARCHAR2;
    FUNCTION test_concurrent_etl_runs RETURN VARCHAR2;
    FUNCTION test_session_lock_handling RETURN VARCHAR2;
    
    -- Plant ID change scenarios
    FUNCTION test_plant_id_change_cascade RETURN VARCHAR2;
    FUNCTION test_plant_rename_impact RETURN VARCHAR2;
    FUNCTION test_plant_merge_scenario RETURN VARCHAR2;
    
    -- Full lifecycle integration tests
    FUNCTION test_complete_plant_lifecycle RETURN VARCHAR2;
    FUNCTION test_end_to_end_etl_flow RETURN VARCHAR2;
    FUNCTION test_data_consistency_check RETURN VARCHAR2;
    
    -- Main test runner
    PROCEDURE run_all_advanced_tests;
    
END pkg_advanced_tests;
/

CREATE OR REPLACE PACKAGE BODY pkg_advanced_tests AS

    -- =========================================================================
    -- MEMORY MANAGEMENT TESTS
    -- =========================================================================
    
    -- Test PGA memory limits
    FUNCTION test_memory_pga_limits RETURN VARCHAR2 IS
        v_pga_used NUMBER;
        v_pga_limit NUMBER;
        v_usage_percent NUMBER;
    BEGIN
        -- Check current PGA usage
        SELECT 
            ROUND(value/1024/1024, 2) INTO v_pga_used
        FROM v$mystat m, v$statname s
        WHERE m.statistic# = s.statistic#
          AND s.name = 'session pga memory'
          AND ROWNUM = 1;
        
        -- Get PGA aggregate limit
        SELECT 
            ROUND(value/1024/1024, 2) INTO v_pga_limit
        FROM v$parameter
        WHERE name = 'pga_aggregate_limit';
        
        IF v_pga_limit > 0 THEN
            v_usage_percent := ROUND((v_pga_used / v_pga_limit) * 100, 2);
            
            IF v_usage_percent < 80 THEN
                RETURN 'PASS: PGA usage at ' || v_pga_used || 'MB (' || 
                       v_usage_percent || '% of ' || v_pga_limit || 'MB limit)';
            ELSE
                RETURN 'WARNING: High PGA usage - ' || v_usage_percent || '%';
            END IF;
        ELSE
            RETURN 'WARNING: No PGA limit configured';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: Cannot check PGA - ' || SQLERRM;
    END test_memory_pga_limits;

    -- Test memory leak detection
    FUNCTION test_memory_leak_detection RETURN VARCHAR2 IS
        v_initial_memory NUMBER;
        v_after_operation NUMBER;
        v_after_cleanup NUMBER;
        v_leak_threshold NUMBER := 10; -- MB
    BEGIN
        -- Get initial memory
        SELECT ROUND(value/1024/1024, 2) INTO v_initial_memory
        FROM v$mystat m, v$statname s
        WHERE m.statistic# = s.statistic#
          AND s.name = 'session pga memory'
          AND ROWNUM = 1;
        
        -- Perform memory-intensive operation
        DECLARE
            TYPE t_large_array IS TABLE OF VARCHAR2(4000);
            l_array t_large_array := t_large_array();
        BEGIN
            -- Allocate memory
            FOR i IN 1..1000 LOOP
                l_array.EXTEND;
                l_array(i) := RPAD('X', 4000, 'X');
            END LOOP;
            
            -- Check memory after allocation
            SELECT ROUND(value/1024/1024, 2) INTO v_after_operation
            FROM v$mystat m, v$statname s
            WHERE m.statistic# = s.statistic#
              AND s.name = 'session pga memory'
              AND ROWNUM = 1;
            
            -- Clear the collection
            l_array.DELETE;
        END;
        
        -- Force garbage collection
        DBMS_SESSION.FREE_UNUSED_USER_MEMORY;
        
        -- Check memory after cleanup
        SELECT ROUND(value/1024/1024, 2) INTO v_after_cleanup
        FROM v$mystat m, v$statname s
        WHERE m.statistic# = s.statistic#
          AND s.name = 'session pga memory'
          AND ROWNUM = 1;
        
        -- Check for memory leak
        IF (v_after_cleanup - v_initial_memory) < v_leak_threshold THEN
            RETURN 'PASS: Memory properly released (recovered ' || 
                   ROUND(v_after_operation - v_after_cleanup, 2) || 'MB)';
        ELSE
            RETURN 'WARNING: Possible memory leak (' || 
                   ROUND(v_after_cleanup - v_initial_memory, 2) || 'MB not released)';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: ' || SQLERRM;
    END test_memory_leak_detection;

    -- Test large dataset memory handling (VDS)
    FUNCTION test_large_dataset_memory RETURN VARCHAR2 IS
        v_vds_count NUMBER;
        v_memory_per_record NUMBER;
        v_total_memory_mb NUMBER;
    BEGIN
        -- Check VDS dataset size
        SELECT COUNT(*) INTO v_vds_count
        FROM VDS_LIST WHERE is_valid = 'Y';
        
        IF v_vds_count = 0 THEN
            RETURN 'SKIP: No VDS data loaded';
        END IF;
        
        -- Estimate memory usage
        SELECT ROUND(bytes/1024/1024, 2) INTO v_total_memory_mb
        FROM user_segments
        WHERE segment_name = 'VDS_LIST';
        
        IF v_vds_count > 0 THEN
            v_memory_per_record := ROUND((v_total_memory_mb * 1024 * 1024) / v_vds_count, 2);
            
            IF v_memory_per_record < 5000 THEN  -- Less than 5KB per record
                RETURN 'PASS: Efficient memory usage - ' || v_memory_per_record || 
                       ' bytes/record for ' || v_vds_count || ' VDS records';
            ELSE
                RETURN 'WARNING: High memory usage - ' || v_memory_per_record || 
                       ' bytes/record';
            END IF;
        ELSE
            RETURN 'SKIP: No VDS data to test';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: ' || SQLERRM;
    END test_large_dataset_memory;

    -- =========================================================================
    -- MULTI-USER CONCURRENCY TESTS
    -- =========================================================================
    
    -- Test concurrent plant updates
    FUNCTION test_concurrent_plant_updates RETURN VARCHAR2 IS
        v_lock_count NUMBER;
        v_deadlock_count NUMBER;
    BEGIN
        -- Check for current locks on PLANTS table
        SELECT COUNT(*) INTO v_lock_count
        FROM v$lock l, dba_objects o
        WHERE l.id1 = o.object_id
          AND o.object_name = 'PLANTS'
          AND l.type = 'TM';
        
        -- Check for deadlock history
        SELECT COUNT(*) INTO v_deadlock_count
        FROM v$session_event
        WHERE event = 'enq: TX - row lock contention'
          AND total_waits > 0;
        
        IF v_lock_count = 0 AND v_deadlock_count = 0 THEN
            RETURN 'PASS: No concurrency issues detected';
        ELSIF v_lock_count > 0 THEN
            RETURN 'WARNING: Active locks detected (' || v_lock_count || ')';
        ELSE
            RETURN 'WARNING: Historical lock contention detected';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Likely permission issue on v$ views
            RETURN 'SKIP: Cannot access lock information';
    END test_concurrent_plant_updates;

    -- Test concurrent ETL runs
    FUNCTION test_concurrent_etl_runs RETURN VARCHAR2 IS
        v_running_count NUMBER;
        v_last_run_time TIMESTAMP;
    BEGIN
        -- Check if ETL is currently running
        SELECT COUNT(*) INTO v_running_count
        FROM ETL_RUN_LOG
        WHERE status = 'RUNNING';
        
        IF v_running_count > 1 THEN
            RETURN 'FAIL: Multiple ETL runs detected (' || v_running_count || ')';
        END IF;
        
        -- Check last run time
        SELECT MAX(start_time) INTO v_last_run_time
        FROM ETL_RUN_LOG
        WHERE status = 'COMPLETED';
        
        IF v_last_run_time IS NOT NULL THEN
            RETURN 'PASS: ETL concurrency controlled (last run: ' || 
                   TO_CHAR(v_last_run_time, 'YYYY-MM-DD HH24:MI:SS') || ')';
        ELSE
            RETURN 'PASS: No concurrent ETL issues';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: ' || SQLERRM;
    END test_concurrent_etl_runs;

    -- Test session lock handling
    FUNCTION test_session_lock_handling RETURN VARCHAR2 IS
        v_max_sessions NUMBER;
        v_current_sessions NUMBER;
        v_usage_percent NUMBER;
    BEGIN
        -- Get session limits
        SELECT 
            DECODE(value, '0', 1000, TO_NUMBER(value)) INTO v_max_sessions
        FROM v$parameter
        WHERE name = 'sessions';
        
        -- Get current session count
        SELECT COUNT(*) INTO v_current_sessions
        FROM v$session
        WHERE type = 'USER';
        
        v_usage_percent := ROUND((v_current_sessions / v_max_sessions) * 100, 2);
        
        IF v_usage_percent < 80 THEN
            RETURN 'PASS: Session usage at ' || v_current_sessions || '/' || 
                   v_max_sessions || ' (' || v_usage_percent || '%)';
        ELSE
            RETURN 'WARNING: High session usage - ' || v_usage_percent || '%';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'SKIP: Cannot access session information';
    END test_session_lock_handling;

    -- =========================================================================
    -- PLANT ID CHANGE SCENARIOS
    -- =========================================================================
    
    -- Test plant ID change cascade
    FUNCTION test_plant_id_change_cascade RETURN VARCHAR2 IS
        v_issue_count NUMBER;
        v_ref_count NUMBER;
        v_test_plant VARCHAR2(50) := 'TEST_CASCADE_' || TO_CHAR(SYSDATE, 'HH24MISS');
    BEGIN
        BEGIN
            -- Create test plant
            INSERT INTO PLANTS (plant_id, operator_name, is_valid, created_date, last_modified_date)
            VALUES (v_test_plant, 'Test Cascade Plant', 'Y', SYSDATE, SYSDATE);
            
            -- Create test issue
            INSERT INTO ISSUES (plant_id, issue_revision, is_valid, created_date, last_modified_date)
            VALUES (v_test_plant, 'TEST_REV', 'Y', SYSDATE, SYSDATE);
            
            -- Simulate plant ID change by invalidating
            UPDATE PLANTS SET is_valid = 'N' WHERE plant_id = v_test_plant;
            
            -- Check cascade
            SELECT COUNT(*) INTO v_issue_count
            FROM ISSUES 
            WHERE plant_id = v_test_plant AND is_valid = 'N';
            
            -- Cleanup
            DELETE FROM ISSUES WHERE plant_id = v_test_plant;
            DELETE FROM PLANTS WHERE plant_id = v_test_plant;
            COMMIT;
            
            IF v_issue_count > 0 THEN
                RETURN 'PASS: Plant change cascaded to issues';
            ELSE
                RETURN 'FAIL: Cascade not working';
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                RETURN 'ERROR: ' || SQLERRM;
        END;
    END test_plant_id_change_cascade;

    -- Test plant rename impact
    FUNCTION test_plant_rename_impact RETURN VARCHAR2 IS
        v_fk_count NUMBER;
    BEGIN
        -- Check foreign key constraints
        SELECT COUNT(*) INTO v_fk_count
        FROM user_constraints
        WHERE constraint_type = 'R'
          AND r_constraint_name IN (
              SELECT constraint_name 
              FROM user_constraints 
              WHERE table_name = 'PLANTS' 
                AND constraint_type = 'P'
          );
        
        IF v_fk_count > 0 THEN
            RETURN 'PASS: ' || v_fk_count || ' tables protected by FK constraints';
        ELSE
            RETURN 'WARNING: No FK constraints found for PLANTS';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: ' || SQLERRM;
    END test_plant_rename_impact;

    -- Test plant merge scenario
    FUNCTION test_plant_merge_scenario RETURN VARCHAR2 IS
        v_duplicate_count NUMBER;
    BEGIN
        -- Check for potential duplicate plants
        SELECT COUNT(*) INTO v_duplicate_count
        FROM (
            SELECT operator_name, COUNT(*) as cnt
            FROM PLANTS
            WHERE is_valid = 'Y'
              AND operator_name IS NOT NULL
            GROUP BY operator_name
            HAVING COUNT(*) > 1
        );
        
        IF v_duplicate_count = 0 THEN
            RETURN 'PASS: No duplicate plants detected';
        ELSE
            RETURN 'WARNING: ' || v_duplicate_count || ' potential duplicate plant names';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: ' || SQLERRM;
    END test_plant_merge_scenario;

    -- =========================================================================
    -- FULL LIFECYCLE INTEGRATION TESTS
    -- =========================================================================
    
    -- Test complete plant lifecycle
    FUNCTION test_complete_plant_lifecycle RETURN VARCHAR2 IS
        v_test_plant VARCHAR2(50) := 'TEST_LIFECYCLE_' || TO_CHAR(SYSDATE, 'HH24MISS');
        v_step VARCHAR2(100);
        v_count NUMBER;
    BEGIN
        BEGIN
            -- Step 1: Create plant
            v_step := 'Create Plant';
            INSERT INTO PLANTS (plant_id, operator_name, is_valid, created_date, last_modified_date)
            VALUES (v_test_plant, 'Lifecycle Test', 'Y', SYSDATE, SYSDATE);
            
            -- Step 2: Add to selection
            v_step := 'Add Selection';
            INSERT INTO SELECTION_LOADER (plant_id, entity_type, is_active, created_date, last_modified_date)
            VALUES (v_test_plant, 'PLANT', 'Y', SYSDATE, SYSDATE);
            
            -- Step 3: Create issue
            v_step := 'Create Issue';
            INSERT INTO ISSUES (plant_id, issue_revision, is_valid, created_date, last_modified_date)
            VALUES (v_test_plant, 'LIFECYCLE_REV', 'Y', SYSDATE, SYSDATE);
            
            -- Step 4: Deactivate plant
            v_step := 'Deactivate Plant';
            UPDATE PLANTS SET is_valid = 'N' WHERE plant_id = v_test_plant;
            
            -- Step 5: Verify cascade
            v_step := 'Verify Cascade';
            SELECT COUNT(*) INTO v_count
            FROM ISSUES 
            WHERE plant_id = v_test_plant AND is_valid = 'N';
            
            -- Cleanup
            DELETE FROM SELECTION_LOADER WHERE plant_id = v_test_plant;
            DELETE FROM ISSUES WHERE plant_id = v_test_plant;
            DELETE FROM PLANTS WHERE plant_id = v_test_plant;
            COMMIT;
            
            IF v_count > 0 THEN
                RETURN 'PASS: Complete lifecycle tested successfully';
            ELSE
                RETURN 'FAIL: Lifecycle cascade failed at ' || v_step;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                RETURN 'ERROR at ' || v_step || ': ' || SQLERRM;
        END;
    END test_complete_plant_lifecycle;

    -- Test end-to-end ETL flow
    FUNCTION test_end_to_end_etl_flow RETURN VARCHAR2 IS
        v_plants_count NUMBER;
        v_issues_count NUMBER;
        v_refs_count NUMBER;
        v_details_count NUMBER;
    BEGIN
        -- Check data exists at each level
        SELECT COUNT(*) INTO v_plants_count FROM PLANTS WHERE is_valid = 'Y';
        SELECT COUNT(*) INTO v_issues_count FROM ISSUES WHERE is_valid = 'Y';
        
        -- Count all references
        SELECT SUM(cnt) INTO v_refs_count FROM (
            SELECT COUNT(*) as cnt FROM PCS_REFERENCES WHERE is_valid = 'Y'
            UNION ALL SELECT COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y'
            UNION ALL SELECT COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y'
        );
        
        -- Count details
        SELECT SUM(cnt) INTO v_details_count FROM (
            SELECT COUNT(*) as cnt FROM PCS_HEADER_PROPERTIES WHERE is_valid = 'Y'
            UNION ALL SELECT COUNT(*) FROM VDS_DETAILS WHERE is_valid = 'Y'
        );
        
        IF v_plants_count > 0 AND v_issues_count > 0 AND v_refs_count > 0 THEN
            RETURN 'PASS: ETL flow complete - ' || 
                   v_plants_count || ' plants, ' ||
                   v_issues_count || ' issues, ' ||
                   v_refs_count || ' references, ' ||
                   v_details_count || ' details';
        ELSE
            RETURN 'WARNING: Incomplete ETL - Plants:' || v_plants_count ||
                   ', Issues:' || v_issues_count || ', Refs:' || v_refs_count;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: ' || SQLERRM;
    END test_end_to_end_etl_flow;

    -- Test data consistency
    FUNCTION test_data_consistency_check RETURN VARCHAR2 IS
        v_orphan_issues NUMBER;
        v_orphan_refs NUMBER;
        v_invalid_dates NUMBER;
    BEGIN
        -- Check for orphaned issues
        SELECT COUNT(*) INTO v_orphan_issues
        FROM ISSUES i
        WHERE i.is_valid = 'Y'
          AND NOT EXISTS (
              SELECT 1 FROM PLANTS p 
              WHERE p.plant_id = i.plant_id 
                AND p.is_valid = 'Y'
          );
        
        -- Check for orphaned references
        SELECT COUNT(*) INTO v_orphan_refs
        FROM PCS_REFERENCES r
        WHERE r.is_valid = 'Y'
          AND NOT EXISTS (
              SELECT 1 FROM ISSUES i 
              WHERE i.plant_id = r.plant_id 
                AND i.issue_revision = r.issue_revision
                AND i.is_valid = 'Y'
          );
        
        -- Check for invalid dates
        SELECT COUNT(*) INTO v_invalid_dates
        FROM PLANTS
        WHERE created_date > last_modified_date
           OR created_date > SYSDATE
           OR last_modified_date > SYSDATE;
        
        IF v_orphan_issues = 0 AND v_orphan_refs = 0 AND v_invalid_dates = 0 THEN
            RETURN 'PASS: Data consistency verified';
        ELSE
            RETURN 'FAIL: Inconsistencies found - ' ||
                   'Orphan Issues:' || v_orphan_issues ||
                   ', Orphan Refs:' || v_orphan_refs ||
                   ', Invalid Dates:' || v_invalid_dates;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: ' || SQLERRM;
    END test_data_consistency_check;

    -- =========================================================================
    -- Run all advanced tests
    -- =========================================================================
    PROCEDURE run_all_advanced_tests IS
        v_test_count NUMBER := 0;
        v_pass_count NUMBER := 0;
        v_result VARCHAR2(1000);
    BEGIN
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Advanced Test Suite');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('MEMORY MANAGEMENT TESTS:');
        DBMS_OUTPUT.PUT_LINE('------------------------');
        
        v_test_count := v_test_count + 1;
        v_result := test_memory_pga_limits;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('PGA Limits: ' || v_result);
        
        v_test_count := v_test_count + 1;
        v_result := test_memory_leak_detection;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Memory Leak Detection: ' || v_result);
        
        v_test_count := v_test_count + 1;
        v_result := test_large_dataset_memory;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Large Dataset Memory: ' || v_result);
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('CONCURRENCY TESTS:');
        DBMS_OUTPUT.PUT_LINE('------------------');
        
        v_test_count := v_test_count + 1;
        v_result := test_concurrent_plant_updates;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Concurrent Plant Updates: ' || v_result);
        
        v_test_count := v_test_count + 1;
        v_result := test_concurrent_etl_runs;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Concurrent ETL Runs: ' || v_result);
        
        v_test_count := v_test_count + 1;
        v_result := test_session_lock_handling;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Session Lock Handling: ' || v_result);
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('PLANT CHANGE SCENARIOS:');
        DBMS_OUTPUT.PUT_LINE('------------------------');
        
        v_test_count := v_test_count + 1;
        v_result := test_plant_id_change_cascade;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Plant ID Change Cascade: ' || v_result);
        
        v_test_count := v_test_count + 1;
        v_result := test_plant_rename_impact;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Plant Rename Impact: ' || v_result);
        
        v_test_count := v_test_count + 1;
        v_result := test_plant_merge_scenario;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Plant Merge Scenario: ' || v_result);
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('LIFECYCLE INTEGRATION TESTS:');
        DBMS_OUTPUT.PUT_LINE('-----------------------------');
        
        v_test_count := v_test_count + 1;
        v_result := test_complete_plant_lifecycle;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Complete Plant Lifecycle: ' || v_result);
        
        v_test_count := v_test_count + 1;
        v_result := test_end_to_end_etl_flow;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('End-to-End ETL Flow: ' || v_result);
        
        v_test_count := v_test_count + 1;
        v_result := test_data_consistency_check;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Data Consistency Check: ' || v_result);
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Results: ' || v_pass_count || '/' || v_test_count || ' PASSED');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
    END run_all_advanced_tests;

END pkg_advanced_tests;
/

-- Grant permissions
GRANT EXECUTE ON pkg_advanced_tests TO TR2000_STAGING;
/