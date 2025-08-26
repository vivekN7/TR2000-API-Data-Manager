-- ===============================================================================
-- Package: PKG_PARSE_ISSUES
-- Purpose: Parses issue JSON data from RAW_JSON into STG_ISSUES staging table
-- ===============================================================================

-- Package Specification
CREATE OR REPLACE PACKAGE pkg_parse_issues AS
    PROCEDURE parse_issues_json(p_raw_json_id NUMBER, p_plant_id VARCHAR2);
    PROCEDURE clear_staging_for_plant(p_plant_id VARCHAR2);
END pkg_parse_issues;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY pkg_parse_issues AS

    PROCEDURE clear_staging_for_plant(p_plant_id VARCHAR2) IS
    BEGIN
        DELETE FROM STG_ISSUES WHERE plant_id = p_plant_id;
    END clear_staging_for_plant;

    PROCEDURE parse_issues_json(p_raw_json_id NUMBER, p_plant_id VARCHAR2) IS
        v_sql CLOB;
        v_row_count NUMBER;
    BEGIN
        -- Clear staging for this plant first
        clear_staging_for_plant(p_plant_id);

        -- Build dynamic SQL with CORRECT JSON path ($.getIssueList[*])
        v_sql := 'INSERT INTO STG_ISSUES (
            raw_json_id,
            plant_id,
            issue_revision,
            status,
            rev_date,
            protect_status,
            general_revision,
            general_rev_date,
            pcs_revision,
            pcs_rev_date,
            eds_revision,
            eds_rev_date,
            vds_revision,
            vds_rev_date,
            vsk_revision,
            vsk_rev_date,
            mds_revision,
            mds_rev_date,
            esk_revision,
            esk_rev_date,
            sc_revision,
            sc_rev_date,
            vsm_revision,
            vsm_rev_date,
            user_name,
            user_entry_time,
            user_protected
        )
        SELECT
            ' || p_raw_json_id || ',
            ''' || p_plant_id || ''',
            IssueRevision,
            Status,
            RevDate,
            ProtectStatus,
            GeneralRevision,
            GeneralRevDate,
            PCSRevision,
            PCSRevDate,
            EDSRevision,
            EDSRevDate,
            VDSRevision,
            VDSRevDate,
            VSKRevision,
            VSKRevDate,
            MDSRevision,
            MDSRevDate,
            ESKRevision,
            ESKRevDate,
            SCRevision,
            SCRevDate,
            VSMRevision,
            VSMRevDate,
            UserName,
            UserEntryTime,
            UserProtected
        FROM RAW_JSON r,
        JSON_TABLE(r.response_json, ''$.getIssueList[*]''
            COLUMNS (
                IssueRevision VARCHAR2(50) PATH ''$.IssueRevision'',
                Status VARCHAR2(50) PATH ''$.Status'',
                RevDate VARCHAR2(50) PATH ''$.RevDate'',
                ProtectStatus VARCHAR2(50) PATH ''$.ProtectStatus'',
                GeneralRevision VARCHAR2(50) PATH ''$.GeneralRevision'',
                GeneralRevDate VARCHAR2(50) PATH ''$.GeneralRevDate'',
                PCSRevision VARCHAR2(50) PATH ''$.PCSRevision'',
                PCSRevDate VARCHAR2(50) PATH ''$.PCSRevDate'',
                EDSRevision VARCHAR2(50) PATH ''$.EDSRevision'',
                EDSRevDate VARCHAR2(50) PATH ''$.EDSRevDate'',
                VDSRevision VARCHAR2(50) PATH ''$.VDSRevision'',
                VDSRevDate VARCHAR2(50) PATH ''$.VDSRevDate'',
                VSKRevision VARCHAR2(50) PATH ''$.VSKRevision'',
                VSKRevDate VARCHAR2(50) PATH ''$.VSKRevision'',
                MDSRevision VARCHAR2(50) PATH ''$.MDSRevision'',
                MDSRevDate VARCHAR2(50) PATH ''$.MDSRevDate'',
                ESKRevision VARCHAR2(50) PATH ''$.ESKRevision'',
                ESKRevDate VARCHAR2(50) PATH ''$.ESKRevDate'',
                SCRevision VARCHAR2(50) PATH ''$.SCRevision'',
                SCRevDate VARCHAR2(50) PATH ''$.SCRevDate'',
                VSMRevision VARCHAR2(50) PATH ''$.VSMRevision'',
                VSMRevDate VARCHAR2(50) PATH ''$.VSMRevDate'',
                UserName VARCHAR2(255) PATH ''$.UserName'',
                UserEntryTime VARCHAR2(50) PATH ''$.UserEntryTime'',
                UserProtected VARCHAR2(50) PATH ''$.UserProtected''
            )
        ) jt
        WHERE r.raw_json_id = ' || p_raw_json_id;

        EXECUTE IMMEDIATE v_sql;
        v_row_count := SQL%ROWCOUNT;

        -- Check if any rows were inserted
        IF v_row_count = 0 THEN
            -- This could be legitimate (plant with no issues) or a parsing error
            -- Log a warning but don't fail
            DBMS_OUTPUT.PUT_LINE('Warning: No issues parsed for plant ' || p_plant_id);
            -- Could check if JSON actually has data here for better error detection
        ELSE
            DBMS_OUTPUT.PUT_LINE('Successfully parsed ' || v_row_count || ' issues for plant ' || p_plant_id);
        END IF;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            -- Log the error and re-raise
            RAISE_APPLICATION_ERROR(-20010, 'Error parsing issues for plant ' || p_plant_id || ': ' || SQLERRM);
    END parse_issues_json;

END pkg_parse_issues;
/