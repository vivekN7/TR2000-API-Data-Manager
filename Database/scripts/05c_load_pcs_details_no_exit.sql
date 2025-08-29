-- ===============================================================================
-- Step 5c: Load PCS Details for Official Revisions
-- Date: 2025-08-29
-- Purpose: Load PCS details ONLY for official revisions from PCS_REFERENCES
-- ===============================================================================
-- NOTE: This is the no_exit version - does NOT disconnect after running
--       Used for running multiple scripts in sequence

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_pcs_count NUMBER;
    v_details_loaded NUMBER := 0;
    v_api_calls NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 5c: Loading PCS Details (Official Revisions Only)');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Loop through all selected issues
    FOR issue IN (SELECT plant_id, issue_revision
                  FROM SELECTED_ISSUES
                  WHERE is_active = 'Y'
                  ORDER BY plant_id, issue_revision) LOOP
        
        -- Count PCS references with official revisions for this issue
        SELECT COUNT(DISTINCT pcs_name || '|' || official_revision) INTO v_pcs_count
        FROM PCS_REFERENCES 
        WHERE plant_id = issue.plant_id
        AND issue_revision = issue.issue_revision
        AND official_revision IS NOT NULL
        AND is_valid = 'Y';
        
        IF v_pcs_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Issue ' || issue.plant_id || '/' || issue.issue_revision || ':');
            DBMS_OUTPUT.PUT_LINE('  PCS with official revisions: ' || v_pcs_count);
            DBMS_OUTPUT.PUT_LINE('  Loading details (6 endpoints per PCS)...');
            
            -- Loop through PCS_REFERENCES directly for official revisions
            -- Get DISTINCT pcs_name/official_revision combinations
            FOR pcs IN (SELECT DISTINCT pcs_name, official_revision
                        FROM PCS_REFERENCES
                        WHERE plant_id = issue.plant_id
                        AND issue_revision = issue.issue_revision
                        AND is_valid = 'Y'
                        AND official_revision IS NOT NULL
                        ORDER BY pcs_name) LOOP
                
                -- Call the 6 detail endpoints for this PCS/revision
                pkg_api_client_pcs_details.refresh_pcs_details(
                    p_plant_id => issue.plant_id,
                    p_pcs_name => pcs.pcs_name,
                    p_revision => pcs.official_revision,
                    p_status => v_status,
                    p_message => v_msg
                );
                
                v_api_calls := v_api_calls + 6; -- Each call makes 6 API requests
                
                IF v_status = 'SUCCESS' THEN
                    v_details_loaded := v_details_loaded + 1;
                    -- Show progress every 10 PCS
                    IF MOD(v_details_loaded, 10) = 0 THEN
                        DBMS_OUTPUT.PUT_LINE('    Processed ' || v_details_loaded || ' PCS...');
                    END IF;
                ELSE
                    DBMS_OUTPUT.PUT_LINE('    ERROR loading ' || pcs.pcs_name || ' Rev ' || pcs.official_revision || ': ' || v_msg);
                END IF;
            END LOOP;
            
            -- Show what was loaded for this issue
            DBMS_OUTPUT.PUT_LINE('  Details loaded for ' || v_details_loaded || ' PCS (' || v_api_calls || ' API calls)');
            
            -- Show counts by detail type
            FOR d IN (
                SELECT 'HEADER' as detail_type, COUNT(*) as cnt 
                FROM PCS_HEADER_PROPERTIES 
                WHERE plant_id = issue.plant_id
                UNION ALL
                SELECT 'TEMP_PRESSURE', COUNT(*) 
                FROM PCS_TEMP_PRESSURES 
                WHERE plant_id = issue.plant_id
                UNION ALL
                SELECT 'PIPE_SIZES', COUNT(*) 
                FROM PCS_PIPE_SIZES 
                WHERE plant_id = issue.plant_id
                UNION ALL
                SELECT 'PIPE_ELEMENTS', COUNT(*) 
                FROM PCS_PIPE_ELEMENTS 
                WHERE plant_id = issue.plant_id
                UNION ALL
                SELECT 'VALVE_ELEMENTS', COUNT(*) 
                FROM PCS_VALVE_ELEMENTS 
                WHERE plant_id = issue.plant_id
                UNION ALL
                SELECT 'EMBEDDED_NOTES', COUNT(*) 
                FROM PCS_EMBEDDED_NOTES 
                WHERE plant_id = issue.plant_id
            ) LOOP
                IF d.cnt > 0 THEN
                    DBMS_OUTPUT.PUT_LINE('    ' || d.detail_type || ': ' || d.cnt || ' records');
                END IF;
            END LOOP;
        ELSE
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Issue ' || issue.plant_id || '/' || issue.issue_revision || ': No PCS with official revisions');
        END IF;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Total PCS details loaded: ' || v_details_loaded);
    DBMS_OUTPUT.PUT_LINE('Total API calls made: ' || v_api_calls);
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/