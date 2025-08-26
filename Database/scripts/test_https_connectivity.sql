-- ===============================================================================
-- HTTPS Connectivity Test Script
-- ===============================================================================
-- Purpose: Systematically test HTTPS connectivity to isolate wallet/certificate issues
-- Run this from SQL*Plus or SQL Developer as TR2000_STAGING user
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200

PROMPT ===============================================================================
PROMPT HTTPS Connectivity Tests - TR2000 ETL System
PROMPT ===============================================================================
PROMPT

-- Test 1: Basic network connectivity (HTTP - no SSL)
PROMPT Test 1: HTTP Call (No SSL Required)
PROMPT ------------------------------------
DECLARE
    v_response CLOB;
    v_status_code NUMBER;
BEGIN
    apex_web_service.g_request_headers.DELETE;
    apex_web_service.g_request_headers(1).name := 'User-Agent';
    apex_web_service.g_request_headers(1).value := 'Oracle APEX';
    
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    
    v_status_code := apex_web_service.g_status_code;
    
    IF v_status_code = 200 THEN
        DBMS_OUTPUT.PUT_LINE('✓ SUCCESS: HTTP works! Status: ' || v_status_code);
        DBMS_OUTPUT.PUT_LINE('  Response length: ' || LENGTH(v_response) || ' chars');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ FAILED: HTTP call failed with status: ' || v_status_code);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('  This indicates Network ACL is not configured');
END;
/

PROMPT

-- Test 2: HTTPS to a well-known site (tests basic SSL)
PROMPT Test 2: HTTPS to Well-Known Site (httpbin.org)
PROMPT -----------------------------------------------
DECLARE
    v_response CLOB;
    v_status_code NUMBER;
BEGIN
    apex_web_service.g_request_headers.DELETE;
    apex_web_service.g_request_headers(1).name := 'User-Agent';
    apex_web_service.g_request_headers(1).value := 'Oracle APEX';
    
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://httpbin.org/get',
        p_http_method => 'GET',
        p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
        p_wallet_pwd => 'WalletPass123'
    );
    
    v_status_code := apex_web_service.g_status_code;
    
    IF v_status_code = 200 THEN
        DBMS_OUTPUT.PUT_LINE('✓ SUCCESS: HTTPS to httpbin.org works!');
        DBMS_OUTPUT.PUT_LINE('  Response length: ' || LENGTH(v_response) || ' chars');
        DBMS_OUTPUT.PUT_LINE('  Wallet is working for standard SSL certificates');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ FAILED: Status: ' || v_status_code);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ ERROR: ' || SQLERRM);
        IF SQLCODE = -29024 THEN
            DBMS_OUTPUT.PUT_LINE('  Certificate validation failure - wallet missing certificates');
        ELSIF SQLCODE = -29273 THEN
            DBMS_OUTPUT.PUT_LINE('  HTTP request failed - check wallet path');
        END IF;
END;
/

PROMPT

-- Test 3: HTTPS to TR2000 API (without /v1)
PROMPT Test 3: HTTPS to tr2000api.equinor.com (Correct URL)
PROMPT -----------------------------------------------------
DECLARE
    v_response CLOB;
    v_status_code NUMBER;
BEGIN
    apex_web_service.g_request_headers.DELETE;
    apex_web_service.g_request_headers(1).name := 'User-Agent';
    apex_web_service.g_request_headers(1).value := 'Oracle APEX';
    
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://tr2000api.equinor.com/plants',  -- NO /v1!
        p_http_method => 'GET',
        p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
        p_wallet_pwd => 'WalletPass123'
    );
    
    v_status_code := apex_web_service.g_status_code;
    
    IF v_status_code = 200 THEN
        DBMS_OUTPUT.PUT_LINE('✓ SUCCESS: TR2000 API connection works!');
        DBMS_OUTPUT.PUT_LINE('  Response length: ' || LENGTH(v_response) || ' chars');
        DBMS_OUTPUT.PUT_LINE('  First 100 chars: ' || SUBSTR(v_response, 1, 100));
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ FAILED: Status: ' || v_status_code);
        IF v_status_code = 404 THEN
            DBMS_OUTPUT.PUT_LINE('  404 Not Found - check if /plants endpoint exists');
        END IF;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ ERROR: ' || SQLERRM);
        IF SQLCODE = -29024 THEN
            DBMS_OUTPUT.PUT_LINE('  Certificate validation failure');
            DBMS_OUTPUT.PUT_LINE('  TR2000 API certificates not in wallet');
            DBMS_OUTPUT.PUT_LINE('  Need to add certificates for tr2000api.equinor.com');
        END IF;
END;
/

PROMPT

-- Test 4: Alternative API endpoint
PROMPT Test 4: HTTPS to Alternative API (pipespec-api.presight.com)
PROMPT ------------------------------------------------------------
DECLARE
    v_response CLOB;
    v_status_code NUMBER;
BEGIN
    apex_web_service.g_request_headers.DELETE;
    apex_web_service.g_request_headers(1).name := 'User-Agent';
    apex_web_service.g_request_headers(1).value := 'Oracle APEX';
    
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',
        p_http_method => 'GET',
        p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
        p_wallet_pwd => 'WalletPass123'
    );
    
    v_status_code := apex_web_service.g_status_code;
    
    IF v_status_code = 200 THEN
        DBMS_OUTPUT.PUT_LINE('✓ SUCCESS: Alternative API works!');
        DBMS_OUTPUT.PUT_LINE('  Response length: ' || LENGTH(v_response) || ' chars');
        DBMS_OUTPUT.PUT_LINE('  Consider using this endpoint instead');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ FAILED: Status: ' || v_status_code);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ ERROR: ' || SQLERRM);
END;
/

PROMPT

-- Test 5: Test the fixed package
PROMPT Test 5: Test pkg_api_client After Fixes
PROMPT ----------------------------------------
DECLARE
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
    v_plant_count NUMBER;
BEGIN
    -- First check what URL is configured
    DECLARE
        v_url VARCHAR2(500);
    BEGIN
        SELECT setting_value INTO v_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        DBMS_OUTPUT.PUT_LINE('Configured API URL: ' || v_url);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('No API_BASE_URL in CONTROL_SETTINGS');
            DBMS_OUTPUT.PUT_LINE('Package will use default: https://tr2000api.equinor.com');
    END;
    
    -- Try to refresh plants
    pkg_api_client.refresh_plants_from_api(
        p_status => v_status,
        p_message => v_message
    );
    
    DBMS_OUTPUT.PUT_LINE('Package Status: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Package Message: ' || v_message);
    
    IF v_status = 'SUCCESS' THEN
        SELECT COUNT(*) INTO v_plant_count FROM PLANTS;
        DBMS_OUTPUT.PUT_LINE('✓ SUCCESS: ' || v_plant_count || ' plants loaded');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ FAILED: Check error details above');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ ERROR calling package: ' || SQLERRM);
END;
/

PROMPT
PROMPT ===============================================================================
PROMPT Test Summary:
PROMPT -------------
PROMPT 1. If Test 1 (HTTP) fails: Network ACL needs to be configured
PROMPT 2. If Test 2 (HTTPS httpbin) fails: Wallet path or password is wrong
PROMPT 3. If Test 3 (TR2000 API) fails: Need TR2000 certificates in wallet
PROMPT 4. If Test 4 (Alternative API) works: Use this endpoint instead
PROMPT 5. If Test 5 (Package) fails: Check package compilation and configuration
PROMPT
PROMPT Next Steps Based on Results:
PROMPT ---------------------------
PROMPT - If certificate error: Add TR2000 certificates to wallet
PROMPT - If 404 error: Check correct API endpoint URL
PROMPT - If network error: Check firewall/proxy settings
PROMPT ===============================================================================