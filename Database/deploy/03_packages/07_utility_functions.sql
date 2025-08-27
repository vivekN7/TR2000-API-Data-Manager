-- ===============================================================================
-- Utility Functions for TR2000_UTIL Integration
-- Date: 2025-08-27
-- Purpose: Wrapper functions to integrate with DBA's TR2000_UTIL package
-- ===============================================================================

-- ===============================================================================
-- make_api_request_util Function
-- Purpose: Wrapper to translate full URLs to TR2000_UTIL's parameter format
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

-- ===============================================================================
-- get_last_http_status Function
-- Purpose: Compatibility function for getting last HTTP status
-- ===============================================================================

CREATE OR REPLACE FUNCTION get_last_http_status RETURN NUMBER IS
BEGIN
    -- TR2000_UTIL logs status in ETL_LOG, but apex_web_service maintains it
    RETURN apex_web_service.g_status_code;
END get_last_http_status;
/

-- ===============================================================================
-- V_RECENT_API_CALLS View
-- Purpose: View recent API calls from ETL_LOG table
-- ===============================================================================

CREATE OR REPLACE VIEW V_RECENT_API_CALLS AS
SELECT 
    log_id,
    endpoint,
    query_params,
    http_status,
    rows_ingested,
    batch_id,
    error_msg,
    TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') as call_time
FROM ETL_LOG
WHERE created_at > SYSDATE - 1  -- Last 24 hours
ORDER BY created_at DESC;

-- Grant necessary privileges for SYSTEM to access our tables
-- (Run as TR2000_STAGING user)
GRANT INSERT ON ETL_LOG TO SYSTEM;
GRANT INSERT ON RAW_JSON TO SYSTEM;

PROMPT ===============================================================================
PROMPT Utility Functions Created Successfully
PROMPT ===============================================================================
PROMPT Functions:
PROMPT   - make_api_request_util: Wrapper for TR2000_UTIL API calls
PROMPT   - get_last_http_status: Get last HTTP status code
PROMPT Views:
PROMPT   - V_RECENT_API_CALLS: Monitor recent API activity
PROMPT ===============================================================================