-- ===============================================================================
-- Package: PKG_UPSERT_PCS_DETAILS
-- Purpose: MERGE staging PCS detail data into core tables with FK validation
-- Author: TR2000 ETL Team
-- Date: 2025-08-28
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_upsert_pcs_details AS
    -- Safe date parsing helper function
    FUNCTION safe_date_parse(p_date_string IN VARCHAR2) RETURN DATE;
    
    -- Safe number parsing helper function
    FUNCTION safe_number_parse(p_number_string IN VARCHAR2) RETURN NUMBER;
    
    -- Upsert PCS header/properties
    PROCEDURE upsert_header_properties(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    -- Upsert temperature/pressure data
    PROCEDURE upsert_temp_pressures(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    -- Upsert pipe sizes
    PROCEDURE upsert_pipe_sizes(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    -- Upsert pipe elements
    PROCEDURE upsert_pipe_elements(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    -- Upsert valve elements
    PROCEDURE upsert_valve_elements(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    -- Upsert embedded notes
    PROCEDURE upsert_embedded_notes(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    -- Generic upsert that routes to appropriate specific procedure
    PROCEDURE upsert_pcs_details(
        p_detail_type  IN VARCHAR2,
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
END pkg_upsert_pcs_details;
/

CREATE OR REPLACE PACKAGE BODY pkg_upsert_pcs_details AS

    -- =========================================================================
    -- Safe date parsing helper
    -- =========================================================================
    FUNCTION safe_date_parse(p_date_string IN VARCHAR2) RETURN DATE IS
    BEGIN
        IF p_date_string IS NULL THEN
            RETURN NULL;
        END IF;
        
        -- Try different date formats
        BEGIN
            RETURN TO_DATE(p_date_string, 'YYYY-MM-DD');
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            RETURN TO_DATE(p_date_string, 'DD-MON-YYYY');
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            RETURN TO_DATE(p_date_string, 'MM/DD/YYYY');
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        -- If all formats fail, return NULL
        RETURN NULL;
    END safe_date_parse;
    
    -- =========================================================================
    -- Safe number parsing helper
    -- =========================================================================
    FUNCTION safe_number_parse(p_number_string IN VARCHAR2) RETURN NUMBER IS
    BEGIN
        IF p_number_string IS NULL THEN
            RETURN NULL;
        END IF;
        
        RETURN TO_NUMBER(p_number_string);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END safe_number_parse;

    -- =========================================================================
    -- Upsert PCS header/properties
    -- =========================================================================
    PROCEDURE upsert_header_properties(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
    BEGIN
        -- Validate FK exists in PCS_REFERENCES
        DECLARE
            v_ref_exists NUMBER;
        BEGIN
            SELECT COUNT(*)
            INTO v_ref_exists
            FROM PCS_REFERENCES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
              AND pcs_name = p_pcs_name
              AND is_valid = 'Y';
            
            IF v_ref_exists = 0 THEN
                RAISE_APPLICATION_ERROR(-20451,
                    'No valid PCS reference found for ' || p_plant_id || '/' || p_issue_rev || '/' || p_pcs_name);
            END IF;
        END;
        
        -- Merge staging data into core table
        MERGE INTO PCS_HEADER_PROPERTIES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                pcs_name,
                revision,
                status,
                safe_date_parse(rev_date) AS rev_date,
                rating_class,
                safe_number_parse(test_pressure) AS test_pressure,
                material_group,
                design_code,
                safe_date_parse(last_update) AS last_update,
                last_update_by,
                approver,
                notepad,
                sc,
                vsm,
                design_code_rev_mark,
                safe_number_parse(corr_allowance) AS corr_allowance,
                corr_allowance_rev_mark,
                safe_number_parse(long_weld_eff) AS long_weld_eff,
                long_weld_eff_rev_mark,
                safe_number_parse(wall_thk_tol) AS wall_thk_tol,
                wall_thk_tol_rev_mark,
                service_remark,
                service_remark_rev_mark,
                safe_number_parse(design_press01) AS design_press01,
                safe_number_parse(design_press02) AS design_press02,
                safe_number_parse(design_press03) AS design_press03,
                safe_number_parse(design_press04) AS design_press04,
                safe_number_parse(design_press05) AS design_press05,
                safe_number_parse(design_press06) AS design_press06,
                safe_number_parse(design_press07) AS design_press07,
                safe_number_parse(design_press08) AS design_press08,
                safe_number_parse(design_press09) AS design_press09,
                safe_number_parse(design_press10) AS design_press10,
                safe_number_parse(design_press11) AS design_press11,
                safe_number_parse(design_press12) AS design_press12,
                design_press_rev_mark,
                safe_number_parse(design_temp01) AS design_temp01,
                safe_number_parse(design_temp02) AS design_temp02,
                safe_number_parse(design_temp03) AS design_temp03,
                safe_number_parse(design_temp04) AS design_temp04,
                safe_number_parse(design_temp05) AS design_temp05,
                safe_number_parse(design_temp06) AS design_temp06,
                safe_number_parse(design_temp07) AS design_temp07,
                safe_number_parse(design_temp08) AS design_temp08,
                safe_number_parse(design_temp09) AS design_temp09,
                safe_number_parse(design_temp10) AS design_temp10,
                safe_number_parse(design_temp11) AS design_temp11,
                safe_number_parse(design_temp12) AS design_temp12,
                design_temp_rev_mark,
                safe_number_parse(note_id_corr_allowance) AS note_id_corr_allowance,
                safe_number_parse(note_id_service_code) AS note_id_service_code,
                safe_number_parse(note_id_wall_thk_tol) AS note_id_wall_thk_tol,
                safe_number_parse(note_id_long_weld_eff) AS note_id_long_weld_eff,
                safe_number_parse(note_id_general_pcs) AS note_id_general_pcs,
                safe_number_parse(note_id_design_code) AS note_id_design_code,
                safe_number_parse(note_id_press_temp_table) AS note_id_press_temp_table,
                safe_number_parse(note_id_pipe_size_wth_table) AS note_id_pipe_size_wth_table,
                press_element_change,
                temp_element_change,
                safe_number_parse(material_group_id) AS material_group_id,
                safe_number_parse(special_req_id) AS special_req_id,
                special_req,
                new_vds_section,
                tube_pcs,
                eds_mj_matrix,
                safe_number_parse(mj_reduction_factor) AS mj_reduction_factor
            FROM STG_PCS_HEADER_PROPERTIES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
              AND pcs_name = p_pcs_name
              AND revision = p_pcs_revision
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.pcs_name = src.pcs_name
            AND tgt.revision = src.revision)
        WHEN MATCHED THEN
            UPDATE SET
                status = src.status,
                rev_date = src.rev_date,
                rating_class = src.rating_class,
                test_pressure = src.test_pressure,
                material_group = src.material_group,
                design_code = src.design_code,
                last_update = src.last_update,
                last_update_by = src.last_update_by,
                approver = src.approver,
                notepad = src.notepad,
                sc = src.sc,
                vsm = src.vsm,
                design_code_rev_mark = src.design_code_rev_mark,
                corr_allowance = src.corr_allowance,
                corr_allowance_rev_mark = src.corr_allowance_rev_mark,
                long_weld_eff = src.long_weld_eff,
                long_weld_eff_rev_mark = src.long_weld_eff_rev_mark,
                wall_thk_tol = src.wall_thk_tol,
                wall_thk_tol_rev_mark = src.wall_thk_tol_rev_mark,
                service_remark = src.service_remark,
                service_remark_rev_mark = src.service_remark_rev_mark,
                design_press01 = src.design_press01,
                design_press02 = src.design_press02,
                design_press03 = src.design_press03,
                design_press04 = src.design_press04,
                design_press05 = src.design_press05,
                design_press06 = src.design_press06,
                design_press07 = src.design_press07,
                design_press08 = src.design_press08,
                design_press09 = src.design_press09,
                design_press10 = src.design_press10,
                design_press11 = src.design_press11,
                design_press12 = src.design_press12,
                design_press_rev_mark = src.design_press_rev_mark,
                design_temp01 = src.design_temp01,
                design_temp02 = src.design_temp02,
                design_temp03 = src.design_temp03,
                design_temp04 = src.design_temp04,
                design_temp05 = src.design_temp05,
                design_temp06 = src.design_temp06,
                design_temp07 = src.design_temp07,
                design_temp08 = src.design_temp08,
                design_temp09 = src.design_temp09,
                design_temp10 = src.design_temp10,
                design_temp11 = src.design_temp11,
                design_temp12 = src.design_temp12,
                design_temp_rev_mark = src.design_temp_rev_mark,
                note_id_corr_allowance = src.note_id_corr_allowance,
                note_id_service_code = src.note_id_service_code,
                note_id_wall_thk_tol = src.note_id_wall_thk_tol,
                note_id_long_weld_eff = src.note_id_long_weld_eff,
                note_id_general_pcs = src.note_id_general_pcs,
                note_id_design_code = src.note_id_design_code,
                note_id_press_temp_table = src.note_id_press_temp_table,
                note_id_pipe_size_wth_table = src.note_id_pipe_size_wth_table,
                press_element_change = src.press_element_change,
                temp_element_change = src.temp_element_change,
                material_group_id = src.material_group_id,
                special_req_id = src.special_req_id,
                special_req = src.special_req,
                new_vds_section = src.new_vds_section,
                tube_pcs = src.tube_pcs,
                eds_mj_matrix = src.eds_mj_matrix,
                mj_reduction_factor = src.mj_reduction_factor,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                detail_guid, plant_id, issue_revision, pcs_name, revision,
                status, rev_date, rating_class, test_pressure, material_group,
                design_code, last_update, last_update_by, approver, notepad,
                sc, vsm, design_code_rev_mark, corr_allowance, corr_allowance_rev_mark,
                long_weld_eff, long_weld_eff_rev_mark, wall_thk_tol, wall_thk_tol_rev_mark,
                service_remark, service_remark_rev_mark,
                design_press01, design_press02, design_press03, design_press04,
                design_press05, design_press06, design_press07, design_press08,
                design_press09, design_press10, design_press11, design_press12,
                design_press_rev_mark,
                design_temp01, design_temp02, design_temp03, design_temp04,
                design_temp05, design_temp06, design_temp07, design_temp08,
                design_temp09, design_temp10, design_temp11, design_temp12,
                design_temp_rev_mark,
                note_id_corr_allowance, note_id_service_code, note_id_wall_thk_tol,
                note_id_long_weld_eff, note_id_general_pcs, note_id_design_code,
                note_id_press_temp_table, note_id_pipe_size_wth_table,
                press_element_change, temp_element_change,
                material_group_id, special_req_id, special_req,
                new_vds_section, tube_pcs, eds_mj_matrix, mj_reduction_factor,
                is_valid, created_date, last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.pcs_name, src.revision,
                src.status, src.rev_date, src.rating_class, src.test_pressure, src.material_group,
                src.design_code, src.last_update, src.last_update_by, src.approver, src.notepad,
                src.sc, src.vsm, src.design_code_rev_mark, src.corr_allowance, src.corr_allowance_rev_mark,
                src.long_weld_eff, src.long_weld_eff_rev_mark, src.wall_thk_tol, src.wall_thk_tol_rev_mark,
                src.service_remark, src.service_remark_rev_mark,
                src.design_press01, src.design_press02, src.design_press03, src.design_press04,
                src.design_press05, src.design_press06, src.design_press07, src.design_press08,
                src.design_press09, src.design_press10, src.design_press11, src.design_press12,
                src.design_press_rev_mark,
                src.design_temp01, src.design_temp02, src.design_temp03, src.design_temp04,
                src.design_temp05, src.design_temp06, src.design_temp07, src.design_temp08,
                src.design_temp09, src.design_temp10, src.design_temp11, src.design_temp12,
                src.design_temp_rev_mark,
                src.note_id_corr_allowance, src.note_id_service_code, src.note_id_wall_thk_tol,
                src.note_id_long_weld_eff, src.note_id_general_pcs, src.note_id_design_code,
                src.note_id_press_temp_table, src.note_id_pipe_size_wth_table,
                src.press_element_change, src.temp_element_change,
                src.material_group_id, src.special_req_id, src.special_req,
                src.new_vds_section, src.tube_pcs, src.eds_mj_matrix, src.mj_reduction_factor,
                'Y', SYSDATE, SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('PCS Header Properties - Merged: ' || v_merge_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20452, 
                'Error upserting PCS header properties: ' || SQLERRM);
    END upsert_header_properties;

    -- =========================================================================
    -- Upsert temperature/pressure data
    -- =========================================================================
    PROCEDURE upsert_temp_pressures(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
        v_delete_count NUMBER := 0;
    BEGIN
        -- Clear existing data for this PCS
        DELETE FROM PCS_TEMP_PRESSURES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        v_delete_count := SQL%ROWCOUNT;
        
        -- Insert new data
        INSERT INTO PCS_TEMP_PRESSURES (
            detail_guid, plant_id, issue_revision, pcs_name, revision,
            temperature, pressure, is_valid, created_date,
            last_modified_date, last_api_sync
        )
        SELECT 
            SYS_GUID(),
            plant_id,
            issue_revision,
            pcs_name,
            revision,
            safe_number_parse(temperature),
            safe_number_parse(pressure),
            'Y',
            SYSDATE,
            SYSDATE,
            SYSTIMESTAMP
        FROM STG_PCS_TEMP_PRESSURES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('PCS Temp/Pressure - Deleted: ' || v_delete_count || ', Inserted: ' || v_merge_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20453, 
                'Error upserting PCS temp/pressure: ' || SQLERRM);
    END upsert_temp_pressures;

    -- =========================================================================
    -- Upsert pipe sizes
    -- =========================================================================
    PROCEDURE upsert_pipe_sizes(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
    BEGIN
        -- Merge staging data into core table
        MERGE INTO PCS_PIPE_SIZES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                pcs_name,
                revision,
                nom_size,
                safe_number_parse(outer_diam) AS outer_diam,
                safe_number_parse(wall_thickness) AS wall_thickness,
                schedule,
                safe_number_parse(under_tolerance) AS under_tolerance,
                safe_number_parse(corrosion_allowance) AS corrosion_allowance,
                safe_number_parse(welding_factor) AS welding_factor,
                dim_element_change,
                schedule_in_matrix
            FROM STG_PCS_PIPE_SIZES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
              AND pcs_name = p_pcs_name
              AND revision = p_pcs_revision
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.pcs_name = src.pcs_name
            AND tgt.revision = src.revision
            AND tgt.nom_size = src.nom_size)
        WHEN MATCHED THEN
            UPDATE SET
                outer_diam = src.outer_diam,
                wall_thickness = src.wall_thickness,
                schedule = src.schedule,
                under_tolerance = src.under_tolerance,
                corrosion_allowance = src.corrosion_allowance,
                welding_factor = src.welding_factor,
                dim_element_change = src.dim_element_change,
                schedule_in_matrix = src.schedule_in_matrix,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                detail_guid, plant_id, issue_revision, pcs_name, revision,
                nom_size, outer_diam, wall_thickness, schedule,
                under_tolerance, corrosion_allowance, welding_factor,
                dim_element_change, schedule_in_matrix,
                is_valid, created_date, last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.pcs_name, src.revision,
                src.nom_size, src.outer_diam, src.wall_thickness, src.schedule,
                src.under_tolerance, src.corrosion_allowance, src.welding_factor,
                src.dim_element_change, src.schedule_in_matrix,
                'Y', SYSDATE, SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('PCS Pipe Sizes - Merged: ' || v_merge_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20454, 
                'Error upserting PCS pipe sizes: ' || SQLERRM);
    END upsert_pipe_sizes;

    -- =========================================================================
    -- Upsert pipe elements
    -- =========================================================================
    PROCEDURE upsert_pipe_elements(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
    BEGIN
        -- Merge staging data into core table
        MERGE INTO PCS_PIPE_ELEMENTS tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                pcs_name,
                revision,
                safe_number_parse(material_group_id) AS material_group_id,
                safe_number_parse(element_group_no) AS element_group_no,
                safe_number_parse(line_no) AS line_no,
                element,
                dim_standard,
                from_size,
                to_size,
                product_form,
                material,
                mds,
                eds,
                eds_revision,
                esk,
                revmark,
                remark,
                page_break,
                safe_number_parse(element_id) AS element_id,
                free_text,
                safe_number_parse(note_id) AS note_id,
                new_deleted_line,
                initial_info,
                initial_revmark,
                mds_variant,
                mds_revision,
                area
            FROM STG_PCS_PIPE_ELEMENTS
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
              AND pcs_name = p_pcs_name
              AND revision = p_pcs_revision
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.pcs_name = src.pcs_name
            AND tgt.revision = src.revision
            AND tgt.element_group_no = src.element_group_no
            AND tgt.line_no = src.line_no)
        WHEN MATCHED THEN
            UPDATE SET
                material_group_id = src.material_group_id,
                element = src.element,
                dim_standard = src.dim_standard,
                from_size = src.from_size,
                to_size = src.to_size,
                product_form = src.product_form,
                material = src.material,
                mds = src.mds,
                eds = src.eds,
                eds_revision = src.eds_revision,
                esk = src.esk,
                revmark = src.revmark,
                remark = src.remark,
                page_break = src.page_break,
                element_id = src.element_id,
                free_text = src.free_text,
                note_id = src.note_id,
                new_deleted_line = src.new_deleted_line,
                initial_info = src.initial_info,
                initial_revmark = src.initial_revmark,
                mds_variant = src.mds_variant,
                mds_revision = src.mds_revision,
                area = src.area,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                detail_guid, plant_id, issue_revision, pcs_name, revision,
                material_group_id, element_group_no, line_no, element,
                dim_standard, from_size, to_size, product_form, material,
                mds, eds, eds_revision, esk, revmark, remark, page_break,
                element_id, free_text, note_id, new_deleted_line,
                initial_info, initial_revmark, mds_variant, mds_revision, area,
                is_valid, created_date, last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.pcs_name, src.revision,
                src.material_group_id, src.element_group_no, src.line_no, src.element,
                src.dim_standard, src.from_size, src.to_size, src.product_form, src.material,
                src.mds, src.eds, src.eds_revision, src.esk, src.revmark, src.remark, src.page_break,
                src.element_id, src.free_text, src.note_id, src.new_deleted_line,
                src.initial_info, src.initial_revmark, src.mds_variant, src.mds_revision, src.area,
                'Y', SYSDATE, SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('PCS Pipe Elements - Merged: ' || v_merge_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20455, 
                'Error upserting PCS pipe elements: ' || SQLERRM);
    END upsert_pipe_elements;

    -- =========================================================================
    -- Upsert valve elements  
    -- =========================================================================
    PROCEDURE upsert_valve_elements(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
    BEGIN
        -- Merge staging data into core table
        MERGE INTO PCS_VALVE_ELEMENTS tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                pcs_name,
                revision,
                safe_number_parse(valve_group_no) AS valve_group_no,
                safe_number_parse(line_no) AS line_no,
                valve_type,
                vds,
                valve_description,
                from_size,
                to_size,
                revmark,
                remark,
                page_break,
                safe_number_parse(note_id) AS note_id,
                previous_vds,
                new_deleted_line,
                initial_info,
                initial_revmark,
                size_range,
                status,
                valve_revision
            FROM STG_PCS_VALVE_ELEMENTS
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
              AND pcs_name = p_pcs_name
              AND revision = p_pcs_revision
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.pcs_name = src.pcs_name
            AND tgt.revision = src.revision
            AND tgt.valve_group_no = src.valve_group_no
            AND tgt.line_no = src.line_no)
        WHEN MATCHED THEN
            UPDATE SET
                valve_type = src.valve_type,
                vds = src.vds,
                valve_description = src.valve_description,
                from_size = src.from_size,
                to_size = src.to_size,
                revmark = src.revmark,
                remark = src.remark,
                page_break = src.page_break,
                note_id = src.note_id,
                previous_vds = src.previous_vds,
                new_deleted_line = src.new_deleted_line,
                initial_info = src.initial_info,
                initial_revmark = src.initial_revmark,
                size_range = src.size_range,
                status = src.status,
                valve_revision = src.valve_revision,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                detail_guid, plant_id, issue_revision, pcs_name, revision,
                valve_group_no, line_no, valve_type, vds,
                valve_description, from_size, to_size,
                revmark, remark, page_break, note_id,
                previous_vds, new_deleted_line, initial_info,
                initial_revmark, size_range, status, valve_revision,
                is_valid, created_date, last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.pcs_name, src.revision,
                src.valve_group_no, src.line_no, src.valve_type, src.vds,
                src.valve_description, src.from_size, src.to_size,
                src.revmark, src.remark, src.page_break, src.note_id,
                src.previous_vds, src.new_deleted_line, src.initial_info,
                src.initial_revmark, src.size_range, src.status, src.valve_revision,
                'Y', SYSDATE, SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('PCS Valve Elements - Merged: ' || v_merge_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20456, 
                'Error upserting PCS valve elements: ' || SQLERRM);
    END upsert_valve_elements;

    -- =========================================================================
    -- Upsert embedded notes
    -- =========================================================================
    PROCEDURE upsert_embedded_notes(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
    BEGIN
        -- Merge staging data into core table
        MERGE INTO PCS_EMBEDDED_NOTES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                pcs_name,
                revision,
                safe_number_parse(text_section_id) AS text_section_id,
                text_section_description,
                page_break,
                html_clob
            FROM STG_PCS_EMBEDDED_NOTES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
              AND pcs_name = p_pcs_name
              AND revision = p_pcs_revision
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.pcs_name = src.pcs_name
            AND tgt.revision = src.revision
            AND tgt.text_section_id = src.text_section_id)
        WHEN MATCHED THEN
            UPDATE SET
                text_section_description = src.text_section_description,
                page_break = src.page_break,
                html_clob = src.html_clob,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                detail_guid, plant_id, issue_revision, pcs_name, revision,
                text_section_id, text_section_description,
                page_break, html_clob,
                is_valid, created_date, last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.pcs_name, src.revision,
                src.text_section_id, src.text_section_description,
                src.page_break, src.html_clob,
                'Y', SYSDATE, SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('PCS Embedded Notes - Merged: ' || v_merge_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20457, 
                'Error upserting PCS embedded notes: ' || SQLERRM);
    END upsert_embedded_notes;

    -- =========================================================================
    -- Generic upsert router
    -- =========================================================================
    PROCEDURE upsert_pcs_details(
        p_detail_type  IN VARCHAR2,
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    ) IS
    BEGIN
        CASE UPPER(p_detail_type)
            WHEN 'HEADER' THEN
                upsert_header_properties(p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            WHEN 'TEMP_PRESSURE' THEN
                upsert_temp_pressures(p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            WHEN 'PIPE_SIZES' THEN
                upsert_pipe_sizes(p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            WHEN 'PIPE_ELEMENTS' THEN
                upsert_pipe_elements(p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            WHEN 'VALVE_ELEMENTS' THEN
                upsert_valve_elements(p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            WHEN 'EMBEDDED_NOTES' THEN
                upsert_embedded_notes(p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            ELSE
                RAISE_APPLICATION_ERROR(-20458,
                    'Unknown PCS detail type: ' || p_detail_type);
        END CASE;
    END upsert_pcs_details;
    
END pkg_upsert_pcs_details;
/