-- ===============================================================================
-- Test run_full_etl with debug output
-- Date: 2025-12-30
-- Purpose: See what run_full_etl is actually doing
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Testing run_full_etl with existing data');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Show current state
    DECLARE
        v_plant_cnt NUMBER;
        v_issue_cnt NUMBER;
        v_sel_cnt NUMBER;
        v_pcs_cnt NUMBER;
        v_vds_cnt NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_plant_cnt FROM PLANTS WHERE is_valid = 'Y';
        SELECT COUNT(*) INTO v_issue_cnt FROM ISSUES WHERE plant_id = '34';
        SELECT COUNT(*) INTO v_sel_cnt FROM SELECTED_ISSUES WHERE is_active = 'Y';
        SELECT COUNT(*) INTO v_pcs_cnt FROM PCS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2';
        SELECT COUNT(*) INTO v_vds_cnt FROM VDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2';
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Current state before ETL:');
        DBMS_OUTPUT.PUT_LINE('  Plants: ' || v_plant_cnt);
        DBMS_OUTPUT.PUT_LINE('  Issues: ' || v_issue_cnt);
        DBMS_OUTPUT.PUT_LINE('  Selected Issues: ' || v_sel_cnt);
        DBMS_OUTPUT.PUT_LINE('  PCS Refs: ' || v_pcs_cnt);
        DBMS_OUTPUT.PUT_LINE('  VDS Refs: ' || v_vds_cnt);
    END;
    
    -- Run the full ETL
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Calling run_full_etl...');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Starting Full ETL Process');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    pkg_etl_operations.run_full_etl(v_status, v_msg);
    
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('ETL Process Complete');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Result:');
    DBMS_OUTPUT.PUT_LINE('  Status: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('  Message: ' || SUBSTR(v_msg, 1, 2000));
    
    -- Show final state
    DECLARE
        v_plant_cnt NUMBER;
        v_issue_cnt NUMBER;
        v_pcs_cnt NUMBER;
        v_vds_cnt NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_plant_cnt FROM PLANTS WHERE is_valid = 'Y';
        SELECT COUNT(*) INTO v_issue_cnt FROM ISSUES WHERE plant_id = '34';
        SELECT COUNT(*) INTO v_pcs_cnt FROM PCS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2';
        SELECT COUNT(*) INTO v_vds_cnt FROM VDS_REFERENCES WHERE plant_id = '34' AND issue_revision = '4.2';
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Final state after ETL:');
        DBMS_OUTPUT.PUT_LINE('  Plants: ' || v_plant_cnt);
        DBMS_OUTPUT.PUT_LINE('  Issues: ' || v_issue_cnt);
        DBMS_OUTPUT.PUT_LINE('  PCS Refs: ' || v_pcs_cnt);
        DBMS_OUTPUT.PUT_LINE('  VDS Refs: ' || v_vds_cnt);
    END;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
END;
/

EXIT;