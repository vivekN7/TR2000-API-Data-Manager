-- ===============================================================================
-- Debug ETL Reference Loading Issue
-- Date: 2025-12-30
-- Purpose: Trace why references don't load in run_full_etl
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Debug: ETL Reference Loading Issue');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- 1. Check SELECTED_ISSUES
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('1. Checking SELECTED_ISSUES table:');
    FOR si IN (SELECT * FROM SELECTED_ISSUES) LOOP
        DBMS_OUTPUT.PUT_LINE('  Plant: ' || si.plant_id || 
                            ', Issue: ' || si.issue_revision || 
                            ', Active: ' || si.is_active ||
                            ', Selected By: ' || si.selected_by);
    END LOOP;
    
    -- 2. Test run_references_etl_for_all_selected directly
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('2. Testing run_references_etl_for_all_selected:');
    DECLARE
        v_status VARCHAR2(50);
        v_msg VARCHAR2(4000);
    BEGIN
        pkg_etl_operations.run_references_etl_for_all_selected(v_status, v_msg);
        DBMS_OUTPUT.PUT_LINE('  Status: ' || v_status);
        DBMS_OUTPUT.PUT_LINE('  Message: ' || SUBSTR(v_msg, 1, 2000));
    END;
    
    -- 3. Check if references were loaded
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('3. References after run_references_etl_for_all_selected:');
    FOR r IN (
        SELECT 'PCS' as ref_type, COUNT(*) as cnt FROM PCS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
        UNION ALL
        SELECT 'VDS', COUNT(*) FROM VDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
        UNION ALL
        SELECT 'MDS', COUNT(*) FROM MDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || r.ref_type || ': ' || r.cnt);
    END LOOP;
    
    -- 4. Test run_references_etl_for_issue directly
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('4. Testing run_references_etl_for_issue directly:');
    DECLARE
        v_status VARCHAR2(50);
        v_msg VARCHAR2(4000);
    BEGIN
        pkg_etl_operations.run_references_etl_for_issue('34', '4.2', v_status, v_msg);
        DBMS_OUTPUT.PUT_LINE('  Status: ' || v_status);
        DBMS_OUTPUT.PUT_LINE('  Message: ' || SUBSTR(v_msg, 1, 500));
    END;
    
    -- 5. Check references again
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('5. References after run_references_etl_for_issue:');
    FOR r IN (
        SELECT 'PCS' as ref_type, COUNT(*) as cnt FROM PCS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
        UNION ALL
        SELECT 'VDS', COUNT(*) FROM VDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
        UNION ALL
        SELECT 'MDS', COUNT(*) FROM MDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || r.ref_type || ': ' || r.cnt);
    END LOOP;
    
    -- 6. Test the API client directly
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('6. Testing pkg_api_client_references directly:');
    DECLARE
        v_status VARCHAR2(50);
        v_msg VARCHAR2(4000);
    BEGIN
        pkg_api_client_references.refresh_all_issue_references('34', '4.2', v_status, v_msg);
        DBMS_OUTPUT.PUT_LINE('  Status: ' || v_status);
        DBMS_OUTPUT.PUT_LINE('  Message: ' || SUBSTR(v_msg, 1, 500));
    END;
    
    -- 7. Final check
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('7. Final reference count:');
    FOR r IN (
        SELECT 'PCS' as ref_type, COUNT(*) as cnt FROM PCS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
        UNION ALL
        SELECT 'VDS', COUNT(*) FROM VDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
        UNION ALL
        SELECT 'MDS', COUNT(*) FROM MDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2'
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || r.ref_type || ': ' || r.cnt);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
END;
/

EXIT;