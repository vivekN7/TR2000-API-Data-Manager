-- ===============================================================================
-- Fix Invalid Objects Before Full Test
-- Date: 2025-08-27
-- Purpose: Clean up objects that reference old SELECTION_LOADER table
-- ===============================================================================

PROMPT ===============================================================================
PROMPT Fixing Invalid Objects (References to Old SELECTION_LOADER)
PROMPT ===============================================================================

-- Drop obsolete triggers (no longer needed with new design)
DROP TRIGGER TRG_ISSUES_TO_SELECTION;
DROP TRIGGER TRG_PLANTS_TO_SELECTION;

-- Drop obsolete views
DROP VIEW VETL_EFFECTIVE_SELECTIONS;
DROP VIEW V_ACTIVE_PLANT_SELECTIONS;

PROMPT Obsolete triggers and views dropped.

-- The package bodies need manual updates:
-- 1. PKG_API_CLIENT - Update refresh_issues_for_selection (line 336-344)
--    Change: FROM SELECTION_LOADER to FROM SELECTED_ISSUES
--    
-- 2. PKG_API_CLIENT_REFERENCES - Already has wrapper procedure refresh_all_issue_references_throttled
--    Can be left as-is or fully updated later
--
-- 3. PKG_SIMPLE_TESTS - Update test_selection_cascade
--    Change: Use SELECTED_ISSUES instead of SELECTION_LOADER
--
-- 4. PKG_TEST_ISOLATION - Already fixed in deployment file
--    Just needs recompile from master file

PROMPT 
PROMPT Next steps:
PROMPT 1. Update package bodies to reference SELECTED_ISSUES
PROMPT 2. Recompile all packages
PROMPT 3. Run full_test_run_plan_2025-08-27.md
PROMPT ===============================================================================