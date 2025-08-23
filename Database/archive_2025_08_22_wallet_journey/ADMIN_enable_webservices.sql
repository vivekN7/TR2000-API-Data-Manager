-- ===============================================================================
-- ADMIN Script: Enable APEX Web Services
-- 
-- HOW TO RUN THIS:
-- ----------------
-- Option 1: From APEX Web Interface (Easiest)
--   1. Login to APEX at: http://localhost:8080/apex (or your APEX URL)
--   2. Workspace: INTERNAL
--   3. Username: ADMIN
--   4. Go to: SQL Workshop > SQL Commands
--   5. Paste and run this script
--
-- Option 2: From SQL*Plus as SYS
--   1. Connect as SYSDBA
--   2. Run this script
--
-- ===============================================================================

-- First, check current status
SELECT name, value 
FROM apex_instance_parameters 
WHERE name = 'ALLOW_PUBLIC_WEBSERVICES';

-- Enable public web services
BEGIN
    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'ALLOW_PUBLIC_WEBSERVICES',
        p_value => 'Y'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ Web services ENABLED successfully!');
END;
/

-- Verify the change
SELECT name, value 
FROM apex_instance_parameters 
WHERE name = 'ALLOW_PUBLIC_WEBSERVICES';

-- Optional: Enable logging for debugging
BEGIN
    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'WEBSERVICE_LOGGING',
        p_value => 'Y'
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ Web service logging ENABLED!');
END;
/

-- Test that it works
DECLARE
    v_response CLOB;
BEGIN
    apex_web_service.g_request_headers.DELETE;
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    DBMS_OUTPUT.PUT_LINE('✓ SUCCESS! Web services are working!');
    DBMS_OUTPUT.PUT_LINE('HTTP Status: ' || apex_web_service.g_status_code);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

PROMPT
PROMPT ========================================
PROMPT Configuration Complete!
PROMPT Web services should now work for all users.
PROMPT ========================================