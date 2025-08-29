-- ===============================================================================
-- Procedure: UPDATE_ETL_STATS
-- Purpose: Update ETL_STATS table with monitoring data
-- ===============================================================================

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
            -- Update last 5 durations (simplified)
            last_5_durations = CASE 
                WHEN last_5_durations IS NULL THEN '[' || p_response_time || ']'
                WHEN LENGTH(last_5_durations) < 50 THEN 
                    SUBSTR(last_5_durations, 1, LENGTH(last_5_durations)-1) || ',' || p_response_time || ']'
                ELSE 
                    '[' || p_response_time || ']' -- Reset when too long
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