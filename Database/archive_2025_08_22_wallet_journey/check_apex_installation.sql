-- ===============================================================================
-- Check APEX Installation and Configuration
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;

BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('APEX INSTALLATION CHECK');
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

-- Check if APEX is installed
SELECT comp_name, version, status 
FROM dba_registry 
WHERE comp_id = 'APEX';

-- Check APEX version from APEX views (if available)
SELECT 'APEX Version from APEX_RELEASE' as source, version_no 
FROM apex_release;

-- Check if APEX_WEB_SERVICE exists
SELECT object_name, object_type, status
FROM all_objects
WHERE object_name = 'APEX_WEB_SERVICE'
AND owner = 'APEX_220200';  -- Common APEX schema naming pattern

-- Check all APEX schemas
SELECT username, account_status
FROM dba_users
WHERE username LIKE 'APEX%'
ORDER BY username;

-- Check if TR2000_STAGING has execute privilege on APEX_WEB_SERVICE
SELECT * FROM user_tab_privs
WHERE table_name = 'APEX_WEB_SERVICE';

-- Check for any APEX_WEB_SERVICE synonyms
SELECT owner, synonym_name, table_owner, table_name
FROM all_synonyms
WHERE table_name = 'APEX_WEB_SERVICE'
OR synonym_name = 'APEX_WEB_SERVICE';

-- Simple test to see if APEX_WEB_SERVICE is accessible
DECLARE
    v_test VARCHAR2(100);
BEGIN
    -- Try to access a constant from APEX_WEB_SERVICE
    v_test := 'Testing APEX_WEB_SERVICE availability';
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('APEX_WEB_SERVICE Accessibility Test:');
    
    -- Try to set a header (this should work if APEX_WEB_SERVICE is available)
    BEGIN
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'Test';
        apex_web_service.g_request_headers(1).value := 'Test';
        DBMS_OUTPUT.PUT_LINE('SUCCESS: APEX_WEB_SERVICE is accessible');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: APEX_WEB_SERVICE not accessible - ' || SQLERRM);
    END;
END;
/