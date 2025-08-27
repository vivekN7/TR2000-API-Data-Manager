# ETL Test Matrix - Complete Testing Coverage
*Last Updated: 2025-08-27*
*Version: 3.0 - Updated with actual test implementation status*

## Purpose
Map every potential failure point in the ETL pipeline to specific test procedures, documenting actual implementation status and coverage gaps.

## Current Test Coverage Summary
- **Total Tests Implemented**: 27 across 5 packages
- **Tests Passing**: 24
- **Tests Failing**: 1 (empty selection handling)
- **Tests with Warnings**: 2 (reference table checks)
- **Overall Coverage**: ~35-40% of potential scenarios

## Test Packages Overview

| Package | Declared | Implemented | Passing | Status |
|---------|----------|-------------|---------|--------|
| **PKG_SIMPLE_TESTS** | 21 | 5 | 5 | ⚠️ Partial |
| **PKG_CONDUCTOR_TESTS** | 5 | 5 | 4 | ✅ Complete |
| **PKG_CONDUCTOR_EXTENDED_TESTS** | 8 | 8 | 8 | ✅ Complete |
| **PKG_REFERENCE_COMPREHENSIVE_TESTS** | 13 | 13 | 11 | ✅ Complete |
| **PKG_TEST_ISOLATION** | N/A | N/A | N/A | ✅ Utility |
| **PKG_ADDITIONAL_TESTS** | 0 | 0 | 0 | ❌ Not created |

---

## Test Result Tracking Structure

The **TEST_RESULTS** table structure (Note: test_timestamp column missing, causes errors):

| Column | Purpose | Example |
|--------|---------|---------|
| **test_name** | Test procedure name | 'test_api_connection' |
| **status** | Test outcome | 'PASS', 'FAIL', 'ERROR', 'WARNING' |
| **error_message** | Failure details | 'Connection timeout after 30s' |
| **execution_time_ms** | Performance metric | 1500 |
| **test_date** | When test ran | SYSDATE |

---

## 1. PKG_SIMPLE_TESTS - Core Functionality Tests

### Implemented Tests (5 of 21)
| Test Function | Purpose | Status | Notes |
|--------------|---------|--------|-------|
| **test_api_connection** | Basic API connectivity | ✅ PASS | Checks TR2000_UTIL proxy |
| **test_json_parsing** | JSON date/path parsing | ✅ PASS | Tests JSON_TABLE functionality |
| **test_soft_deletes** | Cascade soft delete logic | ✅ PASS | Verifies is_valid='N' cascades |
| **test_selection_cascade** | Selection management | ✅ PASS | Tests SELECTED_PLANTS/ISSUES |
| **test_error_capture** | Error logging | ✅ PASS | Verifies ETL_ERROR_LOG |

### Declared but NOT Implemented (16)
```sql
-- Priority 1: Reference Table Tests
test_invalid_fk           -- FK violations for references
test_reference_cascade    -- Reference deletion cascades
test_reference_parsing    -- Reference JSON structure
test_orphan_prevention    -- Prevent orphaned records

-- Priority 2: Performance Tests
test_bulk_operations      -- Batch processing
test_transaction_rollback -- Transaction safety
test_large_json          -- Large payload handling
test_memory_limits       -- Memory constraints
test_vds_performance     -- 44k record test
test_api_timeout         -- Timeout handling
test_api_500            -- Server error handling
test_api_503            -- Service unavailable
test_rate_limit         -- Rate limiting

-- Priority 3: Recovery Tests
test_partial_failure_recovery -- Partial failure handling

-- Priority 4: Integration
test_all_selected_issues_get_references -- Multi-issue processing
```

---

## 2. PKG_CONDUCTOR_TESTS - ETL Orchestration Tests

### All 5 Tests Implemented
| Test | Purpose | Status | Issue |
|------|---------|--------|-------|
| **test_etl_execution_order** | Verify proper sequencing | ✅ PASS | - |
| **test_partial_plant_failure** | Handle partial failures | ✅ PASS | - |
| **test_etl_idempotency** | Prevent duplicates | ✅ PASS | - |
| **test_etl_with_no_selections** | Empty selection handling | ❌ FAIL | Returns PARTIAL not NO_DATA |
| **test_etl_status_reporting** | Status tracking | ✅ PASS | - |

**Known Issue**: Tests call `run_full_etl()` which processes REAL plants (124, 34), causing reference invalidation.

---

## 3. PKG_CONDUCTOR_EXTENDED_TESTS - Advanced Scenarios

### All 8 Tests Implemented and Passing
| Test | Purpose | Result |
|------|---------|--------|
| **test_concurrent_conductor_prevention** | Prevent concurrent ETL | ✅ PASS |
| **test_conductor_memory_leak** | Memory leak detection | ✅ PASS |
| **test_conductor_resume_after_crash** | Crash recovery | ✅ PASS |
| **test_conductor_performance_degradation** | Performance monitoring | ✅ PASS |
| **test_conductor_audit_trail** | Audit completeness | ✅ PASS |
| **test_conductor_error_cascade** | Error handling | ✅ PASS |
| **test_conductor_data_consistency** | Data integrity | ✅ PASS |
| **test_conductor_cleanup_orphans** | Orphan prevention | ✅ PASS |

---

## 4. PKG_REFERENCE_COMPREHENSIVE_TESTS - Reference Validation

### 13 Tests Across 9 Reference Types
| Test Category | Status | Notes |
|---------------|--------|-------|
| **Individual Type Tests** (9) | ⚠️ 7 PASS, 2 WARN | PCS and VDS show warnings when empty |
| **Cascade System** | ✅ PASS | 2 triggers enabled |
| **JSON Parsing** | ✅ PASS | PKG_PARSE_REFERENCES valid |
| **FK Constraints** | ✅ PASS | All tables have FKs |
| **Soft Delete** | ✅ PASS | All have IS_VALID column |

---

## 5. PKG_TEST_ISOLATION - Test Data Management

### Key Functions
| Function | Purpose | Status |
|----------|---------|--------|
| **clean_all_test_data** | Remove test records | ✅ Working |
| **validate_no_test_contamination** | Check for test data | ✅ Working |
| **is_test_data** | Identify test records | ✅ Working |
| **get_test_data_summary** | Test data report | ✅ Working |

### Handles Test Prefixes
- TEST_%
- COND_TEST_%
- EXT_TEST_%

---

## Critical Test Gaps

### High Priority Gaps
1. **API Error Handling** - No tests for 404, 500, 503 responses
2. **Performance Testing** - No large dataset tests (VDS with 44k records)
3. **Transaction Safety** - No rollback testing
4. **Rate Limiting** - No throttling tests

### Medium Priority Gaps
1. **Memory Management** - No PGA limit testing
2. **Concurrent Users** - No multi-user scenarios
3. **Plant ID Changes** - Critical edge case untested
4. **Partial Recovery** - No partial failure recovery tests

### Low Priority Gaps
1. **Full Lifecycle Tests** - Complete plant lifecycle
2. **Cross-System Integration** - External system tests
3. **Data Evolution** - Field change tracking

---

## Test Execution Guide

### Standard Test Sequence
```sql
-- 1. Clean test data
EXEC PKG_TEST_ISOLATION.clean_all_test_data;

-- 2. Run test suites
EXEC PKG_SIMPLE_TESTS.run_critical_tests;
EXEC PKG_CONDUCTOR_TESTS.run_all_conductor_tests;
EXEC PKG_CONDUCTOR_EXTENDED_TESTS.run_all_extended_tests;
EXEC PKG_REFERENCE_COMPREHENSIVE_TESTS.run_all_reference_tests;

-- 3. FIX REFERENCES (MANDATORY!)
@Database/scripts/fix_reference_validity.sql

-- 4. Verify final state
@Database/scripts/final_system_test.sql
```

### Why Reference Fix is Required
The conductor tests process ALL selected plants including real ones (124, 34), triggering cascade operations that mark references as invalid. This is a test isolation issue, not a production bug.

---

## Test Results Analysis

### Typical Test Run Results
```
PKG_SIMPLE_TESTS:               5/5 PASS
PKG_CONDUCTOR_TESTS:            4/5 PASS (1 FAIL: empty selection)
PKG_CONDUCTOR_EXTENDED_TESTS:  8/8 PASS (Perfect Score!)
PKG_REFERENCE_COMPREHENSIVE:   11/13 PASS (2 WARN: empty tables)
```

### Common Issues
1. **References marked invalid** - Run fix_reference_validity.sql
2. **Empty selection test fails** - Known issue, low priority
3. **TEST_TIMESTAMP errors** - Column doesn't exist in TEST_RESULTS

---

## Monitoring Test Health

### Check Recent Test Results
```sql
-- Test summary by package
SELECT test_name, status, COUNT(*) as count
FROM TEST_RESULTS
WHERE test_date > SYSDATE - 1
GROUP BY test_name, status
ORDER BY test_name;

-- Failed tests details
SELECT test_name, error_message
FROM TEST_RESULTS
WHERE status = 'FAIL'
AND test_date > SYSDATE - 1;
```

### System Health After Tests
```sql
-- Should return 4,572 after fix
SELECT COUNT(*) as valid_references
FROM (
    SELECT 1 FROM PCS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT 1 FROM VDS_REFERENCES WHERE is_valid = 'Y'
    -- ... other reference tables
);
```

---

## Future Test Implementation Priority

### Priority 1 - Critical Business Functions (Q1 2025)
- API error handling (404, 500, 503)
- Transaction rollback safety
- Large dataset performance (VDS 44k records)

### Priority 2 - Robustness (Q2 2025)
- Concurrent user scenarios
- Memory limit testing
- Partial failure recovery

### Priority 3 - Edge Cases (As Needed)
- Plant ID change detection
- Full lifecycle testing
- Cross-system integration

---

## Test Maintenance Notes

### When Adding New Features
1. Add test scenarios to this matrix
2. Implement test in appropriate package
3. Update coverage percentage
4. Document any new test isolation issues

### When Tests Fail
1. Check if it's the known reference invalidation issue
2. Run fix_reference_validity.sql if needed
3. Document new failure patterns
4. Update this matrix with findings

---

*Remember: Current 35-40% coverage is adequate for development but needs improvement before production deployment.*