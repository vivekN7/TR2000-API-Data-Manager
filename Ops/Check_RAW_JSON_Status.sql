-- Check what's actually in RAW_JSON table and procedure status

-- 1. Check if RAW_JSON table has any data
SELECT COUNT(*) as TOTAL_RECORDS FROM RAW_JSON;

-- 2. Show recent RAW_JSON records (if any)
SELECT 
    JSON_ID, 
    ETL_RUN_ID, 
    ENDPOINT_NAME, 
    PLANT_ID, 
    CREATED_DATE,
    RESPONSE_STATUS,
    LENGTH(JSON_DATA) as JSON_SIZE,
    PROCESSED_FLAG
FROM RAW_JSON 
ORDER BY CREATED_DATE DESC
FETCH FIRST 10 ROWS ONLY;

-- 3. Check SP_INSERT_RAW_JSON procedure status
SELECT object_name, object_type, status, created, last_ddl_time 
FROM user_objects 
WHERE object_name = 'SP_INSERT_RAW_JSON';

-- 4. Check for any compilation errors
SELECT line, position, text
FROM user_errors
WHERE name = 'SP_INSERT_RAW_JSON'
ORDER BY line, position;

-- 5. Show the procedure source (first few lines)
SELECT text 
FROM user_source 
WHERE name = 'SP_INSERT_RAW_JSON' 
AND type = 'PROCEDURE'
ORDER BY line
FETCH FIRST 20 ROWS ONLY;

-- 6. Test if procedure can be called manually
DECLARE
    v_test_json CLOB := '{"test": "manual_call", "timestamp": "' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || '"}';
BEGIN
    SP_INSERT_RAW_JSON(
        p_etl_run_id     => 888,
        p_endpoint       => 'manual_test',
        p_request_url    => 'https://test.com/manual',
        p_request_params => NULL,
        p_response_status => 200,
        p_plant_id       => 'TEST_MANUAL',
        p_json_data      => v_test_json,
        p_duration_ms    => 100,
        p_headers        => '{"test": "manual"}'
    );
    DBMS_OUTPUT.PUT_LINE('✅ Manual SP_INSERT_RAW_JSON test successful!');
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Manual test failed: ' || SQLERRM);
        ROLLBACK;
END;
/

-- 7. Check if the manual test record was inserted
SELECT COUNT(*) as MANUAL_TEST_COUNT 
FROM RAW_JSON 
WHERE ENDPOINT_NAME = 'manual_test';