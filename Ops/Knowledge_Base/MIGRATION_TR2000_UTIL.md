# TR2000_UTIL Proxy Migration Documentation

## Date: 2025-08-27
## Purpose: Document the migration from direct APEX_WEB_SERVICE calls to DBA's TR2000_UTIL proxy pattern

## Overview
This migration implements a centralized proxy pattern for API calls as recommended by the DBA. Instead of each schema user requiring network ACL permissions, all API calls now route through SYSTEM.TR2000_UTIL package.

## Architecture Change

### Before (Direct API Calls)
```
PKG_API_CLIENT → APEX_WEB_SERVICE → External API
```
- Problem: Each user needs network ACL permissions
- Security: Multiple ACL grants required
- Logging: Decentralized or missing

### After (Proxy Pattern)
```
PKG_API_CLIENT → make_api_request_util → SYSTEM.TR2000_UTIL → APEX_WEB_SERVICE → External API
```
- Benefit: Only SYSTEM needs network permissions
- Security: Centralized authentication via APEX credentials
- Logging: All calls logged to ETL_LOG table

## New Objects Created

### In SYSTEM Schema
1. **TR2000_UTIL Package** (`00_users/03_tr2000_util_package_final.sql`)
   - `http_get()` - Makes HTTP GET requests
   - `log_event()` - Logs API calls to ETL_LOG
   - `hash_json()` - Creates fingerprints for deduplication

### In TR2000_STAGING Schema
1. **ETL_LOG Table** (merged into `01_tables/05_log_tables.sql`)
   - Stores all API call logs
   - Tracks batch_id, status, errors

2. **Utility Functions** (`03_packages/07_utility_functions.sql`)
   - `make_api_request_util()` - Wrapper for TR2000_UTIL
   - `get_last_http_status()` - Status code retrieval
   - `V_RECENT_API_CALLS` - View for monitoring

## Table Structure Changes

### RAW_JSON Table Columns Renamed
Updated in `01_tables/01_raw_json.sql`:
- `endpoint_key` → `endpoint`
- `response_json` → `payload`
- `response_hash` → `key_fingerprint`
- `correlation_id` → `batch_id`
- Removed: `api_url` (redundant)

## Package Updates
All packages updated to use new column names:
- PKG_RAW_INGEST
- PKG_API_CLIENT
- PKG_PARSE_PLANTS
- PKG_PARSE_ISSUES
- PKG_PARSE_REFERENCES

## APEX Credential Setup (REQUIRED FOR PRODUCTION)

### Create TR2000_CRED in APEX Workspace:
1. Login to APEX as workspace admin
2. Navigate to: Workspace Utilities → Web Credentials
3. Click "Create"
4. Fill in:
   - **Credential Name**: TR2000_CRED
   - **Authentication Type**: Basic Authentication (or as required by API)
   - **Username**: (API username if required)
   - **Password**: (API password if required)
   - **Valid for URLs**: https://equinor.pipespec-api.presight.com/*
5. Apply Changes

### Note on Credentials
- Currently, the API works without authentication (public endpoint)
- TR2000_CRED is required for the package to compile but can be empty
- In production, proper credentials should be configured

## Installation Order

### Fresh Installation:
```sql
-- 1. As SYSTEM user:
@00_users/03_tr2000_util_package_final.sql
GRANT EXECUTE ON tr2000_util TO TR2000_STAGING;

-- 2. As TR2000_STAGING user:
@01_tables/01_raw_json.sql
@01_tables/05_log_tables.sql
@03_packages/07_utility_functions.sql
-- Then all other packages in order
```

### Migration from Existing System:
1. Drop old RAW_JSON table (data will be lost - backup if needed)
2. Follow fresh installation steps
3. Create APEX credential TR2000_CRED

## Testing the Migration

### Test API Connectivity:
```sql
-- As TR2000_STAGING user
SET SERVEROUTPUT ON
DECLARE
    v_response CLOB;
BEGIN
    v_response := make_api_request_util(
        'https://equinor.pipespec-api.presight.com/plants',
        'GET'
    );
    DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(v_response));
END;
/
```

### Check Logs:
```sql
SELECT * FROM V_RECENT_API_CALLS;
SELECT * FROM ETL_LOG WHERE created_at > SYSDATE - 1/24;
```

## Production Deployment Checklist

- [ ] Create TR2000_CRED in APEX workspace
- [ ] Verify API_BASE_URL in CONTROL_SETTINGS table
- [ ] Grant EXECUTE on SYSTEM.tr2000_util to application schema
- [ ] Test API connectivity
- [ ] Verify logging to ETL_LOG
- [ ] Remove any direct network ACL grants (no longer needed)

## Troubleshooting

### ORA-20001: HTTP_GET failed
- Check TR2000_CRED exists in APEX
- Verify network connectivity
- Check ETL_LOG for detailed error

### Package compilation errors
- Ensure SYSTEM.tr2000_util exists and is valid
- Verify grants are in place
- Check column names match (endpoint, payload, etc.)

### No data in ETL_LOG
- Verify SYSTEM has INSERT privilege on TR2000_STAGING.ETL_LOG
- Check autonomous transaction is working

## Benefits of This Architecture

1. **Security**: Single point of network access control
2. **Logging**: Centralized API call auditing
3. **Maintenance**: Changes to API authentication only in one place
4. **Production Ready**: Uses APEX credentials (standard Oracle pattern)
5. **Debugging**: All API calls logged with batch tracking

## Files Archived
The following incremental scripts have been merged into master files:
- create_etl_log_table.sql → 05_log_tables.sql
- restructure_raw_json_table.sql → 01_raw_json.sql
- fix_make_api_request_util_v2.sql → 07_utility_functions.sql
- migrate_to_tr2000_util_2025-08-27.sql → 07_utility_functions.sql

All archived in: `incremental/archived_merged/` with appropriate suffixes