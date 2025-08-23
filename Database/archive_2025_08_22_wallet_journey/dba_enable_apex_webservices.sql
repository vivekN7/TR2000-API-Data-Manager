-- ===============================================================================
-- Enable APEX Web Services - CORRECTED VERSION
-- Run as SYS or user with APEX_ADMINISTRATOR_ROLE
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
COLUMN name FORMAT A40
COLUMN value FORMAT A60

-- Check current APEX instance parameters
PROMPT ========================================
PROMPT Current APEX Instance Parameters
PROMPT ========================================

SELECT name, value
FROM apex_instance_parameters
WHERE name IN (
    'WALLET_PATH',
    'WALLET_PWD', 
    'HTTP_PROXY',
    'HTTPS_PROXY',
    'NO_PROXY',
    'ALLOW_PUBLIC_WEBSERVICES',
    'WEBSERVICE_LOGGING'
)
ORDER BY name;

-- Check if web services are disabled
PROMPT
PROMPT ========================================
PROMPT Checking Web Service Configuration
PROMPT ========================================

DECLARE
    v_value VARCHAR2(100);
    v_found BOOLEAN := FALSE;
BEGIN
    -- Check if public web services are allowed
    BEGIN
        SELECT value INTO v_value
        FROM apex_instance_parameters
        WHERE name = 'ALLOW_PUBLIC_WEBSERVICES';
        
        v_found := TRUE;
        
        DBMS_OUTPUT.PUT_LINE('ALLOW_PUBLIC_WEBSERVICES = ' || v_value);
        
        IF v_value = 'N' OR v_value IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('⚠️  WARNING: Web services are DISABLED!');
            DBMS_OUTPUT.PUT_LINE('This is why APEX_WEB_SERVICE fails.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✓ Web services are ENABLED');
        END IF;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ALLOW_PUBLIC_WEBSERVICES parameter not found');
            DBMS_OUTPUT.PUT_LINE('This means web services are DISABLED by default');
    END;
    
    IF NOT v_found OR v_value != 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('TO ENABLE: Run the following as ADMIN user:');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('BEGIN');
        DBMS_OUTPUT.PUT_LINE('    APEX_INSTANCE_ADMIN.SET_PARAMETER(');
        DBMS_OUTPUT.PUT_LINE('        p_parameter => ''ALLOW_PUBLIC_WEBSERVICES'',');
        DBMS_OUTPUT.PUT_LINE('        p_value => ''Y''');
        DBMS_OUTPUT.PUT_LINE('    );');
        DBMS_OUTPUT.PUT_LINE('    COMMIT;');
        DBMS_OUTPUT.PUT_LINE('END;');
        DBMS_OUTPUT.PUT_LINE('/');
    END IF;
END;
/

-- Try to enable if we have privileges
PROMPT
PROMPT ========================================
PROMPT Attempting to Enable Web Services
PROMPT ========================================

BEGIN
    -- This requires APEX Administrator privileges
    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'ALLOW_PUBLIC_WEBSERVICES',
        p_value => 'Y'
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ SUCCESS: Web services have been ENABLED!');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Cannot enable: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('You need to:');
        DBMS_OUTPUT.PUT_LINE('1. Login to APEX as ADMIN user');
        DBMS_OUTPUT.PUT_LINE('2. Go to SQL Workshop > SQL Commands');
        DBMS_OUTPUT.PUT_LINE('3. Run the APEX_INSTANCE_ADMIN.SET_PARAMETER command shown above');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('OR grant APEX_ADMINISTRATOR_ROLE to your DBA user:');
        DBMS_OUTPUT.PUT_LINE('GRANT APEX_ADMINISTRATOR_ROLE TO your_dba_user;');
END;
/

-- Test if it works now
PROMPT
PROMPT ========================================
PROMPT Testing Web Service
PROMPT ========================================

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
        DBMS_OUTPUT.PUT_LINE('✗ Still not working: ' || SQLERRM);
END;
/