-- =====================================================
-- Migrate PKG_API_CLIENT to use API_SERVICE proxy
-- =====================================================

CREATE OR REPLACE PACKAGE BODY PKG_API_CLIENT AS

    -- Build endpoint URL from template
    FUNCTION build_endpoint_url(
        p_endpoint_key VARCHAR2,
        p_plant_id VARCHAR2 DEFAULT NULL,
        p_issue_revision VARCHAR2 DEFAULT NULL,
        p_pcs_name VARCHAR2 DEFAULT NULL,
        p_pcs_revision VARCHAR2 DEFAULT NULL
    ) RETURN VARCHAR2 IS
        v_url VARCHAR2(500);
        v_template VARCHAR2(500);
    BEGIN
        -- Get template from CONTROL_ENDPOINTS
        BEGIN
            SELECT endpoint_template INTO v_template
            FROM CONTROL_ENDPOINTS
            WHERE endpoint_key = p_endpoint_key;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- If not found, build manually for PCS details
                IF p_endpoint_key LIKE 'PCS_%' THEN
                    v_template := '/plants/{plant_id}/pcs/{pcs_name}/rev/{pcs_revision}';
                    IF p_endpoint_key = 'PCS_HEADER_PROPERTIES' THEN
                        v_template := v_template;  -- Base endpoint
                    ELSIF p_endpoint_key = 'PCS_TEMP_PRESSURES' THEN
                        v_template := v_template || '/temp-pressures';
                    ELSIF p_endpoint_key = 'PCS_PIPE_SIZES' THEN
                        v_template := v_template || '/pipe-sizes';
                    ELSIF p_endpoint_key = 'PCS_PIPE_ELEMENTS' THEN
                        v_template := v_template || '/pipe-elements';
                    ELSIF p_endpoint_key = 'PCS_VALVE_ELEMENTS' THEN
                        v_template := v_template || '/valve-elements';
                    ELSIF p_endpoint_key = 'PCS_EMBEDDED_NOTES' THEN
                        v_template := v_template || '/embedded-notes';
                    END IF;
                ELSE
                    RAISE_APPLICATION_ERROR(-20001, 'Endpoint key not found: ' || p_endpoint_key);
                END IF;
        END;
        
        -- Replace placeholders
        v_url := v_template;
        v_url := REPLACE(v_url, '{plant_id}', p_plant_id);
        v_url := REPLACE(v_url, '{issue_revision}', p_issue_revision);
        v_url := REPLACE(v_url, '{pcs_name}', p_pcs_name);
        v_url := REPLACE(v_url, '{pcs_revision}', p_pcs_revision);
        
        RETURN v_url;
    END build_endpoint_url;

    -- Fetch reference data (PCS, VDS, MDS, etc.)
    FUNCTION fetch_reference_data(
        p_plant_id VARCHAR2,
        p_issue_revision VARCHAR2,
        p_ref_type VARCHAR2,
        p_batch_id VARCHAR2
    ) RETURN NUMBER IS
        v_path VARCHAR2(500);
        v_response CLOB;
        v_raw_json_id NUMBER;
        v_base_url VARCHAR2(500);
        v_endpoint_key VARCHAR2(100);
        v_url VARCHAR2(4000);
        v_template VARCHAR2(500);
        v_http_status PLS_INTEGER;
        v_error_msg VARCHAR2(4000);
    BEGIN
        -- Get base URL from configuration
        SELECT setting_value INTO v_base_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        -- Map reference type to endpoint key
        v_endpoint_key := UPPER(p_ref_type) || '_REFERENCES';
        
        -- Build actual path using template
        v_path := build_endpoint_url(
            p_endpoint_key => v_endpoint_key,
            p_plant_id => p_plant_id,
            p_issue_revision => p_issue_revision
        );
        
        -- Get template for logging
        v_template := build_endpoint_url(v_endpoint_key, '{plant_id}', '{issue_revision}');
        
        -- Construct full URL
        v_url := v_base_url || v_path;
        
        -- Make API call through proxy
        BEGIN
            v_response := API_SERVICE.API_GATEWAY.get_clob(
                p_url => v_url,
                p_method => 'GET',
                p_body => NULL,
                p_headers => NULL,
                p_credential_static_id => NULL,
                p_status_code => v_http_status
            );
        EXCEPTION
            WHEN OTHERS THEN
                v_http_status := -1;
                v_error_msg := SUBSTR(SQLERRM, 1, 4000);
        END;
        
        -- Store in RAW_JSON with fingerprint (single logging point)
        INSERT INTO RAW_JSON (
            raw_json_id,
            endpoint_key,
            endpoint_template,
            endpoint_value,
            payload,
            batch_id,
            api_call_timestamp,
            created_date,
            key_fingerprint
        ) VALUES (
            RAW_JSON_SEQ.NEXTVAL,
            v_endpoint_key,
            v_template,
            v_path,
            v_response,
            p_batch_id,
            SYSTIMESTAMP,
            SYSDATE,
            STANDARD_HASH(v_path || '|' || p_batch_id, 'SHA256')
        ) RETURNING raw_json_id INTO v_raw_json_id;
        
        -- Log error if HTTP status is not success
        IF v_http_status IS NULL OR v_http_status NOT BETWEEN 200 AND 299 THEN
            INSERT INTO ETL_ERROR_LOG (
                error_id,
                endpoint_key,
                plant_id,
                issue_revision,
                error_timestamp,
                error_type,
                error_code,
                error_message
            ) VALUES (
                ETL_ERROR_SEQ.NEXTVAL,
                v_endpoint_key,
                p_plant_id,
                p_issue_revision,
                SYSTIMESTAMP,
                'API_CALL_ERROR',
                TO_CHAR(v_http_status),
                'HTTP ' || NVL(TO_CHAR(v_http_status), 'NULL') || ' for ' || v_url ||
                CASE WHEN v_error_msg IS NOT NULL THEN CHR(10) || v_error_msg ELSE '' END
            );
            COMMIT;
            -- Don't raise error - some endpoints might return 404 which is valid
        END IF;
        
        RETURN v_raw_json_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            DECLARE
                v_error_code VARCHAR2(50) := TO_CHAR(SQLCODE);
                v_error_msg VARCHAR2(4000) := SUBSTR(SQLERRM || CHR(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 1, 4000);
            BEGIN
                -- Log unexpected error
                INSERT INTO ETL_ERROR_LOG (
                    error_id,
                    endpoint_key,
                    plant_id,
                    issue_revision,
                    error_timestamp,
                    error_type,
                    error_code,
                    error_message
                ) VALUES (
                    ETL_ERROR_SEQ.NEXTVAL,
                    v_endpoint_key,
                    p_plant_id,
                    p_issue_revision,
                    SYSTIMESTAMP,
                    'UNEXPECTED_ERROR',
                    v_error_code,
                    v_error_msg
                );
                COMMIT;
            END;
            RETURN NULL;
    END fetch_reference_data;

    -- Fetch PCS list for a plant
    FUNCTION fetch_pcs_list(
        p_plant_id VARCHAR2,
        p_batch_id VARCHAR2
    ) RETURN NUMBER IS
        v_path VARCHAR2(500);
        v_response CLOB;
        v_raw_json_id NUMBER;
        v_base_url VARCHAR2(500);
        v_url VARCHAR2(4000);
        v_http_status PLS_INTEGER;
        v_error_msg VARCHAR2(4000);
    BEGIN
        -- Get base URL from configuration
        SELECT setting_value INTO v_base_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        -- Build path
        v_path := build_endpoint_url(
            p_endpoint_key => 'PCS_LIST',
            p_plant_id => p_plant_id
        );
        
        -- Construct full URL
        v_url := v_base_url || v_path;
        
        -- Make API call through proxy
        BEGIN
            v_response := API_SERVICE.API_GATEWAY.get_clob(
                p_url => v_url,
                p_method => 'GET',
                p_body => NULL,
                p_headers => NULL,
                p_credential_static_id => NULL,
                p_status_code => v_http_status
            );
        EXCEPTION
            WHEN OTHERS THEN
                v_http_status := -1;
                v_error_msg := SUBSTR(SQLERRM, 1, 4000);
        END;
        
        -- Store in RAW_JSON
        INSERT INTO RAW_JSON (
            raw_json_id,
            endpoint_key,
            endpoint_template,
            endpoint_value,
            payload,
            batch_id,
            api_call_timestamp,
            created_date,
            key_fingerprint
        ) VALUES (
            RAW_JSON_SEQ.NEXTVAL,
            'PCS_LIST',
            '/plants/{plant_id}/pcs',
            v_path,
            v_response,
            p_batch_id,
            SYSTIMESTAMP,
            SYSDATE,
            STANDARD_HASH(v_path || '|' || p_batch_id, 'SHA256')
        ) RETURNING raw_json_id INTO v_raw_json_id;
        
        -- Log error if HTTP status is not success
        IF v_http_status IS NULL OR v_http_status NOT BETWEEN 200 AND 299 THEN
            INSERT INTO ETL_ERROR_LOG (
                error_id,
                endpoint_key,
                plant_id,
                error_timestamp,
                error_type,
                error_code,
                error_message
            ) VALUES (
                ETL_ERROR_SEQ.NEXTVAL,
                'PCS_LIST',
                p_plant_id,
                NULL,
                SYSTIMESTAMP,
                'API_CALL_ERROR',
                TO_CHAR(v_http_status),
                'HTTP ' || NVL(TO_CHAR(v_http_status), 'NULL') || ' for ' || v_url ||
                CASE WHEN v_error_msg IS NOT NULL THEN CHR(10) || v_error_msg ELSE '' END
            );
            COMMIT;
        END IF;
        
        RETURN v_raw_json_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            DECLARE
                v_error_code VARCHAR2(50) := TO_CHAR(SQLCODE);
                v_error_msg VARCHAR2(4000) := SUBSTR(SQLERRM || CHR(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 1, 4000);
            BEGIN
                INSERT INTO ETL_ERROR_LOG (
                    error_id,
                    endpoint_key,
                    plant_id,
                    error_timestamp,
                    error_type,
                    error_code,
                    error_message
                ) VALUES (
                    ETL_ERROR_SEQ.NEXTVAL,
                    'PCS_LIST',
                    p_plant_id,
                    SYSTIMESTAMP,
                    'UNEXPECTED_ERROR',
                    v_error_code,
                    v_error_msg
                );
                COMMIT;
            END;
            RETURN NULL;
    END fetch_pcs_list;

    -- Fetch PCS detail data (6 endpoints per PCS)
    FUNCTION fetch_pcs_detail_data(
        p_plant_id VARCHAR2,
        p_pcs_name VARCHAR2,
        p_pcs_revision VARCHAR2,
        p_detail_type VARCHAR2,
        p_batch_id VARCHAR2
    ) RETURN NUMBER IS
        v_path VARCHAR2(500);
        v_response CLOB;
        v_raw_json_id NUMBER;
        v_base_url VARCHAR2(500);
        v_endpoint_key VARCHAR2(100);
        v_url VARCHAR2(4000);
        v_template VARCHAR2(500);
        v_http_status PLS_INTEGER;
        v_error_msg VARCHAR2(4000);
    BEGIN
        -- Get base URL from configuration
        SELECT setting_value INTO v_base_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        -- Map detail type to endpoint key
        v_endpoint_key := 'PCS_' || UPPER(p_detail_type);
        
        -- Build actual path using template
        v_path := build_endpoint_url(
            p_endpoint_key => v_endpoint_key,
            p_plant_id => p_plant_id,
            p_pcs_name => p_pcs_name,
            p_pcs_revision => p_pcs_revision
        );
        
        -- Get template for logging
        v_template := build_endpoint_url(v_endpoint_key, '{plant_id}', NULL, '{pcs_name}', '{pcs_revision}');
        
        -- Construct full URL
        v_url := v_base_url || v_path;
        
        -- Make API call through proxy
        BEGIN
            v_response := API_SERVICE.API_GATEWAY.get_clob(
                p_url => v_url,
                p_method => 'GET',
                p_body => NULL,
                p_headers => NULL,
                p_credential_static_id => NULL,
                p_status_code => v_http_status
            );
        EXCEPTION
            WHEN OTHERS THEN
                v_http_status := -1;
                v_error_msg := SUBSTR(SQLERRM, 1, 4000);
        END;
        
        -- Store in RAW_JSON
        INSERT INTO RAW_JSON (
            raw_json_id,
            endpoint_key,
            endpoint_template,
            endpoint_value,
            payload,
            batch_id,
            api_call_timestamp,
            created_date,
            key_fingerprint
        ) VALUES (
            RAW_JSON_SEQ.NEXTVAL,
            v_endpoint_key,
            v_template,
            v_path,
            v_response,
            p_batch_id,
            SYSTIMESTAMP,
            SYSDATE,
            STANDARD_HASH(v_path || '|' || p_batch_id, 'SHA256')
        ) RETURNING raw_json_id INTO v_raw_json_id;
        
        -- Log error if HTTP status is not success
        IF v_http_status IS NULL OR v_http_status NOT BETWEEN 200 AND 299 THEN
            INSERT INTO ETL_ERROR_LOG (
                error_id,
                endpoint_key,
                plant_id,
                pcs_name,
                error_timestamp,
                error_type,
                error_code,
                error_message
            ) VALUES (
                ETL_ERROR_SEQ.NEXTVAL,
                v_endpoint_key,
                p_plant_id,
                p_pcs_name,
                SYSTIMESTAMP,
                'API_CALL_ERROR',
                TO_CHAR(v_http_status),
                'HTTP ' || NVL(TO_CHAR(v_http_status), 'NULL') || ' for ' || v_url ||
                CASE WHEN v_error_msg IS NOT NULL THEN CHR(10) || v_error_msg ELSE '' END
            );
            COMMIT;
        END IF;
        
        RETURN v_raw_json_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            DECLARE
                v_error_code VARCHAR2(50) := TO_CHAR(SQLCODE);
                v_error_msg VARCHAR2(4000) := SUBSTR(SQLERRM || CHR(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 1, 4000);
            BEGIN
                INSERT INTO ETL_ERROR_LOG (
                    error_id,
                    endpoint_key,
                    plant_id,
                    pcs_name,
                    error_timestamp,
                    error_type,
                    error_code,
                    error_message
                ) VALUES (
                    ETL_ERROR_SEQ.NEXTVAL,
                    v_endpoint_key,
                    p_plant_id,
                    p_pcs_name,
                    SYSTIMESTAMP,
                    'UNEXPECTED_ERROR',
                    v_error_code,
                    v_error_msg
                );
                COMMIT;
            END;
            RETURN NULL;
    END fetch_pcs_detail_data;

END PKG_API_CLIENT;
/

SHOW ERRORS;