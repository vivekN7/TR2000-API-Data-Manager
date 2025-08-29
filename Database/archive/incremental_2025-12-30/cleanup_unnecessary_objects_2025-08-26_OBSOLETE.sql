-- ===============================================================================
-- Cleanup Script: Remove unnecessary APEX and test views
-- Date: 2025-08-26
-- Purpose: Clean up views and procedures that are not needed until APEX UI phase
-- ===============================================================================

SET ECHO ON
SET FEEDBACK ON

PROMPT ===============================================================================
PROMPT Dropping unnecessary APEX UI views...
PROMPT ===============================================================================

-- Drop all APEX UI views (will recreate when needed for APEX)
DROP VIEW VAPEXUI_AVAILABLE_PLANTS_LOV;
DROP VIEW VAPEXUI_ETL_CONTROL_ISSUES_LOV;
DROP VIEW VAPEXUI_ETL_CONTROL_PLANTS_LOV;
DROP VIEW VAPEXUI_ETL_HISTORY;
DROP VIEW VAPEXUI_ETL_STATUS;
DROP VIEW VAPEXUI_ISSUES_LOV;
DROP VIEW VAPEXUI_PLANT_LOV;
DROP VIEW VAPEXUI_PLANT_SELECTION;

PROMPT ===============================================================================
PROMPT Dropping APEX-specific procedure...
PROMPT ===============================================================================

-- Drop APEX UI control procedure (will recreate when needed)
DROP PROCEDURE APEX_ETL_CONTROL_ACTION;

PROMPT ===============================================================================
PROMPT Dropping invalid test views (will fix these later if needed)...
PROMPT ===============================================================================

-- These test views are invalid and can be recreated when needed
DROP VIEW VTEST_BY_FLOW_STEP;
DROP VIEW VTEST_COVERAGE;
DROP VIEW VTEST_FAILURES;
DROP VIEW VTEST_FAILURE_ANALYSIS;
DROP VIEW VTEST_SUMMARY;

PROMPT ===============================================================================
PROMPT Dropping invalid ETL control views...
PROMPT ===============================================================================

DROP VIEW V_ETL_CONTROL_LOG;
DROP VIEW V_ETL_CONTROL_STATUS;

PROMPT ===============================================================================
PROMPT Cleanup complete. Checking remaining objects...
PROMPT ===============================================================================

-- Show what's left
SELECT object_type, COUNT(*) as count
FROM user_objects
WHERE status = 'INVALID'
GROUP BY object_type
ORDER BY object_type;

PROMPT
PROMPT Valid views remaining:
SELECT object_name 
FROM user_objects 
WHERE object_type = 'VIEW' 
AND status = 'VALID'
ORDER BY object_name;

PROMPT
PROMPT ===============================================================================
PROMPT Cleanup completed successfully
PROMPT ===============================================================================