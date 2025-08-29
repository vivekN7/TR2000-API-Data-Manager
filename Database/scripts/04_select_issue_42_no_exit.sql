-- ===============================================================================
-- Step 4: User Selection - Select Issue 4.2
-- Date: 2025-12-30
-- Purpose: Simulate user selecting issue 4.2 in the UI
-- ===============================================================================
-- NOTE: This is the no_exit version - does NOT disconnect after running
--       Used for running multiple scripts in sequence

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    v_plant_id VARCHAR2(50) := '34';
    v_issue_rev VARCHAR2(50) := '4.2';
    v_issue_date DATE;
    v_found NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 4: User Selects Issue 4.2');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Verify issue exists
    BEGIN
        SELECT rev_date 
        INTO v_issue_date
        FROM ISSUES 
        WHERE plant_id = v_plant_id 
        AND issue_revision = v_issue_rev
        AND is_valid = 'Y';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: Issue 4.2 not found for GRANE!');
            DBMS_OUTPUT.PUT_LINE('Please run 03_load_issues_for_selected.sql first');
            RAISE;
    END;
    
    -- Clear any previous issue selections
    DELETE FROM SELECTED_ISSUES;
    
    -- Insert user selection
    INSERT INTO SELECTED_ISSUES (plant_id, issue_revision, is_active, selected_by, selection_date)
    VALUES (v_plant_id, v_issue_rev, 'Y', USER, SYSDATE);
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Selected: Plant ' || v_plant_id || ' / Issue ' || v_issue_rev);
    DBMS_OUTPUT.PUT_LINE('Issue Date: ' || TO_CHAR(v_issue_date, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('User selection saved successfully');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

