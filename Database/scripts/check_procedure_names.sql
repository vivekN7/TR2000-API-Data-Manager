-- Check what procedures exist in PKG_MAIN_ETL_CONTROL
SELECT object_name, procedure_name
FROM user_procedures
WHERE object_name = 'PKG_MAIN_ETL_CONTROL'
AND procedure_name IS NOT NULL
ORDER BY procedure_name;

EXIT;
