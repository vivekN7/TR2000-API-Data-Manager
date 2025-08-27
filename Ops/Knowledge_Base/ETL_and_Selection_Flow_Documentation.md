# TR2000 ETL and Selection Flow Documentation

## Overview
This document provides comprehensive documentation of the ETL flow from TR2000 API to Oracle database, including the two-table selection management system and complete data processing pipelines.

## Table of Contents
1. [Current System State](#current-system-state)
2. [Architecture Overview](#architecture-overview)
3. [Selection Management (Two-Table Design)](#selection-management-two-table-design)
4. [Complete ETL Pipeline](#complete-etl-pipeline)
5. [Package Structure and Responsibilities](#package-structure-and-responsibilities)
6. [Reference Tables Implementation](#reference-tables-implementation)
7. [API Proxy Architecture](#api-proxy-architecture)
8. [Testing and Monitoring](#testing-and-monitoring)
9. [Known Issues and Workarounds](#known-issues-and-workarounds)

---

## Current System State

### As of 2025-08-27 (Tasks 1-7 Complete)
- **130** plants loaded from API
- **20** issues loaded (12 for plant 124, 8 for plant 34)
- **4,572** valid references across 8 types
- **2** selected plants (124/JSP2, 34/GRANE)
- **3** selected issues (124/3.3, 34/3.0, 34/4.2)
- **0** invalid database objects
- **~35-40%** test coverage

### Key Components Status
| Component | Status | Notes |
|-----------|--------|-------|
| Plants ETL | ✅ Working | Full API → DB pipeline |
| Issues ETL | ✅ Working | Selection-based loading |
| References ETL | ✅ Working | All 9 types implemented |
| Cascade Operations | ✅ Working | Plant→Issues→References |
| API Throttling | ✅ Working | 5-minute cache |
| Test Isolation | ⚠️ Partial | Tests affect real data |
| APEX UI | ✅ Working | Basic selection UI |

---

## Architecture Overview

### Three-Layer Data Architecture
```
RAW_JSON (Bronze) → STG_* (Silver) → Production (Gold)
```
- **Bronze**: Raw, immutable API responses with SHA256 deduplication
- **Silver**: Parsed but unvalidated staging (all VARCHAR2)
- **Gold**: Clean, validated production data with proper types

### Two-Table Selection Design (Current)
```sql
SELECTED_PLANTS     -- Active plant selections
SELECTED_ISSUES     -- Active issue selections (with plant_id + issue_revision)
```

### Key Design Patterns
1. **SHA256 Deduplication** - Prevents reprocessing identical API responses
2. **Soft Delete Pattern** - Uses `is_valid = 'Y'/'N'` instead of DELETE
3. **Comprehensive Logging** - ETL_RUN_LOG, ETL_ERROR_LOG, CASCADE_LOG
4. **Selection-Based Loading** - Only fetch data for selected items
5. **5-Minute Throttling** - Prevents redundant API calls

---

## Selection Management (Two-Table Design)

### Current Implementation
```sql
-- SELECTED_PLANTS table
CREATE TABLE SELECTED_PLANTS (
    plant_id VARCHAR2(50) PRIMARY KEY,
    is_active CHAR(1) DEFAULT 'Y',
    selected_date TIMESTAMP DEFAULT SYSTIMESTAMP,
    selected_by VARCHAR2(100) DEFAULT USER,
    etl_status VARCHAR2(50),
    last_etl_run TIMESTAMP
);

-- SELECTED_ISSUES table  
CREATE TABLE SELECTED_ISSUES (
    plant_id VARCHAR2(50),
    issue_revision VARCHAR2(50),
    is_active CHAR(1) DEFAULT 'Y',
    selected_date TIMESTAMP DEFAULT SYSTIMESTAMP,
    etl_status VARCHAR2(50),
    CONSTRAINT pk_selected_issues PRIMARY KEY (plant_id, issue_revision)
);
```

### Selection Flow
```
USER SELECTS PLANTS
    ↓
SELECTED_PLANTS (plant_id='124', is_active='Y')
    ↓
USER SELECTS ISSUES
    ↓
SELECTED_ISSUES (plant_id='124', issue_revision='3.3', is_active='Y')
    ↓
ETL PROCESSES SELECTIONS
    ↓
References loaded for selected issues only
```

### Cascade Triggers
1. **TRG_CASCADE_PLANT_TO_ISSUES** - When plant deactivated, deactivates its issues
2. **TRG_CASCADE_ISSUE_TO_REFERENCES** - When issue marked invalid, invalidates references

---

## Complete ETL Pipeline

### Master Refresh Procedure
```sql
-- Main entry point for full refresh
PROCEDURE refresh_all_data_from_api IS
BEGIN
    -- Step 1: Clean test data
    PKG_TEST_ISOLATION.clean_all_test_data;
    
    -- Step 2: Refresh plants (checks 5-min throttle)
    pkg_api_client.refresh_plants_from_api;
    
    -- Step 3: Process selected issues and references
    FOR rec IN (SELECT plant_id, issue_revision FROM SELECTED_ISSUES WHERE is_active = 'Y') LOOP
        pkg_api_client_references.refresh_all_issue_references(
            p_plant_id => rec.plant_id,
            p_issue_rev => rec.issue_revision
        );
    END LOOP;
    
    -- Step 4: Validate data integrity
    PKG_TEST_ISOLATION.validate_no_test_contamination;
END;
```

### Data Flow for Each Endpoint
```
API Call → RAW_JSON → STG_* → Core Table
         ↓           ↓        ↓
    SHA256 Hash  JSON Parse  MERGE with soft delete
```

---

## Package Structure and Responsibilities

### Core ETL Packages
| Package | Purpose | Key Procedures |
|---------|---------|----------------|
| **pkg_api_client** | Plant/Issue API calls | refresh_plants_from_api, refresh_issues_for_plant |
| **pkg_api_client_references** | Reference API calls | refresh_all_issue_references |
| **pkg_raw_ingest** | SHA256 deduplication | insert_raw_json, is_duplicate_hash |
| **pkg_parse_plants** | JSON→STG_PLANTS | parse_plants_json |
| **pkg_parse_issues** | JSON→STG_ISSUES | parse_issues_json |
| **pkg_parse_references** | JSON→STG_*_REFERENCES | parse_[type]_references (9 types) |
| **pkg_upsert_plants** | STG→PLANTS merge | upsert_plants |
| **pkg_upsert_issues** | STG→ISSUES merge | upsert_issues |
| **pkg_upsert_references** | STG→*_REFERENCES merge | upsert_[type]_references (9 types) |
| **pkg_etl_operations** | Orchestration | run_full_etl, run_references_etl_for_all_selected |
| **pkg_selection_mgmt** | Selection management | add_plant_selection, remove_plant_selection |

### Testing Packages
| Package | Tests | Coverage |
|---------|-------|----------|
| **PKG_SIMPLE_TESTS** | 5 implemented (of 21 declared) | Core functionality |
| **PKG_CONDUCTOR_TESTS** | 5 tests | ETL orchestration |
| **PKG_CONDUCTOR_EXTENDED_TESTS** | 8 tests | Advanced scenarios |
| **PKG_REFERENCE_COMPREHENSIVE_TESTS** | 3 tests | Reference validation |
| **PKG_TEST_ISOLATION** | Test data cleanup | Handles TEST_%, COND_TEST_%, EXT_TEST_% |

---

## Reference Tables Implementation

### All 9 Reference Types (Task 7 Complete)
```sql
-- Core reference tables with soft delete pattern
PCS_REFERENCES          -- 206 records
VDS_REFERENCES          -- 2,047 records (largest)
MDS_REFERENCES          -- 752 records
PIPE_ELEMENT_REFERENCES -- 1,309 records
VSK_REFERENCES          -- 230 records
EDS_REFERENCES          -- 23 records
SC_REFERENCES           -- 2 records
VSM_REFERENCES          -- 3 records
ESK_REFERENCES          -- 0 records (no data from API)
```

### Reference Loading Process
1. Selected issue triggers reference fetch
2. API returns JSON with all 9 reference types
3. PKG_PARSE_REFERENCES parses each type to staging
4. PKG_UPSERT_REFERENCES merges to core with FK validation
5. Cascade trigger invalidates references if issue becomes invalid

---

## API Proxy Architecture

### TR2000_UTIL Package (DBA-Owned)
```sql
-- Centralized API access through DBA proxy
TR2000_UTIL.make_api_request(
    p_endpoint VARCHAR2,
    p_method VARCHAR2,
    p_body CLOB
) RETURN CLOB;
```

### Benefits
- Single point for network access control
- No wallet management in application schema
- Simplified security model
- Future: Can add logging, throttling, retry logic

### Current Implementation
- All API calls route through TR2000_UTIL
- 5-minute cache prevents redundant calls
- Correlation IDs track requests

---

## Testing and Monitoring

### Test Execution Sequence
```bash
# Run tests
@Database/scripts/run_comprehensive_tests.sql

# Fix references (MANDATORY after tests!)
@Database/scripts/fix_reference_validity.sql

# Verify system state
@Database/scripts/final_system_test.sql
```

### Key Monitoring Views
```sql
-- System health dashboard
SELECT * FROM V_SYSTEM_HEALTH_DASHBOARD;

-- ETL success rates
SELECT * FROM V_ETL_SUCCESS_RATE;

-- Reference summary by issue
SELECT * FROM V_REFERENCE_SUMMARY;

-- Recent ETL activity
SELECT * FROM V_RECENT_ETL_ACTIVITY;
```

### Current Test Coverage
- **27** tests implemented across 4 packages
- **24** passing, 1 failing (empty selection), 2 warnings
- Known issue: Tests invalidate real reference data

---

## Known Issues and Workarounds

### Issue 1: Test Suite Invalidates References
**Problem**: Conductor tests call `run_full_etl()` which processes real plants (124, 34)
**Workaround**: Always run `@Database/scripts/fix_reference_validity.sql` after tests
**Future Fix**: Improve test isolation to use only TEST_* data

### Issue 2: Empty Selection Test Failure
**Problem**: Test expects NO_DATA but gets PARTIAL status
**Impact**: One test shows as failed
**Status**: Low priority, doesn't affect production

### Issue 3: CONTROL_SETTINGS Confusion
**Active Settings**:
- API_BASE_URL: Used for all API calls

**Placeholder Settings** (NOT implemented):
- API_TIMEOUT_SECONDS
- MAX_PLANTS_PER_RUN  
- RAW_JSON_RETENTION_DAYS
- ETL_LOG_RETENTION_DAYS
- ENABLE_PARALLEL_PROCESSING
- BATCH_SIZE

---

## Performance Metrics

### Current Performance
- Plants ETL: 0.03 seconds average
- Issues ETL: <1 second average
- Reference ETL: 5-10 seconds per issue
- Total refresh (3 issues): ~30 seconds

### API Call Reduction
- Selection-based: 70% reduction in API calls
- 5-minute throttling: Prevents redundant calls
- SHA256 deduplication: Skips unchanged data

---

## Next Steps (Task 8: PCS Details)

### Ready for Implementation
1. Create PCS detail tables (Line, Gasket, Stud, Nut, etc.)
2. Extend pkg_parse_references for PCS details
3. Add FK constraints to PCS_REFERENCES
4. Implement cascade from PCS references to details

### System Readiness
- ✅ All prerequisites complete
- ✅ Reference tables working
- ✅ Cascade logic tested
- ✅ 0 invalid objects
- ✅ Production data loaded

---

*Last Updated: 2025-08-27*
*Version: 3.0 - Complete rewrite for current state*