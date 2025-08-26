-- ===============================================================================
-- Package: PKG_PARSE_PLANTS
-- Purpose: Parses plant JSON data from RAW_JSON into STG_PLANTS staging table
-- ===============================================================================

-- Package Specification
CREATE OR REPLACE PACKAGE pkg_parse_plants AS
    PROCEDURE parse_plants_json(p_raw_json_id NUMBER);
    PROCEDURE clear_staging;
END pkg_parse_plants;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY pkg_parse_plants AS

    PROCEDURE clear_staging IS
    BEGIN
        DELETE FROM STG_PLANTS;
    END clear_staging;

    PROCEDURE parse_plants_json(p_raw_json_id NUMBER) IS
    BEGIN
        -- Clear staging first
        clear_staging;

        -- Parse JSON and insert into staging
        INSERT INTO STG_PLANTS (
            raw_json_id,
            operator_id,
            operator_name,
            plant_id,
            short_description,
            project,
            long_description,
            common_lib_plant_code,
            initial_revision,
            area_id,
            area,
            enable_embedded_note,
            category_id,
            category,
            document_space_link,
            enable_copy_pcs_from_plant,
            over_length,
            pcs_qa,
            eds_mj,
            celsius_bar,
            web_info_text,
            bolt_tension_text,
            visible,
            windows_remark_text,
            user_protected
        )
        SELECT
            p_raw_json_id,
            TO_CHAR(OperatorID),
            OperatorName,
            TO_CHAR(PlantID),
            ShortDescription,
            Project,
            LongDescription,
            CommonLibPlantCode,
            InitialRevision,
            TO_CHAR(AreaID),
            Area,
            EnableEmbeddedNote,
            CategoryID,
            Category,
            DocumentSpaceLink,
            EnableCopyPCSFromPlant,
            OverLength,
            PCSQA,
            EDSMJ,
            CelsiusBar,
            WebInfoText,
            BoltTensionText,
            Visible,
            WindowsRemarkText,
            UserProtected
        FROM RAW_JSON r,
        JSON_TABLE(r.response_json, '$.getPlant[*]'
            COLUMNS (
                OperatorID NUMBER PATH '$.OperatorID',
                OperatorName VARCHAR2(255) PATH '$.OperatorName',
                PlantID NUMBER PATH '$.PlantID',
                ShortDescription VARCHAR2(255) PATH '$.ShortDescription',
                Project VARCHAR2(255) PATH '$.Project',
                LongDescription VARCHAR2(4000) PATH '$.LongDescription',
                CommonLibPlantCode VARCHAR2(50) PATH '$.CommonLibPlantCode',
                InitialRevision VARCHAR2(50) PATH '$.InitialRevision',
                AreaID NUMBER PATH '$.AreaID',
                Area VARCHAR2(255) PATH '$.Area',
                EnableEmbeddedNote VARCHAR2(50) PATH '$.EnableEmbeddedNote',
                CategoryID VARCHAR2(50) PATH '$.CategoryID',
                Category VARCHAR2(255) PATH '$.Category',
                DocumentSpaceLink VARCHAR2(500) PATH '$.DocumentSpaceLink',
                EnableCopyPCSFromPlant VARCHAR2(50) PATH '$.EnableCopyPCSFromPlant',
                OverLength VARCHAR2(50) PATH '$.OverLength',
                PCSQA VARCHAR2(50) PATH '$.PCSQA',
                EDSMJ VARCHAR2(50) PATH '$.EDSMJ',
                CelsiusBar VARCHAR2(50) PATH '$.CelsiusBar',
                WebInfoText VARCHAR2(4000) PATH '$.WebInfoText',
                BoltTensionText VARCHAR2(4000) PATH '$.BoltTensionText',
                Visible VARCHAR2(50) PATH '$.Visible',
                WindowsRemarkText VARCHAR2(4000) PATH '$.WindowsRemarkText',
                UserProtected VARCHAR2(50) PATH '$.UserProtected'
            )
        ) jt
        WHERE r.raw_json_id = p_raw_json_id;

        COMMIT;
    END parse_plants_json;

END pkg_parse_plants;
/