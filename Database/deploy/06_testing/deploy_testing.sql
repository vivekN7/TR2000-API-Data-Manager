-- ============================================================================
-- File: deploy_testing.sql
-- Purpose: Deploy the complete testing framework
-- Author: TR2000 ETL Team
-- Date: 2025-08-24
-- Usage: @deploy/06_testing/deploy_testing.sql
-- ============================================================================

SET ECHO ON;
SET SERVEROUTPUT ON;

PROMPT
PROMPT ============================================================================
PROMPT Deploying ETL Testing Framework
PROMPT ============================================================================
PROMPT

-- Step 1: Create test tables
PROMPT Creating test infrastructure tables...
@01_test_tables.sql

-- Step 2: Create test package
PROMPT Creating PKG_SIMPLE_TESTS package...
@02_pkg_simple_tests.sql

-- Step 3: Create comprehensive reference tests
PROMPT Creating PKG_REFERENCE_COMPREHENSIVE_TESTS package...
@04_reference_comprehensive_tests.sql

PROMPT
PROMPT ============================================================================
PROMPT Testing Framework Deployment Complete
PROMPT ============================================================================
PROMPT
PROMPT Available Components:
PROMPT - TEST_RESULTS table: Stores test execution results
PROMPT - TEMP_TEST_DATA table: Stores temporary test data
PROMPT - V_TEST_SUMMARY view: Shows test summary by suite
PROMPT - V_TEST_FAILURES view: Shows recent test failures
PROMPT - PKG_SIMPLE_TESTS package: Contains all test functions
PROMPT
PROMPT To run tests: @deploy/06_testing/03_run_tests.sql
PROMPT
PROMPT ============================================================================