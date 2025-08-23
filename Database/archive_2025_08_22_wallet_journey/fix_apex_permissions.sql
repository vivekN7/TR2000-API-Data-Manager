-- Fix APEX permissions for TR2000_STAGING user
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ========================================
PROMPT Fixing APEX Permissions
PROMPT ========================================

-- Switch to PDB
ALTER SESSION SET CONTAINER = XEPDB1;

-- Check current grants
PROMPT Current APEX grants to TR2000_STAGING:
SELECT privilege, table_name 
FROM dba_tab_privs 
WHERE grantee = 'TR2000_STAGING' 
AND owner LIKE 'APEX%'
AND ROWNUM <= 20;

-- Grant necessary APEX privileges
PROMPT
PROMPT Granting APEX_WEB_SERVICE access...
BEGIN
    -- Grant execute on APEX packages
    EXECUTE IMMEDIATE 'GRANT EXECUTE ON APEX_240200.WWV_FLOW_WEBSERVICES_API TO TR2000_STAGING';
    DBMS_OUTPUT.PUT_LINE('✓ Granted EXECUTE on WWV_FLOW_WEBSERVICES_API');
    
    EXECUTE IMMEDIATE 'GRANT EXECUTE ON APEX_240200.WWV_FLOW_INSTANCE_ADMIN TO TR2000_STAGING';
    DBMS_OUTPUT.PUT_LINE('✓ Granted EXECUTE on WWV_FLOW_INSTANCE_ADMIN');
    
    -- Grant select on instance parameters
    EXECUTE IMMEDIATE 'GRANT SELECT ON APEX_240200.WWV_FLOW_PLATFORM_PREFS TO TR2000_STAGING';
    DBMS_OUTPUT.PUT_LINE('✓ Granted SELECT on WWV_FLOW_PLATFORM_PREFS');
    
    -- Grant APEX_ADMINISTRATOR_ROLE for full access (if needed)
    -- EXECUTE IMMEDIATE 'GRANT APEX_ADMINISTRATOR_ROLE TO TR2000_STAGING';
    -- DBMS_OUTPUT.PUT_LINE('✓ Granted APEX_ADMINISTRATOR_ROLE');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- Check if instance parameters are properly set
PROMPT
PROMPT Checking instance parameters:
SELECT name, value 
FROM APEX_240200.WWV_FLOW_PLATFORM_PREFS
WHERE name IN ('ALLOW_PUBLIC_WEBSERVICES', 'RESTful_SERVICES_ENABLED');

-- If missing, insert them
PROMPT
PROMPT Setting instance parameters if needed...
DECLARE
    v_count NUMBER;
BEGIN
    -- Check if ALLOW_PUBLIC_WEBSERVICES exists
    SELECT COUNT(*) INTO v_count
    FROM APEX_240200.WWV_FLOW_PLATFORM_PREFS
    WHERE name = 'ALLOW_PUBLIC_WEBSERVICES';
    
    IF v_count = 0 THEN
        INSERT INTO APEX_240200.WWV_FLOW_PLATFORM_PREFS (name, value)
        VALUES ('ALLOW_PUBLIC_WEBSERVICES', 'Y');
        DBMS_OUTPUT.PUT_LINE('✓ Set ALLOW_PUBLIC_WEBSERVICES = Y');
    ELSE
        UPDATE APEX_240200.WWV_FLOW_PLATFORM_PREFS
        SET value = 'Y'
        WHERE name = 'ALLOW_PUBLIC_WEBSERVICES';
        DBMS_OUTPUT.PUT_LINE('✓ Updated ALLOW_PUBLIC_WEBSERVICES = Y');
    END IF;
    
    -- Check if RESTful_SERVICES_ENABLED exists
    SELECT COUNT(*) INTO v_count
    FROM APEX_240200.WWV_FLOW_PLATFORM_PREFS
    WHERE name = 'RESTful_SERVICES_ENABLED';
    
    IF v_count = 0 THEN
        INSERT INTO APEX_240200.WWV_FLOW_PLATFORM_PREFS (name, value)
        VALUES ('RESTful_SERVICES_ENABLED', 'Y');
        DBMS_OUTPUT.PUT_LINE('✓ Set RESTful_SERVICES_ENABLED = Y');
    ELSE
        UPDATE APEX_240200.WWV_FLOW_PLATFORM_PREFS
        SET value = 'Y'
        WHERE name = 'RESTful_SERVICES_ENABLED';
        DBMS_OUTPUT.PUT_LINE('✓ Updated RESTful_SERVICES_ENABLED = Y');
    END IF;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ Changes committed');
END;
/

-- Create Network ACLs if missing
PROMPT
PROMPT Checking Network ACLs...
DECLARE
    v_count NUMBER;
BEGIN
    -- Check for existing ACL
    SELECT COUNT(*) INTO v_count
    FROM dba_network_acls
    WHERE principal = 'TR2000_STAGING'
    AND host = 'httpbin.org';
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Creating ACL for httpbin.org...');
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host => 'httpbin.org',
            ace => xs$ace_type(
                privilege_list => xs$name_list('http', 'connect', 'resolve'),
                principal_name => 'TR2000_STAGING',
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('✓ ACL created for httpbin.org');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ ACL already exists for httpbin.org');
    END IF;
    
    -- Check for jsonplaceholder
    SELECT COUNT(*) INTO v_count
    FROM dba_network_acls
    WHERE principal = 'TR2000_STAGING'
    AND host = 'jsonplaceholder.typicode.com';
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Creating ACL for jsonplaceholder.typicode.com...');
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host => 'jsonplaceholder.typicode.com',
            ace => xs$ace_type(
                privilege_list => xs$name_list('http', 'connect', 'resolve'),
                principal_name => 'TR2000_STAGING',
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('✓ ACL created for jsonplaceholder.typicode.com');
    END IF;
    
    -- Add ACL for TR2000 API
    SELECT COUNT(*) INTO v_count
    FROM dba_network_acls
    WHERE principal = 'TR2000_STAGING'
    AND (host = 'equinor.pipespec-api.presight.com' OR host = '*.presight.com');
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Creating ACL for TR2000 API...');
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host => '*.presight.com',
            ace => xs$ace_type(
                privilege_list => xs$name_list('http', 'connect', 'resolve'),
                principal_name => 'TR2000_STAGING',
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('✓ ACL created for *.presight.com');
    END IF;
    
    COMMIT;
END;
/

-- Verify ACLs
PROMPT
PROMPT Current Network ACLs for TR2000_STAGING:
SELECT host, ace_order, start_date, is_grant, privilege
FROM dba_host_aces
WHERE principal = 'TR2000_STAGING'
ORDER BY host;

PROMPT
PROMPT ========================================
PROMPT Permissions fix complete!
PROMPT Now test APEX_WEB_SERVICE as TR2000_STAGING
PROMPT ========================================