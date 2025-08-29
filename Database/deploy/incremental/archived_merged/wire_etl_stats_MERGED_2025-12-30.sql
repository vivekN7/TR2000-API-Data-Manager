-- ===============================================================================
-- Wire Up ETL_STATS Table
-- Date: 2025-12-30
-- Purpose: Create triggers/procedures to populate ETL_STATS with monitoring data
-- ===============================================================================

-- Create a procedure to update ETL_STATS after each API call
CREATE OR REPLACE PROCEDURE update_etl_stats(
    p_endpoint_key    VARCHAR2,
    p_plant_id        VARCHAR2 DEFAULT NULL,
    p_response_time   NUMBER DEFAULT NULL,
    p_success         CHAR DEFAULT 'Y',
    p_data_volume_mb  NUMBER DEFAULT NULL,
    p_error_msg       VARCHAR2 DEFAULT NULL,
    p_error_code      NUMBER DEFAULT NULL
) AS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_exists NUMBER;
BEGIN
    -- Check if record exists
    SELECT COUNT(*) INTO v_exists
    FROM ETL_STATS
    WHERE endpoint_key = p_endpoint_key
    AND NVL(plant_id, 'NONE') = NVL(p_plant_id, 'NONE');
    
    IF v_exists = 0 THEN
        -- Insert new record
        INSERT INTO ETL_STATS (
            endpoint_key, plant_id, 
            api_call_count, success_count, failure_count,
            total_response_time_ms, min_response_time_ms, max_response_time_ms,
            last_successful_run, last_error, last_error_code, data_volume_mb
        ) VALUES (
            p_endpoint_key, p_plant_id,
            1, 
            CASE WHEN p_success = 'Y' THEN 1 ELSE 0 END,
            CASE WHEN p_success = 'N' THEN 1 ELSE 0 END,
            NVL(p_response_time, 0),
            p_response_time, p_response_time,
            CASE WHEN p_success = 'Y' THEN SYSTIMESTAMP ELSE NULL END,
            CASE WHEN p_success = 'N' THEN p_error_msg ELSE NULL END,
            CASE WHEN p_success = 'N' THEN p_error_code ELSE NULL END,
            p_data_volume_mb
        );
    ELSE
        -- Update existing record
        UPDATE ETL_STATS
        SET api_call_count = api_call_count + 1,
            success_count = success_count + CASE WHEN p_success = 'Y' THEN 1 ELSE 0 END,
            failure_count = failure_count + CASE WHEN p_success = 'N' THEN 1 ELSE 0 END,
            total_response_time_ms = total_response_time_ms + NVL(p_response_time, 0),
            min_response_time_ms = LEAST(NVL(min_response_time_ms, p_response_time), p_response_time),
            max_response_time_ms = GREATEST(NVL(max_response_time_ms, p_response_time), p_response_time),
            last_successful_run = CASE WHEN p_success = 'Y' THEN SYSTIMESTAMP ELSE last_successful_run END,
            last_error = CASE WHEN p_success = 'N' THEN p_error_msg ELSE last_error END,
            last_error_code = CASE WHEN p_success = 'N' THEN p_error_code ELSE last_error_code END,
            data_volume_mb = NVL(data_volume_mb, 0) + NVL(p_data_volume_mb, 0),
            -- Update last 5 durations (JSON array)
            last_5_durations = CASE 
                WHEN last_5_durations IS NULL THEN '[' || p_response_time || ']'
                ELSE 
                    CASE 
                        WHEN LENGTH(last_5_durations) < 50 THEN 
                            SUBSTR(last_5_durations, 1, LENGTH(last_5_durations)-1) || ',' || p_response_time || ']'
                        ELSE 
                            '[' || SUBSTR(SUBSTR(last_5_durations, INSTR(last_5_durations, ',') + 1, LENGTH(last_5_durations) - INSTR(last_5_durations, ',') - 1), 1, LENGTH(SUBSTR(last_5_durations, INSTR(last_5_durations, ',') + 1, LENGTH(last_5_durations) - INSTR(last_5_durations, ',') - 1)) - 1) || ',' || p_response_time || ']'
                    END
            END
        WHERE endpoint_key = p_endpoint_key
        AND NVL(plant_id, 'NONE') = NVL(p_plant_id, 'NONE');
    END IF;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        -- Don't break main transaction for stats update
        ROLLBACK;
END update_etl_stats;
/

-- Create a trigger to capture ETL_RUN_LOG updates and populate ETL_STATS
CREATE OR REPLACE TRIGGER trg_etl_run_to_stats
AFTER INSERT OR UPDATE ON ETL_RUN_LOG
FOR EACH ROW
DECLARE
    v_response_time NUMBER;
    v_success CHAR(1);
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    -- Only process when status changes from RUNNING to SUCCESS/FAILED
    IF :NEW.status IN ('SUCCESS', 'FAILED') AND NVL(:OLD.status, 'RUNNING') = 'RUNNING' THEN
        -- Calculate response time
        v_response_time := :NEW.duration_seconds * 1000; -- Convert to milliseconds
        v_success := CASE WHEN :NEW.status = 'SUCCESS' THEN 'Y' ELSE 'N' END;
        
        -- Update ETL_STATS
        update_etl_stats(
            p_endpoint_key => :NEW.endpoint_key,
            p_plant_id => :NEW.plant_id,
            p_response_time => v_response_time,
            p_success => v_success,
            p_data_volume_mb => NULL, -- Could calculate from records processed
            p_error_msg => :NEW.notes,
            p_error_code => :NEW.error_count
        );
    END IF;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        -- Don't break main transaction
        ROLLBACK;
END;
/

-- Initialize ETL_STATS with current data from ETL_RUN_LOG
DECLARE
    v_count NUMBER;
BEGIN
    -- Check if ETL_STATS is empty
    SELECT COUNT(*) INTO v_count FROM ETL_STATS;
    
    IF v_count = 0 THEN
        -- Populate from historical data
        INSERT INTO ETL_STATS (
            endpoint_key, plant_id,
            api_call_count, success_count, failure_count,
            total_response_time_ms, min_response_time_ms, max_response_time_ms,
            last_successful_run
        )
        SELECT 
            endpoint_key, plant_id,
            COUNT(*) as api_call_count,
            SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as success_count,
            SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failure_count,
            SUM(NVL(duration_seconds, 0) * 1000) as total_response_time_ms,
            MIN(NVL(duration_seconds, 0) * 1000) as min_response_time_ms,
            MAX(NVL(duration_seconds, 0) * 1000) as max_response_time_ms,
            MAX(CASE WHEN status = 'SUCCESS' THEN end_time ELSE NULL END) as last_successful_run
        FROM ETL_RUN_LOG
        WHERE status IN ('SUCCESS', 'FAILED')
        GROUP BY endpoint_key, plant_id;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('ETL_STATS initialized with ' || SQL%ROWCOUNT || ' records');
    END IF;
END;
/

-- Test the setup
SELECT endpoint_key, plant_id, api_call_count, success_count, failure_count,
       ROUND(avg_response_time_ms/1000, 2) as avg_seconds,
       success_rate_pct
FROM ETL_STATS
ORDER BY endpoint_key, plant_id;