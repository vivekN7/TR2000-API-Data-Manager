-- ===============================================================================
-- Clean All Data Tables
-- Date: 2025-12-30
-- Purpose: Delete all data from tables while preserving structure and settings
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Starting data cleanup...');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Step 1: Disable FK constraints temporarily
    DBMS_OUTPUT.PUT_LINE('Disabling foreign key constraints...');
    FOR c IN (SELECT constraint_name, table_name 
              FROM user_constraints 
              WHERE constraint_type = 'R' 
              AND status = 'ENABLED'
              AND table_name NOT LIKE 'BIN%') LOOP
        EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || 
                          ' DISABLE CONSTRAINT ' || c.constraint_name;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Constraints disabled');
    
    -- Step 2: Clean detail tables first
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Cleaning detail tables...');
    
    DELETE FROM VDS_DETAILS;
    DBMS_OUTPUT.PUT_LINE('  VDS_DETAILS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM VDS_LIST;
    DBMS_OUTPUT.PUT_LINE('  VDS_LIST: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM PCS_LIST;
    DBMS_OUTPUT.PUT_LINE('  PCS_LIST: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM PCS_HEADER_PROPERTIES;
    DBMS_OUTPUT.PUT_LINE('  PCS_HEADER_PROPERTIES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM PCS_TEMP_PRESSURES;
    DBMS_OUTPUT.PUT_LINE('  PCS_TEMP_PRESSURES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM PCS_PIPE_SIZES;
    DBMS_OUTPUT.PUT_LINE('  PCS_PIPE_SIZES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM PCS_PIPE_ELEMENTS;
    DBMS_OUTPUT.PUT_LINE('  PCS_PIPE_ELEMENTS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM PCS_VALVE_ELEMENTS;
    DBMS_OUTPUT.PUT_LINE('  PCS_VALVE_ELEMENTS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM PCS_EMBEDDED_NOTES;
    DBMS_OUTPUT.PUT_LINE('  PCS_EMBEDDED_NOTES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    -- Step 3: Clean reference tables
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Cleaning reference tables...');
    
    DELETE FROM VDS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  VDS_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM PCS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  PCS_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM SC_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  SC_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM VSM_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  VSM_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM MDS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  MDS_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM EDS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  EDS_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM ESK_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  ESK_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM VSK_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  VSK_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM PIPE_ELEMENT_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  PIPE_ELEMENT_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    -- Step 4: Clean core tables
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Cleaning core tables...');
    
    DELETE FROM SELECTED_ISSUES;
    DBMS_OUTPUT.PUT_LINE('  SELECTED_ISSUES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM SELECTED_PLANTS;
    DBMS_OUTPUT.PUT_LINE('  SELECTED_PLANTS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM ISSUES;
    DBMS_OUTPUT.PUT_LINE('  ISSUES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM PLANTS;
    DBMS_OUTPUT.PUT_LINE('  PLANTS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM RAW_JSON;
    DBMS_OUTPUT.PUT_LINE('  RAW_JSON: ' || SQL%ROWCOUNT || ' rows deleted');
    
    -- Step 5: Clean log tables
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Cleaning log tables...');
    
    DELETE FROM CASCADE_LOG;
    DBMS_OUTPUT.PUT_LINE('  CASCADE_LOG: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM ETL_RUN_LOG;
    DBMS_OUTPUT.PUT_LINE('  ETL_RUN_LOG: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM ETL_LOG;
    DBMS_OUTPUT.PUT_LINE('  ETL_LOG: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM TEST_RESULTS;
    DBMS_OUTPUT.PUT_LINE('  TEST_RESULTS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM ETL_ERROR_LOG;
    DBMS_OUTPUT.PUT_LINE('  ETL_ERROR_LOG: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM API_TRANSACTIONS;
    DBMS_OUTPUT.PUT_LINE('  API_TRANSACTIONS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    -- Step 6: Clean staging tables
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Cleaning staging tables...');
    
    DELETE FROM STG_PLANTS;
    DBMS_OUTPUT.PUT_LINE('  STG_PLANTS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_ISSUES;
    DBMS_OUTPUT.PUT_LINE('  STG_ISSUES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_PCS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  STG_PCS_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_VDS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  STG_VDS_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_SC_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  STG_SC_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_VSM_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  STG_VSM_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_MDS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  STG_MDS_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_EDS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  STG_EDS_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_ESK_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  STG_ESK_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_VSK_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  STG_VSK_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_PIPE_ELEMENT_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('  STG_PIPE_ELEMENT_REFERENCES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_PCS_LIST;
    DBMS_OUTPUT.PUT_LINE('  STG_PCS_LIST: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_VDS_LIST;
    DBMS_OUTPUT.PUT_LINE('  STG_VDS_LIST: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_PCS_HEADER_PROPERTIES;
    DBMS_OUTPUT.PUT_LINE('  STG_PCS_HEADER_PROPERTIES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_PCS_TEMP_PRESSURES;
    DBMS_OUTPUT.PUT_LINE('  STG_PCS_TEMP_PRESSURES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_PCS_PIPE_SIZES;
    DBMS_OUTPUT.PUT_LINE('  STG_PCS_PIPE_SIZES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_PCS_PIPE_ELEMENTS;
    DBMS_OUTPUT.PUT_LINE('  STG_PCS_PIPE_ELEMENTS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_PCS_VALVE_ELEMENTS;
    DBMS_OUTPUT.PUT_LINE('  STG_PCS_VALVE_ELEMENTS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_PCS_EMBEDDED_NOTES;
    DBMS_OUTPUT.PUT_LINE('  STG_PCS_EMBEDDED_NOTES: ' || SQL%ROWCOUNT || ' rows deleted');
    
    DELETE FROM STG_VDS_DETAILS;
    DBMS_OUTPUT.PUT_LINE('  STG_VDS_DETAILS: ' || SQL%ROWCOUNT || ' rows deleted');
    
    -- Step 7: Re-enable constraints
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Re-enabling foreign key constraints...');
    FOR c IN (SELECT constraint_name, table_name 
              FROM user_constraints 
              WHERE constraint_type = 'R' 
              AND status = 'DISABLED'
              AND table_name NOT LIKE 'BIN%') LOOP
        EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || 
                          ' ENABLE CONSTRAINT ' || c.constraint_name;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Constraints re-enabled');
    
    -- Step 8: Commit changes
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Data cleanup complete!');
    DBMS_OUTPUT.PUT_LINE('===============================================');
END;
/

-- Verify all tables are empty
PROMPT
PROMPT Verifying tables are empty:
PROMPT ===========================

SELECT 'Core Tables' as category, COUNT(*) as total_rows FROM (
    SELECT 1 FROM PLANTS UNION ALL
    SELECT 1 FROM ISSUES UNION ALL
    SELECT 1 FROM SELECTED_PLANTS UNION ALL
    SELECT 1 FROM SELECTED_ISSUES
)
UNION ALL
SELECT 'Reference Tables', COUNT(*) FROM (
    SELECT 1 FROM PCS_REFERENCES UNION ALL
    SELECT 1 FROM VDS_REFERENCES UNION ALL
    SELECT 1 FROM MDS_REFERENCES UNION ALL
    SELECT 1 FROM SC_REFERENCES UNION ALL
    SELECT 1 FROM VSM_REFERENCES UNION ALL
    SELECT 1 FROM EDS_REFERENCES UNION ALL
    SELECT 1 FROM ESK_REFERENCES UNION ALL
    SELECT 1 FROM VSK_REFERENCES UNION ALL
    SELECT 1 FROM PIPE_ELEMENT_REFERENCES
)
UNION ALL
SELECT 'Detail Tables', COUNT(*) FROM (
    SELECT 1 FROM PCS_LIST UNION ALL
    SELECT 1 FROM VDS_LIST UNION ALL
    SELECT 1 FROM VDS_DETAILS UNION ALL
    SELECT 1 FROM PCS_HEADER_PROPERTIES UNION ALL
    SELECT 1 FROM PCS_TEMP_PRESSURES UNION ALL
    SELECT 1 FROM PCS_PIPE_SIZES UNION ALL
    SELECT 1 FROM PCS_PIPE_ELEMENTS UNION ALL
    SELECT 1 FROM PCS_VALVE_ELEMENTS UNION ALL
    SELECT 1 FROM PCS_EMBEDDED_NOTES
)
UNION ALL
SELECT 'Log Tables', COUNT(*) FROM (
    SELECT 1 FROM ETL_LOG UNION ALL
    SELECT 1 FROM ETL_RUN_LOG UNION ALL
    SELECT 1 FROM ETL_ERROR_LOG UNION ALL
    SELECT 1 FROM CASCADE_LOG UNION ALL
    SELECT 1 FROM TEST_RESULTS
);

EXIT;