-- ===============================================================================
-- Step 5: Run Remaining ETL (References and Details)
-- Date: 2025-12-30
-- Purpose: Load all references and details for selected issue(s)
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_plant_count NUMBER;
    v_issue_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 5: Running ETL for Selected Issue(s)');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Verify we have selections
    SELECT COUNT(*) INTO v_plant_count FROM SELECTED_PLANTS WHERE is_active = 'Y';
    SELECT COUNT(*) INTO v_issue_count FROM SELECTED_ISSUES WHERE is_active = 'Y';
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Selected plants: ' || v_plant_count);
    DBMS_OUTPUT.PUT_LINE('Selected issues: ' || v_issue_count);
    
    IF v_issue_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ERROR: No issues selected!');
        DBMS_OUTPUT.PUT_LINE('Please run steps 1-4 first');
        RETURN;
    END IF;
    
    -- Set PCS loading mode
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Setting PCS loading mode to OFFICIAL_ONLY...');
    
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
    
    -- Run the ETL for references and details
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Starting ETL process...');
    DBMS_OUTPUT.PUT_LINE('This will load:');
    DBMS_OUTPUT.PUT_LINE('  - All 9 reference types');
    DBMS_OUTPUT.PUT_LINE('  - PCS details (official only)');
    DBMS_OUTPUT.PUT_LINE('  - VDS details');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Call the full ETL (it will skip plants/issues since already loaded)
    pkg_etl_operations.run_full_etl(v_status, v_msg);
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('ETL Result: ' || v_status);
    IF v_msg IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Details: ' || SUBSTR(v_msg, 1, 2000));
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('ETL Process Complete');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

-- Show final statistics
PROMPT
PROMPT Final Data Statistics:
PROMPT ======================

SELECT 'Plants' as entity, COUNT(*) as count FROM PLANTS WHERE is_valid = 'Y'
UNION ALL
SELECT 'Issues (GRANE)', COUNT(*) FROM ISSUES WHERE plant_id = '34' AND is_valid = 'Y'
UNION ALL
SELECT 'PCS References', COUNT(*) FROM PCS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
UNION ALL
SELECT 'VDS References', COUNT(*) FROM VDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
UNION ALL
SELECT 'MDS References', COUNT(*) FROM MDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
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
    (SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y')
FROM DUAL
UNION ALL
SELECT 'PCS List', COUNT(*) FROM PCS_LIST WHERE plant_id = '34'
UNION ALL
SELECT 'VDS List', COUNT(*) FROM VDS_LIST
UNION ALL
SELECT 'VDS Details', COUNT(*) FROM VDS_DETAILS;

EXIT;