-- Test APEX_WEB_SERVICE after permission fixes
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ========================================
PROMPT Testing APEX_WEB_SERVICE After Fixes
PROMPT ========================================

DECLARE
    v_response CLOB;
    v_status VARCHAR2(100);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Test 1: Simple HTTP request to httpbin.org');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'http://httpbin.org/get',
            p_http_method => 'GET'
        );
        DBMS_OUTPUT.PUT_LINE('✅ SUCCESS! Response length: ' || LENGTH(v_response));
        DBMS_OUTPUT.PUT_LINE('First 200 chars: ' || SUBSTR(v_response, 1, 200));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ FAILED: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 2: HTTPS request (requires wallet)');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://httpbin.org/get',
            p_http_method => 'GET'
        );
        DBMS_OUTPUT.PUT_LINE('✅ HTTPS SUCCESS! Response length: ' || LENGTH(v_response));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ HTTPS FAILED: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('   (This is expected if wallet not configured)');
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 3: TR2000 API endpoint (HTTPS)');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://equinor.pipespec-api.presight.com/api/plants',
            p_http_method => 'GET'
        );
        DBMS_OUTPUT.PUT_LINE('✅ TR2000 API SUCCESS! Response length: ' || LENGTH(v_response));
        -- Show first plant
        IF v_response IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('First 300 chars: ' || SUBSTR(v_response, 1, 300));
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ TR2000 API FAILED: ' || SQLERRM);
    END;
END;
/

PROMPT
PROMPT ========================================
PROMPT Test Complete
PROMPT ========================================