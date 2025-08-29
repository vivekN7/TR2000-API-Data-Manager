-- ===============================================================================
-- Step 1: Load All Plants from API
-- Date: 2025-12-30
-- Purpose: Initial load of all plants (happens once when system starts)
-- NOTE: This is the no_exit version - does NOT disconnect after running
--       Used for running multiple scripts in sequence
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_plant_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 1: Loading All Plants from API');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Load plants from API
    pkg_api_client.refresh_plants_from_api(v_status, v_msg);
    
    -- Check results
    SELECT COUNT(*) INTO v_plant_count FROM PLANTS WHERE is_valid = 'Y';
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Result: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Plants loaded: ' || v_plant_count);
    
    IF v_status = 'SUCCESS' THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Top 10 plants:');
        FOR p IN (SELECT plant_id, SHORT_DESCRIPTION 
                  FROM PLANTS 
                  WHERE is_valid = 'Y' 
                  ORDER BY plant_id
                  FETCH FIRST 10 ROWS ONLY) LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || p.plant_id || ' - ' || p.SHORT_DESCRIPTION);
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Error: ' || v_msg);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

