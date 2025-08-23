-- Check and set SSL verification bypass
SET SERVEROUTPUT ON SIZE UNLIMITED

-- As SYSDBA, check if we can disable SSL verification
PROMPT Checking SSL verification settings...

-- Check current settings
SELECT name, value 
FROM v$parameter 
WHERE name LIKE '%ssl%' OR name LIKE '%http%' OR name LIKE '%wallet%';

-- Try to bypass SSL certificate validation
DECLARE
    v_req UTL_HTTP.REQ;
    v_resp UTL_HTTP.RESP;
    v_buffer VARCHAR2(100);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing with wallet bypass...');
    
    -- Set wallet to NULL to bypass certificate validation
    UTL_HTTP.SET_WALLET(path => NULL, password => NULL);
    
    -- Disable certificate validation (if possible)
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION SET SSL_VERIFY_SERVER = FALSE';
        DBMS_OUTPUT.PUT_LINE('SSL_VERIFY_SERVER set to FALSE');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Cannot set SSL_VERIFY_SERVER: ' || SQLERRM);
    END;
    
    -- Test connection
    v_req := UTL_HTTP.BEGIN_REQUEST('https://equinor.pipespec-api.presight.com/plants', 'GET');
    UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
    
    v_resp := UTL_HTTP.GET_RESPONSE(v_req);
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS! Status: ' || v_resp.status_code);
    
    UTL_HTTP.READ_TEXT(v_resp, v_buffer, 100);
    DBMS_OUTPUT.PUT_LINE('Data: ' || v_buffer);
    
    UTL_HTTP.END_RESPONSE(v_resp);
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Still failing: ' || SQLERRM);
        IF v_resp.status_code IS NOT NULL THEN
            UTL_HTTP.END_RESPONSE(v_resp);
        END IF;
END;
/