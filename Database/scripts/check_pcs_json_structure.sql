-- Check the actual JSON structure for PCS_LIST
SELECT 
    SUBSTR(payload, 1, 500) as json_sample
FROM RAW_JSON
WHERE raw_json_id = 4119;

EXIT;
