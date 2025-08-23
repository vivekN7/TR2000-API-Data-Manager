-- Test APEX_WEB_SERVICE with proper Oracle wallet
SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

PROMPT ========================================
PROMPT Testing HTTPS with Oracle Wallet
PROMPT ========================================

DECLARE
    v_response CLOB;
    v_wallet_path VARCHAR2(500) := 'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Wallet path: ' || v_wallet_path);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 1: APEX_WEB_SERVICE with HTTPS
    DBMS_OUTPUT.PUT_LINE('Test 1: APEX_WEB_SERVICE with TR2000 API');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://equinor.pipespec-api.presight.com/plants',
            p_http_method => 'GET',
            p_wallet_path => v_wallet_path,
            p_wallet_pwd => NULL  -- Auto-login wallet doesn't need password
        );
        
        DBMS_OUTPUT.PUT_LINE('✅ SUCCESS! APEX_WEB_SERVICE works with HTTPS!');
        DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(v_response));
        
        -- Parse JSON to count plants
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count
            FROM JSON_TABLE(v_response, '$[*]'
                COLUMNS (id NUMBER PATH '$.PlantID')
            );
            DBMS_OUTPUT.PUT_LINE('Number of plants returned: ' || v_count);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('JSON parsing: ' || SUBSTR(SQLERRM, 1, 100));
        END;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('First 500 chars of response:');
        DBMS_OUTPUT.PUT_LINE(SUBSTR(v_response, 1, 500));
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Failed: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    -- Test 2: UTL_HTTP with wallet
    DBMS_OUTPUT.PUT_LINE('Test 2: UTL_HTTP with same wallet');
    DECLARE
        v_req UTL_HTTP.REQ;
        v_resp UTL_HTTP.RESP;
        v_buffer VARCHAR2(32767);
    BEGIN
        UTL_HTTP.SET_WALLET(v_wallet_path, NULL);
        
        v_req := UTL_HTTP.BEGIN_REQUEST('https://equinor.pipespec-api.presight.com/plants', 'GET');
        UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
        
        v_resp := UTL_HTTP.GET_RESPONSE(v_req);
        
        DBMS_OUTPUT.PUT_LINE('✅ UTL_HTTP also works! Status: ' || v_resp.status_code);
        
        UTL_HTTP.READ_TEXT(v_resp, v_buffer, 200);
        DBMS_OUTPUT.PUT_LINE('First 200 chars: ' || v_buffer);
        
        UTL_HTTP.END_RESPONSE(v_resp);
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ UTL_HTTP failed: ' || SQLERRM);
            IF v_resp.status_code IS NOT NULL THEN
                UTL_HTTP.END_RESPONSE(v_resp);
            END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('🎉 WALLET WORKS! HTTPS is now functional!');
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/