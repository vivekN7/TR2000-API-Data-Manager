-- ===============================================================================
-- Final System Test - No Side Effects
-- Date: 2025-08-27
-- Purpose: Final validation without triggering cascades
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100

PROMPT
PROMPT ===============================================================================
PROMPT FINAL SYSTEM TEST - Ready for Task 8
PROMPT ===============================================================================
PROMPT

-- ===============================================================================
-- 1. Environment Status
-- ===============================================================================
PROMPT === 1. Environment Status ===
PROMPT

-- Check for invalid objects
SELECT 'Invalid Objects' as check, COUNT(*) as count 
FROM user_objects WHERE status = 'INVALID';

-- Check test data contamination
EXEC PKG_TEST_ISOLATION.validate_no_test_contamination;

-- ===============================================================================
-- 2. Data Summary
-- ===============================================================================
PROMPT
PROMPT === 2. Data Summary ===
PROMPT

SELECT 
    'Plants (Valid)' as entity,
    COUNT(*) as count
FROM PLANTS WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'Issues (Valid)',
    COUNT(*)
FROM ISSUES WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'Selected Plants',
    COUNT(*)
FROM SELECTED_PLANTS WHERE is_active = 'Y'
UNION ALL
SELECT 
    'Selected Issues',
    COUNT(*)
FROM SELECTED_ISSUES WHERE is_active = 'Y';

-- ===============================================================================
-- 3. Reference Data Summary
-- ===============================================================================
PROMPT
PROMPT === 3. Reference Data Summary ===
PROMPT

SELECT 
    reference_type,
    COUNT(*) as total_count,
    COUNT(CASE WHEN is_valid = 'Y' THEN 1 END) as valid_count
FROM (
    SELECT 'PCS' as reference_type, is_valid FROM PCS_REFERENCES
    UNION ALL SELECT 'VDS', is_valid FROM VDS_REFERENCES
    UNION ALL SELECT 'MDS', is_valid FROM MDS_REFERENCES
    UNION ALL SELECT 'PIPE', is_valid FROM PIPE_ELEMENT_REFERENCES
    UNION ALL SELECT 'VSK', is_valid FROM VSK_REFERENCES
    UNION ALL SELECT 'EDS', is_valid FROM EDS_REFERENCES
    UNION ALL SELECT 'SC', is_valid FROM SC_REFERENCES
    UNION ALL SELECT 'VSM', is_valid FROM VSM_REFERENCES
    UNION ALL SELECT 'ESK', is_valid FROM ESK_REFERENCES
)
GROUP BY reference_type
ORDER BY reference_type;

-- Total valid references
SELECT 'TOTAL VALID REFERENCES' as summary, SUM(cnt) as count FROM (
    SELECT COUNT(*) cnt FROM PCS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM VSK_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM EDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM SC_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM VSM_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM ESK_REFERENCES WHERE is_valid = 'Y'
);

-- ===============================================================================
-- 4. Run Basic Tests (Non-Destructive)
-- ===============================================================================
PROMPT
PROMPT === 4. Basic Tests (Non-Destructive) ===
PROMPT

DECLARE
    v_result VARCHAR2(4000);
    v_pass_count NUMBER := 0;
    v_fail_count NUMBER := 0;
BEGIN
    -- Test 1: API Configuration
    BEGIN
        SELECT COUNT(*) INTO v_pass_count
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL'
        AND setting_value = 'https://equinor.pipespec-api.presight.com';
        
        IF v_pass_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('✓ API Configuration: PASS');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ API Configuration: FAIL');
            v_fail_count := v_fail_count + 1;
        END IF;
    END;
    
    -- Test 2: Cascade Triggers Enabled
    BEGIN
        SELECT COUNT(*) INTO v_pass_count
        FROM user_triggers
        WHERE trigger_name IN ('TRG_CASCADE_PLANT_TO_ISSUES', 'TRG_CASCADE_ISSUE_TO_REFERENCES')
        AND status = 'ENABLED';
        
        IF v_pass_count = 2 THEN
            DBMS_OUTPUT.PUT_LINE('✓ Cascade Triggers: PASS');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ Cascade Triggers: FAIL');
            v_fail_count := v_fail_count + 1;
        END IF;
    END;
    
    -- Test 3: Foreign Key Constraints
    BEGIN
        SELECT COUNT(*) INTO v_pass_count
        FROM user_constraints
        WHERE constraint_type = 'R'
        AND table_name LIKE '%_REFERENCES'
        AND status = 'ENABLED';
        
        IF v_pass_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('✓ Foreign Key Constraints: PASS (' || v_pass_count || ' constraints)');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ Foreign Key Constraints: FAIL');
            v_fail_count := v_fail_count + 1;
        END IF;
    END;
    
    -- Test 4: Check for Orphaned References
    BEGIN
        SELECT COUNT(*) INTO v_pass_count
        FROM PCS_REFERENCES pr
        WHERE NOT EXISTS (
            SELECT 1 FROM ISSUES i
            WHERE i.plant_id = pr.plant_id
            AND i.issue_revision = pr.issue_revision
            AND i.is_valid = 'Y'
        ) AND pr.is_valid = 'Y';
        
        IF v_pass_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('✓ No Orphaned References: PASS');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ Orphaned References Found: FAIL (' || v_pass_count || ' orphans)');
            v_fail_count := v_fail_count + 1;
        END IF;
    END;
    
    -- Test 5: ETL Operations Package Valid
    BEGIN
        SELECT COUNT(*) INTO v_pass_count
        FROM user_objects
        WHERE object_name = 'PKG_ETL_OPERATIONS'
        AND status = 'VALID';
        
        IF v_pass_count = 2 THEN -- Package and Package Body
            DBMS_OUTPUT.PUT_LINE('✓ PKG_ETL_OPERATIONS: PASS');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✗ PKG_ETL_OPERATIONS: INVALID');
            v_fail_count := v_fail_count + 1;
        END IF;
    END;
    
    -- Final Summary
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '========================================');
    IF v_fail_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('ALL TESTS PASSED! System ready for Task 8.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ISSUES FOUND: ' || v_fail_count || ' tests failed');
    END IF;
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

-- ===============================================================================
-- 5. Performance Metrics
-- ===============================================================================
PROMPT
PROMPT === 5. Performance Metrics ===
PROMPT

-- Recent ETL runs
SELECT 
    run_type,
    COUNT(*) as runs,
    ROUND(AVG(duration_seconds), 2) as avg_duration_sec,
    MAX(TO_CHAR(end_time, 'MM/DD HH24:MI')) as last_run
FROM ETL_RUN_LOG
WHERE status = 'SUCCESS'
AND start_time > SYSTIMESTAMP - INTERVAL '1' DAY
GROUP BY run_type
ORDER BY run_type;

-- ===============================================================================
-- 6. System Health Dashboard
-- ===============================================================================
PROMPT
PROMPT === 6. System Health Dashboard ===
PROMPT

SELECT * FROM V_SYSTEM_HEALTH_DASHBOARD
WHERE entity_type != 'Invalid Objects' OR valid_count > 0;

-- ===============================================================================
-- Final Status
-- ===============================================================================
PROMPT
PROMPT ===============================================================================
PROMPT EXPECTED RESULTS:
PROMPT - 0 Invalid Objects
PROMPT - 130 Valid Plants
PROMPT - 20 Valid Issues
PROMPT - 4,442 Valid References
PROMPT - 2 Cascade Triggers Enabled
PROMPT - 0 Orphaned References
PROMPT - All Tests PASSED
PROMPT ===============================================================================
PROMPT