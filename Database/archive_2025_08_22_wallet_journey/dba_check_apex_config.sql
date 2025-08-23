-- ===============================================================================
-- DBA Script: Check and Fix APEX Instance Configuration
-- Run as SYS or APEX_ADMINISTRATOR
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
COLUMN parameter FORMAT A40
COLUMN value FORMAT A60

-- Check APEX instance parameters
PROMPT ========================================
PROMPT APEX Instance Parameters
PROMPT ========================================

SELECT parameter, value
FROM apex_instance_parameters
WHERE parameter IN (
    'WALLET_PATH',
    'WALLET_PWD', 
    'HTTP_PROXY',
    'HTTPS_PROXY',
    'NO_PROXY',
    'ALLOW_PUBLIC_WEBSERVICES',
    'WEBSERVICE_LOGGING'
)
ORDER BY parameter;

-- Check if instance allows web service calls
PROMPT
PROMPT ========================================
PROMPT Checking Web Service Configuration
PROMPT ========================================

BEGIN
    -- Check if public web services are allowed
    FOR rec IN (
        SELECT parameter, value
        FROM apex_instance_parameters
        WHERE parameter = 'ALLOW_PUBLIC_WEBSERVICES'
    ) LOOP
        IF rec.value = 'N' THEN
            DBMS_OUTPUT.PUT_LINE('WARNING: ALLOW_PUBLIC_WEBSERVICES is set to N (disabled)');
            DBMS_OUTPUT.PUT_LINE('This prevents APEX_WEB_SERVICE from making external calls!');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('TO FIX: Run the following as ADMIN user in APEX:');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('BEGIN');
            DBMS_OUTPUT.PUT_LINE('    APEX_INSTANCE_ADMIN.SET_PARAMETER(');
            DBMS_OUTPUT.PUT_LINE('        p_parameter => ''ALLOW_PUBLIC_WEBSERVICES'',');
            DBMS_OUTPUT.PUT_LINE('        p_value => ''Y''');
            DBMS_OUTPUT.PUT_LINE('    );');
            DBMS_OUTPUT.PUT_LINE('    COMMIT;');
            DBMS_OUTPUT.PUT_LINE('END;');
            DBMS_OUTPUT.PUT_LINE('/');
        ELSE
            DBMS_OUTPUT.PUT_LINE('OK: ALLOW_PUBLIC_WEBSERVICES is enabled');
        END IF;
    END LOOP;
END;
/

-- Enable web services if needed
PROMPT
PROMPT ========================================
PROMPT Enabling APEX Web Services
PROMPT ========================================

BEGIN
    -- This requires APEX Administrator privileges
    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'ALLOW_PUBLIC_WEBSERVICES',
        p_value => 'Y'
    );
    
    -- Enable logging for debugging
    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'WEBSERVICE_LOGGING',
        p_value => 'Y'
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('APEX Web Services ENABLED');
    DBMS_OUTPUT.PUT_LINE('Web Service Logging ENABLED');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Note: This requires APEX Administrator privileges');
END;
/

-- Test after enabling
PROMPT
PROMPT ========================================
PROMPT Testing Web Service After Configuration
PROMPT ========================================

DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS! Web services are working');
    DBMS_OUTPUT.PUT_LINE('Status: ' || apex_web_service.g_status_code);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Still not working: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('May need to restart APEX or check wallet configuration');
END;
/