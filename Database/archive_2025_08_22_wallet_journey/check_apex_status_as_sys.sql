-- Check APEX installation status as SYSDBA
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 1000

PROMPT ========================================
PROMPT Checking APEX Installation Status
PROMPT ========================================

-- Switch to PDB
ALTER SESSION SET CONTAINER = XEPDB1;

-- Check registry
COL comp_name FORMAT A40
COL version FORMAT A15
COL status FORMAT A12
SELECT comp_name, version, status 
FROM dba_registry 
WHERE comp_id = 'APEX';

-- Check APEX schemas
PROMPT
PROMPT APEX Schemas Present:
SELECT username, account_status, created 
FROM dba_users 
WHERE username LIKE 'APEX%'
ORDER BY username;

-- Check object counts
PROMPT
PROMPT Object Counts in APEX Schema:
SELECT object_type, COUNT(*) as count
FROM dba_objects
WHERE owner LIKE 'APEX%'
GROUP BY object_type
ORDER BY object_type;

-- Check if WWV_FLOW tables exist
PROMPT
PROMPT WWV_FLOW Table Count:
SELECT COUNT(*) as wwv_flow_tables
FROM dba_tables
WHERE owner LIKE 'APEX%' 
AND table_name LIKE 'WWV_FLOW%';

-- Check for installation scripts
PROMPT
PROMPT Checking for APEX installation files:
HOST ls -la /workspace/TR2000/TR2K/Database/apex/*.sql | head -20

PROMPT
PROMPT ========================================
PROMPT Status check complete
PROMPT ========================================