-- Fix the make_api_request_util function to properly reference SYSTEM.tr2000_util

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
    
    -- Call SYSTEM.tr2000_util.http_get
    v_response := SYSTEM.tr2000_util.http_get(
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

PROMPT make_api_request_util function fixed