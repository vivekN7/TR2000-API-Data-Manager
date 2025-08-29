-- ===============================================================================
-- Step 5a: Load References for Selected Issue
-- Date: 2025-12-30
-- Purpose: Load all 9 reference types for the selected issue
-- ===============================================================================
-- NOTE: This is the no_exit version - does NOT disconnect after running
--       Used for running multiple scripts in sequence

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_plant_id VARCHAR2(50) := '34';
    v_issue_rev VARCHAR2(50) := '4.2';
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 5a: Loading References for Issue 4.2');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Verify selections exist
    FOR s IN (SELECT * FROM SELECTED_ISSUES WHERE is_active = 'Y') LOOP
        DBMS_OUTPUT.PUT_LINE('Selected: ' || s.plant_id || '/' || s.issue_revision);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Calling refresh_all_issue_references...');
    
    -- Load all reference types
    pkg_api_client_references.refresh_all_issue_references(
        p_plant_id => v_plant_id,
        p_issue_rev => v_issue_rev,
        p_status => v_status,
        p_message => v_msg
    );
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Result: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Message: ' || SUBSTR(v_msg, 1, 2000));
    
    -- Check what was loaded
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('References Loaded:');
    FOR r IN (
        SELECT 'PCS' as ref_type, COUNT(*) as cnt FROM PCS_REFERENCES 
        WHERE plant_id = v_plant_id AND issue_revision = v_issue_rev AND is_valid = 'Y'
        UNION ALL
        SELECT 'VDS', COUNT(*) FROM VDS_REFERENCES 
        WHERE plant_id = v_plant_id AND issue_revision = v_issue_rev AND is_valid = 'Y'
        UNION ALL
        SELECT 'MDS', COUNT(*) FROM MDS_REFERENCES 
        WHERE plant_id = v_plant_id AND issue_revision = v_issue_rev AND is_valid = 'Y'
        UNION ALL
        SELECT 'SC', COUNT(*) FROM SC_REFERENCES 
        WHERE plant_id = v_plant_id AND issue_revision = v_issue_rev AND is_valid = 'Y'
        UNION ALL
        SELECT 'VSM', COUNT(*) FROM VSM_REFERENCES 
        WHERE plant_id = v_plant_id AND issue_revision = v_issue_rev AND is_valid = 'Y'
        UNION ALL
        SELECT 'EDS', COUNT(*) FROM EDS_REFERENCES 
        WHERE plant_id = v_plant_id AND issue_revision = v_issue_rev AND is_valid = 'Y'
        UNION ALL
        SELECT 'ESK', COUNT(*) FROM ESK_REFERENCES 
        WHERE plant_id = v_plant_id AND issue_revision = v_issue_rev AND is_valid = 'Y'
        UNION ALL
        SELECT 'VSK', COUNT(*) FROM VSK_REFERENCES 
        WHERE plant_id = v_plant_id AND issue_revision = v_issue_rev AND is_valid = 'Y'
        UNION ALL
        SELECT 'PIPE_ELEMENT', COUNT(*) FROM PIPE_ELEMENT_REFERENCES 
        WHERE plant_id = v_plant_id AND issue_revision = v_issue_rev AND is_valid = 'Y'
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || r.ref_type || ': ' || r.cnt);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

