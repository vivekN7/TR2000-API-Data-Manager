-- Test APEX_WEB_SERVICE with HTTPS using configured wallet
SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

PROMPT ========================================
PROMPT Testing APEX_WEB_SERVICE with HTTPS
PROMPT ========================================

-- Set TNS_ADMIN to point to our network/admin directory
-- This tells Oracle where to find sqlnet.ora
HOST export TNS_ADMIN=/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin

DECLARE
    v_response CLOB;
    v_wallet_path VARCHAR2(500) := 'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Test 1: HTTPS with httpbin.org');
    DBMS_OUTPUT.PUT_LINE('Using wallet: ' || v_wallet_path);
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://httpbin.org/get',
            p_http_method => 'GET',
            p_wallet_path => v_wallet_path
        );
        DBMS_OUTPUT.PUT_LINE('✅ SUCCESS! Response length: ' || LENGTH(v_response));
        DBMS_OUTPUT.PUT_LINE('First 200 chars: ' || SUBSTR(v_response, 1, 200));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Failed: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 2: HTTPS with TR2000 API (Plants)');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://equinor.pipespec-api.presight.com/api/plants',
            p_http_method => 'GET',
            p_wallet_path => v_wallet_path
        );
        DBMS_OUTPUT.PUT_LINE('✅ TR2000 API SUCCESS! Response length: ' || LENGTH(v_response));
        
        -- Parse JSON to count plants
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count
            FROM JSON_TABLE(v_response, '$[*]'
                COLUMNS (id NUMBER PATH '$.id')
            );
            DBMS_OUTPUT.PUT_LINE('Number of plants returned: ' || v_count);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('JSON parsing error (but API call worked!)');
        END;
        
        DBMS_OUTPUT.PUT_LINE('First 500 chars: ' || SUBSTR(v_response, 1, 500));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Failed: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 3: HTTPS with TR2000 API (Issues for plant 1903)');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://equinor.pipespec-api.presight.com/api/plants/1903/issues',
            p_http_method => 'GET',
            p_wallet_path => v_wallet_path
        );
        DBMS_OUTPUT.PUT_LINE('✅ Issues API SUCCESS! Response length: ' || LENGTH(v_response));
        
        -- Parse JSON to count issues
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count
            FROM JSON_TABLE(v_response, '$[*]'
                COLUMNS (issueId VARCHAR2(50) PATH '$.issueId')
            );
            DBMS_OUTPUT.PUT_LINE('Number of issues for plant 1903: ' || v_count);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('JSON parsing succeeded but count failed');
        END;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Failed: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Testing without explicit wallet path (using instance settings)');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    -- Test 4: Try without specifying wallet (should use instance settings)
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://httpbin.org/get',
            p_http_method => 'GET'
        );
        DBMS_OUTPUT.PUT_LINE('✅ Works without explicit wallet! Using instance settings.');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Needs explicit wallet path: ' || SQLERRM);
    END;
END;
/

PROMPT
PROMPT ========================================
PROMPT HTTPS test complete
PROMPT ========================================