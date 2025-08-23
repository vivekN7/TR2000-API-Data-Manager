-- ===============================================================================
-- Setup Oracle Wallet for HTTPS API Calls
-- Run this as SYS or DBA user
-- ===============================================================================

-- Step 1: Create wallet directory (run in OS)
-- mkdir -p /opt/oracle/admin/wallet

-- Step 2: Create the wallet (run as oracle user in OS)
-- orapki wallet create -wallet /opt/oracle/admin/wallet -pwd WalletPasswd123 -auto_login

-- Step 3: Download and add the certificate
-- For Linux/Unix:
-- openssl s_client -showcerts -connect equinor.pipespec-api.presight.com:443 </dev/null 2>/dev/null | openssl x509 -outform PEM > api_cert.pem
-- orapki wallet add -wallet /opt/oracle/admin/wallet -trusted_cert -cert api_cert.pem -pwd WalletPasswd123

-- Step 4: Configure Network ACL (run as SYS)
BEGIN
    -- Drop existing ACL if exists
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.DROP_ACL(acl => 'tr2000_api_acl.xml');
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Ignore if doesn't exist
    END;
    
    -- Create new ACL
    DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(
        acl => 'tr2000_api_acl.xml',
        description => 'ACL for TR2000 API access',
        principal => 'TR2000_STAGING',
        is_grant => TRUE,
        privilege => 'connect',
        start_date => NULL,
        end_date => NULL
    );
    
    -- Add resolve privilege
    DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(
        acl => 'tr2000_api_acl.xml',
        principal => 'TR2000_STAGING',
        is_grant => TRUE,
        privilege => 'resolve'
    );
    
    -- Assign ACL to the API host
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'tr2000_api_acl.xml',
        host => 'equinor.pipespec-api.presight.com',
        lower_port => 443,
        upper_port => 443
    );
    
    -- Also add for any subdomain
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'tr2000_api_acl.xml',
        host => '*.presight.com',
        lower_port => 443,
        upper_port => 443
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Network ACL configured successfully');
END;
/

-- Step 5: Test the ACL configuration
SELECT host, lower_port, upper_port, acl
FROM dba_network_acls
WHERE host LIKE '%presight%';

-- Step 6: Check privileges for TR2000_STAGING
SELECT acl, principal, privilege, is_grant
FROM dba_network_acl_privileges
WHERE principal = 'TR2000_STAGING';

-- Step 7: Test connectivity (run as TR2000_STAGING)
-- After wallet is configured, test with:
DECLARE
    v_response CLOB;
BEGIN
    apex_web_service.g_request_headers.DELETE;
    apex_web_service.g_request_headers(1).name := 'Accept';
    apex_web_service.g_request_headers(1).value := 'application/json';
    
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',
        p_http_method => 'GET',
        p_wallet_path => 'file:/opt/oracle/admin/wallet',
        p_wallet_pwd => 'WalletPasswd123'
    );
    
    DBMS_OUTPUT.PUT_LINE('Success! Response length: ' || LENGTH(v_response));
END;
/