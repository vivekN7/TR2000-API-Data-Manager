-- ===============================================================================
-- Migration V003: Create ETL Packages
-- Author: System
-- Date: 2025-08-23
-- Description: Core ETL packages for data processing
-- Dependencies: V001, V002
-- ===============================================================================

-- Record migration start
EXEC pr_record_migration('V003', 'Create ETL packages', 'V003__etl_packages.sql');

-- ===============================================================================
-- Package: PKG_RAW_INGEST
-- ===============================================================================
CREATE OR REPLACE PACKAGE pkg_raw_ingest AS
    FUNCTION is_duplicate_hash(p_hash VARCHAR2) RETURN BOOLEAN;
    
    FUNCTION insert_raw_json(
        p_endpoint_key VARCHAR2,
        p_plant_id VARCHAR2,
        p_issue_revision VARCHAR2,
        p_api_url VARCHAR2,
        p_response_json CLOB,
        p_response_hash VARCHAR2
    ) RETURN NUMBER;
END pkg_raw_ingest;
/

CREATE OR REPLACE PACKAGE BODY pkg_raw_ingest AS
    
    FUNCTION is_duplicate_hash(p_hash VARCHAR2) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM RAW_JSON
        WHERE response_hash = p_hash;
        
        RETURN (v_count > 0);
    END is_duplicate_hash;
    
    FUNCTION insert_raw_json(
        p_endpoint_key VARCHAR2,
        p_plant_id VARCHAR2,
        p_issue_revision VARCHAR2,
        p_api_url VARCHAR2,
        p_response_json CLOB,
        p_response_hash VARCHAR2
    ) RETURN NUMBER IS
        v_raw_json_id NUMBER;
    BEGIN
        INSERT INTO RAW_JSON (
            endpoint_key, plant_id, issue_revision,
            api_url, response_json, response_hash
        ) VALUES (
            p_endpoint_key, p_plant_id, p_issue_revision,
            p_api_url, p_response_json, p_response_hash
        ) RETURNING raw_json_id INTO v_raw_json_id;
        
        RETURN v_raw_json_id;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            SELECT raw_json_id INTO v_raw_json_id
            FROM RAW_JSON
            WHERE response_hash = p_response_hash;
            RETURN v_raw_json_id;
    END insert_raw_json;
    
END pkg_raw_ingest;
/

-- ===============================================================================
-- Package: PKG_PARSE_PLANTS
-- ===============================================================================
CREATE OR REPLACE PACKAGE pkg_parse_plants AS
    PROCEDURE parse_plants_json(
        p_parsed_count OUT NUMBER,
        p_status OUT VARCHAR2
    );
END pkg_parse_plants;
/

CREATE OR REPLACE PACKAGE BODY pkg_parse_plants AS
    
    PROCEDURE parse_plants_json(
        p_parsed_count OUT NUMBER,
        p_status OUT VARCHAR2
    ) IS
        v_count NUMBER := 0;
    BEGIN
        FOR rec IN (
            SELECT raw_json_id, response_json
            FROM RAW_JSON
            WHERE endpoint_key = 'plants'
            AND raw_json_id NOT IN (
                SELECT DISTINCT raw_json_id FROM STG_PLANTS
            )
        ) LOOP
            INSERT INTO STG_PLANTS (
                raw_json_id, operator_id, operator_name, plant_id,
                short_description, project, long_description,
                common_lib_plant_code, initial_revision, area_id, area,
                enable_embedded_note, category_id, category,
                document_space_link, enable_copy_pcs_from_plant,
                over_length, pcs_qa, eds_mj, celsius_bar, web_info_text,
                show_issues_from_common_lib_plant
            )
            SELECT 
                rec.raw_json_id,
                OperatorID, OperatorName, PlantID,
                ShortDescription, Project, LongDescription,
                CommonLibPlantCode, InitialRevision, AreaID, Area,
                EnableEmbeddedNote, CategoryID, Category,
                DocumentSpaceLink, EnableCopyPcsFromPlant,
                OverLength, PcsQA, EdsMJ, CelsiusBar, WebInfoText,
                ShowIssuesFromCommonLibPlant
            FROM JSON_TABLE(rec.response_json, '$.getPlant[*]'
                COLUMNS (
                    OperatorID VARCHAR2(50) PATH '$.OperatorID',
                    OperatorName VARCHAR2(255) PATH '$.OperatorName',
                    PlantID VARCHAR2(50) PATH '$.PlantID',
                    ShortDescription VARCHAR2(255) PATH '$.ShortDescription',
                    Project VARCHAR2(255) PATH '$.Project',
                    LongDescription VARCHAR2(4000) PATH '$.LongDescription',
                    CommonLibPlantCode VARCHAR2(50) PATH '$.CommonLibPlantCode',
                    InitialRevision VARCHAR2(50) PATH '$.InitialRevision',
                    AreaID VARCHAR2(50) PATH '$.AreaID',
                    Area VARCHAR2(255) PATH '$.Area',
                    EnableEmbeddedNote VARCHAR2(10) PATH '$.EnableEmbeddedNote',
                    CategoryID VARCHAR2(50) PATH '$.CategoryID',
                    Category VARCHAR2(255) PATH '$.Category',
                    DocumentSpaceLink VARCHAR2(500) PATH '$.DocumentSpaceLink',
                    EnableCopyPcsFromPlant VARCHAR2(10) PATH '$.EnableCopyPcsFromPlant',
                    OverLength VARCHAR2(10) PATH '$.OverLength',
                    PcsQA VARCHAR2(10) PATH '$.PcsQA',
                    EdsMJ VARCHAR2(10) PATH '$.EdsMJ',
                    CelsiusBar VARCHAR2(10) PATH '$.CelsiusBar',
                    WebInfoText VARCHAR2(4000) PATH '$.WebInfoText',
                    ShowIssuesFromCommonLibPlant VARCHAR2(10) PATH '$.ShowIssuesFromCommonLibPlant'
                )
            );
            
            v_count := v_count + SQL%ROWCOUNT;
        END LOOP;
        
        p_parsed_count := v_count;
        p_status := 'SUCCESS';
        
    EXCEPTION
        WHEN OTHERS THEN
            p_parsed_count := v_count;
            p_status := 'ERROR: ' || SQLERRM;
            RAISE;
    END parse_plants_json;
    
END pkg_parse_plants;
/

-- Similar packages for ISSUES and UPSERT operations would follow...
-- Keeping this migration focused on core packages

COMMIT;