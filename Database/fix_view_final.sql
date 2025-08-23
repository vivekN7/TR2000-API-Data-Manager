-- Final view fix with correct column names
ALTER SESSION SET CURRENT_SCHEMA = TR2000_STAGING;

-- Drop and recreate view with correct column names from PLANTS table
CREATE OR REPLACE VIEW v_apex_plant_selection AS
SELECT 
    sl.plant_id,
    p.short_description as plant_name,  -- Correct column name
    p.operator_name,
    sl.is_active,
    (SELECT COUNT(*) FROM ISSUES i WHERE i.plant_id = sl.plant_id AND i.is_valid = 'Y') as issue_count,
    sl.selection_date,
    sl.last_etl_run,
    sl.etl_status
FROM SELECTION_LOADER sl
LEFT JOIN PLANTS p ON sl.plant_id = p.plant_id
ORDER BY sl.plant_id;

-- Verify all views are created
SELECT view_name, status 
FROM user_views 
WHERE view_name LIKE 'V_APEX%'
ORDER BY view_name;