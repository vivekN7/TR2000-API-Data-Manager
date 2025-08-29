-- ===============================================================================
-- Step 5a: Load References for All Selected Issues
-- Date: 2025-08-29
-- Purpose: Load all 9 reference types for each selected issue
-- ===============================================================================
-- NOTE: This is the no_exit version - does NOT disconnect after running
--       Used for running multiple scripts in sequence

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
    v_count NUMBER := 0;
    v_total_refs NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Step 5a: Loading References for Selected Issues');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- Count selected issues
    SELECT COUNT(*) INTO v_count
    FROM SELECTED_ISSUES
    WHERE is_active = 'Y';
    
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: No active selected issues found!');
        DBMS_OUTPUT.PUT_LINE('Please select issues before loading references.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Active selected issues: ' || v_count);
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Loop through all selected issues
        FOR issue IN (SELECT plant_id, issue_revision
                      FROM SELECTED_ISSUES
                      WHERE is_active = 'Y'
                      ORDER BY plant_id, issue_revision) LOOP
            
            DBMS_OUTPUT.PUT_LINE('Loading references for: ' || issue.plant_id || '/' || issue.issue_revision);
            
            -- Call the refresh procedure for this issue
            pkg_api_client_references.refresh_all_issue_references(
                p_plant_id => issue.plant_id,
                p_issue_rev => issue.issue_revision,
                p_status => v_status,
                p_message => v_msg
            );
            
            DBMS_OUTPUT.PUT_LINE('  Result: ' || v_status);
            IF v_status != 'SUCCESS' THEN
                DBMS_OUTPUT.PUT_LINE('  Error: ' || v_msg);
            ELSE
                -- Show counts for this issue
                FOR ref IN (
                    SELECT 'PCS' as ref_type, COUNT(*) as cnt 
                    FROM PCS_REFERENCES 
                    WHERE plant_id = issue.plant_id 
                    AND issue_revision = issue.issue_revision 
                    AND is_valid = 'Y'
                    UNION ALL
                    SELECT 'VDS', COUNT(*) 
                    FROM VDS_REFERENCES 
                    WHERE plant_id = issue.plant_id 
                    AND issue_revision = issue.issue_revision 
                    AND is_valid = 'Y'
                    UNION ALL
                    SELECT 'MDS', COUNT(*) 
                    FROM MDS_REFERENCES 
                    WHERE plant_id = issue.plant_id 
                    AND issue_revision = issue.issue_revision 
                    AND is_valid = 'Y'
                    UNION ALL
                    SELECT 'Other', 
                        (SELECT COUNT(*) FROM SC_REFERENCES WHERE plant_id = issue.plant_id AND issue_revision = issue.issue_revision AND is_valid = 'Y') +
                        (SELECT COUNT(*) FROM VSM_REFERENCES WHERE plant_id = issue.plant_id AND issue_revision = issue.issue_revision AND is_valid = 'Y') +
                        (SELECT COUNT(*) FROM EDS_REFERENCES WHERE plant_id = issue.plant_id AND issue_revision = issue.issue_revision AND is_valid = 'Y') +
                        (SELECT COUNT(*) FROM ESK_REFERENCES WHERE plant_id = issue.plant_id AND issue_revision = issue.issue_revision AND is_valid = 'Y') +
                        (SELECT COUNT(*) FROM VSK_REFERENCES WHERE plant_id = issue.plant_id AND issue_revision = issue.issue_revision AND is_valid = 'Y') +
                        (SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE plant_id = issue.plant_id AND issue_revision = issue.issue_revision AND is_valid = 'Y')
                    FROM dual
                ) LOOP
                    IF ref.cnt > 0 THEN
                        DBMS_OUTPUT.PUT_LINE('    ' || ref.ref_type || ': ' || ref.cnt);
                    END IF;
                END LOOP;
            END IF;
            
            DBMS_OUTPUT.PUT_LINE('');
        END LOOP;
        
        -- Show total summary
        DBMS_OUTPUT.PUT_LINE('Summary - Total References Loaded:');
        FOR ref IN (
            SELECT 'PCS' as ref_type, COUNT(*) as cnt FROM PCS_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 'VDS', COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 'MDS', COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 'SC', COUNT(*) FROM SC_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 'VSM', COUNT(*) FROM VSM_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 'EDS', COUNT(*) FROM EDS_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 'ESK', COUNT(*) FROM ESK_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 'VSK', COUNT(*) FROM VSK_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 'PIPE_ELEMENT', COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
        ) LOOP
            IF ref.cnt > 0 THEN
                DBMS_OUTPUT.PUT_LINE('  ' || ref.ref_type || ': ' || ref.cnt);
                v_total_refs := v_total_refs + ref.cnt;
            END IF;
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('  TOTAL: ' || v_total_refs);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        RAISE;
END;
/
