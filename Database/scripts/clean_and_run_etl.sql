-- ===============================================================================
-- Clean Data and Run ETL with GRANE/4.2 Selection
-- Date: 2025-12-30
-- Purpose: Clean all data, simulate user selection of GRANE/4.2, then run ETL
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Clean and Run ETL for GRANE/4.2');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Step 1: Clean all data
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 1: Cleaning all data...');
    
    -- Disable FK constraints
    FOR c IN (SELECT constraint_name, table_name 
              FROM user_constraints 
              WHERE constraint_type = 'R' 
              AND status = 'ENABLED'
              AND table_name NOT LIKE 'BIN%') LOOP
        EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || 
                          ' DISABLE CONSTRAINT ' || c.constraint_name;
    END LOOP;
    
    -- Clean all data tables
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
    DELETE FROM API_TRANSACTIONS;
    
    -- Clean staging tables
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
              WHERE constraint_type = 'R' 
              AND status = 'DISABLED'
              AND table_name NOT LIKE 'BIN%') LOOP
        EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || 
                          ' ENABLE CONSTRAINT ' || c.constraint_name;
    END LOOP;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Data cleaned successfully');
    
    -- Step 2: Simulate user selection - Add GRANE/4.2 to selection tables
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 2: Simulating user selection of GRANE/4.2...');
    
    -- Insert GRANE plant selection (plant_id = 34)
    INSERT INTO SELECTED_PLANTS (plant_id, is_active, selected_by, selection_date)
    VALUES ('34', 'Y', USER, SYSDATE);
    
    -- Insert issue 4.2 selection
    INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active, selected_by, selection_date)
    VALUES ('34', '4.2', 'Y', USER, SYSDATE);
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('User selections added: GRANE (34) / Issue 4.2');
    
    -- Step 3: Set PCS loading mode to OFFICIAL_ONLY
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 3: Setting PCS loading mode to OFFICIAL_ONLY...');
    
    MERGE INTO CONTROL_SETTINGS cs
    USING (SELECT 'PCS_LOADING_MODE' as setting_key FROM DUAL) src
    ON (cs.setting_key = src.setting_key)
    WHEN MATCHED THEN
        UPDATE SET setting_value = 'OFFICIAL_ONLY', modified_date = SYSDATE
    WHEN NOT MATCHED THEN
        INSERT (setting_key, setting_value, setting_type, description, created_date, modified_date)
        VALUES ('PCS_LOADING_MODE', 'OFFICIAL_ONLY', 'STRING', 
                'PCS Loading Mode: ALL or OFFICIAL_ONLY', SYSDATE, SYSDATE);
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('PCS loading mode set to OFFICIAL_ONLY');
    
    -- Step 4: Run the full ETL - let it handle everything else
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 4: Running full ETL...');
    DBMS_OUTPUT.PUT_LINE('The ETL will:');
    DBMS_OUTPUT.PUT_LINE('  - Load plants from API');
    DBMS_OUTPUT.PUT_LINE('  - Load issues for selected plant (GRANE)');
    DBMS_OUTPUT.PUT_LINE('  - Load references for selected issue (4.2)');
    DBMS_OUTPUT.PUT_LINE('  - Load PCS details (official only)');
    DBMS_OUTPUT.PUT_LINE('  - Load VDS details');
    DBMS_OUTPUT.PUT_LINE('');
    
    pkg_etl_operations.run_full_etl(v_status, v_msg);
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('ETL Result: ' || v_status);
    IF v_msg IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Message: ' || v_msg);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('ETL Process Complete');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Stack: ' || DBMS_UTILITY.FORMAT_ERROR_STACK());
        RAISE;
END;
/

-- Display final statistics
PROMPT
PROMPT Final Data Statistics:
PROMPT ======================

SELECT 'Plants Total' as metric, COUNT(*) as count 
FROM PLANTS WHERE is_valid = 'Y'
UNION ALL
SELECT 'Issues Total', COUNT(*) 
FROM ISSUES WHERE is_valid = 'Y'
UNION ALL
SELECT 'GRANE Issues', COUNT(*) 
FROM ISSUES WHERE plant_id = '34' AND is_valid = 'Y'
UNION ALL
SELECT 'PCS References', COUNT(*) 
FROM PCS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y'
UNION ALL
SELECT 'VDS References', COUNT(*) 
FROM VDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y'
UNION ALL
SELECT 'MDS References', COUNT(*) 
FROM MDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y'
UNION ALL
SELECT 'Total All References', 
    (SELECT COUNT(*) FROM PCS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM SC_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM VSM_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM EDS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM ESK_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM VSK_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y')
FROM DUAL
UNION ALL
SELECT 'PCS List', COUNT(*) 
FROM PCS_LIST WHERE plant_id = '34' AND is_valid = 'Y'
UNION ALL
SELECT 'VDS List', COUNT(*) 
FROM VDS_LIST WHERE is_valid = 'Y'
UNION ALL
SELECT 'VDS Details', COUNT(*) 
FROM VDS_DETAILS WHERE is_valid = 'Y';

EXIT;