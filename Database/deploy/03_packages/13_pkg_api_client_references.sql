-- ===============================================================================
-- PKG_API_CLIENT_REFERENCES - API Client for Reference Data
-- Date: 2025-08-26, Updated: 2025-08-27
-- Purpose: Fetch reference data from API endpoints
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_api_client_references AS

    -- Fetch reference JSON for a specific type
    FUNCTION fetch_reference_json(
        p_plant_id       VARCHAR2,
        p_issue_rev      VARCHAR2,
        p_reference_type VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- Refresh references for a specific issue and type
    PROCEDURE refresh_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_reference_type  IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );

    -- Refresh ALL reference types for an issue
    PROCEDURE refresh_all_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );

END pkg_api_client_references;
/

CREATE OR REPLACE PACKAGE BODY pkg_api_client_references AS

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

    -- Fetch reference JSON for a specific type
    FUNCTION fetch_reference_json(
        p_plant_id       VARCHAR2,
        p_issue_rev      VARCHAR2,
        p_reference_type VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_response CLOB;
        l_url VARCHAR2(500);
        l_correlation_id VARCHAR2(36);
    BEGIN
        -- Generate correlation ID if not provided
        l_correlation_id := NVL(p_correlation_id, SYS_GUID());
        
        -- Build URL based on reference type
        -- Special case for PIPE-ELEMENT which maps to pipe-elements endpoint
        IF UPPER(p_reference_type) = 'PIPE-ELEMENT' THEN
            l_url := get_base_url() || '/plants/' || p_plant_id || 
                     '/issues/rev/' || p_issue_rev || '/pipe-elements';
        ELSE
            l_url := get_base_url() || '/plants/' || p_plant_id || 
                     '/issues/rev/' || p_issue_rev || '/' || LOWER(p_reference_type);
        END IF;
        
        -- Make API call through wrapper
        l_response := make_api_request_util(
            p_url => l_url,
            p_method => 'GET',
            p_correlation_id => l_correlation_id
        );
        
        RETURN l_response;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error fetching ' || p_reference_type || ' for ' || 
                                p_plant_id || '/' || p_issue_rev || ': ' || SQLERRM);
            RAISE;
    END fetch_reference_json;

    -- Refresh references for a specific issue and type
    PROCEDURE refresh_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_reference_type  IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    ) IS
        l_json CLOB;
        l_raw_json_id NUMBER;
        l_hash VARCHAR2(64);
        l_correlation_id VARCHAR2(36);
        v_count NUMBER;
    BEGIN
        -- Generate correlation ID
        l_correlation_id := NVL(p_correlation_id, SYS_GUID());
        
        -- Fetch JSON from API
        l_json := fetch_reference_json(p_plant_id, p_issue_rev, p_reference_type, l_correlation_id);
        
        IF l_json IS NULL OR LENGTH(l_json) = 0 THEN
            p_status := 'SKIPPED';
            p_message := 'No data returned from API for ' || p_reference_type;
            RETURN;
        END IF;
        
        -- Calculate hash
        l_hash := DBMS_UTILITY.GET_HASH_VALUE(SUBSTR(l_json, 1, 4000), 1, 1073741824);
        
        -- Check if already processed
        SELECT COUNT(*) INTO v_count
        FROM RAW_JSON
        WHERE key_fingerprint = l_hash;
        
        IF v_count > 0 THEN
            p_status := 'SKIPPED';
            p_message := 'Data already processed (duplicate hash)';
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
            p_reference_type,
            p_plant_id,
            p_issue_rev,
            l_json,
            l_hash,
            l_correlation_id
        ) RETURNING raw_json_id INTO l_raw_json_id;
        
        -- Parse based on type
        CASE UPPER(p_reference_type)
            WHEN 'PCS' THEN
                PKG_PARSE_REFERENCES.parse_pcs_json(l_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'VDS' THEN
                PKG_PARSE_REFERENCES.parse_vds_json(l_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'EDS' THEN
                PKG_PARSE_REFERENCES.parse_eds_json(l_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'MDS' THEN
                PKG_PARSE_REFERENCES.parse_mds_json(l_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'VSK' THEN
                PKG_PARSE_REFERENCES.parse_vsk_json(l_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'ESK' THEN
                PKG_PARSE_REFERENCES.parse_esk_json(l_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'PIPE-ELEMENT' THEN
                PKG_PARSE_REFERENCES.parse_pipe_element_json(l_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'SC' THEN
                PKG_PARSE_REFERENCES.parse_sc_json(l_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'VSM' THEN
                PKG_PARSE_REFERENCES.parse_vsm_json(l_raw_json_id, p_plant_id, p_issue_rev);
            ELSE
                p_status := 'ERROR';
                p_message := 'Unknown reference type: ' || p_reference_type;
                RETURN;
        END CASE;
        
        -- Process to final tables
        CASE UPPER(p_reference_type)
            WHEN 'PCS' THEN
                PKG_UPSERT_REFERENCES.upsert_pcs_references(p_plant_id, p_issue_rev);
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
            WHEN 'PIPE-ELEMENT' THEN
                PKG_UPSERT_REFERENCES.upsert_pipe_element_references(p_plant_id, p_issue_rev);
            WHEN 'SC' THEN
                PKG_UPSERT_REFERENCES.upsert_sc_references(p_plant_id, p_issue_rev);
            WHEN 'VSM' THEN
                PKG_UPSERT_REFERENCES.upsert_vsm_references(p_plant_id, p_issue_rev);
        END CASE;
        
        COMMIT;
        
        p_status := 'SUCCESS';
        p_message := 'Successfully processed ' || p_reference_type || ' references';
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status := 'ERROR';
            p_message := SQLERRM;
    END refresh_issue_references;

    -- Refresh ALL reference types for an issue
    PROCEDURE refresh_all_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    ) IS
        l_correlation_id VARCHAR2(36);
        l_status VARCHAR2(50);
        l_message VARCHAR2(4000);
        v_success_count NUMBER := 0;
        v_error_count NUMBER := 0;
        v_messages CLOB;
        l_run_id NUMBER;
        l_start_time TIMESTAMP := SYSTIMESTAMP;
        l_total_records NUMBER := 0;
    BEGIN
        l_correlation_id := NVL(p_correlation_id, SYS_GUID());
        
        -- Log to ETL_RUN_LOG for statistics
        INSERT INTO ETL_RUN_LOG (
            run_type, endpoint_key, plant_id, issue_revision, 
            start_time, status, initiated_by
        ) VALUES (
            'REFERENCES_API_REFRESH', 'references_all', p_plant_id, p_issue_rev,
            l_start_time, 'RUNNING', USER
        )
        RETURNING run_id INTO l_run_id;
        
        -- Process each reference type
        FOR ref_type IN (
            SELECT column_value as ref_type 
            FROM TABLE(SYS.ODCIVARCHAR2LIST('PCS','VDS','EDS','MDS','VSK','ESK','PIPE-ELEMENT','SC','VSM'))
        ) LOOP
            BEGIN
                refresh_issue_references(
                    p_plant_id => p_plant_id,
                    p_issue_rev => p_issue_rev,
                    p_reference_type => ref_type.ref_type,
                    p_status => l_status,
                    p_message => l_message,
                    p_correlation_id => l_correlation_id
                );
                
                IF l_status = 'SUCCESS' THEN
                    v_success_count := v_success_count + 1;
                ELSE
                    v_error_count := v_error_count + 1;
                END IF;
                
                v_messages := v_messages || ref_type.ref_type || ': ' || l_status || 
                             ' - ' || l_message || CHR(10);
                             
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;
                    v_messages := v_messages || ref_type.ref_type || ': ERROR - ' || 
                                 SQLERRM || CHR(10);
            END;
        END LOOP;
        
        -- Count total records loaded
        SELECT 
            (SELECT COUNT(*) FROM PCS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_rev) +
            (SELECT COUNT(*) FROM VDS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_rev) +
            (SELECT COUNT(*) FROM MDS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_rev) +
            (SELECT COUNT(*) FROM EDS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_rev) +
            (SELECT COUNT(*) FROM VSK_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_rev) +
            (SELECT COUNT(*) FROM ESK_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_rev) +
            (SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_rev) +
            (SELECT COUNT(*) FROM SC_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_rev) +
            (SELECT COUNT(*) FROM VSM_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_rev)
        INTO l_total_records
        FROM DUAL;
        
        -- Set overall status
        IF v_error_count = 0 THEN
            p_status := 'SUCCESS';
            p_message := 'All reference types processed successfully (' || 
                        v_success_count || ' types)';
        ELSIF v_success_count > 0 THEN
            p_status := 'PARTIAL';
            p_message := 'Some reference types failed. Success: ' || v_success_count || 
                        ', Errors: ' || v_error_count;
        ELSE
            p_status := 'ERROR';
            p_message := 'All reference types failed';
        END IF;
        
        -- Update ETL_RUN_LOG with final status
        UPDATE ETL_RUN_LOG
        SET end_time = SYSTIMESTAMP,
            status = p_status,
            records_processed = l_total_records,
            records_inserted = l_total_records,
            error_count = v_error_count,
            duration_seconds = EXTRACT(SECOND FROM (SYSTIMESTAMP - l_start_time)) +
                             EXTRACT(MINUTE FROM (SYSTIMESTAMP - l_start_time)) * 60,
            notes = SUBSTR(v_messages, 1, 4000)
        WHERE run_id = l_run_id;
        
        COMMIT;
        
        -- Add detailed messages
        p_message := p_message || CHR(10) || CHR(10) || 'Details:' || CHR(10) || v_messages;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'Failed to process references: ' || SQLERRM;
            
            -- Update ETL_RUN_LOG on error
            IF l_run_id IS NOT NULL THEN
                UPDATE ETL_RUN_LOG
                SET end_time = SYSTIMESTAMP,
                    status = 'ERROR',
                    error_count = 1,
                    duration_seconds = EXTRACT(SECOND FROM (SYSTIMESTAMP - l_start_time)) +
                                     EXTRACT(MINUTE FROM (SYSTIMESTAMP - l_start_time)) * 60,
                    notes = SUBSTR(p_message, 1, 4000)
                WHERE run_id = l_run_id;
                
                COMMIT;
            END IF;
    END refresh_all_issue_references;

END pkg_api_client_references;
/

PROMPT PKG_API_CLIENT_REFERENCES created successfully