-- ===============================================================================
-- Deploy All Triggers - TR2000 ETL System
-- ===============================================================================
-- Purpose: Creates all database triggers
-- Date: 2025-08-27
-- ===============================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ===============================================================================
PROMPT Creating/Replacing All Triggers
PROMPT ===============================================================================

-- Cascade triggers
@01_cascade_triggers.sql

-- Reference cascade trigger (Task 7)
@02_trg_cascade_issue_to_references.sql

PROMPT
PROMPT ===============================================================================
PROMPT Trigger deployment complete
PROMPT ===============================================================================

-- Show trigger status
SELECT trigger_name, table_name, status 
FROM user_triggers 
ORDER BY trigger_name;

EXIT;