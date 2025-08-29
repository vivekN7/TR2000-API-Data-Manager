-- ===============================================================================
-- Apply Package Renames
-- Date: 2025-12-30
-- Purpose: Drop V2 package and create clean-named version
-- ===============================================================================

-- Drop the old V2 package if it exists
BEGIN
    EXECUTE IMMEDIATE 'DROP PACKAGE pkg_api_client_pcs_details_v2';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -4043 THEN -- Package doesn't exist
            RAISE;
        END IF;
END;
/

-- Create the new clean-named package (run from Database directory)
-- @deploy/03_packages/16_pkg_api_client_pcs_details.sql

-- Check that it compiled successfully
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PKG_API_CLIENT_PCS_DETAILS'
ORDER BY object_type;