# TR2000 ETL and Selection Flow Documentation

## Overview
This document provides comprehensive documentation of the ETL flow from TR2000 API to Oracle database, including user selection management and data processing pipelines.

## Table of Contents
1. [Quick Reference - Key Questions](#quick-reference---key-questions)
2. [Architecture Overview](#architecture-overview)
3. [Selection Management Flow](#selection-management-flow)
4. [Complete ETL Pipeline](#complete-etl-pipeline)
5. [Package Structure and Responsibilities](#package-structure-and-responsibilities)
6. [Data Flow Tables](#data-flow-tables)
7. [Error Handling](#error-handling)
8. [Testing and Monitoring](#testing-and-monitoring)

---

## Quick Reference - Key Questions

### Q1: Who calls pkg_api_client.refresh_plants_from_api and how does it know what to do?
**Answer:** YOU (the user) manually call this procedure from SQL*Plus or an APEX button. It's the master orchestrator that controls the entire ETL flow. It knows to read API_BASE_URL because it's hardcoded in the fetch_plants_json function to SELECT from CONTROL_SETTINGS.

### Q2: Which CONTROL_SETTINGS are actually used?
**Answer:** Only **API_BASE_URL** is used! The others (MAX_PLANTS_PER_RUN, RETENTION_DAYS, etc.) are placeholders for future functionality but NOT implemented yet.

### Q3: Who controls the API call and deduplication?
**Answer:** pkg_api_client.refresh_plants_from_api orchestrates everything sequentially. It calls fetch_plants_json → calculates hash → checks for duplicates → inserts to RAW_JSON if new.

### Q4: Who parses RAW_JSON to STG_PLANTS?
**Answer:** pkg_api_client.refresh_plants_from_api directly calls pkg_parse_plants.parse_plants_json(). Errors are caught and logged to ETL_ERROR_LOG.

### Q5: Who parses STG_PLANTS to PLANTS?
**Answer:** pkg_api_client.refresh_plants_from_api directly calls pkg_upsert_plants.upsert_plants(). Errors are caught and logged to ETL_ERROR_LOG.

---

## Architecture Overview

### Understanding Packages vs Procedures

A **package** is a container that groups related procedures and functions together. Think of it like a class in object-oriented programming.

```sql
-- SPECIFICATION (interface/header)
CREATE PACKAGE pkg_api_client AS
    FUNCTION fetch_plants_json RETURN CLOB;  -- Declaration only
    PROCEDURE refresh_plants_from_api(...);   -- Declaration only
END;

-- BODY (implementation)
CREATE PACKAGE BODY pkg_api_client AS
    FUNCTION fetch_plants_json RETURN CLOB IS
        -- Actual code here
    END;
    
    PROCEDURE refresh_plants_from_api(...) IS
        -- Actual code here
    END;
END;
```

### Three-Layer Data Architecture
```
RAW_JSON (Bronze) → STG_* (Silver) → Production (Gold)
```
- **Bronze**: Raw, immutable API responses
- **Silver**: Parsed but unvalidated staging
- **Gold**: Clean, validated production data

### Key Design Patterns
1. **SHA256 Deduplication** - Prevents reprocessing identical API responses
2. **Soft Delete Pattern** - Uses `is_valid = 'Y'/'N'` instead of DELETE
3. **Comprehensive Logging** - Every ETL run tracked in ETL_RUN_LOG
4. **Selection-Based Loading** - Only fetch data for user-selected items

---

## Selection Management Flow

### Plant and Issue Selection Process

```
USER ACTION: Select Plants in UI
           ↓
┌─────────────────────────────────┐
│   1. UPDATE SELECTION_LOADER    │
├─────────────────────────────────┤
│ MERGE INTO SELECTION_LOADER     │
│ - plant_id = '124' (JSP2)       │
│ - plant_id = '34' (GRANE)       │
│ - is_active = 'Y'               │
│ - selected_by = USER            │
└─────────────────────────────────┘
           ↓
USER ACTION: Click "Fetch Issues"
           ↓
┌─────────────────────────────────┐
│  2. LOOP THROUGH SELECTIONS     │
├─────────────────────────────────┤
│ FOR each plant IN              │
│   SELECTION_LOADER              │
│   WHERE is_active = 'Y'        │
└─────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────┐
│  3. CALL pkg_api_client.refresh_issues_from_api │
├─────────────────────────────────────────────┤
│ For each selected plant:                    │
│   a. INSERT INTO ETL_RUN_LOG               │
│   b. Call fetch_issues_json(plant_id)      │
│   c. API: GET /plants/{id}/issues          │
│   d. Calculate SHA256 hash                 │
│   e. Check for duplicate                   │
│   f. INSERT INTO RAW_JSON                  │
│   g. Parse JSON → STG_ISSUES               │
│   h. MERGE STG_ISSUES → ISSUES             │
│   i. UPDATE ETL_RUN_LOG (SUCCESS)          │
│   j. UPDATE SELECTION_LOADER (last_etl_run)│
└─────────────────────────────────────────────┘
```

### Selection Management Architecture

#### 1. Initial Data Population
- **One-time load**: Fetch ALL plants from API to populate PLANTS table
- This provides the master list for user selection
- No issues are loaded initially (API optimization)

#### 2. User Selection Workflow
1. **Plant Selection**:
   - User selects plants from PLANTS table via APEX UI
   - Selected plants saved to SELECTION_LOADER (is_active='Y')
   - Triggers automatic fetch of issues for ONLY selected plants
   
2. **Issue Selection**:
   - Issues dropdown populates with data for selected plants only
   - User selects specific issue revisions
   - Selected issues saved to SELECTION_LOADER with plant_id + issue_revision

#### 3. Change Management & Cascade Logic
- **Plant change**: 
  - Deactivate old plant → cascade deactivate its issues → cascade deactivate all downstream
  - Activate new plant → fetch its issues → user selects issues → fetch downstream
- **Issue change**:
  - Deactivate old issue → cascade deactivate its references and downstream data
  - Activate new issue → fetch its references → fetch downstream details
- **Soft delete**: All tables use is_valid='N' instead of DELETE

#### 4. API Call Optimization Strategy
- **Selection scoping**: Only fetch data for selected plants/issues (70% reduction)
- **SHA256 deduplication**: Skip unchanged API responses
- **Cascade fetching**: Only fetch downstream data that's actually referenced
- **Example**: 3 plants × 2 issues = 6 API calls for issues + their references
  (vs 100+ plants × all issues = 1000s of calls without selection)

---

## Complete ETL Pipeline

### Complete Data Flow for Plants Endpoint

```
┌─────────────────────────────────────────────────────────────────────┐
│                        COMPLETE ETL FLOW                            │
└─────────────────────────────────────────────────────────────────────┘

1. API CALL INITIATED
   └─> pkg_api_client.refresh_plants_from_api()

2. ETL RUN LOGGING
   └─> INSERT INTO ETL_RUN_LOG
       - run_id: auto-generated
       - run_type: 'PLANTS_API_REFRESH'
       - endpoint_key: 'plants'
       - start_time: SYSTIMESTAMP
       - status: 'RUNNING'

3. FETCH API CONFIGURATION
   └─> SELECT FROM CONTROL_SETTINGS
       - Retrieves 'API_BASE_URL'
       - Constructs URL: base_url + 'plants'

4. MAKE HTTPS API CALL
   └─> apex_web_service.make_rest_request()
       - URL: https://equinor.pipespec-api.presight.com/plants
       - Method: GET
       - Wallet: file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet
       - Returns: JSON response

5. CALCULATE SHA256 HASH
   └─> pkg_api_client.calculate_sha256()
       - Creates unique fingerprint for deduplication

6. CHECK FOR DUPLICATE
   └─> pkg_raw_ingest.is_duplicate_hash()
       - If duplicate: Skip processing
       - If new: Continue processing

7. STORE RAW RESPONSE
   └─> pkg_raw_ingest.insert_raw_json()
       └─> INSERT INTO RAW_JSON

8. PARSE JSON TO STAGING
   └─> pkg_parse_plants.parse_plants_json(raw_json_id)
       - Clear staging: DELETE FROM STG_PLANTS
       - Parse using JSON_TABLE
       - INSERT INTO STG_PLANTS

9. MERGE TO CORE TABLE
   └─> pkg_upsert_plants.upsert_plants()
       - Soft delete existing: UPDATE PLANTS SET is_valid = 'N'
       - MERGE INTO PLANTS
       - Sets is_valid = 'Y' for current data

10. UPDATE ETL RUN LOG
    └─> UPDATE ETL_RUN_LOG
        - status: 'SUCCESS'
        - end_time: SYSTIMESTAMP

11. COMMIT TRANSACTION
    └─> All changes committed to database
```

### Master Controller Flow

```
pkg_api_client.refresh_plants_from_api (MASTER CONTROLLER)
    │
    ├─1→ INSERT INTO ETL_RUN_LOG (starts logging)
    │
    ├─2→ SELECT FROM CONTROL_SETTINGS WHERE setting_key = 'API_BASE_URL'
    │
    ├─3→ CALLS fetch_plants_json() (same package, private function)
    │    └→ apex_web_service.make_rest_request() 
    │
    ├─4→ CALLS calculate_sha256() (same package, private function)
    │
    ├─5→ CALLS pkg_raw_ingest.is_duplicate_hash() (external package)
    │
    ├─6→ IF not duplicate:
    │    ├→ CALLS pkg_raw_ingest.insert_raw_json() (external package)
    │    ├→ CALLS pkg_parse_plants.parse_plants_json() (external package)
    │    └→ CALLS pkg_upsert_plants.upsert_plants() (external package)
    │
    ├─7→ UPDATE ETL_RUN_LOG (marks success)
    │
    └─8→ EXCEPTION handlers catch any errors
         └→ INSERT INTO ETL_ERROR_LOG
         └→ UPDATE ETL_RUN_LOG (marks failure)
```

---

## Package Structure and Responsibilities

### Active Packages (Used in Plants Flow)
1. **pkg_api_client** - Master orchestrator, API calls, main ETL flow control
2. **pkg_raw_ingest** - RAW_JSON operations, SHA256 deduplication
3. **pkg_parse_plants** - JSON parsing to staging (STG_PLANTS)
4. **pkg_upsert_plants** - Staging to production merge (PLANTS)

### Active Packages (For Issues - Similar Pattern)
5. **pkg_parse_issues** - JSON parsing for issues endpoint
6. **pkg_upsert_issues** - Issues staging to production
7. **pkg_selection_mgmt** - Manages user selections and cascade operations

### Future/Alternative Package
8. **pkg_etl_operations** - Dynamic ETL using CONTROL_ENDPOINTS table (not currently used)

### Why This Architecture?
- **Single Responsibility**: One place to understand the flow
- **Transaction Control**: Can COMMIT/ROLLBACK entire operation
- **Error Handling**: Centralized exception management
- **Logging**: Consistent ETL_RUN_LOG updates
- **Modularity**: Can reprocess without re-fetching
- **Testing**: Can test parsing separately from merging
- **Reusability**: Same pattern for plants, issues, and future endpoints

---

## Data Flow Tables

### Input/Configuration Tables
1. **CONTROL_SETTINGS**
   - Provides: API_BASE_URL
   - Future: Timeout, batch size, retention settings

2. **CONTROL_ENDPOINTS**
   - Defines available endpoints
   - Used for dynamic ETL processing

3. **SELECTION_LOADER**
   - Tracks user-selected plants and issues
   - Controls what data gets fetched from API

### Logging Tables
4. **ETL_RUN_LOG**
   - Records: Start/end time, status, duration
   - One record per ETL execution

5. **ETL_ERROR_LOG**
   - Records: Error details if process fails
   - Full error stack for debugging

### Data Flow Tables
6. **RAW_JSON**
   - Stores: Complete API response as-is
   - Purpose: Audit trail, deduplication, reprocessing

7. **STG_PLANTS** / **STG_ISSUES**
   - Stores: Parsed JSON data in tabular format
   - Purpose: Staging area for validation/transformation
   - Format: All VARCHAR2 columns

8. **PLANTS** / **ISSUES**
   - Stores: Final normalized data
   - Purpose: Production tables for application use
   - Format: Proper data types, constraints

### Reference Tables (Future Implementation)
9. **PCS_REFERENCES, VDS_REFERENCES, etc.**
   - Store references from issues to other entities
   - Enable cascade fetching of related data

---

## Error Handling

### Error Handling at Each Level

1. **API Call Errors** (in fetch_*_json):
   - Raises: `RAISE_APPLICATION_ERROR(-20002, 'Error fetching: ' || SQLERRM)`
   - Caught by: refresh_*_from_api's EXCEPTION block
   - Logged to: ETL_ERROR_LOG with error_type = 'API_REFRESH_ERROR'

2. **Hash Calculation Errors** (in calculate_sha256):
   - Raises: `RAISE_APPLICATION_ERROR(-20005, 'Error calculating SHA256: ' || SQLERRM)`
   - Caught by: refresh_*_from_api's EXCEPTION block

3. **Parsing Errors** (in parse_*_json):
   - Any SQL errors during JSON_TABLE parsing
   - Caught by: refresh_*_from_api's EXCEPTION block
   - Logged with full error stack

4. **Merge Errors** (in upsert_*):
   - Any constraint violations or data type conversion errors
   - Caught by: refresh_*_from_api's EXCEPTION block

### What if Scenarios

#### API Fails?
- Error logged to ETL_ERROR_LOG
- ETL_RUN_LOG marked as FAILED
- Transaction rolled back
- SELECTION_LOADER keeps last successful timestamp

#### Parsing Fails?
- Caught by refresh_*_from_api
- Logged with full error stack
- Raw JSON still preserved for debugging

#### Duplicate Data?
- SHA256 hash detects identical response
- Processing skipped
- Marked as "duplicate" in logs
- Saves processing time

---

## Testing and Monitoring

### Key Monitoring Queries

```sql
-- Current selections
SELECT * FROM SELECTION_LOADER WHERE is_active = 'Y';

-- Active plants only
SELECT * FROM PLANTS WHERE is_valid = 'Y';

-- Issues for selected plants  
SELECT i.* 
FROM ISSUES i
JOIN SELECTION_LOADER s ON i.plant_id = s.plant_id
WHERE s.is_active = 'Y' AND i.is_valid = 'Y';

-- Check ETL history
SELECT * FROM ETL_RUN_LOG ORDER BY start_time DESC;

-- ETL history for selections
SELECT * FROM ETL_RUN_LOG 
WHERE plant_id IN (
  SELECT plant_id FROM SELECTION_LOADER WHERE is_active = 'Y'
)
ORDER BY start_time DESC;

-- Check for errors
SELECT * FROM ETL_ERROR_LOG WHERE error_timestamp > SYSDATE - 1;

-- Find potential plant ID changes
SELECT old.plant_id as old_id, new.plant_id as new_id, old.short_description
FROM PLANTS old
JOIN PLANTS new ON old.short_description = new.short_description
WHERE old.is_valid = 'N' AND new.is_valid = 'Y'
  AND old.plant_id != new.plant_id;
```

### Testing the Flow

To see the data at each stage:
```sql
-- Check raw JSON
SELECT raw_json_id, endpoint_key, LENGTH(response_json) as json_length, created_date 
FROM RAW_JSON WHERE endpoint_key = 'plants';

-- Check staging
SELECT COUNT(*) as staging_count FROM STG_PLANTS;

-- Check final data
SELECT COUNT(*) as active_plants FROM PLANTS WHERE is_valid = 'Y';

-- Check ETL history
SELECT * FROM ETL_RUN_LOG WHERE endpoint_key = 'plants' ORDER BY start_time DESC;
```

### What Happens on Subsequent Runs?

1. **If API returns same data:**
   - Hash matches existing RAW_JSON record
   - Process stops at deduplication check
   - ETL_RUN_LOG shows "Data unchanged (duplicate hash)"
   - No database changes occur

2. **If API returns different data:**
   - New RAW_JSON record created
   - All plants marked is_valid='N'
   - New/updated plants merged with is_valid='Y'
   - Deleted plants remain with is_valid='N'

### Success Metrics Example
- **API Response**: 28,643 characters
- **Plants Loaded**: 130
- **Tables Updated**: 4 (RAW_JSON, STG_PLANTS, PLANTS, ETL_RUN_LOG)
- **Processing**: Successful end-to-end

---

## CONTROL_SETTINGS Reference

### Currently Used Settings
| Setting Key | Value | Where Used | Purpose |
|------------|-------|------------|----------|
| API_BASE_URL | https://equinor.pipespec-api.presight.com/ | pkg_api_client.fetch_*_json() | Base URL for API calls |

### Future Settings (NOT Implemented)
| Setting Key | Value | Status |
|------------|-------|---------|
| API_TIMEOUT_SECONDS | 60 | NOT IMPLEMENTED |
| MAX_PLANTS_PER_RUN | 10 | NOT IMPLEMENTED |
| RAW_JSON_RETENTION_DAYS | 30 | NOT IMPLEMENTED (no purge job) |
| ETL_LOG_RETENTION_DAYS | 90 | NOT IMPLEMENTED (no purge job) |
| ENABLE_PARALLEL_PROCESSING | N | NOT IMPLEMENTED |
| BATCH_SIZE | 1000 | NOT IMPLEMENTED |

These settings exist but no code references them. They're ready for future enhancements.

---

## Next Steps After Selection

Once plants are selected and issues loaded:

1. **View Issues**: Display in UI for user review
2. **Select Specific Issues**: User can choose which issue revisions
3. **Load Reference Data**: Fetch PCS, VDS, etc. for selected issues
4. **Run Full ETL**: Process all downstream data

---

*Last Updated: 2025-08-24*
*Version: 2.0 - Merged from Plant_Selection_Flow.md and ETL_Flow_Documentation.md*