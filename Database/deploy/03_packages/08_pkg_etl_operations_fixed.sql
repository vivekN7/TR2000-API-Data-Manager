CREATE OR REPLACE PACKAGE BODY PKG_ETL_PROCESSOR AS

    -- Parse and load PCS references
    PROCEDURE parse_and_load_pcs_references(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2,
        p_issue_revision IN VARCHAR2
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_PCS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO STG_PCS_REFERENCES (
            plant_id, issue_revision, "PCS", "Revision", "RevDate", "Status", 
            "OfficialRevision", "RevisionSuffix", "RatingClass", "MaterialGroup", 
            "HistoricalPCS", "Delta"
        )
        SELECT
            p_plant_id, p_issue_revision, 
            jt."PCS", jt."Revision", jt."RevDate", jt."Status",
            jt."OfficialRevision", jt."RevisionSuffix", jt."RatingClass", 
            jt."MaterialGroup", jt."HistoricalPCS", jt."Delta"
        FROM JSON_TABLE(v_json, '$.getPCSReferences[*]'
            COLUMNS (
                "PCS" VARCHAR2(100) PATH '$.PCS',
                "Revision" VARCHAR2(50) PATH '$.Revision',
                "RevDate" VARCHAR2(50) PATH '$.RevDate',
                "Status" VARCHAR2(50) PATH '$.Status',
                "OfficialRevision" VARCHAR2(50) PATH '$.OfficialRevision',
                "RevisionSuffix" VARCHAR2(50) PATH '$.RevisionSuffix',
                "RatingClass" VARCHAR2(50) PATH '$.RatingClass',
                "MaterialGroup" VARCHAR2(50) PATH '$.MaterialGroup',
                "HistoricalPCS" VARCHAR2(50) PATH '$.HistoricalPCS',
                "Delta" VARCHAR2(50) PATH '$.Delta'
            )) jt;

        DELETE FROM PCS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO PCS_REFERENCES (
            pcs_references_guid, plant_id, issue_revision,  -- Fixed: uses pcs_references_guid
            pcs_name, revision, rev_date, status, official_revision,
            revision_suffix, rating_class, material_group, historical_pcs, delta,
            created_date, last_modified_date
        )
        SELECT
            SYS_GUID(), plant_id, issue_revision,
            "PCS", "Revision", TO_DATE("RevDate", 'YYYY-MM-DD'), "Status", "OfficialRevision",
            "RevisionSuffix", "RatingClass", "MaterialGroup", "HistoricalPCS", "Delta",
            SYSDATE, SYSDATE
        FROM STG_PCS_REFERENCES
        WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        COMMIT;
    END parse_and_load_pcs_references;

    -- Parse and load VDS references
    PROCEDURE parse_and_load_vds_references(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2,
        p_issue_revision IN VARCHAR2
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_VDS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO STG_VDS_REFERENCES (
            plant_id, issue_revision, "VDS", "Revision", "RevDate", "Status", "OfficialRevision", "Delta"
        )
        SELECT
            p_plant_id, p_issue_revision,
            jt."VDS", jt."Revision", jt."RevDate", jt."Status", jt."OfficialRevision", jt."Delta"
        FROM JSON_TABLE(v_json, '$.getVDSReferences[*]'
            COLUMNS (
                "VDS" VARCHAR2(100) PATH '$.VDS',
                "Revision" VARCHAR2(50) PATH '$.Revision',
                "RevDate" VARCHAR2(50) PATH '$.RevDate',
                "Status" VARCHAR2(50) PATH '$.Status',
                "OfficialRevision" VARCHAR2(50) PATH '$.OfficialRevision',
                "Delta" VARCHAR2(50) PATH '$.Delta'
            )) jt;

        DELETE FROM VDS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO VDS_REFERENCES (
            vds_references_guid, plant_id, issue_revision,  -- Fixed: uses vds_references_guid
            vds_name, revision, rev_date, status, official_revision, delta,
            created_date, last_modified_date
        )
        SELECT
            SYS_GUID(), plant_id, issue_revision,
            "VDS", "Revision", TO_DATE("RevDate", 'YYYY-MM-DD'), "Status", "OfficialRevision", "Delta",
            SYSDATE, SYSDATE
        FROM STG_VDS_REFERENCES
        WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        COMMIT;
    END parse_and_load_vds_references;

    -- Parse and load MDS references
    PROCEDURE parse_and_load_mds_references(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2,
        p_issue_revision IN VARCHAR2
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_MDS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO STG_MDS_REFERENCES (
            plant_id, issue_revision, "MDS", "Revision", "Area", "RevDate", "Status", "OfficialRevision", "Delta"
        )
        SELECT
            p_plant_id, p_issue_revision,
            jt."MDS", jt."Revision", jt."Area", jt."RevDate", jt."Status", jt."OfficialRevision", jt."Delta"
        FROM JSON_TABLE(v_json, '$.getMDSReferences[*]'
            COLUMNS (
                "MDS" VARCHAR2(100) PATH '$.MDS',
                "Revision" VARCHAR2(50) PATH '$.Revision',
                "Area" VARCHAR2(100) PATH '$.Area',
                "RevDate" VARCHAR2(50) PATH '$.RevDate',
                "Status" VARCHAR2(50) PATH '$.Status',
                "OfficialRevision" VARCHAR2(50) PATH '$.OfficialRevision',
                "Delta" VARCHAR2(50) PATH '$.Delta'
            )) jt;

        DELETE FROM MDS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO MDS_REFERENCES (
            mds_references_guid, plant_id, issue_revision,  -- Fixed: uses mds_references_guid
            mds_name, revision, area, rev_date, status, official_revision, delta,
            created_date, last_modified_date
        )
        SELECT
            SYS_GUID(), plant_id, issue_revision,
            "MDS", "Revision", "Area", TO_DATE("RevDate", 'YYYY-MM-DD'), "Status", "OfficialRevision", "Delta",
            SYSDATE, SYSDATE
        FROM STG_MDS_REFERENCES
        WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        COMMIT;
    END parse_and_load_mds_references;

    -- Parse and load EDS references
    PROCEDURE parse_and_load_eds_references(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2,
        p_issue_revision IN VARCHAR2
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_EDS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO STG_EDS_REFERENCES (
            plant_id, issue_revision, "EDS", "Revision", "RevDate", "Status", "OfficialRevision", "Delta"
        )
        SELECT
            p_plant_id, p_issue_revision,
            jt."EDS", jt."Revision", jt."RevDate", jt."Status", jt."OfficialRevision", jt."Delta"
        FROM JSON_TABLE(v_json, '$.getEDSReferences[*]'
            COLUMNS (
                "EDS" VARCHAR2(100) PATH '$.EDS',
                "Revision" VARCHAR2(50) PATH '$.Revision',
                "RevDate" VARCHAR2(50) PATH '$.RevDate',
                "Status" VARCHAR2(50) PATH '$.Status',
                "OfficialRevision" VARCHAR2(50) PATH '$.OfficialRevision',
                "Delta" VARCHAR2(50) PATH '$.Delta'
            )) jt;

        DELETE FROM EDS_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO EDS_REFERENCES (
            eds_references_guid, plant_id, issue_revision,  -- Fixed: uses eds_references_guid
            eds_name, revision, rev_date, status, official_revision, delta,
            created_date, last_modified_date
        )
        SELECT
            SYS_GUID(), plant_id, issue_revision,
            "EDS", "Revision", TO_DATE("RevDate", 'YYYY-MM-DD'), "Status", "OfficialRevision", "Delta",
            SYSDATE, SYSDATE
        FROM STG_EDS_REFERENCES
        WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        COMMIT;
    END parse_and_load_eds_references;

    -- Parse and load VSK references
    PROCEDURE parse_and_load_vsk_references(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2,
        p_issue_revision IN VARCHAR2
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_VSK_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO STG_VSK_REFERENCES (
            plant_id, issue_revision, "VSK", "Revision", "RevDate", "Status", "OfficialRevision", "Delta"
        )
        SELECT
            p_plant_id, p_issue_revision,
            jt."VSK", jt."Revision", jt."RevDate", jt."Status", jt."OfficialRevision", jt."Delta"
        FROM JSON_TABLE(v_json, '$.getVSKReferences[*]'
            COLUMNS (
                "VSK" VARCHAR2(100) PATH '$.VSK',
                "Revision" VARCHAR2(50) PATH '$.Revision',
                "RevDate" VARCHAR2(50) PATH '$.RevDate',
                "Status" VARCHAR2(50) PATH '$.Status',
                "OfficialRevision" VARCHAR2(50) PATH '$.OfficialRevision',
                "Delta" VARCHAR2(50) PATH '$.Delta'
            )) jt;

        DELETE FROM VSK_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO VSK_REFERENCES (
            vsk_references_guid, plant_id, issue_revision,  -- Fixed: uses vsk_references_guid
            vsk_name, revision, rev_date, status, official_revision, delta,
            created_date, last_modified_date
        )
        SELECT
            SYS_GUID(), plant_id, issue_revision,
            "VSK", "Revision", TO_DATE("RevDate", 'YYYY-MM-DD'), "Status", "OfficialRevision", "Delta",
            SYSDATE, SYSDATE
        FROM STG_VSK_REFERENCES
        WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        COMMIT;
    END parse_and_load_vsk_references;

    -- Parse and load ESK references
    PROCEDURE parse_and_load_esk_references(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2,
        p_issue_revision IN VARCHAR2
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_ESK_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO STG_ESK_REFERENCES (
            plant_id, issue_revision, "ESK", "Revision", "RevDate", "Status", "OfficialRevision", "Delta"
        )
        SELECT
            p_plant_id, p_issue_revision,
            jt."ESK", jt."Revision", jt."RevDate", jt."Status", jt."OfficialRevision", jt."Delta"
        FROM JSON_TABLE(v_json, '$.getESKReferences[*]'
            COLUMNS (
                "ESK" VARCHAR2(100) PATH '$.ESK',
                "Revision" VARCHAR2(50) PATH '$.Revision',
                "RevDate" VARCHAR2(50) PATH '$.RevDate',
                "Status" VARCHAR2(50) PATH '$.Status',
                "OfficialRevision" VARCHAR2(50) PATH '$.OfficialRevision',
                "Delta" VARCHAR2(50) PATH '$.Delta'
            )) jt;

        DELETE FROM ESK_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO ESK_REFERENCES (
            esk_references_guid, plant_id, issue_revision,  -- Fixed: uses esk_references_guid
            esk_name, revision, rev_date, status, official_revision, delta,
            created_date, last_modified_date
        )
        SELECT
            SYS_GUID(), plant_id, issue_revision,
            "ESK", "Revision", TO_DATE("RevDate", 'YYYY-MM-DD'), "Status", "OfficialRevision", "Delta",
            SYSDATE, SYSDATE
        FROM STG_ESK_REFERENCES
        WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        COMMIT;
    END parse_and_load_esk_references;

    -- Parse and load PIPE_ELEMENT references  
    PROCEDURE parse_and_load_pipe_element_references(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2,
        p_issue_revision IN VARCHAR2
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_PIPE_ELEMENT_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO STG_PIPE_ELEMENT_REFERENCES (
            plant_id, issue_revision, "ElementID", "ElementGroup", "DimensionStandard", 
            "ProductForm", "MaterialGrade", "MDS", "MDSRevision", "Area", 
            "Revision", "RevDate", "Status", "Delta"
        )
        SELECT
            p_plant_id, p_issue_revision,
            jt."ElementID", jt."ElementGroup", jt."DimensionStandard",
            jt."ProductForm", jt."MaterialGrade", jt."MDS", jt."MDSRevision", jt."Area",
            jt."Revision", jt."RevDate", jt."Status", jt."Delta"
        FROM JSON_TABLE(v_json, '$.getPipeElementReferences[*]'
            COLUMNS (
                "ElementID" VARCHAR2(100) PATH '$.ElementID',
                "ElementGroup" VARCHAR2(100) PATH '$.ElementGroup',
                "DimensionStandard" VARCHAR2(100) PATH '$.DimensionStandard',
                "ProductForm" VARCHAR2(100) PATH '$.ProductForm',
                "MaterialGrade" VARCHAR2(100) PATH '$.MaterialGrade',
                "MDS" VARCHAR2(100) PATH '$.MDS',
                "MDSRevision" VARCHAR2(50) PATH '$.MDSRevision',
                "Area" VARCHAR2(100) PATH '$.Area',
                "Revision" VARCHAR2(50) PATH '$.Revision',
                "RevDate" VARCHAR2(50) PATH '$.RevDate',
                "Status" VARCHAR2(50) PATH '$.Status',
                "Delta" VARCHAR2(50) PATH '$.Delta'
            )) jt;

        DELETE FROM PIPE_ELEMENT_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO PIPE_ELEMENT_REFERENCES (
            pipe_element_references_guid, plant_id, issue_revision,  -- Fixed: uses pipe_element_references_guid
            element_id, element_group, dimension_standard, product_form, material_grade,
            mds, mds_revision, area, revision, rev_date, status, delta,
            created_date, last_modified_date
        )
        SELECT
            SYS_GUID(), plant_id, issue_revision,
            "ElementID", "ElementGroup", "DimensionStandard", "ProductForm", "MaterialGrade",
            "MDS", "MDSRevision", "Area", "Revision", TO_DATE("RevDate", 'YYYY-MM-DD'), "Status", "Delta",
            SYSDATE, SYSDATE
        FROM STG_PIPE_ELEMENT_REFERENCES
        WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        COMMIT;
    END parse_and_load_pipe_element_references;

    -- Parse and load SC references
    PROCEDURE parse_and_load_sc_references(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2,
        p_issue_revision IN VARCHAR2
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_SC_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO STG_SC_REFERENCES (
            plant_id, issue_revision, "SC", "Revision", "RevDate", "Status", "OfficialRevision", "Delta"
        )
        SELECT
            p_plant_id, p_issue_revision,
            jt."SC", jt."Revision", jt."RevDate", jt."Status", jt."OfficialRevision", jt."Delta"
        FROM JSON_TABLE(v_json, '$.getSCReferences[*]'
            COLUMNS (
                "SC" VARCHAR2(100) PATH '$.SC',
                "Revision" VARCHAR2(50) PATH '$.Revision',
                "RevDate" VARCHAR2(50) PATH '$.RevDate',
                "Status" VARCHAR2(50) PATH '$.Status',
                "OfficialRevision" VARCHAR2(50) PATH '$.OfficialRevision',
                "Delta" VARCHAR2(50) PATH '$.Delta'
            )) jt;

        DELETE FROM SC_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO SC_REFERENCES (
            sc_references_guid, plant_id, issue_revision,  -- Fixed: uses sc_references_guid
            sc_name, revision, rev_date, status, official_revision, delta,
            created_date, last_modified_date
        )
        SELECT
            SYS_GUID(), plant_id, issue_revision,
            "SC", "Revision", TO_DATE("RevDate", 'YYYY-MM-DD'), "Status", "OfficialRevision", "Delta",
            SYSDATE, SYSDATE
        FROM STG_SC_REFERENCES
        WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        COMMIT;
    END parse_and_load_sc_references;

    -- Parse and load VSM references
    PROCEDURE parse_and_load_vsm_references(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2,
        p_issue_revision IN VARCHAR2
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_VSM_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO STG_VSM_REFERENCES (
            plant_id, issue_revision, "VSM", "Revision", "RevDate", "Status", "OfficialRevision", "Delta"
        )
        SELECT
            p_plant_id, p_issue_revision,
            jt."VSM", jt."Revision", jt."RevDate", jt."Status", jt."OfficialRevision", jt."Delta"
        FROM JSON_TABLE(v_json, '$.getVSMReferences[*]'
            COLUMNS (
                "VSM" VARCHAR2(100) PATH '$.VSM',
                "Revision" VARCHAR2(50) PATH '$.Revision',
                "RevDate" VARCHAR2(50) PATH '$.RevDate',
                "Status" VARCHAR2(50) PATH '$.Status',
                "OfficialRevision" VARCHAR2(50) PATH '$.OfficialRevision',
                "Delta" VARCHAR2(50) PATH '$.Delta'
            )) jt;

        DELETE FROM VSM_REFERENCES WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        INSERT INTO VSM_REFERENCES (
            vsm_references_guid, plant_id, issue_revision,  -- Fixed: uses vsm_references_guid
            vsm_name, revision, rev_date, status, official_revision, delta,
            created_date, last_modified_date
        )
        SELECT
            SYS_GUID(), plant_id, issue_revision,
            "VSM", "Revision", TO_DATE("RevDate", 'YYYY-MM-DD'), "Status", "OfficialRevision", "Delta",
            SYSDATE, SYSDATE
        FROM STG_VSM_REFERENCES
        WHERE plant_id = p_plant_id AND issue_revision = p_issue_revision;

        COMMIT;
    END parse_and_load_vsm_references;

    -- Parse and load PCS list
    PROCEDURE parse_and_load_pcs_list(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_PCS_LIST WHERE plant_id = p_plant_id;

        INSERT INTO STG_PCS_LIST (
            plant_id, "PCS", "Revision", "Status", "RevDate", "RatingClass", 
            "TestPressure", "MaterialGroup", "DesignCode", "LastUpdate", 
            "LastUpdateBy", "Approver", "Notepad", "SpecialReqID", "TubePCS", "NewVDSSection"
        )
        SELECT
            p_plant_id,
            jt."PCS", jt."Revision", jt."Status", jt."RevDate", jt."RatingClass",
            jt."TestPressure", jt."MaterialGroup", jt."DesignCode", jt."LastUpdate",
            jt."LastUpdateBy", jt."Approver", jt."Notepad", jt."SpecialReqID", jt."TubePCS", jt."NewVDSSection"
        FROM JSON_TABLE(v_json, '$.getPCSList[*]'
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
                "SpecialReqID" VARCHAR2(50) PATH '$.SpecialReqID',
                "TubePCS" VARCHAR2(50) PATH '$.TubePCS',
                "NewVDSSection" VARCHAR2(50) PATH '$.NewVDSSection'
            )) jt;

        DELETE FROM PCS_LIST WHERE plant_id = p_plant_id;

        INSERT INTO PCS_LIST (
            pcs_list_guid, plant_id, pcs_name, revision, status, rev_date,
            rating_class, test_pressure, material_group, design_code, last_update,
            last_update_by, approver, notepad, special_req_id, tube_pcs, new_vds_section,
            created_date, last_modified_date
        )
        SELECT
            SYS_GUID(), plant_id, "PCS", "Revision", "Status", TO_DATE("RevDate", 'YYYY-MM-DD'),
            "RatingClass", TO_NUMBER("TestPressure"), "MaterialGroup", "DesignCode", TO_DATE("LastUpdate", 'YYYY-MM-DD'),
            "LastUpdateBy", "Approver", "Notepad", "SpecialReqID", "TubePCS", "NewVDSSection",
            SYSDATE, SYSDATE
        FROM STG_PCS_LIST
        WHERE plant_id = p_plant_id;

        COMMIT;
    END parse_and_load_pcs_list;

    -- Parse and load PCS details (delegated to PKG_PCS_DETAIL_PROCESSOR)
    PROCEDURE parse_and_load_pcs_details(
        p_raw_json_id IN NUMBER,
        p_plant_id IN VARCHAR2,
        p_pcs_name IN VARCHAR2,
        p_revision IN VARCHAR2,
        p_detail_type IN VARCHAR2
    ) IS
    BEGIN
        PKG_PCS_DETAIL_PROCESSOR.process_pcs_detail(
            p_raw_json_id, p_plant_id, p_pcs_name, p_revision, p_detail_type
        );
    END parse_and_load_pcs_details;

    -- Parse and load VDS catalog
    PROCEDURE parse_and_load_vds_catalog(
        p_raw_json_id IN NUMBER
    ) IS
        v_json CLOB;
    BEGIN
        SELECT payload INTO v_json FROM RAW_JSON WHERE raw_json_id = p_raw_json_id;

        -- Implementation would go here based on VDS catalog structure
        -- Placeholder for now
        NULL;
        
        COMMIT;
    END parse_and_load_vds_catalog;

END PKG_ETL_PROCESSOR;
/