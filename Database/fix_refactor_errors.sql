-- Fix refactoring errors
ALTER SESSION SET CURRENT_SCHEMA = TR2000_STAGING;

-- Fix view v_apex_plant_selection (last_updated -> last_modified)
CREATE OR REPLACE VIEW v_apex_plant_selection AS
SELECT 
    sl.plant_id,
    p.plant_name,
    p.operator_name,
    sl.is_active,
    (SELECT COUNT(*) FROM ISSUES i WHERE i.plant_id = sl.plant_id AND i.is_valid = 'Y') as issue_count,
    sl.last_modified
FROM SELECTION_LOADER sl
LEFT JOIN PLANTS p ON sl.plant_id = p.plant_id
ORDER BY sl.plant_id;

-- Fix view v_apex_etl_history (add missing column)
ALTER TABLE ETL_RUN_LOG ADD (error_message VARCHAR2(4000));

-- Recreate the view
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

-- Check package compilation errors
SELECT text FROM user_errors 
WHERE name = 'PKG_ETL_OPERATIONS' 
AND type = 'PACKAGE BODY'
ORDER BY line;