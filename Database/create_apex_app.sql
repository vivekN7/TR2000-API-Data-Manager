-- ===============================================================================
-- Create APEX Application: TR2000 ETL Manager
-- Date: 2025-08-23
-- Purpose: Setup 2-page APEX application for ETL management
-- ===============================================================================

-- Note: This script should be run in APEX SQL Workshop or through APEX Admin interface
-- Some operations require APEX context and cannot be run through SQL*Plus

SET DEFINE OFF

-- ===============================================================================
-- STEP 1: Create Supporting Objects for APEX
-- ===============================================================================

-- Create a sequence for application logs
CREATE SEQUENCE seq_apex_log_id START WITH 1;

-- Create application log table for APEX
CREATE TABLE APEX_ETL_LOG (
    log_id NUMBER DEFAULT seq_apex_log_id.NEXTVAL PRIMARY KEY,
    log_timestamp TIMESTAMP DEFAULT SYSTIMESTAMP,
    log_level VARCHAR2(20),
    log_message VARCHAR2(4000),
    log_user VARCHAR2(100) DEFAULT USER,
    apex_session_id NUMBER
);

-- Create a view for dashboard statistics
CREATE OR REPLACE VIEW v_apex_dashboard_stats AS
SELECT 
    'Total Plants' as metric_name,
    COUNT(*) as metric_value,
    'info' as metric_type
FROM PLANTS
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'Selected Plants',
    COUNT(*),
    'primary'
FROM SELECTION_LOADER
WHERE is_active = 'Y'
UNION ALL
SELECT 
    'Total Issues',
    COUNT(*),
    'warning'
FROM ISSUES
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'ETL Runs Today',
    COUNT(*),
    'success'
FROM ETL_RUN_LOG
WHERE TRUNC(start_time) = TRUNC(SYSDATE);

-- Create a view for recent ETL activity
CREATE OR REPLACE VIEW v_apex_recent_activity AS
SELECT * FROM (
    SELECT 
        run_id,
        run_type,
        endpoint_key,
        plant_id,
        start_time,
        end_time,
        duration_seconds,
        status,
        CASE status
            WHEN 'SUCCESS' THEN 'fa-check-circle u-color-success'
            WHEN 'FAILED' THEN 'fa-times-circle u-color-danger'
            WHEN 'RUNNING' THEN 'fa-spinner fa-spin u-color-warning'
            ELSE 'fa-question-circle'
        END as status_icon,
        records_processed,
        initiated_by
    FROM ETL_RUN_LOG
    ORDER BY start_time DESC
) WHERE ROWNUM <= 10;

-- ===============================================================================
-- STEP 2: APEX Application Export (Declarative)
-- ===============================================================================
-- This section contains the APEX application definition that can be imported
-- through APEX Application Builder

DECLARE
    l_workspace_id NUMBER;
    l_app_id NUMBER := 100; -- Application ID
BEGIN
    -- Note: This is a template. Actual APEX app creation should be done through UI
    -- or using APEX export/import functionality
    
    DBMS_OUTPUT.PUT_LINE('=====================================');
    DBMS_OUTPUT.PUT_LINE('APEX Application Setup Instructions');
    DBMS_OUTPUT.PUT_LINE('=====================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('1. Log into APEX as ADMIN');
    DBMS_OUTPUT.PUT_LINE('2. Create Workspace: TR2000_ETL');
    DBMS_OUTPUT.PUT_LINE('3. Schema: TR2000_STAGING');
    DBMS_OUTPUT.PUT_LINE('4. Create Application: TR2000 ETL Manager');
    DBMS_OUTPUT.PUT_LINE('5. Theme: Universal Theme');
    DBMS_OUTPUT.PUT_LINE('6. Create Pages as defined below');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ===============================================================================
-- STEP 3: Page Definitions (Documentation for Manual Creation)
-- ===============================================================================

-- PAGE 1: Dashboard
-- -----------------
-- Page Name: Dashboard
-- Page Number: 1
-- Page Type: Dashboard
-- 
-- Regions:
-- 1. Statistics Cards (Type: Cards)
--    - Source: v_apex_dashboard_stats
--    - Template: Cards Container
--    
-- 2. Recent Activity (Type: Classic Report)
--    - Source: v_apex_recent_activity
--    - Template: Standard
--
-- 3. Quick Actions (Type: Static Content)
--    - Buttons: 
--      - Refresh Plants (Action: Submit Page)
--      - Run Full ETL (Action: Submit Page)
--      - Go to ETL Operations (Action: Navigate to Page 2)

-- PAGE 2: ETL Operations
-- ----------------------
-- Page Name: ETL Operations
-- Page Number: 2
-- Page Type: Form and Report
--
-- Regions:
-- 1. Plant Selection (Type: Checkbox Group)
--    - Source: SELECT plant_id, short_description FROM PLANTS WHERE is_valid = 'Y' ORDER BY plant_id
--    - Max selections: 10 (validated)
--    - Default: Currently selected plants from SELECTION_LOADER
--
-- 2. Issue Selection (Type: Shuttle)
--    - Source: Dynamic based on selected plants
--    - Cascading from Plant Selection
--
-- 3. Action Buttons (Type: Button Container)
--    - Refresh Plants from API
--    - Save Selection
--    - Run ETL for Selected
--    - Clear Selection
--
-- 4. Execution Log (Type: Interactive Report)
--    - Source: v_apex_etl_history
--    - Features: Search, Filter, Sort, Download

-- ===============================================================================
-- STEP 4: APEX Processes (PL/SQL)
-- ===============================================================================

-- Process: Refresh Plants from API
CREATE OR REPLACE PROCEDURE apex_process_refresh_plants (
    p_session_id IN NUMBER DEFAULT NULL
) AS
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
BEGIN
    -- Log start
    INSERT INTO APEX_ETL_LOG (log_level, log_message, apex_session_id)
    VALUES ('INFO', 'Starting plant refresh from API', p_session_id);
    
    -- Call the refresh procedure
    pkg_api_client.refresh_plants_from_api(v_status, v_message);
    
    -- Log result
    INSERT INTO APEX_ETL_LOG (log_level, log_message, apex_session_id)
    VALUES (
        CASE WHEN v_status = 'SUCCESS' THEN 'INFO' ELSE 'ERROR' END,
        'Plant refresh ' || v_status || ': ' || v_message,
        p_session_id
    );
    
    COMMIT;
    
    IF v_status != 'SUCCESS' THEN
        RAISE_APPLICATION_ERROR(-20001, v_message);
    END IF;
END apex_process_refresh_plants;
/

-- Process: Save Plant Selection
CREATE OR REPLACE PROCEDURE apex_process_save_selection (
    p_plant_list IN VARCHAR2,  -- Colon-delimited list
    p_session_id IN NUMBER DEFAULT NULL
) AS
    v_plant_array APEX_T_VARCHAR2;
    v_count NUMBER := 0;
BEGIN
    -- Parse the colon-delimited list
    v_plant_array := APEX_STRING.SPLIT(p_plant_list, ':');
    
    -- Validate max 10 plants
    IF v_plant_array.COUNT > 10 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Maximum 10 plants can be selected');
    END IF;
    
    -- Clear existing selection
    UPDATE SELECTION_LOADER SET is_active = 'N';
    
    -- Add new selections
    FOR i IN 1..v_plant_array.COUNT LOOP
        -- Check if plant exists, insert or update
        MERGE INTO SELECTION_LOADER sl
        USING (SELECT v_plant_array(i) as plant_id FROM dual) src
        ON (sl.plant_id = src.plant_id AND sl.issue_revision IS NULL)
        WHEN MATCHED THEN
            UPDATE SET is_active = 'Y', selection_date = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (plant_id, is_active, selected_by)
            VALUES (src.plant_id, 'Y', USER);
        
        v_count := v_count + 1;
    END LOOP;
    
    -- Log the action
    INSERT INTO APEX_ETL_LOG (log_level, log_message, apex_session_id)
    VALUES ('INFO', 'Saved selection: ' || v_count || ' plants', p_session_id);
    
    COMMIT;
END apex_process_save_selection;
/

-- Process: Run ETL for Selected Plants
CREATE OR REPLACE PROCEDURE apex_process_run_etl (
    p_session_id IN NUMBER DEFAULT NULL
) AS
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
    v_plant_count NUMBER;
BEGIN
    -- Count selected plants
    SELECT COUNT(*) INTO v_plant_count
    FROM SELECTION_LOADER
    WHERE is_active = 'Y';
    
    IF v_plant_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'No plants selected for ETL');
    END IF;
    
    -- Log start
    INSERT INTO APEX_ETL_LOG (log_level, log_message, apex_session_id)
    VALUES ('INFO', 'Starting ETL for ' || v_plant_count || ' plants', p_session_id);
    
    -- Run the ETL
    pkg_etl_operations.run_full_etl(v_status, v_message);
    
    -- Log result
    INSERT INTO APEX_ETL_LOG (log_level, log_message, apex_session_id)
    VALUES (
        CASE WHEN v_status = 'SUCCESS' THEN 'INFO' ELSE 'ERROR' END,
        'ETL ' || v_status || ': ' || v_message,
        p_session_id
    );
    
    COMMIT;
    
    IF v_status = 'FAILED' THEN
        RAISE_APPLICATION_ERROR(-20002, v_message);
    END IF;
END apex_process_run_etl;
/

-- ===============================================================================
-- STEP 5: APEX Collections for Temporary Storage
-- ===============================================================================

-- Procedure to populate plant selection collection
CREATE OR REPLACE PROCEDURE apex_populate_plant_collection AS
    CURSOR c_plants IS
        SELECT 
            p.plant_id,
            p.short_description,
            p.operator_name,
            CASE WHEN sl.plant_id IS NOT NULL THEN 'Y' ELSE 'N' END as is_selected,
            (SELECT COUNT(*) FROM ISSUES i WHERE i.plant_id = p.plant_id) as issue_count
        FROM PLANTS p
        LEFT JOIN (
            SELECT plant_id FROM SELECTION_LOADER 
            WHERE is_active = 'Y' AND issue_revision IS NULL
        ) sl ON p.plant_id = sl.plant_id
        WHERE p.is_valid = 'Y'
        ORDER BY p.plant_id;
BEGIN
    -- Create/truncate collection
    APEX_COLLECTION.CREATE_OR_TRUNCATE_COLLECTION('PLANT_SELECTION');
    
    -- Populate collection
    FOR rec IN c_plants LOOP
        APEX_COLLECTION.ADD_MEMBER(
            p_collection_name => 'PLANT_SELECTION',
            p_c001 => rec.plant_id,
            p_c002 => rec.short_description,
            p_c003 => rec.operator_name,
            p_c004 => rec.is_selected,
            p_n001 => rec.issue_count
        );
    END LOOP;
END apex_populate_plant_collection;
/

-- ===============================================================================
-- STEP 6: JavaScript for Page Interactions
-- ===============================================================================
-- Add to Page 2 JavaScript section:

/*
// Limit plant selection to 10
function validatePlantSelection() {
    var checkedCount = $('input[name="P2_PLANTS"]:checked').length;
    if (checkedCount > 10) {
        apex.message.showErrors({
            type: "error",
            location: "page",
            message: "Maximum 10 plants can be selected"
        });
        return false;
    }
    return true;
}

// Auto-refresh execution log every 30 seconds
setInterval(function() {
    apex.region("execution_log").refresh();
}, 30000);

// Show spinner during ETL operations
function showETLSpinner() {
    apex.util.showSpinner($('#etl_region'));
}

function hideETLSpinner() {
    $('#etl_region .u-Processing').remove();
}
*/

-- ===============================================================================
-- STEP 7: Sample Data for Testing
-- ===============================================================================

-- Add some test plants if none exist
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM PLANTS;
    
    IF v_count = 0 THEN
        -- Insert test plants
        INSERT INTO PLANTS (plant_id, operator_name, short_description, is_valid)
        VALUES ('TEST1', 'Test Operator', 'Test Plant 1', 'Y');
        
        INSERT INTO PLANTS (plant_id, operator_name, short_description, is_valid)
        VALUES ('TEST2', 'Test Operator', 'Test Plant 2', 'Y');
        
        INSERT INTO PLANTS (plant_id, operator_name, short_description, is_valid)
        VALUES ('TEST3', 'Test Operator', 'Test Plant 3', 'Y');
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Added 3 test plants');
    END IF;
END;
/

-- ===============================================================================
-- Verification
-- ===============================================================================

-- Check all supporting objects are created
SELECT 'Objects Created' as status FROM dual;

SELECT object_name, object_type 
FROM user_objects 
WHERE created > SYSDATE - 1/24
AND object_name LIKE '%APEX%'
ORDER BY object_name;

-- Show next steps
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('APEX Application Setup Complete!');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Next Steps:');
    DBMS_OUTPUT.PUT_LINE('1. Access APEX at: http://localhost:8080/apex');
    DBMS_OUTPUT.PUT_LINE('2. Login as ADMIN');
    DBMS_OUTPUT.PUT_LINE('3. Create Workspace: TR2000_ETL');
    DBMS_OUTPUT.PUT_LINE('4. Create Application using Universal Theme');
    DBMS_OUTPUT.PUT_LINE('5. Add the 2 pages as defined above');
    DBMS_OUTPUT.PUT_LINE('6. Add the processes to handle actions');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('All supporting database objects have been created!');
END;
/