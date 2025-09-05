SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 1000

-- Check PKG_ETL_PROCESSOR procedures
SELECT object_name, procedure_name, object_type
FROM user_procedures 
WHERE object_name = 'PKG_ETL_PROCESSOR'
ORDER BY procedure_name;

-- Check package body source
SELECT text 
FROM user_source 
WHERE name = 'PKG_ETL_PROCESSOR' 
AND type = 'PACKAGE BODY'
AND line BETWEEN 1 AND 50
ORDER BY line;

EXIT;
