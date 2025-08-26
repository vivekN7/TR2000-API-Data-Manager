-- ===============================================================================
-- Deploy All Views - TR2000 ETL System
-- ===============================================================================
-- Views use CREATE OR REPLACE so no data is lost
-- No need to drop views first
-- 
-- Naming Convention:
-- VETL_*     - ETL Critical Views (DO NOT DROP without impact analysis!)
-- VAPEXUI_*  - APEX UI Views (LOVs, display views)
-- VTEST_*    - Test monitoring views
-- V_*        - General reporting/analysis views
-- ===============================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ===============================================================================
PROMPT Deploying all views...
PROMPT ===============================================================================

-- ETL Critical Views (MUST deploy first - other views may depend on these)
@00_etl_critical_views.sql

-- APEX LOV Views
@01_apex_lov_views.sql

-- Monitoring Views  
@02_monitoring_views.sql

-- System Views
@03_system_views.sql

PROMPT
PROMPT ===============================================================================
PROMPT View deployment complete
PROMPT ===============================================================================

-- Show all views
SELECT view_name, status FROM user_views ORDER BY view_name;

EXIT;