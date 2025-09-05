-- Check what's at line 542 of PKG_PCS_DETAIL_PROCESSOR
SELECT line, text 
FROM user_source 
WHERE name = 'PKG_PCS_DETAIL_PROCESSOR' 
AND type = 'PACKAGE BODY'
AND line BETWEEN 540 AND 545
ORDER BY line;

-- Check if there's any bad data in staging
SELECT * FROM STG_PCS_PIPE_ELEMENTS 
WHERE "LineNo" IS NOT NULL 
AND NOT REGEXP_LIKE("LineNo", '^[0-9]+$')
AND ROWNUM <= 5;

EXIT;
