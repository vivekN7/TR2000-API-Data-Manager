-- ===============================================================================
-- Fix Empty Selection Handling in PKG_ETL_OPERATIONS
-- Date: 2025-08-27
-- Issue: ETL fails when no plants are selected
-- ===============================================================================

CREATE OR REPLACE PACKAGE BODY pkg_etl_operations AS

    PROCEDURE run_plants_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2) IS
        v_run_id NUMBER;
        v_start_time TIMESTAMP;
    BEGIN
        -- Log ETL start
        v_start_time := SYSTIMESTAMP;
        INSERT INTO ETL_RUN_LOG (run_type, endpoint_key, start_time, status, initiated_by)
        VALUES ('PLANTS_ETL', 'plants', v_start_time, 'RUNNING', USER)
        RETURNING run_id INTO v_run_id;

        BEGIN
            -- Note: Raw JSON insert will be done from C# after API call
            -- Here we just process existing RAW_JSON records

            -- Get latest raw_json_id for plants
            FOR rec IN (
                SELECT raw_json_id
                FROM RAW_JSON
                WHERE endpoint = 'plants'
                ORDER BY created_date DESC
                FETCH FIRST 1 ROWS ONLY
            ) LOOP
                -- Parse JSON to staging
                pkg_parse_plants.parse_plants_json(rec.raw_json_id);

                -- Upsert to core
                pkg_upsert_plants.upsert_plants;
            END LOOP;

            -- Update run log
            UPDATE ETL_RUN_LOG
            SET end_time = SYSTIMESTAMP,
                status = 'SUCCESS',
                duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
            WHERE run_id = v_run_id;

            p_status := 'SUCCESS';
            p_message := 'Plants ETL completed successfully';

        EXCEPTION
            WHEN OTHERS THEN
                DECLARE
                    v_error_code NUMBER := SQLCODE;
                    v_error_msg VARCHAR2(4000) := SQLERRM;
                    v_error_stack VARCHAR2(4000) := DBMS_UTILITY.FORMAT_ERROR_STACK();
                BEGIN
                    -- Log error
                    INSERT INTO ETL_ERROR_LOG (
                        run_id, endpoint_key, error_timestamp, error_type,
                        error_code, error_message, error_stack
                    ) VALUES (
                        v_run_id, 'plants', SYSTIMESTAMP, 'PROCEDURE_ERROR',
                        v_error_code, v_error_msg, v_error_stack
                    );

                    -- Update run log
                    UPDATE ETL_RUN_LOG
                    SET end_time = SYSTIMESTAMP,
                        status = 'FAILED',
                        duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                    WHERE run_id = v_run_id;

                    p_status := 'FAILED';
                    p_message := v_error_msg;
                    RAISE;
                END;
        END;
    END run_plants_etl;

    PROCEDURE run_issues_etl_for_plant(p_plant_id VARCHAR2, p_status OUT VARCHAR2, p_message OUT VARCHAR2) IS
        v_run_id NUMBER;
        v_start_time TIMESTAMP;
    BEGIN
        -- Log ETL start
        v_start_time := SYSTIMESTAMP;
        INSERT INTO ETL_RUN_LOG (run_type, endpoint_key, plant_id, start_time, status, initiated_by)
        VALUES ('ISSUES_ETL', 'issues', p_plant_id, v_start_time, 'RUNNING', USER)
        RETURNING run_id INTO v_run_id;

        BEGIN
            -- Get latest raw_json_id for this plant's issues
            FOR rec IN (
                SELECT raw_json_id
                FROM RAW_JSON
                WHERE endpoint = 'issues'
                  AND plant_id = p_plant_id
                ORDER BY created_date DESC
                FETCH FIRST 1 ROWS ONLY
            ) LOOP
                -- Parse JSON to staging
                pkg_parse_issues.parse_issues_json(rec.raw_json_id);

                -- Upsert to core
                pkg_upsert_issues.upsert_issues(p_plant_id);
            END LOOP;

            -- Update run log
            UPDATE ETL_RUN_LOG
            SET end_time = SYSTIMESTAMP,
                status = 'SUCCESS',
                duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
            WHERE run_id = v_run_id;

            p_status := 'SUCCESS';
            p_message := 'Issues ETL completed for plant ' || p_plant_id;

        EXCEPTION
            WHEN OTHERS THEN
                DECLARE
                    v_error_code NUMBER := SQLCODE;
                    v_error_msg VARCHAR2(4000) := SQLERRM;
                BEGIN
                    -- Log error
                    INSERT INTO ETL_ERROR_LOG (
                        run_id, endpoint_key, plant_id, error_timestamp, error_type,
                        error_code, error_message
                    ) VALUES (
                        v_run_id, 'issues', p_plant_id, SYSTIMESTAMP, 'PROCEDURE_ERROR',
                        v_error_code, v_error_msg
                    );

                    -- Update run log
                    UPDATE ETL_RUN_LOG
                    SET end_time = SYSTIMESTAMP,
                        status = 'FAILED',
                        duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                    WHERE run_id = v_run_id;

                    p_status := 'FAILED';
                    p_message := v_error_msg;
                    RAISE;
                END;
        END;
    END run_issues_etl_for_plant;

    PROCEDURE run_references_etl_for_issue(
        p_plant_id VARCHAR2, 
        p_issue_revision VARCHAR2, 
        p_status OUT VARCHAR2, 
        p_message OUT VARCHAR2
    ) IS
        v_run_id NUMBER;
        v_start_time TIMESTAMP;
        v_ref_count NUMBER := 0;
    BEGIN
        -- Log ETL start
        v_start_time := SYSTIMESTAMP;
        INSERT INTO ETL_RUN_LOG (run_type, endpoint_key, plant_id, issue_revision, start_time, status, initiated_by)
        VALUES ('REFERENCES_ETL', 'references', p_plant_id, p_issue_revision, v_start_time, 'RUNNING', USER)
        RETURNING run_id INTO v_run_id;

        BEGIN
            -- Process each reference type
            FOR ref_type IN (
                SELECT DISTINCT endpoint_key, reference_type
                FROM CONTROL_ENDPOINTS
                WHERE endpoint_key LIKE '%references%'
                  AND is_active = 'Y'
            ) LOOP
                -- Get the raw JSON for this reference type
                FOR rec IN (
                    SELECT raw_json_id
                    FROM RAW_JSON
                    WHERE endpoint = ref_type.endpoint_key
                      AND plant_id = p_plant_id
                      AND issue_revision = p_issue_revision
                    ORDER BY created_date DESC
                    FETCH FIRST 1 ROWS ONLY
                ) LOOP
                    -- Parse based on reference type
                    CASE ref_type.reference_type
                        WHEN 'PCS' THEN
                            pkg_parse_references.parse_pcs_references(rec.raw_json_id);
                            pkg_upsert_references.upsert_pcs_references(p_plant_id, p_issue_revision);
                        WHEN 'SC' THEN
                            pkg_parse_references.parse_sc_references(rec.raw_json_id);
                            pkg_upsert_references.upsert_sc_references(p_plant_id, p_issue_revision);
                        WHEN 'VSM' THEN
                            pkg_parse_references.parse_vsm_references(rec.raw_json_id);
                            pkg_upsert_references.upsert_vsm_references(p_plant_id, p_issue_revision);
                        WHEN 'VDS' THEN
                            pkg_parse_references.parse_vds_references(rec.raw_json_id);
                            pkg_upsert_references.upsert_vds_references(p_plant_id, p_issue_revision);
                        WHEN 'EDS' THEN
                            pkg_parse_references.parse_eds_references(rec.raw_json_id);
                            pkg_upsert_references.upsert_eds_references(p_plant_id, p_issue_revision);
                        WHEN 'MDS' THEN
                            pkg_parse_references.parse_mds_references(rec.raw_json_id);
                            pkg_upsert_references.upsert_mds_references(p_plant_id, p_issue_revision);
                        WHEN 'VSK' THEN
                            pkg_parse_references.parse_vsk_references(rec.raw_json_id);
                            pkg_upsert_references.upsert_vsk_references(p_plant_id, p_issue_revision);
                        WHEN 'ESK' THEN
                            pkg_parse_references.parse_esk_references(rec.raw_json_id);
                            pkg_upsert_references.upsert_esk_references(p_plant_id, p_issue_revision);
                        WHEN 'PIPE_ELEMENT' THEN
                            pkg_parse_references.parse_pipe_element_references(rec.raw_json_id);
                            pkg_upsert_references.upsert_pipe_element_references(p_plant_id, p_issue_revision);
                    END CASE;
                    
                    v_ref_count := v_ref_count + 1;
                END LOOP;
            END LOOP;

            -- Update run log
            UPDATE ETL_RUN_LOG
            SET end_time = SYSTIMESTAMP,
                status = 'SUCCESS',
                duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400),
                records_processed = v_ref_count
            WHERE run_id = v_run_id;

            p_status := 'SUCCESS';
            p_message := 'References ETL completed for ' || p_plant_id || '/' || p_issue_revision || 
                        ' - ' || v_ref_count || ' reference types processed';

        EXCEPTION
            WHEN OTHERS THEN
                DECLARE
                    v_error_code NUMBER := SQLCODE;
                    v_error_msg VARCHAR2(4000) := SQLERRM;
                BEGIN
                    -- Log error
                    INSERT INTO ETL_ERROR_LOG (
                        run_id, endpoint_key, plant_id, issue_revision, error_timestamp, 
                        error_type, error_code, error_message
                    ) VALUES (
                        v_run_id, 'references', p_plant_id, p_issue_revision, SYSTIMESTAMP, 
                        'PROCEDURE_ERROR', v_error_code, v_error_msg
                    );

                    -- Update run log
                    UPDATE ETL_RUN_LOG
                    SET end_time = SYSTIMESTAMP,
                        status = 'FAILED',
                        duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                    WHERE run_id = v_run_id;

                    p_status := 'FAILED';
                    p_message := v_error_msg;
                    RAISE;
                END;
        END;
    END run_references_etl_for_issue;

    PROCEDURE run_references_etl_for_all_selected(p_status OUT VARCHAR2, p_message OUT VARCHAR2) IS
        v_issue_count NUMBER := 0;
        v_success_count NUMBER := 0;
        v_fail_count NUMBER := 0;
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
    BEGIN
        -- FIX: Check if there are any selected issues first
        SELECT COUNT(*) INTO v_issue_count
        FROM SELECTED_ISSUES
        WHERE is_active = 'Y';
        
        IF v_issue_count = 0 THEN
            p_status := 'NO_DATA';
            p_message := 'No selected issues to process';
            RETURN;
        END IF;
        
        -- Process each selected issue
        FOR rec IN (
            SELECT si.plant_id, si.issue_revision
            FROM SELECTED_ISSUES si
            WHERE si.is_active = 'Y'
            ORDER BY si.plant_id, si.issue_revision
        ) LOOP
            v_issue_count := v_issue_count + 1;
            
            BEGIN
                run_references_etl_for_issue(
                    p_plant_id => rec.plant_id,
                    p_issue_revision => rec.issue_revision,
                    p_status => v_status,
                    p_message => v_message
                );
                
                IF v_status = 'SUCCESS' THEN
                    v_success_count := v_success_count + 1;
                ELSE
                    v_fail_count := v_fail_count + 1;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_fail_count := v_fail_count + 1;
                    -- Continue processing other issues
            END;
        END LOOP;

        -- Set overall status
        IF v_fail_count = 0 THEN
            p_status := 'SUCCESS';
            p_message := 'All ' || v_success_count || ' selected issues processed successfully';
        ELSIF v_success_count = 0 THEN
            p_status := 'FAILED';
            p_message := 'All ' || v_fail_count || ' selected issues failed';
        ELSE
            p_status := 'PARTIAL';
            p_message := v_success_count || ' succeeded, ' || v_fail_count || ' failed';
        END IF;
    END run_references_etl_for_all_selected;

    PROCEDURE run_full_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2) IS
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_plant_count NUMBER := 0;
        v_issue_count NUMBER := 0;
        v_has_failures BOOLEAN := FALSE;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Step 1: Loading Plants...');
        
        -- Run plants ETL
        run_plants_etl(v_status, v_message);
        IF v_status != 'SUCCESS' THEN
            v_has_failures := TRUE;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Step 2: Loading Issues...');
        
        -- FIX: Check if there are any selected plants first
        SELECT COUNT(*) INTO v_plant_count
        FROM SELECTED_PLANTS
        WHERE is_active = 'Y';
        
        IF v_plant_count = 0 THEN
            p_status := 'NO_DATA';
            p_message := 'No selected plants to process';
            RETURN;
        END IF;
        
        -- Run issues ETL for each selected plant
        FOR rec IN (
            SELECT plant_id
            FROM SELECTED_PLANTS
            WHERE is_active = 'Y'
        ) LOOP
            v_plant_count := v_plant_count + 1;
            
            BEGIN
                run_issues_etl_for_plant(rec.plant_id, v_status, v_message);
                IF v_status != 'SUCCESS' THEN
                    v_has_failures := TRUE;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_has_failures := TRUE;
                    -- Continue with other plants
            END;
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('Step 3: Loading References for Selected Issues...');
        
        -- Run references ETL for all selected issues
        run_references_etl_for_all_selected(v_status, v_message);
        IF v_status = 'FAILED' THEN
            v_has_failures := TRUE;
        END IF;
        
        -- Set overall status
        IF v_has_failures THEN
            p_status := 'PARTIAL';
            p_message := 'ETL completed with some failures';
        ELSE
            p_status := 'SUCCESS';
            p_message := 'Full ETL completed successfully';
        END IF;
    END run_full_etl;

END pkg_etl_operations;
/

PROMPT
PROMPT ===============================================================================
PROMPT Fix Applied: Empty Selection Handling
PROMPT - Added check for empty selected issues in run_references_etl_for_all_selected
PROMPT - Added check for empty selected plants in run_full_etl
PROMPT - Both return 'NO_DATA' status instead of failing
PROMPT ===============================================================================
PROMPT