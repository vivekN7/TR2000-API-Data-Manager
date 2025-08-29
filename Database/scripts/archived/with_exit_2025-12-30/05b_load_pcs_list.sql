-- ===============================================================================
-- Step 5b: Load PCS List for Plant
-- Date: 2025-12-30
-- Purpose: Load all PCS revisions for the plant
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_plant_id VARCHAR2(50) := '34';
    v_pcs_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 5b: Loading PCS List for GRANE');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Check if we have PCS references first
    SELECT COUNT(*) INTO v_pcs_count
    FROM PCS_REFERENCES 
    WHERE plant_id = v_plant_id 
    AND is_valid = 'Y';
    
    DBMS_OUTPUT.PUT_LINE('PCS References found: ' || v_pcs_count);
    
    IF v_pcs_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Calling refresh_plant_pcs_list...');
        
        -- Load PCS list
        pkg_api_client_pcs_details.refresh_plant_pcs_list(
            p_plant_id => v_plant_id,
            p_status => v_status,
            p_message => v_msg
        );
        
        DBMS_OUTPUT.PUT_LINE('Result: ' || v_status);
        DBMS_OUTPUT.PUT_LINE('Message: ' || v_msg);
        
        -- Check what was loaded
        SELECT COUNT(*) INTO v_pcs_count FROM PCS_LIST WHERE plant_id = v_plant_id;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('PCS List entries loaded: ' || v_pcs_count);
        
        -- Show some details
        FOR p IN (SELECT pcs_name, revision
                  FROM PCS_LIST 
                  WHERE plant_id = v_plant_id
                  AND ROWNUM <= 5
                  ORDER BY pcs_name, revision) LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || p.pcs_name || ' Rev: ' || p.revision);
        END LOOP;
        IF v_pcs_count > 5 THEN
            DBMS_OUTPUT.PUT_LINE('  ... and ' || (v_pcs_count - 5) || ' more');
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No PCS references found - skipping PCS list load');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

EXIT;