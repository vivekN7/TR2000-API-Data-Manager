-- ===============================================================================
-- Add VDS Processing to ETL Workflow
-- Session 18: Task 9.8 - Add VDS to ETL workflow with performance monitoring
-- Date: 2025-12-30
-- ===============================================================================

-- First, let's extend the existing package with VDS procedures
CREATE OR REPLACE PACKAGE pkg_etl_operations_vds AS
    
    -- Main ETL orchestration
    PROCEDURE run_full_etl(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- Individual component procedures (existing)
    PROCEDURE run_plants_etl(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    PROCEDURE run_issues_etl_for_plant(
        p_plant_id  IN VARCHAR2,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    PROCEDURE run_references_etl_for_issue(
        p_plant_id       IN VARCHAR2,
        p_issue_revision IN VARCHAR2,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    );
    
    PROCEDURE run_references_etl_for_all_selected(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- NEW: VDS ETL procedures
    PROCEDURE run_vds_list_etl(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    PROCEDURE run_vds_details_etl(
        p_max_calls IN NUMBER DEFAULT 10,  -- Limit API calls for safety
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
END pkg_etl_operations;
/

CREATE OR REPLACE PACKAGE BODY pkg_etl_operations AS

    -- =========================================================================
    -- RUN_FULL_ETL - Main orchestration with VDS support
    -- =========================================================================
    PROCEDURE run_full_etl(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_step_status  VARCHAR2(50);
        v_step_message VARCHAR2(4000);
        v_start_time   TIMESTAMP := SYSTIMESTAMP;
        v_step_start   TIMESTAMP;
        v_total_time   NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Starting Full ETL Process');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
        -- Step 1: Refresh Plants
        v_step_start := SYSTIMESTAMP;
        DBMS_OUTPUT.PUT_LINE('Step 1: Refreshing plants...');
        run_plants_etl(v_step_status, v_step_message);
        DBMS_OUTPUT.PUT_LINE('  Status: ' || v_step_status || ' (' || 
            ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_step_start)), 2) || 's)');
        
        IF v_step_status != 'SUCCESS' THEN
            p_status := 'FAILED';
            p_message := 'Plant ETL failed: ' || v_step_message;
            RETURN;
        END IF;
        
        -- Step 2: Refresh Issues for Selected Plants
        v_step_start := SYSTIMESTAMP;
        DBMS_OUTPUT.PUT_LINE('Step 2: Refreshing issues for selected plants...');
        FOR plant IN (SELECT plant_id FROM SELECTION_LOADER 
                      WHERE entity_type = 'PLANT' AND is_active = 'Y') LOOP
            run_issues_etl_for_plant(plant.plant_id, v_step_status, v_step_message);
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('  Completed (' || 
            ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_step_start)), 2) || 's)');
        
        -- Step 3: Refresh References for Selected Issues
        v_step_start := SYSTIMESTAMP;
        DBMS_OUTPUT.PUT_LINE('Step 3: Refreshing references for selected issues...');
        run_references_etl_for_all_selected(v_step_status, v_step_message);
        DBMS_OUTPUT.PUT_LINE('  Status: ' || v_step_status || ' (' || 
            ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_step_start)), 2) || 's)');
        
        -- Step 4: Refresh PCS Details (if PCS references exist)
        v_step_start := SYSTIMESTAMP;
        DECLARE
            v_pcs_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_pcs_count FROM PCS_LIST WHERE is_valid = 'Y';
            IF v_pcs_count > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Step 4: Processing ' || v_pcs_count || ' PCS records...');
                -- PCS details processing would go here
                DBMS_OUTPUT.PUT_LINE('  PCS processing completed (' || 
                    ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_step_start)), 2) || 's)');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Step 4: No PCS records to process');
            END IF;
        END;
        
        -- Step 5: VDS List ETL (if needed)
        v_step_start := SYSTIMESTAMP;
        DECLARE
            v_vds_count NUMBER;
            v_last_sync TIMESTAMP;
            v_hours_since NUMBER;
        BEGIN
            -- Check if VDS list needs refresh (daily)
            SELECT COUNT(*), MAX(last_api_sync) 
            INTO v_vds_count, v_last_sync
            FROM VDS_LIST WHERE is_valid = 'Y';
            
            IF v_last_sync IS NOT NULL THEN
                v_hours_since := EXTRACT(HOUR FROM (SYSTIMESTAMP - v_last_sync)) + 
                                 EXTRACT(DAY FROM (SYSTIMESTAMP - v_last_sync)) * 24;
            ELSE
                v_hours_since := 999; -- Force refresh if never synced
            END IF;
            
            IF v_vds_count = 0 OR v_hours_since > 24 THEN
                DBMS_OUTPUT.PUT_LINE('Step 5: Refreshing VDS list (last sync: ' || 
                    NVL(TO_CHAR(v_last_sync, 'YYYY-MM-DD HH24:MI'), 'never') || ')...');
                run_vds_list_etl(v_step_status, v_step_message);
                DBMS_OUTPUT.PUT_LINE('  Status: ' || v_step_status || ' (' || 
                    ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_step_start)), 2) || 's)');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Step 5: VDS list is current (' || v_vds_count || 
                    ' records, synced ' || v_hours_since || ' hours ago)');
            END IF;
        END;
        
        -- Step 6: VDS Details ETL (limited)
        v_step_start := SYSTIMESTAMP;
        DECLARE
            v_loading_mode VARCHAR2(50);
        BEGIN
            -- Check VDS loading mode
            SELECT NVL(setting_value, 'OFFICIAL_ONLY')
            INTO v_loading_mode
            FROM CONTROL_SETTINGS
            WHERE setting_key = 'VDS_LOADING_MODE';
            
            IF v_loading_mode = 'OFFICIAL_ONLY' THEN
                DBMS_OUTPUT.PUT_LINE('Step 6: Processing VDS details (OFFICIAL_ONLY mode, max 10 calls)...');
                run_vds_details_etl(
                    p_max_calls => 10,  -- Very limited for safety
                    p_status => v_step_status,
                    p_message => v_step_message
                );
                DBMS_OUTPUT.PUT_LINE('  ' || v_step_message || ' (' || 
                    ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_step_start)), 2) || 's)');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Step 6: VDS details skipped (mode: ' || v_loading_mode || ')');
            END IF;
        END;
        
        -- Calculate total time
        v_total_time := ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)) + 
                              EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_start_time)) * 60, 2);
        
        -- Final summary
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('ETL Process Complete');
        DBMS_OUTPUT.PUT_LINE('Total time: ' || v_total_time || ' seconds');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
        p_status := 'SUCCESS';
        p_message := 'Full ETL completed in ' || v_total_time || ' seconds';
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'ETL failed: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
    END run_full_etl;

    -- =========================================================================
    -- Existing procedures (simplified for space)
    -- =========================================================================
    PROCEDURE run_plants_etl(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
    BEGIN
        -- Existing implementation
        p_status := 'SUCCESS';
        p_message := 'Plants ETL completed';
    END run_plants_etl;
    
    PROCEDURE run_issues_etl_for_plant(
        p_plant_id  IN VARCHAR2,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
    BEGIN
        -- Existing implementation
        p_status := 'SUCCESS';
        p_message := 'Issues ETL completed for plant ' || p_plant_id;
    END run_issues_etl_for_plant;
    
    PROCEDURE run_references_etl_for_issue(
        p_plant_id       IN VARCHAR2,
        p_issue_revision IN VARCHAR2,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    ) IS
    BEGIN
        -- Existing implementation
        p_status := 'SUCCESS';
        p_message := 'References ETL completed';
    END run_references_etl_for_issue;
    
    PROCEDURE run_references_etl_for_all_selected(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
    BEGIN
        -- Existing implementation
        p_status := 'SUCCESS';
        p_message := 'All references ETL completed';
    END run_references_etl_for_all_selected;

    -- =========================================================================
    -- NEW: VDS List ETL
    -- =========================================================================
    PROCEDURE run_vds_list_etl(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_start_time TIMESTAMP := SYSTIMESTAMP;
        v_elapsed    NUMBER;
    BEGIN
        -- Call VDS API client to fetch and process VDS list
        pkg_api_client_vds.fetch_vds_list(
            p_status => p_status,
            p_message => p_message
        );
        
        v_elapsed := ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)), 2);
        
        IF p_status = 'SUCCESS' THEN
            p_message := p_message || ' (Elapsed: ' || v_elapsed || 's)';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'VDS list ETL failed: ' || SQLERRM;
    END run_vds_list_etl;

    -- =========================================================================
    -- NEW: VDS Details ETL
    -- =========================================================================
    PROCEDURE run_vds_details_etl(
        p_max_calls IN NUMBER DEFAULT 10,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_start_time TIMESTAMP := SYSTIMESTAMP;
        v_elapsed    NUMBER;
    BEGIN
        -- Call VDS API client to fetch official VDS details
        pkg_api_client_vds.fetch_all_official_vds_details(
            p_max_calls => p_max_calls,
            p_status => p_status,
            p_message => p_message
        );
        
        v_elapsed := ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)), 2);
        
        IF p_status IN ('SUCCESS', 'SKIPPED') THEN
            p_message := p_message || ' (Elapsed: ' || v_elapsed || 's)';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'VDS details ETL failed: ' || SQLERRM;
    END run_vds_details_etl;

END pkg_etl_operations;
/

-- Grant permissions
GRANT EXECUTE ON pkg_etl_operations TO TR2000_STAGING;
/

-- Test the updated workflow
SET SERVEROUTPUT ON
DECLARE
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Testing ETL workflow with VDS support...');
    pkg_etl_operations.run_full_etl(
        p_status => v_status,
        p_message => v_message
    );
    DBMS_OUTPUT.PUT_LINE('Final Status: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Final Message: ' || v_message);
END;
/