# ETL Test Matrix - Complete Testing Coverage
*Last Updated: 2025-08-26 (Session 10)*
*Version: 2.3 - Added reference table test functions (Task 7)*

## Purpose
Map every potential failure point in the ETL pipeline to a specific test procedure, ensuring 100% coverage of critical scenarios.

## Test Result Tracking Structure

All test results are logged to **TEST_RESULTS** table with enhanced tracking:

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

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS |
|-----------------|----------------|-----------------|------------------------------------|
| **API Connection Failures** |
| **HTTP timeout** - API takes >30s to respond during peak hours. *Example: VDS endpoint with 44k records times out during business hours* | `test_api_timeout()` | timeout_ms=1000 | data_flow_step='API_TO_RAW', failure_mode='TIMEOUT', error_code='HTTP-TIMEOUT' |
| **Network unreachable** - Server down or firewall blocks connection. *Example: Firewall rule changed, blocking port 443* | `test_api_connection()` ✅ | endpoint='plants' | data_flow_step='API_TO_RAW', failure_mode='NETWORK_ERROR', error_code='ORA-24247' |
| **HTTPS cert expired** - SSL certificate not renewed. *Example: Annual cert expired over weekend, Monday ETL fails* | `test_ssl_cert()` | verify_cert=true | data_flow_step='API_TO_RAW', failure_mode='SSL_ERROR', error_code='ORA-29024' |
| **API returns 404** - Endpoint moved or deprecated. *Example: /api/v1/plants changed to /api/v2/facilities without notice* | `test_api_404()` | endpoint='invalid' | data_flow_step='API_TO_RAW', failure_mode='NOT_FOUND', error_code='HTTP-404' |
| **API returns 500** - Server crash or database down. *Example: API's database connection pool exhausted* | `test_api_500()` | force_error=true | data_flow_step='API_TO_RAW', failure_mode='SERVER_ERROR', error_code='HTTP-500' |
| **API returns 503** - Maintenance window. *Example: Scheduled Sunday 2AM maintenance* | `test_api_503()` | endpoint='plants' | data_flow_step='API_TO_RAW', failure_mode='UNAVAILABLE', error_code='HTTP-503' |
| **Response Validation** |
| **Empty JSON {}** - No data exists. *Example: New plant JSP3 has no issues yet, returns {}* | `test_empty_response()` | response='{}' | data_flow_step='API_TO_RAW', failure_mode='EMPTY_DATA', records_tested=0 |
| **Null response** - Connection drops mid-transfer. *Example: Load balancer timeout returns null* | `test_null_response()` | response=NULL | data_flow_step='API_TO_RAW', failure_mode='NULL_RESPONSE', error_code='CUSTOM-001' |
| **Malformed JSON** - HTML error page instead of JSON. *Example: API returns "503 Service Unavailable" HTML page* | `test_malformed_json()` | response='<html>Error' | data_flow_step='API_TO_RAW', failure_mode='PARSE_ERROR', error_code='ORA-40441' |
| **Schema changed** - Fields renamed. *Example: 'plant_id' renamed to 'facility_id' in new API version* | `test_json_structure()` | missing_fields=['plant_id'] | data_flow_step='API_TO_RAW', failure_mode='SCHEMA_MISMATCH', failed_procedure='JSON_TABLE' |
| **SHA256 Deduplication** |
| **Duplicate data** - Same JSON received twice. *Example: Retry sends duplicate, or API cache stale* | `test_sha256_dedup()` | duplicate=true | data_flow_step='API_TO_RAW', status='SKIP', actual_result='Duplicate SHA256' |
| **Hash fails** - Crypto error. *Example: CLOB >32K overflows buffer* | `test_sha256_error()` | size_mb=50 | data_flow_step='API_TO_RAW', failure_mode='HASH_ERROR', error_code='ORA-28232' |
| **Rate Limiting** |
| **Rate limit hit** - Too many requests. *Example: 5 parallel jobs hit 100/min limit* | `test_rate_limit()` | calls_per_min=101 | data_flow_step='API_TO_RAW', failure_mode='RATE_LIMIT', error_code='HTTP-429' |
| **Retry-after header** - API says wait. *Example: API returns 'Retry-After: 60' header* | `test_retry_logic()` | retry_after=60 | data_flow_step='API_TO_RAW', test_category='RETRY', actual_result='Waited 60s' |

---

## 2. RAW_JSON → STG_PLANTS (JSON Parsing Layer)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS |
|-----------------|----------------|-----------------|------------------------------------|
| **JSON Path Extraction** |
| **Wrong JSON path** - Path doesn't match structure. *Example: Using $.plants[*] but actual is $.data.plants[*]* | `test_json_path_mismatch()` ✅ | path='$.wrong[*]' | data_flow_step='RAW_TO_STG', failure_mode='PATH_ERROR', records_failed=0 |
| **Missing required field** - Expected field not in JSON. *Example: Old plants lack 'operator_id' field* | `test_field_case_sensitivity()` ✅ | required=['operator_id'] | data_flow_step='RAW_TO_STG', failure_mode='MISSING_FIELD', error_message='operator_id not found' |
| **Nested structure changed** - JSON depth increased. *Example: plant_details moved under metadata object* | `test_nested_json()` | depth=4 | data_flow_step='RAW_TO_STG', failure_mode='STRUCTURE_CHANGE', failed_procedure='JSON_TABLE' |
| **Data Type Issues** |
| **String in number field** - Text where number expected. *Example: issue_count='N/A' instead of 0* | `test_type_mismatch()` | issue_count='ABC' | data_flow_step='RAW_TO_STG', failure_mode='TYPE_MISMATCH', error_code='ORA-01722' |
| **Bad date format** - Unexpected date string. *Example: '2025-13-45' invalid date* | `test_json_parsing()` ✅ | date='13/45/2025' | data_flow_step='RAW_TO_STG', failure_mode='DATE_ERROR', failed_procedure='safe_date_parse' |
| **NULL in required** - Mandatory field is null. *Example: plant_id is null in JSON* | `test_null_required()` | plant_id=NULL | data_flow_step='RAW_TO_STG', failure_mode='NULL_CONSTRAINT', error_code='ORA-01400' |
| **Performance Issues** |
| **Large JSON** - Huge response. *Example: VDS endpoint returns 15MB JSON* | `test_large_json()` | size_mb=15 | data_flow_step='RAW_TO_STG', test_category='PERFORMANCE', execution_time_ms=5000 |
| **Many records** - Bulk data. *Example: 15000 pipe elements in one response* | `test_bulk_parse()` | record_count=15000 | data_flow_step='RAW_TO_STG', test_category='PERFORMANCE', records_tested=15000 |

---

## 3. STG_PLANTS → PLANTS (MERGE Operation)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS |
|-----------------|----------------|-----------------|------------------------------------|
| **Primary Key Handling** |
| **Duplicate plant_id** - Same ID twice. *Example: API sends GRANE twice with different data* | `test_duplicate_merge()` | plant_id='GRANE' | data_flow_step='STG_TO_CORE', test_category='MERGE', actual_result='Updated existing' |
| **NULL primary key** - Missing plant_id. *Example: Corrupt JSON has plant with no ID* | `test_null_primary_keys()` ✅ | plant_id=NULL | data_flow_step='STG_TO_CORE', failure_mode='NULL_PK', error_code='ORA-01400' |
| **Soft Delete Logic** |
| **Plant removed from API** - Plant disappears. *Example: TROLL plant decommissioned, not in API* | `test_soft_deletes()` ✅ | remove_plant='TROLL' | data_flow_step='STG_TO_CORE', test_category='SOFT_DELETE', actual_result='is_valid=N' |
| **Plant resurrection** - Deleted plant returns. *Example: TROLL reactivated after maintenance* | `test_plant_resurrection()` | restore='TROLL' | data_flow_step='STG_TO_CORE', test_category='RESURRECTION', expected_result='is_valid=Y, keep created_date' |
| **Complete replacement** - All plants change. *Example: API migrates to new system, all IDs change* | `test_full_replacement()` | all_new=true | data_flow_step='STG_TO_CORE', failure_mode='MASS_CHANGE', records_failed=130 |
| **Data Updates** |
| **Field changes** - Values updated. *Example: GRANE operator changes from 'Statoil' to 'Equinor'* | `test_field_updates()` | operator='Equinor' | data_flow_step='STG_TO_CORE', test_category='UPDATE', actual_result='last_modified_date updated' |
| **Plant ID renamed** - ID itself changes. *Example: 'GRANE' becomes 'GRANE_2025' ⚠️ CRITICAL* | `test_plant_id_change()` | old='GRANE', new='GRANE_2025' | data_flow_step='STG_TO_CORE', failure_mode='ID_CHANGE', error_message='Creates duplicate!' |
| **Constraints** |
| **Check constraint** - Invalid value. *Example: is_valid='X' instead of Y/N* | `test_check_constraint()` | is_valid='X' | data_flow_step='STG_TO_CORE', failure_mode='CHECK_VIOLATION', error_code='ORA-02290' |
| **Field too long** - Exceeds VARCHAR2. *Example: Description >50 chars* | `test_wrong_column_names()` ✅ | len=51 | data_flow_step='STG_TO_CORE', failure_mode='LENGTH_EXCEEDED', error_code='ORA-12899' |

---

## 4. PLANTS → ISSUES (Cascade Operations)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS |
|-----------------|----------------|-----------------|------------------------------------|
| **Foreign Key Integrity** |
| **Invalid plant_id** - Issue references non-existent plant. *Example: Issue for 'UNKNOWN_PLANT'* | `test_invalid_fk()` | plant_id='FAKE' | data_flow_step='ISSUE_LOAD', failure_mode='FK_VIOLATION', error_code='ORA-02291' |
| **Orphaned issues** - Plant deleted but issues remain. *Example: TROLL deleted, 50 issues orphaned* | `test_orphan_prevention()` | delete_plant='TROLL' | data_flow_step='ISSUE_LOAD', test_category='CASCADE', records_failed=50 |
| **Cascade Soft Delete** |
| **Plant soft delete** - Plant marked invalid. *Example: GRANE is_valid=N, all 12 issues must follow* | `test_soft_deletes()` ✅ | plant='GRANE' | data_flow_step='ISSUE_LOAD', test_category='CASCADE', actual_result='12 issues marked invalid' |
| **Single issue delete** - One issue removed. *Example: Issue REV3 obsolete* | `test_issue_delete()` | issue_id='REV3' | data_flow_step='ISSUE_LOAD', test_category='SOFT_DELETE', actual_result='1 issue marked invalid' |
| **API Call Optimization** |
| **No issues exist** - Plant has zero issues. *Example: New plant JSP3 has no issues yet* | `test_empty_issues()` | plant='JSP3' | data_flow_step='ISSUE_LOAD', status='PASS', records_tested=0 |
| **Issues API fails** - Can't load issues. *Example: Issues endpoint timeout for large plant* | `test_issues_api_fail()` | timeout=true | data_flow_step='ISSUE_LOAD', failure_mode='API_FAIL', error_code='HTTP-TIMEOUT' |

---

## 5. SELECTION_LOADER (User Selection Management)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS |
|-----------------|----------------|-----------------|------------------------------------|
| **Selection Validation** |
| **Select non-existent** - User selects invalid plant. *Example: Typo selects 'GARNE' instead of 'GRANE'* | `test_invalid_selection()` | plant_id='GARNE' | data_flow_step='SELECTION', failure_mode='INVALID_SELECTION', error_message='Plant not found' |
| **Duplicate selection** - Same plant selected twice. *Example: Double-click selects GRANE twice* | `test_selection_cascade()` ✅ | duplicate='GRANE' | data_flow_step='SELECTION', test_category='DUPLICATE', actual_result='MERGE updated timestamp' |
| **Cascade Management** |
| **Deselect with issues** - Remove plant that has loaded issues. *Example: Deselect JSP2 with 12 issues* | `test_deselect_cascade()` | plant='JSP2' | data_flow_step='SELECTION', test_category='CASCADE', expected_result='12 issues deactivated' |
| **Reselection** - Previously selected plant. *Example: Re-add GRANE after accidental removal* | `test_reselection()` | plant='GRANE' | data_flow_step='SELECTION', test_category='REACTIVATE', actual_result='is_active=Y with new timestamp' |
| **Concurrency** |
| **Multiple users** - Simultaneous selections. *Example: 2 users select different plants at same time* | `test_concurrent_select()` | users=2 | data_flow_step='SELECTION', test_category='CONCURRENCY', actual_result='Both selections succeed' |
| **Race condition** - Same plant, same time. *Example: 2 users select GRANE simultaneously* | `test_race_condition()` | parallel=true | data_flow_step='SELECTION', test_category='RACE', actual_result='MERGE handles atomically' |

---

## 6. ETL_ERROR_LOG (Error Tracking)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS |
|-----------------|----------------|-----------------|------------------------------------|
| **Error Capture** |
| **Database error** - ORA- errors. *Example: ORA-01400 cannot insert NULL* | `test_error_capture()` ✅ | force_ora=true | data_flow_step='ERROR_LOG', test_category='DB_ERROR', error_code='ORA-01400' |
| **Application error** - Custom errors. *Example: 'Plant validation failed'* | `test_app_error()` | msg='Validation failed' | data_flow_step='ERROR_LOG', test_category='APP_ERROR', error_message='Validation failed' |
| **Silent failure** - No error but wrong result. *Example: 0 rows loaded but status=SUCCESS* | `test_silent_failure()` | rows=0 | data_flow_step='ERROR_LOG', failure_mode='SILENT', actual_result='No error logged' |
| **Error Context** |
| **Missing context** - Error without details. *Example: 'Error occurred' with no specifics* | `test_error_context()` | context=NULL | data_flow_step='ERROR_LOG', failure_mode='NO_CONTEXT', error_message='Context missing' |
| **Logger fails** - Error while logging error. *Example: ETL_ERROR_LOG table full* | `test_meta_error()` | break_logger=true | data_flow_step='ERROR_LOG', failure_mode='META_ERROR', error_code='ORA-01653' |

---

## 7. ETL_RUN_LOG (Execution Tracking)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS |
|-----------------|----------------|-----------------|------------------------------------|
| **Run Status Issues** |
| **False success** - Says success but no data. *Example: Parse succeeds but loaded 0 rows* | `test_false_success()` | rows=0 | data_flow_step='RUN_LOG', failure_mode='FALSE_SUCCESS', actual_result='status=SUCCESS but rows=0' |
| **Partial load** - Some records fail. *Example: 100 plants but only 50 load* | `test_partial_load()` | success_rate=0.5 | data_flow_step='RUN_LOG', test_category='PARTIAL', records_failed=50 |
| **Performance issue** - Much slower than normal. *Example: Usually 1s, now takes 60s* | `test_performance()` | baseline_ms=1000 | data_flow_step='RUN_LOG', test_category='PERFORMANCE', execution_time_ms=60000 |
| **Missing Metrics** |
| **No row counts** - Count not tracked. *Example: Can't tell how many records processed* | `test_row_counting()` | verify=true | data_flow_step='RUN_LOG', failure_mode='NO_METRICS', error_message='record_count is NULL' |
| **No timestamps** - Times not logged. *Example: start_time NULL, can't measure duration* | `test_timing()` | check_times=true | data_flow_step='RUN_LOG', failure_mode='NO_TIMING', error_message='start_time is NULL' |

---

## 8. GUID and Correlation Scenarios (Session 10)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS |
|-----------------|----------------|-----------------|------------------------------------|
| **GUID Generation** |
| **GUID collision** - Duplicate GUID generated. *Example: SYS_GUID() collision (virtually impossible)* | `test_guid_uniqueness()` | iterations=10000 | data_flow_step='GUID_GEN', test_category='UNIQUENESS', expected_result='No duplicates' |
| **GUID conversion** - RAW to VARCHAR2 fails. *Example: Invalid hex in conversion* | `test_guid_conversion()` | test_format=true | data_flow_step='GUID_GEN', test_category='CONVERSION', actual_result='Valid UUID format' |
| **Correlation Tracking** |
| **Lost correlation** - API correlation ID not tracked. *Example: Network retry loses original correlation* | `test_correlation_tracking()` | retry_count=3 | data_flow_step='API_CORRELATION', test_category='TRACKING', actual_result='All retries same correlation' |
| **Cross-system trace** - Can't trace operation across systems. *Example: GUID not propagated to external system* | `test_cross_system()` | systems=['TR2000','SAP'] | data_flow_step='CROSS_SYSTEM', test_category='INTEGRATION', expected_result='GUID preserved' |

---

## 9. CASCADE Management Scenarios (Session 9)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS |
|-----------------|----------------|-----------------|------------------------------------|
| **Cascade Triggers** |
| **Plant cascade** - Plant deletion cascades to issues. *Example: Plant 34 with 8 issues* | `test_plant_cascade()` | plant_id='34' | data_flow_step='CASCADE', test_category='PLANT_CASCADE', actual_result='8 issues marked invalid' |
| **Selection cascade** - Selection removal cascades. *Example: Deselect JSP2 cascades to its data* | `test_selection_cascade()` ✅ | plant='JSP2' | data_flow_step='CASCADE', test_category='SELECTION', records_affected=12 |
| **Cascade logging** - CASCADE_LOG captures operations. *Example: Verify audit trail* | `test_cascade_audit()` | check_log=true | data_flow_step='CASCADE', test_category='AUDIT', actual_result='Log entry created' |
| **Autonomous Transactions** |
| **Main fails, cascade succeeds** - Cascade completes despite error. *Example: Main transaction rolls back* | `test_autonomous_cascade()` | force_error=true | data_flow_step='CASCADE', failure_mode='AUTONOMOUS', actual_result='Cascade committed' |
| **Deadlock in cascade** - Triggers cause deadlock. *Example: Circular cascade dependency* | `test_cascade_deadlock()` | circular=true | data_flow_step='CASCADE', failure_mode='DEADLOCK', error_code='ORA-00060' |

---

## 10. Special Scenarios (Cross-cutting Concerns)

| Failure Scenario | Test Procedure | Test Parameters | Result Tracking in TEST_RESULTS |
|-----------------|----------------|-----------------|------------------------------------|
| **Plant Lifecycle** |
| **Full lifecycle** - Create, delete, restore. *Example: TROLL added Monday, removed Tuesday, restored Friday* | `test_plant_lifecycle()` | plant='TROLL' | data_flow_step='LIFECYCLE', test_category='FULL_CYCLE', actual_result='History preserved' |
| **ID change ⚠️** - Plant renamed. *Example: 'GRANE' → 'GRANE_2025' breaks everything!* | `test_plant_id_change()` | old='GRANE', new='GRANE_2025' | data_flow_step='LIFECYCLE', failure_mode='ID_CHANGE', error_message='CRITICAL: Cannot detect!' |
| **Data evolution** - Fields change over time. *Example: Operator name changes quarterly* | `test_plant_updates()` | quarterly=true | data_flow_step='LIFECYCLE', test_category='EVOLUTION', actual_result='Audit trail maintained' |
| **Transaction Safety** |
| **Rollback on error** - All or nothing. *Example: Error at row 500 of 1000, all rolled back* | `test_transaction_rollback()` | fail_at=500 | data_flow_step='TRANSACTION', test_category='ROLLBACK', actual_result='0 rows committed' |
| **Deadlock** - Competing locks. *Example: Two sessions updating same plant* | `test_deadlock()` | sessions=2 | data_flow_step='TRANSACTION', failure_mode='DEADLOCK', error_code='ORA-00060' |
| **Large Datasets** |
| **VDS performance** - 44k records. *Example: VDS takes 5 minutes to load* | `test_vds_performance()` | records=44000 | data_flow_step='PERFORMANCE', test_category='LARGE_DATA', execution_time_ms=300000 |
| **Memory limits** - Out of memory. *Example: PGA exhausted processing huge JSON* | `test_memory_limits()` | size_gb=2 | data_flow_step='PERFORMANCE', failure_mode='OOM', error_code='ORA-04036' |

---

## Test Implementation Status

### ✅ Currently Implemented (8 tests in PKG_SIMPLE_TESTS)

#### PKG_SIMPLE_TESTS (8 tests)
1. `test_api_connection()` - Basic connectivity only
2. `test_json_parsing()` - Date formats and JSON paths  
3. `test_soft_deletes()` - Basic cascade logic with CASCADE_MANAGER
4. `test_selection_cascade()` - Selection management with triggers
5. `test_error_capture()` - Error logging
6. `test_reference_parsing()` - ✅ Parses reference JSON into staging tables (Task 7)
7. `test_reference_cascade()` - ✅ Tests cascade deletion from issues to references (Task 7)
8. `test_invalid_fk()` - ✅ Validates foreign key constraints on references (Task 7)

#### Note on Additional Tests
The PKG_ADDITIONAL_TESTS mentioned in Session 8 documentation was planned but not implemented.
The test scenarios remain valid and should be implemented in future sessions.

### 🔨 Priority 1: To Implement Next (Task 7 - Reference Tables)
```sql
-- Add these for Task 7 when implementing reference tables
FUNCTION test_invalid_fk RETURN VARCHAR2;      -- Test FK violations for references
FUNCTION test_reference_cascade RETURN VARCHAR2; -- Test reference deletion cascades
FUNCTION test_reference_parsing RETURN VARCHAR2; -- Test reference JSON structure
FUNCTION test_reference_scd2 RETURN VARCHAR2;   -- Test SCD2 versioning for references
```

### 📋 Priority 2: To Implement (Tasks 8-9 - PCS/VDS)
```sql
-- Add these for large data handling
FUNCTION test_vds_performance RETURN VARCHAR2;  -- 44k record test
FUNCTION test_bulk_operations RETURN VARCHAR2;  -- Batch processing
FUNCTION test_memory_limits RETURN VARCHAR2;    -- Resource management
```

### 🔮 Priority 3: Future Production Readiness
```sql
-- Add before production deployment
FUNCTION test_concurrent_users RETURN VARCHAR2; -- Multi-user scenarios
FUNCTION test_plant_id_change RETURN VARCHAR2;  -- Critical edge case
FUNCTION test_full_lifecycle RETURN VARCHAR2;   -- Complete scenarios
```

---

## Enhanced Logging Example

When a test fails, TEST_RESULTS captures complete context:

```sql
-- Example failure record:
data_flow_step: 'API_TO_RAW'
test_category: 'CONNECTIVITY'  
status: 'FAIL'
failure_mode: 'TIMEOUT'
error_code: 'HTTP-TIMEOUT'
error_message: 'Connection timed out after 30000ms waiting for VDS endpoint'
failed_procedure: 'pkg_api_client.fetch_vds_json'
failed_at_line: 234
test_parameters: '{"endpoint": "vds", "timeout_ms": 30000, "plant_id": "JSP2"}'
actual_result: 'No response received within 30 seconds'
expected_result: 'JSON response with 44000 VDS records'
records_tested: 0
records_failed: 0
execution_time_ms: 30000
```

---

## Using the Test Matrix

### Before Starting Any Task:
1. Review relevant section in this matrix
2. Implement missing test procedures
3. Run tests to establish baseline
4. Document any new failure scenarios discovered

### After Implementation:
1. Run all affected tests
2. Update matrix with new scenarios
3. Check TEST_RESULTS for patterns
4. Query analysis views:
```sql
-- Check by flow step
SELECT * FROM V_TEST_BY_FLOW_STEP;

-- Analyze failures
SELECT * FROM V_TEST_FAILURE_ANALYSIS;

-- Coverage report
SELECT * FROM V_TEST_COVERAGE;
```

---

*Remember: Every untested scenario is a potential production incident waiting to happen!*