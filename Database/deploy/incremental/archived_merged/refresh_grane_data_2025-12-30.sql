-- ===============================================================================
-- Refresh Data for GRANE/4.2 Only
-- Date: 2025-12-30
-- Purpose: Clean all data and reload only GRANE plant with issue 4.2
--          Load only official revisions for PCS/VDS
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Starting data refresh for GRANE/4.2');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Step 1: Clean all data (preserve structure and settings)
    DBMS_OUTPUT.PUT_LINE('Step 1: Cleaning all data tables...');
    
    -- Disable FK constraints temporarily
    FOR c IN (SELECT constraint_name, table_name 
              FROM user_constraints 
              WHERE constraint_type = 'R' AND status = 'ENABLED') LOOP
        EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || 
                          ' DISABLE CONSTRAINT ' || c.constraint_name;
    END LOOP;
    
    -- Clean data tables (keep control tables)
    DELETE FROM VDS_DETAILS;
    DELETE FROM VDS_LIST;
    DELETE FROM PCS_LIST;
    DELETE FROM PCS_HEADER_PROPERTIES;
    DELETE FROM PCS_TEMP_PRESSURES;
    DELETE FROM PCS_PIPE_SIZES;
    DELETE FROM PCS_PIPE_ELEMENTS;
    DELETE FROM PCS_VALVE_ELEMENTS;
    DELETE FROM PCS_EMBEDDED_NOTES;
    DELETE FROM VDS_REFERENCES;
    DELETE FROM PCS_REFERENCES;
    DELETE FROM SC_REFERENCES;
    DELETE FROM VSM_REFERENCES;
    DELETE FROM MDS_REFERENCES;
    DELETE FROM EDS_REFERENCES;
    DELETE FROM ESK_REFERENCES;
    DELETE FROM VSK_REFERENCES;
    DELETE FROM PIPE_ELEMENT_REFERENCES;
    DELETE FROM ISSUES;
    DELETE FROM SELECTED_ISSUES;
    DELETE FROM SELECTED_PLANTS;
    DELETE FROM PLANTS;
    DELETE FROM RAW_JSON;
    DELETE FROM CASCADE_LOG;
    DELETE FROM ETL_RUN_LOG;
    DELETE FROM ETL_LOG;
    DELETE FROM TEST_RESULTS;
    DELETE FROM ETL_ERROR_LOG;
    
    -- Clean staging tables too
    DELETE FROM STG_PLANTS;
    DELETE FROM STG_ISSUES;
    DELETE FROM STG_PCS_REFERENCES;
    DELETE FROM STG_VDS_REFERENCES;
    DELETE FROM STG_SC_REFERENCES;
    DELETE FROM STG_VSM_REFERENCES;
    DELETE FROM STG_MDS_REFERENCES;
    DELETE FROM STG_EDS_REFERENCES;
    DELETE FROM STG_ESK_REFERENCES;
    DELETE FROM STG_VSK_REFERENCES;
    DELETE FROM STG_PIPE_ELEMENT_REFERENCES;
    DELETE FROM STG_PCS_LIST;
    DELETE FROM STG_VDS_LIST;
    DELETE FROM STG_PCS_HEADER_PROPERTIES;
    DELETE FROM STG_PCS_TEMP_PRESSURES;
    DELETE FROM STG_PCS_PIPE_SIZES;
    DELETE FROM STG_PCS_PIPE_ELEMENTS;
    DELETE FROM STG_PCS_VALVE_ELEMENTS;
    DELETE FROM STG_PCS_EMBEDDED_NOTES;
    DELETE FROM STG_VDS_DETAILS;
    
    -- Re-enable constraints
    FOR c IN (SELECT constraint_name, table_name 
              FROM user_constraints 
              WHERE constraint_type = 'R' AND status = 'DISABLED') LOOP
        EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || 
                          ' ENABLE CONSTRAINT ' || c.constraint_name;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Data cleaned successfully');
    
    -- Step 2: Load all plants
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 2: Loading all plants from API...');
    pkg_api_client.refresh_plants_from_api(v_status, v_msg);
    DBMS_OUTPUT.PUT_LINE('Plants loaded: ' || v_status || ' - ' || v_msg);
    
    -- Step 3: Select only GRANE
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 3: Selecting GRANE plant...');
    INSERT INTO SELECTED_PLANTS (plant_id, is_active, selected_by, selection_date)
    SELECT plant_id, 'Y', USER, SYSDATE
    FROM PLANTS
    WHERE SHORT_DESCRIPTION = 'GRANE'
    AND is_valid = 'Y';
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('GRANE selected: ' || SQL%ROWCOUNT || ' plant(s)');
    
    -- Step 4: Load issues for GRANE
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 4: Loading issues for GRANE...');
    pkg_api_client.refresh_issues_from_api('34', v_status, v_msg);
    DBMS_OUTPUT.PUT_LINE('Issues loaded: ' || v_status || ' - ' || v_msg);
    
    -- Step 5: Select only issue 4.2
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 5: Selecting issue 4.2...');
    INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active, selected_by, selection_date)
    SELECT plant_id, issue_revision, 'Y', USER, SYSDATE
    FROM ISSUES
    WHERE plant_id = '34'
    AND issue_revision = '4.2'
    AND is_valid = 'Y';
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Issue 4.2 selected: ' || SQL%ROWCOUNT || ' issue(s)');
    
    -- Step 6: Set PCS loading mode to OFFICIAL_ONLY
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 6: Setting PCS loading mode to OFFICIAL_ONLY...');
    UPDATE CONTROL_SETTINGS 
    SET setting_value = 'OFFICIAL_ONLY'
    WHERE setting_key = 'PCS_LOADING_MODE';
    COMMIT;
    
    -- Step 7: Run full ETL (will load references and details)
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 7: Running full ETL for selected items...');
    DBMS_OUTPUT.PUT_LINE('This will load:');
    DBMS_OUTPUT.PUT_LINE('  - All 9 reference types for issue 4.2');
    DBMS_OUTPUT.PUT_LINE('  - PCS details (official revisions only)');
    DBMS_OUTPUT.PUT_LINE('  - VDS details (official records only)');
    
    pkg_etl_operations.run_full_etl(v_status, v_msg);
    DBMS_OUTPUT.PUT_LINE('ETL completed: ' || v_status);
    
    -- Step 8: Show final statistics
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Data Refresh Complete - Final Statistics:');
    DBMS_OUTPUT.PUT_LINE('===============================================');
END;
/

-- Display statistics
SELECT 'Plants' as entity, COUNT(*) as total_count, 
       SUM(CASE WHEN SHORT_DESCRIPTION = 'GRANE' THEN 1 ELSE 0 END) as grane_count 
FROM PLANTS WHERE is_valid = 'Y'
UNION ALL
SELECT 'Issues', COUNT(*), COUNT(*) 
FROM ISSUES WHERE plant_id = '34' AND is_valid = 'Y'
UNION ALL
SELECT 'Selected Items', COUNT(*), COUNT(*) 
FROM SELECTED_ISSUES WHERE plant_id = '34' AND issue_revision = '4.2'
UNION ALL
SELECT 'PCS References', COUNT(*), COUNT(*) 
FROM PCS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y'
UNION ALL
SELECT 'VDS References', COUNT(*), COUNT(*) 
FROM VDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y'
UNION ALL
SELECT 'Total References', 
    (SELECT COUNT(*) FROM PCS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM SC_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM VSM_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM EDS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM ESK_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM VSK_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'),
    (SELECT COUNT(*) FROM PCS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM VDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM MDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM SC_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM VSM_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM EDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM ESK_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM VSK_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y')
FROM DUAL
UNION ALL
SELECT 'PCS List (Official)', COUNT(*), 
       SUM(CASE WHEN plant_id = '34' AND is_official = 'Y' THEN 1 ELSE 0 END)
FROM PCS_LIST WHERE is_valid = 'Y'
UNION ALL
SELECT 'VDS List', COUNT(*), COUNT(*)
FROM VDS_LIST WHERE is_valid = 'Y'
UNION ALL
SELECT 'VDS Details', COUNT(*), COUNT(*)
FROM VDS_DETAILS WHERE is_valid = 'Y';

EXIT;