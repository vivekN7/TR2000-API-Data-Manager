# TR2000 ETL Flow Documentation - Plants API to Database

## QUICK ANSWERS TO YOUR QUESTIONS

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

### Q6: Who logs as complete?
**Answer:** pkg_api_client.refresh_plants_from_api updates ETL_RUN_LOG at the end (success or failure).

### Q7: What do the other packages do?
- **pkg_raw_ingest**: Handles RAW_JSON insertion and SHA256 deduplication
- **pkg_parse_plants**: Parses JSON to staging table
- **pkg_upsert_plants**: Merges staging to production
- **pkg_parse_issues**: Parses issues JSON (for issues endpoint)
- **pkg_upsert_issues**: Merges issues to production (for issues endpoint)
- **pkg_etl_operations**: Alternative orchestrator using CONTROL_ENDPOINTS (not used currently)

---

## Understanding Packages vs Procedures

### What is a Package?
A **package** is a container that groups related procedures and functions together. Think of it like a class in object-oriented programming.

### Package Structure:
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

### Why Use Packages?
1. **Organization**: Groups related functionality
2. **Encapsulation**: Can have private functions (not in spec)
3. **Performance**: Loaded once into memory
4. **Dependencies**: Easier to manage than standalone procedures

---

## Complete Data Flow for Plants Endpoint

When you called `pkg_api_client.refresh_plants_from_api`, here's EXACTLY what happened:

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
       - initiated_by: USER (TR2000_STAGING)

3. FETCH API CONFIGURATION
   └─> SELECT FROM CONTROL_SETTINGS
       - Retrieves 'API_BASE_URL' = 'https://equinor.pipespec-api.presight.com/'
       - Constructs URL: base_url + 'plants'

4. MAKE HTTPS API CALL
   └─> apex_web_service.make_rest_request()
       - URL: https://equinor.pipespec-api.presight.com/plants
       - Method: GET
       - Wallet: file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet
       - Password: WalletPass123
       - Returns: JSON with 130 plants (28,643 characters)

5. CALCULATE SHA256 HASH
   └─> pkg_api_client.calculate_sha256()
       - Uses DBMS_CRYPTO to hash the JSON response
       - Creates unique fingerprint for deduplication

6. CHECK FOR DUPLICATE
   └─> pkg_raw_ingest.is_duplicate_hash()
       - Checks if this exact response already exists in RAW_JSON
       - If duplicate: Skip processing, update ETL_RUN_LOG, exit
       - If new: Continue processing

7. STORE RAW RESPONSE
   └─> pkg_raw_ingest.insert_raw_json()
       └─> INSERT INTO RAW_JSON
           - raw_json_id: auto-generated (e.g., 1)
           - endpoint_key: 'plants'
           - plant_id: NULL (not plant-specific)
           - issue_revision: NULL (not issue-specific)
           - api_url: 'plants'
           - response_json: Full JSON CLOB (28,643 chars)
           - response_hash: SHA256 hash
           - api_call_timestamp: SYSTIMESTAMP
           - created_date: SYSDATE

8. PARSE JSON TO STAGING
   └─> pkg_parse_plants.parse_plants_json(raw_json_id)
       a. Clear staging: DELETE FROM STG_PLANTS
       b. Parse using JSON_TABLE:
          └─> INSERT INTO STG_PLANTS
              - Extracts all fields from JSON
              - Creates 130 records (one per plant)
              - All columns are VARCHAR2 for safety
              - Links back to raw_json_id

9. MERGE TO CORE TABLE
   └─> pkg_upsert_plants.upsert_plants()
       a. Soft delete existing: UPDATE PLANTS SET is_valid = 'N'
       b. MERGE operation:
          └─> MERGE INTO PLANTS
              - Matches on plant_id
              - Updates existing records
              - Inserts new records
              - Sets is_valid = 'Y' for current data
              - Converts VARCHAR2 to proper data types
              - Sets last_updated = SYSDATE

10. UPDATE ETL RUN LOG
    └─> UPDATE ETL_RUN_LOG
        - end_time: SYSTIMESTAMP
        - status: 'SUCCESS'
        - notes: 'Plants refreshed successfully'
        - duration_seconds: calculated
        - WHERE run_id = initial run_id

11. COMMIT TRANSACTION
    └─> All changes committed to database
```

## Tables Used in the Flow

### Input/Configuration Tables:
1. **CONTROL_SETTINGS**
   - Provides: API_BASE_URL
   - Used by: pkg_api_client.fetch_plants_json()

### Logging Tables:
2. **ETL_RUN_LOG**
   - Records: Start/end time, status, duration
   - One record per ETL execution

3. **ETL_ERROR_LOG** (only if errors occur)
   - Records: Error details if process fails
   - Not used in successful run

### Data Flow Tables:
4. **RAW_JSON**
   - Stores: Complete API response as-is
   - Purpose: Audit trail, deduplication, reprocessing

5. **STG_PLANTS**
   - Stores: Parsed JSON data in tabular format
   - Purpose: Staging area for validation/transformation
   - Format: All VARCHAR2 columns

6. **PLANTS**
   - Stores: Final normalized data
   - Purpose: Production table for application use
   - Format: Proper data types, constraints

### Not Used in Plants Flow:
- **CONTROL_ENDPOINTS** - Used for dynamic ETL but not directly in this flow
- **CONTROL_ENDPOINT_STATE** - Tracks endpoint status, not used here
- **SELECTION_LOADER** - For user selections, not used in plants load
- **ISSUES** - Separate endpoint/table
- **STG_ISSUES** - Separate staging table

## Key Design Patterns

### 1. SHA256 Deduplication
- Prevents reprocessing identical API responses
- Saves processing time and maintains data integrity

### 2. Three-Layer Architecture
```
RAW_JSON (Bronze) → STG_PLANTS (Silver) → PLANTS (Gold)
```
- Bronze: Raw, immutable API responses
- Silver: Parsed but unvalidated staging
- Gold: Clean, validated production data

### 3. Soft Delete Pattern
- Uses `is_valid = 'Y'/'N'` instead of DELETE
- Preserves history while showing current state

### 4. Comprehensive Logging
- Every ETL run tracked in ETL_RUN_LOG
- Errors captured in ETL_ERROR_LOG
- Raw responses preserved in RAW_JSON

## What Happens on Subsequent Runs?

1. **If API returns same data:**
   - Hash matches existing RAW_JSON record
   - Process stops at step 6
   - ETL_RUN_LOG shows "Data unchanged (duplicate hash)"
   - No database changes occur

2. **If API returns different data:**
   - New RAW_JSON record created
   - All plants marked is_valid='N'
   - New/updated plants merged with is_valid='Y'
   - Deleted plants remain with is_valid='N'

## Success Metrics from Your Run

- **API Response**: 28,643 characters
- **Plants Loaded**: 130
- **Tables Updated**: 4 (RAW_JSON, STG_PLANTS, PLANTS, ETL_RUN_LOG)
- **Processing**: Successful end-to-end

## WHO CALLS WHAT - DETAILED CONTROL FLOW

### The Master Orchestrator: pkg_api_client.refresh_plants_from_api

```sql
-- YOU initiate this manually:
EXEC pkg_api_client.refresh_plants_from_api(:status, :message);
```

This procedure then controls EVERYTHING:

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

### Error Handling at Each Level

1. **API Call Errors** (in fetch_plants_json):
   - Raises: `RAISE_APPLICATION_ERROR(-20002, 'Error fetching plants: ' || SQLERRM)`
   - Caught by: refresh_plants_from_api's EXCEPTION block
   - Logged to: ETL_ERROR_LOG with error_type = 'API_REFRESH_ERROR'

2. **Hash Calculation Errors** (in calculate_sha256):
   - Raises: `RAISE_APPLICATION_ERROR(-20005, 'Error calculating SHA256: ' || SQLERRM)`
   - Caught by: refresh_plants_from_api's EXCEPTION block
   - Logged to: ETL_ERROR_LOG

3. **Parsing Errors** (in parse_plants_json):
   - Any SQL errors during JSON_TABLE parsing
   - Caught by: refresh_plants_from_api's EXCEPTION block
   - Logged to: ETL_ERROR_LOG with full error stack

4. **Merge Errors** (in upsert_plants):
   - Any constraint violations or data type conversion errors
   - Caught by: refresh_plants_from_api's EXCEPTION block
   - Logged to: ETL_ERROR_LOG

---

## CONTROL_SETTINGS - What's Actually Used?

### Currently Used Settings:
| Setting Key | Value | Where Used | Purpose |
|------------|-------|------------|----------|
| API_BASE_URL | https://equinor.pipespec-api.presight.com/ | pkg_api_client.fetch_plants_json() | Base URL for API calls |

### NOT Used (Placeholders for Future):
| Setting Key | Value | Status |
|------------|-------|---------|
| API_TIMEOUT_SECONDS | 60 | NOT IMPLEMENTED |
| MAX_PLANTS_PER_RUN | 10 | NOT IMPLEMENTED |
| RAW_JSON_RETENTION_DAYS | 30 | NOT IMPLEMENTED (no purge job) |
| ETL_LOG_RETENTION_DAYS | 90 | NOT IMPLEMENTED (no purge job) |
| ENABLE_PARALLEL_PROCESSING | N | NOT IMPLEMENTED |
| BATCH_SIZE | 1000 | NOT IMPLEMENTED |

These settings exist but no code references them. They're ready for future enhancements like:
- Implementing data retention/purging
- Limiting batch sizes
- Parallel processing

---

## Package Responsibilities Summary

### Active Packages (Used in Plants Flow):
1. **pkg_api_client** - Master orchestrator, API calls, main ETL flow control
2. **pkg_raw_ingest** - RAW_JSON operations, SHA256 deduplication
3. **pkg_parse_plants** - JSON parsing to staging (STG_PLANTS)
4. **pkg_upsert_plants** - Staging to production merge (PLANTS)

### Active Packages (For Issues - Similar Pattern):
5. **pkg_parse_issues** - JSON parsing for issues endpoint
6. **pkg_upsert_issues** - Issues staging to production

### Future/Alternative Package:
7. **pkg_etl_operations** - Dynamic ETL using CONTROL_ENDPOINTS table (not currently used, alternative approach)

---

## Key Architecture Decisions

### Why pkg_api_client Controls Everything?
- **Single Responsibility**: One place to understand the flow
- **Transaction Control**: Can COMMIT/ROLLBACK entire operation
- **Error Handling**: Centralized exception management
- **Logging**: Consistent ETL_RUN_LOG updates

### Why Separate Parse and Upsert Packages?
- **Modularity**: Can reprocess without re-fetching
- **Testing**: Can test parsing separately from merging
- **Reusability**: Same pattern for plants, issues, and future endpoints

### Why Check SHA256 Hash?
- **Performance**: Avoid reprocessing identical data
- **Audit**: Know when API data actually changes
- **Efficiency**: 130 plants takes seconds to process, but why do it if nothing changed?

---

## Testing the Flow

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