-- ===============================================================================
-- UI Monitoring Views - APEX Dashboard and Reports
-- ===============================================================================
-- These views support monitoring and reporting features in the APEX UI
-- These views support monitoring and reporting features in the APEX UI
-- ===============================================================================

-- View for APEX Plant Selection display
CREATE OR REPLACE VIEW V_APEX_PLANT_SELECTION AS
SELECT 
    p.plant_id,
    p.short_description,
    p.operator_name,
    p.area,
    CASE WHEN sl.selection_id IS NOT NULL THEN 'Y' ELSE 'N' END as is_selected,
    sl.selection_date,
    sl.selected_by,
    (SELECT COUNT(*) FROM ISSUES i WHERE i.plant_id = p.plant_id AND i.is_valid = 'Y') as issue_count
FROM PLANTS p
LEFT JOIN SELECTION_LOADER sl ON p.plant_id = sl.plant_id 
    AND sl.is_active = 'Y' 
    AND sl.issue_revision IS NULL
WHERE p.is_valid = 'Y'
ORDER BY p.plant_id;

-- View for active plant selections
CREATE OR REPLACE VIEW V_ACTIVE_PLANT_SELECTIONS AS
SELECT 
    sl.selection_id,
    sl.plant_id,
    p.short_description,
    p.operator_name,
    sl.selection_date,
    sl.selected_by,
    sl.last_etl_run,
    sl.etl_status,
    (SELECT COUNT(*) 
     FROM SELECTION_LOADER sl2 
     WHERE sl2.plant_id = sl.plant_id 
     AND sl2.issue_revision IS NOT NULL 
     AND sl2.is_active = 'Y') as selected_issues_count
FROM SELECTION_LOADER sl
JOIN PLANTS p ON sl.plant_id = p.plant_id
WHERE sl.is_active = 'Y'
AND sl.issue_revision IS NULL
AND p.is_valid = 'Y'
ORDER BY sl.selection_date DESC;

-- View for ETL Run Status monitoring
CREATE OR REPLACE VIEW V_ETL_CONTROL_STATUS AS
SELECT 
    run_id,
    run_type,
    endpoint_key,
    plant_id,
    start_time,
    end_time,
    status,
    CASE 
        WHEN status = 'SUCCESS' THEN 'green'
        WHEN status = 'FAILED' THEN 'red'
        WHEN status = 'RUNNING' THEN 'orange'
        ELSE 'gray'
    END as status_color,
    records_processed,
    duration_seconds,
    notes
FROM ETL_RUN_LOG
ORDER BY start_time DESC
FETCH FIRST 50 ROWS ONLY;

-- View for ETL Control Log display
CREATE OR REPLACE VIEW V_ETL_CONTROL_LOG AS
SELECT 
    l.run_id,
    l.run_type,
    l.plant_id,
    p.short_description as plant_name,
    l.start_time,
    l.end_time,
    l.status,
    l.records_processed,
    l.records_inserted,
    l.records_updated,
    l.error_count,
    l.duration_seconds,
    l.initiated_by
FROM ETL_RUN_LOG l
LEFT JOIN PLANTS p ON l.plant_id = p.plant_id
ORDER BY l.start_time DESC;

-- View for APEX ETL History
CREATE OR REPLACE VIEW V_APEX_ETL_HISTORY AS
SELECT 
    run_id,
    run_type,
    plant_id,
    TO_CHAR(start_time, 'DD-MON-YY HH24:MI:SS') as start_time_display,
    TO_CHAR(end_time, 'DD-MON-YY HH24:MI:SS') as end_time_display,
    status,
    NVL(records_processed, 0) as records_processed,
    NVL(error_count, 0) as error_count,
    CASE 
        WHEN duration_seconds < 60 THEN duration_seconds || ' sec'
        WHEN duration_seconds < 3600 THEN ROUND(duration_seconds/60, 1) || ' min'
        ELSE ROUND(duration_seconds/3600, 1) || ' hr'
    END as duration_display,
    initiated_by,
    notes
FROM ETL_RUN_LOG
WHERE start_time > SYSDATE - 7  -- Last 7 days
ORDER BY start_time DESC;

-- View for APEX ETL Status Summary
CREATE OR REPLACE VIEW V_APEX_ETL_STATUS AS
SELECT 
    endpoint_key,
    COUNT(*) as total_runs,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as successful_runs,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_runs,
    MAX(start_time) as last_run_time,
    AVG(duration_seconds) as avg_duration_seconds
FROM ETL_RUN_LOG
WHERE start_time > SYSDATE - 30  -- Last 30 days
GROUP BY endpoint_key
ORDER BY endpoint_key;

PROMPT Monitoring views created successfully