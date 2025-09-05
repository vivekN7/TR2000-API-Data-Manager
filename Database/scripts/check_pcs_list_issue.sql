SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 1000

-- Check STG_PCS_LIST content
PROMPT ====================================
PROMPT STG_PCS_LIST Content (First 5 rows)
PROMPT ====================================
SELECT * FROM STG_PCS_LIST WHERE ROWNUM <= 5;

-- Count non-null PCS values
PROMPT ====================================
PROMPT STG_PCS_LIST Statistics
PROMPT ====================================
SELECT 
    COUNT(*) as total_rows,
    COUNT("PCS") as non_null_pcs,
    COUNT("Revision") as non_null_revision
FROM STG_PCS_LIST;

-- Check PCS_LIST content
PROMPT ====================================
PROMPT PCS_LIST Content
PROMPT ====================================
SELECT COUNT(*) as total_rows FROM PCS_LIST;

-- Check RAW_JSON for PCS list endpoint
PROMPT ====================================
PROMPT RAW_JSON PCS List Entries
PROMPT ====================================
SELECT 
    raw_json_id,
    endpoint_key,
    created_date,
    DBMS_LOB.SUBSTR(payload, 100, 1) as json_start
FROM RAW_JSON
WHERE endpoint_key LIKE '%PCS_LIST%'
OR endpoint_template LIKE '%/pcs%'
AND endpoint_template NOT LIKE '%{pcs_name}%'
ORDER BY created_date DESC
FETCH FIRST 3 ROWS ONLY;

EXIT;
