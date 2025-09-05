-- Check what's at line 446 of PKG_PCS_DETAIL_PROCESSOR
SELECT line, text 
FROM user_source 
WHERE name = 'PKG_PCS_DETAIL_PROCESSOR' 
AND type = 'PACKAGE BODY'
AND line BETWEEN 444 AND 450
ORDER BY line;

-- Check which PCS was being processed
SELECT DISTINCT plant_id, pcs_name, pcs_revision
FROM STG_PCS_HEADER_PROPERTIES;

-- Check for any non-numeric values in numeric columns
SELECT 
    'MaterialGroupID' as column_name,
    COUNT(*) as bad_values
FROM STG_PCS_PIPE_ELEMENTS
WHERE "MaterialGroupID" IS NOT NULL
AND NOT REGEXP_LIKE("MaterialGroupID", '^-?[0-9]+(\.[0-9]+)?$')
UNION ALL
SELECT 
    'ElementGroupNo',
    COUNT(*)
FROM STG_PCS_PIPE_ELEMENTS  
WHERE "ElementGroupNo" IS NOT NULL
AND NOT REGEXP_LIKE("ElementGroupNo", '^-?[0-9]+(\.[0-9]+)?$')
UNION ALL
SELECT 
    'LineNo',
    COUNT(*)
FROM STG_PCS_PIPE_ELEMENTS
WHERE "LineNo" IS NOT NULL  
AND NOT REGEXP_LIKE("LineNo", '^-?[0-9]+(\.[0-9]+)?$')
UNION ALL
SELECT 
    'ElementID',
    COUNT(*)
FROM STG_PCS_PIPE_ELEMENTS
WHERE "ElementID" IS NOT NULL
AND NOT REGEXP_LIKE("ElementID", '^-?[0-9]+(\.[0-9]+)?$');

EXIT;
