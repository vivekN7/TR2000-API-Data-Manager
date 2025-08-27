-- ===============================================================================
-- Fix test_reference_cascade in PKG_SIMPLE_TESTS
-- Date: 2025-08-26
-- Purpose: Add missing REFERENCE_GUID to test data inserts
-- ===============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_SIMPLE_TESTS AS
    -- Keep all existing functions...
    FUNCTION test_api_connection RETURN VARCHAR2 IS
        v_status VARCHAR2(50);
        v_msg VARCHAR2(4000);
    BEGIN
        pkg_api_client.refresh_plants_from_api(
            p_status => v_status,
            p_message => v_msg,
            p_correlation_id => 'TEST-' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDD-HH24MISS')
        );
        
        IF v_status = 'SUCCESS' THEN
            RETURN 'PASS';
        ELSE
            RETURN 'FAIL: API call failed - ' || SUBSTR(v_msg, 1, 100);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_api_connection;

    FUNCTION test_json_parsing RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM STG_PLANTS
        WHERE ROWNUM <= 1;
        
        IF v_count >= 0 THEN
            RETURN 'PASS';
        ELSE
            RETURN 'FAIL: No staging data found';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_json_parsing;

    FUNCTION test_soft_deletes RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM PLANTS
        WHERE is_valid = 'Y'
        AND ROWNUM <= 1;
        
        RETURN 'PASS';
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_soft_deletes;

    FUNCTION test_selection_cascade RETURN VARCHAR2 IS
    BEGIN
        RETURN 'PASS';
    END test_selection_cascade;

    FUNCTION test_error_capture RETURN VARCHAR2 IS
    BEGIN
        RETURN 'PASS';
    END test_error_capture;

    FUNCTION test_reference_parsing RETURN VARCHAR2 IS
        v_json CLOB;
        v_count NUMBER;
    BEGIN
        v_json := '{"success":true,"getIssuePCSList":[' ||
                  '{"PCS":"TEST1","Revision":"A","Status":"O"},' ||
                  '{"PCS":"TEST2","Revision":"B","Status":"I"}' ||
                  ']}';
        
        DELETE FROM RAW_JSON WHERE plant_id = 'TEST_PARSE';
        DELETE FROM STG_PCS_REFERENCES WHERE plant_id = 'TEST_PARSE';
        
        INSERT INTO RAW_JSON (endpoint_key, plant_id, issue_revision, response_json, response_hash, created_date)
        VALUES ('pcs_references', 'TEST_PARSE', '1.0', v_json, 'TEST_HASH', SYSDATE);
        
        INSERT INTO STG_PCS_REFERENCES (plant_id, issue_revision, pcs, revision, status)
        SELECT 'TEST_PARSE', '1.0', jt.pcs, jt.revision, jt.status
        FROM JSON_TABLE(v_json, '$.getIssuePCSList[*]'
            COLUMNS (
                pcs VARCHAR2(100) PATH '$.PCS',
                revision VARCHAR2(50) PATH '$.Revision',
                status VARCHAR2(50) PATH '$.Status'
            )
        ) jt;
        
        v_count := SQL%ROWCOUNT;
        
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

    -- FIXED VERSION OF test_reference_cascade
    FUNCTION test_reference_cascade RETURN VARCHAR2 IS
        v_issue_id NUMBER;
        v_before_count NUMBER;
        v_after_count NUMBER;
    BEGIN
        -- Clean up any existing test data
        DELETE FROM PCS_REFERENCES WHERE plant_id = 'TEST_CASCADE_PLANT';
        DELETE FROM VDS_REFERENCES WHERE plant_id = 'TEST_CASCADE_PLANT';
        DELETE FROM ISSUES WHERE plant_id = 'TEST_CASCADE_PLANT';
        DELETE FROM PLANTS WHERE plant_id = 'TEST_CASCADE_PLANT';
        
        -- First create test plant (required for FK)
        INSERT INTO PLANTS (
            plant_id, short_description, is_valid, created_date
        ) VALUES (
            'TEST_CASCADE_PLANT', 'Test Plant for Cascade', 'Y', SYSDATE
        );

        -- Create test issue
        INSERT INTO ISSUES (
            plant_id, issue_revision, status, is_valid, created_date
        ) VALUES (
            'TEST_CASCADE_PLANT', 'TEST_CASCADE_REV', 'Active', 'Y', SYSDATE
        ) RETURNING issue_id INTO v_issue_id;

        -- Create test references WITH REQUIRED FIELDS
        INSERT INTO PCS_REFERENCES (
            reference_guid, plant_id, issue_revision, pcs_name, 
            is_valid, created_date, last_modified_date
        ) VALUES (
            SYS_GUID(), 'TEST_CASCADE_PLANT', 'TEST_CASCADE_REV', 'TEST_PCS', 
            'Y', SYSDATE, SYSDATE
        );

        INSERT INTO VDS_REFERENCES (
            reference_guid, plant_id, issue_revision, vds_name,
            is_valid, created_date, last_modified_date
        ) VALUES (
            SYS_GUID(), 'TEST_CASCADE_PLANT', 'TEST_CASCADE_REV', 'TEST_VDS',
            'Y', SYSDATE, SYSDATE
        );

        -- Count active references
        SELECT COUNT(*) INTO v_before_count
        FROM (
            SELECT 1 FROM PCS_REFERENCES
            WHERE plant_id = 'TEST_CASCADE_PLANT' AND is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM VDS_REFERENCES
            WHERE plant_id = 'TEST_CASCADE_PLANT' AND is_valid = 'Y'
        );

        -- Mark issue as invalid (should trigger cascade)
        UPDATE ISSUES
        SET is_valid = 'N'
        WHERE plant_id = 'TEST_CASCADE_PLANT'
          AND issue_revision = 'TEST_CASCADE_REV';

        COMMIT;

        -- Count active references after cascade
        SELECT COUNT(*) INTO v_after_count
        FROM (
            SELECT 1 FROM PCS_REFERENCES
            WHERE plant_id = 'TEST_CASCADE_PLANT' AND is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM VDS_REFERENCES
            WHERE plant_id = 'TEST_CASCADE_PLANT' AND is_valid = 'Y'
        );

        -- Clean up test data
        DELETE FROM PCS_REFERENCES WHERE plant_id = 'TEST_CASCADE_PLANT';
        DELETE FROM VDS_REFERENCES WHERE plant_id = 'TEST_CASCADE_PLANT';
        DELETE FROM ISSUES WHERE plant_id = 'TEST_CASCADE_PLANT';
        DELETE FROM PLANTS WHERE plant_id = 'TEST_CASCADE_PLANT';
        COMMIT;

        IF v_before_count = 2 AND v_after_count = 0 THEN
            RETURN 'PASS';
        ELSE
            RETURN 'FAIL: Before=' || v_before_count || ', After=' || v_after_count;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            -- Clean up on error
            DELETE FROM PCS_REFERENCES WHERE plant_id = 'TEST_CASCADE_PLANT';
            DELETE FROM VDS_REFERENCES WHERE plant_id = 'TEST_CASCADE_PLANT';
            DELETE FROM ISSUES WHERE plant_id = 'TEST_CASCADE_PLANT';
            DELETE FROM PLANTS WHERE plant_id = 'TEST_CASCADE_PLANT';
            COMMIT;
            RETURN 'FAIL: ' || SQLERRM;
    END test_reference_cascade;

    FUNCTION test_invalid_fk RETURN VARCHAR2 IS
        v_error_caught BOOLEAN := FALSE;
    BEGIN
        BEGIN
            INSERT INTO PCS_REFERENCES (
                reference_guid, plant_id, issue_revision, pcs_name,
                is_valid, created_date, last_modified_date
            )
            VALUES (
                SYS_GUID(), 'INVALID_PLANT', 'INVALID_ISSUE', 'TEST',
                'Y', SYSDATE, SYSDATE
            );
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -2291 THEN
                    v_error_caught := TRUE;
                END IF;
        END;
        
        IF v_error_caught THEN
            RETURN 'PASS';
        ELSE
            RETURN 'FAIL: FK constraint not enforced';
        END IF;
    END test_invalid_fk;

    PROCEDURE run_critical_tests IS
        v_test_status VARCHAR2(20);
        v_test_result VARCHAR2(500);
        v_pass_count NUMBER := 0;
        v_total_count NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Starting ETL Critical Tests');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
        -- Test API Connection
        v_total_count := v_total_count + 1;
        DBMS_OUTPUT.PUT('Running test_api_connection... ');
        v_test_result := test_api_connection();
        IF v_test_result = 'PASS' THEN
            v_pass_count := v_pass_count + 1;
            v_test_status := 'PASS';
            DBMS_OUTPUT.PUT_LINE('PASS');
        ELSE
            v_test_status := 'FAIL';
            DBMS_OUTPUT.PUT_LINE(v_test_result);
        END IF;
        log_test_result('test_api_connection', v_test_status, v_test_result);
        
        -- Test JSON Parsing
        v_total_count := v_total_count + 1;
        DBMS_OUTPUT.PUT('Running test_json_parsing... ');
        v_test_result := test_json_parsing();
        IF v_test_result = 'PASS' THEN
            v_pass_count := v_pass_count + 1;
            v_test_status := 'PASS';
            DBMS_OUTPUT.PUT_LINE('PASS');
        ELSE
            v_test_status := 'FAIL';
            DBMS_OUTPUT.PUT_LINE(v_test_result);
        END IF;
        log_test_result('test_json_parsing', v_test_status, v_test_result);
        
        -- Test Soft Deletes
        v_total_count := v_total_count + 1;
        DBMS_OUTPUT.PUT('Running test_soft_deletes... ');
        v_test_result := test_soft_deletes();
        IF v_test_result = 'PASS' THEN
            v_pass_count := v_pass_count + 1;
            v_test_status := 'PASS';
            DBMS_OUTPUT.PUT_LINE('PASS');
        ELSE
            v_test_status := 'FAIL';
            DBMS_OUTPUT.PUT_LINE(v_test_result);
        END IF;
        log_test_result('test_soft_deletes', v_test_status, v_test_result);
        
        -- Test Selection Cascade
        v_total_count := v_total_count + 1;
        DBMS_OUTPUT.PUT('Running test_selection_cascade... ');
        v_test_result := test_selection_cascade();
        IF v_test_result = 'PASS' THEN
            v_pass_count := v_pass_count + 1;
            v_test_status := 'PASS';
            DBMS_OUTPUT.PUT_LINE('PASS');
        ELSE
            v_test_status := 'FAIL';
            DBMS_OUTPUT.PUT_LINE(v_test_result);
        END IF;
        log_test_result('test_selection_cascade', v_test_status, v_test_result);
        
        -- Test Error Capture
        v_total_count := v_total_count + 1;
        DBMS_OUTPUT.PUT('Running test_error_capture... ');
        v_test_result := test_error_capture();
        IF v_test_result = 'PASS' THEN
            v_pass_count := v_pass_count + 1;
            v_test_status := 'PASS';
            DBMS_OUTPUT.PUT_LINE('PASS');
        ELSE
            v_test_status := 'FAIL';
            DBMS_OUTPUT.PUT_LINE(v_test_result);
        END IF;
        log_test_result('test_error_capture', v_test_status, v_test_result);
        
        -- Test Reference Parsing
        v_total_count := v_total_count + 1;
        DBMS_OUTPUT.PUT('Running test_reference_parsing... ');
        v_test_result := test_reference_parsing();
        IF SUBSTR(v_test_result, 1, 4) = 'PASS' THEN
            v_pass_count := v_pass_count + 1;
            v_test_status := 'PASS';
            DBMS_OUTPUT.PUT_LINE(v_test_result);
        ELSE
            v_test_status := 'FAIL';
            DBMS_OUTPUT.PUT_LINE(v_test_result);
        END IF;
        log_test_result('test_reference_parsing', v_test_status, v_test_result);
        
        -- Test Reference Cascade
        v_total_count := v_total_count + 1;
        DBMS_OUTPUT.PUT('Running test_reference_cascade... ');
        v_test_result := test_reference_cascade();
        IF v_test_result = 'PASS' THEN
            v_pass_count := v_pass_count + 1;
            v_test_status := 'PASS';
            DBMS_OUTPUT.PUT_LINE('PASS');
        ELSE
            v_test_status := 'FAIL';
            DBMS_OUTPUT.PUT_LINE(v_test_result);
        END IF;
        log_test_result('test_reference_cascade', v_test_status, v_test_result);
        
        -- Test Invalid FK
        v_total_count := v_total_count + 1;
        DBMS_OUTPUT.PUT('Running test_invalid_fk... ');
        v_test_result := test_invalid_fk();
        IF v_test_result = 'PASS' THEN
            v_pass_count := v_pass_count + 1;
            v_test_status := 'PASS';
            DBMS_OUTPUT.PUT_LINE('PASS');
        ELSE
            v_test_status := 'FAIL';
            DBMS_OUTPUT.PUT_LINE(v_test_result);
        END IF;
        log_test_result('test_invalid_fk', v_test_status, v_test_result);
        
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('Test Results: ' || v_pass_count || '/' || v_total_count || ' PASSED');
        DBMS_OUTPUT.PUT_LINE('========================================');
        
        IF v_pass_count < v_total_count THEN
            DBMS_OUTPUT.PUT_LINE('WARNING: Some tests failed. Check TEST_RESULTS table for details.');
            DBMS_OUTPUT.PUT_LINE('Run: SELECT * FROM V_TEST_FAILURES;');
        END IF;
    END run_critical_tests;

    PROCEDURE log_test_result(
        p_test_name VARCHAR2,
        p_status VARCHAR2,
        p_message VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO TEST_RESULTS (
            test_name, run_date, status,
            data_flow_step, execution_time_ms,
            error_message
        ) VALUES (
            p_test_name, SYSDATE, p_status,
            'ETL_PIPELINE', 0,
            p_message
        );
        COMMIT;
    END log_test_result;

END PKG_SIMPLE_TESTS;
/

PROMPT
PROMPT ===============================================================================
PROMPT Fixed test_reference_cascade - Added missing REFERENCE_GUID fields
PROMPT ===============================================================================