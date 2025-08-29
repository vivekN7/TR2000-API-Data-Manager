-- ===============================================================================
-- PKG_VDS_WORKFLOW - VDS ETL Workflow Management
-- Session 18: Task 9.8 - VDS ETL workflow with performance monitoring
-- Purpose: Orchestrate VDS ETL operations with monitoring and safety limits
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_vds_workflow AS
    
    -- Run complete VDS ETL (list + details)
    PROCEDURE run_vds_etl(
        p_refresh_list   IN BOOLEAN DEFAULT FALSE,  -- Force refresh of VDS list
        p_max_details    IN NUMBER DEFAULT 10,      -- Max detail API calls
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    );
    
    -- Run VDS list ETL only
    PROCEDURE run_vds_list_etl(
        p_force_refresh  IN BOOLEAN DEFAULT FALSE,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    );
    
    -- Run VDS details ETL only
    PROCEDURE run_vds_details_etl(
        p_max_calls      IN NUMBER DEFAULT 10,
        p_test_only      IN BOOLEAN DEFAULT FALSE,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    );
    
    -- Get VDS ETL statistics
    FUNCTION get_vds_etl_stats RETURN VARCHAR2;
    
END pkg_vds_workflow;
/

CREATE OR REPLACE PACKAGE BODY pkg_vds_workflow AS

    -- =========================================================================
    -- Run complete VDS ETL
    -- =========================================================================
    PROCEDURE run_vds_etl(
        p_refresh_list   IN BOOLEAN DEFAULT FALSE,
        p_max_details    IN NUMBER DEFAULT 10,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    ) IS
        v_start_time     TIMESTAMP := SYSTIMESTAMP;
        v_list_status    VARCHAR2(50);
        v_list_msg       VARCHAR2(4000);
        v_detail_status  VARCHAR2(50);
        v_detail_msg     VARCHAR2(4000);
        v_total_time     NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('VDS ETL Process Started');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
        -- Step 1: VDS List
        run_vds_list_etl(
            p_force_refresh => p_refresh_list,
            p_status => v_list_status,
            p_message => v_list_msg
        );
        
        DBMS_OUTPUT.PUT_LINE('VDS List: ' || v_list_status || ' - ' || v_list_msg);
        
        -- Step 2: VDS Details (if list succeeded)
        IF v_list_status IN ('SUCCESS', 'SKIPPED') THEN
            run_vds_details_etl(
                p_max_calls => p_max_details,
                p_test_only => FALSE,
                p_status => v_detail_status,
                p_message => v_detail_msg
            );
            
            DBMS_OUTPUT.PUT_LINE('VDS Details: ' || v_detail_status || ' - ' || v_detail_msg);
        END IF;
        
        v_total_time := ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)) + 
                              EXTRACT(MINUTE FROM (SYSTIMESTAMP - v_start_time)) * 60, 2);
        
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('VDS ETL Complete: ' || v_total_time || ' seconds');
        DBMS_OUTPUT.PUT_LINE(get_vds_etl_stats);
        DBMS_OUTPUT.PUT_LINE('========================================');
        
        p_status := 'SUCCESS';
        p_message := 'VDS ETL completed in ' || v_total_time || 's. ' || get_vds_etl_stats;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'VDS ETL failed: ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
    END run_vds_etl;

    -- =========================================================================
    -- Run VDS list ETL only
    -- =========================================================================
    PROCEDURE run_vds_list_etl(
        p_force_refresh  IN BOOLEAN DEFAULT FALSE,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    ) IS
        v_last_sync      TIMESTAMP;
        v_hours_since    NUMBER;
        v_vds_count      NUMBER;
        v_start_time     TIMESTAMP := SYSTIMESTAMP;
    BEGIN
        -- Check if refresh needed
        SELECT COUNT(*), MAX(last_api_sync)
        INTO v_vds_count, v_last_sync
        FROM VDS_LIST
        WHERE is_valid = 'Y';
        
        IF v_last_sync IS NOT NULL THEN
            v_hours_since := EXTRACT(HOUR FROM (SYSTIMESTAMP - v_last_sync)) + 
                            EXTRACT(DAY FROM (SYSTIMESTAMP - v_last_sync)) * 24;
        ELSE
            v_hours_since := 999;
        END IF;
        
        -- Decide if refresh needed
        IF p_force_refresh OR v_vds_count = 0 OR v_hours_since > 24 THEN
            DBMS_OUTPUT.PUT_LINE('Refreshing VDS list (force=' || 
                CASE WHEN p_force_refresh THEN 'Y' ELSE 'N' END ||
                ', last_sync=' || NVL(TO_CHAR(v_last_sync, 'YYYY-MM-DD HH24:MI'), 'never') || ')');
            
            -- Call API client
            pkg_api_client_vds.fetch_vds_list(
                p_status => p_status,
                p_message => p_message
            );
            
            p_message := p_message || ' (Time: ' || 
                ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)), 2) || 's)';
        ELSE
            p_status := 'SKIPPED';
            p_message := 'VDS list current (' || v_vds_count || ' records, ' || 
                        ROUND(v_hours_since, 1) || ' hours old)';
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'VDS list ETL error: ' || SQLERRM;
    END run_vds_list_etl;

    -- =========================================================================
    -- Run VDS details ETL only
    -- =========================================================================
    PROCEDURE run_vds_details_etl(
        p_max_calls      IN NUMBER DEFAULT 10,
        p_test_only      IN BOOLEAN DEFAULT FALSE,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    ) IS
        v_loading_mode   VARCHAR2(50);
        v_start_time     TIMESTAMP := SYSTIMESTAMP;
    BEGIN
        -- Check loading mode
        SELECT NVL(setting_value, 'OFFICIAL_ONLY')
        INTO v_loading_mode
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'VDS_LOADING_MODE';
        
        IF v_loading_mode != 'OFFICIAL_ONLY' AND NOT p_test_only THEN
            p_status := 'SKIPPED';
            p_message := 'VDS details skipped (mode=' || v_loading_mode || ')';
            RETURN;
        END IF;
        
        IF p_test_only THEN
            -- Test with 2 records only
            DBMS_OUTPUT.PUT_LINE('Running VDS details test (2 records)...');
            pkg_api_client_vds.fetch_test_vds_details(
                p_status => p_status,
                p_message => p_message
            );
        ELSE
            -- Production mode with limits
            DBMS_OUTPUT.PUT_LINE('Fetching VDS details (max ' || p_max_calls || ' calls)...');
            pkg_api_client_vds.fetch_all_official_vds_details(
                p_max_calls => p_max_calls,
                p_status => p_status,
                p_message => p_message
            );
        END IF;
        
        p_message := p_message || ' (Time: ' || 
            ROUND(EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)), 2) || 's)';
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := 'VDS details ETL error: ' || SQLERRM;
    END run_vds_details_etl;

    -- =========================================================================
    -- Get VDS ETL statistics
    -- =========================================================================
    FUNCTION get_vds_etl_stats RETURN VARCHAR2 IS
        v_list_total     NUMBER;
        v_list_official  NUMBER;
        v_details_count  NUMBER;
        v_refs_with_vds  NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_list_total 
        FROM VDS_LIST WHERE is_valid = 'Y';
        
        SELECT COUNT(*) INTO v_list_official
        FROM VDS_LIST WHERE is_valid = 'Y' AND status = 'O';
        
        SELECT COUNT(*) INTO v_details_count
        FROM VDS_DETAILS WHERE is_valid = 'Y';
        
        SELECT COUNT(DISTINCT vds_name) INTO v_refs_with_vds
        FROM VDS_REFERENCES WHERE is_valid = 'Y';
        
        RETURN 'VDS Stats: List=' || v_list_total || 
               ' (Official=' || v_list_official || ')' ||
               ', Details=' || v_details_count ||
               ', Referenced=' || v_refs_with_vds;
               
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'VDS Stats: Error retrieving statistics';
    END get_vds_etl_stats;

END pkg_vds_workflow;
/

-- Grant permissions
GRANT EXECUTE ON pkg_vds_workflow TO TR2000_STAGING;
/