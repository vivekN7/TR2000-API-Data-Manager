-- Test with wallet password
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    v_response CLOB;
    v_wallet_path VARCHAR2(500) := 'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing with wallet password...');
    
    -- Test with password
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',
        p_http_method => 'GET',
        p_wallet_path => v_wallet_path,
        p_wallet_pwd => 'WalletPass123'
    );
    
    DBMS_OUTPUT.PUT_LINE('✅ SUCCESS!');
    DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(v_response));
    DBMS_OUTPUT.PUT_LINE('First 300 chars: ' || SUBSTR(v_response, 1, 300));
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Failed with password: ' || SQLERRM);
        
        -- Try UTL_HTTP
        DECLARE
            v_req UTL_HTTP.REQ;
            v_resp UTL_HTTP.RESP;
            v_buffer VARCHAR2(4000);
        BEGIN
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Trying UTL_HTTP with password...');
            
            UTL_HTTP.SET_WALLET(v_wallet_path, 'WalletPass123');
            
            v_req := UTL_HTTP.BEGIN_REQUEST('https://equinor.pipespec-api.presight.com/plants', 'GET');
            UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
            UTL_HTTP.SET_HEADER(v_req, 'User-Agent', 'Oracle/TR2000');
            
            v_resp := UTL_HTTP.GET_RESPONSE(v_req);
            
            DBMS_OUTPUT.PUT_LINE('✅ UTL_HTTP SUCCESS! Status: ' || v_resp.status_code);
            
            UTL_HTTP.READ_TEXT(v_resp, v_buffer, 300);
            DBMS_OUTPUT.PUT_LINE('Response: ' || v_buffer);
            
            UTL_HTTP.END_RESPONSE(v_resp);
            
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('❌ UTL_HTTP also failed: ' || SQLERRM);
                IF v_resp.status_code IS NOT NULL THEN
                    UTL_HTTP.END_RESPONSE(v_resp);
                END IF;
        END;
END;
/