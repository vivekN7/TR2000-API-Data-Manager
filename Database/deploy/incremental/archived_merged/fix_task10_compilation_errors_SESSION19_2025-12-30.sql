-- ===============================================================================
-- Fix Task 10 Compilation Errors
-- Date: 2025-12-30
-- Purpose: Fix package compilation errors before cleanup
-- ===============================================================================

-- The main issue is that PKG_ETL_OPERATIONS references SELECTION_LOADER 
-- which doesn't exist (we have SELECTED_PLANTS and SELECTED_ISSUES instead)

-- First, let's check and fix PKG_ETL_OPERATIONS
-- We need to update it to use SELECTED_PLANTS and SELECTED_ISSUES

-- Since we need to see the full package first, let's just recompile with FORCE
-- to see all errors, then we'll fix them properly

-- For now, let's create a view to bridge the gap temporarily
CREATE OR REPLACE VIEW SELECTION_LOADER AS
SELECT 
    'PLANT' as entity_type,
    plant_id,
    NULL as issue_revision,
    is_active,
    selection_date
FROM SELECTED_PLANTS
WHERE is_active = 'Y'
UNION ALL
SELECT 
    'ISSUE' as entity_type,
    plant_id,
    issue_revision,
    is_active,
    selection_date
FROM SELECTED_ISSUES
WHERE is_active = 'Y';

-- Now try to recompile the packages
ALTER PACKAGE PKG_ETL_OPERATIONS COMPILE BODY;
ALTER PACKAGE PKG_ADVANCED_TESTS COMPILE BODY;
ALTER PACKAGE PKG_API_ERROR_TESTS COMPILE BODY;
ALTER PACKAGE PKG_RESILIENCE_TESTS COMPILE BODY;
ALTER PACKAGE PKG_TRANSACTION_TESTS COMPILE BODY;

-- Check what's still invalid
SELECT object_name, object_type, status
FROM user_objects
WHERE status != 'VALID'
ORDER BY object_type, object_name;