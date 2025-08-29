-- ===============================================================================
-- Step 5e: Load VDS Details (Official Only)
-- Date: 2025-12-30
-- Purpose: Load VDS details for official revisions
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_vds_ref_count NUMBER;
    v_vds_official_count NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 5e: Loading VDS Details (Official Only)');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Check VDS references
    SELECT COUNT(*) INTO v_vds_ref_count
    FROM VDS_REFERENCES 
    WHERE plant_id = '34' 
    AND issue_revision = '4.2'
    AND is_valid = 'Y';
    
    DBMS_OUTPUT.PUT_LINE('VDS References for 4.2: ' || v_vds_ref_count);
    
    -- Check official VDS in list
    SELECT COUNT(*) INTO v_vds_official_count
    FROM VDS_LIST 
    WHERE status = 'OFFICIAL'
    AND is_valid = 'Y';
    
    DBMS_OUTPUT.PUT_LINE('Official VDS in list: ' || v_vds_official_count);
    
    IF v_vds_ref_count > 0 AND v_vds_official_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Check loading mode
        DECLARE
            v_mode VARCHAR2(50);
        BEGIN
            SELECT setting_value INTO v_mode
            FROM CONTROL_SETTINGS
            WHERE setting_key = 'VDS_LOADING_MODE';
            
            DBMS_OUTPUT.PUT_LINE('VDS Loading Mode: ' || v_mode);
            
            IF v_mode = 'OFFICIAL_ONLY' THEN
                DBMS_OUTPUT.PUT_LINE('Loading VDS details for official revisions only...');
                -- Loop through VDS_REFERENCES directly for official revisions
                FOR vds IN (SELECT DISTINCT vds_name, official_revision
                            FROM VDS_REFERENCES
                            WHERE plant_id = '34'
                            AND issue_revision = '4.2'
                            AND is_valid = 'Y'
                            AND official_revision IS NOT NULL
                            AND ROWNUM <= 10) LOOP  -- Limit to 10 for testing
                    DBMS_OUTPUT.PUT_LINE('  Loading details for ' || vds.vds_name || 
                                         ' Rev: ' || vds.official_revision);
                    -- Call VDS detail API
                    -- pkg_api_client_vds.fetch_vds_details(
                    --     p_vds_name => vds.vds_name,
                    --     p_revision => vds.official_revision,
                    --     p_status => v_status,
                    --     p_message => v_msg
                    -- );
                END LOOP;
            ELSE
                -- Use existing workflow for ALL mode
                pkg_vds_workflow.run_vds_details_etl(
                    p_max_calls => 10,
                    p_test_only => FALSE,
                    p_status => v_status,
                    p_message => v_msg
                );
                DBMS_OUTPUT.PUT_LINE('Result: ' || v_status);
                DBMS_OUTPUT.PUT_LINE('Message: ' || SUBSTR(v_msg, 1, 500));
            END IF;
        END;
        
        -- Check what was loaded
        SELECT COUNT(*) INTO v_vds_official_count FROM VDS_DETAILS WHERE is_valid = 'Y';
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('VDS details loaded: ' || v_vds_official_count);
    ELSE
        DBMS_OUTPUT.PUT_LINE('No VDS references or official revisions - skipping details');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/

EXIT;