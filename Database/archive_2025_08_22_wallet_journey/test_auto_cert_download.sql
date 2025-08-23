-- Test Oracle's auto-download certificate feature (19c+)
SET SERVEROUTPUT ON SIZE UNLIMITED

-- Switch to PDB
ALTER SESSION SET CONTAINER = XEPDB1;

PROMPT ========================================
PROMPT Testing Auto Certificate Download
PROMPT ========================================

-- Set HTTPS proxy for certificate download
BEGIN
    UTL_HTTP.SET_PROXY('');  -- Clear any proxy
    UTL_HTTP.SET_TRANSFER_TIMEOUT(30);
    
    -- Try to use auto-download feature
    UTL_HTTP.SET_WALLET('', '');  -- Empty wallet triggers auto-download in 19c+
    
    DBMS_OUTPUT.PUT_LINE('Attempting connection with auto-certificate download...');
END;
/

-- Test connection
DECLARE
    v_req UTL_HTTP.REQ;
    v_resp UTL_HTTP.RESP;
    v_buffer VARCHAR2(100);
BEGIN
    v_req := UTL_HTTP.BEGIN_REQUEST('https://equinor.pipespec-api.presight.com/plants', 'GET');
    UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
    
    v_resp := UTL_HTTP.GET_RESPONSE(v_req);
    
    DBMS_OUTPUT.PUT_LINE('✅ SUCCESS! Status: ' || v_resp.status_code);
    
    UTL_HTTP.READ_TEXT(v_resp, v_buffer, 100);
    DBMS_OUTPUT.PUT_LINE('Response: ' || v_buffer);
    
    UTL_HTTP.END_RESPONSE(v_resp);
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Auto-download not working: ' || SQLERRM);
        IF v_resp.status_code IS NOT NULL THEN
            UTL_HTTP.END_RESPONSE(v_resp);
        END IF;
END;
/

PROMPT ========================================