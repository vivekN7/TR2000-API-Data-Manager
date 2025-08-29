-- ===============================================================================
-- Rename CONTROL_ENDPOINT_STATE to ETL_STATS
-- Date: 2025-12-30
-- Purpose: Better name to reflect its purpose as ETL monitoring table
-- ===============================================================================

-- Step 1: Rename the table
ALTER TABLE CONTROL_ENDPOINT_STATE RENAME TO ETL_STATS;

-- Step 2: Rename the sequence if it exists
BEGIN
    FOR seq IN (SELECT sequence_name FROM user_sequences 
                WHERE sequence_name LIKE '%ENDPOINT_STATE%') LOOP
        EXECUTE IMMEDIATE 'RENAME ' || seq.sequence_name || ' TO ETL_STATS_SEQ';
    END LOOP;
END;
/

-- Step 3: Add new monitoring columns to ETL_STATS
ALTER TABLE ETL_STATS ADD (
    api_call_count NUMBER DEFAULT 0,
    total_response_time_ms NUMBER DEFAULT 0,
    avg_response_time_ms NUMBER GENERATED ALWAYS AS 
        (CASE WHEN api_call_count > 0 
              THEN ROUND(total_response_time_ms/api_call_count,2) 
              ELSE 0 END) VIRTUAL,
    min_response_time_ms NUMBER,
    max_response_time_ms NUMBER,
    success_count NUMBER DEFAULT 0,
    failure_count NUMBER DEFAULT 0,
    success_rate_pct NUMBER GENERATED ALWAYS AS
        (CASE WHEN (success_count + failure_count) > 0
              THEN ROUND(100 * success_count/(success_count + failure_count),2)
              ELSE 0 END) VIRTUAL,
    last_5_durations VARCHAR2(500),
    data_volume_mb NUMBER,
    last_error_code NUMBER
);

-- Step 4: Update any references in packages (none found in our scan)
-- No packages currently reference CONTROL_ENDPOINT_STATE

-- Step 5: Check the new structure
DESC ETL_STATS;

-- Step 6: Verify no invalid objects
SELECT object_name, object_type, status
FROM user_objects
WHERE status != 'VALID';