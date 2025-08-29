-- ===============================================================================
-- Trigger: TRG_ETL_RUN_TO_STATS
-- Purpose: Capture ETL_RUN_LOG updates and populate ETL_STATS
-- ===============================================================================

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