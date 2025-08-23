-- ===============================================================================
-- Test Script for pkg_api_client API Connectivity and Response Parsing
-- Task 7.9 - Test API connectivity and response parsing
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LINESIZE 200;
SET PAGESIZE 50;

DECLARE
    v_json_response CLOB;
    v_hash VARCHAR2(64);
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
    v_test_plant VARCHAR2(50) := 'ALP';  -- Use a known plant for testing
    v_raw_json_id NUMBER;
    v_test_count NUMBER := 0;
    v_pass_count NUMBER := 0;
    v_fail_count NUMBER := 0;
    
    PROCEDURE print_test(p_test_name VARCHAR2, p_result VARCHAR2, p_details VARCHAR2 DEFAULT NULL) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('========================================');
        DBMS_OUTPUT.PUT_LINE('TEST: ' || p_test_name);
        DBMS_OUTPUT.PUT_LINE('RESULT: ' || p_result);
        IF p_details IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('DETAILS: ' || p_details);
        END IF;
        DBMS_OUTPUT.PUT_LINE('========================================');
    END;
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('API CONNECTIVITY AND RESPONSE PARSING TEST SUITE');
    DBMS_OUTPUT.PUT_LINE('Started at: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'));
    DBMS_OUTPUT.PUT_LINE('================================================================');
    
    -- Test 1: Fetch Plants JSON from API
    BEGIN
        v_test_count := v_test_count + 1;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[TEST 1] Fetching Plants data from API...');
        
        v_json_response := pkg_api_client.fetch_plants_json();
        
        IF v_json_response IS NOT NULL AND LENGTH(v_json_response) > 0 THEN
            print_test('Fetch Plants JSON', 'PASSED', 
                      'Response length: ' || LENGTH(v_json_response) || ' characters');
            v_pass_count := v_pass_count + 1;
            
            -- Show first 500 characters of response
            DBMS_OUTPUT.PUT_LINE('First 500 chars of response:');
            DBMS_OUTPUT.PUT_LINE(SUBSTR(v_json_response, 1, 500));
        ELSE
            print_test('Fetch Plants JSON', 'FAILED', 'Empty or NULL response');
            v_fail_count := v_fail_count + 1;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            print_test('Fetch Plants JSON', 'ERROR', SQLERRM);
            v_fail_count := v_fail_count + 1;
    END;
    
    -- Test 2: Calculate SHA256 Hash
    BEGIN
        v_test_count := v_test_count + 1;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[TEST 2] Testing SHA256 hash calculation...');
        
        IF v_json_response IS NOT NULL THEN
            v_hash := pkg_api_client.calculate_sha256(v_json_response);
            
            IF v_hash IS NOT NULL AND LENGTH(v_hash) = 64 THEN
                print_test('Calculate SHA256', 'PASSED', 
                          'Hash: ' || v_hash);
                v_pass_count := v_pass_count + 1;
            ELSE
                print_test('Calculate SHA256', 'FAILED', 
                          'Invalid hash length: ' || NVL(LENGTH(v_hash), 0));
                v_fail_count := v_fail_count + 1;
            END IF;
        ELSE
            print_test('Calculate SHA256', 'SKIPPED', 'No JSON data to hash');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            print_test('Calculate SHA256', 'ERROR', SQLERRM);
            v_fail_count := v_fail_count + 1;
    END;
    
    -- Test 3: Insert Raw JSON and Check Deduplication
    BEGIN
        v_test_count := v_test_count + 1;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[TEST 3] Testing raw JSON insertion and deduplication...');
        
        IF v_json_response IS NOT NULL AND v_hash IS NOT NULL THEN
            -- First insertion
            v_raw_json_id := pkg_raw_ingest.insert_raw_json(
                p_endpoint_key => 'plants',
                p_plant_id => NULL,
                p_issue_revision => NULL,
                p_api_url => 'plants',
                p_response_json => v_json_response,
                p_response_hash => v_hash
            );
            
            IF v_raw_json_id > 0 THEN
                print_test('Insert Raw JSON', 'PASSED', 
                          'Raw JSON ID: ' || v_raw_json_id);
                v_pass_count := v_pass_count + 1;
                
                -- Test deduplication - try inserting same data again
                DECLARE
                    v_dup_id NUMBER;
                BEGIN
                    v_dup_id := pkg_raw_ingest.insert_raw_json(
                        p_endpoint_key => 'plants',
                        p_plant_id => NULL,
                        p_issue_revision => NULL,
                        p_api_url => 'plants',
                        p_response_json => v_json_response,
                        p_response_hash => v_hash
                    );
                    
                    IF v_dup_id = -1 THEN
                        DBMS_OUTPUT.PUT_LINE('  Deduplication working: Duplicate detected correctly');
                    ELSE
                        DBMS_OUTPUT.PUT_LINE('  WARNING: Deduplication may not be working (got ID: ' || v_dup_id || ')');
                    END IF;
                END;
            ELSE
                print_test('Insert Raw JSON', 'FAILED', 'Failed to insert');
                v_fail_count := v_fail_count + 1;
            END IF;
        ELSE
            print_test('Insert Raw JSON', 'SKIPPED', 'No JSON data to insert');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            print_test('Insert Raw JSON', 'ERROR', SQLERRM);
            v_fail_count := v_fail_count + 1;
    END;
    
    -- Test 4: Parse Plants JSON
    BEGIN
        v_test_count := v_test_count + 1;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[TEST 4] Testing Plants JSON parsing...');
        
        IF v_raw_json_id IS NOT NULL AND v_raw_json_id > 0 THEN
            -- Clear staging first
            pkg_parse_plants.clear_staging();
            
            -- Parse the JSON
            pkg_parse_plants.parse_plants_json(v_raw_json_id);
            
            -- Check if data was parsed
            SELECT COUNT(*) INTO v_test_count FROM STG_PLANTS;
            
            IF v_test_count > 0 THEN
                print_test('Parse Plants JSON', 'PASSED', 
                          'Parsed ' || v_test_count || ' plants into staging');
                v_pass_count := v_pass_count + 1;
                
                -- Show sample data
                FOR rec IN (SELECT plant_id, short_description 
                           FROM STG_PLANTS 
                           WHERE ROWNUM <= 3) LOOP
                    DBMS_OUTPUT.PUT_LINE('  Sample: ' || rec.plant_id || ' - ' || rec.short_description);
                END LOOP;
            ELSE
                print_test('Parse Plants JSON', 'FAILED', 'No data parsed to staging');
                v_fail_count := v_fail_count + 1;
            END IF;
        ELSE
            print_test('Parse Plants JSON', 'SKIPPED', 'No raw JSON to parse');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            print_test('Parse Plants JSON', 'ERROR', SQLERRM);
            v_fail_count := v_fail_count + 1;
    END;
    
    -- Test 5: Fetch Issues JSON for a specific plant
    BEGIN
        v_test_count := v_test_count + 1;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[TEST 5] Fetching Issues data for plant ' || v_test_plant || '...');
        
        v_json_response := pkg_api_client.fetch_issues_json(v_test_plant);
        
        IF v_json_response IS NOT NULL AND LENGTH(v_json_response) > 0 THEN
            print_test('Fetch Issues JSON', 'PASSED', 
                      'Response length: ' || LENGTH(v_json_response) || ' characters');
            v_pass_count := v_pass_count + 1;
            
            -- Calculate hash for issues
            v_hash := pkg_api_client.calculate_sha256(v_json_response);
            
            -- Insert issues JSON
            v_raw_json_id := pkg_raw_ingest.insert_raw_json(
                p_endpoint_key => 'issues',
                p_plant_id => v_test_plant,
                p_issue_revision => NULL,
                p_api_url => 'plants/' || v_test_plant || '/issues',
                p_response_json => v_json_response,
                p_response_hash => v_hash
            );
            
            IF v_raw_json_id > 0 THEN
                DBMS_OUTPUT.PUT_LINE('  Issues JSON inserted with ID: ' || v_raw_json_id);
                
                -- Parse issues
                pkg_parse_issues.clear_staging_for_plant(v_test_plant);
                pkg_parse_issues.parse_issues_json(v_raw_json_id, v_test_plant);
                
                SELECT COUNT(*) INTO v_test_count FROM STG_ISSUES WHERE plant_id = v_test_plant;
                DBMS_OUTPUT.PUT_LINE('  Parsed ' || v_test_count || ' issues for plant ' || v_test_plant);
            END IF;
        ELSE
            print_test('Fetch Issues JSON', 'WARNING', 
                      'Empty response - plant may have no issues or plant ID invalid');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            print_test('Fetch Issues JSON', 'ERROR', SQLERRM);
            v_fail_count := v_fail_count + 1;
    END;
    
    -- Test 6: Complete Plants Refresh Process
    BEGIN
        v_test_count := v_test_count + 1;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[TEST 6] Testing complete Plants refresh from API...');
        
        pkg_api_client.refresh_plants_from_api(v_status, v_message);
        
        IF v_status = 'SUCCESS' THEN
            print_test('Refresh Plants from API', 'PASSED', v_message);
            v_pass_count := v_pass_count + 1;
            
            -- Check final PLANTS table
            SELECT COUNT(*) INTO v_test_count FROM PLANTS WHERE is_valid = 'Y';
            DBMS_OUTPUT.PUT_LINE('  Active plants in PLANTS table: ' || v_test_count);
        ELSE
            print_test('Refresh Plants from API', 'FAILED', 
                      'Status: ' || v_status || ', Message: ' || v_message);
            v_fail_count := v_fail_count + 1;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            print_test('Refresh Plants from API', 'ERROR', SQLERRM);
            v_fail_count := v_fail_count + 1;
    END;
    
    -- Test 7: Complete Issues Refresh Process for a Plant
    BEGIN
        v_test_count := v_test_count + 1;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[TEST 7] Testing complete Issues refresh for plant ' || v_test_plant || '...');
        
        pkg_api_client.refresh_issues_from_api(v_test_plant, v_status, v_message);
        
        IF v_status = 'SUCCESS' THEN
            print_test('Refresh Issues from API', 'PASSED', v_message);
            v_pass_count := v_pass_count + 1;
            
            -- Check final ISSUES table
            SELECT COUNT(*) INTO v_test_count FROM ISSUES WHERE plant_id = v_test_plant AND is_valid = 'Y';
            DBMS_OUTPUT.PUT_LINE('  Active issues for plant ' || v_test_plant || ': ' || v_test_count);
        ELSE
            print_test('Refresh Issues from API', 'WARNING', 
                      'Status: ' || v_status || ', Message: ' || v_message);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            print_test('Refresh Issues from API', 'ERROR', SQLERRM);
            v_fail_count := v_fail_count + 1;
    END;
    
    -- Final Summary
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('TEST SUITE SUMMARY');
    DBMS_OUTPUT.PUT_LINE('================================================================');
    DBMS_OUTPUT.PUT_LINE('Total Tests Run: ' || v_test_count);
    DBMS_OUTPUT.PUT_LINE('Passed: ' || v_pass_count);
    DBMS_OUTPUT.PUT_LINE('Failed: ' || v_fail_count);
    DBMS_OUTPUT.PUT_LINE('Success Rate: ' || 
                        ROUND((v_pass_count / NULLIF(v_test_count, 0)) * 100, 2) || '%');
    DBMS_OUTPUT.PUT_LINE('Completed at: ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3'));
    DBMS_OUTPUT.PUT_LINE('================================================================');
    
    -- Check ETL_ERROR_LOG for any errors during the test
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Recent Error Log Entries (if any):');
    FOR rec IN (SELECT error_timestamp, endpoint_key, error_code, error_message
                FROM ETL_ERROR_LOG
                WHERE error_timestamp > SYSTIMESTAMP - INTERVAL '5' MINUTE
                ORDER BY error_timestamp DESC
                FETCH FIRST 5 ROWS ONLY) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || rec.error_timestamp || ' - ' || 
                            rec.endpoint_key || ': ' || rec.error_message);
    END LOOP;
    
    COMMIT;
END;
/