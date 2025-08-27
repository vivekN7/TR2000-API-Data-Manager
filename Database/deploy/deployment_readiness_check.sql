-- ===============================================================================
-- Deployment Readiness Check Script
-- Date: 2025-08-27
-- Purpose: Verify system is ready for production deployment
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100

DECLARE
    v_check_count NUMBER := 0;
    v_pass_count NUMBER := 0;
    v_fail_count NUMBER := 0;
    v_warn_count NUMBER := 0;
    
    PROCEDURE check_item(p_name VARCHAR2, p_status VARCHAR2, p_message VARCHAR2 DEFAULT NULL) IS
    BEGIN
        v_check_count := v_check_count + 1;
        IF p_status = 'PASS' THEN
            DBMS_OUTPUT.PUT_LINE('✓ ' || p_name);
            v_pass_count := v_pass_count + 1;
        ELSIF p_status = 'FAIL' THEN
            DBMS_OUTPUT.PUT_LINE('✗ ' || p_name || ' - ' || NVL(p_message, 'Failed'));
            v_fail_count := v_fail_count + 1;
        ELSIF p_status = 'WARN' THEN
            DBMS_OUTPUT.PUT_LINE('⚠ ' || p_name || ' - ' || NVL(p_message, 'Warning'));
            v_warn_count := v_warn_count + 1;
        END IF;
    END check_item;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================================================');
    DBMS_OUTPUT.PUT_LINE('TR2000 ETL System - Deployment Readiness Check');
    DBMS_OUTPUT.PUT_LINE('Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('===============================================================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- 1. Check for invalid objects
    DBMS_OUTPUT.PUT_LINE('1. DATABASE OBJECTS');
    DBMS_OUTPUT.PUT_LINE('-------------------');
    DECLARE
        v_invalid_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_invalid_count FROM user_objects WHERE status = 'INVALID';
        IF v_invalid_count = 0 THEN
            check_item('All objects are valid', 'PASS');
        ELSE
            check_item('Invalid objects found', 'FAIL', v_invalid_count || ' invalid objects');
        END IF;
    END;
    
    -- 2. Check TR2000_UTIL proxy
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('2. TR2000_UTIL PROXY SETUP');
    DBMS_OUTPUT.PUT_LINE('---------------------------');
    DECLARE
        v_count NUMBER;
    BEGIN
        -- Check if TR2000_UTIL exists
        SELECT COUNT(*) INTO v_count 
        FROM all_objects 
        WHERE owner = 'SYSTEM' 
        AND object_name = 'TR2000_UTIL'
        AND object_type = 'PACKAGE';
        
        IF v_count > 0 THEN
            check_item('TR2000_UTIL package exists in SYSTEM', 'PASS');
        ELSE
            check_item('TR2000_UTIL package missing', 'FAIL');
        END IF;
        
        -- Check execute grant
        SELECT COUNT(*) INTO v_count
        FROM user_tab_privs
        WHERE table_name = 'TR2000_UTIL'
        AND privilege = 'EXECUTE';
        
        IF v_count > 0 THEN
            check_item('Execute grant on TR2000_UTIL', 'PASS');
        ELSE
            check_item('Execute grant on TR2000_UTIL missing', 'FAIL');
        END IF;
        
        -- Check wrapper function
        SELECT COUNT(*) INTO v_count
        FROM user_objects
        WHERE object_name = 'MAKE_API_REQUEST_UTIL'
        AND object_type = 'FUNCTION'
        AND status = 'VALID';
        
        IF v_count > 0 THEN
            check_item('make_api_request_util wrapper function', 'PASS');
        ELSE
            check_item('make_api_request_util wrapper missing', 'FAIL');
        END IF;
    END;
    
    -- 3. Check tables and data
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('3. CORE TABLES');
    DBMS_OUTPUT.PUT_LINE('---------------');
    DECLARE
        v_count NUMBER;
    BEGIN
        -- Check ETL_LOG
        SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name = 'ETL_LOG';
        IF v_count > 0 THEN
            check_item('ETL_LOG table exists', 'PASS');
        ELSE
            check_item('ETL_LOG table missing', 'FAIL');
        END IF;
        
        -- Check RAW_JSON with new columns
        SELECT COUNT(*) INTO v_count 
        FROM user_tab_columns 
        WHERE table_name = 'RAW_JSON' 
        AND column_name IN ('ENDPOINT', 'PAYLOAD', 'KEY_FINGERPRINT', 'BATCH_ID');
        
        IF v_count = 4 THEN
            check_item('RAW_JSON has updated columns', 'PASS');
        ELSE
            check_item('RAW_JSON missing updated columns', 'FAIL', 'Found ' || v_count || ' of 4 columns');
        END IF;
        
        -- Check selection tables
        SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name = 'SELECTED_PLANTS';
        IF v_count > 0 THEN
            check_item('SELECTED_PLANTS table exists', 'PASS');
        ELSE
            check_item('SELECTED_PLANTS table missing', 'FAIL');
        END IF;
        
        SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name = 'SELECTED_ISSUES';
        IF v_count > 0 THEN
            check_item('SELECTED_ISSUES table exists', 'PASS');
        ELSE
            check_item('SELECTED_ISSUES table missing', 'FAIL');
        END IF;
    END;
    
    -- 4. Check API configuration
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('4. API CONFIGURATION');
    DBMS_OUTPUT.PUT_LINE('---------------------');
    DECLARE
        v_url VARCHAR2(500);
    BEGIN
        SELECT setting_value INTO v_url 
        FROM CONTROL_SETTINGS 
        WHERE setting_key = 'API_BASE_URL';
        
        check_item('API_BASE_URL configured', 'PASS', v_url);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            check_item('API_BASE_URL not configured', 'WARN', 'Using default');
    END;
    
    -- 5. Check APEX credential (warning only)
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('5. APEX CREDENTIAL');
    DBMS_OUTPUT.PUT_LINE('------------------');
    check_item('TR2000_CRED credential', 'WARN', 'Must be created in APEX workspace for production');
    
    -- 6. Test API connectivity
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('6. API CONNECTIVITY TEST');
    DBMS_OUTPUT.PUT_LINE('-------------------------');
    DECLARE
        v_response CLOB;
    BEGIN
        v_response := make_api_request_util(
            'https://equinor.pipespec-api.presight.com/plants',
            'GET'
        );
        
        IF LENGTH(v_response) > 0 THEN
            check_item('API connectivity test', 'PASS', 'Response: ' || LENGTH(v_response) || ' chars');
        ELSE
            check_item('API connectivity test', 'FAIL', 'No response');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            check_item('API connectivity test', 'FAIL', SQLERRM);
    END;
    
    -- 7. Check for performance indexes
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('7. PERFORMANCE OPTIMIZATION');
    DBMS_OUTPUT.PUT_LINE('----------------------------');
    DECLARE
        v_count NUMBER;
    BEGIN
        -- Check critical indexes
        SELECT COUNT(*) INTO v_count
        FROM user_indexes
        WHERE table_name = 'RAW_JSON'
        AND index_name LIKE 'IDX_RAW_JSON%';
        
        IF v_count >= 2 THEN
            check_item('RAW_JSON indexes', 'PASS', v_count || ' indexes found');
        ELSE
            check_item('RAW_JSON indexes', 'WARN', 'Only ' || v_count || ' indexes');
        END IF;
        
        -- Check ETL_LOG indexes
        SELECT COUNT(*) INTO v_count
        FROM user_indexes
        WHERE table_name = 'ETL_LOG';
        
        IF v_count >= 2 THEN
            check_item('ETL_LOG indexes', 'PASS', v_count || ' indexes found');
        ELSE
            check_item('ETL_LOG indexes', 'WARN', 'Only ' || v_count || ' indexes');
        END IF;
    END;
    
    -- 8. Data statistics
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('8. DATA STATISTICS');
    DBMS_OUTPUT.PUT_LINE('------------------');
    DECLARE
        v_plants NUMBER;
        v_issues NUMBER;
        v_refs NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_plants FROM PLANTS WHERE is_valid = 'Y';
        SELECT COUNT(*) INTO v_issues FROM ISSUES WHERE is_valid = 'Y';
        SELECT COUNT(*) INTO v_refs FROM PCS_REFERENCES;
        
        DBMS_OUTPUT.PUT_LINE('  Active Plants: ' || v_plants);
        DBMS_OUTPUT.PUT_LINE('  Active Issues: ' || v_issues);
        DBMS_OUTPUT.PUT_LINE('  PCS References: ' || v_refs);
    END;
    
    -- Final Summary
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================================================');
    DBMS_OUTPUT.PUT_LINE('DEPLOYMENT READINESS SUMMARY');
    DBMS_OUTPUT.PUT_LINE('===============================================================================');
    DBMS_OUTPUT.PUT_LINE('Total Checks: ' || v_check_count);
    DBMS_OUTPUT.PUT_LINE('  Passed: ' || v_pass_count);
    DBMS_OUTPUT.PUT_LINE('  Failed: ' || v_fail_count);
    DBMS_OUTPUT.PUT_LINE('  Warnings: ' || v_warn_count);
    DBMS_OUTPUT.PUT_LINE('');
    
    IF v_fail_count = 0 THEN
        IF v_warn_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('STATUS: READY FOR DEPLOYMENT ✓');
        ELSE
            DBMS_OUTPUT.PUT_LINE('STATUS: READY WITH WARNINGS ⚠');
            DBMS_OUTPUT.PUT_LINE('Note: Address warnings before production deployment');
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('STATUS: NOT READY FOR DEPLOYMENT ✗');
        DBMS_OUTPUT.PUT_LINE('Critical issues must be resolved first');
    END IF;
    DBMS_OUTPUT.PUT_LINE('===============================================================================');
    
END;
/

EXIT;