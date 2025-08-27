-- Simple HTTPS Test Script
SET SERVEROUTPUT ON

-- Test 1: Basic HTTP (no SSL)
PROMPT Testing HTTP...
DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    DBMS_OUTPUT.PUT_LINE('HTTP SUCCESS! Length: ' || LENGTH(v_response));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('HTTP FAILED: ' || SQLERRM);
END;
/

-- Test 2: HTTPS to Working API (equinor.pipespec-api.presight.com)
PROMPT Testing HTTPS to Working API...
DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',
        p_http_method => 'GET',
        p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
        p_wallet_pwd => 'WalletPass123'
    );
    DBMS_OUTPUT.PUT_LINE('HTTPS SUCCESS! Length: ' || LENGTH(v_response));
    DBMS_OUTPUT.PUT_LINE('First 200 chars: ' || SUBSTR(v_response, 1, 200));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('HTTPS FAILED: ' || SQLERRM);
END;
/

-- Test 3: Alternative API (if first one fails)
PROMPT Testing alternative API endpoint (tr2000api - requires different certs)...
DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',
        p_http_method => 'GET',
        p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
        p_wallet_pwd => 'WalletPass123'
    );
    DBMS_OUTPUT.PUT_LINE('ALT API SUCCESS! Length: ' || LENGTH(v_response));
    DBMS_OUTPUT.PUT_LINE('First 200 chars: ' || SUBSTR(v_response, 1, 200));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ALT API FAILED: ' || SQLERRM);
END;
/

EXIT;