-- ===============================================================================
-- Remove Unused Tables
-- Date: 2025-12-30
-- Purpose: Drop tables that are never used and not needed
-- ===============================================================================

-- Drop EXTERNAL_SYSTEM_REFS (0 records, never used)
DROP TABLE EXTERNAL_SYSTEM_REFS CASCADE CONSTRAINTS;

-- Drop TEMP_TEST_DATA (0 records, temporary table)
DROP TABLE TEMP_TEST_DATA CASCADE CONSTRAINTS;

-- Check remaining tables
SELECT COUNT(*) as total_tables FROM user_tables;

-- Verify no invalid objects after drops
SELECT object_name, object_type, status
FROM user_objects
WHERE status != 'VALID';