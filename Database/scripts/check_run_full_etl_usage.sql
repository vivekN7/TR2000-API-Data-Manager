-- Check package spec
SELECT text 
FROM user_source 
WHERE name = 'PKG_MAIN_ETL_CONTROL' 
AND type = 'PACKAGE'
AND UPPER(text) LIKE '%RUN_%ETL%';

-- Check if any other packages call run_full_etl
SELECT DISTINCT name, type
FROM user_source
WHERE UPPER(text) LIKE '%RUN_FULL_ETL%'
ORDER BY name, type;

EXIT;
