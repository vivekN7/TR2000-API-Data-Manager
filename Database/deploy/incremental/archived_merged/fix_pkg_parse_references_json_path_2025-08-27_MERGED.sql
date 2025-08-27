-- ===============================================================================
-- Fix PKG_PARSE_REFERENCES JSON Paths
-- Date: 2025-08-27
-- Purpose: Fix JSON paths to correctly parse API responses
-- ===============================================================================
-- The API returns data in a wrapper object, not as a direct array
-- PCS: $.getIssuePCSList[*]
-- SC: $.getIssueSCList[*]  
-- VSM: $.getIssueVSMList[*]
-- etc.
-- ===============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_PARSE_REFERENCES AS

    -- =========================================================================
    -- Parse PCS references JSON
    -- =========================================================================
    PROCEDURE parse_pcs_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    ) IS
        v_json_content CLOB;
        v_record_count NUMBER := 0;
    BEGIN
        -- Get JSON content from RAW_JSON
        SELECT response_json INTO v_json_content
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;

        -- Clear staging table for this plant/issue
        DELETE FROM STG_PCS_REFERENCES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev;

        -- Parse JSON and insert into staging
        -- FIX: Changed from '$[*]' to '$.getIssuePCSList[*]'
        INSERT INTO STG_PCS_REFERENCES (
            plant_id, issue_revision, pcs, revision, rev_date,
            status, official_revision, revision_suffix,
            rating_class, material_group, historical_pcs, delta
        )
        SELECT
            p_plant_id,
            p_issue_rev,
            jt.pcs,
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.official_revision,
            jt.revision_suffix,
            jt.rating_class,
            jt.material_group,
            jt.historical_pcs,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$.getIssuePCSList[*]'  -- FIXED PATH
            COLUMNS (
                pcs               VARCHAR2(100) PATH '$.PCS',
                revision          VARCHAR2(50)  PATH '$.Revision',
                rev_date          VARCHAR2(50)  PATH '$.RevDate',
                status            VARCHAR2(50)  PATH '$.Status',
                official_revision VARCHAR2(50)  PATH '$.OfficialRevision',
                revision_suffix   VARCHAR2(50)  PATH '$.RevisionSuffix',
                rating_class      VARCHAR2(100) PATH '$.RatingClass',
                material_group    VARCHAR2(100) PATH '$.MaterialGroup',
                historical_pcs    VARCHAR2(100) PATH '$.HistoricalPCS',
                delta             VARCHAR2(50)  PATH '$.Delta'
            )
        ) jt;

        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' PCS references');

    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20301,
                'Error parsing PCS JSON: ' || SQLERRM);
    END parse_pcs_json;

    -- =========================================================================
    -- Parse SC references JSON
    -- =========================================================================
    PROCEDURE parse_sc_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    ) IS
        v_json_content CLOB;
        v_record_count NUMBER := 0;
    BEGIN
        SELECT response_json INTO v_json_content
        FROM RAW_JSON
        WHERE raw_json_id = p_raw_json_id;

        DELETE FROM STG_SC_REFERENCES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev;

        -- FIX: Changed from '$[*]' to '$.getIssueSCList[*]'
        INSERT INTO STG_SC_REFERENCES (
            plant_id, issue_revision, sc, revision, rev_date,
            status, official_revision, delta
        )
        SELECT
            p_plant_id,
            p_issue_rev,
            jt.sc,
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.official_revision,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$.getIssueSCList[*]'  -- FIXED PATH
            COLUMNS (
                sc                VARCHAR2(100) PATH '$.SC',
                revision          VARCHAR2(50)  PATH '$.Revision',
                rev_date          VARCHAR2(50)  PATH '$.RevDate',
                status            VARCHAR2(50)  PATH '$.Status',
                official_revision VARCHAR2(50)  PATH '$.OfficialRevision',
                delta             VARCHAR2(50)  PATH '$.Delta'
            )
        ) jt;

        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' SC references');

    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20302,
                'Error parsing SC JSON: ' || SQLERRM);
    END parse_sc_json;

    -- Similar fixes needed for other reference types...
    -- VSM: $.getIssueVSMList[*]
    -- VDS: $.getIssueVDSList[*]
    -- EDS: $.getIssueEDSList[*]
    -- MDS: $.getIssueMDSList[*]
    -- VSK: $.getIssueVSKList[*]
    -- ESK: $.getIssueESKList[*]
    -- PIPE_ELEMENT: $.getIssuePipeElementList[*]

    -- For now, adding stub procedures for the others
    PROCEDURE parse_vsm_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    ) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('parse_vsm_json not yet implemented');
    END;

    PROCEDURE parse_vds_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    ) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('parse_vds_json not yet implemented');
    END;

    PROCEDURE parse_eds_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    ) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('parse_eds_json not yet implemented');
    END;

    PROCEDURE parse_mds_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    ) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('parse_mds_json not yet implemented');
    END;

    PROCEDURE parse_vsk_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    ) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('parse_vsk_json not yet implemented');
    END;

    PROCEDURE parse_esk_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    ) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('parse_esk_json not yet implemented');
    END;

    PROCEDURE parse_pipe_element_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    ) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('parse_pipe_element_json not yet implemented');
    END;

    PROCEDURE parse_reference_json(
        p_reference_type IN VARCHAR2,
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2
    ) IS
    BEGIN
        CASE LOWER(p_reference_type)
            WHEN 'pcs' THEN
                parse_pcs_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'sc' THEN
                parse_sc_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'vsm' THEN
                parse_vsm_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'vds' THEN
                parse_vds_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'eds' THEN
                parse_eds_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'mds' THEN
                parse_mds_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'vsk' THEN
                parse_vsk_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'esk' THEN
                parse_esk_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'pipe_element' THEN
                parse_pipe_element_json(p_raw_json_id, p_plant_id, p_issue_rev);
            ELSE
                RAISE_APPLICATION_ERROR(-20300,
                    'Unknown reference type: ' || p_reference_type);
        END CASE;
    END parse_reference_json;

END PKG_PARSE_REFERENCES;
/

-- Test the fix
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_objects
    WHERE object_name = 'PKG_PARSE_REFERENCES'
    AND object_type = 'PACKAGE BODY'
    AND status = 'VALID';
    
    IF v_count = 1 THEN
        DBMS_OUTPUT.PUT_LINE('SUCCESS: PKG_PARSE_REFERENCES fixed and compiled successfully');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ERROR: PKG_PARSE_REFERENCES compilation failed');
    END IF;
END;
/

PROMPT
PROMPT ===============================================================================
PROMPT PKG_PARSE_REFERENCES JSON paths fixed
PROMPT PCS now uses: $.getIssuePCSList[*]
PROMPT SC now uses: $.getIssueSCList[*]
PROMPT ===============================================================================