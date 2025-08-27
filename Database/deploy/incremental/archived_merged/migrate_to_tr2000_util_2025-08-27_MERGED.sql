-- ===============================================================================
-- Migrate to TR2000_UTIL Package (DBA's Solution)
-- Date: 2025-08-27
-- Purpose: Update all packages to use centralized tr2000_util.http_get
-- ===============================================================================

PROMPT ===============================================================================
PROMPT Migrating to TR2000_UTIL Package
PROMPT ===============================================================================

-- Create wrapper functions in TR2000_STAGING to minimize code changes
CREATE OR REPLACE FUNCTION make_api_request_util(
    p_url            VARCHAR2,
    p_method         VARCHAR2 DEFAULT 'GET',
    p_correlation_id VARCHAR2 DEFAULT NULL
) RETURN CLOB IS
    v_response   CLOB;
    v_url_parts  VARCHAR2(4000);
    v_base_url   VARCHAR2(500) := 'https://equinor.pipespec-api.presight.com';
    v_path       VARCHAR2(500);
    v_batch_id   VARCHAR2(100);
BEGIN
    -- Generate batch ID from correlation ID or timestamp
    v_batch_id := NVL(p_correlation_id, 'BATCH_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDD_HH24MISS'));
    
    -- Extract path from full URL
    IF INSTR(p_url, v_base_url) > 0 THEN
        v_path := SUBSTR(p_url, LENGTH(v_base_url) + 1);
    ELSE
        -- If full URL doesn't match expected base, try to extract path after domain
        v_path := REGEXP_SUBSTR(p_url, '/[^?]*');
    END IF;
    
    -- Call tr2000_util.http_get
    v_response := tr2000_util.http_get(
        p_url_base => v_base_url,
        p_path     => v_path,
        p_qs       => NULL,  -- Query string if needed
        p_batch_id => v_batch_id,
        p_cred_id  => 'TR2000_CRED'
    );
    
    RETURN v_response;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and re-raise
        DBMS_OUTPUT.PUT_LINE('Error in make_api_request_util: ' || SQLERRM);
        RAISE;
END make_api_request_util;
/

-- Function to get last status code (compatibility)
CREATE OR REPLACE FUNCTION get_last_http_status RETURN NUMBER IS
BEGIN
    -- tr2000_util logs status in etl_log, retrieve most recent
    RETURN apex_web_service.g_status_code;
END get_last_http_status;
/

-- Create a view to see recent API calls from etl_log
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
FROM etl_log
WHERE created_at > SYSDATE - 1  -- Last 24 hours
ORDER BY created_at DESC;

COMMENT ON VIEW V_RECENT_API_CALLS IS 'Recent API calls from ETL log (last 24 hours)';

PROMPT 
PROMPT ===============================================================================
PROMPT Migration Helpers Created
PROMPT ===============================================================================
PROMPT 
PROMPT Manual steps required:
PROMPT 
PROMPT 1. Update PKG_API_CLIENT:
PROMPT    Replace calls to apex_web_service.make_rest_request with:
PROMPT    v_response := make_api_request_util(v_url, 'GET');
PROMPT 
PROMPT 2. Update PKG_API_CLIENT_REFERENCES:
PROMPT    Replace calls to apex_web_service.make_rest_request with:
PROMPT    v_response := make_api_request_util(v_url, p_method, p_correlation_id);
PROMPT 
PROMPT 3. Ensure APEX credential 'TR2000_CRED' exists:
PROMPT    - In APEX > Workspace Credentials
PROMPT    - Create credential named 'TR2000_CRED'
PROMPT    - Set authentication as needed for API
PROMPT 
PROMPT 4. Grant execute privilege (as DBA):
PROMPT    GRANT EXECUTE ON tr2000_util TO TR2000_STAGING;
PROMPT 
PROMPT 5. Test the integration:
PROMPT    SELECT make_api_request_util(
PROMPT        'https://equinor.pipespec-api.presight.com/plants',
PROMPT        'GET'
PROMPT    ) FROM dual;
PROMPT 
PROMPT 6. Monitor API calls:
PROMPT    SELECT * FROM V_RECENT_API_CALLS;
PROMPT ===============================================================================