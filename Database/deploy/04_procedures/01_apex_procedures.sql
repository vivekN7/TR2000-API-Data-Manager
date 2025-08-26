-- ===============================================================================
-- APEX Procedures - Support APEX Application
-- ===============================================================================
-- These procedures are called from APEX buttons and processes
-- UI_ prefix is kept for procedures to distinguish from core ETL operations
-- ===============================================================================

-- Main APEX ETL Control Action procedure
-- Called from APEX buttons to execute ETL operations
CREATE OR REPLACE PROCEDURE UI_APEX_ETL_CONTROL_ACTION (
    p_action    IN VARCHAR2,
    p_plant_id  IN VARCHAR2 DEFAULT NULL,
    p_user      IN VARCHAR2 DEFAULT USER
) AS
    v_status    VARCHAR2(50);
    v_message   VARCHAR2(4000);
    v_plant_ids VARCHAR2(4000);
BEGIN
    -- Log the action
    DBMS_OUTPUT.PUT_LINE('Action: ' || p_action || ' by ' || p_user);
    
    CASE p_action
        -- Plant selection actions
        WHEN 'SELECT_PLANT' THEN
            pkg_selection_mgmt.save_plant_selection(
                p_plant_ids => p_plant_id,
                p_user => p_user,
                p_status => v_status,
                p_message => v_message
            );
            
        WHEN 'REMOVE_PLANT' THEN
            pkg_selection_mgmt.remove_plant_selection(
                p_plant_id => p_plant_id,
                p_status => v_status,
                p_message => v_message
            );
            
        WHEN 'CLEAR_ALL_SELECTIONS' THEN
            pkg_selection_mgmt.clear_all_selections(
                p_status => v_status,
                p_message => v_message
            );
            
        -- ETL execution actions
        WHEN 'RUN_PLANTS_ETL' THEN
            pkg_etl_operations.run_plants_etl(
                p_status => v_status,
                p_message => v_message
            );
            
        WHEN 'RUN_ISSUES_ETL' THEN
            pkg_etl_operations.run_issues_etl_for_plant(
                p_plant_id => p_plant_id,
                p_status => v_status,
                p_message => v_message
            );
            
        WHEN 'RUN_FULL_ETL' THEN
            pkg_etl_operations.run_full_etl(
                p_status => v_status,
                p_message => v_message
            );
            
        -- API refresh actions
        WHEN 'REFRESH_PLANTS' THEN
            pkg_api_client.refresh_plants_from_api(
                p_status => v_status,
                p_message => v_message
            );
            
        WHEN 'REFRESH_ISSUES' THEN
            IF p_plant_id IS NOT NULL THEN
                pkg_api_client.refresh_issues_from_api(
                    p_plant_id => p_plant_id,
                    p_status => v_status,
                    p_message => v_message
                );
            ELSE
                v_status := 'ERROR';
                v_message := 'Plant ID required for issues refresh';
            END IF;
            
        -- Get active selections
        WHEN 'GET_ACTIVE_PLANTS' THEN
            v_plant_ids := pkg_selection_mgmt.get_active_plants();
            v_status := 'SUCCESS';
            v_message := 'Active plants: ' || NVL(v_plant_ids, 'None');
            
        ELSE
            v_status := 'ERROR';
            v_message := 'Unknown action: ' || p_action;
    END CASE;
    
    -- Log result
    IF v_status = 'SUCCESS' THEN
        DBMS_OUTPUT.PUT_LINE('Success: ' || v_message);
        -- Could also use APEX_APPLICATION.G_PRINT_SUCCESS_MESSAGE
    ELSE
        DBMS_OUTPUT.PUT_LINE('Error: ' || v_message);
        -- Could also use APEX_ERROR.ADD_ERROR
        RAISE_APPLICATION_ERROR(-20001, v_message);
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in UI_APEX_ETL_CONTROL_ACTION: ' || SQLERRM);
        RAISE;
END UI_APEX_ETL_CONTROL_ACTION;
/

PROMPT APEX procedures created successfully