-- Test APEX_WEB_SERVICE with HTTPS without wallet validation
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ========================================
PROMPT Testing APEX HTTPS without wallet
PROMPT ========================================

DECLARE
    v_response CLOB;
BEGIN
    -- Test 1: Try with p_wallet_path => NULL
    DBMS_OUTPUT.PUT_LINE('Test 1: APEX_WEB_SERVICE with p_wallet_path => NULL');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://httpbin.org/get',
            p_http_method => 'GET',
            p_wallet_path => NULL,
            p_wallet_pwd => NULL
        );
        DBMS_OUTPUT.PUT_LINE('✅ SUCCESS with NULL wallet! Length: ' || LENGTH(v_response));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Failed: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 2: Try TR2000 API with NULL wallet
    DBMS_OUTPUT.PUT_LINE('Test 2: TR2000 API with p_wallet_path => NULL');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://equinor.pipespec-api.presight.com/api/plants',
            p_http_method => 'GET',
            p_wallet_path => NULL,
            p_wallet_pwd => NULL
        );
        DBMS_OUTPUT.PUT_LINE('✅ TR2000 API SUCCESS! Length: ' || LENGTH(v_response));
        -- Show first part of response
        DBMS_OUTPUT.PUT_LINE('First 500 chars:');
        DBMS_OUTPUT.PUT_LINE(SUBSTR(v_response, 1, 500));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Failed: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 3: Try a specific plant's issues
    DBMS_OUTPUT.PUT_LINE('Test 3: Get issues for plant 1903');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://equinor.pipespec-api.presight.com/api/plants/1903/issues',
            p_http_method => 'GET',
            p_wallet_path => NULL,
            p_wallet_pwd => NULL
        );
        DBMS_OUTPUT.PUT_LINE('✅ Issues API SUCCESS! Length: ' || LENGTH(v_response));
        -- Count issues
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count
            FROM JSON_TABLE(v_response, '$[*]'
                COLUMNS (dummy VARCHAR2(1) PATH '$.id')
            );
            DBMS_OUTPUT.PUT_LINE('Number of issues found: ' || v_count);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Could not parse JSON');
        END;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Failed: ' || SQLERRM);
    END;
END;
/

PROMPT
PROMPT ========================================
PROMPT HTTPS test complete
PROMPT ========================================