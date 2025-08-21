-- JSON_TABLE Parsing Procedures for Proper Industry-Standard ETL Architecture
-- These procedures parse RAW_JSON data into staging tables using Oracle JSON_TABLE

-- =====================================================
-- SP_PARSE_OPERATORS_FROM_RAW_JSON
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_PARSE_OPERATORS_FROM_RAW_JSON(
    p_etl_run_id NUMBER DEFAULT NULL
) AS
    v_processed_count NUMBER := 0;
BEGIN
    -- Parse RAW_JSON data to STG_OPERATORS using JSON_TABLE
    INSERT INTO STG_OPERATORS (
        RAW_JSON_ID, ETL_RUN_ID, OPERATOR_ID, OPERATOR_NAME, 
        IS_VALID, IS_DUPLICATE, CREATED_DATE
    )
    SELECT 
        r.JSON_ID,
        COALESCE(p_etl_run_id, r.ETL_RUN_ID),
        TO_NUMBER(jt.operator_id),
        jt.operator_name,
        'Y', -- Default to valid
        'N', -- Default to not duplicate
        SYSDATE
    FROM RAW_JSON r
    CROSS APPLY JSON_TABLE(
        r.JSON_DATA,
        '$[*]'
        COLUMNS (
            operator_id   VARCHAR2(50)  PATH '$.OperatorID',
            operator_name VARCHAR2(200) PATH '$.OperatorName'
        )
    ) jt
    WHERE r.ENDPOINT_NAME = 'operators'
      AND r.PROCESSED_FLAG = 'N'
      AND (p_etl_run_id IS NULL OR r.ETL_RUN_ID = p_etl_run_id);
    
    v_processed_count := SQL%ROWCOUNT;
    
    -- Mark RAW_JSON records as processed
    UPDATE RAW_JSON 
    SET PROCESSED_FLAG = 'Y'
    WHERE ENDPOINT_NAME = 'operators' 
      AND PROCESSED_FLAG = 'N'
      AND (p_etl_run_id IS NULL OR ETL_RUN_ID = p_etl_run_id);
    
    DBMS_OUTPUT.PUT_LINE('✅ Parsed ' || v_processed_count || ' operators from RAW_JSON to STG_OPERATORS');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and re-raise
        LOG_ETL_ERROR(p_etl_run_id, 'SP_PARSE_OPERATORS_FROM_RAW_JSON', SQLCODE, SQLERRM);
        RAISE;
END SP_PARSE_OPERATORS_FROM_RAW_JSON;
/

-- =====================================================
-- SP_PARSE_PLANTS_FROM_RAW_JSON
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_PARSE_PLANTS_FROM_RAW_JSON(
    p_etl_run_id NUMBER DEFAULT NULL
) AS
    v_processed_count NUMBER := 0;
BEGIN
    -- Parse RAW_JSON data to STG_PLANTS using JSON_TABLE
    INSERT INTO STG_PLANTS (
        RAW_JSON_ID, ETL_RUN_ID, OPERATOR_ID, OPERATOR_NAME, PLANT_ID, SHORT_DESCRIPTION,
        PROJECT, LONG_DESCRIPTION, COMMON_LIB_PLANT_CODE, INITIAL_REVISION,
        AREA_ID, AREA, ENABLE_EMBEDDED_NOTE, CATEGORY_ID, CATEGORY,
        DOCUMENT_SPACE_LINK, ENABLE_COPY_PCS_FROM_PLANT, OVER_LENGTH,
        PCS_QA, EDS_MJ, CELSIUS_BAR, WEB_INFO_TEXT, BOLT_TENSION_TEXT,
        VISIBLE, WINDOWS_REMARK_TEXT, USER_PROTECTED,
        IS_VALID, IS_DUPLICATE, CREATED_DATE
    )
    SELECT 
        r.JSON_ID,
        COALESCE(p_etl_run_id, r.ETL_RUN_ID),
        TO_NUMBER(jt.operator_id),
        jt.operator_name,
        TO_NUMBER(jt.plant_id),
        jt.short_description,
        jt.project,
        jt.long_description,
        jt.common_lib_plant_code,
        jt.initial_revision,
        TO_NUMBER(jt.area_id),
        jt.area,
        jt.enable_embedded_note,
        jt.category_id,
        jt.category,
        jt.document_space_link,
        jt.enable_copy_pcs_from_plant,
        jt.over_length,
        jt.pcs_qa,
        jt.eds_mj,
        jt.celsius_bar,
        jt.web_info_text,
        jt.bolt_tension_text,
        jt.visible,
        jt.windows_remark_text,
        jt.user_protected,
        'Y', -- Default to valid
        'N', -- Default to not duplicate
        SYSDATE
    FROM RAW_JSON r
    CROSS APPLY JSON_TABLE(
        r.JSON_DATA,
        '$[*]'
        COLUMNS (
            operator_id                 VARCHAR2(50)  PATH '$.OperatorID',
            operator_name               VARCHAR2(200) PATH '$.OperatorName',
            plant_id                    VARCHAR2(50)  PATH '$.PlantID',
            short_description           VARCHAR2(500) PATH '$.ShortDescription',
            project                     VARCHAR2(200) PATH '$.Project',
            long_description            CLOB          PATH '$.LongDescription',
            common_lib_plant_code       VARCHAR2(100) PATH '$.CommonLibPlantCode',
            initial_revision            VARCHAR2(50)  PATH '$.InitialRevision',
            area_id                     VARCHAR2(50)  PATH '$.AreaID',
            area                        VARCHAR2(200) PATH '$.Area',
            enable_embedded_note        VARCHAR2(10)  PATH '$.EnableEmbeddedNote',
            category_id                 VARCHAR2(50)  PATH '$.CategoryID',
            category                    VARCHAR2(200) PATH '$.Category',
            document_space_link         VARCHAR2(500) PATH '$.DocumentSpaceLink',
            enable_copy_pcs_from_plant  VARCHAR2(10)  PATH '$.EnableCopyPcsFromPlant',
            over_length                 VARCHAR2(10)  PATH '$.OverLength',
            pcs_qa                      VARCHAR2(10)  PATH '$.PcsQa',
            eds_mj                      VARCHAR2(10)  PATH '$.EdsMj',
            celsius_bar                 VARCHAR2(10)  PATH '$.CelsiusBar',
            web_info_text               CLOB          PATH '$.WebInfoText',
            bolt_tension_text           CLOB          PATH '$.BoltTensionText',
            visible                     VARCHAR2(10)  PATH '$.Visible',
            windows_remark_text         CLOB          PATH '$.WindowsRemarkText',
            user_protected              VARCHAR2(10)  PATH '$.UserProtected'
        )
    ) jt
    WHERE r.ENDPOINT_NAME = 'plants'
      AND r.PROCESSED_FLAG = 'N'
      AND (p_etl_run_id IS NULL OR r.ETL_RUN_ID = p_etl_run_id);
    
    v_processed_count := SQL%ROWCOUNT;
    
    -- Mark RAW_JSON records as processed
    UPDATE RAW_JSON 
    SET PROCESSED_FLAG = 'Y'
    WHERE ENDPOINT_NAME = 'plants' 
      AND PROCESSED_FLAG = 'N'
      AND (p_etl_run_id IS NULL OR ETL_RUN_ID = p_etl_run_id);
    
    DBMS_OUTPUT.PUT_LINE('✅ Parsed ' || v_processed_count || ' plants from RAW_JSON to STG_PLANTS');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and re-raise
        LOG_ETL_ERROR(p_etl_run_id, 'SP_PARSE_PLANTS_FROM_RAW_JSON', SQLCODE, SQLERRM);
        RAISE;
END SP_PARSE_PLANTS_FROM_RAW_JSON;
/

-- =====================================================
-- SP_PARSE_ISSUES_FROM_RAW_JSON
-- =====================================================
CREATE OR REPLACE PROCEDURE SP_PARSE_ISSUES_FROM_RAW_JSON(
    p_etl_run_id NUMBER DEFAULT NULL
) AS
    v_processed_count NUMBER := 0;
BEGIN
    -- Parse RAW_JSON data to STG_ISSUES using JSON_TABLE
    INSERT INTO STG_ISSUES (
        RAW_JSON_ID, ETL_RUN_ID, PLANT_ID, ISSUE_REVISION, ISSUE_DESCRIPTION,
        ISSUE_TYPE, REVISION, ISSUE_STATUS, CREATED_BY, CREATED_DATE_API,
        MODIFIED_BY, MODIFIED_DATE, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
        IS_VALID, IS_DUPLICATE, CREATED_DATE
    )
    SELECT 
        r.JSON_ID,
        COALESCE(p_etl_run_id, r.ETL_RUN_ID),
        TO_NUMBER(jt.plant_id),
        jt.issue_revision,
        jt.issue_description,
        jt.issue_type,
        jt.revision,
        jt.issue_status,
        jt.created_by,
        PARSE_TR2000_DATE(jt.created_date),
        jt.modified_by,
        PARSE_TR2000_DATE(jt.modified_date),
        jt.user_name,
        PARSE_TR2000_DATE(jt.user_entry_time),
        jt.user_protected,
        'Y', -- Default to valid
        'N', -- Default to not duplicate
        SYSDATE
    FROM RAW_JSON r
    CROSS APPLY JSON_TABLE(
        r.JSON_DATA,
        '$[*]'
        COLUMNS (
            plant_id           VARCHAR2(50)  PATH '$.PlantID',
            issue_revision     VARCHAR2(100) PATH '$.IssueRevision',
            issue_description  VARCHAR2(500) PATH '$.IssueDescription',
            issue_type         VARCHAR2(100) PATH '$.IssueType',
            revision           VARCHAR2(50)  PATH '$.Revision',
            issue_status       VARCHAR2(50)  PATH '$.IssueStatus',
            created_by         VARCHAR2(100) PATH '$.CreatedBy',
            created_date       VARCHAR2(50)  PATH '$.CreatedDate',
            modified_by        VARCHAR2(100) PATH '$.ModifiedBy',
            modified_date      VARCHAR2(50)  PATH '$.ModifiedDate',
            user_name          VARCHAR2(100) PATH '$.UserName',
            user_entry_time    VARCHAR2(50)  PATH '$.UserEntryTime',
            user_protected     VARCHAR2(10)  PATH '$.UserProtected'
        )
    ) jt
    WHERE r.ENDPOINT_NAME LIKE '%/issues'
      AND r.PROCESSED_FLAG = 'N'
      AND (p_etl_run_id IS NULL OR r.ETL_RUN_ID = p_etl_run_id);
    
    v_processed_count := SQL%ROWCOUNT;
    
    -- Mark RAW_JSON records as processed
    UPDATE RAW_JSON 
    SET PROCESSED_FLAG = 'Y'
    WHERE ENDPOINT_NAME LIKE '%/issues' 
      AND PROCESSED_FLAG = 'N'
      AND (p_etl_run_id IS NULL OR ETL_RUN_ID = p_etl_run_id);
    
    DBMS_OUTPUT.PUT_LINE('✅ Parsed ' || v_processed_count || ' issues from RAW_JSON to STG_ISSUES');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and re-raise
        LOG_ETL_ERROR(p_etl_run_id, 'SP_PARSE_ISSUES_FROM_RAW_JSON', SQLCODE, SQLERRM);
        RAISE;
END SP_PARSE_ISSUES_FROM_RAW_JSON;
/

-- =====================================================
-- TEST THE PROCEDURES
-- =====================================================

-- Test SP_PARSE_OPERATORS_FROM_RAW_JSON
BEGIN
    DBMS_OUTPUT.PUT_LINE('🧪 Testing SP_PARSE_OPERATORS_FROM_RAW_JSON...');
    SP_PARSE_OPERATORS_FROM_RAW_JSON();
    DBMS_OUTPUT.PUT_LINE('✅ SP_PARSE_OPERATORS_FROM_RAW_JSON test completed');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ SP_PARSE_OPERATORS_FROM_RAW_JSON test failed: ' || SQLERRM);
END;
/

-- Check results
SELECT 'STG_OPERATORS' as TABLE_NAME, COUNT(*) as RECORD_COUNT FROM STG_OPERATORS
UNION ALL
SELECT 'RAW_JSON_PROCESSED', COUNT(*) FROM RAW_JSON WHERE PROCESSED_FLAG = 'Y' AND ENDPOINT_NAME = 'operators';

DBMS_OUTPUT.PUT_LINE('🎯 JSON_TABLE parsing procedures are ready for industry-standard ETL flow!');