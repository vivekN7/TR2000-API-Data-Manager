SET SERVEROUTPUT ON
SET LINESIZE 200

-- Test with existing data in ETL_FILTER
DECLARE
    v_count NUMBER;
    v_error VARCHAR2(4000);
BEGIN
    -- Check what's in ETL_FILTER
    SELECT COUNT(*) INTO v_count FROM ETL_FILTER;
    DBMS_OUTPUT.PUT_LINE('Found ' || v_count || ' ETL_FILTER records');
    
    -- Check if we have any data in RAW_JSON
    SELECT COUNT(*) INTO v_count FROM RAW_JSON;
    DBMS_OUTPUT.PUT_LINE('Found ' || v_count || ' RAW_JSON records');
    
    -- Check reference tables
    SELECT COUNT(*) INTO v_count FROM PCS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('PCS_REFERENCES: ' || v_count || ' records');
    
    SELECT COUNT(*) INTO v_count FROM VDS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('VDS_REFERENCES: ' || v_count || ' records');
    
    SELECT COUNT(*) INTO v_count FROM PCS_LIST;
    DBMS_OUTPUT.PUT_LINE('PCS_LIST: ' || v_count || ' records');
    
    -- Try running a small ETL test
    BEGIN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Testing ETL run...');
        PKG_MAIN_ETL_CONTROL.run_full_etl;
        DBMS_OUTPUT.PUT_LINE('ETL completed successfully!');
    EXCEPTION
        WHEN OTHERS THEN
            v_error := SQLERRM;
            DBMS_OUTPUT.PUT_LINE('ETL test encountered error: ' || v_error);
    END;
    
    -- Check results after ETL
    SELECT COUNT(*) INTO v_count FROM PCS_REFERENCES;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('After ETL - PCS_REFERENCES: ' || v_count || ' records');
END;
/

EXIT;
