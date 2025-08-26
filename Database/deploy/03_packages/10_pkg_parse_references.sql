-- ===============================================================================
-- Package: PKG_PARSE_REFERENCES
-- Purpose: Parse JSON responses from issue reference endpoints into staging tables
-- Author: TR2000 ETL Team
-- Date: 2025-08-26
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_parse_references AS
    -- Parse PCS references JSON
    PROCEDURE parse_pcs_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    );
    
    -- Parse SC references JSON
    PROCEDURE parse_sc_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    );
    
    -- Parse VSM references JSON
    PROCEDURE parse_vsm_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    );
    
    -- Parse VDS references JSON
    PROCEDURE parse_vds_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    );
    
    -- Parse EDS references JSON
    PROCEDURE parse_eds_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    );
    
    -- Parse MDS references JSON (includes area field)
    PROCEDURE parse_mds_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    );
    
    -- Parse VSK references JSON
    PROCEDURE parse_vsk_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    );
    
    -- Parse ESK references JSON
    PROCEDURE parse_esk_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    );
    
    -- Parse Pipe Element references JSON (many fields)
    PROCEDURE parse_pipe_element_json(
        p_raw_json_id IN NUMBER,
        p_plant_id    IN VARCHAR2,
        p_issue_rev   IN VARCHAR2
    );
    
    -- Generic parser that routes to appropriate specific parser
    PROCEDURE parse_reference_json(
        p_reference_type IN VARCHAR2,
        p_raw_json_id    IN NUMBER,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2
    );
    
END pkg_parse_references;
/

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
            v_json_content, '$[*]'
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
            v_json_content, '$[*]'
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
            v_json_content, '$[*]'
            COLUMNS (
                vsm               VARCHAR2(100) PATH '$.VSM',
                revision          VARCHAR2(50)  PATH '$.Revision',
                rev_date          VARCHAR2(50)  PATH '$.RevDate',
                status            VARCHAR2(50)  PATH '$.Status',
                official_revision VARCHAR2(50)  PATH '$.OfficialRevision',
                delta             VARCHAR2(50)  PATH '$.Delta'
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
            status, official_revision, delta
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            jt.vds,
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.official_revision,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$[*]'
            COLUMNS (
                vds               VARCHAR2(100) PATH '$.VDS',
                revision          VARCHAR2(50)  PATH '$.Revision',
                rev_date          VARCHAR2(50)  PATH '$.RevDate',
                status            VARCHAR2(50)  PATH '$.Status',
                official_revision VARCHAR2(50)  PATH '$.OfficialRevision',
                delta             VARCHAR2(50)  PATH '$.Delta'
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
            v_json_content, '$[*]'
            COLUMNS (
                eds               VARCHAR2(100) PATH '$.EDS',
                revision          VARCHAR2(50)  PATH '$.Revision',
                rev_date          VARCHAR2(50)  PATH '$.RevDate',
                status            VARCHAR2(50)  PATH '$.Status',
                official_revision VARCHAR2(50)  PATH '$.OfficialRevision',
                delta             VARCHAR2(50)  PATH '$.Delta'
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
    -- Parse MDS references JSON (includes area field)
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
            plant_id, issue_revision, mds, revision, area,
            rev_date, status, official_revision, delta
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            jt.mds,
            jt.revision,
            jt.area,
            jt.rev_date,
            jt.status,
            jt.official_revision,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$[*]'
            COLUMNS (
                mds               VARCHAR2(100) PATH '$.MDS',
                revision          VARCHAR2(50)  PATH '$.Revision',
                area              VARCHAR2(100) PATH '$.Area',
                rev_date          VARCHAR2(50)  PATH '$.RevDate',
                status            VARCHAR2(50)  PATH '$.Status',
                official_revision VARCHAR2(50)  PATH '$.OfficialRevision',
                delta             VARCHAR2(50)  PATH '$.Delta'
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
            v_json_content, '$[*]'
            COLUMNS (
                vsk               VARCHAR2(100) PATH '$.VSK',
                revision          VARCHAR2(50)  PATH '$.Revision',
                rev_date          VARCHAR2(50)  PATH '$.RevDate',
                status            VARCHAR2(50)  PATH '$.Status',
                official_revision VARCHAR2(50)  PATH '$.OfficialRevision',
                delta             VARCHAR2(50)  PATH '$.Delta'
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
            v_json_content, '$[*]'
            COLUMNS (
                esk               VARCHAR2(100) PATH '$.ESK',
                revision          VARCHAR2(50)  PATH '$.Revision',
                rev_date          VARCHAR2(50)  PATH '$.RevDate',
                status            VARCHAR2(50)  PATH '$.Status',
                official_revision VARCHAR2(50)  PATH '$.OfficialRevision',
                delta             VARCHAR2(50)  PATH '$.Delta'
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
    -- Parse Pipe Element references JSON (many fields)
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
            plant_id, issue_revision, element_group, dimension_standard,
            product_form, material_grade, mds, mds_revision, area,
            element_id, revision, rev_date, status, delta
        )
        SELECT 
            p_plant_id,
            p_issue_rev,
            jt.element_group,
            jt.dimension_standard,
            jt.product_form,
            jt.material_grade,
            jt.mds,
            jt.mds_revision,
            jt.area,
            jt.element_id,
            jt.revision,
            jt.rev_date,
            jt.status,
            jt.delta
        FROM JSON_TABLE(
            v_json_content, '$[*]'
            COLUMNS (
                element_group      VARCHAR2(100) PATH '$.ElementGroup',
                dimension_standard VARCHAR2(100) PATH '$.DimensionStandard',
                product_form       VARCHAR2(100) PATH '$.ProductForm',
                material_grade     VARCHAR2(100) PATH '$.MaterialGrade',
                mds                VARCHAR2(100) PATH '$.MDS',
                mds_revision       VARCHAR2(50)  PATH '$.MDSRevision',
                area               VARCHAR2(100) PATH '$.Area',
                element_id         VARCHAR2(50)  PATH '$.ElementID',
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
    -- Generic parser that routes to appropriate specific parser
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

PROMPT Package PKG_PARSE_REFERENCES created successfully.