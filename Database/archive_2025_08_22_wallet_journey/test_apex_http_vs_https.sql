-- Test APEX_WEB_SERVICE with HTTP vs HTTPS to isolate SSL/Wallet issues
-- This will help determine if we need full APEX reinstall or just wallet config

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

PROMPT ========================================
PROMPT Testing APEX_WEB_SERVICE HTTP vs HTTPS
PROMPT ========================================
PROMPT

DECLARE
    v_response CLOB;
    v_http_works BOOLEAN := FALSE;
    v_https_works BOOLEAN := FALSE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting APEX_WEB_SERVICE diagnostic tests...');
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    -- Test 1: Simple HTTP endpoint (no SSL required)
    DBMS_OUTPUT.PUT_LINE('Test 1: HTTP endpoint (http://httpbin.org/get)');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'http://httpbin.org/get',
            p_http_method => 'GET'
        );
        DBMS_OUTPUT.PUT_LINE('  ✅ HTTP WORKS! Response length: ' || LENGTH(v_response));
        v_http_works := TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ❌ HTTP FAILED: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('     Error Code: ' || SQLCODE);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 2: HTTPS endpoint (requires wallet/SSL)
    DBMS_OUTPUT.PUT_LINE('Test 2: HTTPS endpoint (https://httpbin.org/get)');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://httpbin.org/get',
            p_http_method => 'GET'
        );
        DBMS_OUTPUT.PUT_LINE('  ✅ HTTPS WORKS! Response length: ' || LENGTH(v_response));
        v_https_works := TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ❌ HTTPS FAILED: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('     Error Code: ' || SQLCODE);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 3: Try with explicit headers
    DBMS_OUTPUT.PUT_LINE('Test 3: HTTP with explicit headers');
    BEGIN
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'User-Agent';
        apex_web_service.g_request_headers(1).value := 'Oracle/TR2000-ETL';
        apex_web_service.g_request_headers(2).name := 'Accept';
        apex_web_service.g_request_headers(2).value := 'application/json';
        
        v_response := apex_web_service.make_rest_request(
            p_url => 'http://httpbin.org/headers',
            p_http_method => 'GET'
        );
        DBMS_OUTPUT.PUT_LINE('  ✅ HTTP with headers WORKS! Response length: ' || LENGTH(v_response));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ❌ HTTP with headers FAILED: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 4: Check if it's specifically httpbin.org or all URLs
    DBMS_OUTPUT.PUT_LINE('Test 4: Alternative HTTP endpoint (http://jsonplaceholder.typicode.com/posts/1)');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'http://jsonplaceholder.typicode.com/posts/1',
            p_http_method => 'GET'
        );
        DBMS_OUTPUT.PUT_LINE('  ✅ Alternative endpoint WORKS! Response length: ' || LENGTH(v_response));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ❌ Alternative endpoint FAILED: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('DIAGNOSIS SUMMARY:');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    IF NOT v_http_works AND NOT v_https_works THEN
        DBMS_OUTPUT.PUT_LINE('❌ APEX_WEB_SERVICE is completely broken');
        DBMS_OUTPUT.PUT_LINE('   → Root cause: APEX installation is incomplete');
        DBMS_OUTPUT.PUT_LINE('   → Solution: Need to repair or reinstall APEX');
    ELSIF v_http_works AND NOT v_https_works THEN
        DBMS_OUTPUT.PUT_LINE('⚠️  HTTP works but HTTPS fails');
        DBMS_OUTPUT.PUT_LINE('   → Root cause: Oracle Wallet not configured for SSL');
        DBMS_OUTPUT.PUT_LINE('   → Solution: Configure Oracle Wallet with certificates');
    ELSIF v_http_works AND v_https_works THEN
        DBMS_OUTPUT.PUT_LINE('✅ APEX_WEB_SERVICE is fully functional!');
        DBMS_OUTPUT.PUT_LINE('   → Both HTTP and HTTPS work correctly');
        DBMS_OUTPUT.PUT_LINE('   → Can proceed with APEX_WEB_SERVICE implementation');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

PROMPT
PROMPT Now checking APEX installation details...
PROMPT

-- Check APEX version and components
SELECT 'APEX Version' as check_type, version_no as result 
FROM apex_release
UNION ALL
SELECT 'APEX Schema', owner 
FROM all_objects 
WHERE object_name = 'WWV_FLOW' AND object_type = 'SYNONYM' AND rownum = 1
UNION ALL
SELECT 'WWV_FLOW Tables Count', TO_CHAR(COUNT(*))
FROM all_tables 
WHERE owner LIKE 'APEX%' AND table_name LIKE 'WWV_FLOW%'
UNION ALL
SELECT 'Instance Parameters Count', TO_CHAR(COUNT(*))
FROM apex_instance_parameters
UNION ALL
SELECT 'ALLOW_PUBLIC_WEBSERVICES', 
       NVL((SELECT value FROM apex_instance_parameters WHERE name = 'ALLOW_PUBLIC_WEBSERVICES'), 'NOT SET')
FROM dual;

PROMPT
PROMPT Checking Network ACLs for our hosts...
PROMPT

-- Check ACLs for our specific hosts
SELECT host, lower_port, upper_port, acl, principal
FROM dba_network_acls
WHERE principal = 'TR2000_STAGING'
   OR host IN ('httpbin.org', 'jsonplaceholder.typicode.com', 
               'equinor.pipespec-api.presight.com', '*.presight.com')
ORDER BY host;

PROMPT
PROMPT ========================================
PROMPT Test complete. Check results above.
PROMPT ========================================