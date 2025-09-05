-- Check PKG_ETL_LOGGING.log_error procedure
SELECT text 
FROM user_source 
WHERE name = 'PKG_ETL_LOGGING' 
AND type = 'PACKAGE'
AND line BETWEEN 30 AND 60
ORDER BY line;

EXIT;
