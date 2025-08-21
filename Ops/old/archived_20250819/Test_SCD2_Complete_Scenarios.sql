-- =====================================================
-- TEST SCRIPT: COMPLETE SCD2 SCENARIOS
-- Tests all possible data change scenarios:
-- 1. INSERT - New records
-- 2. UPDATE - Changed records  
-- 3. DELETE - Records removed from source
-- 4. REACTIVATE - Deleted records that return
-- 5. UNCHANGED - No changes
-- 6. MANUAL DB CHANGE - Detects corruption
-- =====================================================

SET SERVEROUTPUT ON;
SET LINESIZE 200;
SET PAGESIZE 50;

-- =====================================================
-- SETUP: Create test ETL run
-- =====================================================
DECLARE
    v_etl_run_id NUMBER;
BEGIN
    -- Create ETL run
    INSERT INTO ETL_CONTROL (RUN_TYPE, STATUS, START_TIME)
    VALUES ('TEST_SCD2', 'RUNNING', SYSDATE)
    RETURNING ETL_RUN_ID INTO v_etl_run_id;
    
    DBMS_OUTPUT.PUT_LINE('Created ETL Run ID: ' || v_etl_run_id);
    DBMS_OUTPUT.PUT_LINE('==========================================');
    
    -- =====================================================
    -- SCENARIO 1: INITIAL LOAD (3 operators)
    -- =====================================================
    DBMS_OUTPUT.PUT_LINE('SCENARIO 1: Initial Load');
    DBMS_OUTPUT.PUT_LINE('--------------------------');
    
    -- Insert into staging
    INSERT INTO STG_OPERATORS VALUES (1, 'Equinor', v_etl_run_id);
    INSERT INTO STG_OPERATORS VALUES (2, 'Shell', v_etl_run_id);
    INSERT INTO STG_OPERATORS VALUES (3, 'BP', v_etl_run_id);
    
    -- Process SCD2
    SP_PROCESS_OPERATORS_SCD2_COMPLETE(v_etl_run_id);
    
    -- Show results
    DBMS_OUTPUT.PUT_LINE('Current operators after initial load:');
    FOR r IN (SELECT * FROM V_OPERATORS_CURRENT ORDER BY OPERATOR_ID) LOOP
        DBMS_OUTPUT.PUT_LINE('  ID=' || r.OPERATOR_ID || 
                           ', Name=' || r.OPERATOR_NAME || 
                           ', Change=' || r.CHANGE_TYPE);
    END LOOP;
    
    -- =====================================================
    -- SCENARIO 2: UPDATE (Change operator name)
    -- =====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'SCENARIO 2: Update Operator Name');
    DBMS_OUTPUT.PUT_LINE('--------------------------');
    
    v_etl_run_id := ETL_RUN_ID_SEQ.NEXTVAL;
    
    -- Simulate API returning updated data
    INSERT INTO STG_OPERATORS VALUES (1, 'Equinor ASA', v_etl_run_id);  -- Changed
    INSERT INTO STG_OPERATORS VALUES (2, 'Shell', v_etl_run_id);       -- Unchanged
    INSERT INTO STG_OPERATORS VALUES (3, 'BP', v_etl_run_id);          -- Unchanged
    
    -- Process SCD2
    SP_PROCESS_OPERATORS_SCD2_COMPLETE(v_etl_run_id);
    
    -- Show current records
    DBMS_OUTPUT.PUT_LINE('Current operators after update:');
    FOR r IN (SELECT * FROM V_OPERATORS_CURRENT ORDER BY OPERATOR_ID) LOOP
        DBMS_OUTPUT.PUT_LINE('  ID=' || r.OPERATOR_ID || 
                           ', Name=' || r.OPERATOR_NAME || 
                           ', Change=' || r.CHANGE_TYPE);
    END LOOP;
    
    -- Show history for operator 1
    DBMS_OUTPUT.PUT_LINE('History for Operator 1:');
    FOR r IN (SELECT * FROM OPERATORS WHERE OPERATOR_ID = 1 ORDER BY VALID_FROM) LOOP
        DBMS_OUTPUT.PUT_LINE('  Name=' || r.OPERATOR_NAME || 
                           ', Valid=' || TO_CHAR(r.VALID_FROM, 'HH24:MI:SS') ||
                           ' to ' || NVL(TO_CHAR(r.VALID_TO, 'HH24:MI:SS'), 'CURRENT') ||
                           ', Change=' || r.CHANGE_TYPE);
    END LOOP;
    
    -- =====================================================
    -- SCENARIO 3: DELETE (Operator 3 removed from API)
    -- =====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'SCENARIO 3: Delete Operator 3');
    DBMS_OUTPUT.PUT_LINE('--------------------------');
    
    v_etl_run_id := ETL_RUN_ID_SEQ.NEXTVAL;
    
    -- API returns only 2 operators (3 is missing)
    INSERT INTO STG_OPERATORS VALUES (1, 'Equinor ASA', v_etl_run_id);
    INSERT INTO STG_OPERATORS VALUES (2, 'Shell', v_etl_run_id);
    -- Operator 3 NOT in staging - simulates deletion
    
    -- Process SCD2
    SP_PROCESS_OPERATORS_SCD2_COMPLETE(v_etl_run_id);
    
    -- Show current records
    DBMS_OUTPUT.PUT_LINE('Current operators after deletion:');
    FOR r IN (SELECT * FROM V_OPERATORS_CURRENT ORDER BY OPERATOR_ID) LOOP
        DBMS_OUTPUT.PUT_LINE('  ID=' || r.OPERATOR_ID || 
                           ', Name=' || r.OPERATOR_NAME || 
                           ', Change=' || r.CHANGE_TYPE);
    END LOOP;
    
    -- Show deleted record
    DBMS_OUTPUT.PUT_LINE('Deleted records:');
    FOR r IN (SELECT * FROM OPERATORS WHERE CHANGE_TYPE = 'DELETE') LOOP
        DBMS_OUTPUT.PUT_LINE('  ID=' || r.OPERATOR_ID || 
                           ', Name=' || r.OPERATOR_NAME || 
                           ', Deleted=' || TO_CHAR(r.DELETE_DATE, 'HH24:MI:SS'));
    END LOOP;
    
    -- =====================================================
    -- SCENARIO 4: REACTIVATE (Operator 3 returns)
    -- =====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'SCENARIO 4: Reactivate Operator 3');
    DBMS_OUTPUT.PUT_LINE('--------------------------');
    
    v_etl_run_id := ETL_RUN_ID_SEQ.NEXTVAL;
    
    -- Operator 3 appears again in API
    INSERT INTO STG_OPERATORS VALUES (1, 'Equinor ASA', v_etl_run_id);
    INSERT INTO STG_OPERATORS VALUES (2, 'Shell', v_etl_run_id);
    INSERT INTO STG_OPERATORS VALUES (3, 'BP plc', v_etl_run_id);  -- Back with new name
    
    -- Process SCD2
    SP_PROCESS_OPERATORS_SCD2_COMPLETE(v_etl_run_id);
    
    -- Show current records
    DBMS_OUTPUT.PUT_LINE('Current operators after reactivation:');
    FOR r IN (SELECT * FROM V_OPERATORS_CURRENT ORDER BY OPERATOR_ID) LOOP
        DBMS_OUTPUT.PUT_LINE('  ID=' || r.OPERATOR_ID || 
                           ', Name=' || r.OPERATOR_NAME || 
                           ', Change=' || r.CHANGE_TYPE);
    END LOOP;
    
    -- Show full history for operator 3
    DBMS_OUTPUT.PUT_LINE('Full history for Operator 3:');
    FOR r IN (SELECT * FROM OPERATORS WHERE OPERATOR_ID = 3 ORDER BY VALID_FROM) LOOP
        DBMS_OUTPUT.PUT_LINE('  Name=' || r.OPERATOR_NAME || 
                           ', Change=' || r.CHANGE_TYPE ||
                           ', Current=' || r.IS_CURRENT ||
                           ', Delete=' || NVL(TO_CHAR(r.DELETE_DATE, 'HH24:MI:SS'), 'N/A'));
    END LOOP;
    
    -- =====================================================
    -- SCENARIO 5: MANUAL DB CHANGE DETECTION
    -- =====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'SCENARIO 5: Manual DB Change Detection');
    DBMS_OUTPUT.PUT_LINE('--------------------------');
    
    -- Manually corrupt data (simulating manual DB edit)
    UPDATE OPERATORS 
    SET OPERATOR_NAME = 'CORRUPTED NAME'
    WHERE OPERATOR_ID = 2 
      AND IS_CURRENT = 'Y';
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Manually corrupted Operator 2 name to "CORRUPTED NAME"');
    
    v_etl_run_id := ETL_RUN_ID_SEQ.NEXTVAL;
    
    -- API still returns correct data
    INSERT INTO STG_OPERATORS VALUES (1, 'Equinor ASA', v_etl_run_id);
    INSERT INTO STG_OPERATORS VALUES (2, 'Shell', v_etl_run_id);  -- Correct name
    INSERT INTO STG_OPERATORS VALUES (3, 'BP plc', v_etl_run_id);
    
    -- Process SCD2 - should detect and fix corruption
    SP_PROCESS_OPERATORS_SCD2_COMPLETE(v_etl_run_id);
    
    -- Show results
    DBMS_OUTPUT.PUT_LINE('After self-healing:');
    FOR r IN (SELECT * FROM V_OPERATORS_CURRENT ORDER BY OPERATOR_ID) LOOP
        DBMS_OUTPUT.PUT_LINE('  ID=' || r.OPERATOR_ID || 
                           ', Name=' || r.OPERATOR_NAME || 
                           ', Change=' || r.CHANGE_TYPE);
    END LOOP;
    
    -- =====================================================
    -- SCENARIO 6: NEW OPERATOR WHILE OTHERS CHANGE
    -- =====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'SCENARIO 6: Mixed Operations');
    DBMS_OUTPUT.PUT_LINE('--------------------------');
    
    v_etl_run_id := ETL_RUN_ID_SEQ.NEXTVAL;
    
    -- Mixed scenario
    INSERT INTO STG_OPERATORS VALUES (1, 'Equinor ASA', v_etl_run_id);     -- Unchanged
    -- Operator 2 missing (deleted)
    INSERT INTO STG_OPERATORS VALUES (3, 'British Petroleum', v_etl_run_id); -- Updated
    INSERT INTO STG_OPERATORS VALUES (4, 'TotalEnergies', v_etl_run_id);    -- New
    
    -- Process SCD2
    SP_PROCESS_OPERATORS_SCD2_COMPLETE(v_etl_run_id);
    
    -- Show final state
    DBMS_OUTPUT.PUT_LINE('Final state after mixed operations:');
    FOR r IN (SELECT * FROM V_OPERATORS_CURRENT ORDER BY OPERATOR_ID) LOOP
        DBMS_OUTPUT.PUT_LINE('  ID=' || r.OPERATOR_ID || 
                           ', Name=' || r.OPERATOR_NAME || 
                           ', Change=' || r.CHANGE_TYPE);
    END LOOP;
    
    -- =====================================================
    -- SUMMARY: Show audit trail
    -- =====================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '==========================================');
    DBMS_OUTPUT.PUT_LINE('COMPLETE AUDIT TRAIL:');
    DBMS_OUTPUT.PUT_LINE('==========================================');
    
    FOR r IN (
        SELECT 
            OPERATOR_ID,
            OPERATOR_NAME,
            CHANGE_TYPE,
            TO_CHAR(VALID_FROM, 'HH24:MI:SS') as VALID_FROM_TIME,
            NVL(TO_CHAR(VALID_TO, 'HH24:MI:SS'), 'CURRENT') as VALID_TO_TIME,
            NVL(TO_CHAR(DELETE_DATE, 'HH24:MI:SS'), 'N/A') as DELETE_TIME,
            IS_CURRENT
        FROM OPERATORS
        ORDER BY OPERATOR_ID, VALID_FROM
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            'ID=' || r.OPERATOR_ID || 
            ', Name=' || RPAD(r.OPERATOR_NAME, 20) ||
            ', Change=' || RPAD(NVL(r.CHANGE_TYPE, 'N/A'), 12) ||
            ', Valid=' || r.VALID_FROM_TIME || '-' || r.VALID_TO_TIME ||
            ', Current=' || r.IS_CURRENT ||
            ', Deleted=' || r.DELETE_TIME
        );
    END LOOP;
    
    -- Show change type counts
    DBMS_OUTPUT.PUT_LINE(CHR(10) || 'Change Type Summary:');
    FOR r IN (
        SELECT CHANGE_TYPE, COUNT(*) as CNT
        FROM OPERATORS
        GROUP BY CHANGE_TYPE
        ORDER BY CHANGE_TYPE
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(NVL(r.CHANGE_TYPE, 'INITIAL'), 15) || ': ' || r.CNT);
    END LOOP;
    
END;
/

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- View current state
SELECT 'CURRENT OPERATORS' as QUERY_TYPE FROM DUAL;
SELECT * FROM V_OPERATORS_CURRENT ORDER BY OPERATOR_ID;

-- View full audit trail
SELECT 'FULL AUDIT TRAIL' as QUERY_TYPE FROM DUAL;
SELECT 
    TABLE_NAME,
    PRIMARY_KEY,
    CHANGE_TYPE,
    TO_CHAR(VALID_FROM, 'YYYY-MM-DD HH24:MI:SS') as VALID_FROM,
    TO_CHAR(VALID_TO, 'YYYY-MM-DD HH24:MI:SS') as VALID_TO,
    TO_CHAR(DELETE_DATE, 'YYYY-MM-DD HH24:MI:SS') as DELETE_DATE,
    ETL_RUN_ID
FROM V_AUDIT_TRAIL
WHERE TABLE_NAME = 'OPERATORS'
ORDER BY VALID_FROM DESC;

-- Check ETL Control stats
SELECT 'ETL CONTROL STATS' as QUERY_TYPE FROM DUAL;
SELECT 
    ETL_RUN_ID,
    RUN_TYPE,
    RECORDS_LOADED,
    RECORDS_UPDATED,
    RECORDS_UNCHANGED,
    RECORDS_DELETED,
    RECORDS_REACTIVATED
FROM ETL_CONTROL
WHERE RUN_TYPE = 'TEST_SCD2'
ORDER BY ETL_RUN_ID;