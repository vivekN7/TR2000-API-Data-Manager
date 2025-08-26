-- ===============================================================================
-- Package: PKG_UPSERT_PLANTS
-- Purpose: Merges plant data from staging into PLANTS table
-- ===============================================================================

-- Package Specification
CREATE OR REPLACE PACKAGE pkg_upsert_plants AS
    PROCEDURE upsert_plants;
END pkg_upsert_plants;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY pkg_upsert_plants AS

    PROCEDURE upsert_plants IS
    BEGIN
        -- First, mark all existing plants as invalid
        UPDATE PLANTS SET is_valid = 'N';

        -- Merge staging data into PLANTS
        MERGE INTO PLANTS tgt
        USING (
            SELECT DISTINCT
                plant_id,
                TO_NUMBER(operator_id) as operator_id,
                operator_name,
                short_description,
                project,
                long_description,
                common_lib_plant_code,
                initial_revision,
                TO_NUMBER(area_id) as area_id,
                area,
                CASE WHEN UPPER(enable_embedded_note) IN ('TRUE', 'Y', '1') THEN 'Y' ELSE 'N' END as enable_embedded_note,
                category_id,
                category,
                document_space_link,
                CASE WHEN UPPER(enable_copy_pcs_from_plant) IN ('TRUE', 'Y', '1') THEN 'Y' ELSE 'N' END as enable_copy_pcs_from_plant,
                CASE WHEN UPPER(over_length) IN ('TRUE', 'Y', '1') THEN 'Y' ELSE 'N' END as over_length,
                CASE WHEN UPPER(pcs_qa) IN ('TRUE', 'Y', '1') THEN 'Y' ELSE 'N' END as pcs_qa,
                CASE WHEN UPPER(eds_mj) IN ('TRUE', 'Y', '1') THEN 'Y' ELSE 'N' END as eds_mj,
                CASE WHEN UPPER(celsius_bar) IN ('TRUE', 'Y', '1') THEN 'Y' ELSE 'N' END as celsius_bar,
                web_info_text,
                bolt_tension_text,
                CASE WHEN UPPER(visible) IN ('TRUE', 'Y', '1') THEN 'Y' ELSE 'N' END as visible,
                windows_remark_text,
                CASE WHEN UPPER(user_protected) IN ('TRUE', 'Y', '1') THEN 'Y' ELSE 'N' END as user_protected
            FROM STG_PLANTS
        ) src
        ON (tgt.plant_id = src.plant_id)
        WHEN MATCHED THEN
            UPDATE SET
                operator_id = src.operator_id,
                operator_name = src.operator_name,
                short_description = src.short_description,
                project = src.project,
                long_description = src.long_description,
                common_lib_plant_code = src.common_lib_plant_code,
                initial_revision = src.initial_revision,
                area_id = src.area_id,
                area = src.area,
                enable_embedded_note = src.enable_embedded_note,
                category_id = src.category_id,
                category = src.category,
                document_space_link = src.document_space_link,
                enable_copy_pcs_from_plant = src.enable_copy_pcs_from_plant,
                over_length = src.over_length,
                pcs_qa = src.pcs_qa,
                eds_mj = src.eds_mj,
                celsius_bar = src.celsius_bar,
                web_info_text = src.web_info_text,
                bolt_tension_text = src.bolt_tension_text,
                visible = src.visible,
                windows_remark_text = src.windows_remark_text,
                user_protected = src.user_protected,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                plant_id, operator_id, operator_name, short_description,
                project, long_description, common_lib_plant_code, initial_revision,
                area_id, area, enable_embedded_note, category_id, category,
                document_space_link, enable_copy_pcs_from_plant, over_length,
                pcs_qa, eds_mj, celsius_bar, web_info_text, bolt_tension_text,
                visible, windows_remark_text, user_protected, is_valid,
                created_date, last_modified_date, last_api_sync
            ) VALUES (
                src.plant_id, src.operator_id, src.operator_name, src.short_description,
                src.project, src.long_description, src.common_lib_plant_code, src.initial_revision,
                src.area_id, src.area, src.enable_embedded_note, src.category_id, src.category,
                src.document_space_link, src.enable_copy_pcs_from_plant, src.over_length,
                src.pcs_qa, src.eds_mj, src.celsius_bar, src.web_info_text, src.bolt_tension_text,
                src.visible, src.windows_remark_text, src.user_protected, 'Y',
                SYSDATE, SYSDATE, SYSTIMESTAMP
            );

        COMMIT;
    END upsert_plants;

END pkg_upsert_plants;
/