-- ===============================================================================
-- Package: PKG_UPSERT_ISSUES
-- Purpose: Merges issue data from staging into ISSUES table
-- ===============================================================================

-- Package Specification
CREATE OR REPLACE PACKAGE pkg_upsert_issues AS
    PROCEDURE upsert_issues;
    PROCEDURE cascade_delete_for_plant(p_plant_id VARCHAR2);
    FUNCTION safe_date_parse(p_date_str VARCHAR2) RETURN DATE;
    FUNCTION safe_timestamp_parse(p_timestamp_str VARCHAR2) RETURN TIMESTAMP;
END pkg_upsert_issues;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY pkg_upsert_issues AS

    -- Smart date parser that handles multiple formats
    FUNCTION safe_date_parse(p_date_str VARCHAR2) RETURN DATE IS
        v_date DATE;
    BEGIN
        IF p_date_str IS NULL OR TRIM(p_date_str) IS NULL THEN
            RETURN NULL;
        END IF;

        -- Try different date formats in order of likelihood
        BEGIN
            -- Format: DD.MM.YYYY (European - most common in this API)
            v_date := TO_DATE(p_date_str, 'DD.MM.YYYY');
            RETURN v_date;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        BEGIN
            -- Format: DD/MM/YYYY (European with slashes)
            v_date := TO_DATE(p_date_str, 'DD/MM/YYYY');
            RETURN v_date;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        BEGIN
            -- Format: DD-MM-YYYY (European with dashes)
            v_date := TO_DATE(p_date_str, 'DD-MM-YYYY');
            RETURN v_date;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        BEGIN
            -- Format: MM/DD/YYYY (American)
            v_date := TO_DATE(p_date_str, 'MM/DD/YYYY');
            RETURN v_date;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        BEGIN
            -- Format: YYYY-MM-DD (ISO)
            v_date := TO_DATE(p_date_str, 'YYYY-MM-DD');
            RETURN v_date;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        BEGIN
            -- Format: DD.MM.YY (2-digit year European)
            v_date := TO_DATE(p_date_str, 'DD.MM.YY');
            RETURN v_date;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        BEGIN
            -- Format: DD-MON-YYYY (Oracle default)
            v_date := TO_DATE(p_date_str, 'DD-MON-YYYY');
            RETURN v_date;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        -- If all formats fail, return NULL and log warning
        DBMS_OUTPUT.PUT_LINE('Warning: Could not parse date: ' || p_date_str);
        RETURN NULL;

    END safe_date_parse;

    -- Smart timestamp parser that handles multiple formats
    FUNCTION safe_timestamp_parse(p_timestamp_str VARCHAR2) RETURN TIMESTAMP IS
        v_timestamp TIMESTAMP;
    BEGIN
        IF p_timestamp_str IS NULL OR TRIM(p_timestamp_str) IS NULL THEN
            RETURN NULL;
        END IF;

        -- Try different timestamp formats
        BEGIN
            -- Format: DD.MM.YYYY HH24:MI:SS
            v_timestamp := TO_TIMESTAMP(p_timestamp_str, 'DD.MM.YYYY HH24:MI:SS');
            RETURN v_timestamp;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        BEGIN
            -- Format: DD.MM.YYYY HH24:MI
            v_timestamp := TO_TIMESTAMP(p_timestamp_str, 'DD.MM.YYYY HH24:MI');
            RETURN v_timestamp;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        BEGIN
            -- Format: YYYY-MM-DD HH24:MI:SS (ISO)
            v_timestamp := TO_TIMESTAMP(p_timestamp_str, 'YYYY-MM-DD HH24:MI:SS');
            RETURN v_timestamp;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        BEGIN
            -- Format: MM/DD/YYYY HH:MI:SS AM/PM (American 12-hour)
            v_timestamp := TO_TIMESTAMP(p_timestamp_str, 'MM/DD/YYYY HH:MI:SS AM');
            RETURN v_timestamp;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        BEGIN
            -- Format: DD-MON-YY HH24:MI:SS
            v_timestamp := TO_TIMESTAMP(p_timestamp_str, 'DD-MON-YY HH24:MI:SS');
            RETURN v_timestamp;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        -- If just a date, convert to timestamp
        BEGIN
            v_timestamp := TO_TIMESTAMP(safe_date_parse(p_timestamp_str));
            RETURN v_timestamp;
        EXCEPTION WHEN OTHERS THEN NULL; END;

        -- If all formats fail, return NULL
        RETURN NULL;

    END safe_timestamp_parse;

    PROCEDURE cascade_delete_for_plant(p_plant_id VARCHAR2) IS
    BEGIN
        -- Mark all issues for a removed plant as invalid
        UPDATE ISSUES
        SET is_valid = 'N', last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id;
    END cascade_delete_for_plant;

    PROCEDURE upsert_issues IS
    BEGIN
        -- First, mark all existing issues as invalid for plants that are being processed
        UPDATE ISSUES
        SET is_valid = 'N'
        WHERE plant_id IN (SELECT DISTINCT plant_id FROM STG_ISSUES);

        -- Merge staging data into ISSUES
        MERGE INTO ISSUES tgt
        USING (
            SELECT
                plant_id,
                issue_revision,
                status,
                safe_date_parse(rev_date) as rev_date,
                protect_status,
                general_revision,
                safe_date_parse(general_rev_date) as general_rev_date,
                pcs_revision,
                safe_date_parse(pcs_rev_date) as pcs_rev_date,
                eds_revision,
                safe_date_parse(eds_rev_date) as eds_rev_date,
                vds_revision,
                safe_date_parse(vds_rev_date) as vds_rev_date,
                vsk_revision,
                safe_date_parse(vsk_rev_date) as vsk_rev_date,
                mds_revision,
                safe_date_parse(mds_rev_date) as mds_rev_date,
                esk_revision,
                safe_date_parse(esk_rev_date) as esk_rev_date,
                sc_revision,
                safe_date_parse(sc_rev_date) as sc_rev_date,
                vsm_revision,
                safe_date_parse(vsm_rev_date) as vsm_rev_date,
                user_name,
                safe_timestamp_parse(user_entry_time) as user_entry_time,
                CASE WHEN UPPER(user_protected) IN ('TRUE', 'Y', '1') THEN 'Y' ELSE 'N' END as user_protected
            FROM STG_ISSUES
            WHERE issue_revision IS NOT NULL
        ) src
        ON (tgt.plant_id = src.plant_id AND tgt.issue_revision = src.issue_revision)
        WHEN MATCHED THEN
            UPDATE SET
                status = src.status,
                rev_date = src.rev_date,
                protect_status = src.protect_status,
                general_revision = src.general_revision,
                general_rev_date = src.general_rev_date,
                pcs_revision = src.pcs_revision,
                pcs_rev_date = src.pcs_rev_date,
                eds_revision = src.eds_revision,
                eds_rev_date = src.eds_rev_date,
                vds_revision = src.vds_revision,
                vds_rev_date = src.vds_rev_date,
                vsk_revision = src.vsk_revision,
                vsk_rev_date = src.vsk_rev_date,
                mds_revision = src.mds_revision,
                mds_rev_date = src.mds_rev_date,
                esk_revision = src.esk_revision,
                esk_rev_date = src.esk_rev_date,
                sc_revision = src.sc_revision,
                sc_rev_date = src.sc_rev_date,
                vsm_revision = src.vsm_revision,
                vsm_rev_date = src.vsm_rev_date,
                user_name = src.user_name,
                user_entry_time = src.user_entry_time,
                user_protected = src.user_protected,
                is_valid = 'Y',
                last_modified_date = SYSDATE,
                last_api_sync = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (
                plant_id, issue_revision, status, rev_date, protect_status,
                general_revision, general_rev_date, pcs_revision, pcs_rev_date,
                eds_revision, eds_rev_date, vds_revision, vds_rev_date,
                vsk_revision, vsk_rev_date, mds_revision, mds_rev_date,
                esk_revision, esk_rev_date, sc_revision, sc_rev_date,
                vsm_revision, vsm_rev_date, user_name, user_entry_time,
                user_protected, is_valid, created_date, last_modified_date, last_api_sync
            ) VALUES (
                src.plant_id, src.issue_revision, src.status, src.rev_date, src.protect_status,
                src.general_revision, src.general_rev_date, src.pcs_revision, src.pcs_rev_date,
                src.eds_revision, src.eds_rev_date, src.vds_revision, src.vds_rev_date,
                src.vsk_revision, src.vsk_rev_date, src.mds_revision, src.mds_rev_date,
                src.esk_revision, src.esk_rev_date, src.sc_revision, src.sc_rev_date,
                src.vsm_revision, src.vsm_rev_date, src.user_name, src.user_entry_time,
                src.user_protected, 'Y', SYSDATE, SYSDATE, SYSTIMESTAMP
            );

        -- Cascade delete issues for plants marked as invalid
        FOR plant_rec IN (SELECT plant_id FROM PLANTS WHERE is_valid = 'N') LOOP
            cascade_delete_for_plant(plant_rec.plant_id);
        END LOOP;

        COMMIT;
    END upsert_issues;

END pkg_upsert_issues;
/