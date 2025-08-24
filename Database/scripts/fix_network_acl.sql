-- ===============================================================================
-- Fix Network ACL for APEX_WEB_SERVICE
-- Must be run as SYSDBA
-- ===============================================================================
-- Connect as: sqlplus sys/justkeepswimming@host.docker.internal:1521/XEPDB1 as sysdba

-- Switch to the correct PDB
ALTER SESSION SET CONTAINER = XEPDB1;

SET SERVEROUTPUT ON

-- First, let's check what ACLs exist
PROMPT ===============================================================================
PROMPT Checking existing ACLs...
PROMPT ===============================================================================

SELECT acl, principal, privilege, is_grant
FROM dba_network_acl_privileges
WHERE principal IN ('TR2000_STAGING', 'APEX_240200')
ORDER BY principal, acl;

-- Check host assignments
SELECT acl, host, lower_port, upper_port
FROM dba_network_acls
ORDER BY host;

PROMPT ===============================================================================
PROMPT Creating comprehensive Network ACL for TR2000_STAGING and APEX
PROMPT ===============================================================================

BEGIN
    -- First, drop any existing ACL for our hosts to start fresh
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.DROP_ACL(
            acl => 'tr2000_acl.xml'
        );
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -31001 THEN -- ACL does not exist
                RAISE;
            END IF;
    END;
    
    -- Create new ACL
    DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(
        acl => 'tr2000_acl.xml',
        description => 'ACL for TR2000 ETL API access',
        principal => 'TR2000_STAGING',
        is_grant => TRUE,
        privilege => 'connect'
    );
    
    -- Add resolve privilege for TR2000_STAGING
    DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(
        acl => 'tr2000_acl.xml',
        principal => 'TR2000_STAGING',
        is_grant => TRUE,
        privilege => 'resolve'
    );
    
    -- Also grant to APEX schema (APEX_240200 based on your version)
    DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(
        acl => 'tr2000_acl.xml',
        principal => 'APEX_240200',
        is_grant => TRUE,
        privilege => 'connect'
    );
    
    DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(
        acl => 'tr2000_acl.xml',
        principal => 'APEX_240200',
        is_grant => TRUE,
        privilege => 'resolve'
    );
    
    -- Assign ACL to ALL hosts (for testing - can be restricted later)
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'tr2000_acl.xml',
        host => '*',
        lower_port => 1,
        upper_port => 65535
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Network ACL created successfully for ALL hosts');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error creating ACL: ' || SQLERRM);
        RAISE;
END;
/

-- Alternative approach using the newer syntax (12c+)
BEGIN
    -- Grant connect and resolve to TR2000_STAGING for all hosts
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => 'TR2000_STAGING',
            principal_type => xs_acl.ptype_db
        )
    );
    
    -- Grant same to APEX schema
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => 'APEX_240200',
            principal_type => xs_acl.ptype_db
        )
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('ACL privileges granted using new syntax');
    
EXCEPTION
    WHEN OTHERS THEN
        -- If new syntax fails, that's OK - old syntax should work
        DBMS_OUTPUT.PUT_LINE('New syntax not supported or failed: ' || SQLERRM);
END;
/

PROMPT ===============================================================================
PROMPT Verifying ACL configuration...
PROMPT ===============================================================================

-- Check the privileges again
SELECT 'Principal: ' || principal || ', ACL: ' || acl || ', Privilege: ' || privilege AS acl_info
FROM dba_network_acl_privileges
WHERE principal IN ('TR2000_STAGING', 'APEX_240200')
ORDER BY principal;

-- Check host assignments
SELECT 'ACL: ' || acl || ', Host: ' || host || ', Ports: ' || lower_port || '-' || upper_port AS host_info
FROM dba_network_acls
WHERE acl = 'tr2000_acl.xml'
   OR host = '*';

PROMPT ===============================================================================
PROMPT Testing connectivity for TR2000_STAGING user...
PROMPT ===============================================================================

-- Test as TR2000_STAGING
CONNECT TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1

SET SERVEROUTPUT ON

-- Test 1: Can we resolve a hostname?
DECLARE
    v_ip VARCHAR2(100);
BEGIN
    v_ip := UTL_INADDR.GET_HOST_ADDRESS('www.google.com');
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Can resolve hostnames. Google.com = ' || v_ip);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FAILED: Cannot resolve hostnames - ' || SQLERRM);
END;
/

-- Test 2: Simple HTTP request
DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    DBMS_OUTPUT.PUT_LINE('SUCCESS: HTTP request works! Response length: ' || LENGTH(v_response));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FAILED: HTTP request - ' || SQLERRM);
END;
/

-- Test 3: HTTPS request to public API
DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://jsonplaceholder.typicode.com/posts/1',
        p_http_method => 'GET'
    );
    DBMS_OUTPUT.PUT_LINE('SUCCESS: HTTPS to public API works! Response length: ' || LENGTH(v_response));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FAILED: HTTPS public API - ' || SQLERRM);
END;
/

PROMPT ===============================================================================
PROMPT ACL configuration complete. 
PROMPT If tests above passed, try the basic_apex_test.sql script again.
PROMPT If HTTPS still fails, it's a wallet/certificate issue, not ACL.
PROMPT ===============================================================================