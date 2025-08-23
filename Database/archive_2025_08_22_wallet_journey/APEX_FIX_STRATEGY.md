# APEX_WEB_SERVICE Fix Strategy - Path to Low-Code Solution

## Current Situation
- **UTL_HTTP**: Working but verbose (current workaround)
- **APEX_WEB_SERVICE**: Failing with ORA-29273
- **Root Cause**: APEX 24.2 partially installed - missing core WWV_FLOW tables
- **Goal**: Get APEX fully functional for low-code development

## Fix Strategy (In Order of Priority)

### Phase 1: Verify APEX Installation Status
```sql
-- Check what we actually have installed
SELECT * FROM apex_release;
SELECT COUNT(*) FROM all_objects WHERE owner = 'APEX_240200';
SELECT object_type, COUNT(*) FROM all_objects 
WHERE owner = 'APEX_240200' 
GROUP BY object_type;

-- Check if it's runtime-only or full installation
SELECT * FROM dba_registry WHERE comp_id = 'APEX';
```

### Phase 2: Attempt In-Place Repair (Least Disruptive)
```sql
-- As SYSDBA, try to repair missing components
ALTER SESSION SET CONTAINER = XEPDB1;

-- Create missing instance tables
@/workspace/TR2000/TR2K/Database/apex/core/wwv_flow_platform_prefs.sql
@/workspace/TR2000/TR2K/Database/apex/core/instance_settings.sql

-- Initialize instance parameters
BEGIN
    APEX_INSTANCE_ADMIN.SET_PARAMETER('ALLOW_PUBLIC_WEBSERVICES', 'Y');
    APEX_INSTANCE_ADMIN.SET_PARAMETER('RESTful_SERVICES_ENABLED', 'Y');
    COMMIT;
END;
/
```

### Phase 3: Test with Simple HTTP First
Before testing with HTTPS (which requires wallet), test with HTTP:

```sql
-- Test 1: Simple HTTP endpoint
DECLARE
    v_response CLOB;
BEGIN
    -- Set proxy if needed (common in Docker)
    apex_web_service.g_request_headers(1).name := 'User-Agent';
    apex_web_service.g_request_headers(1).value := 'Oracle/TR2000';
    
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    DBMS_OUTPUT.PUT_LINE('Success! Response length: ' || LENGTH(v_response));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/
```

### Phase 4: Configure Oracle Wallet for HTTPS
If HTTP works but HTTPS doesn't, configure wallet:

```bash
# Create wallet directory
mkdir -p /opt/oracle/admin/XE/wallet

# Create wallet
orapki wallet create -wallet /opt/oracle/admin/XE/wallet -auto_login

# Add trusted certificates
orapki wallet add -wallet /opt/oracle/admin/XE/wallet -trusted_cert -cert /path/to/cert.crt
```

```sql
-- Configure wallet location
BEGIN
    UTL_HTTP.SET_WALLET('file:/opt/oracle/admin/XE/wallet');
END;
/
```

### Phase 5: Nuclear Option - Full APEX Reinstall
If repair fails, do clean reinstall:

```sql
-- First, backup any existing APEX data
CREATE TABLE apex_backup AS SELECT * FROM apex_instance_parameters;

-- Remove broken installation
@/workspace/TR2000/TR2K/Database/apex/apxremov.sql

-- Fresh install
@/workspace/TR2000/TR2K/Database/apex/apexins.sql SYSAUX SYSAUX TEMP /i/

-- Configure REST
@/workspace/TR2000/TR2K/Database/apex/apex_rest_config.sql

-- Set admin password
@/workspace/TR2000/TR2K/Database/apex/apxchpwd.sql
```

## Quick Win Possibilities

### Option A: Hybrid Approach (Immediate)
Keep UTL_HTTP for now but wrap it to look like APEX_WEB_SERVICE:

```sql
CREATE OR REPLACE PACKAGE apex_web_service_wrapper AS
    -- Mimic APEX_WEB_SERVICE interface
    FUNCTION make_rest_request(
        p_url VARCHAR2,
        p_http_method VARCHAR2 DEFAULT 'GET'
    ) RETURN CLOB;
END;
/
```

### Option B: Docker Network Fix
Sometimes Docker networking causes issues:

```sql
-- Check if it's a Docker DNS issue
SELECT UTL_INADDR.GET_HOST_ADDRESS('httpbin.org') FROM dual;

-- If that fails, use IP directly
v_response := apex_web_service.make_rest_request(
    p_url => 'http://93.184.216.34/get',  -- httpbin.org IP
    p_http_method => 'GET'
);
```

### Option C: Instance-Level Fix (Without Full Reinstall)
```sql
-- Manually create minimal instance tables
CREATE TABLE wwv_flow_platform_prefs (
    name VARCHAR2(255),
    value VARCHAR2(4000)
);

INSERT INTO wwv_flow_platform_prefs VALUES ('ALLOW_PUBLIC_WEBSERVICES', 'Y');
INSERT INTO wwv_flow_platform_prefs VALUES ('RESTFUL_SERVICES_ENABLED', 'Y');
COMMIT;

-- Grant access
GRANT SELECT ON wwv_flow_platform_prefs TO APEX_240200;
```

## Decision Matrix

| Solution | Effort | Risk | Success Rate | Time |
|----------|--------|------|--------------|------|
| In-Place Repair | Low | Low | 30% | 30 min |
| HTTP Test First | Low | None | 50% | 10 min |
| Wallet Config | Medium | Low | 70% | 1 hour |
| Full Reinstall | High | Medium | 95% | 2 hours |
| Stay with UTL_HTTP | None | None | 100% | 0 min |

## My Recommendation

1. **Try Phase 3 first** - Test with simple HTTP to isolate HTTPS/wallet issues
2. **If HTTP works**, configure wallet for HTTPS (Phase 4)
3. **If HTTP fails**, attempt in-place repair (Phase 2)
4. **Last resort**, full reinstall (Phase 5)

## Why This Matters for Low-Code

Getting APEX_WEB_SERVICE working enables:
- Automatic JSON parsing
- Built-in error handling
- Response caching
- OAuth support
- Direct APEX app integration
- Declarative REST data sources
- No PL/SQL needed for simple operations

Without it, you're stuck writing verbose UTL_HTTP code for every API call.

## Next Immediate Step

Let's test if the issue is HTTPS-specific:

```sql
-- This test takes 30 seconds and tells us everything
DECLARE
    v_response CLOB;
BEGIN
    -- Test 1: HTTP (no SSL)
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'http://httpbin.org/get',
            p_http_method => 'GET'
        );
        DBMS_OUTPUT.PUT_LINE('HTTP works!');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('HTTP failed: ' || SQLERRM);
    END;
    
    -- Test 2: HTTPS (requires wallet)
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://httpbin.org/get',
            p_http_method => 'GET'
        );
        DBMS_OUTPUT.PUT_LINE('HTTPS works!');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('HTTPS failed: ' || SQLERRM);
    END;
END;
/
```

This will immediately tell us if we're dealing with:
- Complete APEX failure (both fail)
- Wallet/HTTPS issue only (HTTP works, HTTPS fails)
- Something else entirely