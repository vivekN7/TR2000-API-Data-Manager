-- ===============================================================================
-- Incremental Update: Task 7.5 - Extend PKG_API_CLIENT for Reference Types
-- Date: 2025-08-26
-- ===============================================================================
-- This script extends pkg_api_client with fetch_issue_references procedure
-- to support fetching all 9 reference types dynamically
-- ===============================================================================

SET SERVEROUTPUT ON

PROMPT ===============================================================================
PROMPT Extending PKG_API_CLIENT with Reference Support (Task 7.5)
PROMPT ===============================================================================

-- First, update the package specification to add new procedures
CREATE OR REPLACE PACKAGE pkg_api_client AS
    -- Existing functions remain for compatibility
    FUNCTION fetch_plants_json RETURN CLOB;
    FUNCTION fetch_issues_json(p_plant_id VARCHAR2) RETURN CLOB;
    FUNCTION calculate_sha256(p_input CLOB) RETURN VARCHAR2;
    
    -- Enhanced functions with GUID support
    FUNCTION fetch_plants_json_v2(
        p_correlation_id  VARCHAR2 DEFAULT NULL,
        p_idempotency_key VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;
    
    FUNCTION fetch_issues_json_v2(
        p_plant_id        VARCHAR2,
        p_correlation_id  VARCHAR2 DEFAULT NULL,
        p_idempotency_key VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;
    
    -- NEW: Functions for reference types
    FUNCTION fetch_reference_json(
        p_plant_id       VARCHAR2,
        p_issue_rev      VARCHAR2,
        p_reference_type VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;
    
    -- Main procedures - enhanced with optional GUID parameters
    PROCEDURE refresh_plants_from_api(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL,
        p_idempotency_key IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE refresh_issues_from_api(
        p_plant_id        IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL,
        p_idempotency_key IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE refresh_selected_issues(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );
    
    -- NEW: Procedure to fetch references for an issue
    PROCEDURE refresh_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_reference_type  IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );
    
    -- NEW: Procedure to fetch ALL reference types for an issue
    PROCEDURE refresh_all_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );
    
    -- Helper function
    FUNCTION get_base_url RETURN VARCHAR2;
    
END pkg_api_client;
/

-- Now update the package body to add the new procedures
-- We'll need to get the existing body first and extend it
-- For this incremental update, we'll add just the new procedures

DECLARE
    v_body_additions CLOB := '
    -- =========================================================================
    -- NEW: Fetch reference JSON for a specific type
    -- =========================================================================
    FUNCTION fetch_reference_json(
        p_plant_id       VARCHAR2,
        p_issue_rev      VARCHAR2,
        p_reference_type VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        v_url           VARCHAR2(1000);
        v_response      CLOB;
        v_base_url      VARCHAR2(500);
        v_endpoint_path VARCHAR2(500);
        v_correlation   VARCHAR2(36);
    BEGIN
        -- Use provided correlation ID or generate new one
        v_correlation := NVL(p_correlation_id, LOWER(RAWTOHEX(SYS_GUID())));
        
        -- Get base URL
        v_base_url := get_base_url();
        
        -- Get endpoint path from CONTROL_ENDPOINTS
        SELECT endpoint_url INTO v_endpoint_path
        FROM CONTROL_ENDPOINTS
        WHERE UPPER(endpoint_key) = UPPER(p_reference_type || ''_references'')
          AND is_active = ''Y'';
        
        -- Replace placeholders in URL
        v_endpoint_path := REPLACE(v_endpoint_path, ''{plantid}'', p_plant_id);
        v_endpoint_path := REPLACE(v_endpoint_path, ''{issuerev}'', p_issue_rev);
        
        v_url := v_base_url || v_endpoint_path;
        
        DBMS_OUTPUT.PUT_LINE(''Fetching '' || p_reference_type || '' references from: '' || v_url);
        DBMS_OUTPUT.PUT_LINE(''Correlation ID: '' || v_correlation);
        
        -- Make API call
        apex_web_service.g_request_headers.DELETE();
        apex_web_service.g_request_headers(1).name := ''X-Correlation-Id'';
        apex_web_service.g_request_headers(1).value := v_correlation;
        
        v_response := apex_web_service.make_rest_request(
            p_url         => v_url,
            p_http_method => ''GET'',
            p_wallet_path => ''file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet'',
            p_wallet_pwd  => ''WalletPass123''
        );
        
        IF apex_web_service.g_status_code != 200 THEN
            RAISE_APPLICATION_ERROR(-20501, 
                ''API Error for '' || p_reference_type || '': HTTP '' || 
                apex_web_service.g_status_code);
        END IF;
        
        RETURN v_response;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20502, 
                ''Unknown reference type: '' || p_reference_type);
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20503, 
                ''Error fetching '' || p_reference_type || '' references: '' || SQLERRM);
    END fetch_reference_json;
    
    -- =========================================================================
    -- NEW: Refresh references for a specific issue and type
    -- =========================================================================
    PROCEDURE refresh_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_reference_type  IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    ) IS
        v_json_response  CLOB;
        v_sha256_hash    VARCHAR2(64);
        v_raw_json_id    NUMBER;
        v_correlation    VARCHAR2(36);
        v_run_id         NUMBER;
        v_record_count   NUMBER := 0;
    BEGIN
        -- Use provided correlation ID or generate new one
        v_correlation := NVL(p_correlation_id, LOWER(RAWTOHEX(SYS_GUID())));
        
        -- Log ETL run start
        INSERT INTO ETL_RUN_LOG (
            run_type, endpoint_key, plant_id, status, started_at
        ) VALUES (
            ''REFERENCE_REFRESH'', 
            p_reference_type || ''_references'',
            p_plant_id, 
            ''RUNNING'', 
            SYSTIMESTAMP
        ) RETURNING run_id INTO v_run_id;
        
        BEGIN
            -- Fetch JSON from API
            v_json_response := fetch_reference_json(
                p_plant_id, 
                p_issue_rev, 
                p_reference_type,
                v_correlation
            );
            
            -- Calculate hash for deduplication
            v_sha256_hash := calculate_sha256(v_json_response);
            
            -- Check for duplicate
            IF NOT pkg_raw_ingest.is_duplicate_hash(v_sha256_hash) THEN
                -- Insert into RAW_JSON
                v_raw_json_id := pkg_raw_ingest.insert_raw_json(
                    p_response_json => v_json_response,
                    p_endpoint_key  => p_reference_type || ''_references'',
                    p_sha256_hash   => v_sha256_hash,
                    p_plant         => p_plant_id,
                    p_issue_rev     => p_issue_rev
                );
                
                -- Parse JSON to staging using generic parser
                pkg_parse_references.parse_reference_json(
                    p_reference_type => p_reference_type,
                    p_raw_json_id    => v_raw_json_id,
                    p_plant_id       => p_plant_id,
                    p_issue_rev      => p_issue_rev
                );
                
                -- Upsert from staging to core
                pkg_upsert_references.upsert_references(
                    p_reference_type => p_reference_type,
                    p_plant_id       => p_plant_id,
                    p_issue_rev      => p_issue_rev
                );
                
                -- Count records loaded
                EXECUTE IMMEDIATE 
                    ''SELECT COUNT(*) FROM '' || UPPER(p_reference_type) || 
                    ''_REFERENCES WHERE plant_id = :1 AND issue_revision = :2 AND is_valid = ''''Y''''''
                INTO v_record_count USING p_plant_id, p_issue_rev;
                
                p_status := ''SUCCESS'';
                p_message := ''Loaded '' || v_record_count || '' '' || 
                            p_reference_type || '' references for issue '' || 
                            p_issue_rev;
            ELSE
                p_status := ''SKIPPED'';
                p_message := ''Data unchanged for '' || p_reference_type || 
                            '' references (duplicate hash)'';
            END IF;
            
            -- Update ETL run log
            UPDATE ETL_RUN_LOG 
            SET status = p_status,
                ended_at = SYSTIMESTAMP,
                records_processed = v_record_count,
                message = p_message
            WHERE run_id = v_run_id;
            
            COMMIT;
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Log error
                INSERT INTO ETL_ERROR_LOG (
                    run_id, error_timestamp, error_message, 
                    error_stack, endpoint_key, plant_id
                ) VALUES (
                    v_run_id, SYSTIMESTAMP, SQLERRM, 
                    DBMS_UTILITY.FORMAT_ERROR_STACK || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
                    p_reference_type || ''_references'', p_plant_id
                );
                
                -- Update run log
                UPDATE ETL_RUN_LOG 
                SET status = ''FAILED'',
                    ended_at = SYSTIMESTAMP,
                    message = ''Error: '' || SQLERRM
                WHERE run_id = v_run_id;
                
                COMMIT;
                
                p_status := ''ERROR'';
                p_message := ''Error loading '' || p_reference_type || 
                            '' references: '' || SQLERRM;
                RAISE;
        END;
    END refresh_issue_references;
    
    -- =========================================================================
    -- NEW: Refresh ALL reference types for an issue
    -- =========================================================================
    PROCEDURE refresh_all_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    ) IS
        v_correlation    VARCHAR2(36);
        v_status         VARCHAR2(20);
        v_message        VARCHAR2(4000);
        v_success_count  NUMBER := 0;
        v_error_count    NUMBER := 0;
        v_messages       VARCHAR2(4000);
        
        -- Cursor for all reference types
        CURSOR c_reference_types IS
            SELECT REPLACE(endpoint_key, ''_references'', '''') AS reference_type
            FROM CONTROL_ENDPOINTS
            WHERE endpoint_type = ''REFERENCE''
              AND is_active = ''Y''
            ORDER BY processing_order;
    BEGIN
        -- Use provided correlation ID or generate new one
        v_correlation := NVL(p_correlation_id, LOWER(RAWTOHEX(SYS_GUID())));
        
        DBMS_OUTPUT.PUT_LINE(''Processing all reference types for issue '' || 
                            p_plant_id || ''/'' || p_issue_rev);
        DBMS_OUTPUT.PUT_LINE(''Correlation ID: '' || v_correlation);
        
        -- Process each reference type
        FOR rec IN c_reference_types LOOP
            BEGIN
                refresh_issue_references(
                    p_plant_id       => p_plant_id,
                    p_issue_rev      => p_issue_rev,
                    p_reference_type => rec.reference_type,
                    p_status         => v_status,
                    p_message        => v_message,
                    p_correlation_id => v_correlation
                );
                
                IF v_status IN (''SUCCESS'', ''SKIPPED'') THEN
                    v_success_count := v_success_count + 1;
                ELSE
                    v_error_count := v_error_count + 1;
                END IF;
                
                -- Build message summary
                v_messages := v_messages || rec.reference_type || '': '' || 
                             v_status || ''; '';
                             
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;
                    v_messages := v_messages || rec.reference_type || 
                                '': ERROR - '' || SQLERRM || ''; '';
            END;
        END LOOP;
        
        -- Set overall status
        IF v_error_count = 0 THEN
            p_status := ''SUCCESS'';
            p_message := ''All '' || v_success_count || 
                        '' reference types processed successfully. '' || v_messages;
        ELSIF v_success_count > 0 THEN
            p_status := ''PARTIAL'';
            p_message := v_success_count || '' succeeded, '' || v_error_count || 
                        '' failed. '' || v_messages;
        ELSE
            p_status := ''FAILED'';
            p_message := ''All reference types failed. '' || v_messages;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE(''Overall status: '' || p_status);
        DBMS_OUTPUT.PUT_LINE(p_message);
        
    END refresh_all_issue_references;';
    
BEGIN
    DBMS_OUTPUT.PUT_LINE('Note: Package body extension requires manual merge.');
    DBMS_OUTPUT.PUT_LINE('The new procedures have been prepared but need to be added to the existing package body.');
    DBMS_OUTPUT.PUT_LINE('Please run the full package recreation script.');
END;
/

PROMPT
PROMPT ===============================================================================
PROMPT IMPORTANT: Package specification updated, but body needs manual merge
PROMPT The new procedures need to be added to the existing pkg_api_client body
PROMPT Creating a complete replacement script...
PROMPT ===============================================================================

-- Let's create a script that will properly extend the package
-- Since we can't easily append to the existing body, we'll create a new file
-- with the complete extended package

PROMPT
PROMPT Task 7.5 partially complete. 
PROMPT New procedures defined in specification.
PROMPT Run the extended package body script to complete the implementation.
PROMPT ===============================================================================