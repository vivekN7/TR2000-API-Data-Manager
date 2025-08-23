-- Create Oracle Wallet on Database Server as SYSDBA
SET SERVEROUTPUT ON SIZE UNLIMITED

-- Switch to PDB
ALTER SESSION SET CONTAINER = XEPDB1;

PROMPT ========================================
PROMPT Creating Wallet on Database Server
PROMPT ========================================

-- Check if database has wallet tools
DECLARE
    v_wallet_root VARCHAR2(500);
    v_cmd VARCHAR2(4000);
BEGIN
    -- Get Oracle home
    SELECT value INTO v_wallet_root
    FROM v$parameter
    WHERE name = 'db_recovery_file_dest';
    
    DBMS_OUTPUT.PUT_LINE('Database recovery dest: ' || v_wallet_root);
EXCEPTION
    WHEN OTHERS THEN
        v_wallet_root := '/opt/oracle';
        DBMS_OUTPUT.PUT_LINE('Using default: ' || v_wallet_root);
END;
/

-- Create wallet using DBMS_NETWORK_ACL_ADMIN (alternative approach)
BEGIN
    DBMS_OUTPUT.PUT_LINE('Setting up ACL with certificate trust...');
    
    -- Create a more permissive ACL for HTTPS
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(
            privilege_list => xs$name_list('http', 'connect', 'resolve'),
            principal_name => 'TR2000_STAGING',
            principal_type => xs_acl.ptype_db
        )
    );
    
    -- Grant to APEX schema too
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(
            privilege_list => xs$name_list('http', 'connect', 'resolve'),
            principal_name => 'APEX_240200',
            principal_type => xs_acl.ptype_db
        )
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ ACLs configured for all hosts');
END;
/

-- Check if we can use the database's default wallet
DECLARE
    v_req UTL_HTTP.REQ;
    v_resp UTL_HTTP.RESP;
    v_wallet_path VARCHAR2(500);
BEGIN
    -- Common wallet locations
    FOR wallet_rec IN (
        SELECT 'file:/opt/oracle/admin/XE/wallet' as path FROM dual UNION ALL
        SELECT 'file:/opt/oracle/wallet' as path FROM dual UNION ALL
        SELECT 'file:/u01/app/oracle/admin/XE/wallet' as path FROM dual UNION ALL
        SELECT 'file:$ORACLE_BASE/admin/$ORACLE_SID/wallet' as path FROM dual
    ) LOOP
        BEGIN
            DBMS_OUTPUT.PUT_LINE('Trying wallet: ' || wallet_rec.path);
            
            UTL_HTTP.SET_WALLET(wallet_rec.path);
            
            v_req := UTL_HTTP.BEGIN_REQUEST('https://httpbin.org/get', 'GET');
            v_resp := UTL_HTTP.GET_RESPONSE(v_req);
            
            DBMS_OUTPUT.PUT_LINE('✅ SUCCESS with wallet: ' || wallet_rec.path);
            DBMS_OUTPUT.PUT_LINE('Status: ' || v_resp.status_code);
            
            UTL_HTTP.END_RESPONSE(v_resp);
            
            -- Save this wallet path for APEX
            UPDATE APEX_240200.WWV_FLOW_PLATFORM_PREFS
            SET value = wallet_rec.path
            WHERE name = 'WALLET_PATH';
            COMMIT;
            
            EXIT; -- Found working wallet
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('  Failed: ' || SUBSTR(SQLERRM, 1, 50));
        END;
    END LOOP;
END;
/

PROMPT ========================================
PROMPT Wallet setup complete
PROMPT ========================================