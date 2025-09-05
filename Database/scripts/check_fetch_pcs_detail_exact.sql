-- Get exact fetch_pcs_detail signature from package spec
SELECT text 
FROM user_source 
WHERE name = 'PKG_API_CLIENT' 
AND type = 'PACKAGE'
AND line BETWEEN (
    SELECT MIN(line) FROM user_source 
    WHERE name = 'PKG_API_CLIENT' 
    AND type = 'PACKAGE'
    AND UPPER(text) LIKE '%FETCH_PCS_DETAIL%'
) AND (
    SELECT MIN(line) + 7 FROM user_source 
    WHERE name = 'PKG_API_CLIENT' 
    AND type = 'PACKAGE'
    AND UPPER(text) LIKE '%FETCH_PCS_DETAIL%'
)
ORDER BY line;

EXIT;
