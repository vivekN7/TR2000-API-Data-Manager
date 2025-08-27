-- ===============================================================================
-- Test API Proxy Setup
-- Date: 2025-08-27
-- Purpose: Verify the API proxy user is working correctly
-- ===============================================================================

-- Run this as TR2000_STAGING after setting up API_PROXY

SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ===============================================================================
PROMPT Testing API Proxy Setup
PROMPT ===============================================================================

-- Test 1: Direct call through proxy
DECLARE
    v_response CLOB;
    v_status   NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Test 1: Calling Plants API through proxy...');
    
    -- Clear headers
    PKG_API_SERVICE.clear_request_headers();
    
    -- Set headers
    PKG_API_SERVICE.set_request_header('Content-Type', 'application/json');
    
    -- Make the call
    v_response := PKG_API_SERVICE.make_api_call(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',
        p_method => 'GET'
    );
    
    v_status := PKG_API_SERVICE.get_last_status_code();
    
    DBMS_OUTPUT.PUT_LINE('  Status Code: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('  Response Length: ' || LENGTH(v_response));
    
    IF v_status = 200 THEN
        DBMS_OUTPUT.PUT_LINE('✓ Test 1 PASSED - API proxy working!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ Test 1 FAILED - Check configuration');
    END IF;
END;
/

-- Test 2: Use the wrapper function
DECLARE
    v_response CLOB;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 2: Using wrapper function...');
    
    v_response := make_api_request_proxy(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',
        p_method => 'GET',
        p_correlation_id => 'TEST-' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDD-HH24MISS')
    );
    
    DBMS_OUTPUT.PUT_LINE('  Response Length: ' || LENGTH(v_response));
    DBMS_OUTPUT.PUT_LINE('✓ Test 2 PASSED - Wrapper function working!');
END;
/

-- Test 3: Check API call logs
PROMPT
PROMPT Test 3: Checking API call logs...
SELECT 
    calling_user,
    SUBSTR(url, 1, 50) as url_start,
    method,
    status_code,
    elapsed_ms,
    TO_CHAR(request_time, 'HH24:MI:SS') as time
FROM API_PROXY.API_CALL_LOG
WHERE request_time > SYSTIMESTAMP - INTERVAL '5' MINUTE
ORDER BY request_time DESC;

-- Test 4: Get statistics
DECLARE
    v_stats VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 4: API Call Statistics...');
    v_stats := PKG_API_SERVICE.get_call_stats(1);
    DBMS_OUTPUT.PUT_LINE('  ' || v_stats);
END;
/

PROMPT
PROMPT ===============================================================================
PROMPT Test Complete!
PROMPT ===============================================================================
PROMPT 
PROMPT If all tests passed:
PROMPT   1. Update PKG_API_CLIENT to use make_api_request_proxy()
PROMPT   2. Update PKG_API_CLIENT_REFERENCES to use make_api_request_proxy()
PROMPT   3. Your DBA can now revoke ACL rights from TR2000_STAGING
PROMPT   4. Only API_PROXY user needs network ACL privileges
PROMPT ===============================================================================