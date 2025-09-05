-- Find the valve-elements API response
SELECT raw_json_id, endpoint_key, endpoint_template,
       SUBSTR(payload, 1, 200) as json_start
FROM RAW_JSON
WHERE endpoint_template LIKE '%valve-elements%'
AND ROWNUM = 1;

-- Check if we got empty or null numeric fields
SELECT raw_json_id,
       CASE 
         WHEN payload LIKE '%"ValveGroupNo":null%' THEN 'Has null ValveGroupNo'
         WHEN payload LIKE '%"ValveGroupNo":""%' THEN 'Has empty ValveGroupNo'
         WHEN payload LIKE '%"LineNo":null%' THEN 'Has null LineNo'
         WHEN payload LIKE '%"LineNo":""%' THEN 'Has empty LineNo'
         ELSE 'Check actual values'
       END as issue
FROM RAW_JSON
WHERE endpoint_template LIKE '%valve-elements%'
AND ROWNUM = 1;

EXIT;
