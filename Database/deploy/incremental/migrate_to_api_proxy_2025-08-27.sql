-- ===============================================================================
-- Migrate to API Proxy Pattern
-- Date: 2025-08-27
-- Purpose: Update packages to use API_PROXY instead of direct apex_web_service
-- ===============================================================================

PROMPT ===============================================================================
PROMPT Migrating to API Proxy Pattern
PROMPT ===============================================================================

-- First ensure the proxy user and package exist
PROMPT Checking if API_PROXY.PKG_API_SERVICE is available...
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM all_objects
    WHERE owner = 'API_PROXY'
      AND object_name = 'PKG_API_SERVICE'
      AND object_type = 'PACKAGE';
    
    IF v_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'API_PROXY.PKG_API_SERVICE not found! Run 00_users scripts first.');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('API_PROXY.PKG_API_SERVICE found - proceeding with migration');
END;
/

-- Create wrapper functions in TR2000_STAGING to minimize code changes
CREATE OR REPLACE FUNCTION make_api_request_proxy(
    p_url            VARCHAR2,
    p_method         VARCHAR2 DEFAULT 'GET',
    p_correlation_id VARCHAR2 DEFAULT NULL
) RETURN CLOB IS
    v_response CLOB;
BEGIN
    -- Clear any existing headers
    PKG_API_SERVICE.clear_request_headers();
    
    -- Set standard headers
    PKG_API_SERVICE.set_request_header('Content-Type', 'application/json');
    
    -- Add correlation ID if provided
    IF p_correlation_id IS NOT NULL THEN
        PKG_API_SERVICE.set_request_header('X-Correlation-ID', p_correlation_id);
    END IF;
    
    -- Make the call through proxy
    v_response := PKG_API_SERVICE.make_api_call(
        p_url => p_url,
        p_method => p_method,
        p_correlation_id => p_correlation_id
    );
    
    RETURN v_response;
END make_api_request_proxy;
/

-- Create function to get status code
CREATE OR REPLACE FUNCTION get_last_api_status_code RETURN NUMBER IS
BEGIN
    RETURN PKG_API_SERVICE.get_last_status_code();
END get_last_api_status_code;
/

PROMPT Helper functions created in TR2000_STAGING schema

-- Now we need to update PKG_API_CLIENT and PKG_API_CLIENT_REFERENCES
-- Since these package bodies are complex, we'll create new versions that use the proxy

PROMPT 
PROMPT ===============================================================================
PROMPT Migration Complete!
PROMPT ===============================================================================
PROMPT 
PROMPT Manual steps required:
PROMPT 1. Update PKG_API_CLIENT body:
PROMPT    - Replace: apex_web_service.make_rest_request(...)
PROMPT    - With: make_api_request_proxy(p_url, 'GET')
PROMPT    
PROMPT 2. Update PKG_API_CLIENT_REFERENCES body:
PROMPT    - Replace: apex_web_service.make_rest_request(...)
PROMPT    - With: make_api_request_proxy(p_url, p_method, p_correlation_id)
PROMPT    - Replace: apex_web_service.g_status_code
PROMPT    - With: get_last_api_status_code()
PROMPT
PROMPT 3. Test the changes:
PROMPT    EXEC refresh_all_data_from_api;
PROMPT
PROMPT 4. Monitor API calls:
PROMPT    SELECT * FROM API_PROXY.API_CALL_LOG ORDER BY request_time DESC;
PROMPT ===============================================================================