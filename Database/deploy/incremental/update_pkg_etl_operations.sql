-- ===============================================================================
-- Update PKG_ETL_OPERATIONS with Separated Procedures
-- Date: 2025-08-29
-- Purpose: Replace monolithic run_full_etl with modular procedures
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- Drop and recreate package specification
CREATE OR REPLACE PACKAGE pkg_etl_operations AS

    -- =========================================================================
    -- Main ETL Procedures (Separated for Control)
    -- =========================================================================
    
    -- Step 1: Load all plants from API
    PROCEDURE load_plants(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- Step 2: Load issues for plants in SELECTED_PLANTS
    PROCEDURE load_issues_for_selected_plants(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- Step 3: Run complete ETL for issues in SELECTED_ISSUES
    PROCEDURE run_etl_for_selected_issues(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- Step 4: Clear all data (except control tables)
    PROCEDURE clear_all_data(
        p_preserve_selections IN BOOLEAN DEFAULT FALSE,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- =========================================================================
    -- Selection Management Procedures
    -- =========================================================================
    
    -- Add a plant to selections
    PROCEDURE select_plant(
        p_plant_id  IN VARCHAR2,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- Add an issue to selections
    PROCEDURE select_issue(
        p_plant_id       IN VARCHAR2,
        p_issue_revision IN VARCHAR2,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    );
    
    -- Clear all selections
    PROCEDURE clear_selections(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );
    
    -- Show current selections
    PROCEDURE show_selections;
    
    -- =========================================================================
    -- Legacy procedures (kept for compatibility)
    -- =========================================================================
    
    PROCEDURE run_plants_etl(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );

    PROCEDURE run_issues_etl_for_plant(
        p_plant_id  IN VARCHAR2,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );

    PROCEDURE run_references_etl_for_issue(
        p_plant_id       IN VARCHAR2,
        p_issue_revision IN VARCHAR2,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    );

    PROCEDURE run_references_etl_for_all_selected(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    );

END pkg_etl_operations;
/

-- Create package body
CREATE OR REPLACE PACKAGE BODY pkg_etl_operations AS

    -- =========================================================================
    -- Step 1: Load all plants from API
    -- =========================================================================
    PROCEDURE load_plants(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_start_time TIMESTAMP := SYSTIMESTAMP;
        v_run_id NUMBER;
    BEGIN
        -- Create ETL run log entry
        INSERT INTO ETL_RUN_LOG (
            run_id, run_type, start_time, status, initiated_by
        ) VALUES (
            etl_run_log_seq.NEXTVAL, 'LOAD_PLANTS', v_start_time, 'RUNNING', USER
        ) RETURNING run_id INTO v_run_id;
        
        -- Call existing API client to refresh plants
        pkg_api_client.refresh_plants_from_api(p_status, p_message);
        
        -- Update run log
        UPDATE ETL_RUN_LOG
        SET end_time = SYSTIMESTAMP,
            status = p_status,
            records_processed = (SELECT COUNT(*) FROM PLANTS WHERE is_valid = 'Y'),
            duration_seconds = EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)),
            notes = p_message
        WHERE run_id = v_run_id;
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
            
            UPDATE ETL_RUN_LOG
            SET end_time = SYSTIMESTAMP,
                status = 'ERROR',
                notes = SQLERRM
            WHERE run_id = v_run_id;
            
            ROLLBACK;
            RAISE;
    END load_plants;
    
    -- =========================================================================
    -- Step 2: Load issues for plants in SELECTED_PLANTS
    -- =========================================================================
    PROCEDURE load_issues_for_selected_plants(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_start_time TIMESTAMP := SYSTIMESTAMP;
        v_run_id NUMBER;
        v_plant_count NUMBER := 0;
        v_issues_loaded NUMBER := 0;
        v_plant_status VARCHAR2(50);
        v_plant_msg VARCHAR2(4000);
    BEGIN
        -- Count selected plants
        SELECT COUNT(*) INTO v_plant_count
        FROM SELECTED_PLANTS
        WHERE is_active = 'Y';
        
        IF v_plant_count = 0 THEN
            p_status := 'WARNING';
            p_message := 'No plants selected. Use select_plant procedure first.';
            RETURN;
        END IF;
        
        -- Create ETL run log entry
        INSERT INTO ETL_RUN_LOG (
            run_id, run_type, start_time, status, initiated_by
        ) VALUES (
            etl_run_log_seq.NEXTVAL, 'LOAD_ISSUES_FOR_SELECTED', v_start_time, 'RUNNING', USER
        ) RETURNING run_id INTO v_run_id;
        
        -- Loop through selected plants
        FOR plant IN (SELECT sp.plant_id, p.short_description
                      FROM SELECTED_PLANTS sp
                      JOIN PLANTS p ON p.plant_id = sp.plant_id
                      WHERE sp.is_active = 'Y'
                      ORDER BY sp.plant_id) LOOP
            
            -- Load issues for this plant
            pkg_api_client.refresh_issues_from_api(
                p_plant_id => plant.plant_id,
                p_status => v_plant_status,
                p_message => v_plant_msg
            );
            
            IF v_plant_status = 'SUCCESS' THEN
                SELECT COUNT(*) INTO v_issues_loaded
                FROM ISSUES
                WHERE plant_id = plant.plant_id
                AND is_valid = 'Y';
                
                DBMS_OUTPUT.PUT_LINE('Plant ' || plant.plant_id || ' (' || plant.short_description || '): ' || 
                                     v_issues_loaded || ' issues loaded');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Plant ' || plant.plant_id || ' ERROR: ' || v_plant_msg);
            END IF;
        END LOOP;
        
        -- Update run log
        UPDATE ETL_RUN_LOG
        SET end_time = SYSTIMESTAMP,
            status = 'SUCCESS',
            records_processed = (SELECT COUNT(*) FROM ISSUES WHERE is_valid = 'Y'),
            duration_seconds = EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)),
            notes = 'Loaded issues for ' || v_plant_count || ' plants'
        WHERE run_id = v_run_id;
        
        p_status := 'SUCCESS';
        p_message := 'Issues loaded for ' || v_plant_count || ' plants';
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
            
            UPDATE ETL_RUN_LOG
            SET end_time = SYSTIMESTAMP,
                status = 'ERROR',
                notes = SQLERRM
            WHERE run_id = v_run_id;
            
            ROLLBACK;
            RAISE;
    END load_issues_for_selected_plants;
    
    -- =========================================================================
    -- Step 3: Run complete ETL for issues in SELECTED_ISSUES
    -- =========================================================================
    PROCEDURE run_etl_for_selected_issues(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_start_time TIMESTAMP := SYSTIMESTAMP;
        v_run_id NUMBER;
        v_issue_count NUMBER := 0;
        v_ref_status VARCHAR2(50);
        v_ref_msg VARCHAR2(4000);
        v_pcs_status VARCHAR2(50);
        v_pcs_msg VARCHAR2(4000);
        v_vds_status VARCHAR2(50);
        v_vds_msg VARCHAR2(4000);
        v_total_refs NUMBER := 0;
        v_total_pcs_details NUMBER := 0;
    BEGIN
        -- Count selected issues
        SELECT COUNT(*) INTO v_issue_count
        FROM SELECTED_ISSUES
        WHERE is_active = 'Y';
        
        IF v_issue_count = 0 THEN
            p_status := 'WARNING';
            p_message := 'No issues selected. Use select_issue procedure first.';
            RETURN;
        END IF;
        
        -- Create ETL run log entry
        INSERT INTO ETL_RUN_LOG (
            run_id, run_type, start_time, status, initiated_by
        ) VALUES (
            etl_run_log_seq.NEXTVAL, 'RUN_ETL_FOR_SELECTED', v_start_time, 'RUNNING', USER
        ) RETURNING run_id INTO v_run_id;
        
        DBMS_OUTPUT.PUT_LINE('Running ETL for ' || v_issue_count || ' selected issues...');
        
        -- Step 3a: Load references for each selected issue
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Loading references...');
        FOR issue IN (SELECT plant_id, issue_revision
                      FROM SELECTED_ISSUES
                      WHERE is_active = 'Y'
                      ORDER BY plant_id, issue_revision) LOOP
            
            pkg_api_client_references.refresh_all_issue_references(
                p_plant_id => issue.plant_id,
                p_issue_rev => issue.issue_revision,
                p_status => v_ref_status,
                p_message => v_ref_msg
            );
            
            IF v_ref_status = 'SUCCESS' THEN
                DBMS_OUTPUT.PUT_LINE('  ' || issue.plant_id || '/' || issue.issue_revision || ': References loaded');
            ELSE
                DBMS_OUTPUT.PUT_LINE('  ' || issue.plant_id || '/' || issue.issue_revision || ' ERROR: ' || v_ref_msg);
            END IF;
        END LOOP;
        
        -- Count total references loaded
        SELECT COUNT(*) INTO v_total_refs
        FROM (
            SELECT 1 FROM PCS_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM VDS_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM MDS_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM SC_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM VSM_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM EDS_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM ESK_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM VSK_REFERENCES WHERE is_valid = 'Y'
            UNION ALL
            SELECT 1 FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
        );
        
        -- Step 3b: Load PCS list for each unique plant with selected issues
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Loading PCS lists...');
        FOR plant IN (SELECT DISTINCT si.plant_id, p.short_description
                      FROM SELECTED_ISSUES si
                      JOIN PLANTS p ON p.plant_id = si.plant_id
                      WHERE si.is_active = 'Y'
                      ORDER BY si.plant_id) LOOP
            
            pkg_api_client_pcs_details.refresh_plant_pcs_list(
                p_plant_id => plant.plant_id,
                p_status => v_pcs_status,
                p_message => v_pcs_msg
            );
            
            IF v_pcs_status = 'SUCCESS' THEN
                DBMS_OUTPUT.PUT_LINE('  Plant ' || plant.plant_id || ': PCS list loaded');
            ELSE
                DBMS_OUTPUT.PUT_LINE('  Plant ' || plant.plant_id || ' ERROR: ' || v_pcs_msg);
            END IF;
        END LOOP;
        
        -- Step 3c: Load PCS details for official revisions only
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Loading PCS details for official revisions...');
        FOR pcs IN (SELECT DISTINCT pr.plant_id, pr.pcs_name, pr.official_revision
                    FROM PCS_REFERENCES pr
                    JOIN SELECTED_ISSUES si ON si.plant_id = pr.plant_id 
                                            AND si.issue_revision = pr.issue_revision
                    WHERE pr.is_valid = 'Y'
                    AND pr.official_revision IS NOT NULL
                    AND si.is_active = 'Y'
                    ORDER BY pr.plant_id, pr.pcs_name) LOOP
            
            pkg_api_client_pcs_details.refresh_pcs_details(
                p_plant_id => pcs.plant_id,
                p_pcs_name => pcs.pcs_name,
                p_revision => pcs.official_revision,
                p_status => v_pcs_status,
                p_message => v_pcs_msg
            );
            
            IF v_pcs_status = 'SUCCESS' THEN
                v_total_pcs_details := v_total_pcs_details + 1;
                IF MOD(v_total_pcs_details, 10) = 0 THEN
                    DBMS_OUTPUT.PUT_LINE('  Processed ' || v_total_pcs_details || ' PCS details...');
                END IF;
            END IF;
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('  Total PCS details loaded: ' || v_total_pcs_details);
        
        -- Step 3d: Load global VDS list (once)
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Loading global VDS list...');
        pkg_api_client_vds.fetch_vds_list(
            p_status => v_vds_status,
            p_message => v_vds_msg
        );
        
        IF v_vds_status = 'SUCCESS' THEN
            DBMS_OUTPUT.PUT_LINE('  VDS list loaded successfully');
        ELSE
            DBMS_OUTPUT.PUT_LINE('  VDS list ERROR: ' || v_vds_msg);
        END IF;
        
        -- Update run log
        UPDATE ETL_RUN_LOG
        SET end_time = SYSTIMESTAMP,
            status = 'SUCCESS',
            records_processed = v_total_refs,
            duration_seconds = EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)),
            notes = 'Loaded ' || v_total_refs || ' references, ' || 
                    v_total_pcs_details || ' PCS details'
        WHERE run_id = v_run_id;
        
        p_status := 'SUCCESS';
        p_message := 'ETL complete for ' || v_issue_count || ' issues';
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
            
            UPDATE ETL_RUN_LOG
            SET end_time = SYSTIMESTAMP,
                status = 'ERROR',
                notes = SQLERRM
            WHERE run_id = v_run_id;
            
            ROLLBACK;
            RAISE;
    END run_etl_for_selected_issues;
    
    -- =========================================================================
    -- Step 4: Clear all data (except control tables)
    -- =========================================================================
    PROCEDURE clear_all_data(
        p_preserve_selections IN BOOLEAN DEFAULT FALSE,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_rows_deleted NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Clearing all data tables...');
        
        -- Disable FK constraints
        FOR c IN (SELECT constraint_name, table_name 
                  FROM user_constraints 
                  WHERE constraint_type = 'R' 
                  AND status = 'ENABLED'
                  AND table_name NOT LIKE 'BIN%') LOOP
            EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || 
                              ' DISABLE CONSTRAINT ' || c.constraint_name;
        END LOOP;
        
        -- Clean detail tables first
        DELETE FROM PCS_HEADER_PROPERTIES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM PCS_TEMP_PRESSURES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM PCS_PIPE_SIZES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM PCS_PIPE_ELEMENTS;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM PCS_VALVE_ELEMENTS;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM PCS_EMBEDDED_NOTES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM PCS_LIST;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM VDS_LIST;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        -- Clean reference tables
        DELETE FROM PCS_REFERENCES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM VDS_REFERENCES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM SC_REFERENCES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM VSM_REFERENCES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM MDS_REFERENCES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM EDS_REFERENCES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM ESK_REFERENCES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM VSK_REFERENCES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM PIPE_ELEMENT_REFERENCES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        -- Clean selections if not preserving
        IF NOT p_preserve_selections THEN
            DELETE FROM SELECTED_ISSUES;
            v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
            
            DELETE FROM SELECTED_PLANTS;
            v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        END IF;
        
        -- Clean core tables
        DELETE FROM ISSUES;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM PLANTS;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        -- Clean staging tables
        DELETE FROM STG_PLANTS;
        DELETE FROM STG_ISSUES;
        DELETE FROM STG_PCS_REFERENCES;
        DELETE FROM STG_VDS_REFERENCES;
        DELETE FROM STG_SC_REFERENCES;
        DELETE FROM STG_VSM_REFERENCES;
        DELETE FROM STG_MDS_REFERENCES;
        DELETE FROM STG_EDS_REFERENCES;
        DELETE FROM STG_ESK_REFERENCES;
        DELETE FROM STG_VSK_REFERENCES;
        DELETE FROM STG_PIPE_ELEMENT_REFERENCES;
        DELETE FROM STG_PCS_LIST;
        DELETE FROM STG_VDS_LIST;
        DELETE FROM STG_PCS_HEADER_PROPERTIES;
        DELETE FROM STG_PCS_TEMP_PRESSURES;
        DELETE FROM STG_PCS_PIPE_SIZES;
        DELETE FROM STG_PCS_PIPE_ELEMENTS;
        DELETE FROM STG_PCS_VALVE_ELEMENTS;
        DELETE FROM STG_PCS_EMBEDDED_NOTES;
        
        -- Clean other tables
        DELETE FROM RAW_JSON;
        v_rows_deleted := v_rows_deleted + SQL%ROWCOUNT;
        
        DELETE FROM CASCADE_LOG;
        DELETE FROM ETL_RUN_LOG;
        DELETE FROM ETL_LOG;
        DELETE FROM TEST_RESULTS;
        DELETE FROM ETL_ERROR_LOG;
        DELETE FROM API_TRANSACTIONS;
        
        -- Re-enable constraints
        FOR c IN (SELECT constraint_name, table_name 
                  FROM user_constraints 
                  WHERE constraint_type = 'R' 
                  AND status = 'DISABLED'
                  AND table_name NOT LIKE 'BIN%') LOOP
            EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || 
                              ' ENABLE CONSTRAINT ' || c.constraint_name;
        END LOOP;
        
        COMMIT;
        
        p_status := 'SUCCESS';
        p_message := 'Deleted ' || v_rows_deleted || ' rows from data tables' ||
                     CASE WHEN p_preserve_selections THEN ' (selections preserved)' ELSE '' END;
        
        DBMS_OUTPUT.PUT_LINE(p_message);
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
            ROLLBACK;
            RAISE;
    END clear_all_data;
    
    -- =========================================================================
    -- Selection Management: Add plant to selections
    -- =========================================================================
    PROCEDURE select_plant(
        p_plant_id  IN VARCHAR2,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_plant_exists NUMBER;
        v_already_selected NUMBER;
    BEGIN
        -- Check if plant exists
        SELECT COUNT(*) INTO v_plant_exists
        FROM PLANTS
        WHERE plant_id = p_plant_id
        AND is_valid = 'Y';
        
        IF v_plant_exists = 0 THEN
            p_status := 'ERROR';
            p_message := 'Plant ' || p_plant_id || ' not found or invalid';
            RETURN;
        END IF;
        
        -- Check if already selected
        SELECT COUNT(*) INTO v_already_selected
        FROM SELECTED_PLANTS
        WHERE plant_id = p_plant_id
        AND is_active = 'Y';
        
        IF v_already_selected > 0 THEN
            p_status := 'WARNING';
            p_message := 'Plant ' || p_plant_id || ' already selected';
            RETURN;
        END IF;
        
        -- Add to selections
        MERGE INTO SELECTED_PLANTS sp
        USING (SELECT p_plant_id AS plant_id FROM dual) s
        ON (sp.plant_id = s.plant_id)
        WHEN MATCHED THEN
            UPDATE SET is_active = 'Y',
                       selected_by = USER,
                       selection_date = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (plant_id, is_active, selected_by, selection_date)
            VALUES (s.plant_id, 'Y', USER, SYSDATE);
        
        COMMIT;
        
        p_status := 'SUCCESS';
        p_message := 'Plant ' || p_plant_id || ' selected';
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
            ROLLBACK;
    END select_plant;
    
    -- =========================================================================
    -- Selection Management: Add issue to selections
    -- =========================================================================
    PROCEDURE select_issue(
        p_plant_id       IN VARCHAR2,
        p_issue_revision IN VARCHAR2,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    ) IS
        v_issue_exists NUMBER;
        v_already_selected NUMBER;
    BEGIN
        -- Check if issue exists
        SELECT COUNT(*) INTO v_issue_exists
        FROM ISSUES
        WHERE plant_id = p_plant_id
        AND issue_revision = p_issue_revision
        AND is_valid = 'Y';
        
        IF v_issue_exists = 0 THEN
            p_status := 'ERROR';
            p_message := 'Issue ' || p_plant_id || '/' || p_issue_revision || ' not found or invalid';
            RETURN;
        END IF;
        
        -- Check if already selected
        SELECT COUNT(*) INTO v_already_selected
        FROM SELECTED_ISSUES
        WHERE plant_id = p_plant_id
        AND issue_revision = p_issue_revision
        AND is_active = 'Y';
        
        IF v_already_selected > 0 THEN
            p_status := 'WARNING';
            p_message := 'Issue ' || p_plant_id || '/' || p_issue_revision || ' already selected';
            RETURN;
        END IF;
        
        -- Add to selections
        MERGE INTO SELECTED_ISSUES si
        USING (SELECT p_plant_id AS plant_id, p_issue_revision AS issue_revision FROM dual) s
        ON (si.plant_id = s.plant_id AND si.issue_revision = s.issue_revision)
        WHEN MATCHED THEN
            UPDATE SET is_active = 'Y',
                       selected_by = USER,
                       selection_date = SYSDATE
        WHEN NOT MATCHED THEN
            INSERT (plant_id, issue_revision, is_active, selected_by, selection_date)
            VALUES (s.plant_id, s.issue_revision, 'Y', USER, SYSDATE);
        
        COMMIT;
        
        p_status := 'SUCCESS';
        p_message := 'Issue ' || p_plant_id || '/' || p_issue_revision || ' selected';
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
            ROLLBACK;
    END select_issue;
    
    -- =========================================================================
    -- Selection Management: Clear all selections
    -- =========================================================================
    PROCEDURE clear_selections(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
    BEGIN
        UPDATE SELECTED_PLANTS SET is_active = 'N' WHERE is_active = 'Y';
        UPDATE SELECTED_ISSUES SET is_active = 'N' WHERE is_active = 'Y';
        
        COMMIT;
        
        p_status := 'SUCCESS';
        p_message := 'All selections cleared';
        
    EXCEPTION
        WHEN OTHERS THEN
            p_status := 'ERROR';
            p_message := SQLERRM;
            ROLLBACK;
    END clear_selections;
    
    -- =========================================================================
    -- Selection Management: Show current selections
    -- =========================================================================
    PROCEDURE show_selections IS
        v_count NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('===============================================');
        DBMS_OUTPUT.PUT_LINE('Current Selections:');
        DBMS_OUTPUT.PUT_LINE('===============================================');
        
        -- Show selected plants
        SELECT COUNT(*) INTO v_count FROM SELECTED_PLANTS WHERE is_active = 'Y';
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Selected Plants (' || v_count || '):');
        
        FOR plant IN (SELECT sp.plant_id, p.short_description
                      FROM SELECTED_PLANTS sp
                      JOIN PLANTS p ON p.plant_id = sp.plant_id
                      WHERE sp.is_active = 'Y'
                      ORDER BY sp.plant_id) LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || plant.plant_id || ' - ' || plant.short_description);
        END LOOP;
        
        -- Show selected issues
        SELECT COUNT(*) INTO v_count FROM SELECTED_ISSUES WHERE is_active = 'Y';
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Selected Issues (' || v_count || '):');
        
        FOR issue IN (SELECT si.plant_id, si.issue_revision, i.issue_date
                      FROM SELECTED_ISSUES si
                      JOIN ISSUES i ON i.plant_id = si.plant_id 
                                   AND i.issue_revision = si.issue_revision
                      WHERE si.is_active = 'Y'
                      ORDER BY si.plant_id, si.issue_revision) LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || issue.plant_id || '/' || issue.issue_revision || 
                                 ' (Date: ' || TO_CHAR(issue.issue_date, 'YYYY-MM-DD') || ')');
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('===============================================');
    END show_selections;
    
    -- =========================================================================
    -- Legacy procedures (redirect to new ones)
    -- =========================================================================
    PROCEDURE run_plants_etl(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
    BEGIN
        load_plants(p_status, p_message);
    END run_plants_etl;

    PROCEDURE run_issues_etl_for_plant(
        p_plant_id  IN VARCHAR2,
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
    BEGIN
        pkg_api_client.refresh_issues_from_api(p_plant_id, p_status, p_message);
    END run_issues_etl_for_plant;

    PROCEDURE run_references_etl_for_issue(
        p_plant_id       IN VARCHAR2,
        p_issue_revision IN VARCHAR2,
        p_status         OUT VARCHAR2,
        p_message        OUT VARCHAR2
    ) IS
    BEGIN
        pkg_api_client_references.refresh_all_issue_references(
            p_plant_id, p_issue_revision, p_status, p_message
        );
    END run_references_etl_for_issue;

    PROCEDURE run_references_etl_for_all_selected(
        p_status    OUT VARCHAR2,
        p_message   OUT VARCHAR2
    ) IS
        v_temp_status VARCHAR2(50);
        v_temp_msg VARCHAR2(4000);
    BEGIN
        FOR issue IN (SELECT plant_id, issue_revision
                      FROM SELECTED_ISSUES
                      WHERE is_active = 'Y') LOOP
            pkg_api_client_references.refresh_all_issue_references(
                issue.plant_id, issue.issue_revision, v_temp_status, v_temp_msg
            );
        END LOOP;
        
        p_status := 'SUCCESS';
        p_message := 'References loaded for all selected issues';
    END run_references_etl_for_all_selected;

END pkg_etl_operations;
/

-- Verify compilation
SELECT object_name, object_type, status 
FROM user_objects 
WHERE object_name = 'PKG_ETL_OPERATIONS'
ORDER BY object_type;

EXIT;