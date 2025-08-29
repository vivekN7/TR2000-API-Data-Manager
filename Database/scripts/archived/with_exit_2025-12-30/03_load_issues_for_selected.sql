-- ===============================================================================
-- Step 3: Load Issues for Selected Plant
-- Date: 2025-12-30
-- Purpose: Load issues for the plant(s) the user selected
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_issue_count NUMBER;
    v_plant_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 3: Loading Issues for Selected Plants');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Process each selected plant
    FOR plant IN (SELECT plant_id, is_active 
                  FROM SELECTED_PLANTS 
                  WHERE is_active = 'Y') LOOP
        
        v_plant_count := v_plant_count + 1;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Loading issues for plant: ' || plant.plant_id);
        
        -- Load issues from API
        pkg_api_client.refresh_issues_from_api(plant.plant_id, v_status, v_msg);
        
        -- Check results
        SELECT COUNT(*) INTO v_issue_count 
        FROM ISSUES 
        WHERE plant_id = plant.plant_id 
        AND is_valid = 'Y';
        
        DBMS_OUTPUT.PUT_LINE('Result: ' || v_status);
        DBMS_OUTPUT.PUT_LINE('Issues loaded: ' || v_issue_count);
        
        IF v_issue_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Available issues:');
            FOR i IN (SELECT issue_revision, rev_date 
                      FROM ISSUES 
                      WHERE plant_id = plant.plant_id 
                      AND is_valid = 'Y' 
                      ORDER BY issue_revision) LOOP
                DBMS_OUTPUT.PUT_LINE('  ' || i.issue_revision || ' (Date: ' || 
                                     TO_CHAR(i.rev_date, 'YYYY-MM-DD') || ')');
            END LOOP;
        END IF;
    END LOOP;
    
    IF v_plant_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('WARNING: No plants selected!');
        DBMS_OUTPUT.PUT_LINE('Please run 02_select_grane.sql first');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

EXIT;