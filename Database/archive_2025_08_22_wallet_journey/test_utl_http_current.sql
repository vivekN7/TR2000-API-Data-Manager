-- Test if UTL_HTTP works with current setup
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ========================================
PROMPT Testing UTL_HTTP with HTTPS
PROMPT ========================================

DECLARE
    v_req UTL_HTTP.REQ;
    v_resp UTL_HTTP.RESP;
    v_buffer VARCHAR2(32767);
    v_response CLOB;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing UTL_HTTP with TR2000 API...');
    
    -- Initialize CLOB
    DBMS_LOB.CREATETEMPORARY(v_response, TRUE);
    
    -- Try without wallet
    UTL_HTTP.SET_WALLET(NULL);
    
    v_req := UTL_HTTP.BEGIN_REQUEST('https://equinor.pipespec-api.presight.com/api/plants', 'GET');
    UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
    UTL_HTTP.SET_HEADER(v_req, 'User-Agent', 'Oracle/TR2000');
    
    v_resp := UTL_HTTP.GET_RESPONSE(v_req);
    
    DBMS_OUTPUT.PUT_LINE('HTTP Status: ' || v_resp.status_code);
    
    BEGIN
        LOOP
            UTL_HTTP.READ_TEXT(v_resp, v_buffer, 32767);
            DBMS_LOB.WRITEAPPEND(v_response, LENGTH(v_buffer), v_buffer);
        END LOOP;
    EXCEPTION
        WHEN UTL_HTTP.END_OF_BODY THEN
            UTL_HTTP.END_RESPONSE(v_resp);
    END;
    
    DBMS_OUTPUT.PUT_LINE('✅ SUCCESS! Response length: ' || DBMS_LOB.GETLENGTH(v_response));
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Failed: ' || SQLERRM);
        IF v_resp.status_code IS NOT NULL THEN
            UTL_HTTP.END_RESPONSE(v_resp);
        END IF;
END;
/