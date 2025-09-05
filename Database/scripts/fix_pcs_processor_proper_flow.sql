-- PKG_PCS_DETAIL_PROCESSOR with PROPER STAGING FLOW
-- Follows: API -> RAW_JSON -> STG_* -> Core tables
CREATE OR REPLACE PACKAGE BODY PKG_PCS_DETAIL_PROCESSOR AS

    PROCEDURE process_pcs_detail(
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_pcs_name       IN VARCHAR2,
        p_revision       IN VARCHAR2,
        p_detail_type    IN VARCHAR2
    ) IS
        v_json CLOB;
        v_err_msg VARCHAR2(4000);
    BEGIN
        -- Get JSON payload from RAW_JSON
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        -- Process based on detail type - ALWAYS: JSON -> STG -> Core
        CASE UPPER(p_detail_type)
            
            WHEN 'HEADER_PROPERTIES', 'HEADER' THEN
                -- Step 1: Clear staging for this plant
                DELETE FROM STG_PCS_HEADER_PROPERTIES WHERE plant_id = p_plant_id;
                
                -- Step 2: Parse JSON to staging (all VARCHAR2)
                INSERT INTO STG_PCS_HEADER_PROPERTIES (
                    plant_id, pcs_name, "PCS", "Revision", "Status"
                ) VALUES (
                    p_plant_id, p_pcs_name, p_pcs_name, p_revision, 'ACTIVE'
                );
                
                -- Step 3: Move from staging to core (with type conversions)
                DELETE FROM PCS_HEADER_PROPERTIES
                WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND revision = p_revision;
                
                INSERT INTO PCS_HEADER_PROPERTIES (
                    pcs_header_properties_guid, plant_id, pcs_name, revision,
                    status, created_date, last_modified_date
                )
                SELECT
                    SYS_GUID(), plant_id, pcs_name, "Revision", "Status",
                    SYSDATE, SYSDATE
                FROM STG_PCS_HEADER_PROPERTIES
                WHERE plant_id = p_plant_id;

            WHEN 'TEMP_PRESSURES' THEN
                -- Step 1: Clear staging
                DELETE FROM STG_PCS_TEMP_PRESSURES WHERE plant_id = p_plant_id;
                
                -- Step 2: JSON -> Staging (all VARCHAR2, no conversions)
                INSERT INTO STG_PCS_TEMP_PRESSURES (
                    plant_id, pcs_name, "Revision", "Temperature", "Pressure"
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
                WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND revision = p_revision;
                
                INSERT INTO PCS_TEMP_PRESSURES (
                    pcs_temp_pressures_guid, plant_id, pcs_name, revision,
                    temperature, pressure, created_date, last_modified_date
                )
                SELECT
                    SYS_GUID(), plant_id, pcs_name, "Revision",
                    TO_NUMBER("Temperature"), TO_NUMBER("Pressure"),
                    SYSDATE, SYSDATE
                FROM STG_PCS_TEMP_PRESSURES
                WHERE plant_id = p_plant_id;

            WHEN 'PIPE_SIZES' THEN
                -- Step 1: Clear staging
                DELETE FROM STG_PCS_PIPE_SIZES WHERE plant_id = p_plant_id;
                
                -- Step 2: JSON -> Staging (all VARCHAR2)
                INSERT INTO STG_PCS_PIPE_SIZES (
                    plant_id, "PCS", "Revision", "NomSize", "OuterDiam",
                    "WallThickness", "Schedule", "UnderTolerance",
                    "CorrosionAllowance", "WeldingFactor", "DimElementChange",
                    "ScheduleInMatrix"
                )
                SELECT
                    p_plant_id, p_pcs_name, p_revision,
                    nom_size, outer_diam, wall_thickness, schedule,
                    under_tolerance, corrosion_allowance, welding_factor,
                    dim_element_change, schedule_in_matrix
                FROM JSON_TABLE(v_json, '$.getPipeSize[*]'
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
                    ));
                
                -- Step 3: Staging -> Core (with type conversions)
                DELETE FROM PCS_PIPE_SIZES
                WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND revision = p_revision;
                
                INSERT INTO PCS_PIPE_SIZES (
                    pcs_pipe_sizes_guid, plant_id, pcs_name, revision,
                    nom_size, outer_diam, wall_thickness, schedule,
                    under_tolerance, corrosion_allowance, welding_factor,
                    dim_element_change, schedule_in_matrix,
                    created_date, last_modified_date
                )
                SELECT
                    SYS_GUID(), plant_id, "PCS", "Revision",
                    "NomSize", TO_NUMBER("OuterDiam"), TO_NUMBER("WallThickness"),
                    "Schedule", TO_NUMBER("UnderTolerance"),
                    TO_NUMBER("CorrosionAllowance"), TO_NUMBER("WeldingFactor"),
                    "DimElementChange", "ScheduleInMatrix",
                    SYSDATE, SYSDATE
                FROM STG_PCS_PIPE_SIZES
                WHERE plant_id = p_plant_id;

            WHEN 'VALVE_ELEMENTS' THEN
                -- Step 1: Clear staging
                DELETE FROM STG_PCS_VALVE_ELEMENTS WHERE plant_id = p_plant_id;
                
                -- Step 2: JSON -> Staging (all VARCHAR2)
                INSERT INTO STG_PCS_VALVE_ELEMENTS (
                    plant_id, pcs_name, "Revision", "ValveGroupNo", "LineNo",
                    "ValveType", "VDS", "ValveDescription", "FromSize", "ToSize",
                    "Revmark", "Remark", "PageBreak", "NoteID", "PreviousVDS",
                    "NewDeletedLine", "InitialInfo", "InitialRevmark",
                    "SizeRange", "Status", "VDSRevision"
                )
                SELECT
                    p_plant_id, p_pcs_name, p_revision,
                    valve_group_no, line_no, valve_type, vds, valve_description,
                    from_size, to_size, revmark, remark, page_break, note_id,
                    previous_vds, new_deleted_line, initial_info, initial_revmark,
                    size_range, status, vds_revision
                FROM JSON_TABLE(v_json, '$.getValveElement[*]'
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
                        page_break VARCHAR2(10) PATH '$.PageBreak',
                        note_id VARCHAR2(50) PATH '$.NoteID',
                        previous_vds VARCHAR2(100) PATH '$.PreviousVDS',
                        new_deleted_line VARCHAR2(50) PATH '$.NewDeletedLine',
                        initial_info VARCHAR2(500) PATH '$.InitialInfo',
                        initial_revmark VARCHAR2(50) PATH '$.InitialRevmark',
                        size_range VARCHAR2(100) PATH '$.SizeRange',
                        status VARCHAR2(50) PATH '$.Status',
                        vds_revision VARCHAR2(50) PATH '$.Revision'
                    ));
                
                -- Step 3: Staging -> Core (with type conversions)
                DELETE FROM PCS_VALVE_ELEMENTS
                WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND revision = p_revision;
                
                INSERT INTO PCS_VALVE_ELEMENTS (
                    pcs_valve_elements_guid, plant_id, pcs_name, revision,
                    valve_group_no, line_no, valve_type, vds, valve_description,
                    from_size, to_size, revmark, remark, page_break, note_id,
                    previous_vds, new_deleted_line, initial_info, initial_revmark,
                    size_range, status, vds_revision,
                    created_date, last_modified_date
                )
                SELECT
                    SYS_GUID(), plant_id, pcs_name, "Revision",
                    TO_NUMBER("ValveGroupNo"), TO_NUMBER("LineNo"),
                    "ValveType", "VDS", "ValveDescription",
                    "FromSize", "ToSize", "Revmark", "Remark",
                    "PageBreak", "NoteID", "PreviousVDS",
                    "NewDeletedLine", "InitialInfo", "InitialRevmark",
                    "SizeRange", "Status", "VDSRevision",
                    SYSDATE, SYSDATE
                FROM STG_PCS_VALVE_ELEMENTS
                WHERE plant_id = p_plant_id
                AND "ValveGroupNo" IS NOT NULL
                AND "LineNo" IS NOT NULL;

            WHEN 'PIPE_ELEMENTS' THEN
                -- Step 1: Clear staging
                DELETE FROM STG_PCS_PIPE_ELEMENTS WHERE plant_id = p_plant_id;
                
                -- Step 2: JSON -> Staging (all VARCHAR2)
                INSERT INTO STG_PCS_PIPE_ELEMENTS (
                    plant_id, "PCS", "Revision", "MaterialGroupID",
                    "ElementGroupNo", "LineNo", "Element", "DimStandard",
                    "FromSize", "ToSize", "ProductForm", "Material",
                    "MDS", "EDS", "EDSRevision", "ESK", "Revmark",
                    "Remark", "PageBreak", "ElementID", "FreeText",
                    "NoteID", "NewDeletedLine", "InitialInfo",
                    "InitialRevmark", "MDSVariant", "MDSRevision", "Area"
                )
                SELECT
                    p_plant_id, p_pcs_name, p_revision,
                    material_group_id, element_group_no, line_no, element,
                    dim_standard, from_size, to_size, product_form, material,
                    mds, eds, eds_revision, esk, revmark, remark, page_break,
                    element_id, free_text, note_id, new_deleted_line,
                    initial_info, initial_revmark, mds_variant, mds_revision, area
                FROM JSON_TABLE(v_json, '$.getPipeElement[*]'
                    COLUMNS (
                        material_group_id VARCHAR2(50) PATH '$.MaterialGroupID',
                        element_group_no VARCHAR2(50) PATH '$.ElementGroupNo',
                        line_no VARCHAR2(50) PATH '$.LineNo',
                        element VARCHAR2(200) PATH '$.Element',
                        dim_standard VARCHAR2(100) PATH '$.DimStandard',
                        from_size VARCHAR2(50) PATH '$.FromSize',
                        to_size VARCHAR2(50) PATH '$.ToSize',
                        product_form VARCHAR2(100) PATH '$.ProductForm',
                        material VARCHAR2(200) PATH '$.Material',
                        mds VARCHAR2(100) PATH '$.MDS',
                        eds VARCHAR2(100) PATH '$.EDS',
                        eds_revision VARCHAR2(50) PATH '$.EDSRevision',
                        esk VARCHAR2(100) PATH '$.ESK',
                        revmark VARCHAR2(50) PATH '$.Revmark',
                        remark VARCHAR2(500) PATH '$.Remark',
                        page_break VARCHAR2(10) PATH '$.PageBreak',
                        element_id VARCHAR2(50) PATH '$.ElementID',
                        free_text VARCHAR2(500) PATH '$.FreeText',
                        note_id VARCHAR2(50) PATH '$.NoteID',
                        new_deleted_line VARCHAR2(50) PATH '$.NewDeletedLine',
                        initial_info VARCHAR2(500) PATH '$.InitialInfo',
                        initial_revmark VARCHAR2(50) PATH '$.InitialRevmark',
                        mds_variant VARCHAR2(100) PATH '$.MDSVariant',
                        mds_revision VARCHAR2(50) PATH '$.MDSRevision',
                        area VARCHAR2(100) PATH '$.Area'
                    ));
                
                -- Step 3: Staging -> Core (with type conversions)
                DELETE FROM PCS_PIPE_ELEMENTS
                WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND revision = p_revision;
                
                INSERT INTO PCS_PIPE_ELEMENTS (
                    pcs_pipe_elements_guid, plant_id, pcs_name, revision,
                    material_group_id, element_group_no, line_no, element,
                    dim_standard, from_size, to_size, product_form, material,
                    mds, eds, eds_revision, esk, revmark, remark, page_break,
                    element_id, free_text, note_id, new_deleted_line,
                    initial_info, initial_revmark, mds_variant, mds_revision, area,
                    created_date, last_modified_date
                )
                SELECT
                    SYS_GUID(), plant_id, "PCS", "Revision",
                    TO_NUMBER("MaterialGroupID"), TO_NUMBER("ElementGroupNo"),
                    TO_NUMBER("LineNo"), "Element", "DimStandard",
                    "FromSize", "ToSize", "ProductForm", "Material",
                    "MDS", "EDS", "EDSRevision", "ESK", "Revmark",
                    "Remark", "PageBreak", TO_NUMBER("ElementID"),
                    "FreeText", "NoteID", "NewDeletedLine",
                    "InitialInfo", "InitialRevmark", "MDSVariant",
                    "MDSRevision", "Area",
                    SYSDATE, SYSDATE
                FROM STG_PCS_PIPE_ELEMENTS
                WHERE plant_id = p_plant_id
                AND "ElementGroupNo" IS NOT NULL
                AND "LineNo" IS NOT NULL;

            WHEN 'EMBEDDED_NOTES' THEN
                -- Step 1: Clear staging
                DELETE FROM STG_PCS_EMBEDDED_NOTES WHERE plant_id = p_plant_id;
                
                -- Step 2: JSON -> Staging (VARCHAR2 + CLOB for HTML)
                INSERT INTO STG_PCS_EMBEDDED_NOTES (
                    plant_id, "PCSName", "Revision", "TextSectionID",
                    "TextSectionDescription", "PageBreak", "HTMLCLOB"
                )
                SELECT
                    p_plant_id, pcs_name, revision,
                    text_section_id, text_section_description,
                    page_break, html_clob
                FROM JSON_TABLE(v_json, '$.getEmbeddedNote[*]'
                    COLUMNS (
                        pcs_name VARCHAR2(100) PATH '$.PCSName',
                        revision VARCHAR2(50) PATH '$.Revision',
                        text_section_id VARCHAR2(50) PATH '$.TextSectionID',
                        text_section_description VARCHAR2(500) PATH '$.TextSectionDescription',
                        page_break VARCHAR2(10) PATH '$.PageBreak',
                        html_clob CLOB PATH '$.HTMLCLOB'
                    ));
                
                -- Step 3: Staging -> Core
                DELETE FROM PCS_EMBEDDED_NOTES
                WHERE plant_id = p_plant_id AND pcs_name = p_pcs_name AND revision = p_revision;
                
                INSERT INTO PCS_EMBEDDED_NOTES (
                    pcs_embedded_notes_guid, plant_id, pcs_name, revision,
                    text_section_id, text_section_description,
                    page_break, html_clob,
                    created_date, last_modified_date
                )
                SELECT
                    SYS_GUID(), plant_id, p_pcs_name, p_revision,
                    "TextSectionID", "TextSectionDescription",
                    "PageBreak", "HTMLCLOB",
                    SYSDATE, SYSDATE
                FROM STG_PCS_EMBEDDED_NOTES
                WHERE plant_id = p_plant_id
                AND "TextSectionID" IS NOT NULL;

            ELSE
                RAISE_APPLICATION_ERROR(-20002, 'Unknown PCS detail type: ' || p_detail_type);
        END CASE;

        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            v_err_msg := SQLERRM;
            INSERT INTO ETL_ERROR_LOG (
                endpoint_key, plant_id, error_timestamp, error_message
            ) VALUES (
                'PCS_' || p_detail_type, p_plant_id, SYSTIMESTAMP, v_err_msg
            );
            COMMIT;
            RAISE;
    END process_pcs_detail;

END PKG_PCS_DETAIL_PROCESSOR;
/

SHOW ERRORS