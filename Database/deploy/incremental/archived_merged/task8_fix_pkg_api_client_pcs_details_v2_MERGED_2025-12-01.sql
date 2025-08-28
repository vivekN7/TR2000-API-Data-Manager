-- ===============================================================================
-- PKG_API_CLIENT_PCS_DETAILS_V2 - FIXED API Client for PCS Detail Data
-- Date: 2025-08-29
-- Purpose: Correct implementation using proper flow
-- Flow: 1) Get issue PCS refs, 2) Get ALL plant PCS, 3) Load details for ALL PCS revisions
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_api_client_pcs_details_v2 AS

    -- Fetch ALL PCS for a plant (endpoint 3.1)
    FUNCTION fetch_plant_pcs_list(
        p_plant_id       VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;
    
    -- Refresh PCS list for a plant
    PROCEDURE refresh_plant_pcs_list(
        p_plant_id        IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );

    -- Fetch PCS detail JSON for a specific type
    FUNCTION fetch_pcs_detail_json(
        p_plant_id       VARCHAR2,
        p_pcs_name       VARCHAR2,
        p_pcs_revision   VARCHAR2,
        p_detail_type    VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- Refresh PCS details for a specific PCS revision
    PROCEDURE refresh_pcs_details(
        p_plant_id        IN VARCHAR2,
        p_pcs_name        IN VARCHAR2,
        p_pcs_revision    IN VARCHAR2,
        p_detail_type     IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );

    -- Refresh ALL detail types for a PCS revision
    PROCEDURE refresh_all_pcs_details(
        p_plant_id        IN VARCHAR2,
        p_pcs_name        IN VARCHAR2,
        p_pcs_revision    IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );

    -- NEW MAIN PROCEDURE: Process PCS details using correct flow
    PROCEDURE process_pcs_details_correct_flow(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2
    );

END pkg_api_client_pcs_details_v2;
/

CREATE OR REPLACE PACKAGE BODY pkg_api_client_pcs_details_v2 AS

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

    -- =========================================================================
    -- Fetch ALL PCS for a plant (endpoint 3.1)
    -- =========================================================================
    FUNCTION fetch_plant_pcs_list(
        p_plant_id       VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_response CLOB;
        l_url VARCHAR2(500);
        l_correlation_id VARCHAR2(36);
    BEGIN
        -- Generate correlation ID if not provided
        IF p_correlation_id IS NULL THEN
            SELECT SYS_GUID() INTO l_correlation_id FROM DUAL;
        ELSE
            l_correlation_id := p_correlation_id;
        END IF;
        
        -- Build URL for plant PCS list
        l_url := get_base_url() || '/plants/' || p_plant_id || '/pcs';
        
        DBMS_OUTPUT.PUT_LINE('Fetching ALL PCS for plant from: ' || l_url);
        
        -- Make API call through wrapper
        l_response := make_api_request_util(
            p_url => l_url,
            p_method => 'GET',
            p_correlation_id => l_correlation_id
        );
        
        RETURN l_response;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error fetching plant PCS list: ' || SQLERRM);
            RETURN NULL;
    END fetch_plant_pcs_list;

    -- =========================================================================
    -- Refresh PCS list for a plant
    -- =========================================================================
    PROCEDURE refresh_plant_pcs_list(
        p_plant_id        IN VARCHAR2,
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
        IF p_correlation_id IS NULL THEN
            SELECT SYS_GUID() INTO l_correlation_id FROM DUAL;
        ELSE
            l_correlation_id := p_correlation_id;
        END IF;
        
        -- Fetch JSON from API
        l_json := fetch_plant_pcs_list(p_plant_id, l_correlation_id);
        
        IF l_json IS NULL OR LENGTH(l_json) = 0 THEN
            p_status := 'ERROR';
            p_message := 'No data returned from API for plant ' || p_plant_id;
            RETURN;
        END IF;
        
        -- Calculate hash for deduplication
        l_hash := DBMS_UTILITY.GET_HASH_VALUE(SUBSTR(l_json, 1, 4000), 1, 1073741824);
        
        -- Store in RAW_JSON
        INSERT INTO RAW_JSON (
            endpoint,
            plant_id,
            payload,
            key_fingerprint,
            batch_id
        ) VALUES (
            'PLANT_PCS_LIST',
            p_plant_id,
            l_json,
            l_hash,
            l_correlation_id
        ) RETURNING raw_json_id INTO l_raw_json_id;
        
        -- Parse to staging
        pkg_parse_pcs_details.parse_plant_pcs_list(
            p_raw_json_id => l_raw_json_id,
            p_plant_id => p_plant_id
        );
        
        -- Upsert to core PCS_LIST table
        MERGE INTO PCS_LIST tgt
        USING (
            SELECT 
                plant_id,
                pcs AS pcs_name,
                revision,
                status,
                pkg_upsert_pcs_details.safe_date_parse(rev_date) AS rev_date,
                rating_class,
                pkg_upsert_pcs_details.safe_number_parse(test_pressure) AS test_pressure,
                material_group,
                design_code,
                pkg_upsert_pcs_details.safe_date_parse(last_update) AS last_update,
                last_update_by,
                approver,
                notepad,
                pkg_upsert_pcs_details.safe_number_parse(special_req_id) AS special_req_id,
                tube_pcs,
                new_vds_section
            FROM STG_PCS_LIST
            WHERE plant_id = p_plant_id
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.pcs_name = src.pcs_name 
            AND tgt.revision = src.revision)
        WHEN MATCHED THEN
            UPDATE SET
                status = src.status,
                rev_date = src.rev_date,
                rating_class = src.rating_class,
                test_pressure = src.test_pressure,
                material_group = src.material_group,
                design_code = src.design_code,
                last_update = src.last_update,
                last_update_by = src.last_update_by,
                approver = src.approver,
                notepad = src.notepad,
                special_req_id = src.special_req_id,
                tube_pcs = src.tube_pcs,
                new_vds_section = src.new_vds_section,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                pcs_list_guid, plant_id, pcs_name, revision,
                status, rev_date, rating_class, test_pressure,
                material_group, design_code, last_update, last_update_by,
                approver, notepad, special_req_id, tube_pcs, new_vds_section,
                is_valid, created_date, last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.pcs_name, src.revision,
                src.status, src.rev_date, src.rating_class, src.test_pressure,
                src.material_group, src.design_code, src.last_update, src.last_update_by,
                src.approver, src.notepad, src.special_req_id, src.tube_pcs, src.new_vds_section,
                'Y', SYSDATE, SYSDATE, SYSTIMESTAMP
            );
        
        v_count := SQL%ROWCOUNT;
        
        COMMIT;
        
        p_status := 'SUCCESS';
        p_message := 'Loaded ' || v_count || ' PCS revisions for plant ' || p_plant_id;
        
        DBMS_OUTPUT.PUT_LINE(p_message);
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status := 'ERROR';
            p_message := 'Error refreshing plant PCS list: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE(p_message);
    END refresh_plant_pcs_list;

    -- =========================================================================
    -- Fetch PCS detail JSON (unchanged from original)
    -- =========================================================================
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
        IF p_correlation_id IS NULL THEN
            SELECT SYS_GUID() INTO l_correlation_id FROM DUAL;
        ELSE
            l_correlation_id := p_correlation_id;
        END IF;
        
        CASE UPPER(p_detail_type)
            WHEN 'HEADER' THEN
                l_endpoint_suffix := '';
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
        
        l_url := get_base_url() || '/plants/' || p_plant_id || 
                 '/pcs/' || p_pcs_name || '/rev/' || p_pcs_revision || l_endpoint_suffix;
        
        DBMS_OUTPUT.PUT_LINE('  Fetching ' || p_detail_type || ' from: ' || l_url);
        
        l_response := make_api_request_util(
            p_url => l_url,
            p_method => 'GET',
            p_correlation_id => l_correlation_id
        );
        
        RETURN l_response;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  Error fetching ' || p_detail_type || ': ' || SQLERRM);
            RETURN NULL;
    END fetch_pcs_detail_json;

    -- =========================================================================
    -- Refresh PCS details for a specific PCS revision (simplified)
    -- =========================================================================
    PROCEDURE refresh_pcs_details(
        p_plant_id        IN VARCHAR2,
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
        l_endpoint_key VARCHAR2(100);
        -- Using dummy issue_rev since we're processing all plant PCS
        l_issue_rev VARCHAR2(50) := 'PLANT_ALL';
    BEGIN
        IF p_correlation_id IS NULL THEN
            SELECT SYS_GUID() INTO l_correlation_id FROM DUAL;
        ELSE
            l_correlation_id := p_correlation_id;
        END IF;
        
        l_endpoint_key := 'PCS_' || UPPER(p_detail_type) || '_' || p_pcs_name || '_' || p_pcs_revision;
        
        l_json := fetch_pcs_detail_json(p_plant_id, p_pcs_name, p_pcs_revision, 
                                       p_detail_type, l_correlation_id);
        
        IF l_json IS NULL OR LENGTH(l_json) = 0 THEN
            p_status := 'SKIPPED';
            p_message := 'No data for ' || p_detail_type;
            RETURN;
        END IF;
        
        l_hash := DBMS_UTILITY.GET_HASH_VALUE(SUBSTR(l_json, 1, 4000), 1, 1073741824);
        
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
            l_issue_rev,
            l_json,
            l_hash,
            l_correlation_id
        ) RETURNING raw_json_id INTO l_raw_json_id;
        
        -- Parse to staging
        pkg_parse_pcs_details.parse_pcs_detail_json(
            p_detail_type => p_detail_type,
            p_raw_json_id => l_raw_json_id,
            p_plant_id => p_plant_id,
            p_issue_rev => l_issue_rev,
            p_pcs_name => p_pcs_name,
            p_pcs_revision => p_pcs_revision
        );
        
        -- Upsert to core
        pkg_upsert_pcs_details.upsert_pcs_details(
            p_detail_type => p_detail_type,
            p_plant_id => p_plant_id,
            p_issue_rev => l_issue_rev,
            p_pcs_name => p_pcs_name,
            p_pcs_revision => p_pcs_revision
        );
        
        COMMIT;
        
        p_status := 'SUCCESS';
        p_message := p_detail_type || ' loaded';
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status := 'ERROR';
            p_message := 'Error: ' || SUBSTR(SQLERRM, 1, 100);
    END refresh_pcs_details;

    -- =========================================================================
    -- Refresh ALL detail types for a PCS revision
    -- =========================================================================
    PROCEDURE refresh_all_pcs_details(
        p_plant_id        IN VARCHAR2,
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
        
        TYPE t_detail_types IS TABLE OF VARCHAR2(50);
        l_detail_types t_detail_types := t_detail_types(
            'HEADER', 'TEMP_PRESSURE', 'PIPE_SIZES', 
            'PIPE_ELEMENTS', 'VALVE_ELEMENTS', 'EMBEDDED_NOTES'
        );
    BEGIN
        IF p_correlation_id IS NULL THEN
            SELECT SYS_GUID() INTO l_correlation_id FROM DUAL;
        ELSE
            l_correlation_id := p_correlation_id;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Processing PCS: ' || p_pcs_name || ' Rev: ' || p_pcs_revision);
        
        FOR i IN 1..l_detail_types.COUNT LOOP
            BEGIN
                refresh_pcs_details(
                    p_plant_id => p_plant_id,
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
                END IF;
                
            EXCEPTION
                WHEN OTHERS THEN
                    l_error_count := l_error_count + 1;
            END;
        END LOOP;
        
        IF l_error_count > 0 THEN
            p_status := 'PARTIAL';
            p_message := 'Success: ' || l_success_count || ', Errors: ' || l_error_count;
        ELSE
            p_status := 'SUCCESS';
            p_message := 'All ' || l_success_count || ' detail types loaded';
        END IF;
        
    END refresh_all_pcs_details;

    -- =========================================================================
    -- MAIN PROCEDURE: Process PCS details using correct flow
    -- =========================================================================
    PROCEDURE process_pcs_details_correct_flow(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2
    ) IS
        l_status VARCHAR2(50);
        l_message VARCHAR2(4000);
        l_plant_count NUMBER := 0;
        l_pcs_count NUMBER := 0;
        l_processed_count NUMBER := 0;
        l_error_count NUMBER := 0;
        l_correlation_id VARCHAR2(36);
    BEGIN
        -- Generate batch correlation ID
        SELECT SYS_GUID() INTO l_correlation_id FROM DUAL;
        
        DBMS_OUTPUT.PUT_LINE('===== Starting Correct PCS Details Flow =====');
        DBMS_OUTPUT.PUT_LINE('Step 1: Getting active plants...');
        
        -- Step 1: Get active plants
        FOR plant_rec IN (
            SELECT DISTINCT plant_id
            FROM SELECTED_PLANTS
            WHERE is_active = 'Y'
        ) LOOP
            l_plant_count := l_plant_count + 1;
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Step 2: Fetching ALL PCS for plant ' || plant_rec.plant_id || '...');
            
            -- Step 2: Get ALL PCS revisions for this plant
            refresh_plant_pcs_list(
                p_plant_id => plant_rec.plant_id,
                p_status => l_status,
                p_message => l_message,
                p_correlation_id => l_correlation_id
            );
            
            IF l_status != 'SUCCESS' THEN
                DBMS_OUTPUT.PUT_LINE('  Error: ' || l_message);
                l_error_count := l_error_count + 1;
                CONTINUE;
            END IF;
            
            DBMS_OUTPUT.PUT_LINE('  ' || l_message);
            
            -- Count PCS to process
            SELECT COUNT(*) INTO l_pcs_count
            FROM PCS_LIST
            WHERE plant_id = plant_rec.plant_id
              AND is_valid = 'Y';
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Step 3: Loading details for ' || l_pcs_count || ' PCS revisions...');
            
            -- Step 3: For EACH PCS revision, load all 6 detail types
            FOR pcs_rec IN (
                SELECT plant_id, pcs_name, revision
                FROM PCS_LIST
                WHERE plant_id = plant_rec.plant_id
                  AND is_valid = 'Y'
                ORDER BY pcs_name, revision
            ) LOOP
                BEGIN
                    refresh_all_pcs_details(
                        p_plant_id => pcs_rec.plant_id,
                        p_pcs_name => pcs_rec.pcs_name,
                        p_pcs_revision => pcs_rec.revision,
                        p_status => l_status,
                        p_message => l_message,
                        p_correlation_id => l_correlation_id
                    );
                    
                    l_processed_count := l_processed_count + 1;
                    
                    IF l_status = 'ERROR' THEN
                        l_error_count := l_error_count + 1;
                    END IF;
                    
                    -- Progress indicator every 10 PCS
                    IF MOD(l_processed_count, 10) = 0 THEN
                        DBMS_OUTPUT.PUT_LINE('  Processed ' || l_processed_count || ' PCS revisions...');
                    END IF;
                    
                EXCEPTION
                    WHEN OTHERS THEN
                        l_error_count := l_error_count + 1;
                        DBMS_OUTPUT.PUT_LINE('  Error processing ' || pcs_rec.pcs_name || 
                                           ' Rev ' || pcs_rec.revision || ': ' || SQLERRM);
                END;
                
                -- Commit after each PCS to avoid losing work
                COMMIT;
            END LOOP;
        END LOOP;
        
        -- Final summary
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('===== Process Complete =====');
        DBMS_OUTPUT.PUT_LINE('Plants processed: ' || l_plant_count);
        DBMS_OUTPUT.PUT_LINE('PCS revisions processed: ' || l_processed_count);
        DBMS_OUTPUT.PUT_LINE('Errors: ' || l_error_count);
        
        IF l_error_count > 0 THEN
            p_status := 'PARTIAL';
            p_message := 'Processed ' || l_processed_count || ' PCS revisions with ' || 
                        l_error_count || ' errors';
        ELSE
            p_status := 'SUCCESS';
            p_message := 'Successfully processed ' || l_processed_count || ' PCS revisions';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'Fatal error: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('Fatal error: ' || SQLERRM);
    END process_pcs_details_correct_flow;

END pkg_api_client_pcs_details_v2;
/