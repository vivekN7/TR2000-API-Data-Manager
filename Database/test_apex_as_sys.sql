-- Test APEX HTTPS as SYS user
-- Switch to TR2000_STAGING context for testing

SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT Switching to TR2000_STAGING schema context...
ALTER SESSION SET CURRENT_SCHEMA = TR2000_STAGING;

DECLARE
    v_response CLOB;
    v_url VARCHAR2(1000);
    c_wallet_path CONSTANT VARCHAR2(100) := 'file:C:\Oracle\wallet';
    c_wallet_pwd CONSTANT VARCHAR2(100) := 'WalletPass123';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing APEX HTTPS with wallet...');
    DBMS_OUTPUT.PUT_LINE('Wallet Path: ' || c_wallet_path);
    
    -- Test TR2000 API
    v_url := 'https://equinor.pipespec-api.presight.com/plants';
    DBMS_OUTPUT.PUT_LINE('URL: ' || v_url);
    
    v_response := apex_web_service.make_rest_request(
        p_url => v_url,
        p_http_method => 'GET',
        p_wallet_path => c_wallet_path,
        p_wallet_pwd => c_wallet_pwd
    );
    
    DBMS_OUTPUT.PUT_LINE('✅ SUCCESS! APEX HTTPS works!');
    DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(v_response));
    DBMS_OUTPUT.PUT_LINE('First 100 chars: ' || SUBSTR(v_response, 1, 100));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ FAILED: ' || SQLERRM);
END;
/

EXIT;