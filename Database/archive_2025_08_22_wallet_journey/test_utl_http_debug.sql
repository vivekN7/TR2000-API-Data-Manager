-- Debug UTL_HTTP issue
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    v_req UTL_HTTP.REQ;
    v_resp UTL_HTTP.RESP;
    v_buffer VARCHAR2(32767);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing UTL_HTTP with correct URL...');
    
    -- Enable detailed error reporting
    UTL_HTTP.SET_DETAILED_EXCP_SUPPORT(TRUE);
    
    -- Try to make request
    v_req := UTL_HTTP.BEGIN_REQUEST('https://equinor.pipespec-api.presight.com/plants', 'GET');
    UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
    UTL_HTTP.SET_HEADER(v_req, 'User-Agent', 'Oracle/TR2000');
    
    v_resp := UTL_HTTP.GET_RESPONSE(v_req);
    
    DBMS_OUTPUT.PUT_LINE('Status: ' || v_resp.status_code);
    
    UTL_HTTP.READ_TEXT(v_resp, v_buffer, 100);
    DBMS_OUTPUT.PUT_LINE('Response: ' || v_buffer);
    
    UTL_HTTP.END_RESPONSE(v_resp);
    DBMS_OUTPUT.PUT_LINE('SUCCESS!');
    
EXCEPTION
    WHEN UTL_HTTP.REQUEST_FAILED THEN
        DBMS_OUTPUT.PUT_LINE('Request Failed: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Stack: ' || DBMS_UTILITY.FORMAT_ERROR_STACK);
        DBMS_OUTPUT.PUT_LINE('Error Backtrace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
        IF v_resp.status_code IS NOT NULL THEN
            UTL_HTTP.END_RESPONSE(v_resp);
        END IF;
END;
/