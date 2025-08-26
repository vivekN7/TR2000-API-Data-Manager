-- ============================================================================
-- File: 03_run_tests.sql
-- Purpose: Execute ETL test suite and display results
-- Author: TR2000 ETL Team
-- Date: 2025-08-24
-- Usage: @deploy/06_testing/03_run_tests.sql
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 1000;
SET TIMING ON;

PROMPT
PROMPT ============================================================================
PROMPT ETL Testing Framework - Execution Script
PROMPT ============================================================================
PROMPT

-- Clean up any leftover test data first
PROMPT Cleaning up any existing test data...
EXEC PKG_SIMPLE_TESTS.cleanup_test_data;

PROMPT
PROMPT Running critical ETL tests...
PROMPT
EXEC PKG_SIMPLE_TESTS.run_critical_tests;

PROMPT
PROMPT ============================================================================
PROMPT Test Results Summary
PROMPT ============================================================================

-- Show today's test results
COLUMN test_name FORMAT A30
COLUMN status FORMAT A10
COLUMN error_msg FORMAT A50 WORD_WRAPPED
COLUMN execution_time_ms FORMAT 999999

SELECT 
    test_name,
    status,
    SUBSTR(error_msg, 1, 50) as error_msg,
    execution_time_ms,
    TO_CHAR(run_date, 'HH24:MI:SS') as run_time
FROM TEST_RESULTS 
WHERE run_date >= TRUNC(SYSDATE)
ORDER BY test_id DESC;

PROMPT
PROMPT ============================================================================
PROMPT Test Statistics
PROMPT ============================================================================

-- Show pass/fail summary
SELECT 
    COUNT(*) as total_tests,
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) as passed,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) as failed,
    SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) as errors,
    ROUND(100 * SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) / COUNT(*), 1) as pass_rate_pct
FROM TEST_RESULTS
WHERE run_date >= TRUNC(SYSDATE);

PROMPT
PROMPT ============================================================================
PROMPT Recent Failures (if any)
PROMPT ============================================================================

-- Show any failures
SELECT 
    test_name,
    SUBSTR(error_msg, 1, 100) as failure_reason
FROM TEST_RESULTS
WHERE status IN ('FAIL', 'ERROR')
  AND run_date >= TRUNC(SYSDATE)
ORDER BY test_id DESC;

PROMPT
PROMPT ============================================================================
PROMPT Cleanup Test Data
PROMPT ============================================================================
PROMPT
PROMPT Running final cleanup...
EXEC PKG_SIMPLE_TESTS.cleanup_test_data;

PROMPT
PROMPT ============================================================================
PROMPT Testing Complete
PROMPT ============================================================================
PROMPT
PROMPT To view all test results:   SELECT * FROM TEST_RESULTS ORDER BY test_id DESC;
PROMPT To view failures only:      SELECT * FROM V_TEST_FAILURES;
PROMPT To view summary by suite:   SELECT * FROM V_TEST_SUMMARY;
PROMPT
PROMPT To run tests again:         @deploy/06_testing/03_run_tests.sql
PROMPT To cleanup test data:       EXEC PKG_SIMPLE_TESTS.cleanup_test_data;
PROMPT
PROMPT ============================================================================