-- ===============================================================================
-- Package: PKG_ETL_OPERATIONS
-- Purpose: Orchestrates the complete ETL pipeline
-- ===============================================================================

-- Package Specification
CREATE OR REPLACE PACKAGE pkg_etl_operations AS
    PROCEDURE run_plants_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2);
    PROCEDURE run_issues_etl_for_plant(p_plant_id VARCHAR2, p_status OUT VARCHAR2, p_message OUT VARCHAR2);
    PROCEDURE run_references_etl_for_issue(p_plant_id VARCHAR2, p_issue_revision VARCHAR2, p_status OUT VARCHAR2, p_message OUT VARCHAR2);
    PROCEDURE run_references_etl_for_all_selected(p_status OUT VARCHAR2, p_message OUT VARCHAR2);
    PROCEDURE run_full_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2);
END pkg_etl_operations;
/

-- Package Body
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
                pkg_parse_issues.parse_issues_json(rec.raw_json_id, p_plant_id);

                -- Upsert to core
                pkg_upsert_issues.upsert_issues;
            END LOOP;

            -- Update run log
            UPDATE ETL_RUN_LOG
            SET end_time = SYSTIMESTAMP,
                status = 'SUCCESS',
                duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
            WHERE run_id = v_run_id;

            p_status := 'SUCCESS';
            p_message := 'Issues ETL for plant ' || p_plant_id || ' completed successfully';

        EXCEPTION
            WHEN OTHERS THEN
                DECLARE
                    v_error_code NUMBER := SQLCODE;
                    v_error_msg VARCHAR2(4000) := SQLERRM;
                    v_error_stack VARCHAR2(4000) := DBMS_UTILITY.FORMAT_ERROR_STACK();
                BEGIN
                    -- Log error
                    INSERT INTO ETL_ERROR_LOG (
                        run_id, endpoint_key, plant_id, error_timestamp, error_type,
                        error_code, error_message, error_stack
                    ) VALUES (
                        v_run_id, 'issues', p_plant_id, SYSTIMESTAMP, 'PROCEDURE_ERROR',
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
    END run_issues_etl_for_plant;

    PROCEDURE run_references_etl_for_issue(
        p_plant_id VARCHAR2, 
        p_issue_revision VARCHAR2, 
        p_status OUT VARCHAR2, 
        p_message OUT VARCHAR2
    ) IS
        v_run_id NUMBER;
        v_start_time TIMESTAMP;
        v_api_status VARCHAR2(50);
        v_api_message VARCHAR2(4000);
        v_success_count NUMBER := 0;
        v_error_count NUMBER := 0;
    BEGIN
        -- Log ETL start
        v_start_time := SYSTIMESTAMP;
        INSERT INTO ETL_RUN_LOG (
            run_type, endpoint_key, plant_id, issue_revision, 
            start_time, status, initiated_by
        ) VALUES (
            'REFERENCES_ETL', 'references', p_plant_id, p_issue_revision,
            v_start_time, 'RUNNING', USER
        )
        RETURNING run_id INTO v_run_id;

        BEGIN
            -- Check if issue exists and is valid
            DECLARE
                v_issue_valid VARCHAR2(1);
            BEGIN
                SELECT is_valid INTO v_issue_valid
                FROM ISSUES
                WHERE plant_id = p_plant_id
                AND issue_revision = p_issue_revision;
                
                IF v_issue_valid = 'N' THEN
                    p_status := 'SKIPPED';
                    p_message := 'Issue ' || p_plant_id || '/' || p_issue_revision || ' is not valid';
                    
                    UPDATE ETL_RUN_LOG
                    SET end_time = SYSTIMESTAMP,
                        status = 'SKIPPED',
                        notes = p_message
                    WHERE run_id = v_run_id;
                    
                    RETURN;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    p_status := 'ERROR';
                    p_message := 'Issue ' || p_plant_id || '/' || p_issue_revision || ' not found';
                    
                    UPDATE ETL_RUN_LOG
                    SET end_time = SYSTIMESTAMP,
                        status = 'ERROR',
                        notes = p_message
                    WHERE run_id = v_run_id;
                    
                    RETURN;
            END;
            
            -- Call the reference loading procedure
            pkg_api_client_references.refresh_all_issue_references(
                p_plant_id => p_plant_id,
                p_issue_rev => p_issue_revision,
                p_status => v_api_status,
                p_message => v_api_message
            );
            
            IF v_api_status = 'SUCCESS' THEN
                -- Count loaded references
                SELECT COUNT(*) INTO v_success_count
                FROM (
                    SELECT 1 FROM PCS_REFERENCES 
                    WHERE plant_id = p_plant_id 
                    AND issue_revision = p_issue_revision 
                    AND is_valid = 'Y'
                    UNION ALL
                    SELECT 1 FROM VDS_REFERENCES 
                    WHERE plant_id = p_plant_id 
                    AND issue_revision = p_issue_revision 
                    AND is_valid = 'Y'
                    -- Add other reference tables as needed
                );
                
                UPDATE ETL_RUN_LOG
                SET end_time = SYSTIMESTAMP,
                    status = 'SUCCESS',
                    records_processed = v_success_count,
                    duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400),
                    notes = 'Loaded ' || v_success_count || ' references'
                WHERE run_id = v_run_id;
                
                p_status := 'SUCCESS';
                p_message := 'References ETL completed for ' || p_plant_id || '/' || p_issue_revision || 
                            ' (' || v_success_count || ' references)';
            ELSE
                UPDATE ETL_RUN_LOG
                SET end_time = SYSTIMESTAMP,
                    status = 'FAILED',
                    notes = v_api_message
                WHERE run_id = v_run_id;
                
                p_status := 'FAILED';
                p_message := v_api_message;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                DECLARE
                    v_error_code NUMBER := SQLCODE;
                    v_error_msg VARCHAR2(4000) := SQLERRM;
                    v_error_stack VARCHAR2(4000) := DBMS_UTILITY.FORMAT_ERROR_STACK();
                BEGIN
                    -- Log error
                    INSERT INTO ETL_ERROR_LOG (
                        run_id, endpoint_key, plant_id, issue_revision,
                        error_timestamp, error_type, error_code, 
                        error_message, error_stack
                    ) VALUES (
                        v_run_id, 'references', p_plant_id, p_issue_revision,
                        SYSTIMESTAMP, 'PROCEDURE_ERROR', v_error_code, 
                        v_error_msg, v_error_stack
                    );

                    -- Update run log
                    UPDATE ETL_RUN_LOG
                    SET end_time = SYSTIMESTAMP,
                        status = 'FAILED',
                        notes = v_error_msg
                    WHERE run_id = v_run_id;

                    p_status := 'FAILED';
                    p_message := v_error_msg;
                    RAISE;
                END;
        END;
    END run_references_etl_for_issue;

    PROCEDURE run_references_etl_for_all_selected(
        p_status OUT VARCHAR2, 
        p_message OUT VARCHAR2
    ) IS
        v_total_count NUMBER := 0;
        v_success_count NUMBER := 0;
        v_skip_count NUMBER := 0;
        v_error_count NUMBER := 0;
        v_issue_status VARCHAR2(50);
        v_issue_message VARCHAR2(4000);
        v_messages CLOB;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(v_messages, TRUE);
        
        -- Loop through all active selected issues
        FOR issue_rec IN (
            SELECT si.plant_id, si.issue_revision
            FROM SELECTED_ISSUES si
            WHERE si.is_active = 'Y'
            ORDER BY si.plant_id, si.issue_revision
        ) LOOP
            v_total_count := v_total_count + 1;
            
            -- Load references for this issue
            run_references_etl_for_issue(
                p_plant_id => issue_rec.plant_id,
                p_issue_revision => issue_rec.issue_revision,
                p_status => v_issue_status,
                p_message => v_issue_message
            );
            
            -- Track results
            IF v_issue_status = 'SUCCESS' THEN
                v_success_count := v_success_count + 1;
                DBMS_LOB.APPEND(v_messages, '✓ ' || issue_rec.plant_id || '/' || 
                               issue_rec.issue_revision || ': ' || v_issue_message || CHR(10));
            ELSIF v_issue_status = 'SKIPPED' THEN
                v_skip_count := v_skip_count + 1;
                DBMS_LOB.APPEND(v_messages, '- ' || issue_rec.plant_id || '/' || 
                               issue_rec.issue_revision || ': ' || v_issue_message || CHR(10));
            ELSE
                v_error_count := v_error_count + 1;
                DBMS_LOB.APPEND(v_messages, '✗ ' || issue_rec.plant_id || '/' || 
                               issue_rec.issue_revision || ': ' || v_issue_message || CHR(10));
            END IF;
        END LOOP;
        
        -- Prepare summary
        IF v_total_count = 0 THEN
            p_status := 'NO_DATA';
            p_message := 'No active issues selected for reference loading';
        ELSIF v_error_count = 0 AND v_skip_count = 0 THEN
            p_status := 'SUCCESS';
            p_message := 'All ' || v_success_count || ' selected issues processed successfully';
        ELSIF v_error_count > 0 THEN
            p_status := 'PARTIAL';
            p_message := 'Processed ' || v_total_count || ' issues: ' ||
                        v_success_count || ' success, ' ||
                        v_skip_count || ' skipped, ' ||
                        v_error_count || ' failed';
        ELSE
            p_status := 'SUCCESS';
            p_message := 'Processed ' || v_total_count || ' issues: ' ||
                        v_success_count || ' success, ' ||
                        v_skip_count || ' skipped';
        END IF;
        
        -- Add detail messages if any issues were processed
        IF v_total_count > 0 AND DBMS_LOB.GETLENGTH(v_messages) > 0 THEN
            p_message := p_message || CHR(10) || CHR(10) || 
                        'Details:' || CHR(10) || 
                        DBMS_LOB.SUBSTR(v_messages, 3900, 1);
        END IF;
        
        DBMS_LOB.FREETEMPORARY(v_messages);
        
    EXCEPTION
        WHEN OTHERS THEN
            IF DBMS_LOB.ISTEMPORARY(v_messages) = 1 THEN
                DBMS_LOB.FREETEMPORARY(v_messages);
            END IF;
            p_status := 'ERROR';
            p_message := 'Error loading references: ' || SQLERRM;
            RAISE;
    END run_references_etl_for_all_selected;

    PROCEDURE run_full_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2) IS
        v_plant_status VARCHAR2(50);
        v_plant_message VARCHAR2(4000);
        v_issue_status VARCHAR2(50);
        v_issue_message VARCHAR2(4000);
        v_ref_status VARCHAR2(50);
        v_ref_message VARCHAR2(4000);
        v_error_count NUMBER := 0;
        v_messages VARCHAR2(4000);
    BEGIN
        -- Check if we have any selections first
        DECLARE
            v_plant_count NUMBER;
            v_issue_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_plant_count 
            FROM SELECTED_PLANTS WHERE is_active = 'Y';
            
            SELECT COUNT(*) INTO v_issue_count 
            FROM SELECTED_ISSUES WHERE is_active = 'Y';
            
            IF v_plant_count = 0 AND v_issue_count = 0 THEN
                p_status := 'NO_DATA';
                p_message := 'No plants or issues selected for processing';
                RETURN;
            END IF;
        END;
        
        -- Step 1: Run Plants ETL
        DBMS_OUTPUT.PUT_LINE('Step 1: Loading Plants...');
        run_plants_etl(v_plant_status, v_plant_message);
        
        IF v_plant_status != 'SUCCESS' THEN
            v_error_count := v_error_count + 1;
            v_messages := v_messages || 'Plants: ' || v_plant_message || CHR(10);
        ELSE
            v_messages := v_messages || 'Plants: SUCCESS' || CHR(10);
        END IF;

        -- Step 2: Run Issues ETL for each active plant
        DBMS_OUTPUT.PUT_LINE('Step 2: Loading Issues...');
        FOR plant_rec IN (
            SELECT DISTINCT plant_id
            FROM SELECTED_PLANTS
            WHERE is_active = 'Y'
        ) LOOP
            run_issues_etl_for_plant(plant_rec.plant_id, v_issue_status, v_issue_message);

            IF v_issue_status != 'SUCCESS' THEN
                v_error_count := v_error_count + 1;
                v_messages := v_messages || 'Issues (' || plant_rec.plant_id || '): ' || 
                             v_issue_message || CHR(10);
            END IF;
        END LOOP;
        
        -- Step 3: Run References ETL for all selected issues
        DBMS_OUTPUT.PUT_LINE('Step 3: Loading References for Selected Issues...');
        run_references_etl_for_all_selected(v_ref_status, v_ref_message);
        
        IF v_ref_status = 'SUCCESS' THEN
            v_messages := v_messages || 'References: SUCCESS - ' || v_ref_message || CHR(10);
        ELSIF v_ref_status = 'PARTIAL' THEN
            v_error_count := v_error_count + 1;
            v_messages := v_messages || 'References: PARTIAL - ' || v_ref_message || CHR(10);
        ELSIF v_ref_status = 'NO_DATA' THEN
            v_messages := v_messages || 'References: No selected issues to process' || CHR(10);
        ELSE
            v_error_count := v_error_count + 1;
            v_messages := v_messages || 'References: FAILED - ' || v_ref_message || CHR(10);
        END IF;

        -- Final status
        IF v_error_count = 0 THEN
            p_status := 'SUCCESS';
            p_message := 'Full ETL completed successfully' || CHR(10) || CHR(10) || v_messages;
        ELSE
            p_status := 'PARTIAL';
            p_message := 'ETL completed with ' || v_error_count || ' errors' || CHR(10) || CHR(10) || v_messages;
        END IF;
    END run_full_etl;

END pkg_etl_operations;
/