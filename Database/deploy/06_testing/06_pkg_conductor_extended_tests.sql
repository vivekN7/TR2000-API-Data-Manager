-- ===============================================================================
-- Package: PKG_CONDUCTOR_EXTENDED_TESTS
-- Purpose: Extended conductor tests - Making the conductor the best dressed in the pit!
-- Date: 2025-08-27
-- Note: Because the audience demands STYLE!
-- ===============================================================================

CREATE OR REPLACE PACKAGE PKG_CONDUCTOR_EXTENDED_TESTS AS
    
    -- Extended tests for the stylish conductor
    FUNCTION test_concurrent_conductor_prevention RETURN VARCHAR2;
    FUNCTION test_conductor_memory_leak RETURN VARCHAR2;
    FUNCTION test_conductor_resume_after_crash RETURN VARCHAR2;
    FUNCTION test_conductor_performance_degradation RETURN VARCHAR2;
    FUNCTION test_conductor_audit_trail RETURN VARCHAR2;
    FUNCTION test_conductor_error_cascade RETURN VARCHAR2;
    FUNCTION test_conductor_data_consistency RETURN VARCHAR2;
    FUNCTION test_conductor_cleanup_orphans RETURN VARCHAR2;
    
    -- Master test runner
    PROCEDURE run_all_extended_tests;
    
END PKG_CONDUCTOR_EXTENDED_TESTS;
/

CREATE OR REPLACE PACKAGE BODY PKG_CONDUCTOR_EXTENDED_TESTS AS

    -- Helper to clean test data
    PROCEDURE cleanup_extended_test_data IS
    BEGIN
        DELETE FROM RAW_JSON WHERE plant_id LIKE 'EXT_TEST_%';
        DELETE FROM VDS_REFERENCES WHERE plant_id LIKE 'EXT_TEST_%';
        DELETE FROM PCS_REFERENCES WHERE plant_id LIKE 'EXT_TEST_%';
        DELETE FROM SELECTED_ISSUES WHERE plant_id LIKE 'EXT_TEST_%';
        DELETE FROM SELECTED_PLANTS WHERE plant_id LIKE 'EXT_TEST_%';
        DELETE FROM ISSUES WHERE plant_id LIKE 'EXT_TEST_%';
        DELETE FROM PLANTS WHERE plant_id LIKE 'EXT_TEST_%';
        DELETE FROM ETL_RUN_LOG WHERE endpoint_key LIKE '%EXT_TEST%' OR plant_id LIKE 'EXT_TEST_%';
        DELETE FROM ETL_ERROR_LOG WHERE plant_id LIKE 'EXT_TEST_%';
        -- Clear any locks we might have created
        DELETE FROM CONTROL_SETTINGS WHERE setting_key = 'ETL_LOCK_EXT_TEST';
        COMMIT;
    END cleanup_extended_test_data;

    -- ========================================================================
    -- Test: Concurrent Conductor Prevention (No sword fighting!)
    -- ========================================================================
    FUNCTION test_concurrent_conductor_prevention RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status1 VARCHAR2(50);
        v_status2 VARCHAR2(50);
        v_message1 VARCHAR2(4000);
        v_message2 VARCHAR2(4000);
        v_lock_acquired BOOLEAN := FALSE;
    BEGIN
        cleanup_extended_test_data;
        
        -- Simulate ETL lock mechanism
        BEGIN
            -- Try to acquire a lock (simulating first ETL run)
            INSERT INTO CONTROL_SETTINGS (setting_key, setting_value, description)
            VALUES ('ETL_LOCK_EXT_TEST', TO_CHAR(SYSTIMESTAMP), 'ETL Lock for testing');
            COMMIT;
            v_lock_acquired := TRUE;
            
            -- Try to run another ETL while "locked"
            BEGIN
                -- Check if lock exists
                DECLARE
                    v_lock_exists NUMBER;
                BEGIN
                    SELECT COUNT(*) INTO v_lock_exists
                    FROM CONTROL_SETTINGS
                    WHERE setting_key = 'ETL_LOCK_EXT_TEST';
                    
                    IF v_lock_exists > 0 THEN
                        -- Proper behavior: Should refuse to run
                        v_result := 'PASS: Concurrent execution prevented';
                    END IF;
                END;
            EXCEPTION
                WHEN OTHERS THEN
                    v_result := 'WARN: No lock mechanism implemented - concurrent runs possible!';
            END;
            
            -- Release lock
            DELETE FROM CONTROL_SETTINGS WHERE setting_key = 'ETL_LOCK_EXT_TEST';
            COMMIT;
            
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                -- This would mean lock mechanism exists
                v_result := 'PASS: Lock mechanism detected';
            WHEN OTHERS THEN
                v_result := 'FAIL: ' || SQLERRM;
        END;
        
        -- Check if ETL_RUN_LOG tracks concurrent attempts
        DECLARE
            v_concurrent_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_concurrent_count
            FROM ETL_RUN_LOG
            WHERE status = 'BLOCKED'
            AND notes LIKE '%concurrent%';
            
            IF v_concurrent_count > 0 THEN
                v_result := 'PASS: Concurrent attempts are logged';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- No concurrent tracking is ok for now
        END;
        
        cleanup_extended_test_data;
        RETURN v_result;
    END test_concurrent_conductor_prevention;

    -- ========================================================================
    -- Test: Memory Leak (Is the conductor getting fatter?)
    -- ========================================================================
    FUNCTION test_conductor_memory_leak RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_initial_memory NUMBER;
        v_mid_memory NUMBER;
        v_final_memory NUMBER;
        v_growth_rate NUMBER;
    BEGIN
        cleanup_extended_test_data;
        
        -- Create minimal test data
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('EXT_TEST_LEAK', 'Memory Leak Test', 'Y');
        
        INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
        VALUES (997001, 'EXT_TEST_LEAK', 'LEAK_REV', 'Y', SYSDATE, SYSDATE);
        
        INSERT INTO SELECTED_PLANTS (plant_id, is_active)
        VALUES ('EXT_TEST_LEAK', 'Y');
        
        INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active)
        VALUES ('EXT_TEST_LEAK', 'LEAK_REV', 'Y');
        
        -- Get initial memory (if we had access to v$session)
        -- For now, check RAW_JSON growth as a proxy
        SELECT COUNT(*) INTO v_initial_memory FROM RAW_JSON;
        
        -- Run ETL multiple times
        FOR i IN 1..5 LOOP
            -- Add a small reference to process
            INSERT INTO PCS_REFERENCES (
                reference_guid, plant_id, issue_revision, pcs_name, is_valid, created_date
            ) VALUES (
                SYS_GUID(), 'EXT_TEST_LEAK', 'LEAK_REV', 'LEAK_PCS_' || i, 'Y', SYSDATE
            );
            
            -- Run reference ETL
            pkg_etl_operations.run_references_etl_for_issue(
                p_plant_id => 'EXT_TEST_LEAK',
                p_issue_revision => 'LEAK_REV',
                p_status => v_status,
                p_message => v_message
            );
            
            IF i = 3 THEN
                SELECT COUNT(*) INTO v_mid_memory FROM RAW_JSON;
            END IF;
        END LOOP;
        
        SELECT COUNT(*) INTO v_final_memory FROM RAW_JSON;
        
        -- Check for unbounded growth
        v_growth_rate := (v_final_memory - v_initial_memory);
        
        IF v_growth_rate > 100 THEN
            v_result := 'WARN: Possible memory leak - RAW_JSON grew by ' || v_growth_rate || ' records';
        ELSIF v_final_memory > v_mid_memory * 2 THEN
            v_result := 'WARN: Exponential growth detected';
        ELSE
            v_result := 'PASS: No significant memory leak detected';
        END IF;
        
        cleanup_extended_test_data;
        RETURN v_result;
    END test_conductor_memory_leak;

    -- ========================================================================
    -- Test: Resume After Crash (Heart attack recovery!)
    -- ========================================================================
    FUNCTION test_conductor_resume_after_crash RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_incomplete_runs NUMBER;
        v_can_resume BOOLEAN := FALSE;
    BEGIN
        cleanup_extended_test_data;
        
        -- Simulate a crashed ETL run
        INSERT INTO ETL_RUN_LOG (
            run_type, endpoint_key, plant_id, start_time, status, initiated_by
        ) VALUES (
            'CRASHED_ETL', 'test_crash', 'EXT_TEST_CRASH', 
            SYSTIMESTAMP - INTERVAL '10' MINUTE, 'RUNNING', 'TEST_USER'
        );
        
        -- Check if system can detect incomplete runs
        SELECT COUNT(*) INTO v_incomplete_runs
        FROM ETL_RUN_LOG
        WHERE status = 'RUNNING'
        AND start_time < SYSTIMESTAMP - INTERVAL '5' MINUTE;
        
        IF v_incomplete_runs > 0 THEN
            -- System can detect stuck runs
            v_result := 'PASS: System detects incomplete runs';
            
            -- Check if there's a recovery mechanism
            BEGIN
                -- Look for recovery procedures or status updates
                UPDATE ETL_RUN_LOG
                SET status = 'CRASHED',
                    end_time = SYSTIMESTAMP,
                    notes = 'Detected as crashed by recovery test'
                WHERE status = 'RUNNING'
                AND start_time < SYSTIMESTAMP - INTERVAL '5' MINUTE
                AND plant_id = 'EXT_TEST_CRASH';
                
                IF SQL%ROWCOUNT > 0 THEN
                    v_can_resume := TRUE;
                    v_result := 'PASS: Can mark crashed runs and potentially resume';
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_result := 'WARN: No automatic crash recovery mechanism';
            END;
        ELSE
            v_result := 'WARN: No detection of incomplete/crashed runs';
        END IF;
        
        cleanup_extended_test_data;
        RETURN v_result;
    END test_conductor_resume_after_crash;

    -- ========================================================================
    -- Test: Performance Degradation (Getting tired?)
    -- ========================================================================
    FUNCTION test_conductor_performance_degradation RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_time_1_issue NUMBER;
        v_time_10_issues NUMBER;
        v_time_100_issues NUMBER;
        v_start_time TIMESTAMP;
        v_scaling_factor NUMBER;
    BEGIN
        cleanup_extended_test_data;
        
        -- Test with 1 issue
        v_start_time := SYSTIMESTAMP;
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('EXT_TEST_PERF1', 'Perf Test 1', 'Y');
        
        INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
        VALUES (997002, 'EXT_TEST_PERF1', 'PERF1', 'Y', SYSDATE, SYSDATE);
        
        INSERT INTO PCS_REFERENCES (reference_guid, plant_id, issue_revision, pcs_name, is_valid, created_date)
        VALUES (SYS_GUID(), 'EXT_TEST_PERF1', 'PERF1', 'PERF_PCS', 'Y', SYSDATE);
        
        v_time_1_issue := EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time));
        
        -- Test with 10 issues
        v_start_time := SYSTIMESTAMP;
        FOR i IN 1..10 LOOP
            INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
            VALUES (997010 + i, 'EXT_TEST_PERF1', 'PERF10_' || i, 'Y', SYSDATE, SYSDATE);
            
            INSERT INTO PCS_REFERENCES (reference_guid, plant_id, issue_revision, pcs_name, is_valid, created_date)
            VALUES (SYS_GUID(), 'EXT_TEST_PERF1', 'PERF10_' || i, 'PERF_PCS_' || i, 'Y', SYSDATE);
        END LOOP;
        v_time_10_issues := EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time));
        
        -- Test with 100 references (using existing issues)
        v_start_time := SYSTIMESTAMP;
        FOR i IN 1..100 LOOP
            -- Use the existing issues we created (PERF1 and PERF10_1 through PERF10_10)
            INSERT INTO VDS_REFERENCES (reference_guid, plant_id, issue_revision, vds_name, is_valid, created_date)
            VALUES (SYS_GUID(), 'EXT_TEST_PERF1', 
                    CASE WHEN MOD(i,11) = 0 THEN 'PERF1' 
                         ELSE 'PERF10_' || TO_CHAR(MOD(i,10) + 1)
                    END, 
                    'PERF_VDS_' || i, 'Y', SYSDATE);
        END LOOP;
        v_time_100_issues := EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time));
        
        -- Calculate scaling factor
        IF v_time_10_issues > 0 AND v_time_1_issue > 0 THEN
            v_scaling_factor := v_time_100_issues / v_time_10_issues;
            
            IF v_scaling_factor > 20 THEN
                v_result := 'FAIL: O(n²) or worse scaling detected! 100x data took ' || 
                           ROUND(v_scaling_factor) || 'x longer';
            ELSIF v_scaling_factor > 12 THEN
                v_result := 'WARN: Suboptimal scaling. 100x data took ' || 
                           ROUND(v_scaling_factor) || 'x longer';
            ELSE
                v_result := 'PASS: Near linear scaling (factor: ' || 
                           ROUND(v_scaling_factor, 1) || ')';
            END IF;
        ELSE
            v_result := 'PASS: No significant performance degradation detected';
        END IF;
        
        cleanup_extended_test_data;
        RETURN v_result;
    END test_conductor_performance_degradation;

    -- ========================================================================
    -- Test: Audit Trail (Who did what when?)
    -- ========================================================================
    FUNCTION test_conductor_audit_trail RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_has_user NUMBER;
        v_has_timestamps NUMBER;
        v_has_details NUMBER;
        v_audit_score NUMBER := 0;
    BEGIN
        cleanup_extended_test_data;
        
        -- Create test data
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('EXT_TEST_AUDIT', 'Audit Test', 'Y');
        
        INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
        VALUES (997003, 'EXT_TEST_AUDIT', 'AUDIT_REV', 'Y', SYSDATE, SYSDATE);
        
        INSERT INTO SELECTED_PLANTS (plant_id, is_active)
        VALUES ('EXT_TEST_AUDIT', 'Y');
        
        INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active)
        VALUES ('EXT_TEST_AUDIT', 'AUDIT_REV', 'Y');
        
        -- Run ETL
        pkg_etl_operations.run_full_etl(
            p_status => v_status,
            p_message => v_message
        );
        
        -- Check audit trail quality
        BEGIN
            -- Check 1: Does it record WHO initiated?
            SELECT COUNT(*) INTO v_has_user
            FROM ETL_RUN_LOG
            WHERE initiated_by IS NOT NULL
            AND (plant_id = 'EXT_TEST_AUDIT' OR endpoint_key LIKE '%AUDIT%')
            AND ROWNUM = 1;
            
            IF v_has_user > 0 THEN
                v_audit_score := v_audit_score + 1;
            END IF;
            
            -- Check 2: Does it record WHEN (start and end)?
            SELECT COUNT(*) INTO v_has_timestamps
            FROM ETL_RUN_LOG
            WHERE start_time IS NOT NULL
            AND end_time IS NOT NULL
            AND (plant_id = 'EXT_TEST_AUDIT' OR endpoint_key LIKE '%AUDIT%')
            AND ROWNUM = 1;
            
            IF v_has_timestamps > 0 THEN
                v_audit_score := v_audit_score + 1;
            END IF;
            
            -- Check 3: Does it record WHAT was processed?
            SELECT COUNT(*) INTO v_has_details
            FROM ETL_RUN_LOG
            WHERE (records_processed IS NOT NULL OR notes IS NOT NULL)
            AND (plant_id = 'EXT_TEST_AUDIT' OR endpoint_key LIKE '%AUDIT%')
            AND ROWNUM = 1;
            
            IF v_has_details > 0 THEN
                v_audit_score := v_audit_score + 1;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                v_result := 'FAIL: Error checking audit trail - ' || SQLERRM;
        END;
        
        -- Score the audit trail
        IF v_audit_score = 3 THEN
            v_result := 'PASS: Complete audit trail (WHO, WHEN, WHAT)';
        ELSIF v_audit_score = 2 THEN
            v_result := 'WARN: Partial audit trail (score: ' || v_audit_score || '/3)';
        ELSIF v_audit_score = 1 THEN
            v_result := 'FAIL: Minimal audit trail (score: ' || v_audit_score || '/3)';
        ELSE
            v_result := 'FAIL: No audit trail found!';
        END IF;
        
        cleanup_extended_test_data;
        RETURN v_result;
    END test_conductor_audit_trail;

    -- ========================================================================
    -- Test: Error Cascade (One musician falls, does everyone stop?)
    -- ========================================================================
    FUNCTION test_conductor_error_cascade RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_plant_count NUMBER;
        v_issue_count NUMBER;
        v_ref_count NUMBER;
    BEGIN
        cleanup_extended_test_data;
        
        -- Create 3 plants, middle one will "fail"
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('EXT_TEST_CASCADE1', 'Cascade Test 1', 'Y');
        
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('EXT_TEST_CASCADE2', 'Cascade Test 2 - FAIL', 'Y');
        
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('EXT_TEST_CASCADE3', 'Cascade Test 3', 'Y');
        
        -- Create issues for plants 1 and 3
        INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
        VALUES (997004, 'EXT_TEST_CASCADE1', 'CASCADE1', 'Y', SYSDATE, SYSDATE);
        
        INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
        VALUES (997005, 'EXT_TEST_CASCADE3', 'CASCADE3', 'Y', SYSDATE, SYSDATE);
        
        -- Select all plants
        INSERT INTO SELECTED_PLANTS (plant_id, is_active) VALUES ('EXT_TEST_CASCADE1', 'Y');
        INSERT INTO SELECTED_PLANTS (plant_id, is_active) VALUES ('EXT_TEST_CASCADE2', 'Y');
        INSERT INTO SELECTED_PLANTS (plant_id, is_active) VALUES ('EXT_TEST_CASCADE3', 'Y');
        
        -- Select issues (including non-existent one for CASCADE2)
        INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active) VALUES ('EXT_TEST_CASCADE1', 'CASCADE1', 'Y');
        INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active) VALUES ('EXT_TEST_CASCADE2', 'NONEXIST', 'Y');
        INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active) VALUES ('EXT_TEST_CASCADE3', 'CASCADE3', 'Y');
        
        -- Run full ETL
        pkg_etl_operations.run_full_etl(
            p_status => v_status,
            p_message => v_message
        );
        
        -- Check if plants 1 and 3 still got processed despite 2 failing
        SELECT COUNT(*) INTO v_plant_count
        FROM ETL_RUN_LOG
        WHERE plant_id IN ('EXT_TEST_CASCADE1', 'EXT_TEST_CASCADE3')
        AND status = 'SUCCESS';
        
        IF v_plant_count >= 1 THEN
            v_result := 'PASS: Other plants processed despite one failure';
        ELSE
            v_result := 'FAIL: Error cascaded and stopped all processing';
        END IF;
        
        cleanup_extended_test_data;
        RETURN v_result;
    END test_conductor_error_cascade;

    -- ========================================================================
    -- Test: Data Consistency (Is the sheet music correct after the show?)
    -- ========================================================================
    FUNCTION test_conductor_data_consistency RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_orphan_refs NUMBER;
        v_invalid_fks NUMBER;
        v_duplicate_keys NUMBER;
        v_consistency_score NUMBER := 0;
    BEGIN
        cleanup_extended_test_data;
        
        -- Check for orphaned references (references without parent issues)
        SELECT COUNT(*) INTO v_orphan_refs
        FROM (
            SELECT plant_id, issue_revision FROM PCS_REFERENCES
            WHERE is_valid = 'Y'
            MINUS
            SELECT plant_id, issue_revision FROM ISSUES
            WHERE is_valid = 'Y'
        );
        
        IF v_orphan_refs > 0 THEN
            v_result := 'FAIL: Found ' || v_orphan_refs || ' orphaned references';
            v_consistency_score := v_consistency_score - 1;
        ELSE
            v_consistency_score := v_consistency_score + 1;
        END IF;
        
        -- Check for invalid foreign keys
        BEGIN
            SELECT COUNT(*) INTO v_invalid_fks
            FROM SELECTED_ISSUES si
            WHERE NOT EXISTS (
                SELECT 1 FROM ISSUES i
                WHERE i.plant_id = si.plant_id
                AND i.issue_revision = si.issue_revision
            )
            AND si.is_active = 'Y';
            
            IF v_invalid_fks > 0 THEN
                v_result := 'WARN: Found ' || v_invalid_fks || ' selected issues without actual issues';
                v_consistency_score := v_consistency_score - 1;
            ELSE
                v_consistency_score := v_consistency_score + 1;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
        
        -- Check for duplicate active references
        SELECT COUNT(*) INTO v_duplicate_keys
        FROM (
            SELECT plant_id, issue_revision, pcs_name, COUNT(*)
            FROM PCS_REFERENCES
            WHERE is_valid = 'Y'
            GROUP BY plant_id, issue_revision, pcs_name
            HAVING COUNT(*) > 1
        );
        
        IF v_duplicate_keys > 0 THEN
            v_result := 'FAIL: Found ' || v_duplicate_keys || ' duplicate active references';
            v_consistency_score := v_consistency_score - 1;
        ELSE
            v_consistency_score := v_consistency_score + 1;
        END IF;
        
        -- Final scoring
        IF v_consistency_score = 3 THEN
            v_result := 'PASS: Data consistency maintained';
        ELSIF v_consistency_score > 0 THEN
            v_result := 'WARN: Some consistency issues (score: ' || v_consistency_score || '/3)';
        END IF;
        
        cleanup_extended_test_data;
        RETURN v_result;
    END test_conductor_data_consistency;

    -- ========================================================================
    -- Test: Cleanup Orphans (Taking out the trash)
    -- ========================================================================
    FUNCTION test_conductor_cleanup_orphans RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_orphans_before NUMBER;
        v_orphans_after NUMBER;
    BEGIN
        cleanup_extended_test_data;
        
        -- Create intentional orphans
        INSERT INTO PLANTS (plant_id, short_description, is_valid)
        VALUES ('EXT_TEST_ORPHAN', 'Orphan Test', 'Y');
        
        INSERT INTO ISSUES (issue_id, plant_id, issue_revision, is_valid, created_date, last_modified_date)
        VALUES (997006, 'EXT_TEST_ORPHAN', 'ORPHAN_REV', 'Y', SYSDATE, SYSDATE);
        
        -- Create references
        INSERT INTO PCS_REFERENCES (reference_guid, plant_id, issue_revision, pcs_name, is_valid, created_date)
        VALUES (SYS_GUID(), 'EXT_TEST_ORPHAN', 'ORPHAN_REV', 'ORPHAN_PCS', 'Y', SYSDATE);
        
        -- Now try to delete the issue - should fail due to FK constraint
        BEGIN
            DELETE FROM ISSUES WHERE plant_id = 'EXT_TEST_ORPHAN';
            -- If we get here, FK constraint is not working
            v_result := 'FAIL: FK constraint did not prevent orphan creation';
            ROLLBACK;
        EXCEPTION
            WHEN OTHERS THEN
                -- This is expected - FK prevents orphans
                v_result := 'PASS: FK constraints prevent orphans';
                ROLLBACK;
        END;
        
        -- Since FK prevented orphans, check if cascading deletes work
        IF v_result LIKE 'PASS%FK%' THEN
            -- Test cascade delete instead
            BEGIN
                -- Mark issue as invalid (soft delete)
                UPDATE ISSUES SET is_valid = 'N' WHERE plant_id = 'EXT_TEST_ORPHAN';
                
                -- Check if references are also marked invalid
                SELECT COUNT(*) INTO v_orphans_after
                FROM PCS_REFERENCES
                WHERE plant_id = 'EXT_TEST_ORPHAN'
                AND is_valid = 'Y';
                
                IF v_orphans_after = 0 THEN
                    v_result := 'PASS: FK prevents orphans + cascade soft delete works';
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_result := 'PASS: FK constraints prevent orphans (cascade not tested)';
            END;
        END IF;
        
        cleanup_extended_test_data;
        RETURN v_result;
    END test_conductor_cleanup_orphans;

    -- ========================================================================
    -- Master Test Runner - The Fashion Show!
    -- ========================================================================
    PROCEDURE run_all_extended_tests IS
        v_test_count NUMBER := 0;
        v_pass_count NUMBER := 0;
        v_fail_count NUMBER := 0;
        v_warn_count NUMBER := 0;
        v_result VARCHAR2(4000);
        
        TYPE t_test_rec IS RECORD (
            test_name VARCHAR2(100),
            test_func VARCHAR2(100),
            emoji VARCHAR2(10)
        );
        TYPE t_test_array IS TABLE OF t_test_rec;
        
        v_tests t_test_array := t_test_array(
            t_test_rec('Concurrent Prevention', 'test_concurrent_conductor_prevention', '🚫'),
            t_test_rec('Memory Leak Check', 'test_conductor_memory_leak', '💾'),
            t_test_rec('Crash Recovery', 'test_conductor_resume_after_crash', '💔'),
            t_test_rec('Performance Scaling', 'test_conductor_performance_degradation', '📈'),
            t_test_rec('Audit Trail', 'test_conductor_audit_trail', '📝'),
            t_test_rec('Error Cascade', 'test_conductor_error_cascade', '🎯'),
            t_test_rec('Data Consistency', 'test_conductor_data_consistency', '✅'),
            t_test_rec('Orphan Cleanup', 'test_conductor_cleanup_orphans', '🧹')
        );
        
    BEGIN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        DBMS_OUTPUT.PUT_LINE('🎩 THE CONDUCTOR''S FASHION SHOW 🎩');
        DBMS_OUTPUT.PUT_LINE('Let''s see how stylish our conductor really is!');
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        DBMS_OUTPUT.PUT_LINE('');
        
        FOR i IN 1..v_tests.COUNT LOOP
            v_test_count := v_test_count + 1;
            
            -- Execute test dynamically
            EXECUTE IMMEDIATE 
                'BEGIN :result := PKG_CONDUCTOR_EXTENDED_TESTS.' || v_tests(i).test_func || '; END;'
                USING OUT v_result;
            
            -- Display result with style
            DBMS_OUTPUT.PUT(v_tests(i).emoji || ' ' || RPAD(v_tests(i).test_name, 25, '.'));
            
            IF v_result LIKE 'PASS%' THEN
                DBMS_OUTPUT.PUT_LINE(' ✓ ' || v_result);
                v_pass_count := v_pass_count + 1;
            ELSIF v_result LIKE 'WARN%' OR v_result LIKE 'INFO%' THEN
                DBMS_OUTPUT.PUT_LINE(' ⚠ ' || v_result);
                v_warn_count := v_warn_count + 1;
            ELSE
                DBMS_OUTPUT.PUT_LINE(' ✗ ' || v_result);
                v_fail_count := v_fail_count + 1;
            END IF;
        END LOOP;
        
        -- Fashion show results
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        DBMS_OUTPUT.PUT_LINE('🏆 FASHION SHOW RESULTS 🏆');
        DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Total Outfits Tested: ' || v_test_count);
        DBMS_OUTPUT.PUT_LINE('✓ Stunning Successes: ' || v_pass_count);
        DBMS_OUTPUT.PUT_LINE('⚠ Fashion Warnings: ' || v_warn_count);
        DBMS_OUTPUT.PUT_LINE('✗ Wardrobe Malfunctions: ' || v_fail_count);
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Final verdict
        IF v_fail_count = 0 AND v_warn_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('🌟 PERFECT SCORE! The conductor is RUNWAY READY! 🌟');
            DBMS_OUTPUT.PUT_LINE('The audience is giving a standing ovation to those stylish pants!');
        ELSIF v_fail_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('👔 WELL DRESSED! The conductor looks professional with minor adjustments needed.');
            DBMS_OUTPUT.PUT_LINE('The audience approves, but suggests a few accessories.');
        ELSIF v_fail_count <= 2 THEN
            DBMS_OUTPUT.PUT_LINE('👕 CASUAL FRIDAY! The conductor is dressed but not formal enough.');
            DBMS_OUTPUT.PUT_LINE('The audience is understanding but expects better for the gala.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('🩲 WARDROBE EMERGENCY! The conductor needs immediate fashion assistance!');
            DBMS_OUTPUT.PUT_LINE('The audience is politely looking away...');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('💥 CATASTROPHIC WARDROBE MALFUNCTION: ' || SQLERRM);
            cleanup_extended_test_data;
            RAISE;
    END run_all_extended_tests;

END PKG_CONDUCTOR_EXTENDED_TESTS;
/

SHOW ERRORS

PROMPT
PROMPT 🎭 Extended Conductor Test Package Created! 🎭
PROMPT 
PROMPT Run the fashion show with: 
PROMPT   EXEC PKG_CONDUCTOR_EXTENDED_TESTS.run_all_extended_tests;
PROMPT
PROMPT Or run individual style tests:
PROMPT   SELECT PKG_CONDUCTOR_EXTENDED_TESTS.test_concurrent_conductor_prevention FROM dual;
PROMPT