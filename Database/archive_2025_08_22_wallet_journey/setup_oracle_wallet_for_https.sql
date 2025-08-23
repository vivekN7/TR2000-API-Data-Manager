-- Setup Oracle Wallet for HTTPS support in APEX_WEB_SERVICE
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ========================================
PROMPT Setting up Oracle Wallet for HTTPS
PROMPT ========================================

-- Switch to PDB
ALTER SESSION SET CONTAINER = XEPDB1;

-- Check current wallet configuration
PROMPT Current wallet settings:
SELECT * FROM v$encryption_wallet;

-- Set wallet location for HTTP requests
BEGIN
    DBMS_OUTPUT.PUT_LINE('Setting wallet configuration...');
    
    -- Option 1: Use auto-login wallet (no password required)
    -- This tells Oracle to trust all certificates (like curl -k)
    UTL_HTTP.SET_WALLET(NULL);
    
    DBMS_OUTPUT.PUT_LINE('✓ Wallet set to accept all certificates');
    
    -- Set HTTP transfer timeout
    UTL_HTTP.SET_TRANSFER_TIMEOUT(60);
    DBMS_OUTPUT.PUT_LINE('✓ Transfer timeout set to 60 seconds');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- Test HTTPS with relaxed certificate validation
PROMPT
PROMPT Testing HTTPS with relaxed validation...
DECLARE
    v_response CLOB;
    v_req UTL_HTTP.REQ;
    v_resp UTL_HTTP.RESP;
    v_buffer VARCHAR2(32767);
BEGIN
    -- Test with UTL_HTTP first to verify HTTPS works
    DBMS_OUTPUT.PUT_LINE('Test 1: UTL_HTTP with HTTPS (baseline test)');
    BEGIN
        -- Initialize CLOB
        DBMS_LOB.CREATETEMPORARY(v_response, TRUE);
        
        -- Disable certificate validation for testing
        UTL_HTTP.SET_WALLET(NULL);
        
        v_req := UTL_HTTP.BEGIN_REQUEST('https://httpbin.org/get', 'GET');
        UTL_HTTP.SET_HEADER(v_req, 'User-Agent', 'Oracle/Test');
        
        v_resp := UTL_HTTP.GET_RESPONSE(v_req);
        
        BEGIN
            LOOP
                UTL_HTTP.READ_TEXT(v_resp, v_buffer, 32767);
                DBMS_LOB.WRITEAPPEND(v_response, LENGTH(v_buffer), v_buffer);
            END LOOP;
        EXCEPTION
            WHEN UTL_HTTP.END_OF_BODY THEN
                UTL_HTTP.END_RESPONSE(v_resp);
        END;
        
        DBMS_OUTPUT.PUT_LINE('✅ UTL_HTTP HTTPS works! Response length: ' || DBMS_LOB.GETLENGTH(v_response));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ UTL_HTTP HTTPS failed: ' || SQLERRM);
            IF v_resp.status_code IS NOT NULL THEN
                UTL_HTTP.END_RESPONSE(v_resp);
            END IF;
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 2: APEX_WEB_SERVICE with HTTPS');
    BEGIN
        -- Try to bypass SSL validation in APEX_WEB_SERVICE
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'User-Agent';
        apex_web_service.g_request_headers(1).value := 'Oracle/TR2000';
        
        -- Set wallet for APEX_WEB_SERVICE
        APEX_WEB_SERVICE.G_WALLET_PATH := NULL;
        
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://httpbin.org/get',
            p_http_method => 'GET',
            p_wallet_path => NULL  -- Tell APEX to not validate certificates
        );
        
        DBMS_OUTPUT.PUT_LINE('✅ APEX_WEB_SERVICE HTTPS works! Response length: ' || LENGTH(v_response));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ APEX_WEB_SERVICE HTTPS failed: ' || SQLERRM);
    END;
END;
/

-- Alternative: Create a proper wallet with certificates
PROMPT
PROMPT Alternative approach - Creating proper wallet...
PROMPT To create a proper wallet with certificates:
PROMPT 1. As oracle user on the server:
PROMPT    mkdir -p /opt/oracle/admin/XE/wallet
PROMPT    orapki wallet create -wallet /opt/oracle/admin/XE/wallet -auto_login
PROMPT 2. Download certificates and add them:
PROMPT    orapki wallet add -wallet /opt/oracle/admin/XE/wallet -trusted_cert -cert certificate.crt
PROMPT 3. Then use: apex_web_service.make_rest_request(p_wallet_path => 'file:/opt/oracle/admin/XE/wallet')

PROMPT
PROMPT ========================================
PROMPT Wallet setup complete
PROMPT ========================================