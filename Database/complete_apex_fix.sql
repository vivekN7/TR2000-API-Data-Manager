-- Complete fix for APEX application setup
ALTER SESSION SET CURRENT_SCHEMA = TR2000_STAGING;
SET SERVEROUTPUT ON SIZE UNLIMITED

-- Fix issues LOV view with correct column
CREATE OR REPLACE VIEW v_apex_issues_lov AS
SELECT 
    i.issue_revision as return_value,
    i.issue_revision || ' (' || i.status || ')' as display_value,
    i.plant_id as parent_value
FROM ISSUES i
WHERE i.is_valid = 'Y'
ORDER BY i.plant_id, i.issue_revision;

-- Check and display all APEX views
PROMPT
PROMPT APEX Views Status:
SELECT view_name FROM user_views WHERE view_name LIKE 'V_APEX%' ORDER BY 1;

-- Check stored procedures
PROMPT
PROMPT APEX Procedures Status:
SELECT object_name, status 
FROM user_objects 
WHERE object_name LIKE 'APEX_%' 
AND object_type = 'PROCEDURE'
ORDER BY 1;

-- Create APEX application export file
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=====================================================');
    DBMS_OUTPUT.PUT_LINE('APEX APPLICATION READY FOR MANUAL CREATION');
    DBMS_OUTPUT.PUT_LINE('=====================================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Database objects created successfully:');
    DBMS_OUTPUT.PUT_LINE('- APEX_ETL_LOG table');
    DBMS_OUTPUT.PUT_LINE('- v_apex_dashboard_stats view');
    DBMS_OUTPUT.PUT_LINE('- v_apex_recent_activity view');
    DBMS_OUTPUT.PUT_LINE('- v_apex_plant_selection view');
    DBMS_OUTPUT.PUT_LINE('- v_apex_plant_lov view');
    DBMS_OUTPUT.PUT_LINE('- v_apex_issues_lov view');
    DBMS_OUTPUT.PUT_LINE('- v_apex_etl_history view');
    DBMS_OUTPUT.PUT_LINE('- v_apex_etl_status view');
    DBMS_OUTPUT.PUT_LINE('- apex_process_refresh_plants procedure');
    DBMS_OUTPUT.PUT_LINE('- apex_process_save_selection procedure');
    DBMS_OUTPUT.PUT_LINE('- apex_process_run_etl procedure');
    DBMS_OUTPUT.PUT_LINE('- apex_process_clear_selection procedure');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('NEXT STEPS:');
    DBMS_OUTPUT.PUT_LINE('1. Access APEX at http://localhost:8080/apex');
    DBMS_OUTPUT.PUT_LINE('2. Login to APEX Admin');
    DBMS_OUTPUT.PUT_LINE('3. Create Workspace "TR2000_ETL"');
    DBMS_OUTPUT.PUT_LINE('4. Link to schema "TR2000_STAGING"');
    DBMS_OUTPUT.PUT_LINE('5. Create app "TR2000 ETL Manager"');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('PAGE 1 - DASHBOARD:');
    DBMS_OUTPUT.PUT_LINE('- Cards Region: v_apex_dashboard_stats');
    DBMS_OUTPUT.PUT_LINE('- Report Region: v_apex_recent_activity');
    DBMS_OUTPUT.PUT_LINE('- Buttons: Refresh Plants, Go to ETL Operations');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('PAGE 2 - ETL OPERATIONS:');
    DBMS_OUTPUT.PUT_LINE('- Checkbox Group: v_apex_plant_lov');
    DBMS_OUTPUT.PUT_LINE('- Process Buttons: Save, Refresh, Run ETL, Clear');
    DBMS_OUTPUT.PUT_LINE('- Report: v_apex_etl_history');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=====================================================');
END;
/

-- Test data verification
PROMPT
PROMPT Current Data Status:
SELECT 'Plants' as table_name, COUNT(*) as record_count FROM PLANTS WHERE is_valid = 'Y'
UNION ALL
SELECT 'Issues', COUNT(*) FROM ISSUES WHERE is_valid = 'Y'
UNION ALL
SELECT 'Selected Plants', COUNT(*) FROM SELECTION_LOADER WHERE is_active = 'Y'
UNION ALL
SELECT 'RAW_JSON Records', COUNT(*) FROM RAW_JSON
UNION ALL
SELECT 'ETL Runs', COUNT(*) FROM ETL_RUN_LOG;