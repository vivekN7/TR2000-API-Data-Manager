-- Test Basic ETL Functions
-- Date: 2025-08-23

SET SERVEROUTPUT ON SIZE UNLIMITED
ALTER SESSION SET CURRENT_SCHEMA = TR2000_STAGING;

PROMPT ========================================
PROMPT Testing Basic ETL Functions
PROMPT ========================================
PROMPT

-- Test 1: Fetch Plants from API
PROMPT Test 1: Testing pkg_api_client.fetch_plants_json
DECLARE
    v_response CLOB;
    v_plant_count NUMBER;
BEGIN
    v_response := pkg_api_client.fetch_plants_json;
    
    -- Count plants in response
    SELECT COUNT(*) INTO v_plant_count
    FROM JSON_TABLE(v_response, '$[*]'
        COLUMNS (plant_id VARCHAR2(50) PATH '$.PlantID'));
    
    DBMS_OUTPUT.PUT_LINE('✅ Plants fetch successful!');
    DBMS_OUTPUT.PUT_LINE('   Response length: ' || LENGTH(v_response));
    DBMS_OUTPUT.PUT_LINE('   Number of plants: ' || v_plant_count);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Plants fetch failed: ' || SQLERRM);
END;
/

-- Test 2: Fetch Issues for a specific plant
PROMPT
PROMPT Test 2: Testing pkg_api_client.fetch_issues_json for plant AAS
DECLARE
    v_response CLOB;
    v_issue_count NUMBER;
BEGIN
    v_response := pkg_api_client.fetch_issues_json('AAS');
    
    -- Count issues in response
    SELECT COUNT(*) INTO v_issue_count
    FROM JSON_TABLE(v_response, '$[*]'
        COLUMNS (revision VARCHAR2(50) PATH '$.Revision'));
    
    DBMS_OUTPUT.PUT_LINE('✅ Issues fetch successful!');
    DBMS_OUTPUT.PUT_LINE('   Response length: ' || LENGTH(v_response));
    DBMS_OUTPUT.PUT_LINE('   Number of issues: ' || v_issue_count);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Issues fetch failed: ' || SQLERRM);
END;
/

-- Test 3: Test SHA256 calculation
PROMPT
PROMPT Test 3: Testing pkg_api_client.calculate_sha256
DECLARE
    v_hash VARCHAR2(64);
BEGIN
    v_hash := pkg_api_client.calculate_sha256('Test data for hashing');
    DBMS_OUTPUT.PUT_LINE('✅ SHA256 calculation successful!');
    DBMS_OUTPUT.PUT_LINE('   Hash: ' || v_hash);
    DBMS_OUTPUT.PUT_LINE('   Hash length: ' || LENGTH(v_hash));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ SHA256 calculation failed: ' || SQLERRM);
END;
/

-- Test 4: Test Plants refresh procedure
PROMPT
PROMPT Test 4: Testing pkg_api_client.refresh_plants_from_api
DECLARE
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
BEGIN
    pkg_api_client.refresh_plants_from_api(v_status, v_message);
    
    IF v_status = 'SUCCESS' THEN
        DBMS_OUTPUT.PUT_LINE('✅ Plants refresh successful!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('⚠️  Plants refresh status: ' || v_status);
    END IF;
    DBMS_OUTPUT.PUT_LINE('   Message: ' || v_message);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Plants refresh failed: ' || SQLERRM);
END;
/

-- Test 5: Check RAW_JSON table
PROMPT
PROMPT Test 5: Checking RAW_JSON table contents
SELECT 
    endpoint_key,
    COUNT(*) as record_count,
    MIN(created_date) as oldest_record,
    MAX(created_date) as newest_record
FROM RAW_JSON
GROUP BY endpoint_key;

-- Test 6: Check PLANTS table
PROMPT
PROMPT Test 6: Checking PLANTS table
SELECT COUNT(*) as plant_count, 
       SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) as valid_plants
FROM PLANTS;

-- Test 7: Test Selection Management
PROMPT
PROMPT Test 7: Testing Selection Management
BEGIN
    -- Clear existing selections
    DELETE FROM SELECTION_LOADER;
    
    -- Add some test plants
    INSERT INTO SELECTION_LOADER (plant_id, is_active) VALUES ('AAS', 'Y');
    INSERT INTO SELECTION_LOADER (plant_id, is_active) VALUES ('DEV', 'Y');
    INSERT INTO SELECTION_LOADER (plant_id, is_active) VALUES ('GOA', 'Y');
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('✅ Added 3 plants to selection');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Selection management failed: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Test 8: Test the new purge procedure
PROMPT
PROMPT Test 8: Testing pr_purge_raw_json procedure
DECLARE
    v_count NUMBER;
BEGIN
    -- Dry run test
    pr_purge_raw_json(30, TRUE, v_count);
    DBMS_OUTPUT.PUT_LINE('✅ Purge procedure (dry run) successful!');
    DBMS_OUTPUT.PUT_LINE('   Would delete ' || v_count || ' records older than 30 days');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Purge procedure failed: ' || SQLERRM);
END;
/

-- Test 9: Check ETL_RUN_LOG
PROMPT
PROMPT Test 9: Checking ETL_RUN_LOG
SELECT run_type, status, COUNT(*) as run_count
FROM ETL_RUN_LOG
GROUP BY run_type, status
ORDER BY run_type, status;

-- Test 10: Verify all packages are valid
PROMPT
PROMPT Test 10: Checking package compilation status
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')
AND object_name LIKE 'PKG%'
ORDER BY object_name, object_type;

PROMPT
PROMPT ========================================
PROMPT All ETL Function Tests Complete!
PROMPT ========================================