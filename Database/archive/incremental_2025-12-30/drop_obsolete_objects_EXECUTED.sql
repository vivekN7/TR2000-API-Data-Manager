-- ===============================================================================
-- Drop Obsolete Objects (Related to old SELECTION_LOADER table)
-- Date: 2025-08-27
-- ===============================================================================

-- Drop obsolete triggers
DROP TRIGGER TRG_PLANTS_TO_SELECTION;
DROP TRIGGER TRG_ISSUES_TO_SELECTION;

-- Drop obsolete views
DROP VIEW VETL_EFFECTIVE_SELECTIONS;
DROP VIEW V_ACTIVE_PLANT_SELECTIONS;

PROMPT Obsolete objects dropped successfully