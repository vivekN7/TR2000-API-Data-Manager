-- Fix APEX views and recompile packages
ALTER SESSION SET CURRENT_SCHEMA = TR2000_STAGING;

-- Fix plant LOV view
CREATE OR REPLACE VIEW v_apex_plant_lov AS
SELECT 
    p.plant_id as return_value,
    p.plant_id || ' - ' || p.short_description as display_value,
    CASE WHEN sl.plant_id IS NOT NULL THEN 'Y' ELSE 'N' END as is_selected
FROM PLANTS p
LEFT JOIN (
    SELECT DISTINCT plant_id 
    FROM SELECTION_LOADER 
    WHERE is_active = 'Y'
) sl ON p.plant_id = sl.plant_id
WHERE p.is_valid = 'Y'
ORDER BY p.plant_id;

-- Fix issues LOV view (check actual column names)
CREATE OR REPLACE VIEW v_apex_issues_lov AS
SELECT 
    i.issue_revision as return_value,
    i.issue_revision || ' - ' || NVL(i.issue_number, 'Issue') as display_value,
    i.plant_id as parent_value
FROM ISSUES i
WHERE i.is_valid = 'Y'
ORDER BY i.plant_id, i.issue_revision;

-- Recompile pkg_etl_operations
ALTER PACKAGE pkg_etl_operations COMPILE;
ALTER PACKAGE pkg_etl_operations COMPILE BODY;

-- Check compilation status
SELECT object_name, object_type, status
FROM user_objects
WHERE status = 'INVALID';

-- Verify views
SELECT 'APEX Views Created' as status, COUNT(*) as count
FROM user_views
WHERE view_name LIKE 'V_APEX%';

-- Verify procedures
SELECT 'APEX Procedures Created' as status, COUNT(*) as count
FROM user_procedures
WHERE object_name LIKE 'APEX_%';

-- Check plants data
SELECT 'Plants Available' as status, COUNT(*) as count
FROM PLANTS
WHERE is_valid = 'Y';