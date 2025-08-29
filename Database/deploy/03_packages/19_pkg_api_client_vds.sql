-- ===============================================================================
-- PKG_API_CLIENT_VDS - API Client for VDS Data
-- Session 18: VDS Details Implementation
-- Purpose: Fetch VDS data from API with official revision strategy
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_api_client_vds AS
    
    -- Fetch all VDS list (44k records - single API call)
    PROCEDURE fetch_vds_list(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- Fetch VDS details for specific VDS/revision
    PROCEDURE fetch_vds_details(
        p_vds_name  IN VARCHAR2,
        p_revision  IN VARCHAR2,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- Fetch VDS details for test records only (2 records)
    PROCEDURE fetch_test_vds_details(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- Fetch VDS details for all official revisions
    PROCEDURE fetch_all_official_vds_details(
        p_max_calls IN NUMBER DEFAULT 500,  -- Safety limit
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
END pkg_api_client_vds;
/

CREATE OR REPLACE PACKAGE BODY pkg_api_client_vds AS

    -- =========================================================================
    -- Fetch all VDS list (single API call for 44k records)
    -- =========================================================================
    PROCEDURE fetch_vds_list(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_url           VARCHAR2(500);
        v_response      CLOB;
        v_raw_json_id   NUMBER;
        v_start_time    TIMESTAMP := SYSTIMESTAMP;
        v_http_status   NUMBER;
        v_run_id        NUMBER;
    BEGIN
        -- Log to ETL_RUN_LOG for statistics
        INSERT INTO ETL_RUN_LOG (
            run_type, endpoint_key, 
            start_time, status, initiated_by
        ) VALUES (
            'VDS_LIST_REFRESH', 'vds_list',
            v_start_time, 'RUNNING', USER
        )
        RETURNING run_id INTO v_run_id;
        p_status := 'STARTED';
        
        -- Get base URL from settings
        SELECT setting_value || '/vds'
        INTO v_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        DBMS_OUTPUT.PUT_LINE('Fetching VDS list from: ' || v_url);
        DBMS_OUTPUT.PUT_LINE('WARNING: This will fetch 44,000+ records and may take several minutes...');
        
        -- Make API call using APEX_WEB_SERVICE
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        
        v_response := apex_web_service.make_rest_request(
            p_url         => v_url,
            p_http_method => 'GET',
            p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
            p_wallet_pwd  => 'WalletPass123'
        );
        
        v_http_status := apex_web_service.g_status_code;
        
        IF v_http_status != 200 THEN
            p_status := 'ERROR';
            p_message := 'HTTP ' || v_http_status || ' from API';
            RETURN;
        END IF;
        
        -- Store in RAW_JSON
        INSERT INTO RAW_JSON (
            endpoint,
            payload,
            api_call_timestamp,
            created_date
        ) VALUES (
            'VDS_LIST',
            v_response,
            SYSTIMESTAMP,
            SYSDATE
        ) RETURNING raw_json_id INTO v_raw_json_id;
        
        COMMIT;
        
        -- Parse the JSON
        pkg_parse_vds.parse_vds_list(v_raw_json_id);
        
        -- Upsert to core tables with batch processing
        pkg_upsert_vds.upsert_vds_list(p_batch_size => 1000);
        
        -- Mark missing as invalid
        pkg_upsert_vds.invalidate_missing_vds;
        
        p_status := 'SUCCESS';
        p_message := 'VDS list loaded in ' || 
            ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)), 2) || ' seconds. ' ||
            pkg_upsert_vds.get_vds_stats;
        
        -- Update ETL_RUN_LOG with success
        UPDATE ETL_RUN_LOG
        SET end_time = SYSTIMESTAMP,
            status = p_status,
            records_processed = (SELECT COUNT(*) FROM VDS_LIST WHERE is_valid = 'Y'),
            records_inserted = (SELECT COUNT(*) FROM VDS_LIST WHERE is_valid = 'Y'),
            duration_seconds = EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)) +
                             EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_start_time)) * 60,
            notes = p_message
        WHERE run_id = v_run_id;
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
            ROLLBACK;
            
            -- Update ETL_RUN_LOG with error
            IF v_run_id IS NOT NULL THEN
                UPDATE ETL_RUN_LOG
                SET end_time = SYSTIMESTAMP,
                    status = 'ERROR',
                    error_count = 1,
                    duration_seconds = EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)) +
                                     EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_start_time)) * 60,
                    notes = p_message
                WHERE run_id = v_run_id;
                
                COMMIT;
            END IF;
    END fetch_vds_list;

    -- =========================================================================
    -- Fetch VDS details for specific VDS/revision
    -- =========================================================================
    PROCEDURE fetch_vds_details(
        p_vds_name  IN VARCHAR2,
        p_revision  IN VARCHAR2,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_url           VARCHAR2(500);
        v_response      CLOB;
        v_raw_json_id   NUMBER;
        v_http_status   NUMBER;
    BEGIN
        -- Build URL with VDS name and revision
        SELECT setting_value || '/vds/' || p_vds_name || '/rev/' || p_revision
        INTO v_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        DBMS_OUTPUT.PUT_LINE('Fetching VDS details: ' || v_url);
        
        -- Make API call
        apex_web_service.g_request_headers.DELETE;
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
        
        v_response := apex_web_service.make_rest_request(
            p_url         => v_url,
            p_http_method => 'GET',
            p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
            p_wallet_pwd  => 'WalletPass123'
        );
        
        v_http_status := apex_web_service.g_status_code;
        
        IF v_http_status != 200 THEN
            p_status := 'ERROR';
            p_message := 'HTTP ' || v_http_status || ' for VDS ' || p_vds_name || '/' || p_revision;
            RETURN;
        END IF;
        
        -- Store in RAW_JSON
        INSERT INTO RAW_JSON (
            endpoint,
            payload,
            api_call_timestamp,
            created_date
        ) VALUES (
            'VDS_DETAILS',
            v_response,
            SYSTIMESTAMP,
            SYSDATE
        ) RETURNING raw_json_id INTO v_raw_json_id;
        
        COMMIT;
        
        -- Parse the JSON
        pkg_parse_vds.parse_vds_details(v_raw_json_id, p_vds_name, p_revision);
        
        -- Upsert to core tables
        pkg_upsert_vds.upsert_vds_details(p_vds_name, p_revision);
        
        p_status := 'SUCCESS';
        p_message := 'VDS details loaded for ' || p_vds_name || '/' || p_revision;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
            ROLLBACK;
    END fetch_vds_details;

    -- =========================================================================
    -- Fetch VDS details for test records only (2 records)
    -- =========================================================================
    PROCEDURE fetch_test_vds_details(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_count         NUMBER := 0;
        v_success       NUMBER := 0;
        v_failed        NUMBER := 0;
        v_status        VARCHAR2(50);
        v_msg           VARCHAR2(4000);
        
        -- Test VDS records
        CURSOR c_test_vds IS
            SELECT 'GVAD151I' as vds_name, 'A' as revision FROM DUAL
            UNION ALL
            SELECT 'LYDD151J' as vds_name, 'A' as revision FROM DUAL;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Fetching test VDS details (2 records only)...');
        
        FOR rec IN c_test_vds LOOP
            v_count := v_count + 1;
            
            -- Fetch details for this VDS
            fetch_vds_details(
                p_vds_name => rec.vds_name,
                p_revision => rec.revision,
                p_status   => v_status,
                p_message  => v_msg
            );
            
            IF v_status = 'SUCCESS' THEN
                v_success := v_success + 1;
                DBMS_OUTPUT.PUT_LINE('  ' || rec.vds_name || '/' || rec.revision || ': SUCCESS');
            ELSE
                v_failed := v_failed + 1;
                DBMS_OUTPUT.PUT_LINE('  ' || rec.vds_name || '/' || rec.revision || ': FAILED - ' || v_msg);
            END IF;
        END LOOP;
        
        p_status := 'SUCCESS';
        p_message := 'Test VDS details: ' || v_success || ' succeeded, ' || v_failed || ' failed out of ' || v_count;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
    END fetch_test_vds_details;

    -- =========================================================================
    -- Fetch VDS details for all official revisions
    -- =========================================================================
    PROCEDURE fetch_all_official_vds_details(
        p_max_calls IN NUMBER DEFAULT 500,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_count         NUMBER := 0;
        v_success       NUMBER := 0;
        v_failed        NUMBER := 0;
        v_status        VARCHAR2(50);
        v_msg           VARCHAR2(4000);
        v_loading_mode  VARCHAR2(50);
        
        -- Get VDS to load based on mode
        CURSOR c_vds_to_load IS
            SELECT DISTINCT 
                   vr.vds_name,
                   vr.official_revision as revision
            FROM VDS_REFERENCES vr
            WHERE vr.is_valid = 'Y'
              AND vr.official_revision IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM VDS_DETAILS vd
                  WHERE vd.vds_name = vr.vds_name
                    AND vd.revision = vr.official_revision
                    AND vd.is_valid = 'Y'
              )
            ORDER BY vr.vds_name;
    BEGIN
        -- Check loading mode
        BEGIN
            SELECT setting_value 
            INTO v_loading_mode
            FROM CONTROL_SETTINGS 
            WHERE setting_key = 'VDS_LOADING_MODE';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_loading_mode := 'OFFICIAL_ONLY';
        END;
        
        IF v_loading_mode != 'OFFICIAL_ONLY' THEN
            p_status := 'SKIPPED';
            p_message := 'VDS_LOADING_MODE is not OFFICIAL_ONLY. Set to ALL_REVISIONS if needed.';
            RETURN;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Fetching VDS details for official revisions only...');
        DBMS_OUTPUT.PUT_LINE('Max API calls allowed: ' || p_max_calls);
        
        FOR rec IN c_vds_to_load LOOP
            EXIT WHEN v_count >= p_max_calls;
            
            v_count := v_count + 1;
            
            -- Fetch details for this VDS
            fetch_vds_details(
                p_vds_name => rec.vds_name,
                p_revision => rec.revision,
                p_status   => v_status,
                p_message  => v_msg
            );
            
            IF v_status = 'SUCCESS' THEN
                v_success := v_success + 1;
            ELSE
                v_failed := v_failed + 1;
            END IF;
            
            -- Progress update every 10 records
            IF MOD(v_count, 10) = 0 THEN
                DBMS_OUTPUT.PUT_LINE('Progress: ' || v_count || ' VDS processed (' || 
                    v_success || ' success, ' || v_failed || ' failed)');
            END IF;
        END LOOP;
        
        p_status := 'SUCCESS';
        p_message := 'VDS details fetched: ' || v_success || ' succeeded, ' || 
                     v_failed || ' failed out of ' || v_count || ' API calls';
        
        IF v_count >= p_max_calls THEN
            p_message := p_message || ' (stopped at max limit)';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
    END fetch_all_official_vds_details;

END pkg_api_client_vds;
/

-- Grant necessary permissions
GRANT EXECUTE ON pkg_api_client_vds TO TR2000_STAGING;
/