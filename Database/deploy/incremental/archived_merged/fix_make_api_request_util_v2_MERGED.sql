-- ===============================================================================
-- Fix make_api_request_util - Remove Shortcuts for Production
-- Date: 2025-08-27
-- Purpose: Make the wrapper function production-ready
-- ===============================================================================

CREATE OR REPLACE FUNCTION make_api_request_util(
    p_url            VARCHAR2,
    p_method         VARCHAR2 DEFAULT 'GET',
    p_correlation_id VARCHAR2 DEFAULT NULL
) RETURN CLOB IS
    v_response   CLOB;
    v_base_url   VARCHAR2(500);
    v_path       VARCHAR2(500);
    v_query_str  VARCHAR2(2000);
    v_batch_id   VARCHAR2(100);
    v_url_parts  VARCHAR2(4000);
    v_q_pos      NUMBER;
BEGIN
    -- Generate batch ID from correlation ID or timestamp
    v_batch_id := NVL(p_correlation_id, 'BATCH_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDD_HH24MISS'));
    
    -- Get base URL from configuration instead of hard-coding
    BEGIN
        SELECT setting_value INTO v_base_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Fallback to default if not configured
            v_base_url := 'https://equinor.pipespec-api.presight.com';
    END;
    
    -- Parse URL into components
    -- Check if we have a query string
    v_q_pos := INSTR(p_url, '?');
    
    IF v_q_pos > 0 THEN
        -- Extract path and query string separately
        v_url_parts := SUBSTR(p_url, LENGTH(v_base_url) + 1, v_q_pos - LENGTH(v_base_url) - 1);
        v_path := v_url_parts;
        v_query_str := SUBSTR(p_url, v_q_pos + 1);
    ELSE
        -- No query string
        IF INSTR(p_url, v_base_url) > 0 THEN
            v_path := SUBSTR(p_url, LENGTH(v_base_url) + 1);
        ELSE
            -- If full URL doesn't match expected base, try to extract path
            v_path := REGEXP_SUBSTR(p_url, '/[^?]*');
        END IF;
        v_query_str := NULL;
    END IF;
    
    -- Call SYSTEM.tr2000_util.http_get with proper parameters
    v_response := SYSTEM.tr2000_util.http_get(
        p_url_base => v_base_url,
        p_path     => v_path,
        p_qs       => v_query_str,
        p_batch_id => v_batch_id,
        p_cred_id  => 'TR2000_CRED'
    );
    
    RETURN v_response;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Better error handling with context
        DBMS_OUTPUT.PUT_LINE('Error in make_api_request_util:');
        DBMS_OUTPUT.PUT_LINE('  URL: ' || p_url);
        DBMS_OUTPUT.PUT_LINE('  Base URL: ' || v_base_url);
        DBMS_OUTPUT.PUT_LINE('  Path: ' || v_path);
        DBMS_OUTPUT.PUT_LINE('  Query: ' || v_query_str);
        DBMS_OUTPUT.PUT_LINE('  Error: ' || SQLERRM);
        RAISE;
END make_api_request_util;
/

PROMPT make_api_request_util updated - shortcuts removed for production