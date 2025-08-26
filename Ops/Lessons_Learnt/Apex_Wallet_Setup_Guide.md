# 🔴 CRITICAL: APEX Wallet and Network ACL Setup Guide

## Problem Summary
APEX_WEB_SERVICE requires two things to make HTTPS API calls:
1. **Network ACL permissions** - Often overlooked, this blocks everything if not set
2. **Oracle Wallet with SSL certificates** - Required for HTTPS connections

### 🔴 CRITICAL DISCOVERY (2025-08-24)
- **WORKING API**: `https://equinor.pipespec-api.presight.com/` ✅
- **NOT WORKING**: `https://tr2000api.equinor.com/` ❌ (needs different certificates)
- **NEVER USE**: `/v1/` in the URL path - this was causing 404 errors!

## ⚠️ Common Pitfall
**90% of "wallet not working" issues are actually Network ACL issues!** The wallet might be perfect, but if the ACL blocks network access, you'll get certificate errors that are misleading.

---

## STEP 1: Network ACL Setup (MOST IMPORTANT!)

### Check Current APEX Version
```sql
-- Connect as any user with APEX access
SELECT version_no FROM apex_release;
```
This gives you something like `24.2.0`, which means your APEX schema is `APEX_240200`.

### Grant Network ACL Permissions
```sql
-- MUST RUN AS SYSDBA
-- sqlplus sys/your_password@localhost:1521/XEPDB1 as sysdba

ALTER SESSION SET CONTAINER = XEPDB1;

-- Grant for TR2000_STAGING user
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => 'TR2000_STAGING',
            principal_type => xs_acl.ptype_db
        )
    );
END;
/

-- Grant for APEX schema (CHANGE VERSION NUMBER TO MATCH YOUR APEX!)
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => 'APEX_240200',  -- UPDATE THIS!
            principal_type => xs_acl.ptype_db
        )
    );
END;
/

COMMIT;
```

### Verify ACL is Working
```sql
-- Connect as TR2000_STAGING
CONNECT TR2000_STAGING/piping@localhost:1521/XEPDB1

-- Test 1: Can we resolve hostnames?
DECLARE
    v_ip VARCHAR2(100);
BEGIN
    v_ip := UTL_INADDR.GET_HOST_ADDRESS('www.google.com');
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Can resolve hosts. IP: ' || v_ip);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FAILED: ' || SQLERRM);
END;
/

-- Test 2: Can we make HTTP calls?
DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    DBMS_OUTPUT.PUT_LINE('SUCCESS: HTTP works! Length: ' || LENGTH(v_response));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FAILED: ' || SQLERRM);
END;
/
```

If these tests fail, STOP! Fix the ACL first before touching the wallet.

---

## STEP 2: Oracle Wallet Setup

### Option A: Use Existing Oracle Wallet (RECOMMENDED)
During Oracle installation, a wallet is often created at:
- `C:\app\[username]\product\21c\dbhomeXE\network\admin\wallet`

Check if it exists and has certificates:
```cmd
cd C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet
dir
```

If you see `cwallet.sso` and `ewallet.p12`, you have a wallet!

### Option B: Create New Wallet
If no wallet exists or you need to add certificates:

```cmd
# On Windows, navigate to Oracle bin directory
cd C:\app\vivek\product\21c\dbhomeXE\bin

# Create wallet directory
mkdir C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet
cd C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet

# Create wallet
orapki wallet create -wallet . -auto_login -pwd WalletPass123

# Download Let's Encrypt certificates (for APIs using Let's Encrypt)
curl -o isrgrootx1.pem https://letsencrypt.org/certs/isrgrootx1.pem
curl -o lets-encrypt-r3.pem https://letsencrypt.org/certs/lets-encrypt-r3.pem

# Add certificates to wallet
orapki wallet add -wallet . -trusted_cert -cert isrgrootx1.pem -pwd WalletPass123
orapki wallet add -wallet . -trusted_cert -cert lets-encrypt-r3.pem -pwd WalletPass123

# Verify wallet contents
orapki wallet display -wallet . -pwd WalletPass123
```

### Update sqlnet.ora (Optional but Recommended)
Edit `C:\app\vivek\product\21c\dbhomeXE\network\admin\sqlnet.ora`:
```
WALLET_LOCATION = 
   (SOURCE = 
      (METHOD = FILE)
      (METHOD_DATA = 
         (DIRECTORY = C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet)
      )
   )

SSL_CLIENT_AUTHENTICATION = FALSE
SSL_VERSION = 0
```

---

## STEP 3: Configure APEX to Use Wallet

### Update pkg_api_client in Master_DDL.sql
```sql
CREATE OR REPLACE PACKAGE BODY pkg_api_client AS
    -- CRITICAL: Use Windows path (not Docker path!) and include password
    -- Wallet configuration that WORKS:
    
    FUNCTION fetch_plants_json RETURN CLOB IS
        l_response CLOB;
        l_url VARCHAR2(500);
    BEGIN
        l_url := get_base_url() || '/plants';  -- NO /v1 here!
        
        l_response := APEX_WEB_SERVICE.make_rest_request(
            p_url => l_url,
            p_http_method => 'GET',
            p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
            p_wallet_pwd => 'WalletPass123'  -- MUST include password!
        );
        
        RETURN l_response;
    END;
```

### Test the Complete Setup
```sql
-- Final test (UPDATED: Using working API endpoint)
SET SERVEROUTPUT ON
DECLARE
    v_response CLOB;
BEGIN
    -- Using the WORKING endpoint (not tr2000api.equinor.com)
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',
        p_http_method => 'GET',
        p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
        p_wallet_pwd => 'WalletPass123'  -- CRITICAL: Must include password!
    );
    DBMS_OUTPUT.PUT_LINE('SUCCESS! Length: ' || LENGTH(v_response));
    DBMS_OUTPUT.PUT_LINE('First 200 chars: ' || SUBSTR(v_response, 1, 200));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FAILED: ' || SQLERRM);
        IF SQLCODE = -29024 THEN
            DBMS_OUTPUT.PUT_LINE('Try the alternative endpoint: equinor.pipespec-api.presight.com');
        END IF;
END;
/
```

---

## Troubleshooting Checklist

### Error: ORA-24247: network access denied by access control list (ACL)
**Solution**: Network ACL not set. Run Step 1 as SYSDBA.

### Error: ORA-29024: Certificate validation failure
**Solution**: Wallet missing or doesn't have required certificates. Check Step 2.

### Error: ORA-29273: HTTP request failed (after ACL is fixed)
**Solution**: Usually wallet path is wrong or wallet doesn't exist. Verify wallet location.

### After APEX Reinstall
1. Check new APEX version: `SELECT version_no FROM apex_release;`
2. Grant ACL to new APEX schema (e.g., APEX_240200)
3. Wallet should still work if in Oracle home directory

### Quick Debug Script
```sql
-- Run this to check everything
SET SERVEROUTPUT ON

-- 1. Check APEX version
SELECT 'APEX Version: ' || version_no FROM apex_release;

-- 2. Test HTTP (no SSL)
DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    DBMS_OUTPUT.PUT_LINE('HTTP works: YES');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('HTTP works: NO - ' || SQLERRM);
END;
/

-- 3. Test HTTPS with wallet
DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://jsonplaceholder.typicode.com/posts/1',
        p_http_method => 'GET',
        p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
        p_wallet_pwd => 'WalletPass123'
    );
    DBMS_OUTPUT.PUT_LINE('HTTPS works: YES');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('HTTPS works: NO - ' || SQLERRM);
END;
/
```

---

## Recovery Commands

### Complete Setup from Scratch
```sql
-- 1. As SYSDBA: Grant ACL
sqlplus sys/justkeepswimming@localhost:1521/XEPDB1 as sysdba
@/workspace/TR2000/TR2K/Database/scripts/fix_network_acl.sql

-- 2. As TR2000_STAGING: Deploy schema
sqlplus TR2000_STAGING/piping@localhost:1521/XEPDB1
@/workspace/TR2000/TR2K/Database/Master_DDL.sql

-- 3. Test API
@/workspace/TR2000/TR2K/Database/scripts/test_refresh_plants.sql
```

### Working Configuration (As of 2025-08-24)
- **Wallet Path**: `file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet`
- **Wallet Password**: `WalletPass123`
- **APEX Version**: 24.2.0 (schema APEX_240200)
- **API Base URL**: `https://equinor.pipespec-api.presight.com/` ✅ WORKING
- **Alternative API**: `https://tr2000api.equinor.com/` ❌ REQUIRES DIFFERENT CERTIFICATES

---

## Key Lessons Learned

1. **Always check Network ACL first** - It's the most common issue
2. **APEX reinstall creates new schema** - Must grant ACL to new APEX_XXXXXX schema
3. **Wallet in Oracle home survives reinstalls** - Use Oracle home directory, not custom paths
4. **Test with HTTP first** - Isolates network issues from SSL issues
5. **Error messages are misleading** - "Certificate error" often means ACL issue
6. **NEVER use /v1 in TR2000 API URLs** - The correct URL is `https://equinor.pipespec-api.presight.com/plants`, NOT `/v1/plants`
7. **Two APIs available** - `equinor.pipespec-api.presight.com` works with Let's Encrypt certs, `tr2000api.equinor.com` needs specific certs
8. **Docker paths don't work on Windows** - Always use Windows paths like `C:\app\...` not `/workspace/...`

---

## Files to Keep Safe

1. `/workspace/TR2000/TR2K/Database/Master_DDL.sql` - Has correct wallet path
2. `/workspace/TR2000/TR2K/Database/scripts/fix_network_acl.sql` - ACL setup script
3. `/workspace/TR2000/TR2K/Database/scripts/test_refresh_plants.sql` - Verification script
4. This guide - `Apex_Wallet_Setup_Guide.md`

Save these files and you can recover from any disaster in 15 minutes instead of 2 days!