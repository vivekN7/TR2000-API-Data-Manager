-- ===============================================================================
-- Quick API Configuration Verification Script
-- Checks CONTROL_SETTINGS and tests basic API connectivity
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;

DECLARE
    v_api_base_url VARCHAR2(500);
    v_test_response CLOB;
    v_test_url VARCHAR2(1000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('API CONFIGURATION VERIFICATION');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    -- Check API Base URL setting
    BEGIN
        SELECT setting_value 
        INTO v_api_base_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        DBMS_OUTPUT.PUT_LINE('API Base URL: ' || v_api_base_url);
        
        -- Validate URL format
        IF v_api_base_url IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: API_BASE_URL is NULL');
        ELSIF NOT (v_api_base_url LIKE 'http://%' OR v_api_base_url LIKE 'https://%') THEN
            DBMS_OUTPUT.PUT_LINE('WARNING: API_BASE_URL does not start with http:// or https://');
        ELSE
            DBMS_OUTPUT.PUT_LINE('URL format appears valid');
        END IF;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: API_BASE_URL not found in CONTROL_SETTINGS');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('To fix, run:');
            DBMS_OUTPUT.PUT_LINE('INSERT INTO CONTROL_SETTINGS (setting_key, setting_value, description)');
            DBMS_OUTPUT.PUT_LINE('VALUES (''API_BASE_URL'', ''https://tr2000api.equinor.com/v1/'', ''Base URL for TR2000 API'');');
            RETURN;
    END;
    
    -- Check CONTROL_ENDPOINTS configuration
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Configured Endpoints:');
    FOR rec IN (SELECT endpoint_key, endpoint_url_pattern, is_active
                FROM CONTROL_ENDPOINTS
                ORDER BY endpoint_key) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD(rec.endpoint_key, 10) || 
                            ' -> ' || rec.endpoint_url_pattern || 
                            ' (Active: ' || rec.is_active || ')');
    END LOOP;
    
    -- Test basic connectivity with a simple HTTP call
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Testing API Connectivity...');
    BEGIN
        -- Build test URL for plants endpoint
        v_test_url := v_api_base_url || 'plants';
        DBMS_OUTPUT.PUT_LINE('Test URL: ' || v_test_url);
        
        -- Try to make a basic request (this will fail if APEX_WEB_SERVICE is not available)
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'Accept';
        apex_web_service.g_request_headers(1).value := 'application/json';
        
        v_test_response := apex_web_service.make_rest_request(
            p_url => v_test_url,
            p_http_method => 'GET'
        );
        
        IF apex_web_service.g_status_code = 200 THEN
            DBMS_OUTPUT.PUT_LINE('SUCCESS: API returned HTTP 200');
            DBMS_OUTPUT.PUT_LINE('Response size: ' || LENGTH(v_test_response) || ' bytes');
            
            -- Try to parse as JSON to verify it's valid
            IF v_test_response LIKE '[%' OR v_test_response LIKE '{%' THEN
                DBMS_OUTPUT.PUT_LINE('Response appears to be valid JSON');
            ELSE
                DBMS_OUTPUT.PUT_LINE('WARNING: Response may not be valid JSON');
            END IF;
        ELSE
            DBMS_OUTPUT.PUT_LINE('ERROR: API returned HTTP ' || apex_web_service.g_status_code);
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR during API call: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Possible causes:');
            DBMS_OUTPUT.PUT_LINE('1. APEX_WEB_SERVICE not available (need Oracle APEX installed)');
            DBMS_OUTPUT.PUT_LINE('2. Network connectivity issues');
            DBMS_OUTPUT.PUT_LINE('3. API endpoint not accessible');
            DBMS_OUTPUT.PUT_LINE('4. Missing privileges (GRANT EXECUTE ON APEX_WEB_SERVICE TO TR2000_STAGING)');
    END;
    
    -- Check if required privileges are granted
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Checking Privileges:');
    FOR rec IN (SELECT privilege, table_name
                FROM user_tab_privs
                WHERE table_name IN ('APEX_WEB_SERVICE', 'DBMS_CRYPTO')
                ORDER BY table_name) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || rec.privilege || ' on ' || rec.table_name);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('VERIFICATION COMPLETE');
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/