# ETL Test Matrix - Complete Testing Coverage
*Last Updated: 2025-08-24*

## Purpose
Map every potential failure point in the ETL pipeline to a specific test procedure, ensuring 100% coverage of critical scenarios.

## Test Result Tracking Structure

All test results are logged to **TEST_RESULTS_V2** table with the following information:

| Column | Purpose | Example |
|--------|---------|---------|
| **data_flow_step** | Which pipeline step | 'API_TO_RAW', 'RAW_TO_STG', 'STG_TO_CORE' |
| **test_category** | Type of test | 'CONNECTIVITY', 'PARSING', 'VALIDATION' |
| **status** | Test outcome | 'PASS', 'FAIL', 'ERROR', 'WARNING' |
| **failure_mode** | Classification of failure | 'TIMEOUT', 'PARSE_ERROR', 'FK_VIOLATION' |
| **error_code** | Specific error | 'ORA-01400', 'HTTP-404' |
| **failed_procedure** | Exact procedure that failed | 'pkg_api_client.fetch_plants_json' |
| **failed_at_line** | Line number of failure | 157 |
| **test_parameters** | JSON of test inputs | '{"timeout_ms": 1000, "endpoint": "plants"}' |
| **actual_result** | What happened | 'Connection timed out after 1000ms' |
| **expected_result** | What should happen | 'Receive JSON response within 1000ms' |

---

## 1. API → RAW_JSON (Data Ingestion Layer)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS_V2 |
|-----------------|----------------|-----------------|------------------------------------|
| **API Connection Failures** |
| HTTP timeout (>30s) | `test_api_timeout()` | timeout_ms=1000 | ETL_ERROR_LOG: error_type='TIMEOUT' |
| Network unreachable | `test_api_connection()` ✅ | endpoint='plants' | ETL_ERROR_LOG: error_type='NETWORK' |
| HTTPS cert invalid | `test_ssl_cert()` | verify_cert=true | ETL_ERROR_LOG: error_type='SSL_ERROR' |
| API returns 404 | `test_api_404()` | endpoint='invalid' | ETL_ERROR_LOG: error_code='404' |
| API returns 500 | `test_api_500()` | force_error=true | ETL_ERROR_LOG: error_code='500' |
| API returns 503 (maintenance) | `test_api_503()` | endpoint='plants' | ETL_ERROR_LOG: error_code='503' |
| **Response Validation** |
| Empty JSON response {} | `test_empty_response()` | response='{}' | ETL_RUN_LOG: record_count=0 |
| Null response | `test_null_response()` | response=NULL | ETL_ERROR_LOG: error_type='NULL_RESPONSE' |
| Malformed JSON | `test_malformed_json()` | response='{bad' | ETL_ERROR_LOG: error_type='JSON_PARSE' |
| Unexpected structure | `test_json_structure()` | missing_fields=true | ETL_ERROR_LOG: error_type='STRUCTURE' |
| **SHA256 Deduplication** |
| Duplicate hash found | `test_sha256_dedup()` | duplicate=true | RAW_JSON: skipped, no insert |
| Hash calculation fails | `test_sha256_error()` | corrupt_data=true | ETL_ERROR_LOG: error_type='HASH_ERROR' |
| **Rate Limiting** |
| API rate limit exceeded | `test_rate_limit()` | calls_per_min=100 | ETL_ERROR_LOG: error_code='429' |
| Retry after header | `test_retry_logic()` | retry_after=60 | ETL_RUN_LOG: retry_attempted=true |

---

## 2. RAW_JSON → STG_PLANTS (JSON Parsing Layer)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS_V2 |
|-----------------|----------------|-----------------|------------------------------------|
| **JSON Path Extraction** |
| Wrong JSON path | `test_json_parsing()` ✅ | path='$.plants[*]' | ETL_ERROR_LOG: rows_parsed=0 |
| Missing expected fields | `test_missing_fields()` | required=['plant_id'] | ETL_ERROR_LOG: validation_errors |
| Nested structure change | `test_nested_json()` | depth=3 | ETL_ERROR_LOG: parse_errors |
| **Data Type Issues** |
| String in number field | `test_type_mismatch()` | value='ABC' for NUMBER | ORA-01722 logged |
| Invalid date format | `test_json_parsing()` ✅ | date='13/25/2025' | Uses safe_date_parse |
| NULL in NOT NULL field | `test_null_required()` | plant_id=NULL | ETL_ERROR_LOG: constraint_violation |
| **Performance** |
| Large JSON (>10MB) | `test_large_json()` | size_mb=15 | ETL_RUN_LOG: parse_time_ms |
| Many records (>10000) | `test_bulk_parse()` | record_count=15000 | ETL_RUN_LOG: records_per_sec |

---

## 3. STG_PLANTS → PLANTS (MERGE Operation)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS_V2 |
|-----------------|----------------|-----------------|------------------------------------|
| **Primary Key Handling** |
| Duplicate plant_id | `test_duplicate_merge()` | plant_id='DUP' | MERGE updates existing |
| NULL primary key | `test_null_pk()` | plant_id=NULL | ORA-01400 logged |
| **Soft Delete Logic** |
| Plant removed from API | `test_soft_deletes()` ✅ | is_valid='N' | PLANTS.is_valid='N' |
| Plant resurrection | `test_plant_resurrection()` | restore=true | PLANTS.is_valid='Y', keeps created_date |
| Complete API replacement | `test_full_replacement()` | all_new=true | Old plants is_valid='N' |
| **Data Updates** |
| Field value changes | `test_field_updates()` | new_value='UPDATED' | last_modified_date=SYSDATE |
| Plant ID changes | `test_plant_id_change()` | old='P1', new='P1A' | Creates new record (critical issue!) |
| **Constraints** |
| Check constraint violation | `test_check_constraint()` | is_valid='X' | ORA-02290 logged |
| Length exceeded | `test_field_length()` | len>VARCHAR2(50) | ORA-12899 logged |

---

## 4. PLANTS → ISSUES (Cascade Operations)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS_V2 |
|-----------------|----------------|-----------------|------------------------------------|
| **Foreign Key Integrity** |
| Invalid plant_id | `test_invalid_fk()` | plant_id='INVALID' | ORA-02291 logged |
| Orphaned issues | `test_orphan_prevention()` | delete_plant=true | Issues.is_valid='N' |
| **Cascade Soft Delete** |
| Plant deleted cascade | `test_soft_deletes()` ✅ | plant.is_valid='N' | All issues.is_valid='N' |
| Selective issue delete | `test_issue_delete()` | issue_id=123 | Only that issue.is_valid='N' |
| **API Call Optimization** |
| Plant has no issues | `test_empty_issues()` | issue_count=0 | ETL_RUN_LOG: issues_loaded=0 |
| Issues API fails | `test_issues_api_fail()` | force_error=true | Plant remains, no issues |

---

## 5. SELECTION_LOADER (User Selection Management)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS_V2 |
|-----------------|----------------|-----------------|------------------------------------|
| **Selection Validation** |
| Select non-existent plant | `test_invalid_selection()` | plant_id='FAKE' | Should reject (not implemented) |
| Duplicate selection | `test_selection_cascade()` ✅ | duplicate=true | MERGE handles, updates timestamp |
| **Cascade Management** |
| Deselect plant with issues | `test_deselect_cascade()` | has_issues=true | Issues also deactivated |
| Reselect previously selected | `test_reselection()` | was_selected=true | Reactivates with new timestamp |
| **Concurrency** |
| Multiple users selecting | `test_concurrent_select()` | users=5 | Last update wins |
| Race condition | `test_race_condition()` | parallel=true | MERGE handles atomically |

---

## 6. ETL_ERROR_LOG (Error Tracking)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS_V2 |
|-----------------|----------------|-----------------|------------------------------------|
| **Error Capture** |
| Database errors | `test_error_capture()` ✅ | force_ora_error=true | Full stack trace logged |
| Application errors | `test_app_error()` | custom_error='TEST' | Error message logged |
| Silent failures | `test_silent_failure()` | no_exception=true | Should detect via row counts |
| **Error Context** |
| Missing context info | `test_error_context()` | context=NULL | Should capture automatically |
| Error during logging | `test_meta_error()` | break_logger=true | Autonomous transaction protects |

---

## 7. ETL_RUN_LOG (Execution Tracking)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS_V2 |
|-----------------|----------------|-----------------|------------------------------------|
| **Run Status Tracking** |
| Parse succeeds, no data | `test_false_success()` | rows=0 | Check record_count not just status |
| Partial load | `test_partial_load()` | fail_at=50% | Track records_processed vs total |
| Performance degradation | `test_performance()` | baseline_ms=1000 | Alert if 2x slower |
| **Metrics Collection** |
| Missing row counts | `test_row_counting()` | verify_counts=true | All stages should report counts |
| Missing timestamps | `test_timing()` | check_times=true | Start/end times required |

---

## 8. Special Scenarios

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS_V2 |
|-----------------|----------------|-----------------|------------------------------------|
| **Plant Lifecycle** |
| Plant deleted then restored | `test_plant_lifecycle()` | full_cycle=true | Maintains history |
| Plant ID changes (CRITICAL) | `test_plant_id_change()` | detect_rename=true | Cannot detect automatically! |
| Plant data updates | `test_plant_updates()` | change_fields=true | last_modified_date updated |
| **Transaction Management** |
| Rollback on error | `test_transaction_rollback()` | force_fail=true | No partial commits |
| Deadlock detection | `test_deadlock()` | create_lock=true | ORA-00060 handled |
| **Large Data Sets** |
| VDS 44k records | `test_vds_performance()` | records=44000 | Must complete < 60s |
| Memory overflow | `test_memory_limits()` | force_oom=true | Batch processing required |

---

## Test Implementation Status

### ✅ Currently Implemented (5 tests)
1. `test_api_connection()` - Basic connectivity only
2. `test_json_parsing()` - Date formats and JSON paths
3. `test_soft_deletes()` - Basic cascade logic
4. `test_selection_cascade()` - Selection management
5. `test_error_capture()` - Error logging

### 🔨 Priority 1: To Implement Next (Reference Tables - Task 7)
1. `test_plant_lifecycle()` - Full lifecycle scenarios
2. `test_invalid_fk()` - Foreign key validation
3. `test_transaction_rollback()` - Data integrity

### 📋 Priority 2: To Implement (PCS/VDS - Tasks 8-9)
1. `test_vds_performance()` - Large dataset handling
2. `test_bulk_parse()` - Batch processing
3. `test_memory_limits()` - Resource management

### 🔮 Priority 3: Future Enhancements
1. `test_concurrent_select()` - Multi-user scenarios
2. `test_rate_limit()` - API throttling
3. `test_plant_id_change()` - Critical edge case

---

## Test Execution Guidelines

### Before Each Task
```sql
-- Run existing tests to ensure baseline
EXEC PKG_SIMPLE_TESTS.run_critical_tests;
```

### After Implementation
```sql
-- Run new tests specific to the task
EXEC PKG_SIMPLE_TESTS.test_[new_feature];
```

### Before Deployment
```sql
-- Run complete test suite
EXEC PKG_SIMPLE_TESTS.run_all_tests;
-- Check results
SELECT * FROM V_TEST_SUMMARY;
```

---

## Adding New Tests

When implementing a new data flow step:

1. **Identify all failure points** in the flow
2. **Create test function** in PKG_SIMPLE_TESTS
3. **Use TEST_ prefix** for all test data
4. **Log results** to TEST_RESULTS table
5. **Clean up** test data after execution
6. **Document** in this matrix

Example template:
```sql
FUNCTION test_new_scenario RETURN VARCHAR2 IS
    v_result VARCHAR2(4000) := 'PASS';
BEGIN
    -- Setup test data with TEST_ prefix
    -- Execute test scenario
    -- Verify expected outcome
    -- Cleanup test data
    -- Log result
    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        -- Cleanup and return error
        RETURN 'FAIL: ' || SQLERRM;
END;
```

---

## Success Criteria

Each data flow step is considered fully tested when:
- ✅ All failure scenarios have test procedures
- ✅ Tests use realistic data and parameters
- ✅ Error reporting destinations are verified
- ✅ Test can be run repeatedly (idempotent)
- ✅ No test data remains after execution
- ✅ Results are logged to TEST_RESULTS

---

## Notes

- **Plant ID Change** is the most critical untested scenario - system cannot detect when API changes a plant's ID
- **Performance tests** become critical at VDS stage (44k records)
- **Concurrency tests** needed before production deployment
- **API error simulation** may require mock endpoints