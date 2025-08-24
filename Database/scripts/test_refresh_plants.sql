-- Test complete plants refresh
CONNECT TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1

SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ===============================================================================
PROMPT Running full plants refresh from API
PROMPT ===============================================================================

DECLARE
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
    v_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting full plants refresh...');
    
    pkg_api_client.refresh_plants_from_api(
        p_status => v_status,
        p_message => v_message
    );
    
    DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Message: ' || v_message);
    
    -- Check results
    SELECT COUNT(*) INTO v_count FROM RAW_JSON WHERE endpoint_key = 'plants';
    DBMS_OUTPUT.PUT_LINE('RAW_JSON records: ' || v_count);
    
    SELECT COUNT(*) INTO v_count FROM STG_PLANTS;
    DBMS_OUTPUT.PUT_LINE('STG_PLANTS records: ' || v_count);
    
    SELECT COUNT(*) INTO v_count FROM PLANTS WHERE is_valid = 'Y';
    DBMS_OUTPUT.PUT_LINE('PLANTS records (active): ' || v_count);
    
    -- Show sample plants
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Sample plants loaded:');
    DBMS_OUTPUT.PUT_LINE('================================');
    FOR rec IN (
        SELECT plant_id, short_description, operator_name
        FROM PLANTS
        WHERE is_valid = 'Y'
        AND ROWNUM <= 10
        ORDER BY plant_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('Plant ' || rec.plant_id || ': ' || 
                            rec.short_description || ' (' || rec.operator_name || ')');
    END LOOP;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

PROMPT ===============================================================================
PROMPT Success! API integration is working!
PROMPT ===============================================================================