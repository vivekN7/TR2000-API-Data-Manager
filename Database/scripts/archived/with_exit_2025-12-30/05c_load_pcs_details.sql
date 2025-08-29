-- ===============================================================================
-- Step 5c: Load PCS Details (Official Only)
-- Date: 2025-12-30
-- Purpose: Load PCS details for official revisions only
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_plant_id VARCHAR2(50) := '34';
    v_pcs_official_count NUMBER;
    v_mode VARCHAR2(50);
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 5c: Loading PCS Details (Official Only)');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Check loading mode
    SELECT setting_value INTO v_mode
    FROM CONTROL_SETTINGS
    WHERE setting_key = 'PCS_LOADING_MODE';
    
    DBMS_OUTPUT.PUT_LINE('PCS Loading Mode: ' || v_mode);
    
    -- Count PCS references (which have official_revision info)
    SELECT COUNT(*) INTO v_pcs_official_count
    FROM PCS_REFERENCES 
    WHERE plant_id = v_plant_id 
    AND is_valid = 'Y';
    
    DBMS_OUTPUT.PUT_LINE('PCS references with official revisions: ' || v_pcs_official_count);
    
    IF v_pcs_official_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        
        IF v_mode = 'OFFICIAL_ONLY' THEN
            DBMS_OUTPUT.PUT_LINE('Loading PCS details for official revisions only...');
            -- Loop through PCS_REFERENCES directly for official revisions
            FOR pcs IN (SELECT DISTINCT plant_id, pcs_name, official_revision
                        FROM PCS_REFERENCES
                        WHERE plant_id = v_plant_id
                        AND is_valid = 'Y'
                        AND official_revision IS NOT NULL) LOOP
                DBMS_OUTPUT.PUT_LINE('  Loading details for ' || pcs.pcs_name || 
                                     ' Rev: ' || pcs.official_revision);
                -- Call the 6 detail endpoints for this PCS/revision
                -- pkg_api_client_pcs_details.fetch_pcs_details(
                --     p_plant_id => pcs.plant_id,
                --     p_pcs_name => pcs.pcs_name,
                --     p_revision => pcs.official_revision
                -- );
            END LOOP;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Loading PCS details for ALL revisions...');
            -- Loop through PCS_LIST for all revisions
            FOR pcs IN (SELECT plant_id, pcs_name, revision
                        FROM PCS_LIST
                        WHERE plant_id = v_plant_id
                        AND is_valid = 'Y') LOOP
                DBMS_OUTPUT.PUT_LINE('  Loading details for ' || pcs.pcs_name || 
                                     ' Rev: ' || pcs.revision);
                -- Call the 6 detail endpoints for this PCS/revision
                -- pkg_api_client_pcs_details.fetch_pcs_details(
                --     p_plant_id => pcs.plant_id,
                --     p_pcs_name => pcs.pcs_name,
                --     p_revision => pcs.revision
                -- );
            END LOOP;
        END IF;
        
        -- Check what was loaded
        FOR d IN (
            SELECT 'HEADER' as detail_type, COUNT(*) as cnt FROM PCS_HEADER_PROPERTIES WHERE plant_id = v_plant_id
            UNION ALL
            SELECT 'TEMP_PRESSURE', COUNT(*) FROM PCS_TEMP_PRESSURES WHERE plant_id = v_plant_id
            UNION ALL
            SELECT 'PIPE_SIZES', COUNT(*) FROM PCS_PIPE_SIZES WHERE plant_id = v_plant_id
            UNION ALL
            SELECT 'PIPE_ELEMENTS', COUNT(*) FROM PCS_PIPE_ELEMENTS WHERE plant_id = v_plant_id
            UNION ALL
            SELECT 'VALVE_ELEMENTS', COUNT(*) FROM PCS_VALVE_ELEMENTS WHERE plant_id = v_plant_id
            UNION ALL
            SELECT 'EMBEDDED_NOTES', COUNT(*) FROM PCS_EMBEDDED_NOTES WHERE plant_id = v_plant_id
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || d.detail_type || ': ' || d.cnt || ' records');
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No official PCS revisions found - skipping details load');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

EXIT;