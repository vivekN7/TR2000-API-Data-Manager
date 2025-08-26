# Testing Procedures for TR2000 ETL System

## Purpose
Document all failure scenarios and test procedures for each ETL flow step to ensure robust error handling.

---

## 1. PLANTS ETL FLOW

### API Call Stage (pkg_api_client.fetch_plants_json)
| Failure Scenario | Current Behavior | Expected Behavior | Test Status |
|-----------------|------------------|-------------------|-------------|
| HTTP timeout | RAISE_APPLICATION_ERROR(-20002) | Log to ETL_ERROR_LOG, mark FAILED | ❓ Untested |
| Network down | ORA-24247 (ACL error) | Handle gracefully, log error | ✅ Fixed (ACL) |
| HTTPS cert invalid | ORA-29024 | Use wallet, fallback to HTTP | ✅ Fixed (wallet) |
| API returns 404 | Empty response | Log specific HTTP error | ❓ Untested |
| API returns 500 | Error response | Parse error message, log | ❓ Untested |
| API returns empty JSON | {} or [] | Mark as SUCCESS (no data) | ❓ Untested |
| API returns malformed JSON | Invalid JSON | Catch parse error, log | ❓ Untested |

### Deduplication Stage (pkg_raw_ingest)
| Failure Scenario | Current Behavior | Expected Behavior | Test Status |
|-----------------|------------------|-------------------|-------------|
| SHA256 calculation fails | RAISE_APPLICATION_ERROR(-20005) | Log error, continue | ❓ Untested |
| Duplicate hash found | Skip processing | Log as duplicate, SUCCESS | ✅ Working |

### Parsing Stage (pkg_parse_plants)
| Failure Scenario | Current Behavior | Expected Behavior | Test Status |
|-----------------|------------------|-------------------|-------------|
| Wrong JSON path | Silent failure (0 rows) | Log warning, check rowcount | ❓ Partial fix |
| Missing required fields | NULL values inserted | Validate required fields | ❓ Untested |
| Data type mismatch | Conversion error | Handle gracefully | ❓ Untested |

### Merge Stage (pkg_upsert_plants)
| Failure Scenario | Current Behavior | Expected Behavior | Test Status |
|-----------------|------------------|-------------------|-------------|
| Primary key violation | Should not happen (MERGE) | Log if happens | ✅ Working |
| Foreign key violation | Error raised | Log and handle | ❓ Untested |
| Check constraint violation | Error raised | Log specific constraint | ❓ Untested |

---

## 2. ISSUES ETL FLOW

### Critical Bugs Found (2025-08-24)
1. **Wrong JSON Path**: Was `$.get."plants/ID/issues"[*]`, should be `$.getIssueList[*]` - **FIXED**
2. **Silent Parsing Failures**: EXECUTE IMMEDIATE returns 0 rows without error - **PARTIALLY FIXED**
3. **Date Format Issues**: Expected 'DD-MON-YY', actual 'DD.MM.YYYY' - **FIXED with safe_date_parse**
4. **No Error Logging**: Failures not logged to ETL_ERROR_LOG - **PARTIALLY FIXED**

### API Call Stage (pkg_api_client.fetch_issues_json)
| Failure Scenario | Current Behavior | Expected Behavior | Test Status |
|-----------------|------------------|-------------------|-------------|
| Plant doesn't exist | Returns empty/error | Log plant not found | ❓ Untested |
| Plant has no issues | Returns empty array [] | SUCCESS (legitimate) | ✅ Handled |
| Invalid plant_id format | API error | Validate before calling | ❓ Untested |

### Parsing Stage (pkg_parse_issues) 
| Failure Scenario | Current Behavior | Expected Behavior | Test Status |
|-----------------|------------------|-------------------|-------------|
| Wrong JSON structure | 0 rows inserted | Check rowcount, log warning | ✅ FIXED |
| Date format variations | ORA-01843 error | safe_date_parse handles | ✅ FIXED |
| Timestamp format variations | Conversion error | safe_timestamp_parse handles | ✅ FIXED |
| NULL required fields | NULLs in staging | Validate before merge | ❓ Untested |

### Date/Time Parsing (safe_date_parse)
**Supported formats (in order):**
1. DD.MM.YYYY (European) ✅
2. DD/MM/YYYY (European slashes) ✅
3. DD-MM-YYYY (European dashes) ✅
4. MM/DD/YYYY (American) ✅
5. YYYY-MM-DD (ISO) ✅
6. DD.MM.YY (2-digit year) ✅
7. DD-MON-YYYY (Oracle) ✅

---

## 3. SELECTION FLOW

### Selection Stage (SELECTION_LOADER)
| Failure Scenario | Current Behavior | Expected Behavior | Test Status |
|-----------------|------------------|-------------------|-------------|
| Select non-existent plant | Allows selection | Validate against PLANTS | ❓ Untested |
| Duplicate selection | MERGE handles | Update timestamp only | ✅ Working |
| Deselect with dependencies | Orphaned issues | CASCADE deactivation | ❓ Untested |

---

## 4. GENERAL ERROR HANDLING

### ETL_RUN_LOG Issues
| Issue | Current Behavior | Expected Behavior | Status |
|-------|------------------|-------------------|---------|
| Parse fails, status SUCCESS | Misleading status | Check data actually loaded | ❓ Needs validation |
| No row count tracking | Can't detect partial loads | Track records at each stage | ❓ Not implemented |
| No performance metrics | Duration tracked | Add record counts | ❓ Enhancement |

### ETL_ERROR_LOG Issues
| Issue | Current Behavior | Expected Behavior | Status |
|-------|------------------|-------------------|---------|
| Silent failures not logged | No error record | All failures logged | ❓ Partial |
| No warning level | Only errors | Add WARNING type | ❓ Enhancement |
| No retry logic | Single attempt | Configurable retries | ❓ Not implemented |

---

## TEST SCRIPTS NEEDED

### Priority 1 (Critical)
- [ ] Test all date format variations
- [ ] Test parsing with missing required fields
- [ ] Test API error responses (404, 500, timeout)
- [ ] Test cascade deletion impacts

### Priority 2 (Important)
- [ ] Test large dataset performance (VDS with 44k records)
- [ ] Test transaction rollback scenarios
- [ ] Test concurrent user selections
- [ ] Test network interruption recovery

### Priority 3 (Nice to Have)
- [ ] Test data retention/purging
- [ ] Test audit trail completeness
- [ ] Test performance optimization

---

## NEXT SESSION CRITICAL INFO

### What Was Fixed Today
1. **Network ACL**: Fixed for APEX_240200
2. **Wallet Path**: `file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet`
3. **JSON Path for Issues**: Changed to `$.getIssueList[*]`
4. **Date Parsing**: Created safe_date_parse function
5. **Timestamp Parsing**: Created safe_timestamp_parse function

### What Still Needs Testing
1. Deploy Master_DDL.sql with all fixes
2. Verify issues parsing works end-to-end
3. Test error logging improvements
4. Document any remaining failures

### Files Changed
- `/workspace/TR2000/TR2K/Database/Master_DDL.sql` - All fixes applied
- `/workspace/TR2000/TR2K/Ops/Knowledge_Base/` - Contains all knowledge base documentation
- `/workspace/TR2000/TR2K/Ops/Testing/` - Testing documentation folder

---

*Last Updated: 2025-08-24*
*Context: 3% remaining - handoff to next session*