-- Check PKG_ETL_LOGGING procedures
SELECT text 
FROM user_source 
WHERE name = 'PKG_ETL_LOGGING' 
AND type = 'PACKAGE'
AND line BETWEEN 1 AND 30
ORDER BY line;

EXIT;
