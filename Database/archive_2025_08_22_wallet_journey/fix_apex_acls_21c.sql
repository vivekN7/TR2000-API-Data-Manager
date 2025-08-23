-- Fix Network ACLs for Oracle 21c
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ========================================
PROMPT Setting up Network ACLs for APEX
PROMPT ========================================

-- Switch to PDB
ALTER SESSION SET CONTAINER = XEPDB1;

-- Create ACLs using 21c syntax
BEGIN
    DBMS_OUTPUT.PUT_LINE('Creating Network ACLs for TR2000_STAGING...');
    
    -- httpbin.org
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host => 'httpbin.org',
            ace => xs$ace_type(
                privilege_list => xs$name_list('http', 'connect', 'resolve'),
                principal_name => 'TR2000_STAGING',
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('✓ ACL created for httpbin.org');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -24247 THEN
                DBMS_OUTPUT.PUT_LINE('✓ ACL already exists for httpbin.org');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Error for httpbin.org: ' || SQLERRM);
            END IF;
    END;
    
    -- jsonplaceholder.typicode.com
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host => 'jsonplaceholder.typicode.com',
            ace => xs$ace_type(
                privilege_list => xs$name_list('http', 'connect', 'resolve'),
                principal_name => 'TR2000_STAGING',
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('✓ ACL created for jsonplaceholder.typicode.com');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -24247 THEN
                DBMS_OUTPUT.PUT_LINE('✓ ACL already exists for jsonplaceholder.typicode.com');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Error for jsonplaceholder: ' || SQLERRM);
            END IF;
    END;
    
    -- *.presight.com (for TR2000 API)
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host => '*.presight.com',
            ace => xs$ace_type(
                privilege_list => xs$name_list('http', 'connect', 'resolve'),
                principal_name => 'TR2000_STAGING',
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('✓ ACL created for *.presight.com');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -24247 THEN
                DBMS_OUTPUT.PUT_LINE('✓ ACL already exists for *.presight.com');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Error for presight.com: ' || SQLERRM);
            END IF;
    END;
    
    -- Also grant to APEX schema itself
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host => '*',
            ace => xs$ace_type(
                privilege_list => xs$name_list('http', 'connect', 'resolve'),
                principal_name => 'APEX_240200',
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('✓ ACL created for APEX_240200 (all hosts)');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -24247 THEN
                DBMS_OUTPUT.PUT_LINE('✓ ACL already exists for APEX_240200');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Error for APEX_240200: ' || SQLERRM);
            END IF;
    END;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ All ACLs committed');
END;
/

-- Check ACLs
PROMPT
PROMPT Current Network ACLs:
COL host FORMAT A40
COL principal FORMAT A20
COL privilege FORMAT A10
SELECT host, principal, privilege, ace_order
FROM dba_host_aces
WHERE principal IN ('TR2000_STAGING', 'APEX_240200')
ORDER BY principal, host;

PROMPT
PROMPT ========================================
PROMPT ACL setup complete!
PROMPT ========================================