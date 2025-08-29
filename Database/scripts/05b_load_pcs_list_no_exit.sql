-- ===============================================================================
-- Step 5b: Load PCS List for All Plants with Selected Issues
-- Date: 2025-08-29
-- Purpose: Load all PCS revisions for each plant that has selected issues
-- ===============================================================================
-- NOTE: This is the no_exit version - does NOT disconnect after running
--       Used for running multiple scripts in sequence

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_pcs_count NUMBER;
    v_total_pcs NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 5b: Loading PCS List for Selected Plants');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Loop through each unique plant that has selected issues
    FOR plant IN (SELECT DISTINCT si.plant_id, p.short_description
                  FROM SELECTED_ISSUES si
                  JOIN PLANTS p ON p.plant_id = si.plant_id
                  WHERE si.is_active = 'Y'
                  ORDER BY si.plant_id) LOOP
        
        -- Check if we have PCS references for this plant
        SELECT COUNT(*) INTO v_pcs_count
        FROM PCS_REFERENCES 
        WHERE plant_id = plant.plant_id 
        AND is_valid = 'Y';
        
        IF v_pcs_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Plant ' || plant.plant_id || ' (' || plant.short_description || '):');
            DBMS_OUTPUT.PUT_LINE('  PCS References found: ' || v_pcs_count);
            DBMS_OUTPUT.PUT_LINE('  Loading PCS list from API...');
            
            -- Load PCS list for this plant
            pkg_api_client_pcs_details.refresh_plant_pcs_list(
                p_plant_id => plant.plant_id,
                p_status => v_status,
                p_message => v_msg
            );
            
            DBMS_OUTPUT.PUT_LINE('  Result: ' || v_status);
            
            IF v_status = 'SUCCESS' THEN
                -- Check what was loaded
                SELECT COUNT(*) INTO v_pcs_count 
                FROM PCS_LIST 
                WHERE plant_id = plant.plant_id
                AND is_valid = 'Y';
                
                DBMS_OUTPUT.PUT_LINE('  PCS List entries loaded: ' || v_pcs_count);
                v_total_pcs := v_total_pcs + v_pcs_count;
                
                -- Show sample entries
                FOR p IN (SELECT pcs_name, revision
                          FROM PCS_LIST
                          WHERE plant_id = plant.plant_id
                          AND is_valid = 'Y'
                          AND ROWNUM <= 3
                          ORDER BY pcs_name, revision) LOOP
                    DBMS_OUTPUT.PUT_LINE('    Sample: ' || p.pcs_name || ' Rev: ' || p.revision);
                END LOOP;
                
                IF v_pcs_count > 3 THEN
                    DBMS_OUTPUT.PUT_LINE('    ... and ' || (v_pcs_count - 3) || ' more');
                END IF;
            ELSE
                DBMS_OUTPUT.PUT_LINE('  Error: ' || v_msg);
            END IF;
        ELSE
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Plant ' || plant.plant_id || ' (' || plant.short_description || '): No PCS references - skipping');
        END IF;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Total PCS List entries loaded: ' || v_total_pcs);
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/