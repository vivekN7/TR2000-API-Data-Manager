-- ===============================================================================
-- Refactoring Script: Simplify Oracle Architecture for APEX
-- Date: 2025-08-23
-- Purpose: Add missing procedures and optimize for pure APEX architecture
-- ===============================================================================

-- First, switch to TR2000_STAGING schema
ALTER SESSION SET CURRENT_SCHEMA = TR2000_STAGING;

-- ===============================================================================
-- 1. Add pr_purge_raw_json procedure (Task 3.8)
-- ===============================================================================
CREATE OR REPLACE PROCEDURE pr_purge_raw_json(
    p_retention_days NUMBER DEFAULT 30,
    p_dry_run BOOLEAN DEFAULT TRUE,
    p_deleted_count OUT NUMBER
) AS
    v_cutoff_date DATE;
BEGIN
    v_cutoff_date := SYSDATE - p_retention_days;
    
    IF p_dry_run THEN
        -- Count only, don't delete
        SELECT COUNT(*) INTO p_deleted_count
        FROM RAW_JSON
        WHERE created_date < v_cutoff_date;
        
        DBMS_OUTPUT.PUT_LINE('DRY RUN: Would delete ' || p_deleted_count || ' records older than ' || v_cutoff_date);
    ELSE
        -- Actually delete
        DELETE FROM RAW_JSON
        WHERE created_date < v_cutoff_date;
        
        p_deleted_count := SQL%ROWCOUNT;
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('DELETED: ' || p_deleted_count || ' records older than ' || v_cutoff_date);
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, 'Error purging RAW_JSON: ' || SQLERRM);
END pr_purge_raw_json;
/

-- ===============================================================================
-- 2. Make pkg_etl_operations dynamic (Task 3.10)
-- ===============================================================================
CREATE OR REPLACE PACKAGE BODY pkg_etl_operations AS
    
    -- Run ETL for plants endpoint
    PROCEDURE run_plants_etl(
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_run_id NUMBER;
        v_start_time TIMESTAMP;
        v_raw_json_count NUMBER;
        v_parsed_count NUMBER;
        v_merged_count NUMBER;
        v_endpoint_config CONTROL_ENDPOINTS%ROWTYPE;
    BEGIN
        -- Get endpoint configuration dynamically
        SELECT * INTO v_endpoint_config
        FROM CONTROL_ENDPOINTS
        WHERE endpoint_key = 'plants' AND is_active = 'Y';
        
        v_start_time := SYSTIMESTAMP;
        
        -- Create ETL run log entry
        INSERT INTO ETL_RUN_LOG (run_type, endpoint_key, start_time, status, initiated_by)
        VALUES ('PLANTS_ETL', 'plants', v_start_time, 'RUNNING', USER)
        RETURNING run_id INTO v_run_id;
        
        BEGIN
            -- Step 1: Identify unprocessed raw JSON records
            SELECT COUNT(*) INTO v_raw_json_count
            FROM RAW_JSON r
            WHERE r.endpoint_key = 'plants'
            AND NOT EXISTS (
                SELECT 1 FROM STG_PLANTS s 
                WHERE s.raw_json_id = r.raw_json_id
            );
            
            IF v_raw_json_count = 0 THEN
                UPDATE ETL_RUN_LOG 
                SET end_time = SYSTIMESTAMP,
                    status = 'SUCCESS',
                    notes = 'No new data to process',
                    duration_seconds = 0
                WHERE run_id = v_run_id;
                
                p_status := 'SUCCESS';
                p_message := 'No new plants data to process';
                COMMIT;
                RETURN;
            END IF;
            
            -- Step 2: Parse JSON to staging dynamically using stored procedure name
            IF v_endpoint_config.parse_procedure IS NOT NULL THEN
                EXECUTE IMMEDIATE 'BEGIN ' || v_endpoint_config.parse_procedure || '(:1, :2); END;'
                    USING OUT v_parsed_count, OUT p_message;
            ELSE
                -- Fallback to hardcoded procedure
                pkg_parse_plants.parse_plants_json(v_parsed_count, p_message);
            END IF;
            
            IF p_message != 'SUCCESS' THEN
                RAISE_APPLICATION_ERROR(-20001, 'Parse failed: ' || p_message);
            END IF;
            
            -- Step 3: Upsert to core table dynamically
            IF v_endpoint_config.upsert_procedure IS NOT NULL THEN
                EXECUTE IMMEDIATE 'BEGIN ' || v_endpoint_config.upsert_procedure || '(:1, :2); END;'
                    USING OUT v_merged_count, OUT p_message;
            ELSE
                -- Fallback to hardcoded procedure
                pkg_upsert_plants.upsert_plants(v_merged_count, p_message);
            END IF;
            
            IF p_message != 'SUCCESS' THEN
                RAISE_APPLICATION_ERROR(-20002, 'Upsert failed: ' || p_message);
            END IF;
            
            -- Update ETL run log
            UPDATE ETL_RUN_LOG 
            SET end_time = SYSTIMESTAMP,
                status = 'SUCCESS',
                records_processed = v_parsed_count,
                records_inserted = v_merged_count,
                duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400),
                notes = 'Parsed: ' || v_parsed_count || ', Merged: ' || v_merged_count
            WHERE run_id = v_run_id;
            
            p_status := 'SUCCESS';
            p_message := 'Plants ETL completed. Parsed: ' || v_parsed_count || ', Merged: ' || v_merged_count;
            
            COMMIT;
            
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                
                -- Log error
                INSERT INTO ETL_ERROR_LOG (
                    run_id, endpoint_key, error_code, error_message, 
                    error_timestamp, error_context
                )
                VALUES (
                    v_run_id, 'plants', SQLCODE, SQLERRM,
                    SYSTIMESTAMP, 'run_plants_etl'
                );
                
                -- Update run log
                UPDATE ETL_RUN_LOG 
                SET end_time = SYSTIMESTAMP,
                    status = 'FAILED',
                    error_message = SUBSTR(SQLERRM, 1, 4000),
                    duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                WHERE run_id = v_run_id;
                
                COMMIT;
                
                p_status := 'FAILED';
                p_message := 'Plants ETL failed: ' || SQLERRM;
                RAISE;
        END;
    END run_plants_etl;
    
    -- Similar updates for run_issues_etl_for_plant (make it dynamic)
    PROCEDURE run_issues_etl_for_plant(
        p_plant_id VARCHAR2,
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_run_id NUMBER;
        v_start_time TIMESTAMP;
        v_raw_json_count NUMBER;
        v_parsed_count NUMBER;
        v_merged_count NUMBER;
        v_endpoint_config CONTROL_ENDPOINTS%ROWTYPE;
    BEGIN
        -- Get endpoint configuration dynamically
        SELECT * INTO v_endpoint_config
        FROM CONTROL_ENDPOINTS
        WHERE endpoint_key = 'issues' AND is_active = 'Y';
        
        v_start_time := SYSTIMESTAMP;
        
        -- Create ETL run log entry
        INSERT INTO ETL_RUN_LOG (
            run_type, endpoint_key, plant_id, start_time, 
            status, initiated_by
        )
        VALUES (
            'ISSUES_ETL', 'issues', p_plant_id, v_start_time, 
            'RUNNING', USER
        )
        RETURNING run_id INTO v_run_id;
        
        BEGIN
            -- Check for unprocessed raw JSON
            SELECT COUNT(*) INTO v_raw_json_count
            FROM RAW_JSON r
            WHERE r.endpoint_key = 'issues'
            AND r.plant_id = p_plant_id
            AND NOT EXISTS (
                SELECT 1 FROM STG_ISSUES s 
                WHERE s.raw_json_id = r.raw_json_id
            );
            
            IF v_raw_json_count = 0 THEN
                UPDATE ETL_RUN_LOG 
                SET end_time = SYSTIMESTAMP,
                    status = 'SUCCESS',
                    notes = 'No new data to process for plant ' || p_plant_id,
                    duration_seconds = 0
                WHERE run_id = v_run_id;
                
                p_status := 'SUCCESS';
                p_message := 'No new issues data to process for plant ' || p_plant_id;
                COMMIT;
                RETURN;
            END IF;
            
            -- Parse JSON dynamically
            IF v_endpoint_config.parse_procedure IS NOT NULL THEN
                EXECUTE IMMEDIATE 'BEGIN ' || v_endpoint_config.parse_procedure || '(:1, :2, :3); END;'
                    USING p_plant_id, OUT v_parsed_count, OUT p_message;
            ELSE
                pkg_parse_issues.parse_issues_json(p_plant_id, v_parsed_count, p_message);
            END IF;
            
            IF p_message != 'SUCCESS' THEN
                RAISE_APPLICATION_ERROR(-20001, 'Parse failed: ' || p_message);
            END IF;
            
            -- Upsert dynamically
            IF v_endpoint_config.upsert_procedure IS NOT NULL THEN
                EXECUTE IMMEDIATE 'BEGIN ' || v_endpoint_config.upsert_procedure || '(:1, :2, :3); END;'
                    USING p_plant_id, OUT v_merged_count, OUT p_message;
            ELSE
                pkg_upsert_issues.upsert_issues(p_plant_id, v_merged_count, p_message);
            END IF;
            
            IF p_message != 'SUCCESS' THEN
                RAISE_APPLICATION_ERROR(-20002, 'Upsert failed: ' || p_message);
            END IF;
            
            -- Update ETL run log
            UPDATE ETL_RUN_LOG 
            SET end_time = SYSTIMESTAMP,
                status = 'SUCCESS',
                records_processed = v_parsed_count,
                records_inserted = v_merged_count,
                duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400),
                notes = 'Plant: ' || p_plant_id || ', Parsed: ' || v_parsed_count || ', Merged: ' || v_merged_count
            WHERE run_id = v_run_id;
            
            p_status := 'SUCCESS';
            p_message := 'Issues ETL completed for ' || p_plant_id || '. Parsed: ' || v_parsed_count || ', Merged: ' || v_merged_count;
            
            COMMIT;
            
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                
                -- Log error
                INSERT INTO ETL_ERROR_LOG (
                    run_id, endpoint_key, plant_id, error_code, 
                    error_message, error_timestamp, error_context
                )
                VALUES (
                    v_run_id, 'issues', p_plant_id, SQLCODE, 
                    SQLERRM, SYSTIMESTAMP, 'run_issues_etl_for_plant'
                );
                
                -- Update run log
                UPDATE ETL_RUN_LOG 
                SET end_time = SYSTIMESTAMP,
                    status = 'FAILED',
                    error_message = SUBSTR(SQLERRM, 1, 4000),
                    duration_seconds = ROUND((CAST(SYSTIMESTAMP AS DATE) - CAST(v_start_time AS DATE)) * 86400)
                WHERE run_id = v_run_id;
                
                COMMIT;
                
                p_status := 'FAILED';
                p_message := 'Issues ETL failed for ' || p_plant_id || ': ' || SQLERRM;
                RAISE;
        END;
    END run_issues_etl_for_plant;
    
    -- Run full ETL for all selected plants
    PROCEDURE run_full_etl(
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        v_plant_status VARCHAR2(50);
        v_plant_message VARCHAR2(4000);
        v_issue_status VARCHAR2(50);
        v_issue_message VARCHAR2(4000);
        v_error_count NUMBER := 0;
    BEGIN
        -- Run Plants ETL
        run_plants_etl(v_plant_status, v_plant_message);
        
        IF v_plant_status != 'SUCCESS' THEN
            v_error_count := v_error_count + 1;
        END IF;
        
        -- Run Issues ETL for each active plant in selection
        FOR plant_rec IN (
            SELECT DISTINCT plant_id 
            FROM SELECTION_LOADER 
            WHERE is_active = 'Y'
        ) LOOP
            run_issues_etl_for_plant(plant_rec.plant_id, v_issue_status, v_issue_message);
            
            IF v_issue_status != 'SUCCESS' THEN
                v_error_count := v_error_count + 1;
            END IF;
        END LOOP;
        
        IF v_error_count = 0 THEN
            p_status := 'SUCCESS';
            p_message := 'Full ETL completed successfully';
        ELSE
            p_status := 'PARTIAL';
            p_message := 'ETL completed with ' || v_error_count || ' errors';
        END IF;
    END run_full_etl;
    
END pkg_etl_operations;
/

-- ===============================================================================
-- 3. Add APEX-specific helper procedures
-- ===============================================================================

-- Procedure to be called from APEX processes
CREATE OR REPLACE PROCEDURE pr_apex_refresh_plants AS
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
BEGIN
    pkg_api_client.refresh_plants_from_api(v_status, v_message);
    
    IF v_status != 'SUCCESS' THEN
        RAISE_APPLICATION_ERROR(-20001, v_message);
    END IF;
END pr_apex_refresh_plants;
/

-- Procedure to refresh issues for selected plants
CREATE OR REPLACE PROCEDURE pr_apex_refresh_selected_issues AS
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
    v_error_count NUMBER := 0;
BEGIN
    FOR plant_rec IN (
        SELECT DISTINCT plant_id 
        FROM SELECTION_LOADER 
        WHERE is_active = 'Y'
    ) LOOP
        pkg_api_client.refresh_issues_from_api(
            plant_rec.plant_id, 
            v_status, 
            v_message
        );
        
        IF v_status != 'SUCCESS' THEN
            v_error_count := v_error_count + 1;
        END IF;
    END LOOP;
    
    IF v_error_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 
            'Failed to refresh issues for ' || v_error_count || ' plants');
    END IF;
END pr_apex_refresh_selected_issues;
/

-- Procedure to run complete ETL pipeline
CREATE OR REPLACE PROCEDURE pr_apex_run_full_etl AS
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
BEGIN
    -- First refresh from API
    pr_apex_refresh_plants;
    pr_apex_refresh_selected_issues;
    
    -- Then run ETL processing
    pkg_etl_operations.run_full_etl(v_status, v_message);
    
    IF v_status = 'FAILED' THEN
        RAISE_APPLICATION_ERROR(-20003, v_message);
    END IF;
END pr_apex_run_full_etl;
/

-- ===============================================================================
-- 4. Create APEX views for simplified reporting
-- ===============================================================================

-- View for plant selection with statistics
CREATE OR REPLACE VIEW v_apex_plant_selection AS
SELECT 
    sl.plant_id,
    p.plant_name,
    p.operator_name,
    sl.is_active,
    (SELECT COUNT(*) FROM ISSUES i WHERE i.plant_id = sl.plant_id AND i.is_valid = 'Y') as issue_count,
    sl.last_updated
FROM SELECTION_LOADER sl
LEFT JOIN PLANTS p ON sl.plant_id = p.plant_id
ORDER BY sl.plant_id;

-- View for ETL run history
CREATE OR REPLACE VIEW v_apex_etl_history AS
SELECT 
    run_id,
    run_type,
    endpoint_key,
    plant_id,
    start_time,
    end_time,
    duration_seconds,
    status,
    records_processed,
    records_inserted,
    error_message,
    initiated_by
FROM ETL_RUN_LOG
ORDER BY start_time DESC;

-- View for current ETL status
CREATE OR REPLACE VIEW v_apex_etl_status AS
SELECT 
    endpoint_key,
    COUNT(DISTINCT plant_id) as plants_configured,
    MAX(last_sync_timestamp) as last_sync,
    SUM(CASE WHEN sync_status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_syncs,
    SUM(CASE WHEN sync_status = 'FAILED' THEN 1 ELSE 0 END) as failed_syncs
FROM CONTROL_ENDPOINT_STATE
GROUP BY endpoint_key;

-- ===============================================================================
-- 5. Create DBMS_SCHEDULER jobs for automation
-- ===============================================================================

-- Daily plant refresh job
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'TR2000_DAILY_PLANT_REFRESH',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'pr_apex_refresh_plants',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0',
        enabled         => FALSE,
        comments        => 'Daily refresh of plant data from TR2000 API'
    );
END;
/

-- Hourly issues refresh for selected plants
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'TR2000_HOURLY_ISSUES_REFRESH',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'pr_apex_refresh_selected_issues',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=HOURLY',
        enabled         => FALSE,
        comments        => 'Hourly refresh of issues for selected plants'
    );
END;
/

-- Weekly RAW_JSON cleanup
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'TR2000_WEEKLY_CLEANUP',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'DECLARE v_count NUMBER; BEGIN pr_purge_raw_json(30, FALSE, v_count); END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=WEEKLY; BYDAY=SUN; BYHOUR=3; BYMINUTE=0',
        enabled         => FALSE,
        comments        => 'Weekly cleanup of RAW_JSON data older than 30 days'
    );
END;
/

-- ===============================================================================
-- Verification
-- ===============================================================================
SELECT 'Refactoring complete!' as status FROM dual;

-- Show new procedures
SELECT object_name, object_type, status 
FROM user_objects 
WHERE object_name LIKE 'PR_APEX%' OR object_name = 'PR_PURGE_RAW_JSON'
ORDER BY object_name;

-- Show new views
SELECT view_name 
FROM user_views 
WHERE view_name LIKE 'V_APEX%'
ORDER BY view_name;

-- Show scheduler jobs
SELECT job_name, enabled, state, repeat_interval
FROM user_scheduler_jobs
WHERE job_name LIKE 'TR2000%'
ORDER BY job_name;