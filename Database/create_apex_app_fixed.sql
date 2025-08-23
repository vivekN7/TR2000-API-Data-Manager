-- ===============================================================================
-- Create APEX Application: TR2000 ETL Manager
-- Date: 2025-08-23
-- Purpose: Setup 2-page APEX application for ETL management
-- ===============================================================================

-- Switch to TR2000_STAGING schema
ALTER SESSION SET CURRENT_SCHEMA = TR2000_STAGING;

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

-- ===============================================================================
-- STEP 1: Create Supporting Objects for APEX
-- ===============================================================================

-- Create a sequence for application logs
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_apex_log_id';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE SEQUENCE seq_apex_log_id START WITH 1;

-- Create application log table for APEX
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE APEX_ETL_LOG CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

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
-- STEP 2: Create APEX-specific procedures
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

-- Process: Save Plant Selection (simplified without APEX_STRING)
CREATE OR REPLACE PROCEDURE apex_process_save_selection (
    p_plant_list IN VARCHAR2,  -- Colon-delimited list
    p_session_id IN NUMBER DEFAULT NULL
) AS
    v_plant VARCHAR2(50);
    v_start_pos NUMBER := 1;
    v_colon_pos NUMBER;
    v_count NUMBER := 0;
BEGIN
    -- Clear existing selection
    UPDATE SELECTION_LOADER SET is_active = 'N';
    
    -- Parse the colon-delimited list manually
    LOOP
        v_colon_pos := INSTR(p_plant_list, ':', v_start_pos);
        
        IF v_colon_pos = 0 THEN
            -- Last item
            v_plant := SUBSTR(p_plant_list, v_start_pos);
        ELSE
            v_plant := SUBSTR(p_plant_list, v_start_pos, v_colon_pos - v_start_pos);
        END IF;
        
        EXIT WHEN v_plant IS NULL OR LENGTH(TRIM(v_plant)) = 0;
        
        -- Validate max 10 plants
        v_count := v_count + 1;
        IF v_count > 10 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Maximum 10 plants can be selected');
        END IF;
        
        -- Check if plant exists, insert or update
        MERGE INTO SELECTION_LOADER sl
        USING (SELECT TRIM(v_plant) as plant_id FROM dual) src
        ON (sl.plant_id = src.plant_id AND sl.issue_revision IS NULL)
        WHEN MATCHED THEN
            UPDATE SET is_active = 'Y', selection_date = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (plant_id, is_active, selected_by)
            VALUES (src.plant_id, 'Y', USER);
        
        EXIT WHEN v_colon_pos = 0;
        v_start_pos := v_colon_pos + 1;
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

-- Process to clear all selections
CREATE OR REPLACE PROCEDURE apex_process_clear_selection (
    p_session_id IN NUMBER DEFAULT NULL
) AS
BEGIN
    UPDATE SELECTION_LOADER SET is_active = 'N';
    
    INSERT INTO APEX_ETL_LOG (log_level, log_message, apex_session_id)
    VALUES ('INFO', 'Cleared all plant selections', p_session_id);
    
    COMMIT;
END apex_process_clear_selection;
/

-- ===============================================================================
-- STEP 3: Create LOVs (List of Values) for APEX
-- ===============================================================================

-- Create table for plant LOV
CREATE OR REPLACE VIEW v_apex_plant_lov AS
SELECT 
    plant_id as return_value,
    plant_id || ' - ' || short_description as display_value,
    CASE WHEN sl.plant_id IS NOT NULL THEN 'Y' ELSE 'N' END as is_selected
FROM PLANTS p
LEFT JOIN (
    SELECT DISTINCT plant_id 
    FROM SELECTION_LOADER 
    WHERE is_active = 'Y'
) sl ON p.plant_id = sl.plant_id
WHERE p.is_valid = 'Y'
ORDER BY plant_id;

-- Create view for issues LOV (cascading)
CREATE OR REPLACE VIEW v_apex_issues_lov AS
SELECT 
    i.issue_revision as return_value,
    i.issue_revision || ' - ' || i.issue_description as display_value,
    i.plant_id as parent_value
FROM ISSUES i
WHERE i.is_valid = 'Y'
ORDER BY i.plant_id, i.issue_revision;

-- ===============================================================================
-- STEP 4: Sample Test Data
-- ===============================================================================

-- Check if we have data, if not add from API
DECLARE
    v_plant_count NUMBER;
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
BEGIN
    SELECT COUNT(*) INTO v_plant_count FROM PLANTS;
    
    IF v_plant_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No plants found. Fetching from API...');
        
        -- Try to fetch from API
        BEGIN
            pkg_api_client.refresh_plants_from_api(v_status, v_message);
            DBMS_OUTPUT.PUT_LINE('API Fetch Status: ' || v_status);
            DBMS_OUTPUT.PUT_LINE('Message: ' || v_message);
            
            -- Now run the ETL to process the data
            pkg_etl_operations.run_plants_etl(v_status, v_message);
            DBMS_OUTPUT.PUT_LINE('ETL Status: ' || v_status);
            DBMS_OUTPUT.PUT_LINE('Message: ' || v_message);
            
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error fetching from API: ' || SQLERRM);
                
                -- Insert dummy data for testing
                INSERT INTO PLANTS (plant_id, operator_name, short_description, is_valid, created_date)
                VALUES ('TEST1', 'Test Operator', 'Test Plant 1', 'Y', SYSDATE);
                
                INSERT INTO PLANTS (plant_id, operator_name, short_description, is_valid, created_date)
                VALUES ('TEST2', 'Test Operator', 'Test Plant 2', 'Y', SYSDATE);
                
                INSERT INTO PLANTS (plant_id, operator_name, short_description, is_valid, created_date)
                VALUES ('TEST3', 'Test Operator', 'Test Plant 3', 'Y', SYSDATE);
                
                COMMIT;
                DBMS_OUTPUT.PUT_LINE('Added 3 test plants');
        END;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Found ' || v_plant_count || ' plants in database');
    END IF;
END;
/

-- ===============================================================================
-- STEP 5: Create APEX Application Export Script
-- ===============================================================================

-- This creates a basic APEX application export that can be imported
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('APEX Application Manual Setup Steps');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('1. Access APEX Admin:');
    DBMS_OUTPUT.PUT_LINE('   URL: http://host.docker.internal:8080/apex');
    DBMS_OUTPUT.PUT_LINE('   or:  http://localhost:8080/apex');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('2. Create Workspace:');
    DBMS_OUTPUT.PUT_LINE('   - Workspace Name: TR2000_ETL');
    DBMS_OUTPUT.PUT_LINE('   - Database User: TR2000_STAGING');
    DBMS_OUTPUT.PUT_LINE('   - Password: [set a password]');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('3. Create Application:');
    DBMS_OUTPUT.PUT_LINE('   - Name: TR2000 ETL Manager');
    DBMS_OUTPUT.PUT_LINE('   - Theme: Universal Theme');
    DBMS_OUTPUT.PUT_LINE('   - Pages: Start with blank application');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('4. Create Page 1 - Dashboard:');
    DBMS_OUTPUT.PUT_LINE('   - Type: Dashboard');
    DBMS_OUTPUT.PUT_LINE('   - Add Cards Region:');
    DBMS_OUTPUT.PUT_LINE('     Source: SELECT * FROM v_apex_dashboard_stats');
    DBMS_OUTPUT.PUT_LINE('   - Add Report Region:');
    DBMS_OUTPUT.PUT_LINE('     Source: SELECT * FROM v_apex_recent_activity');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('5. Create Page 2 - ETL Operations:');
    DBMS_OUTPUT.PUT_LINE('   - Type: Blank Page');
    DBMS_OUTPUT.PUT_LINE('   - Add Checkbox Group:');
    DBMS_OUTPUT.PUT_LINE('     Name: P2_PLANTS');
    DBMS_OUTPUT.PUT_LINE('     LOV: SELECT * FROM v_apex_plant_lov');
    DBMS_OUTPUT.PUT_LINE('   - Add Buttons:');
    DBMS_OUTPUT.PUT_LINE('     - Refresh Plants (Process: apex_process_refresh_plants)');
    DBMS_OUTPUT.PUT_LINE('     - Save Selection (Process: apex_process_save_selection)');
    DBMS_OUTPUT.PUT_LINE('     - Run ETL (Process: apex_process_run_etl)');
    DBMS_OUTPUT.PUT_LINE('   - Add Report Region:');
    DBMS_OUTPUT.PUT_LINE('     Source: SELECT * FROM v_apex_etl_history');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('All database objects have been created successfully!');
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

-- ===============================================================================
-- Verification
-- ===============================================================================

-- Check all objects are created
PROMPT
PROMPT Checking created objects...

SELECT 'Views' as object_type, COUNT(*) as count
FROM user_views
WHERE view_name LIKE 'V_APEX%'
UNION ALL
SELECT 'Procedures', COUNT(*)
FROM user_procedures
WHERE object_name LIKE 'APEX_%'
UNION ALL
SELECT 'Tables', COUNT(*)
FROM user_tables
WHERE table_name = 'APEX_ETL_LOG';

-- Check current plant count
SELECT 'Plants in database' as metric, COUNT(*) as value
FROM PLANTS
WHERE is_valid = 'Y';

-- Check if we have any ETL runs
SELECT 'ETL runs logged' as metric, COUNT(*) as value
FROM ETL_RUN_LOG;

PROMPT
PROMPT Setup complete! Follow the manual steps above to create the APEX application.