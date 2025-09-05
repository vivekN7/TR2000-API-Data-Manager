SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 1000

-- Check all tables match backup
PROMPT ====================================
PROMPT Checking Tables
PROMPT ====================================
SELECT table_name 
FROM user_tables 
WHERE table_name NOT LIKE 'BIN$%'
ORDER BY table_name;

-- Check package status
PROMPT ====================================
PROMPT Checking Package Status
PROMPT ====================================
SELECT object_name, object_type, status
FROM user_objects
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')
AND object_name NOT LIKE 'BIN$%'
ORDER BY object_name, object_type;

-- Check sequences
PROMPT ====================================
PROMPT Checking Sequences
PROMPT ====================================
SELECT sequence_name 
FROM user_sequences
ORDER BY sequence_name;

-- Check data flow verification
PROMPT ====================================
PROMPT Verifying Data Flow (Recent ETL)
PROMPT ====================================
SELECT 
    'RAW_JSON' as table_name,
    COUNT(*) as record_count
FROM RAW_JSON
WHERE created_date > SYSDATE - 1
UNION ALL
SELECT 
    'STG_PCS_REFERENCES',
    COUNT(*)
FROM STG_PCS_REFERENCES
UNION ALL
SELECT 
    'PCS_REFERENCES',
    COUNT(*)
FROM PCS_REFERENCES
UNION ALL
SELECT 
    'STG_VDS_REFERENCES',
    COUNT(*)
FROM STG_VDS_REFERENCES
UNION ALL
SELECT 
    'VDS_REFERENCES',
    COUNT(*)
FROM VDS_REFERENCES;

EXIT;
