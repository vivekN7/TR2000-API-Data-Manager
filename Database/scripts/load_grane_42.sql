-- ===============================================================================
-- Load GRANE/4.2 Data
-- Date: 2025-12-30
-- Purpose: Load all plants, select GRANE, load issues, select 4.2, run ETL
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
    DBMS_OUTPUT.PUT_LINE('Starting GRANE/4.2 Data Load');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Step 1: Load all plants from API
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 1: Loading all plants from API...');
    pkg_api_client.refresh_plants_from_api(v_status, v_msg);
    
    SELECT COUNT(*) INTO v_plant_count FROM PLANTS WHERE is_valid = 'Y';
    DBMS_OUTPUT.PUT_LINE('Result: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Plants loaded: ' || v_plant_count);
    
    IF v_status != 'SUCCESS' THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || v_msg);
        RETURN;
    END IF;
    
    -- Step 2: Select GRANE plant
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 2: Selecting GRANE plant...');
    INSERT INTO SELECTED_PLANTS (plant_id, is_active, selected_by, selection_date)
    SELECT plant_id, 'Y', USER, SYSDATE
    FROM PLANTS
    WHERE plant_id = '34'  -- GRANE's ID
    AND is_valid = 'Y';
    
    IF SQL%ROWCOUNT = 0 THEN
        -- Try by short description if ID didn't work
        INSERT INTO SELECTED_PLANTS (plant_id, is_active, selected_by, selection_date)
        SELECT plant_id, 'Y', USER, SYSDATE
        FROM PLANTS
        WHERE SHORT_DESCRIPTION = 'GRANE'
        AND is_valid = 'Y';
    END IF;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('GRANE selected: ' || SQL%ROWCOUNT || ' plant(s)');
    
    -- Step 3: Load issues for GRANE
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 3: Loading issues for GRANE (plant_id=34)...');
    pkg_api_client.refresh_issues_from_api('34', v_status, v_msg);
    
    SELECT COUNT(*) INTO v_issue_count FROM ISSUES WHERE plant_id = '34' AND is_valid = 'Y';
    DBMS_OUTPUT.PUT_LINE('Result: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Issues loaded for GRANE: ' || v_issue_count);
    
    IF v_status != 'SUCCESS' THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || v_msg);
    END IF;
    
    -- Step 4: Select issue 4.2
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 4: Selecting issue 4.2...');
    INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active, selected_by, selection_date)
    SELECT plant_id, issue_revision, 'Y', USER, SYSDATE
    FROM ISSUES
    WHERE plant_id = '34'
    AND issue_revision = '4.2'
    AND is_valid = 'Y';
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Issue 4.2 selected: ' || SQL%ROWCOUNT || ' issue(s)');
    
    -- Step 5: Set PCS loading mode to OFFICIAL_ONLY
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 5: Setting PCS loading mode to OFFICIAL_ONLY...');
    UPDATE CONTROL_SETTINGS 
    SET setting_value = 'OFFICIAL_ONLY',
        modified_date = SYSDATE
    WHERE setting_key = 'PCS_LOADING_MODE';
    
    IF SQL%ROWCOUNT = 0 THEN
        -- Insert if doesn't exist
        INSERT INTO CONTROL_SETTINGS (setting_key, setting_value, setting_type, description, created_date, modified_date)
        VALUES ('PCS_LOADING_MODE', 'OFFICIAL_ONLY', 'STRING', 'PCS Loading Mode: ALL or OFFICIAL_ONLY', SYSDATE, SYSDATE);
    END IF;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('PCS loading mode set to OFFICIAL_ONLY');
    
    -- Step 6: Run full ETL
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Step 6: Running full ETL for selected items...');
    DBMS_OUTPUT.PUT_LINE('This will load:');
    DBMS_OUTPUT.PUT_LINE('  - All 9 reference types for issue 4.2');
    DBMS_OUTPUT.PUT_LINE('  - PCS details (official revisions only)');
    DBMS_OUTPUT.PUT_LINE('  - VDS details (official records only)');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Starting ETL...');
    
    pkg_etl_operations.run_full_etl(v_status, v_msg);
    
    DBMS_OUTPUT.PUT_LINE('ETL Result: ' || v_status);
    IF v_msg IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Message: ' || v_msg);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('GRANE/4.2 Data Load Complete!');
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
SELECT 'GRANE Selected', COUNT(*) 
FROM SELECTED_PLANTS WHERE plant_id = '34' AND is_active = 'Y'
UNION ALL
SELECT 'Issues for GRANE', COUNT(*) 
FROM ISSUES WHERE plant_id = '34' AND is_valid = 'Y'
UNION ALL
SELECT 'Issue 4.2 Selected', COUNT(*) 
FROM SELECTED_ISSUES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_active = 'Y'
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
SELECT 'Other References', 
    (SELECT COUNT(*) FROM SC_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM VSM_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM EDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM ESK_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM VSK_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y') +
    (SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2' AND is_valid = 'Y')
FROM DUAL
UNION ALL
SELECT 'PCS List (Total)', COUNT(*) 
FROM PCS_LIST WHERE plant_id = '34' AND is_valid = 'Y'
UNION ALL
SELECT 'PCS List (Official)', COUNT(*) 
FROM PCS_LIST WHERE plant_id = '34' AND is_official = 'Y' AND is_valid = 'Y'
UNION ALL
SELECT 'VDS List', COUNT(*) 
FROM VDS_LIST WHERE is_valid = 'Y'
UNION ALL
SELECT 'VDS Details', COUNT(*) 
FROM VDS_DETAILS WHERE is_valid = 'Y';

EXIT;