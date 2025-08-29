-- ===============================================================================
-- Step 5d: Load VDS List (Global)
-- Date: 2025-12-30
-- Purpose: Load global VDS list (not plant-specific)
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_vds_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 5d: Loading VDS List (Global)');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Check if VDS list already loaded
    SELECT COUNT(*) INTO v_vds_count FROM VDS_LIST WHERE is_valid = 'Y';
    
    DBMS_OUTPUT.PUT_LINE('Current VDS list entries: ' || v_vds_count);
    
    IF v_vds_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Loading VDS list from API...');
        DBMS_OUTPUT.PUT_LINE('WARNING: This loads 50,000+ records and may take time');
        
        -- Call VDS list API
        pkg_api_client_vds.fetch_vds_list(
            p_status => v_status,
            p_message => v_msg
        );
        
        DBMS_OUTPUT.PUT_LINE('Result: ' || v_status);
        DBMS_OUTPUT.PUT_LINE('Message: ' || SUBSTR(v_msg, 1, 500));
        
        -- Check what was loaded
        SELECT COUNT(*) INTO v_vds_count FROM VDS_LIST WHERE is_valid = 'Y';
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('VDS list entries loaded: ' || v_vds_count);
    ELSE
        DBMS_OUTPUT.PUT_LINE('VDS list already loaded - skipping');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

EXIT;