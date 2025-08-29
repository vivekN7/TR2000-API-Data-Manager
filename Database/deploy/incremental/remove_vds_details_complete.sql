-- ===============================================================================
-- Remove VDS_DETAILS and All Related Objects
-- Date: 2025-08-29
-- Purpose: VDS details require thousands of API calls and are not needed
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Removing VDS_DETAILS and related objects...');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Drop views that reference VDS_DETAILS
    FOR v IN (SELECT view_name FROM user_views 
              WHERE upper(text) LIKE '%VDS_DETAILS%') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
            DBMS_OUTPUT.PUT_LINE('Dropped view: ' || v.view_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Could not drop view ' || v.view_name || ': ' || SQLERRM);
        END;
    END LOOP;
    
    -- Drop packages that handle VDS details
    BEGIN
        EXECUTE IMMEDIATE 'DROP PACKAGE pkg_vds_workflow';
        DBMS_OUTPUT.PUT_LINE('Dropped package: pkg_vds_workflow');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Could not drop pkg_vds_workflow: ' || SQLERRM);
    END;
    
    BEGIN
        EXECUTE IMMEDIATE 'DROP PACKAGE pkg_parse_vds';
        DBMS_OUTPUT.PUT_LINE('Dropped package: pkg_parse_vds');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Could not drop pkg_parse_vds: ' || SQLERRM);
    END;
    
    BEGIN
        EXECUTE IMMEDIATE 'DROP PACKAGE pkg_upsert_vds';
        DBMS_OUTPUT.PUT_LINE('Dropped package: pkg_upsert_vds');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Could not drop pkg_upsert_vds: ' || SQLERRM);
    END;
    
    -- Drop the tables
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE VDS_DETAILS CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('Dropped table: VDS_DETAILS');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Could not drop VDS_DETAILS: ' || SQLERRM);
    END;
    
    BEGIN
        EXECUTE IMMEDIATE 'DROP TABLE STG_VDS_DETAILS CASCADE CONSTRAINTS';
        DBMS_OUTPUT.PUT_LINE('Dropped table: STG_VDS_DETAILS');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Could not drop STG_VDS_DETAILS: ' || SQLERRM);
    END;
    
    -- Remove VDS detail endpoint from CONTROL_ENDPOINTS if exists
    DELETE FROM CONTROL_ENDPOINTS WHERE endpoint_key = 'VDS_DETAILS';
    IF SQL%ROWCOUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Removed VDS_DETAILS from CONTROL_ENDPOINTS');
    END IF;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('VDS_DETAILS removal complete!');
    DBMS_OUTPUT.PUT_LINE('===============================================');
END;
/

-- Verify removal
SELECT 'Remaining VDS objects:' as info FROM dual;
SELECT object_type, object_name 
FROM user_objects 
WHERE object_name LIKE '%VDS%DETAIL%'
ORDER BY object_type, object_name;

EXIT;