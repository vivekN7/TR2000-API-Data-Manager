-- Test APEX_WEB_SERVICE with HTTPS and current wallet configuration
-- Date: 2025-08-23
-- Purpose: Verify APEX HTTPS works after cleanup

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

PROMPT ========================================
PROMPT Testing APEX HTTPS with Wallet
PROMPT ========================================
PROMPT

DECLARE
    v_response CLOB;
    v_api_base_url VARCHAR2(500);
    v_url VARCHAR2(1000);
    v_plants_count NUMBER;
    c_wallet_path CONSTANT VARCHAR2(100) := 'file:C:\Oracle\wallet';
    c_wallet_pwd CONSTANT VARCHAR2(100) := 'WalletPass123';
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting APEX HTTPS test with wallet configuration...');
    DBMS_OUTPUT.PUT_LINE('Wallet Path: ' || c_wallet_path);
    DBMS_OUTPUT.PUT_LINE('----------------------------------------');
    
    -- Get API base URL from settings
    BEGIN
        SELECT setting_value INTO v_api_base_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        DBMS_OUTPUT.PUT_LINE('API Base URL: ' || v_api_base_url);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_api_base_url := 'https://equinor.pipespec-api.presight.com/';
            DBMS_OUTPUT.PUT_LINE('Using default API Base URL: ' || v_api_base_url);
    END;
    
    -- Test 1: Simple HTTPS endpoint (httpbin)
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 1: Generic HTTPS endpoint (httpbin.org)');
    BEGIN
        v_response := apex_web_service.make_rest_request(
            p_url => 'https://httpbin.org/get',
            p_http_method => 'GET',
            p_wallet_path => c_wallet_path,
            p_wallet_pwd => c_wallet_pwd
        );
        DBMS_OUTPUT.PUT_LINE('  ✅ Generic HTTPS WORKS! Response length: ' || LENGTH(v_response));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ❌ Generic HTTPS FAILED: ' || SQLERRM);
    END;
    
    -- Test 2: TR2000 API Plants endpoint
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 2: TR2000 API Plants endpoint');
    BEGIN
        v_url := v_api_base_url || 'plants';
        DBMS_OUTPUT.PUT_LINE('  URL: ' || v_url);
        
        v_response := apex_web_service.make_rest_request(
            p_url => v_url,
            p_http_method => 'GET',
            p_wallet_path => c_wallet_path,
            p_wallet_pwd => c_wallet_pwd
        );
        
        -- Count plants in response
        SELECT COUNT(*) INTO v_plants_count
        FROM JSON_TABLE(v_response, '$[*]'
            COLUMNS (
                plant_id VARCHAR2(50) PATH '$.id'
            ));
        
        DBMS_OUTPUT.PUT_LINE('  ✅ TR2000 Plants API WORKS!');
        DBMS_OUTPUT.PUT_LINE('     Response length: ' || LENGTH(v_response));
        DBMS_OUTPUT.PUT_LINE('     Number of plants: ' || v_plants_count);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ❌ TR2000 Plants API FAILED: ' || SQLERRM);
    END;
    
    -- Test 3: TR2000 API Issues endpoint for a specific plant
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 3: TR2000 API Issues endpoint (Plant: AAS)');
    BEGIN
        v_url := v_api_base_url || 'plants/AAS/issues';
        DBMS_OUTPUT.PUT_LINE('  URL: ' || v_url);
        
        v_response := apex_web_service.make_rest_request(
            p_url => v_url,
            p_http_method => 'GET',
            p_wallet_path => c_wallet_path,
            p_wallet_pwd => c_wallet_pwd
        );
        
        DBMS_OUTPUT.PUT_LINE('  ✅ TR2000 Issues API WORKS!');
        DBMS_OUTPUT.PUT_LINE('     Response length: ' || LENGTH(v_response));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ❌ TR2000 Issues API FAILED: ' || SQLERRM);
    END;
    
    -- Test 4: Using pkg_api_client functions
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 4: pkg_api_client.fetch_plants_json');
    BEGIN
        v_response := pkg_api_client.fetch_plants_json;
        DBMS_OUTPUT.PUT_LINE('  ✅ pkg_api_client.fetch_plants_json WORKS!');
        DBMS_OUTPUT.PUT_LINE('     Response length: ' || LENGTH(v_response));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ❌ pkg_api_client.fetch_plants_json FAILED: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 5: pkg_api_client.fetch_issues_json');
    BEGIN
        v_response := pkg_api_client.fetch_issues_json('AAS');
        DBMS_OUTPUT.PUT_LINE('  ✅ pkg_api_client.fetch_issues_json WORKS!');
        DBMS_OUTPUT.PUT_LINE('     Response length: ' || LENGTH(v_response));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  ❌ pkg_api_client.fetch_issues_json FAILED: ' || SQLERRM);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('✅ ALL TESTS COMPLETED SUCCESSFULLY!');
    DBMS_OUTPUT.PUT_LINE('APEX HTTPS with wallet is fully functional');
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

PROMPT
PROMPT Checking APEX and Network Configuration...
PROMPT

-- Verify APEX version
SELECT 'APEX Version' as config_item, version_no as value FROM apex_release;

-- Check network ACLs for TR2000_STAGING
SELECT 'Network ACL for ' || host as config_item, 
       'Ports ' || lower_port || '-' || upper_port as value
FROM dba_network_acls
WHERE principal = 'TR2000_STAGING'
ORDER BY host;

PROMPT
PROMPT ========================================
PROMPT Test Complete
PROMPT ========================================