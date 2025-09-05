-- Let's look at the exact INSERT statement around line 446-460
SELECT line, text 
FROM user_source 
WHERE name = 'PKG_PCS_DETAIL_PROCESSOR' 
AND type = 'PACKAGE BODY'
AND line BETWEEN 446 AND 465
ORDER BY line;

EXIT;
