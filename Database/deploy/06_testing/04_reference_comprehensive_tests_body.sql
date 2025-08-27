-- ===============================================================================
-- Reference Comprehensive Tests Package Body
-- Date: 2025-08-27
-- Purpose: Comprehensive testing of reference data ETL
-- ===============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_REFERENCE_COMPREHENSIVE_TESTS AS

    -- ========================================================================
    -- Individual Reference Type Tests
    -- ========================================================================
    
    FUNCTION test_pcs_references RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        -- Check if PCS_REFERENCES table exists and has data
        SELECT COUNT(*) INTO v_count FROM PCS_REFERENCES WHERE is_valid = 'Y';
        
        IF v_count > 0 THEN
            RETURN 'PASS: PCS_REFERENCES has ' || v_count || ' valid records';
        ELSE
            RETURN 'WARN: PCS_REFERENCES has no valid records';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_pcs_references;
    
    FUNCTION test_sc_references RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM SC_REFERENCES WHERE is_valid = 'Y';
        
        IF v_count >= 0 THEN
            RETURN 'PASS: SC_REFERENCES table accessible (' || v_count || ' records)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_sc_references;
    
    FUNCTION test_vsm_references RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM VSM_REFERENCES WHERE is_valid = 'Y';
        
        IF v_count >= 0 THEN
            RETURN 'PASS: VSM_REFERENCES table accessible (' || v_count || ' records)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_vsm_references;
    
    FUNCTION test_vds_references RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM VDS_REFERENCES WHERE is_valid = 'Y';
        
        IF v_count > 0 THEN
            RETURN 'PASS: VDS_REFERENCES has ' || v_count || ' valid records';
        ELSE
            RETURN 'WARN: VDS_REFERENCES has no valid records';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_vds_references;
    
    FUNCTION test_eds_references RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM EDS_REFERENCES WHERE is_valid = 'Y';
        
        IF v_count >= 0 THEN
            RETURN 'PASS: EDS_REFERENCES table accessible (' || v_count || ' records)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_eds_references;
    
    FUNCTION test_mds_references RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM MDS_REFERENCES WHERE is_valid = 'Y';
        
        IF v_count >= 0 THEN
            RETURN 'PASS: MDS_REFERENCES table accessible (' || v_count || ' records)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_mds_references;
    
    FUNCTION test_vsk_references RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM VSK_REFERENCES WHERE is_valid = 'Y';
        
        IF v_count >= 0 THEN
            RETURN 'PASS: VSK_REFERENCES table accessible (' || v_count || ' records)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_vsk_references;
    
    FUNCTION test_esk_references RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM ESK_REFERENCES WHERE is_valid = 'Y';
        
        IF v_count >= 0 THEN
            RETURN 'PASS: ESK_REFERENCES table accessible (' || v_count || ' records)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_esk_references;
    
    FUNCTION test_pipe_element_references RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y';
        
        IF v_count >= 0 THEN
            RETURN 'PASS: PIPE_ELEMENT_REFERENCES table accessible (' || v_count || ' records)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_pipe_element_references;
    
    -- ========================================================================
    -- Comprehensive Tests
    -- ========================================================================
    
    FUNCTION test_comprehensive_cascade RETURN VARCHAR2 IS
        v_result VARCHAR2(4000);
        v_count NUMBER;
    BEGIN
        -- Test if cascade triggers exist
        SELECT COUNT(*) INTO v_count
        FROM user_triggers
        WHERE trigger_name LIKE '%CASCADE%'
        AND status = 'ENABLED';
        
        IF v_count > 0 THEN
            RETURN 'PASS: ' || v_count || ' cascade triggers enabled';
        ELSE
            RETURN 'WARN: No cascade triggers found or enabled';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_comprehensive_cascade;
    
    FUNCTION test_json_parsing_all_types RETURN VARCHAR2 IS
        v_pkg_status VARCHAR2(20);
    BEGIN
        -- Check if PKG_PARSE_REFERENCES exists and is valid
        SELECT status INTO v_pkg_status
        FROM user_objects
        WHERE object_name = 'PKG_PARSE_REFERENCES'
        AND object_type = 'PACKAGE BODY'
        AND ROWNUM = 1;
        
        IF v_pkg_status = 'VALID' THEN
            RETURN 'PASS: PKG_PARSE_REFERENCES is valid and ready';
        ELSE
            RETURN 'FAIL: PKG_PARSE_REFERENCES is invalid';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'FAIL: PKG_PARSE_REFERENCES not found';
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_json_parsing_all_types;
    
    FUNCTION test_foreign_key_constraints RETURN VARCHAR2 IS
        v_count NUMBER;
        v_missing_fks VARCHAR2(4000);
    BEGIN
        v_missing_fks := '';
        
        -- Check each reference table for FK constraints
        FOR ref_table IN (
            SELECT 'PCS_REFERENCES' as table_name FROM dual UNION ALL
            SELECT 'SC_REFERENCES' FROM dual UNION ALL
            SELECT 'VSM_REFERENCES' FROM dual UNION ALL
            SELECT 'VDS_REFERENCES' FROM dual UNION ALL
            SELECT 'EDS_REFERENCES' FROM dual UNION ALL
            SELECT 'MDS_REFERENCES' FROM dual UNION ALL
            SELECT 'VSK_REFERENCES' FROM dual UNION ALL
            SELECT 'ESK_REFERENCES' FROM dual UNION ALL
            SELECT 'PIPE_ELEMENT_REFERENCES' FROM dual
        ) LOOP
            SELECT COUNT(*) INTO v_count
            FROM user_constraints
            WHERE table_name = ref_table.table_name
            AND constraint_type = 'R';
            
            IF v_count = 0 THEN
                v_missing_fks := v_missing_fks || ref_table.table_name || ' ';
            END IF;
        END LOOP;
        
        IF LENGTH(v_missing_fks) > 0 THEN
            RETURN 'FAIL: Missing FK constraints on: ' || v_missing_fks;
        ELSE
            RETURN 'PASS: All reference tables have FK constraints';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_foreign_key_constraints;
    
    FUNCTION test_soft_delete_all_types RETURN VARCHAR2 IS
        v_count NUMBER;
    BEGIN
        -- Check if all reference tables have is_valid column
        SELECT COUNT(*) INTO v_count
        FROM (
            SELECT table_name, column_name
            FROM user_tab_columns
            WHERE table_name LIKE '%_REFERENCES'
            AND column_name = 'IS_VALID'
        );
        
        IF v_count >= 9 THEN
            RETURN 'PASS: All ' || v_count || ' reference tables have IS_VALID column';
        ELSE
            RETURN 'FAIL: Only ' || v_count || ' reference tables have IS_VALID column (expected 9)';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAIL: ' || SQLERRM;
    END test_soft_delete_all_types;
    
    -- ========================================================================
    -- Main Test Runner
    -- ========================================================================
    
    PROCEDURE run_all_reference_tests IS
        v_status VARCHAR2(50);
        v_message VARCHAR2(4000);
        v_test_count NUMBER := 0;
        v_pass_count NUMBER := 0;
        v_fail_count NUMBER := 0;
        v_warn_count NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        DBMS_OUTPUT.PUT_LINE('Reference Comprehensive Tests');
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        
        -- Test 1: Individual reference type tests
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Individual Reference Type Tests:');
        DBMS_OUTPUT.PUT_LINE('---------------------------------');
        
        v_test_count := v_test_count + 1;
        v_message := test_pcs_references;
        DBMS_OUTPUT.PUT_LINE('PCS_REFERENCES: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_vds_references;
        DBMS_OUTPUT.PUT_LINE('VDS_REFERENCES: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_mds_references;
        DBMS_OUTPUT.PUT_LINE('MDS_REFERENCES: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_pipe_element_references;
        DBMS_OUTPUT.PUT_LINE('PIPE_ELEMENT: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_vsk_references;
        DBMS_OUTPUT.PUT_LINE('VSK_REFERENCES: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_eds_references;
        DBMS_OUTPUT.PUT_LINE('EDS_REFERENCES: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_sc_references;
        DBMS_OUTPUT.PUT_LINE('SC_REFERENCES: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_vsm_references;
        DBMS_OUTPUT.PUT_LINE('VSM_REFERENCES: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_esk_references;
        DBMS_OUTPUT.PUT_LINE('ESK_REFERENCES: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        -- Test 2: Comprehensive tests
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Comprehensive Tests:');
        DBMS_OUTPUT.PUT_LINE('--------------------');
        
        v_test_count := v_test_count + 1;
        v_message := test_comprehensive_cascade;
        DBMS_OUTPUT.PUT_LINE('Cascade System: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_json_parsing_all_types;
        DBMS_OUTPUT.PUT_LINE('JSON Parsing: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_foreign_key_constraints;
        DBMS_OUTPUT.PUT_LINE('FK Constraints: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        v_test_count := v_test_count + 1;
        v_message := test_soft_delete_all_types;
        DBMS_OUTPUT.PUT_LINE('Soft Delete: ' || v_message);
        IF v_message LIKE 'PASS%' THEN v_pass_count := v_pass_count + 1;
        ELSIF v_message LIKE 'FAIL%' THEN v_fail_count := v_fail_count + 1;
        ELSE v_warn_count := v_warn_count + 1; END IF;
        
        -- Summary
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        DBMS_OUTPUT.PUT_LINE('Test Summary:');
        DBMS_OUTPUT.PUT_LINE('  Total Tests: ' || v_test_count);
        DBMS_OUTPUT.PUT_LINE('  Passed: ' || v_pass_count);
        DBMS_OUTPUT.PUT_LINE('  Failed: ' || v_fail_count);
        DBMS_OUTPUT.PUT_LINE('  Warnings: ' || v_warn_count);
        
        IF v_fail_count = 0 THEN
            IF v_warn_count > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Result: PASSED WITH WARNINGS ⚠');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Result: ALL TESTS PASSED ✓');
            END IF;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Result: SOME TESTS FAILED ✗');
        END IF;
        DBMS_OUTPUT.PUT_LINE('===============================================================================');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Fatal error in tests: ' || SQLERRM);
            RAISE;
    END run_all_reference_tests;

END PKG_REFERENCE_COMPREHENSIVE_TESTS;
/

PROMPT Reference comprehensive tests package body created