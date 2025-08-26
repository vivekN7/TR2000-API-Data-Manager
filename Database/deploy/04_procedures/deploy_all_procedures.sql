-- ===============================================================================
-- Deploy All Procedures - TR2000 ETL System
-- ===============================================================================
-- UI procedures are prefixed with UI_ to distinguish from core ETL
-- ===============================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ===============================================================================
PROMPT Creating/Replacing Procedures
PROMPT ===============================================================================

-- APEX procedures (UI_ prefix kept for procedures)
@01_apex_procedures.sql

PROMPT
PROMPT ===============================================================================
PROMPT Procedure deployment complete
PROMPT ===============================================================================

EXIT;