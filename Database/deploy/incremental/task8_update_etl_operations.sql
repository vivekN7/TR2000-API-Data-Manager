-- ===============================================================================
-- Update PKG_ETL_OPERATIONS to include PCS Details
-- Date: 2025-08-28
-- Purpose: Add PCS details processing to ETL workflow (Task 8)
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_etl_operations AS
    PROCEDURE run_plants_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2);
    PROCEDURE run_issues_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2);
    PROCEDURE run_issues_etl_for_plant(
        p_plant_id IN VARCHAR2, 
        p_status OUT VARCHAR2, 
        p_message OUT VARCHAR2
    );
    PROCEDURE run_full_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2);
    PROCEDURE run_references_etl_for_issue(
        p_plant_id IN VARCHAR2,
        p_issue_revision IN VARCHAR2,
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    );
    PROCEDURE run_references_etl_for_all_selected(
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    );
    -- NEW: Run PCS details ETL for all selected PCS references
    PROCEDURE run_pcs_details_etl(
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    );
END pkg_etl_operations;
/

CREATE OR REPLACE PACKAGE BODY pkg_etl_operations AS

    -- Existing procedures remain unchanged (run_plants_etl, run_issues_etl, etc.)
    -- We'll just show the modified run_full_etl and new run_pcs_details_etl

    PROCEDURE run_full_etl(p_status OUT VARCHAR2, p_message OUT VARCHAR2) IS
        v_plant_status VARCHAR2(50);
        v_plant_message VARCHAR2(4000);
        v_issue_status VARCHAR2(50);
        v_issue_message VARCHAR2(4000);
        v_ref_status VARCHAR2(50);
        v_ref_message VARCHAR2(4000);
        v_pcs_status VARCHAR2(50);
        v_pcs_message VARCHAR2(4000);
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
            v_messages := v_messages || 'References: SUCCESS' || CHR(10);
        ELSIF v_ref_status = 'PARTIAL' THEN
            v_messages := v_messages || 'References: PARTIAL - ' || v_ref_message || CHR(10);
        ELSE
            v_error_count := v_error_count + 1;
            v_messages := v_messages || 'References: ' || v_ref_message || CHR(10);
        END IF;
        
        -- Step 4: NEW - Run PCS Details ETL for loaded PCS references
        DBMS_OUTPUT.PUT_LINE('Step 4: Loading PCS Details...');
        run_pcs_details_etl(v_pcs_status, v_pcs_message);
        
        IF v_pcs_status = 'SUCCESS' THEN
            v_messages := v_messages || 'PCS Details: SUCCESS' || CHR(10);
        ELSIF v_pcs_status = 'PARTIAL' THEN
            v_messages := v_messages || 'PCS Details: PARTIAL - ' || v_pcs_message || CHR(10);
        ELSIF v_pcs_status = 'NO_DATA' THEN
            v_messages := v_messages || 'PCS Details: No PCS references to process' || CHR(10);
        ELSE
            v_error_count := v_error_count + 1;
            v_messages := v_messages || 'PCS Details: ' || v_pcs_message || CHR(10);
        END IF;
        
        -- Set overall status
        IF v_error_count > 0 THEN
            p_status := 'PARTIAL';
            p_message := 'ETL completed with errors:' || CHR(10) || v_messages;
        ELSE
            p_status := 'SUCCESS';
            p_message := 'Full ETL completed successfully:' || CHR(10) || v_messages;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Full ETL Complete. Status: ' || p_status);
        DBMS_OUTPUT.PUT_LINE(p_message);
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'ETL failed with error: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('ETL Error: ' || SQLERRM);
            RAISE;
    END run_full_etl;

    -- NEW PROCEDURE: Run PCS details ETL
    PROCEDURE run_pcs_details_etl(
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_run_id NUMBER;
        v_start_time TIMESTAMP := SYSTIMESTAMP;
        v_pcs_count NUMBER;
        v_details_count NUMBER;
    BEGIN
        -- Check if we have PCS references to process
        SELECT COUNT(*)
        INTO v_pcs_count
        FROM PCS_REFERENCES pr
        WHERE pr.is_valid = 'Y'
          AND EXISTS (
              SELECT 1
              FROM SELECTED_ISSUES si
              WHERE si.plant_id = pr.plant_id
                AND si.issue_revision = pr.issue_revision
                AND si.is_active = 'Y'
          );
        
        IF v_pcs_count = 0 THEN
            p_status := 'NO_DATA';
            p_message := 'No PCS references found for selected issues';
            DBMS_OUTPUT.PUT_LINE('No PCS references to process');
            RETURN;
        END IF;
        
        -- Create ETL run log entry
        INSERT INTO ETL_RUN_LOG (
            run_id, endpoint_key, start_time, status, plant_id
        ) VALUES (
            ETL_RUN_LOG_SEQ.NEXTVAL, 'PCS_DETAILS', v_start_time, 'RUNNING', 'ALL'
        ) RETURNING run_id INTO v_run_id;
        
        -- Call the PCS details loading procedure
        pkg_api_client_pcs_details.process_all_selected_pcs_details(
            p_status => p_status,
            p_message => p_message
        );
        
        -- Count loaded details
        SELECT COUNT(*)
        INTO v_details_count
        FROM (
            SELECT 1 FROM PCS_HEADER_PROPERTIES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM PCS_TEMP_PRESSURES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM PCS_PIPE_SIZES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM PCS_PIPE_ELEMENTS WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM PCS_VALVE_ELEMENTS WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM PCS_EMBEDDED_NOTES WHERE is_valid = 'Y'
        );
        
        -- Update ETL run log
        UPDATE ETL_RUN_LOG
        SET end_time = SYSTIMESTAMP,
            status = p_status,
            records_processed = v_pcs_count,
            records_loaded = v_details_count,
            execution_time_seconds = 
                EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time))
        WHERE run_id = v_run_id;
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('PCS Details ETL completed. Status: ' || p_status);
        DBMS_OUTPUT.PUT_LINE('Processed ' || v_pcs_count || ' PCS references');
        DBMS_OUTPUT.PUT_LINE('Loaded ' || v_details_count || ' detail records');
        
    EXCEPTION
        WHEN OTHERS THEN
            IF v_run_id IS NOT NULL THEN
                UPDATE ETL_RUN_LOG
                SET end_time = SYSTIMESTAMP,
                    status = 'ERROR',
                    error_message = SQLERRM
                WHERE run_id = v_run_id;
                COMMIT;
            END IF;
            
            p_status := 'ERROR';
            p_message := 'Error in PCS details ETL: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('PCS Details ETL Error: ' || SQLERRM);
    END run_pcs_details_etl;

    -- Include all other existing procedures here...
    -- (run_plants_etl, run_issues_etl, run_issues_etl_for_plant, 
    --  run_references_etl_for_issue, run_references_etl_for_all_selected)
    -- These remain unchanged from the original package

END pkg_etl_operations;
/

-- Note: This is a partial update showing only the modified/new procedures
-- The actual deployment should include all existing procedures from the original package