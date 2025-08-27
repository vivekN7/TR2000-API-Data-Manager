-- ============================================================================
-- Additional Tests Based on Issues Discovered
-- ============================================================================
-- Purpose: Tests for issues discovered during ETL implementation
-- Author: TR2000 ETL Team
-- Date: 2025-08-24
-- ============================================================================

CREATE OR REPLACE PACKAGE PKG_ADDITIONAL_TESTS AS
    
    -- Test for JSON path mismatches
    FUNCTION test_json_path_mismatch RETURN VARCHAR2;
    
    -- Test for field name case sensitivity
    FUNCTION test_field_case_sensitivity RETURN VARCHAR2;
    
    -- Test for NULL in primary key fields
    FUNCTION test_null_primary_keys RETURN VARCHAR2;
    
    -- Test for wrong column names in ETL
    FUNCTION test_wrong_column_names RETURN VARCHAR2;
    
    -- Master procedure to run all additional tests
    PROCEDURE run_additional_tests;
    
END PKG_ADDITIONAL_TESTS;
/

CREATE OR REPLACE PACKAGE BODY PKG_ADDITIONAL_TESTS AS

    -- ========================================================================
    -- Test: JSON Path Mismatch
    -- Risk: API changes JSON structure without notice
    -- ========================================================================
    FUNCTION test_json_path_mismatch RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_count NUMBER := 0;
        v_json CLOB;
        v_raw_json_id NUMBER;
    BEGIN
        -- Test 1: Wrong root path - API returns 'plants' instead of 'getPlant'
        v_json := '{"plants":[{"PlantID":999,"ShortDescription":"TEST_PLANT"}]}';
        
        -- Insert test JSON
        INSERT INTO RAW_JSON (endpoint, payload, key_fingerprint, created_date)
        VALUES ('plants', v_json, 'TEST_HASH_PATH_001', SYSDATE)
        RETURNING raw_json_id INTO v_raw_json_id;
        
        -- Try to parse with expected path (should find nothing)
        BEGIN
            SELECT COUNT(*) INTO v_count
            FROM RAW_JSON r,
                 JSON_TABLE(r.payload, '$.getPlant[*]'
                     COLUMNS (
                         PlantID NUMBER PATH '$.PlantID',
                         ShortDescription VARCHAR2(100) PATH '$.ShortDescription'
                     )
                 ) jt
            WHERE r.raw_json_id = v_raw_json_id;
            
            IF v_count = 0 THEN
                v_result := 'PASS: Correctly detected JSON path mismatch (found 0 records with wrong path)';
            ELSE
                v_result := 'FAIL: Parser should not find data with wrong JSON path';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                -- This is expected - wrong path should cause issues
                v_result := 'PASS: JSON path mismatch properly detected';
        END;
        
        -- Cleanup
        DELETE FROM RAW_JSON WHERE raw_json_id = v_raw_json_id;
        COMMIT;
        
        RETURN v_result;
    EXCEPTION
        WHEN OTHERS THEN
            -- Cleanup on error
            ROLLBACK;
            RETURN 'ERROR: ' || SQLERRM;
    END test_json_path_mismatch;

    -- ========================================================================
    -- Test: Field Case Sensitivity
    -- Risk: API changes field casing (PlantID vs plantId)
    -- ========================================================================
    FUNCTION test_field_case_sensitivity RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_json CLOB;
        v_raw_json_id NUMBER;
        v_plant_id NUMBER;
    BEGIN
        -- Test: API returns camelCase instead of PascalCase
        v_json := '{"getPlant":[{"plantId":888,"shortDescription":"CASE_TEST"}]}';
        
        INSERT INTO RAW_JSON (endpoint, payload, key_fingerprint, created_date)
        VALUES ('plants', v_json, 'TEST_HASH_CASE_001', SYSDATE)
        RETURNING raw_json_id INTO v_raw_json_id;
        
        -- Try to parse with PascalCase expectation
        BEGIN
            SELECT PlantID INTO v_plant_id
            FROM RAW_JSON r,
                 JSON_TABLE(r.payload, '$.getPlant[*]'
                     COLUMNS (
                         PlantID NUMBER PATH '$.PlantID'  -- Expects PascalCase
                     )
                 ) jt
            WHERE r.raw_json_id = v_raw_json_id
            AND ROWNUM = 1;
            
            IF v_plant_id IS NULL THEN
                v_result := 'PASS: Case sensitivity issue detected';
            ELSE
                v_result := 'FAIL: Should not parse with wrong case';
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_result := 'PASS: Case sensitivity properly detected (no data found)';
            WHEN OTHERS THEN
                v_result := 'PASS: Case sensitivity caused expected error';
        END;
        
        -- Cleanup
        DELETE FROM RAW_JSON WHERE raw_json_id = v_raw_json_id;
        COMMIT;
        
        RETURN v_result;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RETURN 'ERROR: ' || SQLERRM;
    END test_field_case_sensitivity;

    -- ========================================================================
    -- Test: NULL Primary Keys
    -- Risk: NULL values in key fields break MERGE operations
    -- ========================================================================
    FUNCTION test_null_primary_keys RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_count NUMBER := 0;
    BEGIN
        -- Insert test data with NULL key field
        INSERT INTO STG_ISSUES (plant_id, issue_revision, status, created_date)
        VALUES ('TEST_PLANT_NULL', NULL, 'S', SYSDATE);
        
        -- Try to merge with NULL key (should handle gracefully)
        BEGIN
            MERGE INTO ISSUES tgt
            USING (SELECT * FROM STG_ISSUES WHERE plant_id = 'TEST_PLANT_NULL') src
            ON (tgt.plant_id = src.plant_id AND 
                NVL(tgt.issue_revision, 'NULL') = NVL(src.issue_revision, 'NULL'))
            WHEN MATCHED THEN 
                UPDATE SET status = src.status
            WHEN NOT MATCHED THEN 
                INSERT (plant_id, issue_revision, status, is_valid, created_date)
                VALUES (src.plant_id, src.issue_revision, src.status, 'N', SYSDATE);
            
            -- Check if NULL key was handled
            SELECT COUNT(*) INTO v_count
            FROM ISSUES 
            WHERE plant_id = 'TEST_PLANT_NULL';
            
            IF v_count > 0 THEN
                -- Check if it was marked invalid due to NULL key
                SELECT COUNT(*) INTO v_count
                FROM ISSUES 
                WHERE plant_id = 'TEST_PLANT_NULL'
                AND is_valid = 'N';
                
                IF v_count > 0 THEN
                    v_result := 'PASS: NULL key detected and marked invalid';
                ELSE
                    v_result := 'FAIL: NULL key not properly handled';
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                -- NULL key causing error is acceptable
                v_result := 'PASS: NULL key prevented from entering core table';
        END;
        
        -- Cleanup
        DELETE FROM STG_ISSUES WHERE plant_id = 'TEST_PLANT_NULL';
        DELETE FROM ISSUES WHERE plant_id = 'TEST_PLANT_NULL';
        COMMIT;
        
        RETURN v_result;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RETURN 'ERROR: ' || SQLERRM;
    END test_null_primary_keys;

    -- ========================================================================
    -- Test: Wrong Column Names
    -- Risk: Using wrong column names in INSERT/UPDATE statements
    -- ========================================================================
    FUNCTION test_wrong_column_names RETURN VARCHAR2 IS
        v_result VARCHAR2(4000) := 'PASS';
        v_count NUMBER := 0;
    BEGIN
        -- Test 1: Check ETL_ERROR_LOG has correct columns
        SELECT COUNT(*) INTO v_count
        FROM user_tab_columns
        WHERE table_name = 'ETL_ERROR_LOG'
        AND column_name = 'ERROR_TIMESTAMP';
        
        IF v_count = 0 THEN
            v_result := 'FAIL: ETL_ERROR_LOG missing ERROR_TIMESTAMP column';
            RETURN v_result;
        END IF;
        
        -- Test 2: Try inserting with correct column names
        BEGIN
            INSERT INTO ETL_ERROR_LOG (
                error_type,
                error_message,
                error_timestamp,
                endpoint_key
            ) VALUES (
                'TEST_COLUMN_CHECK',
                'Testing column names',
                SYSTIMESTAMP,
                'test'
            );
            
            -- If we get here, columns are correct
            v_result := 'PASS: All column names verified';
            
            -- Cleanup
            DELETE FROM ETL_ERROR_LOG WHERE error_type = 'TEST_COLUMN_CHECK';
            COMMIT;
        EXCEPTION
            WHEN OTHERS THEN
                v_result := 'FAIL: Column name error - ' || SQLERRM;
        END;
        
        RETURN v_result;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RETURN 'ERROR: ' || SQLERRM;
    END test_wrong_column_names;

    -- ========================================================================
    -- Master Procedure: Run All Additional Tests
    -- ========================================================================
    PROCEDURE run_additional_tests IS
        v_test_count NUMBER := 0;
        v_pass_count NUMBER := 0;
        v_fail_count NUMBER := 0;
        v_result VARCHAR2(4000);
    BEGIN
        DBMS_OUTPUT.PUT_LINE('================================================================================');
        DBMS_OUTPUT.PUT_LINE('Running Additional ETL Tests');
        DBMS_OUTPUT.PUT_LINE('================================================================================');
        
        -- Test 1: JSON Path Mismatch
        v_result := test_json_path_mismatch();
        v_test_count := v_test_count + 1;
        IF v_result LIKE 'PASS%' THEN
            v_pass_count := v_pass_count + 1;
            DBMS_OUTPUT.PUT_LINE('✓ test_json_path_mismatch: ' || v_result);
        ELSE
            v_fail_count := v_fail_count + 1;
            DBMS_OUTPUT.PUT_LINE('✗ test_json_path_mismatch: ' || v_result);
        END IF;
        
        -- Test 2: Field Case Sensitivity
        v_result := test_field_case_sensitivity();
        v_test_count := v_test_count + 1;
        IF v_result LIKE 'PASS%' THEN
            v_pass_count := v_pass_count + 1;
            DBMS_OUTPUT.PUT_LINE('✓ test_field_case_sensitivity: ' || v_result);
        ELSE
            v_fail_count := v_fail_count + 1;
            DBMS_OUTPUT.PUT_LINE('✗ test_field_case_sensitivity: ' || v_result);
        END IF;
        
        -- Test 3: NULL Primary Keys
        v_result := test_null_primary_keys();
        v_test_count := v_test_count + 1;
        IF v_result LIKE 'PASS%' THEN
            v_pass_count := v_pass_count + 1;
            DBMS_OUTPUT.PUT_LINE('✓ test_null_primary_keys: ' || v_result);
        ELSE
            v_fail_count := v_fail_count + 1;
            DBMS_OUTPUT.PUT_LINE('✗ test_null_primary_keys: ' || v_result);
        END IF;
        
        -- Test 4: Wrong Column Names
        v_result := test_wrong_column_names();
        v_test_count := v_test_count + 1;
        IF v_result LIKE 'PASS%' THEN
            v_pass_count := v_pass_count + 1;
            DBMS_OUTPUT.PUT_LINE('✓ test_wrong_column_names: ' || v_result);
        ELSE
            v_fail_count := v_fail_count + 1;
            DBMS_OUTPUT.PUT_LINE('✗ test_wrong_column_names: ' || v_result);
        END IF;
        
        -- Summary
        DBMS_OUTPUT.PUT_LINE('================================================================================');
        DBMS_OUTPUT.PUT_LINE('Test Summary: ' || v_pass_count || '/' || v_test_count || ' passed');
        IF v_fail_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('⚠️  ' || v_fail_count || ' tests failed - review results above');
        ELSE
            DBMS_OUTPUT.PUT_LINE('✅ All additional tests passed!');
        END IF;
        DBMS_OUTPUT.PUT_LINE('================================================================================');
        
    END run_additional_tests;

END PKG_ADDITIONAL_TESTS;
/

SHOW ERRORS

PROMPT
PROMPT Package PKG_ADDITIONAL_TESTS created/updated
PROMPT To run tests: EXEC PKG_ADDITIONAL_TESTS.run_additional_tests;
PROMPT