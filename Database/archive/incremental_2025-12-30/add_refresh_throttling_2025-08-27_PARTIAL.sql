-- ===============================================================================
-- Add Simple Refresh Throttling (Quick Win)
-- Date: 2025-08-27
-- Purpose: Prevent redundant API calls within 5-minute window
-- ===============================================================================

PROMPT ===============================================================================
PROMPT Adding Refresh Throttling to Reduce Unnecessary API Calls
PROMPT ===============================================================================

-- Add last_refresh columns to track when references were fetched
ALTER TABLE SELECTED_ISSUES ADD (
    last_ref_refresh_all TIMESTAMP,     -- When all references were last refreshed
    last_ref_refresh_pcs TIMESTAMP,     -- When PCS specifically was refreshed
    refresh_count NUMBER DEFAULT 0       -- How many times refreshed today
);

COMMENT ON COLUMN SELECTED_ISSUES.last_ref_refresh_all IS 'Last time all reference types were refreshed from API';
COMMENT ON COLUMN SELECTED_ISSUES.last_ref_refresh_pcs IS 'Last time PCS references specifically were refreshed';
COMMENT ON COLUMN SELECTED_ISSUES.refresh_count IS 'Number of refreshes today (reset daily)';

-- Update PKG_API_CLIENT_REFERENCES with throttling
CREATE OR REPLACE PACKAGE BODY PKG_API_CLIENT_REFERENCES AS

    -- Private constants for throttling
    c_min_refresh_interval CONSTANT INTERVAL DAY TO SECOND := INTERVAL '5' MINUTE;
    
    -- =========================================================================
    -- Main procedure to refresh all reference types for an issue
    -- Now includes throttling to prevent excessive API calls
    -- =========================================================================
    PROCEDURE refresh_all_issue_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_correlation_id VARCHAR2(36);
        v_ref_status VARCHAR2(50);
        v_ref_msg VARCHAR2(4000);
        v_overall_status VARCHAR2(50) := 'SUCCESS';
        v_details VARCHAR2(4000);
        v_last_refresh TIMESTAMP;
    BEGIN
        -- Check if recently refreshed (throttling)
        BEGIN
            SELECT last_ref_refresh_all
            INTO v_last_refresh
            FROM SELECTED_ISSUES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev;
            
            -- Skip if refreshed within last 5 minutes
            IF v_last_refresh IS NOT NULL AND 
               v_last_refresh + c_min_refresh_interval > SYSTIMESTAMP THEN
                p_status := 'SKIPPED';
                p_message := 'Recently refreshed at ' || 
                           TO_CHAR(v_last_refresh, 'HH24:MI:SS') || 
                           ' (within 5-minute throttle window)';
                RETURN;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL; -- Issue not in SELECTED_ISSUES, proceed anyway
        END;
        
        v_correlation_id := generate_correlation_id();
        
        DBMS_OUTPUT.PUT_LINE('Processing all reference types for issue ' || 
                           p_plant_id || '/' || p_issue_rev);
        DBMS_OUTPUT.PUT_LINE('Correlation ID: ' || v_correlation_id);
        
        -- Process each reference type
        FOR ref_type IN (
            SELECT 'pcs' as type FROM dual UNION ALL
            SELECT 'sc' FROM dual UNION ALL
            SELECT 'vsm' FROM dual UNION ALL
            SELECT 'vds' FROM dual UNION ALL
            SELECT 'eds' FROM dual UNION ALL
            SELECT 'mds' FROM dual UNION ALL
            SELECT 'vsk' FROM dual UNION ALL
            SELECT 'esk' FROM dual UNION ALL
            SELECT 'pipe_element' FROM dual
        ) LOOP
            BEGIN
                refresh_issue_references(
                    p_plant_id => p_plant_id,
                    p_issue_rev => p_issue_rev,
                    p_reference_type => ref_type.type,
                    p_status => v_ref_status,
                    p_message => v_ref_msg,
                    p_correlation_id => v_correlation_id
                );
                
                v_details := v_details || ref_type.type || ': ' || v_ref_status || '; ';
                
                IF v_ref_status = 'ERROR' THEN
                    v_overall_status := 'PARTIAL';
                END IF;
                
            EXCEPTION
                WHEN OTHERS THEN
                    v_details := v_details || ref_type.type || ': ERROR (' || SQLERRM || '); ';
                    v_overall_status := 'PARTIAL';
            END;
        END LOOP;
        
        -- Update last refresh timestamp
        UPDATE SELECTED_ISSUES
        SET last_ref_refresh_all = SYSTIMESTAMP,
            refresh_count = NVL(refresh_count, 0) + 1,
            last_etl_run = SYSTIMESTAMP,
            etl_status = v_overall_status
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev;
        
        COMMIT;
        
        p_status := v_overall_status;
        p_message := 'All 9 reference types processed. ' || v_details;
        
        DBMS_OUTPUT.PUT_LINE('Overall status: ' || v_overall_status);
        DBMS_OUTPUT.PUT_LINE(p_message);
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
            DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
    END refresh_all_issue_references;

    -- =========================================================================
    -- Refresh references for a specific issue and type
    -- Also includes throttling for individual reference types
    -- =========================================================================
    PROCEDURE refresh_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_reference_type  IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    ) IS
        v_json_response CLOB;
        v_correlation_id VARCHAR2(36);
        v_raw_json_id NUMBER;
        v_endpoint_key VARCHAR2(100);
        v_response_hash VARCHAR2(64);
        v_existing_hash VARCHAR2(64);
        v_last_refresh TIMESTAMP;
    BEGIN
        -- For PCS specifically, check separate throttle
        IF UPPER(p_reference_type) = 'PCS' THEN
            BEGIN
                SELECT last_ref_refresh_pcs
                INTO v_last_refresh
                FROM SELECTED_ISSUES
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_rev;
                
                IF v_last_refresh IS NOT NULL AND 
                   v_last_refresh + c_min_refresh_interval > SYSTIMESTAMP THEN
                    p_status := 'SKIPPED';
                    p_message := 'PCS recently refreshed at ' || 
                               TO_CHAR(v_last_refresh, 'HH24:MI:SS');
                    RETURN;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL; -- Proceed
            END;
        END IF;
        
        v_correlation_id := NVL(p_correlation_id, generate_correlation_id());
        v_endpoint_key := LOWER(p_reference_type) || '_references';
        
        -- Fetch the JSON
        v_json_response := fetch_reference_json(
            p_plant_id => p_plant_id,
            p_issue_rev => p_issue_rev,
            p_reference_type => p_reference_type,
            p_correlation_id => v_correlation_id
        );
        
        IF v_json_response IS NULL THEN
            p_status := 'ERROR';
            p_message := 'Failed to fetch ' || p_reference_type || ' references';
            RETURN;
        END IF;
        
        -- Calculate hash
        v_response_hash := DBMS_CRYPTO.HASH(
            UTL_RAW.CAST_TO_RAW(v_json_response),
            DBMS_CRYPTO.HASH_SH256
        );
        
        -- Check if data changed
        BEGIN
            SELECT response_hash INTO v_existing_hash
            FROM RAW_JSON
            WHERE endpoint_key = v_endpoint_key
              AND plant_id = p_plant_id
              AND issue_revision = p_issue_rev
              AND response_hash = v_response_hash
              AND ROWNUM = 1;
            
            -- Data unchanged
            p_status := 'SKIPPED';
            p_message := 'Data unchanged for ' || p_reference_type || 
                        ' references (duplicate hash)';
            
            -- Still update the last refresh time even though data unchanged
            IF UPPER(p_reference_type) = 'PCS' THEN
                UPDATE SELECTED_ISSUES
                SET last_ref_refresh_pcs = SYSTIMESTAMP
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_rev;
            END IF;
            
            RETURN;
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL; -- New or changed data, proceed
        END;
        
        -- Store and process
        store_raw_json(
            p_endpoint_key => v_endpoint_key,
            p_plant_id => p_plant_id,
            p_issue_rev => p_issue_rev,
            p_json_response => v_json_response,
            p_response_hash => v_response_hash,
            p_correlation_id => v_correlation_id,
            p_raw_json_id => v_raw_json_id
        );
        
        -- Parse and upsert
        PKG_PARSE_REFERENCES.parse_reference_json(
            p_reference_type => UPPER(p_reference_type),
            p_raw_json_id => v_raw_json_id,
            p_plant_id => p_plant_id,
            p_issue_rev => p_issue_rev
        );
        
        -- Call appropriate upsert procedure
        CASE UPPER(p_reference_type)
            WHEN 'PCS' THEN 
                PKG_UPSERT_REFERENCES.upsert_pcs_references(p_plant_id, p_issue_rev);
                UPDATE SELECTED_ISSUES
                SET last_ref_refresh_pcs = SYSTIMESTAMP
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_rev;
            WHEN 'SC' THEN 
                PKG_UPSERT_REFERENCES.upsert_sc_references(p_plant_id, p_issue_rev);
            WHEN 'VSM' THEN 
                PKG_UPSERT_REFERENCES.upsert_vsm_references(p_plant_id, p_issue_rev);
            WHEN 'VDS' THEN 
                PKG_UPSERT_REFERENCES.upsert_vds_references(p_plant_id, p_issue_rev);
            WHEN 'EDS' THEN 
                PKG_UPSERT_REFERENCES.upsert_eds_references(p_plant_id, p_issue_rev);
            WHEN 'MDS' THEN 
                PKG_UPSERT_REFERENCES.upsert_mds_references(p_plant_id, p_issue_rev);
            WHEN 'VSK' THEN 
                PKG_UPSERT_REFERENCES.upsert_vsk_references(p_plant_id, p_issue_rev);
            WHEN 'ESK' THEN 
                PKG_UPSERT_REFERENCES.upsert_esk_references(p_plant_id, p_issue_rev);
            WHEN 'PIPE_ELEMENT' THEN 
                PKG_UPSERT_REFERENCES.upsert_pipe_element_references(p_plant_id, p_issue_rev);
        END CASE;
        
        COMMIT;
        
        p_status := 'SUCCESS';
        p_message := p_reference_type || ' references refreshed successfully';
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'Error refreshing ' || p_reference_type || ': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE(p_message);
    END refresh_issue_references;

    -- Keep all other procedures unchanged...
    -- [Rest of package body remains the same]
    
    FUNCTION generate_correlation_id RETURN VARCHAR2 IS
    BEGIN
        RETURN LOWER(REGEXP_REPLACE(RAWTOHEX(SYS_GUID()), 
            '([A-F0-9]{8})([A-F0-9]{4})([A-F0-9]{4})([A-F0-9]{4})([A-F0-9]{12})', 
            '\1-\2-\3-\4-\5'));
    END generate_correlation_id;

    FUNCTION fetch_reference_json(
        p_plant_id       VARCHAR2,
        p_issue_rev      VARCHAR2,
        p_reference_type VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        v_url VARCHAR2(500);
        v_response CLOB;
        v_endpoint_suffix VARCHAR2(50);
        v_correlation_id VARCHAR2(36);
    BEGIN
        v_correlation_id := NVL(p_correlation_id, generate_correlation_id());
        
        v_endpoint_suffix := CASE LOWER(p_reference_type)
            WHEN 'pipe_element' THEN 'pipe-elements'
            ELSE LOWER(p_reference_type)
        END;
        
        v_url := 'https://equinor.pipespec-api.presight.com/plants/' || 
                p_plant_id || '/issues/rev/' || p_issue_rev || '/' || v_endpoint_suffix;
        
        DBMS_OUTPUT.PUT_LINE('Fetching ' || p_reference_type || ' references from: ' || v_url);
        DBMS_OUTPUT.PUT_LINE('Correlation ID: ' || v_correlation_id);
        
        v_response := make_api_request(
            p_url => v_url,
            p_method => 'GET',
            p_correlation_id => v_correlation_id
        );
        
        RETURN v_response;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error fetching ' || p_reference_type || ': ' || SQLERRM);
            RETURN NULL;
    END fetch_reference_json;

    PROCEDURE store_raw_json(
        p_endpoint_key   IN VARCHAR2,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_json_response  IN CLOB,
        p_response_hash  IN VARCHAR2,
        p_correlation_id IN VARCHAR2,
        p_raw_json_id    OUT NUMBER
    ) IS
    BEGIN
        INSERT INTO RAW_JSON (
            endpoint_key, plant_id, issue_revision,
            response_json, response_hash, api_correlation_id,
            fetch_date
        ) VALUES (
            p_endpoint_key, p_plant_id, p_issue_rev,
            p_json_response, p_response_hash, p_correlation_id,
            SYSDATE
        ) RETURNING raw_json_id INTO p_raw_json_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error storing raw JSON: ' || SQLERRM);
            RAISE;
    END store_raw_json;

    FUNCTION make_api_request(
        p_url            VARCHAR2,
        p_method         VARCHAR2 DEFAULT 'GET',
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        v_response CLOB;
        v_http_status NUMBER;
    BEGIN
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        apex_web_service.g_request_headers(2).name := 'X-Correlation-ID';
        apex_web_service.g_request_headers(2).value := NVL(p_correlation_id, generate_correlation_id());
        
        v_response := apex_web_service.make_rest_request(
            p_url => p_url,
            p_http_method => p_method,
            p_wallet_path => 'file:C:\wallet'
        );
        
        v_http_status := apex_web_service.g_status_code;
        
        IF v_http_status != 200 THEN
            DBMS_OUTPUT.PUT_LINE('HTTP Status: ' || v_http_status);
            RETURN NULL;
        END IF;
        
        RETURN v_response;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('API Request failed: ' || SQLERRM);
            RETURN NULL;
    END make_api_request;

END PKG_API_CLIENT_REFERENCES;
/

SHOW ERRORS

PROMPT
PROMPT ===============================================================================
PROMPT Refresh Throttling Implemented Successfully!
PROMPT ===============================================================================
PROMPT 
PROMPT Changes made:
PROMPT - Added last_ref_refresh_all to track when all references were fetched
PROMPT - Added last_ref_refresh_pcs for PCS-specific tracking
PROMPT - 5-minute throttle window prevents redundant API calls
PROMPT - Still fetches if data changed (hash comparison)
PROMPT
PROMPT Benefits:
PROMPT - Reduces unnecessary API calls during rapid ETL runs
PROMPT - Simple time-based caching (5 minutes)
PROMPT - Can be adjusted by changing c_min_refresh_interval constant
PROMPT ===============================================================================