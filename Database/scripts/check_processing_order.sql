-- Check where valve-elements processing starts
SELECT line, text 
FROM user_source 
WHERE name = 'PKG_PCS_DETAIL_PROCESSOR' 
AND type = 'PACKAGE BODY'
AND UPPER(text) LIKE '%VALVE_ELEMENT%'
AND line BETWEEN 430 AND 450
ORDER BY line;

-- Also check if there's a DELETE before INSERT
SELECT line, text 
FROM user_source 
WHERE name = 'PKG_PCS_DETAIL_PROCESSOR' 
AND type = 'PACKAGE BODY'
AND line BETWEEN 440 AND 446
ORDER BY line;

EXIT;
