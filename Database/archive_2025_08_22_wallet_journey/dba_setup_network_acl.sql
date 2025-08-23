-- ===============================================================================
-- DBA Script: Setup Network ACL for APEX_WEB_SERVICE
-- MUST BE RUN AS SYS OR DBA USER
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Setting up Network ACL for TR2000_STAGING');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    -- Drop existing ACL if it exists
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.DROP_ACL(acl => 'tr2000_api_acl.xml');
        DBMS_OUTPUT.PUT_LINE('Dropped existing ACL');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('No existing ACL to drop');
    END;
    
    -- Create new ACL
    DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(
        acl => 'tr2000_api_acl.xml',
        description => 'Network ACL for TR2000 API access',
        principal => 'TR2000_STAGING',
        is_grant => TRUE,
        privilege => 'connect',
        start_date => NULL,
        end_date => NULL
    );
    DBMS_OUTPUT.PUT_LINE('Created new ACL');
    
    -- Add resolve privilege
    DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(
        acl => 'tr2000_api_acl.xml',
        principal => 'TR2000_STAGING',
        is_grant => TRUE,
        privilege => 'resolve'
    );
    DBMS_OUTPUT.PUT_LINE('Added resolve privilege');
    
    -- Assign ACL to specific hosts
    
    -- 1. Equinor API
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'tr2000_api_acl.xml',
        host => 'equinor.pipespec-api.presight.com',
        lower_port => NULL,
        upper_port => NULL
    );
    DBMS_OUTPUT.PUT_LINE('Assigned ACL to equinor.pipespec-api.presight.com');
    
    -- 2. Allow all presight.com subdomains
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'tr2000_api_acl.xml',
        host => '*.presight.com',
        lower_port => NULL,
        upper_port => NULL
    );
    DBMS_OUTPUT.PUT_LINE('Assigned ACL to *.presight.com');
    
    -- 3. For testing - httpbin.org
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'tr2000_api_acl.xml',
        host => 'httpbin.org',
        lower_port => NULL,
        upper_port => NULL
    );
    DBMS_OUTPUT.PUT_LINE('Assigned ACL to httpbin.org');
    
    -- 4. For testing - jsonplaceholder
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'tr2000_api_acl.xml',
        host => 'jsonplaceholder.typicode.com',
        lower_port => NULL,
        upper_port => NULL
    );
    DBMS_OUTPUT.PUT_LINE('Assigned ACL to jsonplaceholder.typicode.com');
    
    -- 5. GitHub API (for testing)
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'tr2000_api_acl.xml',
        host => 'api.github.com',
        lower_port => NULL,
        upper_port => NULL
    );
    DBMS_OUTPUT.PUT_LINE('Assigned ACL to api.github.com');
    
    -- If you want to allow ALL external hosts (less secure but simpler):
    -- Uncomment the following:
    /*
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'tr2000_api_acl.xml',
        host => '*',
        lower_port => NULL,
        upper_port => NULL
    );
    DBMS_OUTPUT.PUT_LINE('Assigned ACL to * (all hosts)');
    */
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Network ACL setup complete!');
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

-- Verify the ACL configuration
COLUMN host FORMAT A40
COLUMN acl FORMAT A30
COLUMN principal FORMAT A20
COLUMN privilege FORMAT A10

PROMPT
PROMPT Configured Network ACLs:
SELECT host, lower_port, upper_port, acl
FROM dba_network_acls
WHERE acl LIKE '%tr2000%'
ORDER BY host;

PROMPT
PROMPT ACL Privileges for TR2000_STAGING:
SELECT acl, principal, privilege, is_grant
FROM dba_network_acl_privileges
WHERE principal = 'TR2000_STAGING';

PROMPT
PROMPT ========================================
PROMPT Network ACL Configuration Complete
PROMPT Please test API access as TR2000_STAGING user
PROMPT ========================================