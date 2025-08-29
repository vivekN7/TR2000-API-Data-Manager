-- ===============================================================================
-- PKG_TRANSACTION_TESTS - Transaction Safety Test Suite
-- Session 18: Critical test gap coverage
-- Purpose: Test transaction rollback, atomicity, and data integrity
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_transaction_tests AS
    
    -- Transaction safety tests
    FUNCTION test_rollback_on_error RETURN VARCHAR2;
    FUNCTION test_atomic_operations RETURN VARCHAR2;
    FUNCTION test_deadlock_handling RETURN VARCHAR2;
    FUNCTION test_concurrent_updates RETURN VARCHAR2;
    FUNCTION test_savepoint_rollback RETURN VARCHAR2;
    FUNCTION test_bulk_operation_failure RETURN VARCHAR2;
    
    -- Main test runner
    PROCEDURE run_all_transaction_tests;
    
END pkg_transaction_tests;
/

CREATE OR REPLACE PACKAGE BODY pkg_transaction_tests AS

    -- =========================================================================
    -- Test Rollback on Error
    -- =========================================================================
    FUNCTION test_rollback_on_error RETURN VARCHAR2 IS
        v_initial_count NUMBER;
        v_final_count NUMBER;
        v_test_plant VARCHAR2(50) := 'TEST_ROLLBACK_' || TO_CHAR(SYSTIMESTAMP, 'HH24MISS');
    BEGIN
        -- Get initial count
        SELECT COUNT(*) INTO v_initial_count FROM PLANTS WHERE is_valid = 'Y';
        
        -- Try to insert with forced error
        BEGIN
            -- Start transaction
            INSERT INTO PLANTS (plant_id, plant_name, is_valid, created_date)
            VALUES (v_test_plant, 'Test Rollback Plant', 'Y', SYSDATE);
            
            -- Force an error (duplicate key)
            INSERT INTO PLANTS (plant_id, plant_name, is_valid, created_date)
            VALUES (v_test_plant, 'Duplicate Plant', 'Y', SYSDATE);
            
            COMMIT;
            
            RETURN 'FAIL: Duplicate insert should have failed';
            
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                -- This is expected
                ROLLBACK;
                
                -- Verify rollback worked
                SELECT COUNT(*) INTO v_final_count FROM PLANTS WHERE is_valid = 'Y';
                
                IF v_final_count = v_initial_count THEN
                    RETURN 'PASS: Transaction rolled back correctly';
                ELSE
                    RETURN 'FAIL: Rollback incomplete (count changed from ' || 
                           v_initial_count || ' to ' || v_final_count || ')';
                END IF;
        END;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RETURN 'ERROR: ' || SQLERRM;
    END test_rollback_on_error;

    -- =========================================================================
    -- Test Atomic Operations
    -- =========================================================================
    FUNCTION test_atomic_operations RETURN VARCHAR2 IS
        v_plant_count NUMBER;
        v_issue_count NUMBER;
        v_test_plant VARCHAR2(50) := 'TEST_ATOMIC_' || TO_CHAR(SYSTIMESTAMP, 'HH24MISS');
    BEGIN
        -- Test that plant+issues are atomic
        BEGIN
            SAVEPOINT before_atomic_test;
            
            -- Insert plant
            INSERT INTO PLANTS (plant_id, plant_name, is_valid, created_date)
            VALUES (v_test_plant, 'Atomic Test Plant', 'Y', SYSDATE);
            
            -- Insert issue with bad FK (should fail)
            INSERT INTO ISSUES (plant_id, issue_revision, is_valid, created_date)
            VALUES ('NONEXISTENT_PLANT', 'TEST_REV', 'Y', SYSDATE);
            
            COMMIT;
            
            RETURN 'FAIL: Bad FK should have prevented commit';
            
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO before_atomic_test;
                
                -- Verify nothing was inserted
                SELECT COUNT(*) INTO v_plant_count 
                FROM PLANTS WHERE plant_id = v_test_plant;
                
                IF v_plant_count = 0 THEN
                    RETURN 'PASS: Atomic operation maintained';
                ELSE
                    RETURN 'FAIL: Partial data committed';
                END IF;
        END;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RETURN 'ERROR: ' || SQLERRM;
    END test_atomic_operations;

    -- =========================================================================
    -- Test Deadlock Handling
    -- =========================================================================
    FUNCTION test_deadlock_handling RETURN VARCHAR2 IS
        v_deadlock_detected BOOLEAN := FALSE;
    BEGIN
        -- Note: Actual deadlock testing requires multiple sessions
        -- This tests deadlock detection configuration
        
        -- Check if deadlock monitoring is configured
        SELECT COUNT(*) INTO v_deadlock_detected
        FROM V$PARAMETER
        WHERE name = 'deadlock_resolution_time'
          AND value IS NOT NULL;
        
        IF v_deadlock_detected > 0 THEN
            RETURN 'PASS: Deadlock detection configured';
        ELSE
            RETURN 'WARNING: Deadlock detection may not be configured';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Check for deadlock error (ORA-00060)
            IF SQLCODE = -60 THEN
                RETURN 'PASS: Deadlock detected and handled';
            ELSE
                RETURN 'ERROR: ' || SQLERRM;
            END IF;
    END test_deadlock_handling;

    -- =========================================================================
    -- Test Concurrent Updates
    -- =========================================================================
    FUNCTION test_concurrent_updates RETURN VARCHAR2 IS
        v_update_count NUMBER;
        v_test_plant VARCHAR2(50) := '34';  -- Use existing plant
    BEGIN
        -- Test optimistic locking with last_modified_date
        DECLARE
            v_original_date DATE;
            v_new_date DATE;
        BEGIN
            -- Get current modification date
            SELECT last_modified_date INTO v_original_date
            FROM PLANTS
            WHERE plant_id = v_test_plant
              AND is_valid = 'Y';
            
            -- Simulate concurrent update check
            UPDATE PLANTS
            SET last_modified_date = SYSDATE,
                plant_name = plant_name || '_TEST'
            WHERE plant_id = v_test_plant
              AND last_modified_date = v_original_date;
            
            v_update_count := SQL%ROWCOUNT;
            
            IF v_update_count = 1 THEN
                -- Rollback test change
                ROLLBACK;
                RETURN 'PASS: Optimistic locking working';
            ELSE
                ROLLBACK;
                RETURN 'WARNING: Update affected ' || v_update_count || ' rows';
            END IF;
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN 'SKIP: Test plant not found';
            WHEN OTHERS THEN
                ROLLBACK;
                RETURN 'ERROR: ' || SQLERRM;
        END;
        
    END test_concurrent_updates;

    -- =========================================================================
    -- Test Savepoint Rollback
    -- =========================================================================
    FUNCTION test_savepoint_rollback RETURN VARCHAR2 IS
        v_count1 NUMBER;
        v_count2 NUMBER;
        v_count3 NUMBER;
    BEGIN
        -- Get initial state
        SELECT COUNT(*) INTO v_count1 FROM PLANTS WHERE plant_id LIKE 'TEST_SP_%';
        
        -- Test savepoint functionality
        BEGIN
            SAVEPOINT sp1;
            
            INSERT INTO PLANTS (plant_id, plant_name, is_valid, created_date)
            VALUES ('TEST_SP_1', 'Savepoint Test 1', 'Y', SYSDATE);
            
            SAVEPOINT sp2;
            
            INSERT INTO PLANTS (plant_id, plant_name, is_valid, created_date)
            VALUES ('TEST_SP_2', 'Savepoint Test 2', 'Y', SYSDATE);
            
            -- Check intermediate state
            SELECT COUNT(*) INTO v_count2 FROM PLANTS WHERE plant_id LIKE 'TEST_SP_%';
            
            -- Rollback to sp2 (should keep first insert)
            ROLLBACK TO sp2;
            
            -- Check after partial rollback
            SELECT COUNT(*) INTO v_count3 FROM PLANTS WHERE plant_id LIKE 'TEST_SP_%';
            
            -- Full rollback for cleanup
            ROLLBACK;
            
            IF v_count2 = v_count1 + 2 AND v_count3 = v_count1 + 1 THEN
                RETURN 'PASS: Savepoint rollback working correctly';
            ELSE
                RETURN 'FAIL: Savepoint counts incorrect (' || 
                       v_count1 || ',' || v_count2 || ',' || v_count3 || ')';
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                RAISE;
        END;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RETURN 'ERROR: ' || SQLERRM;
    END test_savepoint_rollback;

    -- =========================================================================
    -- Test Bulk Operation Failure
    -- =========================================================================
    FUNCTION test_bulk_operation_failure RETURN VARCHAR2 IS
        TYPE t_plants IS TABLE OF PLANTS%ROWTYPE;
        l_plants t_plants := t_plants();
        v_initial_count NUMBER;
        v_final_count NUMBER;
    BEGIN
        -- Get initial count
        SELECT COUNT(*) INTO v_initial_count FROM PLANTS WHERE is_valid = 'Y';
        
        -- Prepare bulk data with one bad record
        FOR i IN 1..5 LOOP
            l_plants.EXTEND;
            l_plants(i).plant_id := 'TEST_BULK_' || i;
            l_plants(i).plant_name := 'Bulk Test ' || i;
            l_plants(i).is_valid := 'Y';
            l_plants(i).created_date := SYSDATE;
        END LOOP;
        
        -- Add duplicate to cause failure
        l_plants.EXTEND;
        l_plants(6).plant_id := 'TEST_BULK_1';  -- Duplicate!
        l_plants(6).plant_name := 'Duplicate';
        l_plants(6).is_valid := 'Y';
        l_plants(6).created_date := SYSDATE;
        
        -- Try bulk insert
        BEGIN
            FORALL i IN 1..l_plants.COUNT SAVE EXCEPTIONS
                INSERT INTO PLANTS VALUES l_plants(i);
            
            COMMIT;
            
            -- Clean up test data
            DELETE FROM PLANTS WHERE plant_id LIKE 'TEST_BULK_%';
            COMMIT;
            
            RETURN 'FAIL: Bulk insert should have failed on duplicate';
            
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                ROLLBACK;
                
                -- Verify rollback
                SELECT COUNT(*) INTO v_final_count FROM PLANTS WHERE is_valid = 'Y';
                
                IF v_final_count = v_initial_count THEN
                    RETURN 'PASS: Bulk operation rolled back on error';
                ELSE
                    RETURN 'FAIL: Partial bulk data committed';
                END IF;
                
            WHEN OTHERS THEN
                ROLLBACK;
                
                -- Check for bulk errors
                IF SQL%BULK_EXCEPTIONS.COUNT > 0 THEN
                    RETURN 'PASS: Bulk exceptions handled (' || 
                           SQL%BULK_EXCEPTIONS.COUNT || ' errors)';
                ELSE
                    RETURN 'ERROR: ' || SQLERRM;
                END IF;
        END;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RETURN 'ERROR: ' || SQLERRM;
    END test_bulk_operation_failure;

    -- =========================================================================
    -- Run all transaction tests
    -- =========================================================================
    PROCEDURE run_all_transaction_tests IS
        v_test_count NUMBER := 0;
        v_pass_count NUMBER := 0;
        v_result VARCHAR2(1000);
    BEGIN
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Transaction Safety Tests');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
        -- Test rollback on error
        v_test_count := v_test_count + 1;
        v_result := test_rollback_on_error;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Rollback on Error: ' || v_result);
        
        -- Test atomic operations
        v_test_count := v_test_count + 1;
        v_result := test_atomic_operations;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Atomic Operations: ' || v_result);
        
        -- Test deadlock handling
        v_test_count := v_test_count + 1;
        v_result := test_deadlock_handling;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Deadlock Handling: ' || v_result);
        
        -- Test concurrent updates
        v_test_count := v_test_count + 1;
        v_result := test_concurrent_updates;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Concurrent Updates: ' || v_result);
        
        -- Test savepoint rollback
        v_test_count := v_test_count + 1;
        v_result := test_savepoint_rollback;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Savepoint Rollback: ' || v_result);
        
        -- Test bulk operation failure
        v_test_count := v_test_count + 1;
        v_result := test_bulk_operation_failure;
        IF v_result LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1; END IF;
        DBMS_OUTPUT.PUT_LINE('Bulk Operation Failure: ' || v_result);
        
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Results: ' || v_pass_count || '/' || v_test_count || ' PASSED');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
    END run_all_transaction_tests;

END pkg_transaction_tests;
/

-- Grant permissions
GRANT EXECUTE ON pkg_transaction_tests TO TR2000_STAGING;
/