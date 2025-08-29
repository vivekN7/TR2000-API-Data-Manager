-- ===============================================================================
-- PKG_API_CLIENT_PCS_DETAILS - API Client for PCS Detail Data
-- Date: 2025-08-28
-- Purpose: Fetch PCS detail data from API endpoints (Task 8)
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_api_client_pcs_details AS

    -- Fetch PCS detail JSON for a specific type
    FUNCTION fetch_pcs_detail_json(
        p_plant_id       VARCHAR2,
        p_pcs_name       VARCHAR2,
        p_pcs_revision   VARCHAR2,
        p_detail_type    VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- Refresh PCS details for a specific type
    PROCEDURE refresh_pcs_details(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_pcs_name        IN VARCHAR2,
        p_pcs_revision    IN VARCHAR2,
        p_detail_type     IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );

    -- Refresh ALL detail types for a PCS
    PROCEDURE refresh_all_pcs_details(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_pcs_name        IN VARCHAR2,
        p_pcs_revision    IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );

    -- Process all PCS references for selected issues
    PROCEDURE process_all_selected_pcs_details(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2
    );

END pkg_api_client_pcs_details;
/

CREATE OR REPLACE PACKAGE BODY pkg_api_client_pcs_details AS

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
            RETURN 'https://equinor.pipespec-api.presight.com';
    END get_base_url;

    -- Fetch PCS detail JSON for a specific type
    FUNCTION fetch_pcs_detail_json(
        p_plant_id       VARCHAR2,
        p_pcs_name       VARCHAR2,
        p_pcs_revision   VARCHAR2,
        p_detail_type    VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_response CLOB;
        l_url VARCHAR2(500);
        l_correlation_id VARCHAR2(36);
        l_endpoint_suffix VARCHAR2(100);
    BEGIN
        -- Generate correlation ID if not provided
        IF p_correlation_id IS NULL THEN
            SELECT SYS_GUID() INTO l_correlation_id FROM DUAL;
        ELSE
            l_correlation_id := p_correlation_id;
        END IF;
        
        -- Determine endpoint suffix based on detail type
        CASE UPPER(p_detail_type)
            WHEN 'HEADER' THEN
                l_endpoint_suffix := '';  -- No suffix for header/properties
            WHEN 'TEMP_PRESSURE' THEN
                l_endpoint_suffix := '/temp-pressures';
            WHEN 'PIPE_SIZES' THEN
                l_endpoint_suffix := '/pipe-sizes';
            WHEN 'PIPE_ELEMENTS' THEN
                l_endpoint_suffix := '/pipe-elements';
            WHEN 'VALVE_ELEMENTS' THEN
                l_endpoint_suffix := '/valve-elements';
            WHEN 'EMBEDDED_NOTES' THEN
                l_endpoint_suffix := '/embedded-notes';
            ELSE
                RAISE_APPLICATION_ERROR(-20501, 'Unknown PCS detail type: ' || p_detail_type);
        END CASE;
        
        -- Build URL
        l_url := get_base_url() || '/plants/' || p_plant_id || 
                 '/pcs/' || p_pcs_name || '/rev/' || p_pcs_revision || l_endpoint_suffix;
        
        DBMS_OUTPUT.PUT_LINE('Fetching PCS details from: ' || l_url);
        
        -- Make API call through wrapper
        l_response := make_api_request_util(
            p_url => l_url,
            p_method => 'GET',
            p_correlation_id => l_correlation_id
        );
        
        RETURN l_response;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error fetching PCS ' || p_detail_type || ' for ' || 
                                p_plant_id || '/' || p_pcs_name || '/' || p_pcs_revision || 
                                ': ' || SQLERRM);
            -- Log error but don't fail the whole process
            DECLARE
                v_error_msg VARCHAR2(4000) := SQLERRM;
            BEGIN
                INSERT INTO ETL_ERROR_LOG (
                    error_timestamp, endpoint_key, error_message,
                    plant_id, error_type
                ) VALUES (
                    SYSTIMESTAMP, 'PCS_' || p_detail_type,
                    v_error_msg, p_plant_id,
                    'API_FETCH_ERROR'
                );
                COMMIT;
            END;
            RETURN NULL;
    END fetch_pcs_detail_json;

    -- Refresh PCS details for a specific type
    PROCEDURE refresh_pcs_details(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_pcs_name        IN VARCHAR2,
        p_pcs_revision    IN VARCHAR2,
        p_detail_type     IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    ) IS
        l_json CLOB;
        l_raw_json_id NUMBER;
        l_hash VARCHAR2(64);
        l_correlation_id VARCHAR2(36);
        v_count NUMBER;
        l_endpoint_key VARCHAR2(100);
    BEGIN
        -- Generate correlation ID
        IF p_correlation_id IS NULL THEN
            SELECT SYS_GUID() INTO l_correlation_id FROM DUAL;
        ELSE
            l_correlation_id := p_correlation_id;
        END IF;
        
        -- Build endpoint key for storage
        l_endpoint_key := 'PCS_' || UPPER(p_detail_type) || '_' || p_pcs_name || '_' || p_pcs_revision;
        
        -- Fetch JSON from API
        l_json := fetch_pcs_detail_json(p_plant_id, p_pcs_name, p_pcs_revision, 
                                       p_detail_type, l_correlation_id);
        
        IF l_json IS NULL OR LENGTH(l_json) = 0 THEN
            p_status := 'SKIPPED';
            p_message := 'No data returned from API for PCS ' || p_detail_type;
            RETURN;
        END IF;
        
        -- Calculate hash for deduplication
        l_hash := DBMS_UTILITY.GET_HASH_VALUE(SUBSTR(l_json, 1, 4000), 1, 1073741824);
        
        -- Check if already processed
        SELECT COUNT(*) INTO v_count
        FROM RAW_JSON
        WHERE key_fingerprint = l_hash
          AND endpoint = l_endpoint_key
          AND plant_id = p_plant_id;
        
        IF v_count > 0 THEN
            p_status := 'SKIPPED';
            p_message := 'PCS detail data already processed (duplicate hash)';
            RETURN;
        END IF;
        
        -- Store in RAW_JSON
        INSERT INTO RAW_JSON (
            endpoint,
            plant_id,
            issue_revision,
            payload,
            key_fingerprint,
            batch_id
        ) VALUES (
            l_endpoint_key,
            p_plant_id,
            p_issue_rev,
            l_json,
            l_hash,
            l_correlation_id
        ) RETURNING raw_json_id INTO l_raw_json_id;
        
        -- Parse to staging based on detail type
        pkg_parse_pcs_details.parse_pcs_detail_json(
            p_detail_type => p_detail_type,
            p_raw_json_id => l_raw_json_id,
            p_plant_id => p_plant_id,
            p_issue_rev => p_issue_rev,
            p_pcs_name => p_pcs_name,
            p_pcs_revision => p_pcs_revision
        );
        
        -- Upsert to core tables
        pkg_upsert_pcs_details.upsert_pcs_details(
            p_detail_type => p_detail_type,
            p_plant_id => p_plant_id,
            p_issue_rev => p_issue_rev,
            p_pcs_name => p_pcs_name,
            p_pcs_revision => p_pcs_revision
        );
        
        COMMIT;
        
        p_status := 'SUCCESS';
        p_message := 'PCS ' || p_detail_type || ' refreshed successfully';
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status := 'ERROR';
            p_message := 'Error refreshing PCS details: ' || SQLERRM;
            
            DECLARE
                v_error_msg VARCHAR2(4000) := SQLERRM;
            BEGIN
                INSERT INTO ETL_ERROR_LOG (
                    error_timestamp, endpoint_key, error_message,
                    plant_id, issue_revision, error_type
                ) VALUES (
                    SYSTIMESTAMP, 'PCS_' || p_detail_type,
                    v_error_msg, p_plant_id, p_issue_rev,
                    'REFRESH_ERROR'
                );
            END;
            COMMIT;
    END refresh_pcs_details;

    -- Refresh ALL detail types for a PCS
    PROCEDURE refresh_all_pcs_details(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_pcs_name        IN VARCHAR2,
        p_pcs_revision    IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    ) IS
        l_correlation_id VARCHAR2(36);
        l_status VARCHAR2(50);
        l_message VARCHAR2(4000);
        l_success_count NUMBER := 0;
        l_error_count NUMBER := 0;
        l_skip_count NUMBER := 0;
        
        -- Detail types to process
        TYPE t_detail_types IS TABLE OF VARCHAR2(50);
        l_detail_types t_detail_types := t_detail_types(
            'HEADER', 'TEMP_PRESSURE', 'PIPE_SIZES', 
            'PIPE_ELEMENTS', 'VALVE_ELEMENTS', 'EMBEDDED_NOTES'
        );
    BEGIN
        -- Generate correlation ID for batch
        IF p_correlation_id IS NULL THEN
            SELECT SYS_GUID() INTO l_correlation_id FROM DUAL;
        ELSE
            l_correlation_id := p_correlation_id;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Fetching all PCS details for ' || p_pcs_name || 
                            ' Rev: ' || p_pcs_revision);
        
        -- Process each detail type
        FOR i IN 1..l_detail_types.COUNT LOOP
            BEGIN
                refresh_pcs_details(
                    p_plant_id => p_plant_id,
                    p_issue_rev => p_issue_rev,
                    p_pcs_name => p_pcs_name,
                    p_pcs_revision => p_pcs_revision,
                    p_detail_type => l_detail_types(i),
                    p_status => l_status,
                    p_message => l_message,
                    p_correlation_id => l_correlation_id
                );
                
                IF l_status = 'SUCCESS' THEN
                    l_success_count := l_success_count + 1;
                ELSIF l_status = 'ERROR' THEN
                    l_error_count := l_error_count + 1;
                ELSIF l_status = 'SKIPPED' THEN
                    l_skip_count := l_skip_count + 1;
                END IF;
                
                DBMS_OUTPUT.PUT_LINE('  ' || l_detail_types(i) || ': ' || l_status || 
                                    ' - ' || l_message);
                
            EXCEPTION
                WHEN OTHERS THEN
                    l_error_count := l_error_count + 1;
                    DBMS_OUTPUT.PUT_LINE('  ' || l_detail_types(i) || ': ERROR - ' || SQLERRM);
            END;
        END LOOP;
        
        -- Set overall status
        IF l_error_count > 0 THEN
            p_status := 'PARTIAL';
            p_message := 'PCS details refresh completed with errors. Success: ' || 
                        l_success_count || ', Errors: ' || l_error_count || 
                        ', Skipped: ' || l_skip_count;
        ELSIF l_success_count = 0 AND l_skip_count > 0 THEN
            p_status := 'SKIPPED';
            p_message := 'All PCS detail types were skipped (already up to date)';
        ELSE
            p_status := 'SUCCESS';
            p_message := 'PCS details refreshed successfully. Success: ' || 
                        l_success_count || ', Skipped: ' || l_skip_count;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'Error refreshing all PCS details: ' || SQLERRM;
    END refresh_all_pcs_details;

    -- Process all PCS references for selected issues
    PROCEDURE process_all_selected_pcs_details(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2
    ) IS
        l_status VARCHAR2(50);
        l_message VARCHAR2(4000);
        l_total_pcs NUMBER := 0;
        l_processed NUMBER := 0;
        l_errors NUMBER := 0;
        l_correlation_id VARCHAR2(36);
    BEGIN
        -- Generate batch correlation ID
        SELECT SYS_GUID() INTO l_correlation_id FROM DUAL;
        
        DBMS_OUTPUT.PUT_LINE('Processing PCS details for all selected issues...');
        
        -- Process each valid PCS reference
        FOR rec IN (
            SELECT DISTINCT
                pr.plant_id,
                pr.issue_revision,
                pr.pcs_name,
                pr.revision
            FROM PCS_REFERENCES pr
            WHERE pr.is_valid = 'Y'
              AND EXISTS (
                  SELECT 1 
                  FROM SELECTED_ISSUES si
                  WHERE si.plant_id = pr.plant_id
                    AND si.issue_revision = pr.issue_revision
                    AND si.is_active = 'Y'
              )
            ORDER BY pr.plant_id, pr.issue_revision, pr.pcs_name
        ) LOOP
            l_total_pcs := l_total_pcs + 1;
            
            BEGIN
                refresh_all_pcs_details(
                    p_plant_id => rec.plant_id,
                    p_issue_rev => rec.issue_revision,
                    p_pcs_name => rec.pcs_name,
                    p_pcs_revision => rec.revision,
                    p_status => l_status,
                    p_message => l_message,
                    p_correlation_id => l_correlation_id
                );
                
                IF l_status IN ('SUCCESS', 'PARTIAL') THEN
                    l_processed := l_processed + 1;
                END IF;
                
                IF l_status IN ('ERROR', 'PARTIAL') THEN
                    l_errors := l_errors + 1;
                END IF;
                
                DBMS_OUTPUT.PUT_LINE('PCS ' || rec.pcs_name || ' Rev ' || rec.revision || 
                                    ': ' || l_status);
                
            EXCEPTION
                WHEN OTHERS THEN
                    l_errors := l_errors + 1;
                    DBMS_OUTPUT.PUT_LINE('Error processing PCS ' || rec.pcs_name || 
                                        ': ' || SQLERRM);
            END;
            
            -- Commit after each PCS to avoid losing work
            COMMIT;
        END LOOP;
        
        -- Set overall status
        IF l_total_pcs = 0 THEN
            p_status := 'NO_DATA';
            p_message := 'No valid PCS references found for selected issues';
        ELSIF l_errors > 0 THEN
            p_status := 'PARTIAL';
            p_message := 'Processed ' || l_processed || ' of ' || l_total_pcs || 
                        ' PCS references with ' || l_errors || ' errors';
        ELSE
            p_status := 'SUCCESS';
            p_message := 'Successfully processed ' || l_processed || ' of ' || 
                        l_total_pcs || ' PCS references';
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Overall: ' || p_message);
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'Error processing PCS details: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('Fatal error: ' || SQLERRM);
    END process_all_selected_pcs_details;

END pkg_api_client_pcs_details;
/