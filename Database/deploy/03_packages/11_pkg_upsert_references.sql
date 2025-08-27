-- ===============================================================================
-- Package: PKG_UPSERT_REFERENCES
-- Purpose: MERGE staging reference data into core tables with FK validation
-- Author: TR2000 ETL Team
-- Date: 2025-08-26
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_upsert_references AS
    -- Safe date parsing helper function
    FUNCTION safe_date_parse(p_date_string IN VARCHAR2) RETURN DATE;
    
    -- Safe number parsing helper function
    FUNCTION safe_number_parse(p_number_string IN VARCHAR2) RETURN NUMBER;
    
    -- Upsert PCS references
    PROCEDURE upsert_pcs_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    );
    
    -- Upsert SC references
    PROCEDURE upsert_sc_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    );
    
    -- Upsert VSM references
    PROCEDURE upsert_vsm_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    );
    
    -- Upsert VDS references
    PROCEDURE upsert_vds_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    );
    
    -- Upsert EDS references
    PROCEDURE upsert_eds_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    );
    
    -- Upsert MDS references
    PROCEDURE upsert_mds_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    );
    
    -- Upsert VSK references
    PROCEDURE upsert_vsk_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    );
    
    -- Upsert ESK references
    PROCEDURE upsert_esk_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    );
    
    -- Upsert Pipe Element references
    PROCEDURE upsert_pipe_element_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    );
    
    -- Generic upsert that routes to appropriate specific procedure
    PROCEDURE upsert_references(
        p_reference_type IN VARCHAR2,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2
    );
    
END pkg_upsert_references;
/

CREATE OR REPLACE PACKAGE BODY pkg_upsert_references AS

    -- =========================================================================
    -- Safe date parsing helper
    -- =========================================================================
    FUNCTION safe_date_parse(p_date_string IN VARCHAR2) RETURN DATE IS
    BEGIN
        IF p_date_string IS NULL THEN
            RETURN NULL;
        END IF;
        
        -- Try different date formats
        BEGIN
            RETURN TO_DATE(p_date_string, 'YYYY-MM-DD');
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            RETURN TO_DATE(p_date_string, 'DD-MON-YYYY');
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        BEGIN
            RETURN TO_DATE(p_date_string, 'MM/DD/YYYY');
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        
        -- If all formats fail, return NULL
        RETURN NULL;
    END safe_date_parse;
    
    -- =========================================================================
    -- Safe number parsing helper
    -- =========================================================================
    FUNCTION safe_number_parse(p_number_string IN VARCHAR2) RETURN NUMBER IS
    BEGIN
        IF p_number_string IS NULL THEN
            RETURN NULL;
        END IF;
        
        RETURN TO_NUMBER(p_number_string);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END safe_number_parse;

    -- =========================================================================
    -- Upsert PCS references
    -- =========================================================================
    PROCEDURE upsert_pcs_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
        v_soft_delete_count NUMBER := 0;
    BEGIN
        -- First, soft delete existing references not in staging
        UPDATE PCS_REFERENCES
        SET is_valid = 'N',
            last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND is_valid = 'Y'
          AND pcs_name NOT IN (
              SELECT pcs FROM STG_PCS_REFERENCES
              WHERE plant_id = p_plant_id
                AND issue_revision = p_issue_rev
          );
        
        v_soft_delete_count := SQL%ROWCOUNT;
        
        -- Now merge staging data into core table
        MERGE INTO PCS_REFERENCES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                pcs AS pcs_name,
                revision,
                safe_date_parse(rev_date) AS rev_date,
                status,
                official_revision,
                revision_suffix,
                rating_class,
                material_group,
                historical_pcs,
                delta
            FROM STG_PCS_REFERENCES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.pcs_name = src.pcs_name)
        WHEN MATCHED THEN
            UPDATE SET
                revision = src.revision,
                rev_date = src.rev_date,
                status = src.status,
                official_revision = src.official_revision,
                revision_suffix = src.revision_suffix,
                rating_class = src.rating_class,
                material_group = src.material_group,
                historical_pcs = src.historical_pcs,
                delta = src.delta,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                reference_guid, plant_id, issue_revision, pcs_name,
                revision, rev_date, status, official_revision,
                revision_suffix, rating_class, material_group,
                historical_pcs, delta, is_valid, created_date,
                last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.pcs_name,
                src.revision, src.rev_date, src.status, src.official_revision,
                src.revision_suffix, src.rating_class, src.material_group,
                src.historical_pcs, src.delta, 'Y', SYSDATE,
                SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('PCS References - Merged: ' || v_merge_count || ', Soft deleted: ' || v_soft_delete_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20401, 
                'Error upserting PCS references: ' || SQLERRM);
    END upsert_pcs_references;

    -- =========================================================================
    -- Upsert SC references
    -- =========================================================================
    PROCEDURE upsert_sc_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
        v_soft_delete_count NUMBER := 0;
    BEGIN
        -- Soft delete existing references not in staging
        UPDATE SC_REFERENCES
        SET is_valid = 'N',
            last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND is_valid = 'Y'
          AND sc_name NOT IN (
              SELECT sc FROM STG_SC_REFERENCES
              WHERE plant_id = p_plant_id
                AND issue_revision = p_issue_rev
          );
        
        v_soft_delete_count := SQL%ROWCOUNT;
        
        -- Merge staging data into core table
        MERGE INTO SC_REFERENCES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                sc AS sc_name,
                revision,
                safe_date_parse(rev_date) AS rev_date,
                status,
                official_revision,
                delta
            FROM STG_SC_REFERENCES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.sc_name = src.sc_name)
        WHEN MATCHED THEN
            UPDATE SET
                revision = src.revision,
                rev_date = src.rev_date,
                status = src.status,
                official_revision = src.official_revision,
                delta = src.delta,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                reference_guid, plant_id, issue_revision, sc_name,
                revision, rev_date, status, official_revision,
                delta, is_valid, created_date,
                last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.sc_name,
                src.revision, src.rev_date, src.status, src.official_revision,
                src.delta, 'Y', SYSDATE,
                SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('SC References - Merged: ' || v_merge_count || ', Soft deleted: ' || v_soft_delete_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20402, 
                'Error upserting SC references: ' || SQLERRM);
    END upsert_sc_references;

    -- =========================================================================
    -- Upsert VSM references
    -- =========================================================================
    PROCEDURE upsert_vsm_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
        v_soft_delete_count NUMBER := 0;
    BEGIN
        UPDATE VSM_REFERENCES
        SET is_valid = 'N',
            last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND is_valid = 'Y'
          AND vsm_name NOT IN (
              SELECT vsm FROM STG_VSM_REFERENCES
              WHERE plant_id = p_plant_id
                AND issue_revision = p_issue_rev
          );
        
        v_soft_delete_count := SQL%ROWCOUNT;
        
        MERGE INTO VSM_REFERENCES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                vsm AS vsm_name,
                revision,
                safe_date_parse(rev_date) AS rev_date,
                status,
                official_revision,
                delta
            FROM STG_VSM_REFERENCES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.vsm_name = src.vsm_name)
        WHEN MATCHED THEN
            UPDATE SET
                revision = src.revision,
                rev_date = src.rev_date,
                status = src.status,
                official_revision = src.official_revision,
                delta = src.delta,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                reference_guid, plant_id, issue_revision, vsm_name,
                revision, rev_date, status, official_revision,
                delta, is_valid, created_date,
                last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.vsm_name,
                src.revision, src.rev_date, src.status, src.official_revision,
                src.delta, 'Y', SYSDATE,
                SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('VSM References - Merged: ' || v_merge_count || ', Soft deleted: ' || v_soft_delete_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20403, 
                'Error upserting VSM references: ' || SQLERRM);
    END upsert_vsm_references;

    -- =========================================================================
    -- Upsert VDS references
    -- =========================================================================
    PROCEDURE upsert_vds_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
        v_soft_delete_count NUMBER := 0;
    BEGIN
        UPDATE VDS_REFERENCES
        SET is_valid = 'N',
            last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND is_valid = 'Y'
          AND vds_name NOT IN (
              SELECT vds FROM STG_VDS_REFERENCES
              WHERE plant_id = p_plant_id
                AND issue_revision = p_issue_rev
          );
        
        v_soft_delete_count := SQL%ROWCOUNT;
        
        MERGE INTO VDS_REFERENCES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                vds AS vds_name,
                revision,
                safe_date_parse(rev_date) AS rev_date,
                status,
                official_revision,
                delta
            FROM STG_VDS_REFERENCES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.vds_name = src.vds_name)
        WHEN MATCHED THEN
            UPDATE SET
                revision = src.revision,
                rev_date = src.rev_date,
                status = src.status,
                official_revision = src.official_revision,
                delta = src.delta,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                reference_guid, plant_id, issue_revision, vds_name,
                revision, rev_date, status, official_revision,
                delta, is_valid, created_date,
                last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.vds_name,
                src.revision, src.rev_date, src.status, src.official_revision,
                src.delta, 'Y', SYSDATE,
                SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('VDS References - Merged: ' || v_merge_count || ', Soft deleted: ' || v_soft_delete_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20404, 
                'Error upserting VDS references: ' || SQLERRM);
    END upsert_vds_references;

    -- =========================================================================
    -- Upsert EDS references
    -- =========================================================================
    PROCEDURE upsert_eds_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
        v_soft_delete_count NUMBER := 0;
    BEGIN
        UPDATE EDS_REFERENCES
        SET is_valid = 'N',
            last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND is_valid = 'Y'
          AND eds_name NOT IN (
              SELECT eds FROM STG_EDS_REFERENCES
              WHERE plant_id = p_plant_id
                AND issue_revision = p_issue_rev
          );
        
        v_soft_delete_count := SQL%ROWCOUNT;
        
        MERGE INTO EDS_REFERENCES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                eds AS eds_name,
                revision,
                safe_date_parse(rev_date) AS rev_date,
                status,
                official_revision,
                delta
            FROM STG_EDS_REFERENCES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.eds_name = src.eds_name)
        WHEN MATCHED THEN
            UPDATE SET
                revision = src.revision,
                rev_date = src.rev_date,
                status = src.status,
                official_revision = src.official_revision,
                delta = src.delta,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                reference_guid, plant_id, issue_revision, eds_name,
                revision, rev_date, status, official_revision,
                delta, is_valid, created_date,
                last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.eds_name,
                src.revision, src.rev_date, src.status, src.official_revision,
                src.delta, 'Y', SYSDATE,
                SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('EDS References - Merged: ' || v_merge_count || ', Soft deleted: ' || v_soft_delete_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20405, 
                'Error upserting EDS references: ' || SQLERRM);
    END upsert_eds_references;

    -- =========================================================================
    -- Upsert MDS references (includes area field)
    -- =========================================================================
    PROCEDURE upsert_mds_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
        v_soft_delete_count NUMBER := 0;
    BEGIN
        UPDATE MDS_REFERENCES
        SET is_valid = 'N',
            last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND is_valid = 'Y'
          AND mds_name NOT IN (
              SELECT mds FROM STG_MDS_REFERENCES
              WHERE plant_id = p_plant_id
                AND issue_revision = p_issue_rev
          );
        
        v_soft_delete_count := SQL%ROWCOUNT;
        
        MERGE INTO MDS_REFERENCES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                mds AS mds_name,
                revision,
                area,
                safe_date_parse(rev_date) AS rev_date,
                status,
                official_revision,
                delta
            FROM STG_MDS_REFERENCES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.mds_name = src.mds_name)
        WHEN MATCHED THEN
            UPDATE SET
                revision = src.revision,
                area = src.area,
                rev_date = src.rev_date,
                status = src.status,
                official_revision = src.official_revision,
                delta = src.delta,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                reference_guid, plant_id, issue_revision, mds_name,
                revision, area, rev_date, status, official_revision,
                delta, is_valid, created_date,
                last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.mds_name,
                src.revision, src.area, src.rev_date, src.status, src.official_revision,
                src.delta, 'Y', SYSDATE,
                SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('MDS References - Merged: ' || v_merge_count || ', Soft deleted: ' || v_soft_delete_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20406, 
                'Error upserting MDS references: ' || SQLERRM);
    END upsert_mds_references;

    -- =========================================================================
    -- Upsert VSK references
    -- =========================================================================
    PROCEDURE upsert_vsk_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
        v_soft_delete_count NUMBER := 0;
    BEGIN
        UPDATE VSK_REFERENCES
        SET is_valid = 'N',
            last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND is_valid = 'Y'
          AND vsk_name NOT IN (
              SELECT vsk FROM STG_VSK_REFERENCES
              WHERE plant_id = p_plant_id
                AND issue_revision = p_issue_rev
          );
        
        v_soft_delete_count := SQL%ROWCOUNT;
        
        MERGE INTO VSK_REFERENCES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                vsk AS vsk_name,
                revision,
                safe_date_parse(rev_date) AS rev_date,
                status,
                official_revision,
                delta
            FROM STG_VSK_REFERENCES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.vsk_name = src.vsk_name)
        WHEN MATCHED THEN
            UPDATE SET
                revision = src.revision,
                rev_date = src.rev_date,
                status = src.status,
                official_revision = src.official_revision,
                delta = src.delta,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                reference_guid, plant_id, issue_revision, vsk_name,
                revision, rev_date, status, official_revision,
                delta, is_valid, created_date,
                last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.vsk_name,
                src.revision, src.rev_date, src.status, src.official_revision,
                src.delta, 'Y', SYSDATE,
                SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('VSK References - Merged: ' || v_merge_count || ', Soft deleted: ' || v_soft_delete_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20407, 
                'Error upserting VSK references: ' || SQLERRM);
    END upsert_vsk_references;

    -- =========================================================================
    -- Upsert ESK references
    -- =========================================================================
    PROCEDURE upsert_esk_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
        v_soft_delete_count NUMBER := 0;
    BEGIN
        UPDATE ESK_REFERENCES
        SET is_valid = 'N',
            last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND is_valid = 'Y'
          AND esk_name NOT IN (
              SELECT esk FROM STG_ESK_REFERENCES
              WHERE plant_id = p_plant_id
                AND issue_revision = p_issue_rev
          );
        
        v_soft_delete_count := SQL%ROWCOUNT;
        
        MERGE INTO ESK_REFERENCES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                esk AS esk_name,
                revision,
                safe_date_parse(rev_date) AS rev_date,
                status,
                official_revision,
                delta
            FROM STG_ESK_REFERENCES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.esk_name = src.esk_name)
        WHEN MATCHED THEN
            UPDATE SET
                revision = src.revision,
                rev_date = src.rev_date,
                status = src.status,
                official_revision = src.official_revision,
                delta = src.delta,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                reference_guid, plant_id, issue_revision, esk_name,
                revision, rev_date, status, official_revision,
                delta, is_valid, created_date,
                last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.esk_name,
                src.revision, src.rev_date, src.status, src.official_revision,
                src.delta, 'Y', SYSDATE,
                SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('ESK References - Merged: ' || v_merge_count || ', Soft deleted: ' || v_soft_delete_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20408, 
                'Error upserting ESK references: ' || SQLERRM);
    END upsert_esk_references;

    -- =========================================================================
    -- Upsert Pipe Element references
    -- =========================================================================
    PROCEDURE upsert_pipe_element_references(
        p_plant_id  IN VARCHAR2,
        p_issue_rev IN VARCHAR2
    ) IS
        v_merge_count NUMBER := 0;
        v_soft_delete_count NUMBER := 0;
    BEGIN
        UPDATE PIPE_ELEMENT_REFERENCES
        SET is_valid = 'N',
            last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_rev
          AND is_valid = 'Y'
          AND (mds, element_name) NOT IN (
              SELECT mds, name FROM STG_PIPE_ELEMENT_REFERENCES
              WHERE plant_id = p_plant_id
                AND issue_revision = p_issue_rev
          );
        
        v_soft_delete_count := SQL%ROWCOUNT;
        
        MERGE INTO PIPE_ELEMENT_REFERENCES tgt
        USING (
            SELECT 
                plant_id,
                issue_revision,
                mds,
                name AS element_name,
                revision,
                safe_date_parse(rev_date) AS rev_date,
                status,
                official_revision,
                delta
            FROM STG_PIPE_ELEMENT_REFERENCES
            WHERE plant_id = p_plant_id
              AND issue_revision = p_issue_rev
              AND name IS NOT NULL
        ) src
        ON (tgt.plant_id = src.plant_id 
            AND tgt.issue_revision = src.issue_revision
            AND tgt.mds = src.mds
            AND tgt.element_name = src.element_name)
        WHEN MATCHED THEN
            UPDATE SET
                revision = src.revision,
                rev_date = src.rev_date,
                status = src.status,
                official_revision = src.official_revision,
                delta = src.delta,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                reference_guid, plant_id, issue_revision, mds, element_name,
                revision, rev_date, status, official_revision, delta,
                is_valid, created_date, last_modified_date, last_api_sync
            )
            VALUES (
                SYS_GUID(), src.plant_id, src.issue_revision, src.mds, src.element_name,
                src.revision, src.rev_date, src.status, src.official_revision, src.delta,
                'Y', SYSDATE, SYSDATE, SYSTIMESTAMP
            );
        
        v_merge_count := SQL%ROWCOUNT;
        DBMS_OUTPUT.PUT_LINE('Pipe Element References - Merged: ' || v_merge_count || ', Soft deleted: ' || v_soft_delete_count);
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20409, 
                'Error upserting Pipe Element references: ' || SQLERRM);
    END upsert_pipe_element_references;

    -- =========================================================================
    -- Generic upsert that routes to appropriate specific procedure
    -- =========================================================================
    PROCEDURE upsert_references(
        p_reference_type IN VARCHAR2,
        p_plant_id       IN VARCHAR2,
        p_issue_rev      IN VARCHAR2
    ) IS
    BEGIN
        CASE UPPER(p_reference_type)
            WHEN 'PCS' THEN
                upsert_pcs_references(p_plant_id, p_issue_rev);
            WHEN 'SC' THEN
                upsert_sc_references(p_plant_id, p_issue_rev);
            WHEN 'VSM' THEN
                upsert_vsm_references(p_plant_id, p_issue_rev);
            WHEN 'VDS' THEN
                upsert_vds_references(p_plant_id, p_issue_rev);
            WHEN 'EDS' THEN
                upsert_eds_references(p_plant_id, p_issue_rev);
            WHEN 'MDS' THEN
                upsert_mds_references(p_plant_id, p_issue_rev);
            WHEN 'VSK' THEN
                upsert_vsk_references(p_plant_id, p_issue_rev);
            WHEN 'ESK' THEN
                upsert_esk_references(p_plant_id, p_issue_rev);
            WHEN 'PIPE_ELEMENT' THEN
                upsert_pipe_element_references(p_plant_id, p_issue_rev);
            ELSE
                RAISE_APPLICATION_ERROR(-20410,
                    'Unknown reference type: ' || p_reference_type);
        END CASE;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE_APPLICATION_ERROR(-20411,
                'Error in upsert_references for type ' || p_reference_type || ': ' || SQLERRM);
    END upsert_references;

END pkg_upsert_references;
/

SHOW ERRORS

PROMPT Package PKG_UPSERT_REFERENCES created successfully.