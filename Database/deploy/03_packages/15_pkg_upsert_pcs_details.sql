-- ===============================================================================
-- PKG_UPSERT_PCS_DETAILS - Upsert PCS List and Detail Data
-- Date: 2025-12-01
-- Purpose: Move PCS data from staging to core tables with MERGE logic
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_upsert_pcs_details AS
    
    -- Helper functions
    FUNCTION safe_date_parse(p_date_string IN VARCHAR2) RETURN DATE;
    FUNCTION safe_number_parse(p_number_string IN VARCHAR2) RETURN NUMBER;
    
    -- Upsert plant PCS list
    PROCEDURE upsert_pcs_list(p_plant_id IN VARCHAR2);
    
    -- Upsert PCS details by type
    PROCEDURE upsert_header_properties(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_temp_pressures(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_pipe_sizes(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_pipe_elements(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_valve_elements(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_embedded_notes(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    );
    
    -- Generic dispatcher
    PROCEDURE upsert_pcs_details(
        p_detail_type IN VARCHAR2, p_plant_id IN VARCHAR2,
        p_issue_rev IN VARCHAR2, p_pcs_name IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
END pkg_upsert_pcs_details;
/

CREATE OR REPLACE PACKAGE BODY pkg_upsert_pcs_details AS

    -- Safe date parsing
    FUNCTION safe_date_parse(p_date_string IN VARCHAR2) RETURN DATE IS
    BEGIN
        IF p_date_string IS NULL THEN
            RETURN NULL;
        END IF;
        -- Try common formats
        BEGIN
            RETURN TO_DATE(p_date_string, 'YYYY-MM-DD HH24:MI:SS');
        EXCEPTION WHEN OTHERS THEN NULL; END;
        BEGIN
            RETURN TO_DATE(p_date_string, 'YYYY-MM-DD');
        EXCEPTION WHEN OTHERS THEN NULL; END;
        BEGIN
            RETURN TO_DATE(p_date_string, 'DD-MON-YYYY');
        EXCEPTION WHEN OTHERS THEN NULL; END;
        BEGIN
            RETURN TO_DATE(p_date_string, 'MM/DD/YYYY');
        EXCEPTION WHEN OTHERS THEN NULL; END;
        RETURN NULL;
    END safe_date_parse;
    
    -- Safe number parsing
    FUNCTION safe_number_parse(p_number_string IN VARCHAR2) RETURN NUMBER IS
    BEGIN
        IF p_number_string IS NULL THEN
            RETURN NULL;
        END IF;
        RETURN TO_NUMBER(TRIM(p_number_string));
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END safe_number_parse;
    
    -- Upsert PCS list from staging to core
    PROCEDURE upsert_pcs_list(p_plant_id IN VARCHAR2) IS
        v_merge_count NUMBER;
    BEGIN
        MERGE INTO PCS_LIST t
        USING (
            SELECT 
                plant_id,
                pcs AS pcs_name,
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
                safe_number_parse(special_req_id) AS special_req_id,
                tube_pcs,
                new_vds_section
            FROM STG_PCS_LIST
            WHERE plant_id = p_plant_id
        ) s
        ON (t.plant_id = s.plant_id 
            AND t.pcs_name = s.pcs_name 
            AND t.revision = s.revision)
        WHEN MATCHED THEN
            UPDATE SET
                t.status = s.status,
                t.rev_date = s.rev_date,
                t.rating_class = s.rating_class,
                t.test_pressure = s.test_pressure,
                t.material_group = s.material_group,
                t.design_code = s.design_code,
                t.last_update = s.last_update,
                t.last_update_by = s.last_update_by,
                t.approver = s.approver,
                t.notepad = s.notepad,
                t.special_req_id = s.special_req_id,
                t.tube_pcs = s.tube_pcs,
                t.new_vds_section = s.new_vds_section,
                t.is_valid = 'Y',
                t.last_modified_date = SYSDATE,
                t.last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                plant_id, pcs_name, revision, status, rev_date,
                rating_class, test_pressure, material_group, design_code,
                last_update, last_update_by, approver, notepad,
                special_req_id, tube_pcs, new_vds_section,
                is_valid, created_date, last_modified_date, last_api_sync
            ) VALUES (
                s.plant_id, s.pcs_name, s.revision, s.status, s.rev_date,
                s.rating_class, s.test_pressure, s.material_group, s.design_code,
                s.last_update, s.last_update_by, s.approver, s.notepad,
                s.special_req_id, s.tube_pcs, s.new_vds_section,
                'Y', SYSDATE, SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Upserted ' || v_merge_count || ' PCS list records');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20361, 
                'Error upserting PCS list: ' || SQLERRM);
    END upsert_pcs_list;
    
    -- Upsert header properties (simplified - full implementation would follow same pattern)
    PROCEDURE upsert_header_properties(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    ) IS
    BEGIN
        -- Delete existing then insert new
        DELETE FROM PCS_HEADER_PROPERTIES
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO PCS_HEADER_PROPERTIES (
            plant_id, pcs_name, revision,
            status, rev_date, rating_class, test_pressure,
            material_group, design_code, is_valid
        )
        SELECT 
            plant_id, pcs_name, revision,
            status, safe_date_parse(rev_date), rating_class,
            safe_number_parse(test_pressure),
            material_group, design_code, 'Y'
        FROM STG_PCS_HEADER_PROPERTIES
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        DBMS_OUTPUT.PUT_LINE('Upserted header properties');
    END upsert_header_properties;
    
    -- Simplified implementations for other detail types
    PROCEDURE upsert_temp_pressures(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM PCS_TEMP_PRESSURES
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO PCS_TEMP_PRESSURES (
            plant_id, pcs_name, revision, temperature, pressure, is_valid
        )
        SELECT plant_id, pcs_name, revision,
               safe_number_parse(temperature),
               safe_number_parse(pressure), 'Y'
        FROM STG_PCS_TEMP_PRESSURES
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
    END upsert_temp_pressures;
    
    PROCEDURE upsert_pipe_sizes(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM PCS_PIPE_SIZES
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO PCS_PIPE_SIZES (
            plant_id, pcs_name, revision, nom_size, outer_diam,
            wall_thickness, schedule, is_valid
        )
        SELECT plant_id, pcs_name, revision, nom_size,
               safe_number_parse(outer_diam),
               safe_number_parse(wall_thickness),
               schedule, 'Y'
        FROM STG_PCS_PIPE_SIZES
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
    END upsert_pipe_sizes;
    
    PROCEDURE upsert_pipe_elements(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM PCS_PIPE_ELEMENTS
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO PCS_PIPE_ELEMENTS (
            plant_id, pcs_name, revision,
            material_group_id, element_group_no, line_no,
            element, dim_standard, material, mds, eds, is_valid
        )
        SELECT plant_id, pcs_name, revision,
               safe_number_parse(material_group_id),
               safe_number_parse(element_group_no),
               safe_number_parse(line_no),
               element, dim_standard, material, mds, eds, 'Y'
        FROM STG_PCS_PIPE_ELEMENTS
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
    END upsert_pipe_elements;
    
    PROCEDURE upsert_valve_elements(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM PCS_VALVE_ELEMENTS
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO PCS_VALVE_ELEMENTS (
            plant_id, pcs_name, revision,
            valve_group_no, line_no, valve_type, vds, is_valid
        )
        SELECT plant_id, pcs_name, revision,
               safe_number_parse(valve_group_no),
               safe_number_parse(line_no),
               valve_type, vds, 'Y'
        FROM STG_PCS_VALVE_ELEMENTS
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
    END upsert_valve_elements;
    
    PROCEDURE upsert_embedded_notes(
        p_plant_id IN VARCHAR2, p_issue_rev IN VARCHAR2,
        p_pcs_name IN VARCHAR2, p_pcs_revision IN VARCHAR2
    ) IS
    BEGIN
        DELETE FROM PCS_EMBEDDED_NOTES
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO PCS_EMBEDDED_NOTES (
            plant_id, pcs_name, revision,
            text_section_id, text_section_description,
            page_break, html_clob, is_valid
        )
        SELECT plant_id, pcs_name, revision,
               safe_number_parse(text_section_id),
               text_section_description,
               page_break, html_clob, 'Y'
        FROM STG_PCS_EMBEDDED_NOTES
        WHERE plant_id = p_plant_id
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
    END upsert_embedded_notes;
    
    -- Generic dispatcher
    PROCEDURE upsert_pcs_details(
        p_detail_type IN VARCHAR2, p_plant_id IN VARCHAR2,
        p_issue_rev IN VARCHAR2, p_pcs_name IN VARCHAR2,
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
                RAISE_APPLICATION_ERROR(-20367,
                    'Unknown PCS detail type: ' || p_detail_type);
        END CASE;
    END upsert_pcs_details;
    
END pkg_upsert_pcs_details;
/