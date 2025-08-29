-- ===============================================================================
-- Clean up V2/Final/Fixed Naming Issues
-- Date: 2025-12-30
-- Purpose: Remove version suffixes from package names
-- ===============================================================================

-- Step 1: Check if old PKG_API_CLIENT_PCS_DETAILS exists
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_objects
    WHERE object_name = 'PKG_API_CLIENT_PCS_DETAILS'
    AND object_type = 'PACKAGE';
    
    IF v_count > 0 THEN
        -- Drop the old package
        EXECUTE IMMEDIATE 'DROP PACKAGE PKG_API_CLIENT_PCS_DETAILS';
        DBMS_OUTPUT.PUT_LINE('Dropped old PKG_API_CLIENT_PCS_DETAILS');
    END IF;
END;
/

-- Step 2: Rename PKG_API_CLIENT_PCS_DETAILS_V2 to PKG_API_CLIENT_PCS_DETAILS
-- First need to update any references to the V2 package

-- Check what references the V2 package
SELECT DISTINCT name, type 
FROM user_source 
WHERE UPPER(text) LIKE '%PKG_API_CLIENT_PCS_DETAILS_V2%'
AND name != 'PKG_API_CLIENT_PCS_DETAILS_V2';

-- Create new package with clean name (copy from V2)
-- We'll need to read the V2 package and recreate it