-- Test manually created wallet
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ========================================
PROMPT Testing Manual Wallet
PROMPT ========================================

DECLARE
    v_req UTL_HTTP.REQ;
    v_resp UTL_HTTP.RESP;
    v_buffer VARCHAR2(32767);
    v_wallet_path VARCHAR2(500) := 'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing with manual wallet: ' || v_wallet_path);
    
    -- Set wallet path
    UTL_HTTP.SET_WALLET(v_wallet_path, '');  -- Empty password
    
    -- Test HTTPS connection
    v_req := UTL_HTTP.BEGIN_REQUEST('https://equinor.pipespec-api.presight.com/plants', 'GET');
    UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
    UTL_HTTP.SET_HEADER(v_req, 'User-Agent', 'Oracle/TR2000');
    
    v_resp := UTL_HTTP.GET_RESPONSE(v_req);
    
    DBMS_OUTPUT.PUT_LINE('✅ SUCCESS! Status: ' || v_resp.status_code);
    
    UTL_HTTP.READ_TEXT(v_resp, v_buffer, 200);
    DBMS_OUTPUT.PUT_LINE('Response: ' || v_buffer);
    
    UTL_HTTP.END_RESPONSE(v_resp);
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('✅ MANUAL WALLET WORKS!');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Failed: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error code: ' || SQLCODE);
        IF v_resp.status_code IS NOT NULL THEN
            UTL_HTTP.END_RESPONSE(v_resp);
        END IF;
END;
/

-- Now test APEX_WEB_SERVICE with the wallet
PROMPT
PROMPT Testing APEX_WEB_SERVICE with manual wallet...
DECLARE
    v_response CLOB;
    v_wallet_path VARCHAR2(500) := 'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet';
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',
        p_http_method => 'GET',
        p_wallet_path => v_wallet_path,
        p_wallet_pwd => ''
    );
    
    DBMS_OUTPUT.PUT_LINE('✅ APEX_WEB_SERVICE SUCCESS!');
    DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(v_response));
    DBMS_OUTPUT.PUT_LINE('First 200 chars: ' || SUBSTR(v_response, 1, 200));
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ APEX_WEB_SERVICE failed: ' || SQLERRM);
END;
/

PROMPT ========================================
PROMPT Test complete
PROMPT ========================================