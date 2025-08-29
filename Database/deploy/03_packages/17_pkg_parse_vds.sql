-- ===============================================================================
-- PKG_PARSE_VDS - Parse VDS List and VDS Detail JSON Data
-- Session 18: VDS Details Implementation
-- Purpose: Parse JSON data for VDS list (44k records) and VDS details
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_parse_vds AS
    
    -- Parse VDS master list from /vds endpoint (4.1)
    PROCEDURE parse_vds_list(
        p_raw_json_id    IN NUMBER
    );
    
    -- Parse VDS details from /vds/{name}/rev/{revision} endpoint (4.2)
    PROCEDURE parse_vds_details(
        p_raw_json_id    IN NUMBER,
        p_vds_name       IN VARCHAR2,
        p_revision       IN VARCHAR2
    );
    
    -- Utility procedure to clear staging tables
    PROCEDURE clear_staging_tables;
    
END pkg_parse_vds;
/

CREATE OR REPLACE PACKAGE BODY pkg_parse_vds AS

    -- =========================================================================
    -- Parse VDS master list (endpoint 4.1)
    -- This will handle 44,000+ records from single API call
    -- =========================================================================
    PROCEDURE parse_vds_list(
        p_raw_json_id    IN NUMBER
    ) IS
        v_json_content CLOB;
        v_record_count NUMBER := 0;
        v_error_count  NUMBER := 0;
    BEGIN
        -- Get JSON content from RAW_JSON
        SELECT payload INTO v_json_content
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;
        
        -- Clear staging table (this is a full refresh)
        DELETE FROM STG_VDS_LIST;
        
        -- Parse JSON array and insert into staging
        -- Using JSON_TABLE for bulk processing
        INSERT INTO STG_VDS_LIST (
            vds_name,
            revision,
            status,
            rev_date,
            last_update,
            last_update_by,
            description,
            notepad,
            special_req_id,
            valve_type_id,
            rating_class_id,
            material_group_id,
            end_connection_id,
            bore_id,
            vds_size_id,
            size_range,
            custom_name,
            subsegment_list,
            raw_json,
            created_date,
            api_correlation_id
        )
        SELECT 
            vds_name,
            revision,
            status,
            rev_date,
            last_update,
            last_update_by,
            description,
            notepad,
            special_req_id,
            valve_type_id,
            rating_class_id,
            material_group_id,
            end_connection_id,
            bore_id,
            vds_size_id,
            size_range,
            custom_name,
            subsegment_list,
            NULL,  -- Skip storing individual JSON for now (too large)
            SYSDATE,
            SYS_GUID()
        FROM JSON_TABLE(
            v_json_content, '$.getVDS[*]'
            COLUMNS (
                vds_name          VARCHAR2(100)  PATH '$.VDS',
                revision          VARCHAR2(50)   PATH '$.Revision',
                status            VARCHAR2(50)   PATH '$.Status',
                rev_date          VARCHAR2(100)  PATH '$.RevDate',
                last_update       VARCHAR2(100)  PATH '$.LastUpdate',
                last_update_by    VARCHAR2(100)  PATH '$.LastUpdateBy',
                description       VARCHAR2(4000) PATH '$.Description',
                notepad           VARCHAR2(4000) PATH '$.Notepad',
                special_req_id    VARCHAR2(50)   PATH '$.SpecialReqID',
                valve_type_id     VARCHAR2(50)   PATH '$.ValveTypeID',
                rating_class_id   VARCHAR2(50)   PATH '$.RatingClassID',
                material_group_id VARCHAR2(50)   PATH '$.MaterialGroupID',
                end_connection_id VARCHAR2(50)   PATH '$.EndConnectionID',
                bore_id           VARCHAR2(50)   PATH '$.BoreID',
                vds_size_id       VARCHAR2(50)   PATH '$.VDSSizeID',
                size_range        VARCHAR2(100)  PATH '$.SizeRange',
                custom_name       VARCHAR2(200)  PATH '$.CustomName',
                subsegment_list   VARCHAR2(4000) PATH '$.SubsegmentList'
            )
        ) j;
        
        v_record_count := SQL%ROWCOUNT;
        
        -- Log results (simplified - no sequence needed)
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' VDS records from raw_json_id=' || p_raw_json_id);
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error
            DBMS_OUTPUT.PUT_LINE('Error parsing VDS list: ' || SQLERRM);
            ROLLBACK;
            RAISE;
    END parse_vds_list;

    -- =========================================================================
    -- Parse VDS details (endpoint 4.2)
    -- Parse detailed subsegment and property data for specific VDS/revision
    -- =========================================================================
    PROCEDURE parse_vds_details(
        p_raw_json_id    IN NUMBER,
        p_vds_name       IN VARCHAR2,
        p_revision       IN VARCHAR2
    ) IS
        v_json_content CLOB;
        v_record_count NUMBER := 0;
    BEGIN
        -- Get JSON content from RAW_JSON
        SELECT payload INTO v_json_content
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;
        
        -- Clear staging for this specific VDS/revision
        DELETE FROM STG_VDS_DETAILS
        WHERE vds_name = p_vds_name 
          AND revision = p_revision;
        
        -- Parse JSON - note this might be a single object or have subsegments
        -- The API response structure needs to be verified
        INSERT INTO STG_VDS_DETAILS (
            vds_name,
            revision,
            valve_type_id,
            rating_class_id,
            material_type_id,
            end_connection_id,
            full_reduced_bore_indicator,
            bore_id,
            vds_size_id,
            housing_design_indicator,
            housing_design_id,
            special_req_id,
            min_operating_temperature,
            max_operating_temperature,
            vds_description,
            notepad,
            rev_date,
            last_update,
            last_update_by,
            subsegment_id,
            subsegment_name,
            sequence_num,
            raw_json,
            created_date,
            api_correlation_id
        )
        SELECT 
            p_vds_name,  -- Pass in VDS name
            p_revision,  -- Pass in revision
            valve_type_id,
            rating_class_id,
            material_type_id,
            end_connection_id,
            full_reduced_bore_indicator,
            bore_id,
            vds_size_id,
            housing_design_indicator,
            housing_design_id,
            special_req_id,
            min_operating_temperature,
            max_operating_temperature,
            vds_description,
            notepad,
            rev_date,
            last_update,
            last_update_by,
            subsegment_id,
            subsegment_name,
            sequence_num,
            v_json_content,  -- Store full JSON
            SYSDATE,
            SYS_GUID()
        FROM JSON_TABLE(
            v_json_content, '$'
            COLUMNS (
                valve_type_id                VARCHAR2(50)   PATH '$.ValveTypeID',
                rating_class_id              VARCHAR2(50)   PATH '$.RatingClassID',
                material_type_id             VARCHAR2(50)   PATH '$.MaterialTypeID',
                end_connection_id            VARCHAR2(50)   PATH '$.EndConnectionID',
                full_reduced_bore_indicator  VARCHAR2(50)   PATH '$.FullReducedBoreIndicator',
                bore_id                      VARCHAR2(50)   PATH '$.BoreID',
                vds_size_id                  VARCHAR2(50)   PATH '$.VDSSizeID',
                housing_design_indicator     VARCHAR2(50)   PATH '$.HousingDesignIndicator',
                housing_design_id            VARCHAR2(50)   PATH '$.HousingDesignID',
                special_req_id               VARCHAR2(50)   PATH '$.SpecialReqID',
                min_operating_temperature    VARCHAR2(50)   PATH '$.MinOperatingTemperature',
                max_operating_temperature    VARCHAR2(50)   PATH '$.MaxOperatingTemperature',
                vds_description              VARCHAR2(4000) PATH '$.VDSDescription',
                notepad                      VARCHAR2(4000) PATH '$.Notepad',
                rev_date                     VARCHAR2(100)  PATH '$.RevDate',
                last_update                  VARCHAR2(100)  PATH '$.LastUpdate',
                last_update_by               VARCHAR2(100)  PATH '$.LastUpdateBy',
                subsegment_id                VARCHAR2(50)   PATH '$.SubsegmentID',
                subsegment_name              VARCHAR2(200)  PATH '$.SubsegmentName',
                sequence_num                 VARCHAR2(50)   PATH '$.Sequence'
            )
        );
        
        v_record_count := SQL%ROWCOUNT;
        
        -- Log results
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' detail records for VDS=' || p_vds_name || 
            ', revision=' || p_revision);
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error
            DBMS_OUTPUT.PUT_LINE('Error parsing VDS details: ' || SQLERRM);
            ROLLBACK;
            RAISE;
    END parse_vds_details;

    -- =========================================================================
    -- Clear staging tables
    -- =========================================================================
    PROCEDURE clear_staging_tables IS
    BEGIN
        DELETE FROM STG_VDS_LIST;
        DELETE FROM STG_VDS_DETAILS;
        COMMIT;
    END clear_staging_tables;

END pkg_parse_vds;
/

-- Grant necessary permissions
GRANT EXECUTE ON pkg_parse_vds TO TR2000_STAGING;
/