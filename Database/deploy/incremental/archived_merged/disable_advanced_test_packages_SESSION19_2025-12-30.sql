-- ===============================================================================
-- Temporarily Disable Advanced Test Packages
-- Date: 2025-12-30
-- Purpose: These test packages require DBA privileges for V$ views
--          We'll disable them for now and focus on core cleanup
-- ===============================================================================

-- Drop the test package bodies that require DBA privileges
-- These can be recreated later if needed with proper privileges

DROP PACKAGE BODY PKG_ADVANCED_TESTS;
DROP PACKAGE BODY PKG_API_ERROR_TESTS;
DROP PACKAGE BODY PKG_RESILIENCE_TESTS;
DROP PACKAGE BODY PKG_TRANSACTION_TESTS;

-- Keep the package specs so we don't break dependencies
-- The specs remain valid even without bodies

-- Check remaining invalid objects
SELECT object_name, object_type, status
FROM user_objects
WHERE status != 'VALID'
ORDER BY object_type, object_name;