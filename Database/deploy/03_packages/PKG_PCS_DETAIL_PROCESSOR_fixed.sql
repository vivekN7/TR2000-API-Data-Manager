CREATE OR REPLACE PACKAGE BODY PKG_PCS_DETAIL_PROCESSOR AS

    PROCEDURE process_pcs_detail(
        p_raw_json_id   IN NUMBER,
        p_plant_id      IN VARCHAR2,
        p_pcs_name      IN VARCHAR2,
        p_revision      IN VARCHAR2,
        p_detail_type   IN VARCHAR2
    ) IS
        v_json CLOB;
        v_upper_type VARCHAR2(50);
        v_error_msg VARCHAR2(4000);
    BEGIN
        -- Get JSON from RAW_JSON (maintaining data flow: API -> RAW_JSON -> STG -> Core)
        SELECT payload INTO v_json
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;

        v_upper_type := UPPER(p_detail_type);

        -- Process based on detail type
        IF v_upper_type = 'HEADER_PROPERTIES' OR v_upper_type = 'PCS_HEADER' THEN
            -- Step 1: Clear staging
            DELETE FROM STG_PCS_HEADER_PROPERTIES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

            -- Step 2: JSON -> Staging (all VARCHAR2)
            INSERT INTO STG_PCS_HEADER_PROPERTIES (
                plant_id, pcs_name, pcs_revision, "PCS", "Revision", "Status", "RevDate",
                "RatingClass", "TestPressure", "MaterialGroup", "DesignCode", "LastUpdate",
                "LastUpdateBy", "Approver", "Notepad", "SC", "VSM", "DesignCodeRevMark",
                "CorrAllowance", "CorrAllowanceRevMark", "LongWeldEff", "LongWeldEffRevMark",
                "WallThkTol", "WallThkTolRevMark", "ServiceRemark", "ServiceRemarkRevMark",
                "DesignPress01", "DesignPress02", "DesignPress03", "DesignPress04", "DesignPress05",
                "DesignPress06", "DesignPress07", "DesignPress08", "DesignPress09", "DesignPress10",
                "DesignPress11", "DesignPress12", "DesignPressRevMark",
                "DesignTemp01", "DesignTemp02", "DesignTemp03", "DesignTemp04", "DesignTemp05",
                "DesignTemp06", "DesignTemp07", "DesignTemp08", "DesignTemp09", "DesignTemp10",
                "DesignTemp11", "DesignTemp12", "DesignTempRevMark",
                "NoteIDCorrAllowance", "NoteIDServiceCode", "NoteIDWallThkTol", "NoteIDLongWeldEff",
                "NoteIDGeneralPCS", "NoteIDDesignCode", "NoteIDPressTempTable", "NoteIDPipeSizeWthTable",
                "PressElementChange", "TempElementChange", "MaterialGroupID", "SpecialReqID",
                "SpecialReq", "NewVDSSection", "TubePCS", "EDSMJMatrix", "MJReductionFactor"
            )
            SELECT
                p_plant_id, p_pcs_name, p_revision,
                jt."PCS", jt."Revision", jt."Status", jt."RevDate",
                jt."RatingClass", jt."TestPressure", jt."MaterialGroup", jt."DesignCode", jt."LastUpdate",
                jt."LastUpdateBy", jt."Approver", jt."Notepad", jt."SC", jt."VSM", jt."DesignCodeRevMark",
                jt."CorrAllowance", jt."CorrAllowanceRevMark", jt."LongWeldEff", jt."LongWeldEffRevMark",
                jt."WallThkTol", jt."WallThkTolRevMark", jt."ServiceRemark", jt."ServiceRemarkRevMark",
                jt."DesignPress01", jt."DesignPress02", jt."DesignPress03", jt."DesignPress04", jt."DesignPress05",
                jt."DesignPress06", jt."DesignPress07", jt."DesignPress08", jt."DesignPress09", jt."DesignPress10",
                jt."DesignPress11", jt."DesignPress12", jt."DesignPressRevMark",
                jt."DesignTemp01", jt."DesignTemp02", jt."DesignTemp03", jt."DesignTemp04", jt."DesignTemp05",
                jt."DesignTemp06", jt."DesignTemp07", jt."DesignTemp08", jt."DesignTemp09", jt."DesignTemp10",
                jt."DesignTemp11", jt."DesignTemp12", jt."DesignTempRevMark",
                jt."NoteIDCorrAllowance", jt."NoteIDServiceCode", jt."NoteIDWallThkTol", jt."NoteIDLongWeldEff",
                jt."NoteIDGeneralPCS", jt."NoteIDDesignCode", jt."NoteIDPressTempTable", jt."NoteIDPipeSizeWthTable",
                jt."PressElementChange", jt."TempElementChange", jt."MaterialGroupID", jt."SpecialReqID",
                jt."SpecialReq", jt."NewVDSSection", jt."TubePCS", jt."EDSMJMatrix", jt."MJReductionFactor"
            FROM JSON_TABLE(v_json, '$'
                COLUMNS (
                    "PCS" VARCHAR2(100) PATH '$.PCS',
                    "Revision" VARCHAR2(50) PATH '$.Revision',
                    "Status" VARCHAR2(50) PATH '$.Status',
                    "RevDate" VARCHAR2(50) PATH '$.RevDate',
                    "RatingClass" VARCHAR2(50) PATH '$.RatingClass',
                    "TestPressure" VARCHAR2(50) PATH '$.TestPressure',
                    "MaterialGroup" VARCHAR2(50) PATH '$.MaterialGroup',
                    "DesignCode" VARCHAR2(50) PATH '$.DesignCode',
                    "LastUpdate" VARCHAR2(50) PATH '$.LastUpdate',
                    "LastUpdateBy" VARCHAR2(100) PATH '$.LastUpdateBy',
                    "Approver" VARCHAR2(100) PATH '$.Approver',
                    "Notepad" VARCHAR2(500) PATH '$.Notepad',
                    "SC" VARCHAR2(100) PATH '$.SC',
                    "VSM" VARCHAR2(100) PATH '$.VSM',
                    "DesignCodeRevMark" VARCHAR2(50) PATH '$.DesignCodeRevMark',
                    "CorrAllowance" VARCHAR2(50) PATH '$.CorrAllowance',
                    "CorrAllowanceRevMark" VARCHAR2(50) PATH '$.CorrAllowanceRevMark',
                    "LongWeldEff" VARCHAR2(50) PATH '$.LongWeldEff',
                    "LongWeldEffRevMark" VARCHAR2(50) PATH '$.LongWeldEffRevMark',
                    "WallThkTol" VARCHAR2(50) PATH '$.WallThkTol',
                    "WallThkTolRevMark" VARCHAR2(50) PATH '$.WallThkTolRevMark',
                    "ServiceRemark" VARCHAR2(500) PATH '$.ServiceRemark',
                    "ServiceRemarkRevMark" VARCHAR2(50) PATH '$.ServiceRemarkRevMark',
                    "DesignPress01" VARCHAR2(50) PATH '$.DesignPress01',
                    "DesignPress02" VARCHAR2(50) PATH '$.DesignPress02',
                    "DesignPress03" VARCHAR2(50) PATH '$.DesignPress03',
                    "DesignPress04" VARCHAR2(50) PATH '$.DesignPress04',
                    "DesignPress05" VARCHAR2(50) PATH '$.DesignPress05',
                    "DesignPress06" VARCHAR2(50) PATH '$.DesignPress06',
                    "DesignPress07" VARCHAR2(50) PATH '$.DesignPress07',
                    "DesignPress08" VARCHAR2(50) PATH '$.DesignPress08',
                    "DesignPress09" VARCHAR2(50) PATH '$.DesignPress09',
                    "DesignPress10" VARCHAR2(50) PATH '$.DesignPress10',
                    "DesignPress11" VARCHAR2(50) PATH '$.DesignPress11',
                    "DesignPress12" VARCHAR2(50) PATH '$.DesignPress12',
                    "DesignPressRevMark" VARCHAR2(50) PATH '$.DesignPressRevMark',
                    "DesignTemp01" VARCHAR2(50) PATH '$.DesignTemp01',
                    "DesignTemp02" VARCHAR2(50) PATH '$.DesignTemp02',
                    "DesignTemp03" VARCHAR2(50) PATH '$.DesignTemp03',
                    "DesignTemp04" VARCHAR2(50) PATH '$.DesignTemp04',
                    "DesignTemp05" VARCHAR2(50) PATH '$.DesignTemp05',
                    "DesignTemp06" VARCHAR2(50) PATH '$.DesignTemp06',
                    "DesignTemp07" VARCHAR2(50) PATH '$.DesignTemp07',
                    "DesignTemp08" VARCHAR2(50) PATH '$.DesignTemp08',
                    "DesignTemp09" VARCHAR2(50) PATH '$.DesignTemp09',
                    "DesignTemp10" VARCHAR2(50) PATH '$.DesignTemp10',
                    "DesignTemp11" VARCHAR2(50) PATH '$.DesignTemp11',
                    "DesignTemp12" VARCHAR2(50) PATH '$.DesignTemp12',
                    "DesignTempRevMark" VARCHAR2(50) PATH '$.DesignTempRevMark',
                    "NoteIDCorrAllowance" VARCHAR2(50) PATH '$.NoteIDCorrAllowance',
                    "NoteIDServiceCode" VARCHAR2(50) PATH '$.NoteIDServiceCode',
                    "NoteIDWallThkTol" VARCHAR2(50) PATH '$.NoteIDWallThkTol',
                    "NoteIDLongWeldEff" VARCHAR2(50) PATH '$.NoteIDLongWeldEff',
                    "NoteIDGeneralPCS" VARCHAR2(50) PATH '$.NoteIDGeneralPCS',
                    "NoteIDDesignCode" VARCHAR2(50) PATH '$.NoteIDDesignCode',
                    "NoteIDPressTempTable" VARCHAR2(50) PATH '$.NoteIDPressTempTable',
                    "NoteIDPipeSizeWthTable" VARCHAR2(50) PATH '$.NoteIDPipeSizeWthTable',
                    "PressElementChange" VARCHAR2(50) PATH '$.PressElementChange',
                    "TempElementChange" VARCHAR2(50) PATH '$.TempElementChange',
                    "MaterialGroupID" VARCHAR2(50) PATH '$.MaterialGroupID',
                    "SpecialReqID" VARCHAR2(50) PATH '$.SpecialReqID',
                    "SpecialReq" VARCHAR2(500) PATH '$.SpecialReq',
                    "NewVDSSection" VARCHAR2(50) PATH '$.NewVDSSection',
                    "TubePCS" VARCHAR2(50) PATH '$.TubePCS',
                    "EDSMJMatrix" VARCHAR2(50) PATH '$.EDSMJMatrix',
                    "MJReductionFactor" VARCHAR2(50) PATH '$.MJReductionFactor'
                )) jt;

            -- Step 3: Staging -> Core (with proper type conversions)
            DELETE FROM PCS_HEADER_PROPERTIES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND pcs_revision = p_revision;

            INSERT INTO PCS_HEADER_PROPERTIES (
                pcs_header_properties_guid, plant_id, pcs_name, pcs_revision,
                pcs, revision, status, rev_date, rating_class, test_pressure,
                material_group, design_code, last_update, last_update_by, approver,
                notepad, sc, vsm, design_code_rev_mark, corr_allowance,
                corr_allowance_rev_mark, long_weld_eff, long_weld_eff_rev_mark,
                wall_thk_tol, wall_thk_tol_rev_mark, service_remark, service_remark_rev_mark,
                design_press01, design_press02, design_press03, design_press04, design_press05,
                design_press06, design_press07, design_press08, design_press09, design_press10,
                design_press11, design_press12, design_press_rev_mark,
                design_temp01, design_temp02, design_temp03, design_temp04, design_temp05,
                design_temp06, design_temp07, design_temp08, design_temp09, design_temp10,
                design_temp11, design_temp12, design_temp_rev_mark,
                note_id_corr_allowance, note_id_service_code, note_id_wall_thk_tol, note_id_long_weld_eff,
                note_id_general_pcs, note_id_design_code, note_id_press_temp_table, note_id_pipe_size_wth_table,
                press_element_change, temp_element_change, material_group_id, special_req_id,
                special_req, new_vds_section, tube_pcs, eds_mj_matrix, mj_reduction_factor,
                created_date, last_modified_date
            )
            SELECT
                SYS_GUID(), plant_id, pcs_name, pcs_revision,
                "PCS", "Revision", "Status", TO_DATE("RevDate", 'YYYY-MM-DD'), "RatingClass", TO_NUMBER("TestPressure"),
                "MaterialGroup", "DesignCode", TO_DATE("LastUpdate", 'YYYY-MM-DD'), "LastUpdateBy", "Approver",
                "Notepad", "SC", "VSM", "DesignCodeRevMark", TO_NUMBER("CorrAllowance"),
                "CorrAllowanceRevMark", TO_NUMBER("LongWeldEff"), "LongWeldEffRevMark",
                TO_NUMBER("WallThkTol"), "WallThkTolRevMark", "ServiceRemark", "ServiceRemarkRevMark",
                TO_NUMBER("DesignPress01"), TO_NUMBER("DesignPress02"), TO_NUMBER("DesignPress03"), TO_NUMBER("DesignPress04"), TO_NUMBER("DesignPress05"),
                TO_NUMBER("DesignPress06"), TO_NUMBER("DesignPress07"), TO_NUMBER("DesignPress08"), TO_NUMBER("DesignPress09"), TO_NUMBER("DesignPress10"),
                TO_NUMBER("DesignPress11"), TO_NUMBER("DesignPress12"), "DesignPressRevMark",
                TO_NUMBER("DesignTemp01"), TO_NUMBER("DesignTemp02"), TO_NUMBER("DesignTemp03"), TO_NUMBER("DesignTemp04"), TO_NUMBER("DesignTemp05"),
                TO_NUMBER("DesignTemp06"), TO_NUMBER("DesignTemp07"), TO_NUMBER("DesignTemp08"), TO_NUMBER("DesignTemp09"), TO_NUMBER("DesignTemp10"),
                TO_NUMBER("DesignTemp11"), TO_NUMBER("DesignTemp12"), "DesignTempRevMark",
                TO_NUMBER("NoteIDCorrAllowance"), TO_NUMBER("NoteIDServiceCode"), TO_NUMBER("NoteIDWallThkTol"), TO_NUMBER("NoteIDLongWeldEff"),
                TO_NUMBER("NoteIDGeneralPCS"), TO_NUMBER("NoteIDDesignCode"), TO_NUMBER("NoteIDPressTempTable"), TO_NUMBER("NoteIDPipeSizeWthTable"),
                "PressElementChange", "TempElementChange", TO_NUMBER("MaterialGroupID"), TO_NUMBER("SpecialReqID"),
                "SpecialReq", "NewVDSSection", "TubePCS", "EDSMJMatrix", TO_NUMBER("MJReductionFactor"),
                SYSDATE, SYSDATE
            FROM STG_PCS_HEADER_PROPERTIES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

        ELSIF v_upper_type = 'PIPE_ELEMENTS' OR v_upper_type = 'PIPE-ELEMENTS' THEN
            -- Step 1: Clear staging
            DELETE FROM STG_PCS_PIPE_ELEMENTS
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

            -- Step 2: JSON -> Staging (all VARCHAR2)
            INSERT INTO STG_PCS_PIPE_ELEMENTS (
                plant_id, pcs_name, pcs_revision, "PCS", "Revision", "MaterialGroupID",
                "ElementGroupNo", "LineNo", "Element", "DimStandard", "FromSize", "ToSize",
                "ProductForm", "Material", "MDS", "EDS", "EDSRevision", "ESK", "Revmark",
                "Remark", "PageBreak", "ElementID", "FreeText", "NoteID", "NewDeletedLine",
                "InitialInfo", "InitialRevmark", "MDSVariant", "MDSRevision", "Area"
            )
            SELECT
                p_plant_id, p_pcs_name, p_revision,
                json_pcs, json_revision, material_group_id,
                element_group_no, line_no, element, dim_standard, from_size, to_size,
                product_form, material, mds, eds, eds_revision, esk, revmark,
                remark, page_break, element_id, free_text, note_id, new_deleted_line,
                initial_info, initial_revmark, mds_variant, mds_revision, area
            FROM JSON_TABLE(v_json, '$'
                COLUMNS (
                    json_pcs VARCHAR2(100) PATH '$.PCS',
                    json_revision VARCHAR2(50) PATH '$.Revision',
                    NESTED PATH '$.getPipeElements[*]'
                    COLUMNS (
                        material_group_id VARCHAR2(50) PATH '$.MaterialGroupID',
                        element_group_no VARCHAR2(50) PATH '$.ElementGroupNo',
                        line_no VARCHAR2(50) PATH '$.LineNo',
                        element VARCHAR2(100) PATH '$.Element',
                        dim_standard VARCHAR2(100) PATH '$.DimStandard',
                        from_size VARCHAR2(50) PATH '$.FromSize',
                        to_size VARCHAR2(50) PATH '$.ToSize',
                        product_form VARCHAR2(100) PATH '$.ProductForm',
                        material VARCHAR2(100) PATH '$.Material',
                        mds VARCHAR2(100) PATH '$.MDS',
                        eds VARCHAR2(100) PATH '$.EDS',
                        eds_revision VARCHAR2(50) PATH '$.EDSRevision',
                        esk VARCHAR2(100) PATH '$.ESK',
                        revmark VARCHAR2(50) PATH '$.Revmark',
                        remark VARCHAR2(500) PATH '$.Remark',
                        page_break VARCHAR2(50) PATH '$.PageBreak',
                        element_id VARCHAR2(100) PATH '$.ElementID',
                        free_text VARCHAR2(500) PATH '$.FreeText',
                        note_id VARCHAR2(50) PATH '$.NoteID',
                        new_deleted_line VARCHAR2(50) PATH '$.NewDeletedLine',
                        initial_info VARCHAR2(500) PATH '$.InitialInfo',
                        initial_revmark VARCHAR2(50) PATH '$.InitialRevmark',
                        mds_variant VARCHAR2(100) PATH '$.MDSVariant',
                        mds_revision VARCHAR2(50) PATH '$.MDSRevision',
                        area VARCHAR2(100) PATH '$.Area'
                    )
                ));

            -- Step 3: Staging -> Core
            DELETE FROM PCS_PIPE_ELEMENTS
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND pcs_revision = p_revision;

            INSERT INTO PCS_PIPE_ELEMENTS (
                pcs_pipe_elements_guid, plant_id, pcs_name, pcs_revision,
                pcs, revision, material_group_id, element_group_no, line_no, element,
                dim_standard, from_size, to_size, product_form, material, mds, eds,
                eds_revision, esk, revmark, remark, page_break, element_id, free_text,
                note_id, new_deleted_line, initial_info, initial_revmark,
                mds_variant, mds_revision, area, created_date, last_modified_date
            )
            SELECT
                SYS_GUID(), plant_id, pcs_name, pcs_revision,
                "PCS", "Revision", TO_NUMBER("MaterialGroupID"), TO_NUMBER("ElementGroupNo"), TO_NUMBER("LineNo"), "Element",
                "DimStandard", "FromSize", "ToSize", "ProductForm", "Material", "MDS", "EDS",
                "EDSRevision", "ESK", "Revmark", "Remark", "PageBreak", "ElementID", "FreeText",
                "NoteID", "NewDeletedLine", "InitialInfo", "InitialRevmark",
                "MDSVariant", "MDSRevision", "Area", SYSDATE, SYSDATE
            FROM STG_PCS_PIPE_ELEMENTS
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

        ELSIF v_upper_type = 'VALVE_ELEMENTS' OR v_upper_type = 'VALVE-ELEMENTS' THEN
            -- Step 1: Clear staging
            DELETE FROM STG_PCS_VALVE_ELEMENTS
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

            -- Step 2: JSON -> Staging (all VARCHAR2)
            INSERT INTO STG_PCS_VALVE_ELEMENTS (
                plant_id, pcs_name, pcs_revision, "ValveGroupNo", "LineNo", "ValveType",
                "VDS", "ValveDescription", "FromSize", "ToSize", "Revmark", "Remark",
                "PageBreak", "NoteID", "PreviousVDS", "NewDeletedLine", "InitialInfo",
                "InitialRevmark", "SizeRange", "Status", "Revision"
            )
            SELECT
                p_plant_id, p_pcs_name, p_revision,
                valve_group_no, line_no, valve_type, vds, valve_description,
                from_size, to_size, revmark, remark, page_break, note_id,
                previous_vds, new_deleted_line, initial_info, initial_revmark,
                size_range, status, revision
            FROM JSON_TABLE(v_json, '$.getValveElements[*]'
                COLUMNS (
                    valve_group_no VARCHAR2(50) PATH '$.ValveGroupNo',
                    line_no VARCHAR2(50) PATH '$.LineNo',
                    valve_type VARCHAR2(100) PATH '$.ValveType',
                    vds VARCHAR2(100) PATH '$.VDS',
                    valve_description VARCHAR2(500) PATH '$.ValveDescription',
                    from_size VARCHAR2(50) PATH '$.FromSize',
                    to_size VARCHAR2(50) PATH '$.ToSize',
                    revmark VARCHAR2(50) PATH '$.Revmark',
                    remark VARCHAR2(500) PATH '$.Remark',
                    page_break VARCHAR2(50) PATH '$.PageBreak',
                    note_id VARCHAR2(50) PATH '$.NoteID',
                    previous_vds VARCHAR2(100) PATH '$.PreviousVDS',
                    new_deleted_line VARCHAR2(50) PATH '$.NewDeletedLine',
                    initial_info VARCHAR2(500) PATH '$.InitialInfo',
                    initial_revmark VARCHAR2(50) PATH '$.InitialRevmark',
                    size_range VARCHAR2(100) PATH '$.SizeRange',
                    status VARCHAR2(50) PATH '$.Status',
                    revision VARCHAR2(50) PATH '$.Revision'
                ));

            -- Step 3: Staging -> Core
            DELETE FROM PCS_VALVE_ELEMENTS
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND pcs_revision = p_revision;

            INSERT INTO PCS_VALVE_ELEMENTS (
                pcs_valve_elements_guid, plant_id, pcs_name, pcs_revision,
                valve_group_no, line_no, valve_type, vds, valve_description,
                from_size, to_size, revmark, remark, page_break, note_id,
                previous_vds, new_deleted_line, initial_info, initial_revmark,
                size_range, status, revision, created_date, last_modified_date
            )
            SELECT
                SYS_GUID(), plant_id, pcs_name, pcs_revision,
                TO_NUMBER("ValveGroupNo"), TO_NUMBER("LineNo"), "ValveType", "VDS", "ValveDescription",
                "FromSize", "ToSize", "Revmark", "Remark", "PageBreak", "NoteID",
                "PreviousVDS", "NewDeletedLine", "InitialInfo", "InitialRevmark",
                "SizeRange", "Status", "Revision", SYSDATE, SYSDATE
            FROM STG_PCS_VALVE_ELEMENTS
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

        ELSIF v_upper_type = 'EMBEDDED_NOTES' OR v_upper_type = 'EMBEDDED-NOTES' THEN
            -- Step 1: Clear staging
            DELETE FROM STG_PCS_EMBEDDED_NOTES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

            -- Step 2: JSON -> Staging (all VARCHAR2)
            INSERT INTO STG_PCS_EMBEDDED_NOTES (
                plant_id, pcs_name, pcs_revision, "PCSName", "Revision",
                "TextSectionID", "TextSectionDescription", "PageBreak", "HTMLCLOB"
            )
            SELECT
                p_plant_id, p_pcs_name, p_revision,
                pcs_name, revision, text_section_id, text_section_description,
                page_break, html_clob
            FROM JSON_TABLE(v_json, '$.getEmbeddedNotes[*]'
                COLUMNS (
                    pcs_name VARCHAR2(100) PATH '$.PCSName',
                    revision VARCHAR2(50) PATH '$.Revision',
                    text_section_id VARCHAR2(50) PATH '$.TextSectionID',
                    text_section_description VARCHAR2(500) PATH '$.TextSectionDescription',
                    page_break VARCHAR2(50) PATH '$.PageBreak',
                    html_clob CLOB PATH '$.HTMLCLOB'
                ));

            -- Step 3: Staging -> Core
            DELETE FROM PCS_EMBEDDED_NOTES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND pcs_revision = p_revision;

            INSERT INTO PCS_EMBEDDED_NOTES (
                pcs_embedded_notes_guid, plant_id, pcs_name, pcs_revision,
                pcsname, revision, text_section_id, text_section_description,
                page_break, html_clob, created_date, last_modified_date
            )
            SELECT
                SYS_GUID(), plant_id, pcs_name, pcs_revision,
                "PCSName", "Revision", TO_NUMBER("TextSectionID"), "TextSectionDescription",
                "PageBreak", "HTMLCLOB", SYSDATE, SYSDATE
            FROM STG_PCS_EMBEDDED_NOTES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

        ELSIF v_upper_type = 'TEMP_PRESSURES' OR v_upper_type = 'TEMP-PRESSURES' THEN
            -- Step 1: Clear staging
            DELETE FROM STG_PCS_TEMP_PRESSURES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

            -- Step 2: JSON -> Staging (all VARCHAR2)
            INSERT INTO STG_PCS_TEMP_PRESSURES (
                plant_id, pcs_name, pcs_revision, "Temperature", "Pressure"
            )
            SELECT
                p_plant_id, p_pcs_name, p_revision,
                temperature, pressure
            FROM JSON_TABLE(v_json, '$.getTempPressure[*]'
                COLUMNS (
                    temperature VARCHAR2(50) PATH '$.Temperature',
                    pressure VARCHAR2(50) PATH '$.Pressure'
                ));

            -- Step 3: Staging -> Core (with NUMBER conversions)
            DELETE FROM PCS_TEMP_PRESSURES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND pcs_revision = p_revision;

            INSERT INTO PCS_TEMP_PRESSURES (
                pcs_temp_pressures_guid, plant_id, pcs_name, pcs_revision,
                temperature, pressure, created_date, last_modified_date
            )
            SELECT
                SYS_GUID(), plant_id, pcs_name, pcs_revision,
                TO_NUMBER("Temperature"), TO_NUMBER("Pressure"),
                SYSDATE, SYSDATE
            FROM STG_PCS_TEMP_PRESSURES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

        ELSIF v_upper_type = 'PIPE_SIZES' OR v_upper_type = 'PIPE-SIZES' THEN
            -- Step 1: Clear staging
            DELETE FROM STG_PCS_PIPE_SIZES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

            -- Step 2: JSON -> Staging (all VARCHAR2)
            INSERT INTO STG_PCS_PIPE_SIZES (
                plant_id, pcs_name, pcs_revision, "PCS", "Revision",
                "NomSize", "OuterDiam", "WallThickness", "Schedule",
                "UnderTolerance", "CorrosionAllowance", "WeldingFactor",
                "DimElementChange", "ScheduleInMatrix"
            )
            SELECT
                p_plant_id, p_pcs_name, p_revision,
                json_pcs, json_revision,
                nom_size, outer_diam, wall_thickness, schedule,
                under_tolerance, corrosion_allowance, welding_factor,
                dim_element_change, schedule_in_matrix
            FROM JSON_TABLE(v_json, '$'
                COLUMNS (
                    json_pcs VARCHAR2(100) PATH '$.PCS',
                    json_revision VARCHAR2(50) PATH '$.Revision',
                    NESTED PATH '$.getPipeSize[*]'
                    COLUMNS (
                        nom_size VARCHAR2(50) PATH '$.NomSize',
                        outer_diam VARCHAR2(50) PATH '$.OuterDiam',
                        wall_thickness VARCHAR2(50) PATH '$.WallThickness',
                        schedule VARCHAR2(50) PATH '$.Schedule',
                        under_tolerance VARCHAR2(50) PATH '$.UnderTolerance',
                        corrosion_allowance VARCHAR2(50) PATH '$.CorrosionAllowance',
                        welding_factor VARCHAR2(50) PATH '$.WeldingFactor',
                        dim_element_change VARCHAR2(50) PATH '$.DimElementChange',
                        schedule_in_matrix VARCHAR2(50) PATH '$.ScheduleInMatrix'
                    )
                ));

            -- Step 3: Staging -> Core
            DELETE FROM PCS_PIPE_SIZES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND pcs_revision = p_revision;

            INSERT INTO PCS_PIPE_SIZES (
                pcs_pipe_sizes_guid, plant_id, pcs_name, pcs_revision,
                pcs, revision, nom_size, outer_diam, wall_thickness, schedule,
                under_tolerance, corrosion_allowance, welding_factor,
                dim_element_change, schedule_in_matrix,
                created_date, last_modified_date
            )
            SELECT
                SYS_GUID(), plant_id, pcs_name, pcs_revision,
                "PCS", "Revision", "NomSize",
                TO_NUMBER("OuterDiam"), TO_NUMBER("WallThickness"),
                "Schedule", TO_NUMBER("UnderTolerance"),
                TO_NUMBER("CorrosionAllowance"), TO_NUMBER("WeldingFactor"),
                "DimElementChange", "ScheduleInMatrix",
                SYSDATE, SYSDATE
            FROM STG_PCS_PIPE_SIZES
            WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name;

        END IF;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            v_error_msg := SQLERRM;
            -- Log error
            INSERT INTO ETL_ERROR_LOG (
                error_id, endpoint_key, plant_id,
                error_timestamp, error_type, error_message
            )
            VALUES (
                ETL_ERROR_SEQ.NEXTVAL,
                'PCS_' || NVL(v_upper_type, 'UNKNOWN'),
                p_plant_id,
                SYSTIMESTAMP,
                'PROCESSING_ERROR',
                v_error_msg
            );
            COMMIT;
            RAISE;
    END process_pcs_detail;

END PKG_PCS_DETAIL_PROCESSOR;
/