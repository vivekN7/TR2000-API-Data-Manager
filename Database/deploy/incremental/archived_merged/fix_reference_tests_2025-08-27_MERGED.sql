-- ===============================================================================
-- Fix Reference Tests to Use Correct JSON Structure
-- Date: 2025-08-27
-- Purpose: Update tests to match actual API JSON format
-- ===============================================================================

-- Only update the reference parsing test function
CREATE OR REPLACE FUNCTION test_reference_parsing RETURN VARCHAR2 IS
    v_json CLOB;
    v_count NUMBER;
BEGIN
    -- Use correct JSON structure that matches API
    v_json := '{"success":true,"getIssuePCSList":[' ||
              '{"PCS":"TEST1","Revision":"A","Status":"O"},' ||
              '{"PCS":"TEST2","Revision":"B","Status":"I"}' ||
              ']}';
    
    DELETE FROM RAW_JSON WHERE plant_id = 'TEST_PARSE';
    DELETE FROM STG_PCS_REFERENCES WHERE plant_id = 'TEST_PARSE';
    
    INSERT INTO RAW_JSON (endpoint_key, plant_id, issue_revision, response_json, response_hash, created_date)
    VALUES ('pcs_references', 'TEST_PARSE', '1.0', v_json, 'TEST_HASH', SYSDATE);
    
    -- Use the actual package to parse
    DECLARE
        v_raw_id NUMBER;
    BEGIN
        SELECT raw_json_id INTO v_raw_id
        FROM RAW_JSON 
        WHERE plant_id = 'TEST_PARSE'
        AND ROWNUM = 1;
        
        PKG_PARSE_REFERENCES.parse_pcs_json(
            p_raw_json_id => v_raw_id,
            p_plant_id => 'TEST_PARSE',
            p_issue_rev => '1.0'
        );
    END;
    
    v_count := SQL%ROWCOUNT;
    
    -- Check the count
    SELECT COUNT(*) INTO v_count FROM STG_PCS_REFERENCES WHERE plant_id = 'TEST_PARSE';
    
    DELETE FROM STG_PCS_REFERENCES WHERE plant_id = 'TEST_PARSE';
    DELETE FROM RAW_JSON WHERE plant_id = 'TEST_PARSE';
    COMMIT;
    
    IF v_count = 2 THEN
        RETURN 'PASS: Parsed ' || v_count || ' PCS references';
    ELSE
        RETURN 'FAIL: Expected 2, got ' || v_count;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DELETE FROM STG_PCS_REFERENCES WHERE plant_id = 'TEST_PARSE';
        DELETE FROM RAW_JSON WHERE plant_id = 'TEST_PARSE';
        COMMIT;
        RETURN 'FAIL: ' || SQLERRM;
END test_reference_parsing;
/

PROMPT
PROMPT ===============================================================================
PROMPT Reference parsing test fixed to use correct JSON structure
PROMPT ===============================================================================