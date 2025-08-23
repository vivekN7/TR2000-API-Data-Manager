-- Final fixes for refactoring
ALTER SESSION SET CURRENT_SCHEMA = TR2000_STAGING;

-- Fix view with correct column names
CREATE OR REPLACE VIEW v_apex_plant_selection AS
SELECT 
    sl.plant_id,
    p.plant_name,
    p.operator_name,
    sl.is_active,
    (SELECT COUNT(*) FROM ISSUES i WHERE i.plant_id = sl.plant_id AND i.is_valid = 'Y') as issue_count,
    sl.selection_date,
    sl.last_etl_run,
    sl.etl_status
FROM SELECTION_LOADER sl
LEFT JOIN PLANTS p ON sl.plant_id = p.plant_id
ORDER BY sl.plant_id;

-- Show all created objects
SELECT 'New Procedures' as category, object_name 
FROM user_objects 
WHERE object_name LIKE 'PR_%' 
AND object_type = 'PROCEDURE'
AND created > SYSDATE - 1
UNION ALL
SELECT 'New Views', view_name 
FROM user_views 
WHERE view_name LIKE 'V_APEX%'
UNION ALL
SELECT 'Scheduler Jobs', job_name
FROM user_scheduler_jobs
WHERE job_name LIKE 'TR2000%';

-- Test the new purge procedure
DECLARE
    v_count NUMBER;
BEGIN
    -- Dry run first
    pr_purge_raw_json(30, TRUE, v_count);
    DBMS_OUTPUT.PUT_LINE('Dry run complete - would delete ' || v_count || ' records');
END;
/