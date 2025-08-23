-- ===============================================================================
-- Rollback R001: Remove Core Tables
-- Author: System
-- Date: 2025-08-23
-- Description: Rollback script for V001 migration
-- WARNING: This will DELETE all data in these tables!
-- ===============================================================================

-- Record rollback start
EXEC pr_record_migration('R001', 'Rollback core tables', 'R001__rollback_core_tables.sql', 'ROLLBACK');

-- Drop tables in reverse order of creation
DROP TABLE SELECTION_LOADER CASCADE CONSTRAINTS;
DROP TABLE ISSUES CASCADE CONSTRAINTS;
DROP TABLE PLANTS CASCADE CONSTRAINTS;
DROP TABLE RAW_JSON CASCADE CONSTRAINTS;

-- Update version table
DELETE FROM schema_version WHERE version = 'V001' AND type = 'MIGRATION';

COMMIT;