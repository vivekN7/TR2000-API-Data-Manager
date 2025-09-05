-- Let's see what revision we're actually passing
SELECT 
    'PCS_LIST columns' as source,
    column_name 
FROM user_tab_columns 
WHERE table_name = 'PCS_LIST'
AND column_name LIKE '%REVISION%'
ORDER BY column_id;

-- And check what we're selecting in process_pcs_details
SELECT text 
FROM user_source 
WHERE name = 'PKG_MAIN_ETL_CONTROL' 
AND type = 'PACKAGE BODY'
AND UPPER(text) LIKE '%L.REVISION%'
AND ROWNUM <= 5;

EXIT;
