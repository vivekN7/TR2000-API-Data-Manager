-- See all PCS detail endpoints that were called
SELECT endpoint_key, endpoint_template, COUNT(*) as count
FROM RAW_JSON
WHERE endpoint_template LIKE '%/pcs/%/rev/%'
GROUP BY endpoint_key, endpoint_template
ORDER BY endpoint_template;

-- Check last ETL run details
SELECT * FROM (
    SELECT raw_json_id, endpoint_key, created_date,
           LENGTH(payload) as payload_size
    FROM RAW_JSON
    ORDER BY raw_json_id DESC
)
WHERE ROWNUM <= 10;

EXIT;
