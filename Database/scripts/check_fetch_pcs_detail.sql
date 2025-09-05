-- Check PKG_API_CLIENT.fetch_pcs_detail signature
SELECT text 
FROM user_source 
WHERE name = 'PKG_API_CLIENT' 
AND type = 'PACKAGE'
AND UPPER(text) LIKE '%FETCH_PCS_DETAIL%'
OR (line > (
    SELECT MIN(line) FROM user_source 
    WHERE name = 'PKG_API_CLIENT' 
    AND type = 'PACKAGE'
    AND UPPER(text) LIKE '%FETCH_PCS_DETAIL%'
) AND line < (
    SELECT MIN(line) + 10 FROM user_source 
    WHERE name = 'PKG_API_CLIENT' 
    AND type = 'PACKAGE'
    AND UPPER(text) LIKE '%FETCH_PCS_DETAIL%'
))
ORDER BY line;

EXIT;
