-- ===============================================================================
-- Package: PKG_PARSE_PCS_DETAILS
-- Purpose: Parse JSON responses from PCS detail endpoints into staging tables
-- Author: TR2000 ETL Team
-- Date: 2025-08-28
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_parse_pcs_details AS
    -- Parse PCS header/properties JSON (endpoint 3.2)
    PROCEDURE parse_header_properties(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    );
    
    -- Parse temperature/pressure JSON (endpoint 3.3)
    PROCEDURE parse_temp_pressures(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    );
    
    -- Parse pipe sizes JSON (endpoint 3.4)
    PROCEDURE parse_pipe_sizes(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    );
    
    -- Parse pipe elements JSON (endpoint 3.5)
    PROCEDURE parse_pipe_elements(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    );
    
    -- Parse valve elements JSON (endpoint 3.6)
    PROCEDURE parse_valve_elements(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    );
    
    -- Parse embedded notes JSON (endpoint 3.7)
    PROCEDURE parse_embedded_notes(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    );
    
    -- Generic parser that routes to appropriate specific parser
    PROCEDURE parse_pcs_detail_json(
        p_detail_type    IN VARCHAR2,
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    );
    
END pkg_parse_pcs_details;
/

CREATE OR REPLACE PACKAGE BODY pkg_parse_pcs_details AS

    -- =========================================================================
    -- Parse PCS header/properties JSON
    -- =========================================================================
    PROCEDURE parse_header_properties(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    ) IS
        v_json_content CLOB;
        v_record_count NUMBER := 0;
    BEGIN
        -- Get JSON content from RAW_JSON
        SELECT payload INTO v_json_content
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;
        
        -- Clear staging table for this PCS
        DELETE FROM STG_PCS_HEADER_PROPERTIES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        -- Parse JSON and insert into staging
        INSERT INTO STG_PCS_HEADER_PROPERTIES (
            plant_id, issue_revision, pcs_name, revision, status, rev_date,
            rating_class, test_pressure, material_group, design_code,
            last_update, last_update_by, approver, notepad,
            sc, vsm, design_code_rev_mark,
            corr_allowance, corr_allowance_rev_mark,
            long_weld_eff, long_weld_eff_rev_mark,
            wall_thk_tol, wall_thk_tol_rev_mark,
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
            new_vds_section, tube_pcs, eds_mj_matrix, mj_reduction_factor
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            p_pcs_name,
            p_pcs_revision,
            jt.*
        FROM JSON_TABLE(
            v_json_content, '$'
            COLUMNS (
                status                      VARCHAR2(50)   PATH '$.Status',
                rev_date                    VARCHAR2(50)   PATH '$.RevDate',
                rating_class                VARCHAR2(100)  PATH '$.RatingClass',
                test_pressure               VARCHAR2(50)   PATH '$.TestPressure',
                material_group              VARCHAR2(100)  PATH '$.MaterialGroup',
                design_code                 VARCHAR2(100)  PATH '$.DesignCode',
                last_update                 VARCHAR2(50)   PATH '$.LastUpdate',
                last_update_by              VARCHAR2(100)  PATH '$.LastUpdateBy',
                approver                    VARCHAR2(100)  PATH '$.Approver',
                notepad                     VARCHAR2(4000) PATH '$.Notepad',
                sc                          VARCHAR2(100)  PATH '$.SC',
                vsm                         VARCHAR2(100)  PATH '$.VSM',
                design_code_rev_mark        VARCHAR2(50)   PATH '$.DesignCodeRevMark',
                corr_allowance              VARCHAR2(50)   PATH '$.CorrAllowance',
                corr_allowance_rev_mark     VARCHAR2(50)   PATH '$.CorrAllowanceRevMark',
                long_weld_eff               VARCHAR2(50)   PATH '$.LongWeldEff',
                long_weld_eff_rev_mark      VARCHAR2(50)   PATH '$.LongWeldEffRevMark',
                wall_thk_tol                VARCHAR2(50)   PATH '$.WallThkTol',
                wall_thk_tol_rev_mark       VARCHAR2(50)   PATH '$.WallThkTolRevMark',
                service_remark              VARCHAR2(500)  PATH '$.ServiceRemark',
                service_remark_rev_mark     VARCHAR2(50)   PATH '$.ServiceRemarkRevMark',
                -- Design pressures
                design_press01              VARCHAR2(50)   PATH '$.DesignPress01',
                design_press02              VARCHAR2(50)   PATH '$.DesignPress02',
                design_press03              VARCHAR2(50)   PATH '$.DesignPress03',
                design_press04              VARCHAR2(50)   PATH '$.DesignPress04',
                design_press05              VARCHAR2(50)   PATH '$.DesignPress05',
                design_press06              VARCHAR2(50)   PATH '$.DesignPress06',
                design_press07              VARCHAR2(50)   PATH '$.DesignPress07',
                design_press08              VARCHAR2(50)   PATH '$.DesignPress08',
                design_press09              VARCHAR2(50)   PATH '$.DesignPress09',
                design_press10              VARCHAR2(50)   PATH '$.DesignPress10',
                design_press11              VARCHAR2(50)   PATH '$.DesignPress11',
                design_press12              VARCHAR2(50)   PATH '$.DesignPress12',
                design_press_rev_mark       VARCHAR2(50)   PATH '$.DesignPressRevMark',
                -- Design temperatures
                design_temp01               VARCHAR2(50)   PATH '$.DesignTemp01',
                design_temp02               VARCHAR2(50)   PATH '$.DesignTemp02',
                design_temp03               VARCHAR2(50)   PATH '$.DesignTemp03',
                design_temp04               VARCHAR2(50)   PATH '$.DesignTemp04',
                design_temp05               VARCHAR2(50)   PATH '$.DesignTemp05',
                design_temp06               VARCHAR2(50)   PATH '$.DesignTemp06',
                design_temp07               VARCHAR2(50)   PATH '$.DesignTemp07',
                design_temp08               VARCHAR2(50)   PATH '$.DesignTemp08',
                design_temp09               VARCHAR2(50)   PATH '$.DesignTemp09',
                design_temp10               VARCHAR2(50)   PATH '$.DesignTemp10',
                design_temp11               VARCHAR2(50)   PATH '$.DesignTemp11',
                design_temp12               VARCHAR2(50)   PATH '$.DesignTemp12',
                design_temp_rev_mark        VARCHAR2(50)   PATH '$.DesignTempRevMark',
                -- Note IDs
                note_id_corr_allowance      VARCHAR2(50)   PATH '$.NoteIDCorrAllowance',
                note_id_service_code        VARCHAR2(50)   PATH '$.NoteIDServiceCode',
                note_id_wall_thk_tol        VARCHAR2(50)   PATH '$.NoteIDWallThkTol',
                note_id_long_weld_eff       VARCHAR2(50)   PATH '$.NoteIDLongWeldEff',
                note_id_general_pcs         VARCHAR2(50)   PATH '$.NoteIDGeneralPCS',
                note_id_design_code         VARCHAR2(50)   PATH '$.NoteIDDesignCode',
                note_id_press_temp_table    VARCHAR2(50)   PATH '$.NoteIDPressTempTable',
                note_id_pipe_size_wth_table VARCHAR2(50)   PATH '$.NoteIDPipeSizeWthTable',
                -- Additional fields
                press_element_change        VARCHAR2(50)   PATH '$.PressElementChange',
                temp_element_change         VARCHAR2(50)   PATH '$.TempElementChange',
                material_group_id           VARCHAR2(50)   PATH '$.MaterialGroupID',
                special_req_id              VARCHAR2(50)   PATH '$.SpecialReqID',
                special_req                 VARCHAR2(500)  PATH '$.SpecialReq',
                new_vds_section             VARCHAR2(100)  PATH '$.NewVDSSection',
                tube_pcs                    VARCHAR2(100)  PATH '$.TubePCS',
                eds_mj_matrix               VARCHAR2(100)  PATH '$.EDSMJMatrix',
                mj_reduction_factor         VARCHAR2(50)   PATH '$.MJReductionFactor'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' PCS header record');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20351, 
                'Error parsing PCS header JSON: ' || SQLERRM);
    END parse_header_properties;

    -- =========================================================================
    -- Parse temperature/pressure JSON
    -- =========================================================================
    PROCEDURE parse_temp_pressures(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    ) IS
        v_json_content CLOB;
        v_record_count NUMBER := 0;
    BEGIN
        SELECT payload INTO v_json_content
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;
        
        DELETE FROM STG_PCS_TEMP_PRESSURES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO STG_PCS_TEMP_PRESSURES (
            plant_id, issue_revision, pcs_name, revision,
            temperature, pressure
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            p_pcs_name,
            p_pcs_revision,
            jt.temperature,
            jt.pressure
        FROM JSON_TABLE(
            v_json_content, '$[*]'
            COLUMNS (
                temperature VARCHAR2(50) PATH '$.Temperature',
                pressure    VARCHAR2(50) PATH '$.Pressure'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' temperature/pressure pairs');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20352, 
                'Error parsing temp/pressure JSON: ' || SQLERRM);
    END parse_temp_pressures;

    -- =========================================================================
    -- Parse pipe sizes JSON
    -- =========================================================================
    PROCEDURE parse_pipe_sizes(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    ) IS
        v_json_content CLOB;
        v_record_count NUMBER := 0;
    BEGIN
        SELECT payload INTO v_json_content
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;
        
        DELETE FROM STG_PCS_PIPE_SIZES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO STG_PCS_PIPE_SIZES (
            plant_id, issue_revision, pcs_name, revision,
            nom_size, outer_diam, wall_thickness, schedule,
            under_tolerance, corrosion_allowance, welding_factor,
            dim_element_change, schedule_in_matrix
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            p_pcs_name,
            p_pcs_revision,
            jt.*
        FROM JSON_TABLE(
            v_json_content, '$[*]'
            COLUMNS (
                nom_size            VARCHAR2(50) PATH '$.NomSize',
                outer_diam          VARCHAR2(50) PATH '$.OuterDiam',
                wall_thickness      VARCHAR2(50) PATH '$.WallThickness',
                schedule            VARCHAR2(50) PATH '$.Schedule',
                under_tolerance     VARCHAR2(50) PATH '$.UnderTolerance',
                corrosion_allowance VARCHAR2(50) PATH '$.CorrosionAllowance',
                welding_factor      VARCHAR2(50) PATH '$.WeldingFactor',
                dim_element_change  VARCHAR2(50) PATH '$.DimElementChange',
                schedule_in_matrix  VARCHAR2(50) PATH '$.ScheduleInMatrix'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' pipe size records');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20353, 
                'Error parsing pipe sizes JSON: ' || SQLERRM);
    END parse_pipe_sizes;

    -- =========================================================================
    -- Parse pipe elements JSON
    -- =========================================================================
    PROCEDURE parse_pipe_elements(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    ) IS
        v_json_content CLOB;
        v_record_count NUMBER := 0;
    BEGIN
        SELECT payload INTO v_json_content
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;
        
        DELETE FROM STG_PCS_PIPE_ELEMENTS
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO STG_PCS_PIPE_ELEMENTS (
            plant_id, issue_revision, pcs_name, revision,
            material_group_id, element_group_no, line_no, element,
            dim_standard, from_size, to_size, product_form, material,
            mds, eds, eds_revision, esk, revmark, remark, page_break,
            element_id, free_text, note_id, new_deleted_line,
            initial_info, initial_revmark, mds_variant, mds_revision, area
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            p_pcs_name,
            p_pcs_revision,
            jt.*
        FROM JSON_TABLE(
            v_json_content, '$[*]'
            COLUMNS (
                material_group_id  VARCHAR2(50)  PATH '$.MaterialGroupID',
                element_group_no   VARCHAR2(50)  PATH '$.ElementGroupNo',
                line_no            VARCHAR2(50)  PATH '$.LineNo',
                element            VARCHAR2(200) PATH '$.Element',
                dim_standard       VARCHAR2(100) PATH '$.DimStandard',
                from_size          VARCHAR2(50)  PATH '$.FromSize',
                to_size            VARCHAR2(50)  PATH '$.ToSize',
                product_form       VARCHAR2(100) PATH '$.ProductForm',
                material           VARCHAR2(200) PATH '$.Material',
                mds                VARCHAR2(100) PATH '$.MDS',
                eds                VARCHAR2(100) PATH '$.EDS',
                eds_revision       VARCHAR2(50)  PATH '$.EDSRevision',
                esk                VARCHAR2(100) PATH '$.ESK',
                revmark            VARCHAR2(50)  PATH '$.Revmark',
                remark             VARCHAR2(500) PATH '$.Remark',
                page_break         VARCHAR2(50)  PATH '$.PageBreak',
                element_id         VARCHAR2(50)  PATH '$.ElementID',
                free_text          VARCHAR2(500) PATH '$.FreeText',
                note_id            VARCHAR2(50)  PATH '$.NoteID',
                new_deleted_line   VARCHAR2(50)  PATH '$.NewDeletedLine',
                initial_info       VARCHAR2(200) PATH '$.InitialInfo',
                initial_revmark    VARCHAR2(50)  PATH '$.InitialRevmark',
                mds_variant        VARCHAR2(100) PATH '$.MDSVariant',
                mds_revision       VARCHAR2(50)  PATH '$.MDSRevision',
                area               VARCHAR2(100) PATH '$.Area'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' pipe element records');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20354, 
                'Error parsing pipe elements JSON: ' || SQLERRM);
    END parse_pipe_elements;

    -- =========================================================================
    -- Parse valve elements JSON
    -- =========================================================================
    PROCEDURE parse_valve_elements(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    ) IS
        v_json_content CLOB;
        v_record_count NUMBER := 0;
    BEGIN
        SELECT payload INTO v_json_content
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;
        
        DELETE FROM STG_PCS_VALVE_ELEMENTS
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO STG_PCS_VALVE_ELEMENTS (
            plant_id, issue_revision, pcs_name, revision,
            valve_group_no, line_no, valve_type, vds,
            valve_description, from_size, to_size,
            revmark, remark, page_break, note_id,
            previous_vds, new_deleted_line, initial_info,
            initial_revmark, size_range, status, valve_revision
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            p_pcs_name,
            p_pcs_revision,
            jt.*
        FROM JSON_TABLE(
            v_json_content, '$[*]'
            COLUMNS (
                valve_group_no    VARCHAR2(50)  PATH '$.ValveGroupNo',
                line_no           VARCHAR2(50)  PATH '$.LineNo',
                valve_type        VARCHAR2(100) PATH '$.ValveType',
                vds               VARCHAR2(100) PATH '$.VDS',
                valve_description VARCHAR2(500) PATH '$.ValveDescription',
                from_size         VARCHAR2(50)  PATH '$.FromSize',
                to_size           VARCHAR2(50)  PATH '$.ToSize',
                revmark           VARCHAR2(50)  PATH '$.Revmark',
                remark            VARCHAR2(500) PATH '$.Remark',
                page_break        VARCHAR2(50)  PATH '$.PageBreak',
                note_id           VARCHAR2(50)  PATH '$.NoteID',
                previous_vds      VARCHAR2(100) PATH '$.PreviousVDS',
                new_deleted_line  VARCHAR2(50)  PATH '$.NewDeletedLine',
                initial_info      VARCHAR2(200) PATH '$.InitialInfo',
                initial_revmark   VARCHAR2(50)  PATH '$.InitialRevmark',
                size_range        VARCHAR2(100) PATH '$.SizeRange',
                status            VARCHAR2(50)  PATH '$.Status',
                valve_revision    VARCHAR2(50)  PATH '$.Revision'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' valve element records');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20355, 
                'Error parsing valve elements JSON: ' || SQLERRM);
    END parse_valve_elements;

    -- =========================================================================
    -- Parse embedded notes JSON
    -- =========================================================================
    PROCEDURE parse_embedded_notes(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    ) IS
        v_json_content CLOB;
        v_record_count NUMBER := 0;
    BEGIN
        SELECT payload INTO v_json_content
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;
        
        DELETE FROM STG_PCS_EMBEDDED_NOTES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND pcs_name = p_pcs_name
          AND revision = p_pcs_revision;
        
        INSERT INTO STG_PCS_EMBEDDED_NOTES (
            plant_id, issue_revision, pcs_name, revision,
            text_section_id, text_section_description,
            page_break, html_clob
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            p_pcs_name,
            p_pcs_revision,
            jt.text_section_id,
            jt.text_section_description,
            jt.page_break,
            jt.html_clob
        FROM JSON_TABLE(
            v_json_content, '$[*]'
            COLUMNS (
                text_section_id          VARCHAR2(50)  PATH '$.TextSectionID',
                text_section_description VARCHAR2(500) PATH '$.TextSectionDescription',
                page_break               VARCHAR2(50)  PATH '$.PageBreak',
                html_clob                CLOB          PATH '$.HTMLCLOB'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' embedded note records');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20356, 
                'Error parsing embedded notes JSON: ' || SQLERRM);
    END parse_embedded_notes;

    -- =========================================================================
    -- Generic parser router
    -- =========================================================================
    PROCEDURE parse_pcs_detail_json(
        p_detail_type    IN VARCHAR2,
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_pcs_revision   IN VARCHAR2
    ) IS
    BEGIN
        CASE UPPER(p_detail_type)
            WHEN 'HEADER' THEN
                parse_header_properties(p_raw_json_id, p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            WHEN 'TEMP_PRESSURE' THEN
                parse_temp_pressures(p_raw_json_id, p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            WHEN 'PIPE_SIZES' THEN
                parse_pipe_sizes(p_raw_json_id, p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            WHEN 'PIPE_ELEMENTS' THEN
                parse_pipe_elements(p_raw_json_id, p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            WHEN 'VALVE_ELEMENTS' THEN
                parse_valve_elements(p_raw_json_id, p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            WHEN 'EMBEDDED_NOTES' THEN
                parse_embedded_notes(p_raw_json_id, p_plant_id, p_issue_rev, p_pcs_name, p_pcs_revision);
            ELSE
                RAISE_APPLICATION_ERROR(-20357,
                    'Unknown PCS detail type: ' || p_detail_type);
        END CASE;
    END parse_pcs_detail_json;
    
END pkg_parse_pcs_details;
/