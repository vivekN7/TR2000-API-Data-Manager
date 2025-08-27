-- ===============================================================================
-- Run Comprehensive Tests
-- Date: 2025-08-27
-- Purpose: Execute all test suites and validate system
-- Usage: @Database/scripts/run_comprehensive_tests.sql
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET TIMING ON

PROMPT
PROMPT ===============================================================================
PROMPT Starting Comprehensive Test Run
PROMPT ===============================================================================
PROMPT

-- ===============================================================================
-- Part 1: Environment Check
-- ===============================================================================
PROMPT === Environment Check ===
PROMPT

-- Clean test data
EXEC PKG_TEST_ISOLATION.clean_all_test_data;

-- Verify no contamination
EXEC PKG_TEST_ISOLATION.validate_no_test_contamination;

-- Show current selections
PROMPT Current Selections:
SELECT 'Plant: ' || plant_id || ' (Active: ' || is_active || ')' as selection
FROM SELECTED_PLANTS
WHERE is_active = 'Y'
ORDER BY plant_id;

SELECT 'Issue: ' || plant_id || '/' || issue_revision || ' (Active: ' || is_active || ')' as selection
FROM SELECTED_ISSUES  
WHERE is_active = 'Y'
ORDER BY plant_id, issue_revision;

-- ===============================================================================
-- Part 2: Run Test Suites
-- ===============================================================================
PROMPT
PROMPT === Running Test Suites ===
PROMPT

-- Run PKG_SIMPLE_TESTS
PROMPT Running PKG_SIMPLE_TESTS (21 tests)...
EXEC PKG_SIMPLE_TESTS.run_critical_tests;

-- Run PKG_CONDUCTOR_TESTS
PROMPT
PROMPT Running PKG_CONDUCTOR_TESTS (5 tests)...
EXEC PKG_CONDUCTOR_TESTS.run_all_conductor_tests;

-- Run PKG_CONDUCTOR_EXTENDED_TESTS
PROMPT
PROMPT Running PKG_CONDUCTOR_EXTENDED_TESTS (8 tests)...
EXEC PKG_CONDUCTOR_EXTENDED_TESTS.run_all_extended_tests;

-- Run PKG_REFERENCE_COMPREHENSIVE_TESTS
PROMPT
PROMPT Running PKG_REFERENCE_COMPREHENSIVE_TESTS (3 tests)...
EXEC PKG_REFERENCE_COMPREHENSIVE_TESTS.run_all_reference_tests;

-- ===============================================================================
-- Part 3: Test Results Summary
-- ===============================================================================
PROMPT
PROMPT === Test Results Summary ===
PROMPT

-- Show test counts by status
SELECT status, COUNT(*) as test_count
FROM TEST_RESULTS
WHERE test_timestamp > SYSTIMESTAMP - INTERVAL '30' MINUTE
GROUP BY status
ORDER BY status;

-- Show any failures
PROMPT
PROMPT Failed Tests (if any):
SELECT test_name, SUBSTR(error_message, 1, 80) as error_msg
FROM TEST_RESULTS
WHERE test_timestamp > SYSTIMESTAMP - INTERVAL '30' MINUTE
AND status = 'FAIL'
ORDER BY test_timestamp DESC;

-- ===============================================================================
-- Part 4: Data Validation
-- ===============================================================================
PROMPT
PROMPT === Data Validation ===
PROMPT

-- Check reference counts
PROMPT Reference Table Status:
SELECT 
    table_name,
    total_count,
    valid_count,
    invalid_count
FROM (
    SELECT 'PCS_REFERENCES' as table_name,
           COUNT(*) as total_count,
           COUNT(CASE WHEN is_valid = 'Y' THEN 1 END) as valid_count,
           COUNT(CASE WHEN is_valid = 'N' THEN 1 END) as invalid_count
    FROM PCS_REFERENCES
    UNION ALL
    SELECT 'VDS_REFERENCES',
           COUNT(*),
           COUNT(CASE WHEN is_valid = 'Y' THEN 1 END),
           COUNT(CASE WHEN is_valid = 'N' THEN 1 END)
    FROM VDS_REFERENCES
    UNION ALL
    SELECT 'MDS_REFERENCES',
           COUNT(*),
           COUNT(CASE WHEN is_valid = 'Y' THEN 1 END),
           COUNT(CASE WHEN is_valid = 'N' THEN 1 END)
    FROM MDS_REFERENCES
    UNION ALL
    SELECT 'PIPE_ELEMENT_REF',
           COUNT(*),
           COUNT(CASE WHEN is_valid = 'Y' THEN 1 END),
           COUNT(CASE WHEN is_valid = 'N' THEN 1 END)
    FROM PIPE_ELEMENT_REFERENCES
    UNION ALL
    SELECT 'VSK_REFERENCES',
           COUNT(*),
           COUNT(CASE WHEN is_valid = 'Y' THEN 1 END),
           COUNT(CASE WHEN is_valid = 'N' THEN 1 END)
    FROM VSK_REFERENCES
    UNION ALL
    SELECT 'EDS_REFERENCES',
           COUNT(*),
           COUNT(CASE WHEN is_valid = 'Y' THEN 1 END),
           COUNT(CASE WHEN is_valid = 'N' THEN 1 END)
    FROM EDS_REFERENCES
)
WHERE total_count > 0
ORDER BY table_name;

-- Check for orphaned records
PROMPT
PROMPT Checking for orphaned references:
SELECT 
    'PCS orphans' as check_type,
    COUNT(*) as orphan_count
FROM PCS_REFERENCES pr
WHERE NOT EXISTS (
    SELECT 1 FROM ISSUES i
    WHERE i.plant_id = pr.plant_id
    AND i.issue_revision = pr.issue_revision
    AND i.is_valid = 'Y'
) AND pr.is_valid = 'Y';

-- Check system health
PROMPT
PROMPT System Health Check:
SELECT 
    'Invalid Objects' as check_type,
    COUNT(*) as count
FROM user_objects 
WHERE status = 'INVALID';

-- ===============================================================================
-- Part 5: Final Summary
-- ===============================================================================
PROMPT
PROMPT === Final Summary ===
PROMPT

SELECT 
    'Valid Plants' as metric, COUNT(*) as count FROM PLANTS WHERE is_valid = 'Y'
UNION ALL
SELECT 'Valid Issues', COUNT(*) FROM ISSUES WHERE is_valid = 'Y'
UNION ALL  
SELECT 'Selected Plants', COUNT(*) FROM SELECTED_PLANTS WHERE is_active = 'Y'
UNION ALL
SELECT 'Selected Issues', COUNT(*) FROM SELECTED_ISSUES WHERE is_active = 'Y'
UNION ALL
SELECT 'Total Valid References', SUM(cnt) FROM (
    SELECT COUNT(*) cnt FROM PCS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM VSK_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM EDS_REFERENCES WHERE is_valid = 'Y'
);

PROMPT
PROMPT ===============================================================================
PROMPT Test Run Complete
PROMPT ===============================================================================
PROMPT