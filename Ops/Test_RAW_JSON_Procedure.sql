-- Test script to validate SP_INSERT_RAW_JSON procedure
-- Run this in SQL Developer to check what's wrong

-- 1. Check if RAW_JSON table exists
SELECT table_name FROM user_tables WHERE table_name = 'RAW_JSON';

-- 2. Check if SP_INSERT_RAW_JSON procedure exists
SELECT object_name, object_type, status 
FROM user_objects 
WHERE object_name = 'SP_INSERT_RAW_JSON';

-- 3. Check compilation errors (if any)
SELECT line, position, text
FROM user_errors
WHERE name = 'SP_INSERT_RAW_JSON'
ORDER BY line, position;

-- 4. Simple test call (if procedure exists)
DECLARE
    v_test_result NUMBER;
BEGIN
    SP_INSERT_RAW_JSON(
        p_etl_run_id     => 999,
        p_endpoint       => 'test',
        p_request_url    => 'https://test.com',
        p_request_params => '{}',
        p_response_status => 200,
        p_plant_id       => 'TEST_PLANT',
        p_json_data      => '{"test": "data"}',
        p_duration_ms    => 100,
        p_headers        => '{}'
    );
    DBMS_OUTPUT.PUT_LINE('SP_INSERT_RAW_JSON test successful');
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('SP_INSERT_RAW_JSON test failed: ' || SQLERRM);
        ROLLBACK;
END;
/

-- 5. Check if test data was inserted
SELECT COUNT(*) FROM RAW_JSON WHERE ENDPOINT_NAME = 'test';