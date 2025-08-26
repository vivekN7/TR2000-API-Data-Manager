-- ===============================================================================
-- Enhanced pkg_api_client with GUID Support
-- Date: 2025-08-26
-- Purpose: Add correlation tracking and idempotency to API operations
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_api_client AS
    -- Existing functions remain for compatibility
    FUNCTION fetch_plants_json RETURN CLOB;
    FUNCTION fetch_issues_json(p_plant_id VARCHAR2) RETURN CLOB;
    FUNCTION calculate_sha256(p_input CLOB) RETURN VARCHAR2;
    
    -- Enhanced functions with GUID support
    FUNCTION fetch_plants_json_v2(
        p_correlation_id  VARCHAR2 DEFAULT NULL,
        p_idempotency_key VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;
    
    FUNCTION fetch_issues_json_v2(
        p_plant_id        VARCHAR2,
        p_correlation_id  VARCHAR2 DEFAULT NULL,
        p_idempotency_key VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;
    
    -- Main procedures - enhanced with optional GUID parameters
    PROCEDURE refresh_plants_from_api(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL,
        p_idempotency_key IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE refresh_issues_from_api(
        p_plant_id        IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL,
        p_idempotency_key IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE refresh_selected_issues(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );
    
    -- Helper function
    FUNCTION get_base_url RETURN VARCHAR2;
    
END pkg_api_client;
/

CREATE OR REPLACE PACKAGE BODY pkg_api_client AS

    -- Private function to get base URL
    FUNCTION get_base_url RETURN VARCHAR2 IS
        v_url VARCHAR2(500);
    BEGIN
        SELECT setting_value INTO v_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        RETURN v_url;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Default URL if not configured
            RETURN 'https://equinor.pipespec-api.presight.com';
    END get_base_url;

    -- Enhanced fetch with correlation tracking
    FUNCTION fetch_plants_json_v2(
        p_correlation_id  VARCHAR2 DEFAULT NULL,
        p_idempotency_key VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_response CLOB;
        l_url VARCHAR2(500);
        l_correlation_id VARCHAR2(36);
    BEGIN
        -- Use provided correlation ID or generate new
        l_correlation_id := NVL(p_correlation_id, PKG_GUID_UTILS.create_correlation_id());
        
        -- Check for duplicate operation
        IF p_idempotency_key IS NOT NULL THEN
            IF PKG_GUID_UTILS.is_duplicate_operation(p_idempotency_key) THEN
                -- Return cached result
                SELECT response_body INTO l_response
                FROM API_TRANSACTIONS
                WHERE idempotency_key = p_idempotency_key
                AND status = 'SUCCESS'
                AND ROWNUM = 1;
                RETURN l_response;
            END IF;
        END IF;
        
        -- Log API call start
        PKG_GUID_UTILS.log_api_transaction(
            p_correlation_id => l_correlation_id,
            p_operation_type => 'FETCH_PLANTS',
            p_request_url => get_base_url() || '/plants',
            p_request_method => 'GET',
            p_idempotency_key => p_idempotency_key
        );
        
        BEGIN
            -- Make the actual API call
            l_url := get_base_url() || '/plants';
            l_response := APEX_WEB_SERVICE.make_rest_request(
                p_url => l_url,
                p_http_method => 'GET',
                p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
                p_wallet_pwd => 'WalletPass123'
            );
            
            -- Log success
            PKG_GUID_UTILS.update_api_response(
                p_correlation_id => l_correlation_id,
                p_response_code => 200,
                p_response_body => l_response,
                p_status => 'SUCCESS'
            );
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Log failure
                PKG_GUID_UTILS.update_api_response(
                    p_correlation_id => l_correlation_id,
                    p_response_code => 500,
                    p_response_body => NULL,
                    p_status => 'FAILED',
                    p_error_message => SQLERRM
                );
                RAISE;
        END;
        
        RETURN l_response;
    END fetch_plants_json_v2;
    
    -- Keep existing function for compatibility
    FUNCTION fetch_plants_json RETURN CLOB IS
    BEGIN
        RETURN fetch_plants_json_v2(NULL, NULL);
    END fetch_plants_json;
    
    -- Enhanced fetch issues with correlation tracking
    FUNCTION fetch_issues_json_v2(
        p_plant_id        VARCHAR2,
        p_correlation_id  VARCHAR2 DEFAULT NULL,
        p_idempotency_key VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_response CLOB;
        l_url VARCHAR2(500);
        l_correlation_id VARCHAR2(36);
    BEGIN
        l_correlation_id := NVL(p_correlation_id, PKG_GUID_UTILS.create_correlation_id());
        
        IF p_idempotency_key IS NOT NULL THEN
            IF PKG_GUID_UTILS.is_duplicate_operation(p_idempotency_key) THEN
                SELECT response_body INTO l_response
                FROM API_TRANSACTIONS
                WHERE idempotency_key = p_idempotency_key
                AND status = 'SUCCESS'
                AND ROWNUM = 1;
                RETURN l_response;
            END IF;
        END IF;
        
        PKG_GUID_UTILS.log_api_transaction(
            p_correlation_id => l_correlation_id,
            p_operation_type => 'FETCH_ISSUES',
            p_request_url => get_base_url() || '/plants/' || p_plant_id || '/issues',
            p_request_method => 'GET',
            p_idempotency_key => p_idempotency_key
        );
        
        BEGIN
            l_url := get_base_url() || '/plants/' || p_plant_id || '/issues';
            l_response := APEX_WEB_SERVICE.make_rest_request(
                p_url => l_url,
                p_http_method => 'GET',
                p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
                p_wallet_pwd => 'WalletPass123'
            );
            
            PKG_GUID_UTILS.update_api_response(
                p_correlation_id => l_correlation_id,
                p_response_code => 200,
                p_response_body => l_response,
                p_status => 'SUCCESS'
            );
            
        EXCEPTION
            WHEN OTHERS THEN
                PKG_GUID_UTILS.update_api_response(
                    p_correlation_id => l_correlation_id,
                    p_response_code => 500,
                    p_response_body => NULL,
                    p_status => 'FAILED',
                    p_error_message => SQLERRM
                );
                RAISE;
        END;
        
        RETURN l_response;
    END fetch_issues_json_v2;
    
    -- Keep existing function for compatibility
    FUNCTION fetch_issues_json(p_plant_id VARCHAR2) RETURN CLOB IS
    BEGIN
        RETURN fetch_issues_json_v2(p_plant_id, NULL, NULL);
    END fetch_issues_json;
    
    -- Calculate SHA256 hash
    FUNCTION calculate_sha256(p_input CLOB) RETURN VARCHAR2 IS
        l_hash RAW(32);
        l_blob BLOB;
        l_dest_offset INTEGER := 1;
        l_src_offset INTEGER := 1;
        l_lang_context INTEGER := DBMS_LOB.default_lang_ctx;
        l_warning INTEGER;
    BEGIN
        DBMS_LOB.createtemporary(l_blob, TRUE);
        DBMS_LOB.convertToBlob(
            dest_lob => l_blob,
            src_clob => p_input,
            amount => DBMS_LOB.lobmaxsize,
            dest_offset => l_dest_offset,
            src_offset => l_src_offset,
            blob_csid => DBMS_LOB.default_csid,
            lang_context => l_lang_context,
            warning => l_warning
        );
        
        l_hash := DBMS_CRYPTO.hash(l_blob, DBMS_CRYPTO.HASH_SH256);
        DBMS_LOB.freetemporary(l_blob);
        
        RETURN RAWTOHEX(l_hash);
    END calculate_sha256;
    
    -- Enhanced refresh plants procedure
    PROCEDURE refresh_plants_from_api(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL,
        p_idempotency_key IN VARCHAR2 DEFAULT NULL
    ) IS
        l_json CLOB;
        l_hash VARCHAR2(64);
        l_raw_json_id NUMBER;
        l_correlation_id VARCHAR2(36);
        l_run_id NUMBER;
    BEGIN
        -- Generate or use correlation ID
        l_correlation_id := NVL(p_correlation_id, PKG_GUID_UTILS.create_correlation_id());
        
        -- Start ETL run logging with correlation
        INSERT INTO ETL_RUN_LOG (
            run_type, endpoint_key, start_time, status
        ) VALUES (
            'PLANTS_API_REFRESH', 'plants', SYSTIMESTAMP, 'RUNNING'
        )
        RETURNING run_id INTO l_run_id;
        
        -- Fetch with correlation tracking
        l_json := fetch_plants_json_v2(l_correlation_id, p_idempotency_key);
        l_hash := calculate_sha256(l_json);
        
        -- Store in RAW_JSON with correlation
        IF NOT pkg_raw_ingest.is_duplicate_hash(l_hash) THEN
            INSERT INTO RAW_JSON (
                endpoint_key,
                api_url,
                response_json,
                response_hash,
                correlation_id,
                transaction_guid
            ) VALUES (
                'plants',
                get_base_url() || '/plants',
                l_json,
                l_hash,
                l_correlation_id,
                SYS_GUID()
            )
            RETURNING raw_json_id INTO l_raw_json_id;
            
            -- Continue with parsing
            pkg_parse_plants.parse_plants_json(l_raw_json_id);
            pkg_upsert_plants.upsert_plants();
            
            p_status := 'SUCCESS';
            p_message := 'Plants refreshed. Correlation: ' || l_correlation_id;
        ELSE
            p_status := 'SKIPPED';
            p_message := 'No changes detected. Correlation: ' || l_correlation_id;
        END IF;
        
        -- Update ETL run log
        UPDATE ETL_RUN_LOG
        SET end_time = SYSTIMESTAMP,
            status = p_status,
            notes = p_message
        WHERE run_id = l_run_id;
        
        COMMIT;
    END refresh_plants_from_api;
    
    -- Enhanced refresh issues procedure
    PROCEDURE refresh_issues_from_api(
        p_plant_id        IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL,
        p_idempotency_key IN VARCHAR2 DEFAULT NULL
    ) IS
        l_json CLOB;
        l_hash VARCHAR2(64);
        l_raw_json_id NUMBER;
        l_correlation_id VARCHAR2(36);
        l_run_id NUMBER;
    BEGIN
        l_correlation_id := NVL(p_correlation_id, PKG_GUID_UTILS.create_correlation_id());
        
        INSERT INTO ETL_RUN_LOG (
            run_type, endpoint_key, start_time, status
        ) VALUES (
            'ISSUES_API_REFRESH', 'issues', SYSTIMESTAMP, 'RUNNING'
        )
        RETURNING run_id INTO l_run_id;
        
        l_json := fetch_issues_json_v2(p_plant_id, l_correlation_id, p_idempotency_key);
        l_hash := calculate_sha256(l_json);
        
        IF NOT pkg_raw_ingest.is_duplicate_hash(l_hash) THEN
            INSERT INTO RAW_JSON (
                endpoint_key,
                api_url,
                response_json,
                response_hash,
                plant_id,
                correlation_id,
                transaction_guid
            ) VALUES (
                'issues',
                get_base_url() || '/plants/' || p_plant_id || '/issues',
                l_json,
                l_hash,
                p_plant_id,
                l_correlation_id,
                SYS_GUID()
            )
            RETURNING raw_json_id INTO l_raw_json_id;
            
            pkg_parse_issues.parse_issues_json(l_raw_json_id, p_plant_id);
            pkg_upsert_issues.upsert_issues();
            
            p_status := 'SUCCESS';
            p_message := 'Issues refreshed for plant ' || p_plant_id || '. Correlation: ' || l_correlation_id;
        ELSE
            p_status := 'SKIPPED';
            p_message := 'No changes for plant ' || p_plant_id || '. Correlation: ' || l_correlation_id;
        END IF;
        
        UPDATE ETL_RUN_LOG
        SET end_time = SYSTIMESTAMP,
            status = p_status,
            notes = p_message
        WHERE run_id = l_run_id;
        
        COMMIT;
    END refresh_issues_from_api;
    
    -- Refresh all selected issues
    PROCEDURE refresh_selected_issues(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    ) IS
        l_plant_count NUMBER := 0;
        l_success_count NUMBER := 0;
        l_skip_count NUMBER := 0;
        l_fail_count NUMBER := 0;
        l_temp_status VARCHAR2(50);
        l_temp_message VARCHAR2(4000);
        l_correlation_id VARCHAR2(36);
    BEGIN
        l_correlation_id := NVL(p_correlation_id, PKG_GUID_UTILS.create_correlation_id());
        
        FOR plant_rec IN (
            SELECT DISTINCT plant_id 
            FROM SELECTION_LOADER 
            WHERE is_active = 'Y'
        ) LOOP
            l_plant_count := l_plant_count + 1;
            
            BEGIN
                refresh_issues_from_api(
                    p_plant_id => plant_rec.plant_id,
                    p_status => l_temp_status,
                    p_message => l_temp_message,
                    p_correlation_id => l_correlation_id
                );
                
                IF l_temp_status = 'SUCCESS' THEN
                    l_success_count := l_success_count + 1;
                ELSIF l_temp_status = 'SKIPPED' THEN
                    l_skip_count := l_skip_count + 1;
                END IF;
                
            EXCEPTION
                WHEN OTHERS THEN
                    l_fail_count := l_fail_count + 1;
                    CONTINUE;
            END;
        END LOOP;
        
        p_status := 'COMPLETE';
        p_message := 'Processed ' || l_plant_count || ' plants. ' ||
                     'Success: ' || l_success_count || ', ' ||
                     'Skipped: ' || l_skip_count || ', ' ||
                     'Failed: ' || l_fail_count ||
                     '. Correlation: ' || l_correlation_id;
                     
    END refresh_selected_issues;

END pkg_api_client;
/

PROMPT Enhanced pkg_api_client with GUID support created successfully.