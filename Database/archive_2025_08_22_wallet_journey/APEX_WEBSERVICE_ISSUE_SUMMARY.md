# APEX_WEB_SERVICE Issue Summary - TR2000 Project

## Executive Summary
APEX_WEB_SERVICE fails with ORA-29273 despite Network ACLs being properly configured. Investigation reveals APEX 24.2 installation is incomplete/corrupted with missing core components.

## Environment
- **Database**: Oracle 21c Express Edition (21.3.0.0.0)
- **APEX Version**: 24.2.0 (reported by apex_release)
- **Container**: XEPDB1 (Pluggable Database)
- **Environment**: Docker container accessing database via host.docker.internal:1521
- **Schema**: TR2000_STAGING (regular user, not APEX workspace)

## The Problem
1. **Symptom**: `apex_web_service.make_rest_request` fails with ORA-29273 for ALL URLs (HTTP and HTTPS)
2. **UTL_HTTP works perfectly** with same URLs and same Network ACLs
3. **Network ACLs are properly configured** for all required hosts

## Investigation Results

### What Works ✅
- UTL_HTTP successfully makes HTTP/HTTPS calls
- Network ACLs configured and verified for:
  - equinor.pipespec-api.presight.com
  - *.presight.com  
  - httpbin.org
  - jsonplaceholder.typicode.com
- APEX_WEB_SERVICE package exists and is accessible
- Public synonym APEX_WEB_SERVICE points to APEX_240200.WWV_FLOW_WEBSERVICES_API

### What's Broken ❌

#### 1. **APEX Core Tables Missing**
```sql
SELECT COUNT(*) FROM all_tables 
WHERE owner = 'APEX_240200' AND table_name LIKE 'WWV_FLOW%';
-- Result: 0 (should be hundreds)
```

#### 2. **APEX_INSTANCE_ADMIN Package Missing**
- Public synonym exists but points to non-existent APEX_240200.WWV_FLOW_INSTANCE_ADMIN
- Cannot set instance parameters like ALLOW_PUBLIC_WEBSERVICES

#### 3. **Instance Parameters Not Initialized**
```sql
SELECT COUNT(*) FROM apex_instance_parameters;
-- Result: 0 (should have default parameters)
```

#### 4. **No APEX Workspaces**
- No INTERNAL workspace found
- TR2000_STAGING is not associated with any APEX workspace

## Root Cause Analysis

### Primary Issue: **Incomplete APEX Installation**
APEX 24.2 appears to be only partially installed:
- The APEX_240200 schema exists
- Basic views like apex_release work
- But core WWV_FLOW tables are missing
- Instance administration components don't exist

### Why This Affects APEX_WEB_SERVICE
1. APEX_WEB_SERVICE checks internal parameter ALLOW_PUBLIC_WEBSERVICES
2. This parameter should be stored in instance configuration tables
3. These tables don't exist in this installation
4. The check fails, blocking all web service calls

### Why UTL_HTTP Works
- UTL_HTTP is a database-native package
- Only requires Network ACLs (which are configured)
- Doesn't depend on APEX infrastructure

## Docker Considerations

### Potential Docker-Related Issues:
1. **Installation Method**: APEX may have been installed incorrectly in the containerized Oracle XE
2. **PDB Limitations**: Pluggable databases have restrictions (e.g., cannot create PUBLIC synonyms)
3. **Missing Installation Steps**: Post-installation configuration may have been skipped
4. **Runtime vs Full Mode**: Might be runtime-only installation missing development tables

## Attempted Solutions

### What We Tried:
1. ✅ Configured Network ACLs (successful, UTL_HTTP works)
2. ✅ Created manual INSTANCE_PARAMETERS table
3. ✅ Set ALLOW_PUBLIC_WEBSERVICES = 'Y' 
4. ✅ Created missing WWV_FLOW_INSTANCE_ADMIN package
5. ❌ APEX_WEB_SERVICE still fails (deeper internal checks)

## Recommended Solutions

### Option 1: **Reinstall APEX Properly** (Recommended)
```bash
# Download APEX 24.2
wget https://download.oracle.com/otn_software/apex/apex_24.2.zip
unzip apex_24.2.zip
cd apex

# Connect as SYSDBA to CDB
sqlplus sys/password@//localhost:1521/XE as sysdba

# Switch to PDB
ALTER SESSION SET CONTAINER = XEPDB1;

# Run installation
@apexins.sql SYSAUX SYSAUX TEMP /i/

# Configure APEX instance admin
@apex_rest_config.sql

# Set admin password
@apxchpwd.sql
```

### Option 2: **Use UTL_HTTP Instead**
- Proven to work in current environment
- Requires updating pkg_api_client package
- More verbose but reliable

### Option 3: **Repair Current Installation**
```sql
-- As SYS, run APEX validation
@?/apex/validate_apex.sql

-- Run missing component installation
@?/apex/core/wwv_flow_platform_prefs.sql
@?/apex/core/wwv_flow_instance_admin.sql
```

## Questions for Further Investigation

1. **How was APEX installed in this Docker container?**
   - Was it pre-installed with Oracle XE?
   - Was it added later?
   - Which installation script was used?

2. **Is this a runtime-only installation?**
   - Check for @apxrtins.sql vs @apexins.sql

3. **Are there proxy requirements in Docker?**
   - Does the container need proxy settings for external URLs?

4. **Database version compatibility?**
   - Is APEX 24.2 fully compatible with Oracle 21c XE?

## Code Impact Analysis

### If we switch to UTL_HTTP:
- **Files to update**: Master_DDL.sql (pkg_api_client package)
- **Functions affected**: fetch_plants_json, fetch_issues_json
- **Additional code**: ~20 lines per function
- **Benefits**: Immediate solution, proven to work
- **Drawbacks**: More verbose, manual response handling

### If we fix APEX:
- **No code changes required**
- **Benefits**: Cleaner code, built-in features, future APEX app support
- **Risks**: Installation might affect other database operations

## Recommendation

Given that this is a test environment and you're the DBA:

1. **First**: Try to repair/reinstall APEX properly (it's worth the effort)
2. **Fallback**: If APEX repair is too complex/risky, switch to UTL_HTTP
3. **Long-term**: Document the issue for production deployment

## Test Commands

```sql
-- Quick test to verify if fix worked
DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    DBMS_OUTPUT.PUT_LINE('SUCCESS! Length: ' || LENGTH(v_response));
END;
/
```

---
*Document prepared for: Cross-LLM consultation on APEX_WEB_SERVICE issues*
*Date: 2025-08-22*
*Project: TR2000 ETL System*