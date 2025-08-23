-- ===============================================================================
-- Alternative pkg_api_client Implementation using UTL_HTTP
-- Use this if Oracle APEX is not available
-- ===============================================================================

CREATE OR REPLACE PACKAGE BODY pkg_api_client AS
    
    -- Fetch plants data from API using UTL_HTTP
    FUNCTION fetch_plants_json RETURN CLOB IS
        v_response CLOB;
        v_api_base_url VARCHAR2(500);
        v_url VARCHAR2(1000);
        v_req UTL_HTTP.REQ;
        v_resp UTL_HTTP.RESP;
        v_buffer VARCHAR2(32767);
    BEGIN
        -- Get API base URL from settings
        SELECT setting_value INTO v_api_base_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        -- Build full URL
        v_url := v_api_base_url || 'plants';
        
        -- Initialize CLOB
        DBMS_LOB.CREATETEMPORARY(v_response, TRUE);
        
        -- Make HTTP request
        v_req := UTL_HTTP.BEGIN_REQUEST(v_url, 'GET');
        UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
        
        v_resp := UTL_HTTP.GET_RESPONSE(v_req);
        
        -- Check response status
        IF v_resp.status_code != 200 THEN
            UTL_HTTP.END_RESPONSE(v_resp);
            RAISE_APPLICATION_ERROR(-20001, 'HTTP Error: ' || v_resp.status_code || ' ' || v_resp.reason_phrase);
        END IF;
        
        -- Read response body
        BEGIN
            LOOP
                UTL_HTTP.READ_TEXT(v_resp, v_buffer, 32767);
                DBMS_LOB.WRITEAPPEND(v_response, LENGTH(v_buffer), v_buffer);
            END LOOP;
        EXCEPTION
            WHEN UTL_HTTP.END_OF_BODY THEN
                UTL_HTTP.END_RESPONSE(v_resp);
        END;
        
        RETURN v_response;
    EXCEPTION
        WHEN OTHERS THEN
            IF v_resp.status_code IS NOT NULL THEN
                UTL_HTTP.END_RESPONSE(v_resp);
            END IF;
            RAISE_APPLICATION_ERROR(-20002, 'Error fetching plants data: ' || SQLERRM);
    END fetch_plants_json;
    
    -- Fetch issues data for a specific plant using UTL_HTTP
    FUNCTION fetch_issues_json(p_plant_id VARCHAR2) RETURN CLOB IS
        v_response CLOB;
        v_api_base_url VARCHAR2(500);
        v_url VARCHAR2(1000);
        v_req UTL_HTTP.REQ;
        v_resp UTL_HTTP.RESP;
        v_buffer VARCHAR2(32767);
    BEGIN
        -- Get API base URL from settings
        SELECT setting_value INTO v_api_base_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        -- Build full URL
        v_url := v_api_base_url || 'plants/' || p_plant_id || '/issues';
        
        -- Initialize CLOB
        DBMS_LOB.CREATETEMPORARY(v_response, TRUE);
        
        -- Make HTTP request
        v_req := UTL_HTTP.BEGIN_REQUEST(v_url, 'GET');
        UTL_HTTP.SET_HEADER(v_req, 'Accept', 'application/json');
        
        v_resp := UTL_HTTP.GET_RESPONSE(v_req);
        
        -- Check response status
        IF v_resp.status_code != 200 THEN
            UTL_HTTP.END_RESPONSE(v_resp);
            -- Return empty CLOB for 404 (plant has no issues)
            IF v_resp.status_code = 404 THEN
                RETURN v_response;
            END IF;
            RAISE_APPLICATION_ERROR(-20003, 'HTTP Error: ' || v_resp.status_code || ' ' || v_resp.reason_phrase);
        END IF;
        
        -- Read response body
        BEGIN
            LOOP
                UTL_HTTP.READ_TEXT(v_resp, v_buffer, 32767);
                DBMS_LOB.WRITEAPPEND(v_response, LENGTH(v_buffer), v_buffer);
            END LOOP;
        EXCEPTION
            WHEN UTL_HTTP.END_OF_BODY THEN
                UTL_HTTP.END_RESPONSE(v_resp);
        END;
        
        RETURN v_response;
    EXCEPTION
        WHEN OTHERS THEN
            IF v_resp.status_code IS NOT NULL THEN
                UTL_HTTP.END_RESPONSE(v_resp);
            END IF;
            RAISE_APPLICATION_ERROR(-20004, 'Error fetching issues for plant ' || p_plant_id || ': ' || SQLERRM);
    END fetch_issues_json;
    
    -- Calculate SHA256 hash
    FUNCTION calculate_sha256(p_input CLOB) RETURN VARCHAR2 IS
        v_hash RAW(32);
    BEGIN
        v_hash := SYS.DBMS_CRYPTO.HASH(
            UTL_RAW.CAST_TO_RAW(p_input),
            SYS.DBMS_CRYPTO.HASH_SH256
        );
        RETURN LOWER(RAWTOHEX(v_hash));
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20005, 'Error calculating SHA256: ' || SQLERRM);
    END calculate_sha256;
    
    -- Refresh plants data from API
    PROCEDURE refresh_plants_from_api(
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_json_response CLOB;
        v_response_hash VARCHAR2(64);
        v_raw_json_id NUMBER;
        v_run_id NUMBER;
        v_start_time TIMESTAMP;
    BEGIN
        -- Start ETL run
        v_start_time := SYSTIMESTAMP;
        INSERT INTO ETL_RUN_LOG (run_type, endpoint_key, start_time, status, initiated_by)
        VALUES ('PLANTS_API_REFRESH', 'plants', v_start_time, 'RUNNING', USER)
        RETURNING run_id INTO v_run_id;
        
        BEGIN
            -- Fetch data from API
            v_json_response := fetch_plants_json();
            
            -- Calculate hash
            v_response_hash := calculate_sha256(v_json_response);
            
            -- Check if this response is a duplicate
            IF pkg_raw_ingest.is_duplicate_hash(v_response_hash) THEN
                -- Update run log
                UPDATE ETL_RUN_LOG 
                SET end_time = SYSTIMESTAMP,
                    status = 'SUCCESS',
                    notes = 'Data unchanged (duplicate hash)',
                    duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                WHERE run_id = v_run_id;
                
                p_status := 'SUCCESS';
                p_message := 'Plants data unchanged (duplicate hash detected)';
                COMMIT;
                RETURN;
            END IF;
            
            -- Insert into RAW_JSON
            v_raw_json_id := pkg_raw_ingest.insert_raw_json(
                p_endpoint_key => 'plants',
                p_plant_id => NULL,
                p_issue_revision => NULL,
                p_api_url => 'plants',
                p_response_json => v_json_response,
                p_response_hash => v_response_hash
            );
            
            -- Parse JSON to staging
            pkg_parse_plants.parse_plants_json(v_raw_json_id);
            
            -- Upsert to core
            pkg_upsert_plants.upsert_plants();
            
            -- Update run log
            UPDATE ETL_RUN_LOG 
            SET end_time = SYSTIMESTAMP,
                status = 'SUCCESS',
                notes = 'Plants refreshed successfully',
                duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
            WHERE run_id = v_run_id;
            
            COMMIT;
            
            p_status := 'SUCCESS';
            p_message := 'Plants data refreshed successfully from API';
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Log error
                INSERT INTO ETL_ERROR_LOG (
                    run_id, endpoint_key, error_timestamp, error_type, 
                    error_code, error_message, error_stack
                ) VALUES (
                    v_run_id, 'plants', SYSTIMESTAMP, 'API_REFRESH_ERROR',
                    SQLCODE, SUBSTR(SQLERRM, 1, 4000), DBMS_UTILITY.FORMAT_ERROR_STACK()
                );
                
                -- Update run log
                UPDATE ETL_RUN_LOG 
                SET end_time = SYSTIMESTAMP,
                    status = 'FAILED',
                    notes = SUBSTR(SQLERRM, 1, 4000),
                    duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                WHERE run_id = v_run_id;
                
                ROLLBACK;
                
                p_status := 'ERROR';
                p_message := 'Failed to refresh plants: ' || SUBSTR(SQLERRM, 1, 3900);
                RAISE;
        END;
    END refresh_plants_from_api;
    
    -- Refresh issues data for a specific plant
    PROCEDURE refresh_issues_from_api(
        p_plant_id VARCHAR2,
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_json_response CLOB;
        v_response_hash VARCHAR2(64);
        v_raw_json_id NUMBER;
        v_run_id NUMBER;
        v_start_time TIMESTAMP;
    BEGIN
        -- Start ETL run
        v_start_time := SYSTIMESTAMP;
        INSERT INTO ETL_RUN_LOG (run_type, endpoint_key, plant_id, start_time, status, initiated_by)
        VALUES ('ISSUES_API_REFRESH', 'issues', p_plant_id, v_start_time, 'RUNNING', USER)
        RETURNING run_id INTO v_run_id;
        
        BEGIN
            -- Fetch data from API
            v_json_response := fetch_issues_json(p_plant_id);
            
            -- Check if response is empty (plant has no issues)
            IF v_json_response IS NULL OR DBMS_LOB.GETLENGTH(v_json_response) = 0 THEN
                -- Update run log
                UPDATE ETL_RUN_LOG 
                SET end_time = SYSTIMESTAMP,
                    status = 'SUCCESS',
                    notes = 'No issues found for plant',
                    duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                WHERE run_id = v_run_id;
                
                p_status := 'SUCCESS';
                p_message := 'No issues found for plant ' || p_plant_id;
                COMMIT;
                RETURN;
            END IF;
            
            -- Calculate hash
            v_response_hash := calculate_sha256(v_json_response);
            
            -- Check if this response is a duplicate
            IF pkg_raw_ingest.is_duplicate_hash(v_response_hash) THEN
                -- Update run log
                UPDATE ETL_RUN_LOG 
                SET end_time = SYSTIMESTAMP,
                    status = 'SUCCESS',
                    notes = 'Data unchanged (duplicate hash)',
                    duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                WHERE run_id = v_run_id;
                
                p_status := 'SUCCESS';
                p_message := 'Issues data unchanged for plant ' || p_plant_id || ' (duplicate hash detected)';
                COMMIT;
                RETURN;
            END IF;
            
            -- Insert into RAW_JSON
            v_raw_json_id := pkg_raw_ingest.insert_raw_json(
                p_endpoint_key => 'issues',
                p_plant_id => p_plant_id,
                p_issue_revision => NULL,
                p_api_url => 'plants/' || p_plant_id || '/issues',
                p_response_json => v_json_response,
                p_response_hash => v_response_hash
            );
            
            -- Parse JSON to staging
            pkg_parse_issues.parse_issues_json(v_raw_json_id, p_plant_id);
            
            -- Upsert to core
            pkg_upsert_issues.upsert_issues();
            
            -- Update run log
            UPDATE ETL_RUN_LOG 
            SET end_time = SYSTIMESTAMP,
                status = 'SUCCESS',
                notes = 'Issues refreshed successfully',
                duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
            WHERE run_id = v_run_id;
            
            COMMIT;
            
            p_status := 'SUCCESS';
            p_message := 'Issues data refreshed successfully for plant ' || p_plant_id;
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Log error
                INSERT INTO ETL_ERROR_LOG (
                    run_id, endpoint_key, plant_id, error_timestamp, error_type, 
                    error_code, error_message, error_stack
                ) VALUES (
                    v_run_id, 'issues', p_plant_id, SYSTIMESTAMP, 'API_REFRESH_ERROR',
                    SQLCODE, SUBSTR(SQLERRM, 1, 4000), DBMS_UTILITY.FORMAT_ERROR_STACK()
                );
                
                -- Update run log
                UPDATE ETL_RUN_LOG 
                SET end_time = SYSTIMESTAMP,
                    status = 'FAILED',
                    notes = SUBSTR(SQLERRM, 1, 4000),
                    duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                WHERE run_id = v_run_id;
                
                ROLLBACK;
                
                p_status := 'ERROR';
                p_message := 'Failed to refresh issues for plant ' || p_plant_id || ': ' || SUBSTR(SQLERRM, 1, 3900);
                RAISE;
        END;
    END refresh_issues_from_api;
    
END pkg_api_client;
/

-- ===============================================================================
-- Additional Setup Required for UTL_HTTP
-- ===============================================================================
-- 1. Grant privileges (run as SYS/DBA):
--    GRANT EXECUTE ON UTL_HTTP TO TR2000_STAGING;
--    GRANT EXECUTE ON SYS.DBMS_CRYPTO TO TR2000_STAGING;
--
-- 2. Create Network ACL (run as SYS/DBA):
BEGIN
    -- Create ACL
    DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(
        acl => 'tr2000_api_acl.xml',
        description => 'ACL for TR2000 API access',
        principal => 'TR2000_STAGING',
        is_grant => TRUE,
        privilege => 'connect'
    );
    
    -- Add resolve privilege
    DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(
        acl => 'tr2000_api_acl.xml',
        principal => 'TR2000_STAGING',
        is_grant => TRUE,
        privilege => 'resolve'
    );
    
    -- Assign ACL to TR2000 API host
    DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
        acl => 'tr2000_api_acl.xml',
        host => 'tr2000api.equinor.com',
        lower_port => 443,
        upper_port => 443
    );
    
    COMMIT;
END;
/
-- ===============================================================================