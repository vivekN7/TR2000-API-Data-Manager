-- ===============================================================================
-- Test API Connectivity using UTL_HTTP (Alternative to APEX_WEB_SERVICE)
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
    v_req UTL_HTTP.REQ;
    v_resp UTL_HTTP.RESP;
    v_url VARCHAR2(500);
    v_buffer VARCHAR2(32767);
    v_response CLOB;
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Testing API with UTL_HTTP');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    -- Get API URL
    SELECT setting_value || 'plants' INTO v_url
    FROM CONTROL_SETTINGS
    WHERE setting_key = 'API_BASE_URL';
    
    DBMS_OUTPUT.PUT_LINE('URL: ' || v_url);
    
    -- Initialize CLOB
    DBMS_LOB.CREATETEMPORARY(v_response, TRUE);
    
    -- Make HTTP request
    BEGIN
        v_req := UTL_HTTP.BEGIN_REQUEST(v_url, 'GET');
        UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
        UTL_HTTP.SET_HEADER(v_req, 'User-Agent', 'Oracle/TR2000-ETL');
        
        v_resp := UTL_HTTP.GET_RESPONSE(v_req);
        
        DBMS_OUTPUT.PUT_LINE('HTTP Status: ' || v_resp.status_code || ' ' || v_resp.reason_phrase);
        
        IF v_resp.status_code = 200 THEN
            -- Read first chunk of response
            UTL_HTTP.READ_TEXT(v_resp, v_buffer, 1000);
            DBMS_OUTPUT.PUT_LINE('First 1000 chars of response:');
            DBMS_OUTPUT.PUT_LINE(v_buffer);
            DBMS_OUTPUT.PUT_LINE('...');
            DBMS_OUTPUT.PUT_LINE('SUCCESS: API is accessible via UTL_HTTP');
        END IF;
        
        UTL_HTTP.END_RESPONSE(v_resp);
        
    EXCEPTION
        WHEN UTL_HTTP.REQUEST_FAILED THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: Request failed - ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Possible causes:');
            DBMS_OUTPUT.PUT_LINE('1. Network ACL not configured');
            DBMS_OUTPUT.PUT_LINE('2. Proxy configuration needed');
            DBMS_OUTPUT.PUT_LINE('3. SSL/TLS certificate issues');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('To configure Network ACL, run as DBA:');
            DBMS_OUTPUT.PUT_LINE('BEGIN');
            DBMS_OUTPUT.PUT_LINE('  DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(');
            DBMS_OUTPUT.PUT_LINE('    acl => ''tr2000_api_acl.xml'',');
            DBMS_OUTPUT.PUT_LINE('    description => ''ACL for TR2000 API'',');
            DBMS_OUTPUT.PUT_LINE('    principal => ''TR2000_STAGING'',');
            DBMS_OUTPUT.PUT_LINE('    is_grant => TRUE,');
            DBMS_OUTPUT.PUT_LINE('    privilege => ''connect''');
            DBMS_OUTPUT.PUT_LINE('  );');
            DBMS_OUTPUT.PUT_LINE('  DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(');
            DBMS_OUTPUT.PUT_LINE('    acl => ''tr2000_api_acl.xml'',');
            DBMS_OUTPUT.PUT_LINE('    host => ''tr2000api.equinor.com''');
            DBMS_OUTPUT.PUT_LINE('  );');
            DBMS_OUTPUT.PUT_LINE('END;');
            DBMS_OUTPUT.PUT_LINE('/');
            
        WHEN OTHERS THEN
            IF v_resp.status_code IS NOT NULL THEN
                UTL_HTTP.END_RESPONSE(v_resp);
            END IF;
            DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/