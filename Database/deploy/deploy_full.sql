-- ===============================================================================
-- Master Deployment Script - TR2000 ETL System
-- ===============================================================================
-- This script deploys the entire database from scratch
-- WARNING: All existing data will be lost!
-- ===============================================================================
-- Usage: sqlplus user/pass @deploy_full.sql
-- ===============================================================================

SET ECHO ON
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT ===============================================================================
PROMPT TR2000 ETL System - Full Database Deployment
PROMPT ===============================================================================
PROMPT WARNING: This will DROP and RECREATE the entire database schema!
PROMPT All existing data will be permanently lost!
PROMPT 
PROMPT Press Ctrl+C now to cancel, or Enter to continue...
PROMPT ===============================================================================
PAUSE

-- Get start time
COLUMN start_time NEW_VALUE start_time
SELECT TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') as start_time FROM dual;

PROMPT
PROMPT Starting deployment at &&start_time
PROMPT

-- 1. Deploy Tables (with drops)
PROMPT ===============================================================================
PROMPT STEP 1: Deploying Tables
PROMPT ===============================================================================
@01_tables/deploy_all_tables.sql

-- 2. Deploy Views (CREATE OR REPLACE - safe)
PROMPT ===============================================================================
PROMPT STEP 2: Deploying Views
PROMPT ===============================================================================
@02_views/deploy_all_views.sql

-- 3. Deploy Packages (CREATE OR REPLACE - safe)
PROMPT ===============================================================================
PROMPT STEP 3: Deploying Packages
PROMPT ===============================================================================
@03_packages/deploy_all_packages.sql

-- 4. Deploy Procedures (CREATE OR REPLACE - safe)
PROMPT ===============================================================================
PROMPT STEP 4: Deploying Procedures
PROMPT ===============================================================================
@04_procedures/deploy_all_procedures.sql

-- 5. Load Initial Data
PROMPT ===============================================================================
PROMPT STEP 5: Loading Initial Data
PROMPT ===============================================================================
@05_data/deploy_all_data.sql

-- Check for invalid objects
PROMPT
PROMPT ===============================================================================
PROMPT Checking for invalid objects...
PROMPT ===============================================================================

SELECT object_type, object_name, status
FROM user_objects
WHERE status = 'INVALID'
ORDER BY object_type, object_name;

-- Summary
PROMPT
PROMPT ===============================================================================
PROMPT Deployment Summary
PROMPT ===============================================================================

SELECT object_type, COUNT(*) as count, status
FROM user_objects
WHERE object_type IN ('TABLE', 'VIEW', 'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'INDEX')
GROUP BY object_type, status
ORDER BY object_type, status;

-- Get end time
COLUMN end_time NEW_VALUE end_time
SELECT TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') as end_time FROM dual;

PROMPT
PROMPT ===============================================================================
PROMPT Deployment completed at &&end_time
PROMPT ===============================================================================
PROMPT
PROMPT To test the deployment:
PROMPT   - Tables: SELECT COUNT(*) FROM user_tables;
PROMPT   - Views:  SELECT COUNT(*) FROM user_views;
PROMPT   - Packages: SELECT COUNT(*) FROM user_objects WHERE object_type = 'PACKAGE';
PROMPT
PROMPT To load test data:
PROMPT   EXEC pkg_api_client.refresh_plants_from_api(:status, :msg);
PROMPT ===============================================================================

EXIT;