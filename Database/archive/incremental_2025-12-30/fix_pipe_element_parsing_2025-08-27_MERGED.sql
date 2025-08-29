-- ===============================================================================
-- Fix PIPE_ELEMENT JSON Parsing
-- Date: 2025-08-27  
-- Issue: JSON has ElementID but parse was looking for Name field
-- ===============================================================================

-- Fix the parse procedure to use ElementID and convert to string
CREATE OR REPLACE PACKAGE BODY pkg_parse_references AS
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
        INSERT INTO STG_PCS_REFERENCES (
            plant_id, issue_revision, pcs, revision, rev_date,
            status, official_revision, revision_suffix, rating_class,
            material_group, historical_pcs, delta
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
            v_json_content, '$.getIssuePCSList[*]'
            COLUMNS (
                pcs                VARCHAR2(100) PATH '$.PCS',
                revision           VARCHAR2(50)  PATH '$.Revision',
                rev_date           VARCHAR2(50)  PATH '$.RevDate',
                status             VARCHAR2(50)  PATH '$.Status',
                official_revision  VARCHAR2(50)  PATH '$.OfficialRevision',
                revision_suffix    VARCHAR2(50)  PATH '$.RevisionSuffix',
                rating_class       VARCHAR2(100) PATH '$.RatingClass',
                material_group     VARCHAR2(100) PATH '$.MaterialGroup',
                historical_pcs     VARCHAR2(100) PATH '$.HistoricalPCS',
                delta              VARCHAR2(50)  PATH '$.Delta'
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
            v_json_content, '$.getIssueSCList[*]'
            COLUMNS (
                sc                 VARCHAR2(100) PATH '$.SC',
                revision           VARCHAR2(50)  PATH '$.Revision',
                rev_date           VARCHAR2(50)  PATH '$.RevDate',
                status             VARCHAR2(50)  PATH '$.Status',
                official_revision  VARCHAR2(50)  PATH '$.OfficialRevision',
                delta              VARCHAR2(50)  PATH '$.Delta'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' SC references');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20302, 
                'Error parsing SC JSON: ' || SQLERRM);
    END parse_sc_json;

    -- =========================================================================
    -- Parse VSM references JSON
    -- =========================================================================
    PROCEDURE parse_vsm_json(
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
        
        DELETE FROM STG_VSM_REFERENCES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev;
        
        INSERT INTO STG_VSM_REFERENCES (
            plant_id, issue_revision, vsm, revision, rev_date,
            status, official_revision, delta
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            jt.vsm,
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.official_revision,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$.getIssueVSMList[*]'
            COLUMNS (
                vsm                VARCHAR2(100) PATH '$.VSM',
                revision           VARCHAR2(50)  PATH '$.Revision',
                rev_date           VARCHAR2(50)  PATH '$.RevDate',
                status             VARCHAR2(50)  PATH '$.Status',
                official_revision  VARCHAR2(50)  PATH '$.OfficialRevision',
                delta              VARCHAR2(50)  PATH '$.Delta'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' VSM references');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20303, 
                'Error parsing VSM JSON: ' || SQLERRM);
    END parse_vsm_json;

    -- =========================================================================
    -- Parse VDS references JSON
    -- =========================================================================
    PROCEDURE parse_vds_json(
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
        
        DELETE FROM STG_VDS_REFERENCES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev;
        
        INSERT INTO STG_VDS_REFERENCES (
            plant_id, issue_revision, vds, revision, rev_date,
            status, official_revision, rating_class, material_group,
            bolt_material, gasket_type, delta
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            jt.vds,
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.official_revision,
            jt.rating_class,
            jt.material_group,
            jt.bolt_material,
            jt.gasket_type,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$.getIssueVDSList[*]'
            COLUMNS (
                vds                VARCHAR2(100) PATH '$.VDS',
                revision           VARCHAR2(50)  PATH '$.Revision',
                rev_date           VARCHAR2(50)  PATH '$.RevDate',
                status             VARCHAR2(50)  PATH '$.Status',
                official_revision  VARCHAR2(50)  PATH '$.OfficialRevision',
                rating_class       VARCHAR2(100) PATH '$.RatingClass',
                material_group     VARCHAR2(100) PATH '$.MaterialGroup',
                bolt_material      VARCHAR2(100) PATH '$.BoltMaterial',
                gasket_type        VARCHAR2(100) PATH '$.GasketType',
                delta              VARCHAR2(50)  PATH '$.Delta'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' VDS references');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20304, 
                'Error parsing VDS JSON: ' || SQLERRM);
    END parse_vds_json;

    -- =========================================================================
    -- Parse EDS references JSON
    -- =========================================================================
    PROCEDURE parse_eds_json(
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
        
        DELETE FROM STG_EDS_REFERENCES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev;
        
        INSERT INTO STG_EDS_REFERENCES (
            plant_id, issue_revision, eds, revision, rev_date,
            status, official_revision, delta
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            jt.eds,
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.official_revision,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$.getIssueEDSList[*]'
            COLUMNS (
                eds                VARCHAR2(100) PATH '$.EDS',
                revision           VARCHAR2(50)  PATH '$.Revision',
                rev_date           VARCHAR2(50)  PATH '$.RevDate',
                status             VARCHAR2(50)  PATH '$.Status',
                official_revision  VARCHAR2(50)  PATH '$.OfficialRevision',
                delta              VARCHAR2(50)  PATH '$.Delta'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' EDS references');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20305, 
                'Error parsing EDS JSON: ' || SQLERRM);
    END parse_eds_json;

    -- =========================================================================
    -- Parse MDS references JSON
    -- =========================================================================
    PROCEDURE parse_mds_json(
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
        
        DELETE FROM STG_MDS_REFERENCES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev;
        
        INSERT INTO STG_MDS_REFERENCES (
            plant_id, issue_revision, mds, area, revision, rev_date,
            status, official_revision, rating_class, material_group, delta
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            jt.mds,
            jt.area,
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.official_revision,
            jt.rating_class,
            jt.material_group,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$.getIssueMDSList[*]'
            COLUMNS (
                mds                VARCHAR2(100) PATH '$.MDS',
                area               VARCHAR2(100) PATH '$.Area',
                revision           VARCHAR2(50)  PATH '$.Revision',
                rev_date           VARCHAR2(50)  PATH '$.RevDate',
                status             VARCHAR2(50)  PATH '$.Status',
                official_revision  VARCHAR2(50)  PATH '$.OfficialRevision',
                rating_class       VARCHAR2(100) PATH '$.RatingClass',
                material_group     VARCHAR2(100) PATH '$.MaterialGroup',
                delta              VARCHAR2(50)  PATH '$.Delta'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' MDS references');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20306, 
                'Error parsing MDS JSON: ' || SQLERRM);
    END parse_mds_json;

    -- =========================================================================
    -- Parse VSK references JSON
    -- =========================================================================
    PROCEDURE parse_vsk_json(
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
        
        DELETE FROM STG_VSK_REFERENCES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev;
        
        INSERT INTO STG_VSK_REFERENCES (
            plant_id, issue_revision, vsk, revision, rev_date,
            status, official_revision, delta
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            jt.vsk,
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.official_revision,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$.getIssueVSKList[*]'
            COLUMNS (
                vsk                VARCHAR2(100) PATH '$.VSK',
                revision           VARCHAR2(50)  PATH '$.Revision',
                rev_date           VARCHAR2(50)  PATH '$.RevDate',
                status             VARCHAR2(50)  PATH '$.Status',
                official_revision  VARCHAR2(50)  PATH '$.OfficialRevision',
                delta              VARCHAR2(50)  PATH '$.Delta'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' VSK references');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20307, 
                'Error parsing VSK JSON: ' || SQLERRM);
    END parse_vsk_json;

    -- =========================================================================
    -- Parse ESK references JSON
    -- =========================================================================
    PROCEDURE parse_esk_json(
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
        
        DELETE FROM STG_ESK_REFERENCES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev;
        
        INSERT INTO STG_ESK_REFERENCES (
            plant_id, issue_revision, esk, revision, rev_date,
            status, official_revision, delta
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            jt.esk,
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.official_revision,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$.getIssueESKList[*]'
            COLUMNS (
                esk                VARCHAR2(100) PATH '$.ESK',
                revision           VARCHAR2(50)  PATH '$.Revision',
                rev_date           VARCHAR2(50)  PATH '$.RevDate',
                status             VARCHAR2(50)  PATH '$.Status',
                official_revision  VARCHAR2(50)  PATH '$.OfficialRevision',
                delta              VARCHAR2(50)  PATH '$.Delta'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' ESK references');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20308, 
                'Error parsing ESK JSON: ' || SQLERRM);
    END parse_esk_json;

    -- =========================================================================
    -- Parse PIPE ELEMENT references JSON
    -- FIXED: Changed from $.Name to $.ElementID and convert to string
    -- =========================================================================
    PROCEDURE parse_pipe_element_json(
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
        
        DELETE FROM STG_PIPE_ELEMENT_REFERENCES
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev;
        
        INSERT INTO STG_PIPE_ELEMENT_REFERENCES (
            plant_id, issue_revision, mds, name,
            revision, rev_date, status, official_revision, delta
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            jt.mds,
            TO_CHAR(jt.element_id), -- Convert ElementID number to string
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.status, -- Using Status as OfficialRevision since field not in JSON
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$.getIssuePipeElementList[*]'
            COLUMNS (
                element_id         NUMBER        PATH '$.ElementID',
                mds                VARCHAR2(100) PATH '$.MDS',
                revision           VARCHAR2(50)  PATH '$.Revision',
                rev_date           VARCHAR2(50)  PATH '$.RevDate',
                status             VARCHAR2(50)  PATH '$.Status',
                delta              VARCHAR2(50)  PATH '$.Delta'
            )
        ) jt;
        
        v_record_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Parsed ' || v_record_count || ' Pipe Element references');
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20309, 
                'Error parsing Pipe Element JSON: ' || SQLERRM);
    END parse_pipe_element_json;

    -- =========================================================================
    -- Generic parser routing procedure
    -- =========================================================================
    PROCEDURE parse_reference_json(
        p_reference_type IN VARCHAR2,
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2
    ) IS
    BEGIN
        CASE UPPER(p_reference_type)
            WHEN 'PCS' THEN
                parse_pcs_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'SC' THEN
                parse_sc_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'VSM' THEN
                parse_vsm_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'VDS' THEN
                parse_vds_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'EDS' THEN
                parse_eds_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'MDS' THEN
                parse_mds_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'VSK' THEN
                parse_vsk_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'ESK' THEN
                parse_esk_json(p_raw_json_id, p_plant_id, p_issue_rev);
            WHEN 'PIPE_ELEMENT' THEN
                parse_pipe_element_json(p_raw_json_id, p_plant_id, p_issue_rev);
            ELSE
                RAISE_APPLICATION_ERROR(-20310,
                    'Unknown reference type: ' || p_reference_type);
        END CASE;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20311,
                'Error in parse_reference_json for type ' || p_reference_type || ': ' || SQLERRM);
    END parse_reference_json;
END pkg_parse_references;
/

SHOW ERRORS

-- Test the fix
PROMPT Testing PIPE_ELEMENT parsing fix...
SET SERVEROUTPUT ON
DECLARE
    v_count NUMBER;
BEGIN
    -- Clear staging
    DELETE FROM STG_PIPE_ELEMENT_REFERENCES;
    
    -- Re-parse existing JSON
    FOR rec IN (SELECT raw_json_id, plant_id, issue_rev
                FROM RAW_JSON 
                WHERE endpoint_key = 'pipe_element_references'
                AND ROWNUM = 1) LOOP
        PKG_PARSE_REFERENCES.parse_pipe_element_json(rec.raw_json_id, rec.plant_id, rec.issue_rev);
    END LOOP;
    
    -- Check if name is now populated
    SELECT COUNT(*), COUNT(name) 
    INTO v_count, v_count
    FROM STG_PIPE_ELEMENT_REFERENCES;
    
    DBMS_OUTPUT.PUT_LINE('Total staging records: ' || v_count);
    
    -- Show sample
    FOR rec IN (SELECT mds, name, revision, status
                FROM STG_PIPE_ELEMENT_REFERENCES
                WHERE ROWNUM <= 3) LOOP
        DBMS_OUTPUT.PUT_LINE('MDS: ' || rec.mds || ', Name: ' || rec.name || 
                           ', Rev: ' || rec.revision || ', Status: ' || rec.status);
    END LOOP;
END;
/

PROMPT Fix applied. Now run upsert to load into final table.