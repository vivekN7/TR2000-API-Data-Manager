-- ===============================================================================
-- Test API with SSL Bypass (Development Only)
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- First, check if we can use HTTP instead of HTTPS
DECLARE
    v_response CLOB;
    v_api_url VARCHAR2(500);
    v_status_code NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Testing API Access Options');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    -- Test 1: Try HTTP (non-SSL)
    DBMS_OUTPUT.PUT_LINE('Test 1: Trying HTTP (non-SSL)...');
    BEGIN
        v_api_url := 'http://equinor.pipespec-api.presight.com/plants';
        
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'Accept';
        apex_web_service.g_request_headers(1).value := 'application/json';
        
        v_response := apex_web_service.make_rest_request(
            p_url => v_api_url,
            p_http_method => 'GET'
        );
        
        v_status_code := apex_web_service.g_status_code;
        DBMS_OUTPUT.PUT_LINE('HTTP Status: ' || v_status_code);
        
        IF v_status_code = 200 THEN
            DBMS_OUTPUT.PUT_LINE('SUCCESS with HTTP!');
            DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(v_response));
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('HTTP failed: ' || SQLERRM);
    END;
    
    -- Test 2: Try with empty wallet path (sometimes works)
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 2: Trying HTTPS with empty wallet...');
    BEGIN
        v_api_url := 'https://equinor.pipespec-api.presight.com/plants';
        
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'Accept';
        apex_web_service.g_request_headers(1).value := 'application/json';
        
        v_response := apex_web_service.make_rest_request(
            p_url => v_api_url,
            p_http_method => 'GET',
            p_wallet_path => ''  -- Empty wallet path
        );
        
        v_status_code := apex_web_service.g_status_code;
        DBMS_OUTPUT.PUT_LINE('HTTPS Status: ' || v_status_code);
        
        IF v_status_code = 200 THEN
            DBMS_OUTPUT.PUT_LINE('SUCCESS with HTTPS (no wallet)!');
            DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(v_response));
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('HTTPS failed: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    -- Show current wallet location if set
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Checking for existing wallet configuration...');
    DECLARE
        v_wallet_path VARCHAR2(500);
    BEGIN
        -- Check if there's a default wallet configured
        SELECT value INTO v_wallet_path
        FROM v$parameter
        WHERE name = 'wallet_location';
        DBMS_OUTPUT.PUT_LINE('Wallet location: ' || v_wallet_path);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No wallet location configured');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Cannot check wallet: ' || SQLERRM);
    END;
END;
/

-- Alternative: Create a wrapper function that handles the SSL issue
CREATE OR REPLACE FUNCTION fetch_api_data(p_endpoint VARCHAR2) RETURN CLOB AS
    v_response CLOB;
    v_url VARCHAR2(500);
BEGIN
    -- Get base URL
    SELECT setting_value || p_endpoint INTO v_url
    FROM CONTROL_SETTINGS
    WHERE setting_key = 'API_BASE_URL';
    
    -- Try HTTP first (for testing)
    v_url := REPLACE(v_url, 'https://', 'http://');
    
    apex_web_service.g_request_headers.DELETE;
    apex_web_service.g_request_headers(1).name := 'Accept';
    apex_web_service.g_request_headers(1).value := 'application/json';
    
    v_response := apex_web_service.make_rest_request(
        p_url => v_url,
        p_http_method => 'GET'
    );
    
    RETURN v_response;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return null
        DBMS_OUTPUT.PUT_LINE('API Error: ' || SQLERRM);
        RETURN NULL;
END;
/