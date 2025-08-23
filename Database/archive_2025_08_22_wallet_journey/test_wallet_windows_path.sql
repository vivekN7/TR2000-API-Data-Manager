-- Test with wallet on Windows host machine
SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

PROMPT ========================================
PROMPT Testing HTTPS with Wallet on Windows Host
PROMPT ========================================

DECLARE
    v_response CLOB;
    v_wallet_path VARCHAR2(500) := 'file:C:\Oracle\wallet';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Wallet path on Windows: ' || v_wallet_path);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 1: UTL_HTTP first
    DBMS_OUTPUT.PUT_LINE('Test 1: UTL_HTTP with Windows wallet path');
    DECLARE
        v_req UTL_HTTP.REQ;
        v_resp UTL_HTTP.RESP;
        v_buffer VARCHAR2(4000);
    BEGIN
        UTL_HTTP.SET_WALLET(v_wallet_path, 'WalletPass123');
        
        v_req := UTL_HTTP.BEGIN_REQUEST('https://equinor.pipespec-api.presight.com/plants', 'GET');
        UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
        UTL_HTTP.SET_HEADER(v_req, 'User-Agent', 'Oracle/TR2000');
        
        v_resp := UTL_HTTP.GET_RESPONSE(v_req);
        
        DBMS_OUTPUT.PUT_LINE('✅ SUCCESS! UTL_HTTP works!');
        DBMS_OUTPUT.PUT_LINE('Status: ' || v_resp.status_code);
        
        UTL_HTTP.READ_TEXT(v_resp, v_buffer, 300);
        DBMS_OUTPUT.PUT_LINE('Response: ' || v_buffer);
        
        UTL_HTTP.END_RESPONSE(v_resp);
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ UTL_HTTP failed: ' || SQLERRM);
            IF v_resp.status_code IS NOT NULL THEN
                UTL_HTTP.END_RESPONSE(v_resp);
            END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    -- Test 2: APEX_WEB_SERVICE
    DBMS_OUTPUT.PUT_LINE('Test 2: APEX_WEB_SERVICE with Windows wallet path');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://equinor.pipespec-api.presight.com/plants',
            p_http_method => 'GET',
            p_wallet_path => v_wallet_path,
            p_wallet_pwd => 'WalletPass123'
        );
        
        DBMS_OUTPUT.PUT_LINE('✅ SUCCESS! APEX_WEB_SERVICE works!');
        DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(v_response));
        
        -- Parse JSON to count plants
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count
            FROM JSON_TABLE(v_response, '$.getPlant[*]'
                COLUMNS (id NUMBER PATH '$.PlantID')
            );
            DBMS_OUTPUT.PUT_LINE('Number of plants returned: ' || v_count);
        EXCEPTION
            WHEN OTHERS THEN
                -- Try different JSON path
                BEGIN
                    SELECT COUNT(*) INTO v_count
                    FROM JSON_TABLE(v_response, '$[*]'
                        COLUMNS (id NUMBER PATH '$.PlantID')
                    );
                    DBMS_OUTPUT.PUT_LINE('Number of plants returned: ' || v_count);
                EXCEPTION
                    WHEN OTHERS THEN
                        DBMS_OUTPUT.PUT_LINE('JSON structure different than expected');
                END;
        END;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('First 500 chars of response:');
        DBMS_OUTPUT.PUT_LINE(SUBSTR(v_response, 1, 500));
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ APEX_WEB_SERVICE failed: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('🎉 Testing Complete!');
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/