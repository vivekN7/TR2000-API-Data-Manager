-- ===============================================================================
-- Step 2: User Selection - Select GRANE Plant
-- Date: 2025-12-30
-- Purpose: Simulate user selecting GRANE plant in the UI
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    v_plant_id VARCHAR2(50);
    v_plant_desc VARCHAR2(255);
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 2: User Selects GRANE Plant');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Find GRANE plant
    BEGIN
        SELECT plant_id, SHORT_DESCRIPTION 
        INTO v_plant_id, v_plant_desc
        FROM PLANTS 
        WHERE plant_id = '34' 
        AND is_valid = 'Y';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: GRANE plant (ID=34) not found!');
            RAISE;
    END;
    
    -- Clear any previous selections
    DELETE FROM SELECTED_PLANTS;
    
    -- Insert user selection
    INSERT INTO SELECTED_PLANTS (plant_id, is_active, selected_by, selection_date)
    VALUES (v_plant_id, 'Y', USER, SYSDATE);
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Selected: ' || v_plant_id || ' - ' || v_plant_desc);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('User selection saved successfully');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

EXIT;