-- =====================================================
-- TR2000 STAGING DATABASE - ENHANCED SCD2 WITH COMPLETE FIELD COVERAGE
-- Database: Oracle 21c Express Edition
-- Schema: TR2000_STAGING  
-- Version: ENHANCED - Complete API Field Coverage
-- Updated: 2025-08-17 (Session 20)
-- 
-- This DDL implements COMPLETE FIELD COVERAGE based on actual API responses:
-- - All 25+ ISSUES fields from plant_issues endpoint
-- - All 24+ PLANTS fields from plants endpoint
-- - All reference table fields with complete metadata
-- - New detailed PCS tables (Properties, Temperature/Pressure, Pipe Sizes, Elements)
-- - Enhanced audit trails and data quality controls
-- =====================================================

SET SERVEROUTPUT ON;
SET LINESIZE 200;
SET PAGESIZE 50;

-- =====================================================
-- STEP 1: DROP ALL EXISTING OBJECTS (SAFE)
-- =====================================================

BEGIN
    -- Drop any old invalid functions from previous attempts
    FOR f IN (SELECT object_name FROM user_objects WHERE object_type = 'FUNCTION' AND status = 'INVALID') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP FUNCTION ' || f.object_name;
            DBMS_OUTPUT.PUT_LINE('Dropped invalid function: ' || f.object_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Drop all views
    FOR v IN (SELECT view_name FROM user_views WHERE view_name NOT LIKE 'USER_%') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
            DBMS_OUTPUT.PUT_LINE('Dropped view: ' || v.view_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Drop all packages
    FOR p IN (SELECT object_name FROM user_objects WHERE object_type = 'PACKAGE') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP PACKAGE ' || p.object_name;
            DBMS_OUTPUT.PUT_LINE('Dropped package: ' || p.object_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Drop all procedures
    FOR p IN (SELECT object_name FROM user_objects WHERE object_type = 'PROCEDURE') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP PROCEDURE ' || p.object_name;
            DBMS_OUTPUT.PUT_LINE('Dropped procedure: ' || p.object_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Drop all tables
    FOR t IN (SELECT table_name FROM user_tables) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
            DBMS_OUTPUT.PUT_LINE('Dropped table: ' || t.table_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Drop all sequences
    FOR s IN (SELECT sequence_name FROM user_sequences) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
            DBMS_OUTPUT.PUT_LINE('Dropped sequence: ' || s.sequence_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Drop all jobs
    FOR j IN (SELECT job_name FROM user_scheduler_jobs) LOOP
        BEGIN
            DBMS_SCHEDULER.DROP_JOB(j.job_name);
            DBMS_OUTPUT.PUT_LINE('Dropped job: ' || j.job_name);
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
END;
/

-- =====================================================
-- STEP 2: CREATE SEQUENCES
-- =====================================================

CREATE SEQUENCE ETL_RUN_ID_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE ETL_LOG_ID_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE ETL_ERROR_ID_SEQ START WITH 1 INCREMENT BY 1 NOCACHE;

-- =====================================================
-- STEP 3: CREATE CONTROL TABLES
-- =====================================================

-- ETL Control Table (tracks all ETL runs)
CREATE TABLE ETL_CONTROL (
    ETL_RUN_ID         NUMBER DEFAULT ETL_RUN_ID_SEQ.NEXTVAL PRIMARY KEY,
    RUN_TYPE           VARCHAR2(50),
    STATUS             VARCHAR2(20) DEFAULT 'RUNNING',
    START_TIME         DATE DEFAULT SYSDATE,
    END_TIME           DATE,
    PROCESSING_TIME_SEC NUMBER,
    RECORDS_LOADED     NUMBER DEFAULT 0,
    RECORDS_UPDATED    NUMBER DEFAULT 0,
    RECORDS_UNCHANGED  NUMBER DEFAULT 0,
    RECORDS_DELETED    NUMBER DEFAULT 0,
    RECORDS_REACTIVATED NUMBER DEFAULT 0,
    ERROR_COUNT        NUMBER DEFAULT 0,
    API_CALL_COUNT     NUMBER DEFAULT 0,
    COMMENTS           VARCHAR2(500)
);

-- ETL Endpoint Log (tracks API calls)
CREATE TABLE ETL_ENDPOINT_LOG (
    LOG_ID             NUMBER DEFAULT ETL_LOG_ID_SEQ.NEXTVAL PRIMARY KEY,
    ETL_RUN_ID         NUMBER REFERENCES ETL_CONTROL(ETL_RUN_ID),
    ENDPOINT_NAME      VARCHAR2(100),
    PLANT_ID           VARCHAR2(50),
    API_URL            VARCHAR2(500),
    HTTP_STATUS        NUMBER,
    RECORDS_RETURNED   NUMBER,
    LOAD_TIME_SECONDS  NUMBER(10,2),
    ERROR_MESSAGE      VARCHAR2(4000),
    CREATED_DATE       DATE DEFAULT SYSDATE
);

-- ETL Error Log (survives rollbacks via autonomous transaction)
CREATE TABLE ETL_ERROR_LOG (
    ERROR_ID           NUMBER DEFAULT ETL_ERROR_ID_SEQ.NEXTVAL PRIMARY KEY,
    ETL_RUN_ID         NUMBER,
    ERROR_TIME         DATE DEFAULT SYSDATE,
    ERROR_SOURCE       VARCHAR2(100),
    ERROR_CODE         VARCHAR2(20),
    ERROR_MESSAGE      VARCHAR2(4000),
    STACK_TRACE        CLOB,
    RECORD_DATA        CLOB
);

-- ETL Plant Loader (scope control)
CREATE TABLE ETL_PLANT_LOADER (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    IS_ACTIVE          CHAR(1) DEFAULT 'Y' CHECK (IS_ACTIVE IN ('Y', 'N')),
    LOAD_PRIORITY      NUMBER DEFAULT 100,
    NOTES              VARCHAR2(500),
    CREATED_DATE       DATE DEFAULT SYSDATE,
    CREATED_BY         VARCHAR2(100) DEFAULT USER,
    MODIFIED_DATE      DATE DEFAULT SYSDATE,
    MODIFIED_BY        VARCHAR2(100) DEFAULT USER,
    CONSTRAINT PK_ETL_PLANT_LOADER PRIMARY KEY (PLANT_ID)
);

-- ETL Issue Loader (scope control for reference tables)
CREATE TABLE ETL_ISSUE_LOADER (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    CREATED_DATE       DATE DEFAULT SYSDATE,
    CONSTRAINT PK_ETL_ISSUE_LOADER PRIMARY KEY (PLANT_ID, ISSUE_REVISION),
    CONSTRAINT FK_ISSUE_LOADER_PLANT FOREIGN KEY (PLANT_ID) 
        REFERENCES ETL_PLANT_LOADER(PLANT_ID) ON DELETE CASCADE
);

-- ETL Reconciliation (tracks counts)
CREATE TABLE ETL_RECONCILIATION (
    ETL_RUN_ID         NUMBER,
    ENTITY_TYPE        VARCHAR2(50),
    SOURCE_COUNT       NUMBER,
    TARGET_COUNT       NUMBER,
    DIFF_COUNT         NUMBER,
    CHECK_TIME         DATE DEFAULT SYSDATE,
    CONSTRAINT PK_ETL_RECON PRIMARY KEY (ETL_RUN_ID, ENTITY_TYPE)
);

-- =====================================================
-- STEP 4: CREATE ENHANCED STAGING TABLES WITH COMPLETE FIELDS
-- =====================================================

-- Staging for Operators (unchanged - already minimal)
CREATE TABLE STG_OPERATORS (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    OPERATOR_ID        NUMBER NOT NULL,
    OPERATOR_NAME      VARCHAR2(200),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N' CHECK (IS_DUPLICATE IN ('Y','N')),
    IS_VALID           CHAR(1) DEFAULT 'Y' CHECK (IS_VALID IN ('Y','N')),
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Enhanced Staging for Plants (ALL 24+ API fields)
CREATE TABLE STG_PLANTS (
    STG_ID                   NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    -- Core Plant Fields
    OPERATOR_ID              NUMBER,
    OPERATOR_NAME            VARCHAR2(200),
    PLANT_ID                 VARCHAR2(50) NOT NULL,
    SHORT_DESCRIPTION        VARCHAR2(200),
    PROJECT                  VARCHAR2(200),
    LONG_DESCRIPTION         VARCHAR2(500),
    COMMON_LIB_PLANT_CODE    VARCHAR2(50),
    INITIAL_REVISION         VARCHAR2(50),
    AREA_ID                  NUMBER,
    AREA                     VARCHAR2(200),
    -- Extended Plant Configuration Fields
    ENABLE_EMBEDDED_NOTE     VARCHAR2(10),
    CATEGORY_ID              VARCHAR2(50),
    CATEGORY                 VARCHAR2(200),
    DOCUMENT_SPACE_LINK      VARCHAR2(500),
    ENABLE_COPY_PCS_FROM_PLANT VARCHAR2(10),
    OVER_LENGTH              VARCHAR2(50),
    PCS_QA                   VARCHAR2(50),
    EDS_MJ                   VARCHAR2(50),
    CELSIUS_BAR              VARCHAR2(50),
    WEB_INFO_TEXT            CLOB,
    BOLT_TENSION_TEXT        CLOB,
    VISIBLE                  VARCHAR2(10),
    WINDOWS_REMARK_TEXT      CLOB,
    USER_PROTECTED           VARCHAR2(20),
    -- ETL Control Fields
    ETL_RUN_ID               NUMBER,
    IS_DUPLICATE             CHAR(1) DEFAULT 'N',
    IS_VALID                 CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR         VARCHAR2(500),
    PROCESSED_FLAG           CHAR(1) DEFAULT 'N'
);

-- Helper function to parse TR2000 API date formats
CREATE OR REPLACE FUNCTION PARSE_TR2000_DATE(p_date_str VARCHAR2) RETURN DATE
IS
    v_date DATE;
BEGIN
    -- Return NULL for empty/null strings
    IF p_date_str IS NULL OR TRIM(p_date_str) = '' THEN
        RETURN NULL;
    END IF;
    
    -- Try DD.MM.YYYY HH24:MI:SS format first (most common in TR2000)
    BEGIN
        v_date := TO_DATE(p_date_str, 'DD.MM.YYYY HH24:MI:SS');
        RETURN v_date;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    -- Try DD.MM.YYYY HH24:MI format
    BEGIN
        v_date := TO_DATE(p_date_str, 'DD.MM.YYYY HH24:MI');
        RETURN v_date;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    -- Try DD.MM.YYYY format (date only)
    BEGIN
        v_date := TO_DATE(p_date_str, 'DD.MM.YYYY');
        RETURN v_date;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    -- Try YYYY-MM-DD HH24:MI:SS format (ISO)
    BEGIN
        v_date := TO_DATE(p_date_str, 'YYYY-MM-DD HH24:MI:SS');
        RETURN v_date;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    -- Try YYYY-MM-DD format (ISO date only)
    BEGIN
        v_date := TO_DATE(p_date_str, 'YYYY-MM-DD');
        RETURN v_date;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    -- If all formats fail, return NULL
    RETURN NULL;
END PARSE_TR2000_DATE;
/

-- Enhanced Staging for Issues (ALL 25+ API fields)
CREATE TABLE STG_ISSUES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    -- Issue Status and Dates
    STATUS             VARCHAR2(50),
    REV_DATE           VARCHAR2(50),
    PROTECT_STATUS     VARCHAR2(50),
    -- General Revision Info
    GENERAL_REVISION   VARCHAR2(50),
    GENERAL_REV_DATE   VARCHAR2(50),
    -- Specific Component Revisions and Dates
    PCS_REVISION       VARCHAR2(50),
    PCS_REV_DATE       VARCHAR2(50),
    EDS_REVISION       VARCHAR2(50),
    EDS_REV_DATE       VARCHAR2(50),
    VDS_REVISION       VARCHAR2(50),
    VDS_REV_DATE       VARCHAR2(50),
    VSK_REVISION       VARCHAR2(50),
    VSK_REV_DATE       VARCHAR2(50),
    MDS_REVISION       VARCHAR2(50),
    MDS_REV_DATE       VARCHAR2(50),
    ESK_REVISION       VARCHAR2(50),
    ESK_REV_DATE       VARCHAR2(50),
    SC_REVISION        VARCHAR2(50),
    SC_REV_DATE        VARCHAR2(50),
    VSM_REVISION       VARCHAR2(50),
    VSM_REV_DATE       VARCHAR2(50),
    -- User Audit Fields
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    VARCHAR2(50),
    USER_PROTECTED     VARCHAR2(20),
    -- ETL Control Fields
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Enhanced Staging for PCS References (ALL API fields)
CREATE TABLE STG_PCS_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    PCS_NAME           VARCHAR2(100),
    PCS_REVISION       VARCHAR2(20),
    REV_DATE           VARCHAR2(50),
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    REVISION_SUFFIX    VARCHAR2(20),
    RATING_CLASS       VARCHAR2(50),
    MATERIAL_GROUP     VARCHAR2(100),
    HISTORICAL_PCS     VARCHAR2(100),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Enhanced Staging for SC References
CREATE TABLE STG_SC_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    SC_NAME            VARCHAR2(100),
    SC_REVISION        VARCHAR2(20),
    REV_DATE           VARCHAR2(50),
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Enhanced Staging for VSM References
CREATE TABLE STG_VSM_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VSM_NAME           VARCHAR2(100),
    VSM_REVISION       VARCHAR2(20),
    REV_DATE           VARCHAR2(50),
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Enhanced Staging for VDS References
CREATE TABLE STG_VDS_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VDS_NAME           VARCHAR2(100),
    VDS_REVISION       VARCHAR2(20),
    REV_DATE           VARCHAR2(50),
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Enhanced Staging for EDS References
CREATE TABLE STG_EDS_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    EDS_NAME           VARCHAR2(100),
    EDS_REVISION       VARCHAR2(20),
    REV_DATE           VARCHAR2(50),
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Enhanced Staging for MDS References (includes AREA field)
CREATE TABLE STG_MDS_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    MDS_NAME           VARCHAR2(100),
    MDS_REVISION       VARCHAR2(20),
    AREA               VARCHAR2(50),
    REV_DATE           VARCHAR2(50),
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Enhanced Staging for VSK References
CREATE TABLE STG_VSK_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VSK_NAME           VARCHAR2(100),
    VSK_REVISION       VARCHAR2(20),
    REV_DATE           VARCHAR2(50),
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Enhanced Staging for ESK References
CREATE TABLE STG_ESK_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    ESK_NAME           VARCHAR2(100),
    ESK_REVISION       VARCHAR2(20),
    REV_DATE           VARCHAR2(50),
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Enhanced Staging for Pipe Element References
CREATE TABLE STG_PIPE_ELEMENT_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    -- Pipe Element Fields
    ELEMENT_GROUP      VARCHAR2(100),
    DIMENSION_STANDARD VARCHAR2(100),
    PRODUCT_FORM       VARCHAR2(100),
    MATERIAL_GRADE     VARCHAR2(100),
    MDS                VARCHAR2(100),
    MDS_REVISION       VARCHAR2(20),
    AREA               VARCHAR2(50),
    ELEMENT_ID         NUMBER,
    REVISION           VARCHAR2(20),
    REV_DATE           VARCHAR2(50),
    STATUS             VARCHAR2(50),
    DELTA              VARCHAR2(50),
    -- User Audit Fields
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    -- ETL Control Fields
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- =====================================================
-- STEP 5: CREATE NEW DETAILED PCS STAGING TABLES
-- =====================================================

-- Staging for PCS Header/Properties (15+ fields)
CREATE TABLE STG_PCS_HEADER (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PCS_NAME           VARCHAR2(100) NOT NULL,
    PCS_REVISION       VARCHAR2(20) NOT NULL,
    STATUS             VARCHAR2(50),
    REV_DATE           VARCHAR2(50),
    RATING_CLASS       VARCHAR2(50),
    TEST_PRESSURE      VARCHAR2(50),
    MATERIAL_GROUP     VARCHAR2(100),
    DESIGN_CODE        VARCHAR2(100),
    LAST_UPDATE        VARCHAR2(50),
    LAST_UPDATE_BY     VARCHAR2(100),
    APPROVER           VARCHAR2(100),
    NOTEPAD            CLOB,
    SPECIAL_REQ_ID     NUMBER,
    TUBE_PCS           VARCHAR2(100),
    NEW_VDS_SECTION    VARCHAR2(100),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Staging for PCS Temperature/Pressure (50+ fields)
CREATE TABLE STG_PCS_TEMP_PRESSURE (
    STG_ID                   NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID                 VARCHAR2(50) NOT NULL,
    PCS_NAME                 VARCHAR2(100) NOT NULL,
    PCS_REVISION             VARCHAR2(20) NOT NULL,
    -- Base Fields
    STATUS                   VARCHAR2(50),
    REV_DATE                 VARCHAR2(50),
    RATING_CLASS             VARCHAR2(50),
    TEST_PRESSURE            VARCHAR2(50),
    MATERIAL_GROUP           VARCHAR2(100),
    DESIGN_CODE              VARCHAR2(100),
    LAST_UPDATE              VARCHAR2(50),
    LAST_UPDATE_BY           VARCHAR2(100),
    APPROVER                 VARCHAR2(100),
    NOTEPAD                  CLOB,
    SC                       VARCHAR2(100),
    VSM                      VARCHAR2(100),
    DESIGN_CODE_REV_MARK     VARCHAR2(50),
    CORR_ALLOWANCE           NUMBER,
    CORR_ALLOWANCE_REV_MARK  VARCHAR2(50),
    LONG_WELD_EFF            VARCHAR2(50),
    LONG_WELD_EFF_REV_MARK   VARCHAR2(50),
    WALL_THK_TOL             VARCHAR2(50),
    WALL_THK_TOL_REV_MARK    VARCHAR2(50),
    SERVICE_REMARK           CLOB,
    SERVICE_REMARK_REV_MARK  VARCHAR2(50),
    -- Design Pressure Fields (12 temperature/pressure pairs)
    DESIGN_PRESS_01          VARCHAR2(50),
    DESIGN_PRESS_02          VARCHAR2(50),
    DESIGN_PRESS_03          VARCHAR2(50),
    DESIGN_PRESS_04          VARCHAR2(50),
    DESIGN_PRESS_05          VARCHAR2(50),
    DESIGN_PRESS_06          VARCHAR2(50),
    DESIGN_PRESS_07          VARCHAR2(50),
    DESIGN_PRESS_08          VARCHAR2(50),
    DESIGN_PRESS_09          VARCHAR2(50),
    DESIGN_PRESS_10          VARCHAR2(50),
    DESIGN_PRESS_11          VARCHAR2(50),
    DESIGN_PRESS_12          VARCHAR2(50),
    DESIGN_PRESS_REV_MARK    VARCHAR2(50),
    -- Design Temperature Fields (12 temperature values)
    DESIGN_TEMP_01           VARCHAR2(50),
    DESIGN_TEMP_02           VARCHAR2(50),
    DESIGN_TEMP_03           VARCHAR2(50),
    DESIGN_TEMP_04           VARCHAR2(50),
    DESIGN_TEMP_05           VARCHAR2(50),
    DESIGN_TEMP_06           VARCHAR2(50),
    DESIGN_TEMP_07           VARCHAR2(50),
    DESIGN_TEMP_08           VARCHAR2(50),
    DESIGN_TEMP_09           VARCHAR2(50),
    DESIGN_TEMP_10           VARCHAR2(50),
    DESIGN_TEMP_11           VARCHAR2(50),
    DESIGN_TEMP_12           VARCHAR2(50),
    DESIGN_TEMP_REV_MARK     VARCHAR2(50),
    -- Note ID Fields
    NOTE_ID_CORR_ALLOWANCE   VARCHAR2(50),
    NOTE_ID_SERVICE_CODE     VARCHAR2(50),
    NOTE_ID_WALL_THK_TOL     VARCHAR2(50),
    NOTE_ID_LONG_WELD_EFF    VARCHAR2(50),
    NOTE_ID_GENERAL_PCS      VARCHAR2(50),
    NOTE_ID_DESIGN_CODE      VARCHAR2(50),
    NOTE_ID_PRESS_TEMP_TABLE VARCHAR2(50),
    NOTE_ID_PIPE_SIZE_WTH_TABLE VARCHAR2(50),
    -- Additional Fields
    PRESS_ELEMENT_CHANGE     VARCHAR2(50),
    TEMP_ELEMENT_CHANGE      VARCHAR2(50),
    MATERIAL_GROUP_ID        NUMBER,
    SPECIAL_REQ_ID           NUMBER,
    SPECIAL_REQ              VARCHAR2(200),
    NEW_VDS_SECTION          VARCHAR2(100),
    TUBE_PCS                 VARCHAR2(100),
    EDS_MJ_MATRIX            VARCHAR2(50),
    MJ_REDUCTION_FACTOR      NUMBER,
    -- ETL Control Fields
    ETL_RUN_ID               NUMBER,
    IS_DUPLICATE             CHAR(1) DEFAULT 'N',
    IS_VALID                 CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR         VARCHAR2(500),
    PROCESSED_FLAG           CHAR(1) DEFAULT 'N'
);

-- Staging for PCS Pipe Sizes (11 fields)
CREATE TABLE STG_PCS_PIPE_SIZES (
    STG_ID               NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID             VARCHAR2(50) NOT NULL,
    PCS_NAME             VARCHAR2(100) NOT NULL,
    PCS_REVISION         VARCHAR2(20) NOT NULL,
    NOM_SIZE             VARCHAR2(50),
    OUTER_DIAM           VARCHAR2(50),
    WALL_THICKNESS       VARCHAR2(50),
    SCHEDULE             VARCHAR2(50),
    UNDER_TOLERANCE      VARCHAR2(50),
    CORROSION_ALLOWANCE  VARCHAR2(50),
    WELDING_FACTOR       VARCHAR2(50),
    DIM_ELEMENT_CHANGE   VARCHAR2(50),
    SCHEDULE_IN_MATRIX   VARCHAR2(50),
    ETL_RUN_ID           NUMBER,
    IS_DUPLICATE         CHAR(1) DEFAULT 'N',
    IS_VALID             CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR     VARCHAR2(500),
    PROCESSED_FLAG       CHAR(1) DEFAULT 'N'
);

-- Staging for PCS Pipe Elements (25+ fields)
CREATE TABLE STG_PCS_PIPE_ELEMENTS (
    STG_ID               NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID             VARCHAR2(50) NOT NULL,
    PCS_NAME             VARCHAR2(100) NOT NULL,
    PCS_REVISION         VARCHAR2(20) NOT NULL,
    MATERIAL_GROUP_ID    NUMBER,
    ELEMENT_GROUP_NO     NUMBER,
    LINE_NO              NUMBER,
    ELEMENT              VARCHAR2(200),
    DIM_STANDARD         VARCHAR2(100),
    FROM_SIZE            VARCHAR2(50),
    TO_SIZE              VARCHAR2(50),
    PRODUCT_FORM         VARCHAR2(100),
    MATERIAL             VARCHAR2(200),
    MDS                  VARCHAR2(100),
    EDS                  VARCHAR2(100),
    EDS_REVISION         VARCHAR2(20),
    ESK                  VARCHAR2(100),
    REVMARK              VARCHAR2(50),
    REMARK               CLOB,
    PAGE_BREAK           VARCHAR2(10),
    ELEMENT_GROUP        VARCHAR2(100),
    MATL_IN_MATRIX       VARCHAR2(10),
    PARENT_ELEMENT       VARCHAR2(200),
    ITEM_CODE            VARCHAR2(100),
    MDS_REVISION         VARCHAR2(20),
    ETL_RUN_ID           NUMBER,
    IS_DUPLICATE         CHAR(1) DEFAULT 'N',
    IS_VALID             CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR     VARCHAR2(500),
    PROCESSED_FLAG       CHAR(1) DEFAULT 'N'
);

-- =====================================================
-- STEP 6: CREATE ENHANCED DIMENSION TABLES (COMPLETE SCD2)
-- =====================================================

-- OPERATORS Dimension (unchanged - already minimal)
CREATE TABLE OPERATORS (
    OPERATOR_ID        NUMBER NOT NULL,
    OPERATOR_NAME      VARCHAR2(200),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),  -- INSERT, UPDATE, DELETE, REACTIVATE
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_OPERATORS PRIMARY KEY (OPERATOR_ID, VALID_FROM)
);

-- Enhanced PLANTS Dimension (ALL 24+ API fields with SCD2)
CREATE TABLE PLANTS (
    -- Core Plant Fields
    OPERATOR_ID              NUMBER,
    OPERATOR_NAME            VARCHAR2(200),
    PLANT_ID                 VARCHAR2(50) NOT NULL,
    SHORT_DESCRIPTION        VARCHAR2(200),
    PROJECT                  VARCHAR2(200),
    LONG_DESCRIPTION         VARCHAR2(500),
    COMMON_LIB_PLANT_CODE    VARCHAR2(50),
    INITIAL_REVISION         VARCHAR2(50),
    AREA_ID                  NUMBER,
    AREA                     VARCHAR2(200),
    -- Extended Plant Configuration Fields
    ENABLE_EMBEDDED_NOTE     VARCHAR2(10),
    CATEGORY_ID              VARCHAR2(50),
    CATEGORY                 VARCHAR2(200),
    DOCUMENT_SPACE_LINK      VARCHAR2(500),
    ENABLE_COPY_PCS_FROM_PLANT VARCHAR2(10),
    OVER_LENGTH              VARCHAR2(50),
    PCS_QA                   VARCHAR2(50),
    EDS_MJ                   VARCHAR2(50),
    CELSIUS_BAR              VARCHAR2(50),
    WEB_INFO_TEXT            CLOB,
    BOLT_TENSION_TEXT        CLOB,
    VISIBLE                  VARCHAR2(10),
    WINDOWS_REMARK_TEXT      CLOB,
    USER_PROTECTED           VARCHAR2(20),
    -- SCD2 Fields
    SRC_HASH                 RAW(32),
    VALID_FROM               DATE DEFAULT SYSDATE,
    VALID_TO                 DATE,
    IS_CURRENT               CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE              VARCHAR2(20),
    DELETE_DATE              DATE,
    ETL_RUN_ID               NUMBER,
    CONSTRAINT PK_PLANTS PRIMARY KEY (PLANT_ID, VALID_FROM)
);

-- Enhanced ISSUES Dimension (ALL 25+ API fields with SCD2)
CREATE TABLE ISSUES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    -- Issue Status and Dates
    STATUS             VARCHAR2(50),
    REV_DATE           DATE,
    PROTECT_STATUS     VARCHAR2(50),
    -- General Revision Info
    GENERAL_REVISION   VARCHAR2(50),
    GENERAL_REV_DATE   DATE,
    -- Specific Component Revisions and Dates
    PCS_REVISION       VARCHAR2(50),
    PCS_REV_DATE       DATE,
    EDS_REVISION       VARCHAR2(50),
    EDS_REV_DATE       DATE,
    VDS_REVISION       VARCHAR2(50),
    VDS_REV_DATE       DATE,
    VSK_REVISION       VARCHAR2(50),
    VSK_REV_DATE       DATE,
    MDS_REVISION       VARCHAR2(50),
    MDS_REV_DATE       DATE,
    ESK_REVISION       VARCHAR2(50),
    ESK_REV_DATE       DATE,
    SC_REVISION        VARCHAR2(50),
    SC_REV_DATE        DATE,
    VSM_REVISION       VARCHAR2(50),
    VSM_REV_DATE       DATE,
    -- User Audit Fields
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    -- SCD2 Fields
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_ISSUES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VALID_FROM)
);

-- Enhanced PCS_REFERENCES Dimension (ALL API fields with SCD2)
CREATE TABLE PCS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    PCS_NAME           VARCHAR2(100),
    PCS_REVISION       VARCHAR2(20),
    REV_DATE           DATE,
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    REVISION_SUFFIX    VARCHAR2(20),
    RATING_CLASS       VARCHAR2(50),
    MATERIAL_GROUP     VARCHAR2(100),
    HISTORICAL_PCS     VARCHAR2(100),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_PCS_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, PCS_NAME, PCS_REVISION, VALID_FROM)
);

-- Continue with enhanced reference tables...
-- (Similar pattern for SC, VSM, VDS, EDS, MDS, VSK, ESK, PIPE_ELEMENT)

-- Enhanced SC_REFERENCES Dimension
CREATE TABLE SC_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    SC_NAME            VARCHAR2(100),
    SC_REVISION        VARCHAR2(20),
    REV_DATE           DATE,
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_SC_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, SC_NAME, SC_REVISION, VALID_FROM)
);

-- Enhanced VSM_REFERENCES Dimension
CREATE TABLE VSM_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VSM_NAME           VARCHAR2(100),
    VSM_REVISION       VARCHAR2(20),
    REV_DATE           DATE,
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_VSM_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VSM_NAME, VSM_REVISION, VALID_FROM)
);

-- Enhanced VDS_REFERENCES Dimension
CREATE TABLE VDS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VDS_NAME           VARCHAR2(100),
    VDS_REVISION       VARCHAR2(20),
    REV_DATE           DATE,
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_VDS_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VDS_NAME, VDS_REVISION, VALID_FROM)
);

-- Enhanced EDS_REFERENCES Dimension
CREATE TABLE EDS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    EDS_NAME           VARCHAR2(100),
    EDS_REVISION       VARCHAR2(20),
    REV_DATE           DATE,
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_EDS_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, EDS_NAME, EDS_REVISION, VALID_FROM)
);

-- Enhanced MDS_REFERENCES Dimension (includes AREA field)
CREATE TABLE MDS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    MDS_NAME           VARCHAR2(100),
    MDS_REVISION       VARCHAR2(20),
    AREA               VARCHAR2(50),
    REV_DATE           DATE,
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_MDS_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, MDS_NAME, MDS_REVISION, VALID_FROM)
);

-- Enhanced VSK_REFERENCES Dimension
CREATE TABLE VSK_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VSK_NAME           VARCHAR2(100),
    VSK_REVISION       VARCHAR2(20),
    REV_DATE           DATE,
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_VSK_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VSK_NAME, VSK_REVISION, VALID_FROM)
);

-- Enhanced ESK_REFERENCES Dimension
CREATE TABLE ESK_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    ESK_NAME           VARCHAR2(100),
    ESK_REVISION       VARCHAR2(20),
    REV_DATE           DATE,
    STATUS             VARCHAR2(50),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_ESK_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, ESK_NAME, ESK_REVISION, VALID_FROM)
);

-- Enhanced PIPE_ELEMENT_REFERENCES Dimension
CREATE TABLE PIPE_ELEMENT_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    ELEMENT_GROUP      VARCHAR2(100),
    DIMENSION_STANDARD VARCHAR2(100),
    PRODUCT_FORM       VARCHAR2(100),
    MATERIAL_GRADE     VARCHAR2(100),
    MDS                VARCHAR2(100),
    MDS_REVISION       VARCHAR2(20),
    AREA               VARCHAR2(50),
    ELEMENT_ID         NUMBER,
    REVISION           VARCHAR2(20),
    REV_DATE           DATE,
    STATUS             VARCHAR2(50),
    DELTA              VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_PIPE_ELEMENT_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, ELEMENT_ID, VALID_FROM)
);

-- =====================================================
-- STEP 7: CREATE NEW DETAILED PCS DIMENSION TABLES
-- =====================================================

-- PCS_HEADER Dimension (Complete PCS properties)
CREATE TABLE PCS_HEADER (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PCS_NAME           VARCHAR2(100) NOT NULL,
    PCS_REVISION       VARCHAR2(20) NOT NULL,
    STATUS             VARCHAR2(50),
    REV_DATE           DATE,
    RATING_CLASS       VARCHAR2(50),
    TEST_PRESSURE      VARCHAR2(50),
    MATERIAL_GROUP     VARCHAR2(100),
    DESIGN_CODE        VARCHAR2(100),
    LAST_UPDATE        DATE,
    LAST_UPDATE_BY     VARCHAR2(100),
    APPROVER           VARCHAR2(100),
    NOTEPAD            CLOB,
    SPECIAL_REQ_ID     NUMBER,
    TUBE_PCS           VARCHAR2(100),
    NEW_VDS_SECTION    VARCHAR2(100),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_PCS_HEADER PRIMARY KEY (PLANT_ID, PCS_NAME, PCS_REVISION, VALID_FROM)
);

-- PCS_TEMP_PRESSURE Dimension (Complete temperature/pressure matrix)
CREATE TABLE PCS_TEMP_PRESSURE (
    PLANT_ID                 VARCHAR2(50) NOT NULL,
    PCS_NAME                 VARCHAR2(100) NOT NULL,
    PCS_REVISION             VARCHAR2(20) NOT NULL,
    -- Base Fields
    STATUS                   VARCHAR2(50),
    REV_DATE                 DATE,
    RATING_CLASS             VARCHAR2(50),
    TEST_PRESSURE            VARCHAR2(50),
    MATERIAL_GROUP           VARCHAR2(100),
    DESIGN_CODE              VARCHAR2(100),
    LAST_UPDATE              DATE,
    LAST_UPDATE_BY           VARCHAR2(100),
    APPROVER                 VARCHAR2(100),
    NOTEPAD                  CLOB,
    SC                       VARCHAR2(100),
    VSM                      VARCHAR2(100),
    DESIGN_CODE_REV_MARK     VARCHAR2(50),
    CORR_ALLOWANCE           NUMBER,
    CORR_ALLOWANCE_REV_MARK  VARCHAR2(50),
    LONG_WELD_EFF            VARCHAR2(50),
    LONG_WELD_EFF_REV_MARK   VARCHAR2(50),
    WALL_THK_TOL             VARCHAR2(50),
    WALL_THK_TOL_REV_MARK    VARCHAR2(50),
    SERVICE_REMARK           CLOB,
    SERVICE_REMARK_REV_MARK  VARCHAR2(50),
    -- Design Pressure Fields (12 temperature/pressure pairs)
    DESIGN_PRESS_01          NUMBER(10,2),
    DESIGN_PRESS_02          NUMBER(10,2),
    DESIGN_PRESS_03          NUMBER(10,2),
    DESIGN_PRESS_04          NUMBER(10,2),
    DESIGN_PRESS_05          NUMBER(10,2),
    DESIGN_PRESS_06          NUMBER(10,2),
    DESIGN_PRESS_07          NUMBER(10,2),
    DESIGN_PRESS_08          NUMBER(10,2),
    DESIGN_PRESS_09          NUMBER(10,2),
    DESIGN_PRESS_10          NUMBER(10,2),
    DESIGN_PRESS_11          NUMBER(10,2),
    DESIGN_PRESS_12          NUMBER(10,2),
    DESIGN_PRESS_REV_MARK    VARCHAR2(50),
    -- Design Temperature Fields (12 temperature values)
    DESIGN_TEMP_01           NUMBER(10,2),
    DESIGN_TEMP_02           NUMBER(10,2),
    DESIGN_TEMP_03           NUMBER(10,2),
    DESIGN_TEMP_04           NUMBER(10,2),
    DESIGN_TEMP_05           NUMBER(10,2),
    DESIGN_TEMP_06           NUMBER(10,2),
    DESIGN_TEMP_07           NUMBER(10,2),
    DESIGN_TEMP_08           NUMBER(10,2),
    DESIGN_TEMP_09           NUMBER(10,2),
    DESIGN_TEMP_10           NUMBER(10,2),
    DESIGN_TEMP_11           NUMBER(10,2),
    DESIGN_TEMP_12           NUMBER(10,2),
    DESIGN_TEMP_REV_MARK     VARCHAR2(50),
    -- Note ID Fields
    NOTE_ID_CORR_ALLOWANCE   VARCHAR2(50),
    NOTE_ID_SERVICE_CODE     VARCHAR2(50),
    NOTE_ID_WALL_THK_TOL     VARCHAR2(50),
    NOTE_ID_LONG_WELD_EFF    VARCHAR2(50),
    NOTE_ID_GENERAL_PCS      VARCHAR2(50),
    NOTE_ID_DESIGN_CODE      VARCHAR2(50),
    NOTE_ID_PRESS_TEMP_TABLE VARCHAR2(50),
    NOTE_ID_PIPE_SIZE_WTH_TABLE VARCHAR2(50),
    -- Additional Fields
    PRESS_ELEMENT_CHANGE     VARCHAR2(50),
    TEMP_ELEMENT_CHANGE      VARCHAR2(50),
    MATERIAL_GROUP_ID        NUMBER,
    SPECIAL_REQ_ID           NUMBER,
    SPECIAL_REQ              VARCHAR2(200),
    NEW_VDS_SECTION          VARCHAR2(100),
    TUBE_PCS                 VARCHAR2(100),
    EDS_MJ_MATRIX            VARCHAR2(50),
    MJ_REDUCTION_FACTOR      NUMBER,
    -- SCD2 Fields
    SRC_HASH                 RAW(32),
    VALID_FROM               DATE DEFAULT SYSDATE,
    VALID_TO                 DATE,
    IS_CURRENT               CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE              VARCHAR2(20),
    DELETE_DATE              DATE,
    ETL_RUN_ID               NUMBER,
    CONSTRAINT PK_PCS_TEMP_PRESSURE PRIMARY KEY (PLANT_ID, PCS_NAME, PCS_REVISION, VALID_FROM)
);

-- PCS_PIPE_SIZES Dimension
CREATE TABLE PCS_PIPE_SIZES (
    PLANT_ID             VARCHAR2(50) NOT NULL,
    PCS_NAME             VARCHAR2(100) NOT NULL,
    PCS_REVISION         VARCHAR2(20) NOT NULL,
    NOM_SIZE             VARCHAR2(50) NOT NULL,
    OUTER_DIAM           NUMBER(10,3),
    WALL_THICKNESS       NUMBER(10,3),
    SCHEDULE             VARCHAR2(50),
    UNDER_TOLERANCE      NUMBER(10,3),
    CORROSION_ALLOWANCE  NUMBER(10,3),
    WELDING_FACTOR       NUMBER(5,3),
    DIM_ELEMENT_CHANGE   VARCHAR2(50),
    SCHEDULE_IN_MATRIX   VARCHAR2(50),
    SRC_HASH             RAW(32),
    VALID_FROM           DATE DEFAULT SYSDATE,
    VALID_TO             DATE,
    IS_CURRENT           CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE          VARCHAR2(20),
    DELETE_DATE          DATE,
    ETL_RUN_ID           NUMBER,
    CONSTRAINT PK_PCS_PIPE_SIZES PRIMARY KEY (PLANT_ID, PCS_NAME, PCS_REVISION, NOM_SIZE, VALID_FROM)
);

-- PCS_PIPE_ELEMENTS Dimension
CREATE TABLE PCS_PIPE_ELEMENTS (
    PLANT_ID             VARCHAR2(50) NOT NULL,
    PCS_NAME             VARCHAR2(100) NOT NULL,
    PCS_REVISION         VARCHAR2(20) NOT NULL,
    MATERIAL_GROUP_ID    NUMBER NOT NULL,
    ELEMENT_GROUP_NO     NUMBER NOT NULL,
    LINE_NO              NUMBER NOT NULL,
    ELEMENT              VARCHAR2(200),
    DIM_STANDARD         VARCHAR2(100),
    FROM_SIZE            VARCHAR2(50),
    TO_SIZE              VARCHAR2(50),
    PRODUCT_FORM         VARCHAR2(100),
    MATERIAL             VARCHAR2(200),
    MDS                  VARCHAR2(100),
    EDS                  VARCHAR2(100),
    EDS_REVISION         VARCHAR2(20),
    ESK                  VARCHAR2(100),
    REVMARK              VARCHAR2(50),
    REMARK               CLOB,
    PAGE_BREAK           VARCHAR2(10),
    ELEMENT_GROUP        VARCHAR2(100),
    MATL_IN_MATRIX       VARCHAR2(10),
    PARENT_ELEMENT       VARCHAR2(200),
    ITEM_CODE            VARCHAR2(100),
    MDS_REVISION         VARCHAR2(20),
    SRC_HASH             RAW(32),
    VALID_FROM           DATE DEFAULT SYSDATE,
    VALID_TO             DATE,
    IS_CURRENT           CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE          VARCHAR2(20),
    DELETE_DATE          DATE,
    ETL_RUN_ID           NUMBER,
    CONSTRAINT PK_PCS_PIPE_ELEMENTS PRIMARY KEY (PLANT_ID, PCS_NAME, PCS_REVISION, MATERIAL_GROUP_ID, ELEMENT_GROUP_NO, LINE_NO, VALID_FROM)
);

-- =====================================================
-- STEP 8: CREATE RAW_JSON AUDIT TRAIL
-- =====================================================

-- Enhanced RAW_JSON table for complete API response audit trail
CREATE TABLE RAW_JSON (
    JSON_ID            NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    ETL_RUN_ID         NUMBER,
    ENDPOINT_NAME      VARCHAR2(100) NOT NULL,
    REQUEST_URL        VARCHAR2(1000),
    REQUEST_PARAMS     CLOB,
    RESPONSE_STATUS    NUMBER,
    PLANT_ID           VARCHAR2(50),
    CREATED_DATE       TIMESTAMP(6) DEFAULT SYSTIMESTAMP NOT NULL,
    JSON_DATA          CLOB CHECK (JSON_DATA IS JSON),
    RESP_HASH_SHA256   RAW(32) NOT NULL,
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N' CHECK (PROCESSED_FLAG IN ('Y','N')),
    DURATION_MS        NUMBER,
    HEADERS_JSON       CLOB
) LOB (JSON_DATA) STORE AS SECUREFILE (
    COMPRESS MEDIUM
    DEDUPLICATE
);

-- Performance indexes for RAW_JSON table
CREATE INDEX IX_RAWJSON_PICK
  ON RAW_JSON (ENDPOINT_NAME, PROCESSED_FLAG, CREATED_DATE);

CREATE INDEX IX_RAWJSON_HASH
  ON RAW_JSON (RESP_HASH_SHA256);

-- =====================================================
-- STEP 9: CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Indexes on dimension tables for current records
CREATE INDEX IDX_OPERATORS_CURRENT ON OPERATORS (OPERATOR_ID, IS_CURRENT);
CREATE INDEX IDX_PLANTS_CURRENT ON PLANTS (PLANT_ID, IS_CURRENT);
CREATE INDEX IDX_ISSUES_CURRENT ON ISSUES (PLANT_ID, ISSUE_REVISION, IS_CURRENT);
CREATE INDEX IDX_PCS_REF_CURRENT ON PCS_REFERENCES (PLANT_ID, ISSUE_REVISION, IS_CURRENT);
CREATE INDEX IDX_VDS_REF_CURRENT ON VDS_REFERENCES (PLANT_ID, ISSUE_REVISION, IS_CURRENT);

-- Indexes on staging tables for ETL processing
CREATE INDEX IDX_STG_OPERATORS_ETL ON STG_OPERATORS (ETL_RUN_ID, IS_DUPLICATE, IS_VALID);
CREATE INDEX IDX_STG_PLANTS_ETL ON STG_PLANTS (ETL_RUN_ID, IS_DUPLICATE, IS_VALID);
CREATE INDEX IDX_STG_ISSUES_ETL ON STG_ISSUES (ETL_RUN_ID, IS_DUPLICATE, IS_VALID);

-- =====================================================
-- STEP 10: CREATE UTILITY VIEWS
-- =====================================================

-- View for current active issues (used by reference loading)
CREATE OR REPLACE VIEW V_ISSUES_FOR_REFERENCES AS
SELECT DISTINCT i.PLANT_ID, i.ISSUE_REVISION, i.USER_NAME, i.USER_ENTRY_TIME, i.USER_PROTECTED
FROM ISSUES i
INNER JOIN ETL_ISSUE_LOADER il ON i.PLANT_ID = il.PLANT_ID AND i.ISSUE_REVISION = il.ISSUE_REVISION
WHERE i.IS_CURRENT = 'Y';

-- View for current plants in loader scope
CREATE OR REPLACE VIEW V_PLANTS_IN_SCOPE AS
SELECT p.*, pl.IS_ACTIVE, pl.LOAD_PRIORITY
FROM PLANTS p
INNER JOIN ETL_PLANT_LOADER pl ON p.PLANT_ID = pl.PLANT_ID
WHERE p.IS_CURRENT = 'Y' AND pl.IS_ACTIVE = 'Y';

-- =====================================================
-- STEP 11: CREATE UTILITY PROCEDURES
-- =====================================================

-- Error logging procedure (autonomous transaction)
CREATE OR REPLACE PROCEDURE LOG_ETL_ERROR(
    p_etl_run_id NUMBER,
    p_error_source VARCHAR2,
    p_error_code VARCHAR2,
    p_error_message VARCHAR2,
    p_stack_trace CLOB DEFAULT NULL,
    p_record_data CLOB DEFAULT NULL
) AS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO ETL_ERROR_LOG (
        ETL_RUN_ID, ERROR_SOURCE, ERROR_CODE, ERROR_MESSAGE, STACK_TRACE, RECORD_DATA
    ) VALUES (
        p_etl_run_id, p_error_source, p_error_code, p_error_message, p_stack_trace, p_record_data
    );
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END LOG_ETL_ERROR;
/

-- Enhanced RAW_JSON insert procedure (matches C# parameter expectations)
CREATE OR REPLACE PROCEDURE SP_INSERT_RAW_JSON(
    p_etl_run_id     NUMBER,
    p_endpoint       VARCHAR2,
    p_request_url    VARCHAR2 DEFAULT NULL,
    p_request_params CLOB DEFAULT NULL,
    p_response_status NUMBER DEFAULT 200,
    p_plant_id       VARCHAR2 DEFAULT NULL,
    p_json_data      CLOB,
    p_duration_ms    NUMBER DEFAULT NULL,
    p_headers        CLOB DEFAULT NULL
) AS
    v_hash RAW(32);
    v_hash_input VARCHAR2(4000);
BEGIN
    -- Create hash input from data characteristics (no special privileges required)
    v_hash_input := p_endpoint || '|' || NVL(p_plant_id, 'NULL') || '|' || 
                    TO_CHAR(LENGTH(p_json_data)) || '|' || 
                    SUBSTR(p_json_data, 1, 100) || '|' || 
                    SUBSTR(p_json_data, -100);
    
    -- Use DBMS_UTILITY.GET_HASH_VALUE (no special privileges required)
    v_hash := UTL_RAW.CAST_FROM_BINARY_INTEGER(
        DBMS_UTILITY.GET_HASH_VALUE(v_hash_input, 1, POWER(2,30))
    );
    
    -- Insert with comprehensive metadata
    INSERT INTO RAW_JSON (
        ETL_RUN_ID, ENDPOINT_NAME, REQUEST_URL, REQUEST_PARAMS,
        RESPONSE_STATUS, PLANT_ID, JSON_DATA, RESP_HASH_SHA256,
        DURATION_MS, HEADERS_JSON
    ) VALUES (
        p_etl_run_id, p_endpoint, p_request_url, p_request_params,
        p_response_status, p_plant_id, p_json_data, v_hash,
        p_duration_ms, p_headers
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't break ETL
        LOG_ETL_ERROR(p_etl_run_id, 'RAW_JSON_INSERT', 'SP_INSERT_RAW_JSON', SQLERRM);
        RAISE; -- Re-raise to maintain error handling
END SP_INSERT_RAW_JSON;
/

-- RAW_JSON cleanup procedure
CREATE OR REPLACE PROCEDURE SP_PURGE_RAW_JSON AS
BEGIN
    DELETE FROM RAW_JSON 
    WHERE CREATED_DATE < SYSDATE - 30;
    DBMS_OUTPUT.PUT_LINE('Purged ' || SQL%ROWCOUNT || ' old RAW_JSON records');
EXCEPTION
    WHEN OTHERS THEN
        -- Don't let cleanup failures break ETL
        DBMS_OUTPUT.PUT_LINE('RAW_JSON cleanup failed: ' || SQLERRM);
END SP_PURGE_RAW_JSON;
/

-- Deduplication procedure
CREATE OR REPLACE PROCEDURE SP_DEDUPLICATE_STAGING(p_etl_run_id NUMBER) AS
BEGIN
    -- Deduplicate STG_OPERATORS
    UPDATE STG_OPERATORS
    SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID)
        FROM STG_OPERATORS
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY OPERATOR_ID
    ) AND ETL_RUN_ID = p_etl_run_id;

    -- Deduplicate STG_PLANTS
    UPDATE STG_PLANTS
    SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID)
        FROM STG_PLANTS
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID
    ) AND ETL_RUN_ID = p_etl_run_id;

    -- Deduplicate STG_ISSUES
    UPDATE STG_ISSUES
    SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID)
        FROM STG_ISSUES
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID, ISSUE_REVISION
    ) AND ETL_RUN_ID = p_etl_run_id;

    -- Deduplicate all reference staging tables
    UPDATE STG_PCS_REFERENCES SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID) FROM STG_PCS_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID, ISSUE_REVISION, PCS_NAME, PCS_REVISION
    ) AND ETL_RUN_ID = p_etl_run_id;

    UPDATE STG_VDS_REFERENCES SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID) FROM STG_VDS_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID, ISSUE_REVISION, VDS_NAME, VDS_REVISION
    ) AND ETL_RUN_ID = p_etl_run_id;

    -- Continue for all other reference types...
    UPDATE STG_EDS_REFERENCES SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID) FROM STG_EDS_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID, ISSUE_REVISION, EDS_NAME, EDS_REVISION
    ) AND ETL_RUN_ID = p_etl_run_id;

    UPDATE STG_MDS_REFERENCES SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID) FROM STG_MDS_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID, ISSUE_REVISION, MDS_NAME, MDS_REVISION
    ) AND ETL_RUN_ID = p_etl_run_id;

    UPDATE STG_VSK_REFERENCES SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID) FROM STG_VSK_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID, ISSUE_REVISION, VSK_NAME, VSK_REVISION
    ) AND ETL_RUN_ID = p_etl_run_id;

    UPDATE STG_ESK_REFERENCES SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID) FROM STG_ESK_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID, ISSUE_REVISION, ESK_NAME, ESK_REVISION
    ) AND ETL_RUN_ID = p_etl_run_id;

    UPDATE STG_SC_REFERENCES SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID) FROM STG_SC_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID, ISSUE_REVISION, SC_NAME, SC_REVISION
    ) AND ETL_RUN_ID = p_etl_run_id;

    UPDATE STG_VSM_REFERENCES SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID) FROM STG_VSM_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID, ISSUE_REVISION, VSM_NAME, VSM_REVISION
    ) AND ETL_RUN_ID = p_etl_run_id;

    UPDATE STG_PIPE_ELEMENT_REFERENCES SET IS_DUPLICATE = 'Y'
    WHERE STG_ID NOT IN (
        SELECT MIN(STG_ID) FROM STG_PIPE_ELEMENT_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        GROUP BY PLANT_ID, ISSUE_REVISION, ELEMENT_ID
    ) AND ETL_RUN_ID = p_etl_run_id;

END SP_DEDUPLICATE_STAGING;
/

-- =====================================================
-- STEP 12: CREATE STORED PROCEDURES AND PACKAGES
-- =====================================================

-- Enhanced SP_DEDUPLICATE_STAGING procedure
CREATE OR REPLACE PROCEDURE SP_DEDUPLICATE_STAGING(
    p_etl_run_id IN NUMBER,
    p_entity_type IN VARCHAR2
) AS
    v_dup_count NUMBER;
BEGIN
    -- NO COMMIT in this procedure - orchestrator handles it
    CASE p_entity_type
        WHEN 'OPERATORS' THEN
            MERGE INTO STG_OPERATORS tgt
            USING (
                SELECT STG_ID,
                       ROW_NUMBER() OVER (
                           PARTITION BY OPERATOR_ID 
                           ORDER BY ETL_RUN_ID DESC, STG_ID DESC
                       ) as rn
                FROM STG_OPERATORS
                WHERE ETL_RUN_ID = p_etl_run_id
            ) src
            ON (tgt.STG_ID = src.STG_ID)
            WHEN MATCHED THEN
                UPDATE SET IS_DUPLICATE = CASE WHEN src.rn > 1 THEN 'Y' ELSE 'N' END;
                
        WHEN 'PLANTS' THEN
            MERGE INTO STG_PLANTS tgt
            USING (
                SELECT STG_ID,
                       ROW_NUMBER() OVER (
                           PARTITION BY PLANT_ID 
                           ORDER BY ETL_RUN_ID DESC, STG_ID DESC
                       ) as rn
                FROM STG_PLANTS
                WHERE ETL_RUN_ID = p_etl_run_id
            ) src
            ON (tgt.STG_ID = src.STG_ID)
            WHEN MATCHED THEN
                UPDATE SET IS_DUPLICATE = CASE WHEN src.rn > 1 THEN 'Y' ELSE 'N' END;
                
        WHEN 'ISSUES' THEN
            MERGE INTO STG_ISSUES tgt
            USING (
                SELECT STG_ID,
                       ROW_NUMBER() OVER (
                           PARTITION BY PLANT_ID, ISSUE_REVISION 
                           ORDER BY ETL_RUN_ID DESC, STG_ID DESC
                       ) as rn
                FROM STG_ISSUES
                WHERE ETL_RUN_ID = p_etl_run_id
            ) src
            ON (tgt.STG_ID = src.STG_ID)
            WHEN MATCHED THEN
                UPDATE SET IS_DUPLICATE = CASE WHEN src.rn > 1 THEN 'Y' ELSE 'N' END;
                
        WHEN 'VDS_REFERENCES' THEN
            MERGE INTO STG_VDS_REFERENCES tgt
            USING (
                SELECT STG_ID,
                       ROW_NUMBER() OVER (
                           PARTITION BY PLANT_ID, ISSUE_REVISION, VDS_NAME, VDS_REVISION 
                           ORDER BY ETL_RUN_ID DESC, STG_ID DESC
                       ) as rn
                FROM STG_VDS_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
            ) src
            ON (tgt.STG_ID = src.STG_ID)
            WHEN MATCHED THEN
                UPDATE SET IS_DUPLICATE = CASE WHEN src.rn > 1 THEN 'Y' ELSE 'N' END;
                
        WHEN 'EDS_REFERENCES' THEN
            UPDATE STG_EDS_REFERENCES SET IS_DUPLICATE = 'Y'
            WHERE STG_ID NOT IN (
                SELECT MIN(STG_ID) FROM STG_EDS_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
                GROUP BY PLANT_ID, ISSUE_REVISION, EDS_NAME, EDS_REVISION
            ) AND ETL_RUN_ID = p_etl_run_id;

        WHEN 'MDS_REFERENCES' THEN
            UPDATE STG_MDS_REFERENCES SET IS_DUPLICATE = 'Y'
            WHERE STG_ID NOT IN (
                SELECT MIN(STG_ID) FROM STG_MDS_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
                GROUP BY PLANT_ID, ISSUE_REVISION, MDS_NAME, MDS_REVISION
            ) AND ETL_RUN_ID = p_etl_run_id;

        WHEN 'VSK_REFERENCES' THEN
            UPDATE STG_VSK_REFERENCES SET IS_DUPLICATE = 'Y'
            WHERE STG_ID NOT IN (
                SELECT MIN(STG_ID) FROM STG_VSK_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
                GROUP BY PLANT_ID, ISSUE_REVISION, VSK_NAME, VSK_REVISION
            ) AND ETL_RUN_ID = p_etl_run_id;

        WHEN 'ESK_REFERENCES' THEN
            UPDATE STG_ESK_REFERENCES SET IS_DUPLICATE = 'Y'
            WHERE STG_ID NOT IN (
                SELECT MIN(STG_ID) FROM STG_ESK_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
                GROUP BY PLANT_ID, ISSUE_REVISION, ESK_NAME, ESK_REVISION
            ) AND ETL_RUN_ID = p_etl_run_id;

        WHEN 'SC_REFERENCES' THEN
            UPDATE STG_SC_REFERENCES SET IS_DUPLICATE = 'Y'
            WHERE STG_ID NOT IN (
                SELECT MIN(STG_ID) FROM STG_SC_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
                GROUP BY PLANT_ID, ISSUE_REVISION, SC_NAME, SC_REVISION
            ) AND ETL_RUN_ID = p_etl_run_id;

        WHEN 'VSM_REFERENCES' THEN
            UPDATE STG_VSM_REFERENCES SET IS_DUPLICATE = 'Y'
            WHERE STG_ID NOT IN (
                SELECT MIN(STG_ID) FROM STG_VSM_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
                GROUP BY PLANT_ID, ISSUE_REVISION, VSM_NAME, VSM_REVISION
            ) AND ETL_RUN_ID = p_etl_run_id;

        WHEN 'PIPE_ELEMENT_REFERENCES' THEN
            UPDATE STG_PIPE_ELEMENT_REFERENCES SET IS_DUPLICATE = 'Y'
            WHERE STG_ID NOT IN (
                SELECT MIN(STG_ID) FROM STG_PIPE_ELEMENT_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
                GROUP BY PLANT_ID, ISSUE_REVISION, ELEMENT_ID
            ) AND ETL_RUN_ID = p_etl_run_id;
                
        ELSE
            RAISE_APPLICATION_ERROR(-20002, 'Unknown entity type: ' || p_entity_type);
    END CASE;
END SP_DEDUPLICATE_STAGING;
/

-- =====================================================
-- STEP 13: CREATE ETL PACKAGES
-- =====================================================

-- OPERATORS ETL Package
CREATE OR REPLACE PACKAGE PKG_OPERATORS_ETL AS
    PROCEDURE VALIDATE(p_etl_run_id NUMBER);
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER);
    PROCEDURE RECONCILE(p_etl_run_id NUMBER);
END PKG_OPERATORS_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_OPERATORS_ETL AS
    
    PROCEDURE VALIDATE(p_etl_run_id NUMBER) AS
        v_invalid_count NUMBER;
    BEGIN
        -- Update validation status
        UPDATE STG_OPERATORS
        SET IS_VALID = CASE
                WHEN OPERATOR_ID IS NULL THEN 'N'
                WHEN LENGTH(OPERATOR_NAME) > 200 THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN OPERATOR_ID IS NULL THEN 'Missing OPERATOR_ID'
                WHEN LENGTH(OPERATOR_NAME) > 200 THEN 'Name exceeds 200 chars'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        SELECT COUNT(*) INTO v_invalid_count
        FROM STG_OPERATORS
        WHERE ETL_RUN_ID = p_etl_run_id AND IS_VALID = 'N';
        
        IF v_invalid_count > 0 THEN
            LOG_ETL_ERROR(p_etl_run_id, 'VALIDATE_OPERATORS', 'VALIDATION', 
                         v_invalid_count || ' records failed validation');
        END IF;
    END VALIDATE;
    
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER) AS
        v_new_count NUMBER := 0;
        v_updated_count NUMBER := 0;
        v_unchanged_count NUMBER := 0;
        v_deleted_count NUMBER := 0;
    BEGIN
        -- Step 1: Mark deleted records
        UPDATE OPERATORS
        SET IS_CURRENT = 'N',
            VALID_TO = SYSDATE,
            CHANGE_TYPE = 'DELETE',
            DELETE_DATE = SYSDATE,
            ETL_RUN_ID = p_etl_run_id
        WHERE IS_CURRENT = 'Y'
          AND OPERATOR_ID NOT IN (
              SELECT DISTINCT OPERATOR_ID
              FROM STG_OPERATORS
              WHERE ETL_RUN_ID = p_etl_run_id
                AND IS_VALID = 'Y' 
                AND IS_DUPLICATE = 'N'
          );
        
        v_deleted_count := SQL%ROWCOUNT;
        
        -- Step 2: Handle updates (expire current, insert new)
        FOR rec IN (
            SELECT s.OPERATOR_ID, s.OPERATOR_NAME
            FROM STG_OPERATORS s
            INNER JOIN OPERATORS d ON s.OPERATOR_ID = d.OPERATOR_ID AND d.IS_CURRENT = 'Y'
            WHERE s.ETL_RUN_ID = p_etl_run_id
              AND s.IS_VALID = 'Y' 
              AND s.IS_DUPLICATE = 'N'
              AND STANDARD_HASH(s.OPERATOR_NAME, 'SHA256') != d.SRC_HASH
        ) LOOP
            -- Expire current record
            UPDATE OPERATORS
            SET IS_CURRENT = 'N',
                VALID_TO = SYSDATE,
                CHANGE_TYPE = 'UPDATE',
                ETL_RUN_ID = p_etl_run_id
            WHERE OPERATOR_ID = rec.OPERATOR_ID
              AND IS_CURRENT = 'Y';
            
            -- Insert new version
            INSERT INTO OPERATORS (
                OPERATOR_ID, OPERATOR_NAME, SRC_HASH, VALID_FROM, VALID_TO,
                IS_CURRENT, CHANGE_TYPE, DELETE_DATE, ETL_RUN_ID
            ) VALUES (
                rec.OPERATOR_ID, rec.OPERATOR_NAME,
                STANDARD_HASH(rec.OPERATOR_NAME, 'SHA256'),
                SYSDATE, NULL, 'Y', 'UPDATE', NULL, p_etl_run_id
            );
            
            v_updated_count := v_updated_count + 1;
        END LOOP;
        
        -- Step 3: Handle inserts
        INSERT INTO OPERATORS (
            OPERATOR_ID, OPERATOR_NAME, SRC_HASH, VALID_FROM, VALID_TO,
            IS_CURRENT, CHANGE_TYPE, DELETE_DATE, ETL_RUN_ID
        )
        SELECT 
            s.OPERATOR_ID, s.OPERATOR_NAME,
            STANDARD_HASH(s.OPERATOR_NAME, 'SHA256'),
            SYSDATE, NULL, 'Y', 'INSERT', NULL, p_etl_run_id
        FROM STG_OPERATORS s
        LEFT JOIN OPERATORS d ON s.OPERATOR_ID = d.OPERATOR_ID AND d.IS_CURRENT = 'Y'
        WHERE s.ETL_RUN_ID = p_etl_run_id
          AND s.IS_VALID = 'Y' 
          AND s.IS_DUPLICATE = 'N'
          AND d.OPERATOR_ID IS NULL;
        
        v_new_count := SQL%ROWCOUNT;
        
        -- Count unchanged records
        SELECT COUNT(*) INTO v_unchanged_count
        FROM STG_OPERATORS s
        INNER JOIN OPERATORS d ON s.OPERATOR_ID = d.OPERATOR_ID AND d.IS_CURRENT = 'Y'
        WHERE s.ETL_RUN_ID = p_etl_run_id
          AND s.IS_VALID = 'Y' 
          AND s.IS_DUPLICATE = 'N'
          AND STANDARD_HASH(s.OPERATOR_NAME, 'SHA256') = d.SRC_HASH;
        
        -- Update ETL_CONTROL with counts
        UPDATE ETL_CONTROL
        SET RECORDS_LOADED = v_new_count,
            RECORDS_UPDATED = v_updated_count,
            RECORDS_UNCHANGED = v_unchanged_count,
            RECORDS_DELETED = v_deleted_count
        WHERE ETL_RUN_ID = p_etl_run_id;
    END PROCESS_SCD2;
    
    PROCEDURE RECONCILE(p_etl_run_id NUMBER) AS
        v_staging_count NUMBER;
        v_dimension_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_staging_count
        FROM STG_OPERATORS
        WHERE ETL_RUN_ID = p_etl_run_id AND IS_VALID = 'Y' AND IS_DUPLICATE = 'N';
        
        SELECT COUNT(*) INTO v_dimension_count
        FROM OPERATORS WHERE IS_CURRENT = 'Y';
        
        INSERT INTO ETL_RECONCILIATION (ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT)
        VALUES (p_etl_run_id, 'OPERATORS', v_staging_count, v_dimension_count, 
                ABS(v_staging_count - v_dimension_count));
    END RECONCILE;
    
END PKG_OPERATORS_ETL;
/

-- PLANTS ETL Package  
CREATE OR REPLACE PACKAGE PKG_PLANTS_ETL AS
    PROCEDURE VALIDATE(p_etl_run_id NUMBER);
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER);
    PROCEDURE RECONCILE(p_etl_run_id NUMBER);
END PKG_PLANTS_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_PLANTS_ETL AS
    
    PROCEDURE VALIDATE(p_etl_run_id NUMBER) AS
        v_invalid_count NUMBER;
    BEGIN
        UPDATE STG_PLANTS
        SET IS_VALID = CASE
                WHEN PLANT_ID IS NULL THEN 'N'
                WHEN LENGTH(SHORT_DESCRIPTION) > 200 THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN PLANT_ID IS NULL THEN 'Missing PLANT_ID'
                WHEN LENGTH(SHORT_DESCRIPTION) > 200 THEN 'Description too long'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        SELECT COUNT(*) INTO v_invalid_count
        FROM STG_PLANTS WHERE ETL_RUN_ID = p_etl_run_id AND IS_VALID = 'N';
        
        IF v_invalid_count > 0 THEN
            LOG_ETL_ERROR(p_etl_run_id, 'VALIDATE_PLANTS', 'VALIDATION', 
                         v_invalid_count || ' records failed validation');
        END IF;
    END VALIDATE;
    
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER) AS
        v_new_count NUMBER := 0;
        v_updated_count NUMBER := 0;
        v_unchanged_count NUMBER := 0;
        v_deleted_count NUMBER := 0;
    BEGIN
        -- Mark deleted records
        UPDATE PLANTS
        SET IS_CURRENT = 'N', VALID_TO = SYSDATE, CHANGE_TYPE = 'DELETE',
            DELETE_DATE = SYSDATE, ETL_RUN_ID = p_etl_run_id
        WHERE IS_CURRENT = 'Y'
          AND PLANT_ID NOT IN (
              SELECT DISTINCT PLANT_ID FROM STG_PLANTS
              WHERE ETL_RUN_ID = p_etl_run_id AND IS_VALID = 'Y' AND IS_DUPLICATE = 'N'
          );
        v_deleted_count := SQL%ROWCOUNT;
        
        -- Handle updates
        FOR rec IN (
            SELECT s.*
            FROM STG_PLANTS s
            INNER JOIN PLANTS d ON s.PLANT_ID = d.PLANT_ID AND d.IS_CURRENT = 'Y'
            WHERE s.ETL_RUN_ID = p_etl_run_id AND s.IS_VALID = 'Y' AND s.IS_DUPLICATE = 'N'
              AND STANDARD_HASH(
                  NVL(s.OPERATOR_ID,0)||'|'||NVL(s.OPERATOR_NAME,'')||'|'||
                  NVL(s.SHORT_DESCRIPTION,'')||'|'||NVL(s.PROJECT,'')||'|'||
                  NVL(s.LONG_DESCRIPTION,'')||'|'||NVL(s.COMMON_LIB_PLANT_CODE,'')||'|'||
                  NVL(s.INITIAL_REVISION,'')||'|'||NVL(s.AREA_ID,0)||'|'||
                  NVL(s.AREA,'')||'|'||NVL(s.ENABLE_EMBEDDED_NOTE,'')||'|'||
                  NVL(s.CATEGORY_ID,'')||'|'||NVL(s.CATEGORY,'')||'|'||
                  NVL(s.DOCUMENT_SPACE_LINK,'')||'|'||NVL(s.ENABLE_COPY_PCS_FROM_PLANT,'')||'|'||
                  NVL(s.OVER_LENGTH,'')||'|'||NVL(s.PCS_QA,'')||'|'||
                  NVL(s.EDS_MJ,'')||'|'||NVL(s.CELSIUS_BAR,'')||'|'||
                  NVL(s.VISIBLE,'')||'|'||NVL(s.USER_PROTECTED,''), 
                  'SHA256') != d.SRC_HASH
        ) LOOP
            -- Expire current
            UPDATE PLANTS
            SET IS_CURRENT = 'N', VALID_TO = SYSDATE, CHANGE_TYPE = 'UPDATE', ETL_RUN_ID = p_etl_run_id
            WHERE PLANT_ID = rec.PLANT_ID AND IS_CURRENT = 'Y';
            
            -- Insert new version with ALL enhanced fields
            INSERT INTO PLANTS (
                OPERATOR_ID, OPERATOR_NAME, PLANT_ID, SHORT_DESCRIPTION, PROJECT,
                LONG_DESCRIPTION, COMMON_LIB_PLANT_CODE, INITIAL_REVISION, 
                AREA_ID, AREA, ENABLE_EMBEDDED_NOTE, CATEGORY_ID, CATEGORY,
                DOCUMENT_SPACE_LINK, ENABLE_COPY_PCS_FROM_PLANT, OVER_LENGTH,
                PCS_QA, EDS_MJ, CELSIUS_BAR, WEB_INFO_TEXT, BOLT_TENSION_TEXT,
                VISIBLE, WINDOWS_REMARK_TEXT, USER_PROTECTED,
                SRC_HASH, VALID_FROM, VALID_TO, IS_CURRENT, CHANGE_TYPE, 
                DELETE_DATE, ETL_RUN_ID
            ) VALUES (
                rec.OPERATOR_ID, rec.OPERATOR_NAME, rec.PLANT_ID, rec.SHORT_DESCRIPTION, rec.PROJECT,
                rec.LONG_DESCRIPTION, rec.COMMON_LIB_PLANT_CODE, rec.INITIAL_REVISION,
                rec.AREA_ID, rec.AREA, rec.ENABLE_EMBEDDED_NOTE, rec.CATEGORY_ID, rec.CATEGORY,
                rec.DOCUMENT_SPACE_LINK, rec.ENABLE_COPY_PCS_FROM_PLANT, rec.OVER_LENGTH,
                rec.PCS_QA, rec.EDS_MJ, rec.CELSIUS_BAR, rec.WEB_INFO_TEXT, rec.BOLT_TENSION_TEXT,
                rec.VISIBLE, rec.WINDOWS_REMARK_TEXT, rec.USER_PROTECTED,
                STANDARD_HASH(
                    NVL(rec.OPERATOR_ID,0)||'|'||NVL(rec.OPERATOR_NAME,'')||'|'||
                    NVL(rec.SHORT_DESCRIPTION,'')||'|'||NVL(rec.PROJECT,'')||'|'||
                    NVL(rec.LONG_DESCRIPTION,'')||'|'||NVL(rec.COMMON_LIB_PLANT_CODE,'')||'|'||
                    NVL(rec.INITIAL_REVISION,'')||'|'||NVL(rec.AREA_ID,0)||'|'||
                    NVL(rec.AREA,'')||'|'||NVL(rec.ENABLE_EMBEDDED_NOTE,'')||'|'||
                    NVL(rec.CATEGORY_ID,'')||'|'||NVL(rec.CATEGORY,'')||'|'||
                    NVL(rec.DOCUMENT_SPACE_LINK,'')||'|'||NVL(rec.ENABLE_COPY_PCS_FROM_PLANT,'')||'|'||
                    NVL(rec.OVER_LENGTH,'')||'|'||NVL(rec.PCS_QA,'')||'|'||
                    NVL(rec.EDS_MJ,'')||'|'||NVL(rec.CELSIUS_BAR,'')||'|'||
                    NVL(rec.VISIBLE,'')||'|'||NVL(rec.USER_PROTECTED,''), 
                    'SHA256'),
                SYSDATE, NULL, 'Y', 'UPDATE', NULL, p_etl_run_id
            );
            v_updated_count := v_updated_count + 1;
        END LOOP;
        
        -- Handle inserts with ALL enhanced fields
        INSERT INTO PLANTS (
            OPERATOR_ID, OPERATOR_NAME, PLANT_ID, SHORT_DESCRIPTION, PROJECT,
            LONG_DESCRIPTION, COMMON_LIB_PLANT_CODE, INITIAL_REVISION, 
            AREA_ID, AREA, ENABLE_EMBEDDED_NOTE, CATEGORY_ID, CATEGORY,
            DOCUMENT_SPACE_LINK, ENABLE_COPY_PCS_FROM_PLANT, OVER_LENGTH,
            PCS_QA, EDS_MJ, CELSIUS_BAR, WEB_INFO_TEXT, BOLT_TENSION_TEXT,
            VISIBLE, WINDOWS_REMARK_TEXT, USER_PROTECTED,
            SRC_HASH, VALID_FROM, VALID_TO, IS_CURRENT, CHANGE_TYPE, 
            DELETE_DATE, ETL_RUN_ID
        )
        SELECT 
            s.OPERATOR_ID, s.OPERATOR_NAME, s.PLANT_ID, s.SHORT_DESCRIPTION, s.PROJECT,
            s.LONG_DESCRIPTION, s.COMMON_LIB_PLANT_CODE, s.INITIAL_REVISION,
            s.AREA_ID, s.AREA, s.ENABLE_EMBEDDED_NOTE, s.CATEGORY_ID, s.CATEGORY,
            s.DOCUMENT_SPACE_LINK, s.ENABLE_COPY_PCS_FROM_PLANT, s.OVER_LENGTH,
            s.PCS_QA, s.EDS_MJ, s.CELSIUS_BAR, s.WEB_INFO_TEXT, s.BOLT_TENSION_TEXT,
            s.VISIBLE, s.WINDOWS_REMARK_TEXT, s.USER_PROTECTED,
            STANDARD_HASH(
                NVL(s.OPERATOR_ID,0)||'|'||NVL(s.OPERATOR_NAME,'')||'|'||
                NVL(s.SHORT_DESCRIPTION,'')||'|'||NVL(s.PROJECT,'')||'|'||
                NVL(s.LONG_DESCRIPTION,'')||'|'||NVL(s.COMMON_LIB_PLANT_CODE,'')||'|'||
                NVL(s.INITIAL_REVISION,'')||'|'||NVL(s.AREA_ID,0)||'|'||
                NVL(s.AREA,'')||'|'||NVL(s.ENABLE_EMBEDDED_NOTE,'')||'|'||
                NVL(s.CATEGORY_ID,'')||'|'||NVL(s.CATEGORY,'')||'|'||
                NVL(s.DOCUMENT_SPACE_LINK,'')||'|'||NVL(s.ENABLE_COPY_PCS_FROM_PLANT,'')||'|'||
                NVL(s.OVER_LENGTH,'')||'|'||NVL(s.PCS_QA,'')||'|'||
                NVL(s.EDS_MJ,'')||'|'||NVL(s.CELSIUS_BAR,'')||'|'||
                NVL(s.VISIBLE,'')||'|'||NVL(s.USER_PROTECTED,''), 
                'SHA256'),
            SYSDATE, NULL, 'Y', 'INSERT', NULL, p_etl_run_id
        FROM STG_PLANTS s
        LEFT JOIN PLANTS d ON s.PLANT_ID = d.PLANT_ID AND d.IS_CURRENT = 'Y'
        WHERE s.ETL_RUN_ID = p_etl_run_id AND s.IS_VALID = 'Y' AND s.IS_DUPLICATE = 'N'
          AND d.PLANT_ID IS NULL;
        
        v_new_count := SQL%ROWCOUNT;
        
        -- Count unchanged
        SELECT COUNT(*) INTO v_unchanged_count
        FROM STG_PLANTS s
        INNER JOIN PLANTS d ON s.PLANT_ID = d.PLANT_ID AND d.IS_CURRENT = 'Y'
        WHERE s.ETL_RUN_ID = p_etl_run_id AND s.IS_VALID = 'Y' AND s.IS_DUPLICATE = 'N'
          AND STANDARD_HASH(
              NVL(s.OPERATOR_ID,0)||'|'||NVL(s.OPERATOR_NAME,'')||'|'||
              NVL(s.SHORT_DESCRIPTION,'')||'|'||NVL(s.PROJECT,'')||'|'||
              NVL(s.LONG_DESCRIPTION,'')||'|'||NVL(s.COMMON_LIB_PLANT_CODE,'')||'|'||
              NVL(s.INITIAL_REVISION,'')||'|'||NVL(s.AREA_ID,0)||'|'||
              NVL(s.AREA,'')||'|'||NVL(s.ENABLE_EMBEDDED_NOTE,'')||'|'||
              NVL(s.CATEGORY_ID,'')||'|'||NVL(s.CATEGORY,'')||'|'||
              NVL(s.DOCUMENT_SPACE_LINK,'')||'|'||NVL(s.ENABLE_COPY_PCS_FROM_PLANT,'')||'|'||
              NVL(s.OVER_LENGTH,'')||'|'||NVL(s.PCS_QA,'')||'|'||
              NVL(s.EDS_MJ,'')||'|'||NVL(s.CELSIUS_BAR,'')||'|'||
              NVL(s.VISIBLE,'')||'|'||NVL(s.USER_PROTECTED,''), 
              'SHA256') = d.SRC_HASH;
        
        UPDATE ETL_CONTROL
        SET RECORDS_LOADED = v_new_count,
            RECORDS_UPDATED = v_updated_count,
            RECORDS_UNCHANGED = v_unchanged_count,
            RECORDS_DELETED = v_deleted_count
        WHERE ETL_RUN_ID = p_etl_run_id;
    END PROCESS_SCD2;
    
    PROCEDURE RECONCILE(p_etl_run_id NUMBER) AS
        v_staging_count NUMBER;
        v_dimension_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_staging_count
        FROM STG_PLANTS WHERE ETL_RUN_ID = p_etl_run_id AND IS_VALID = 'Y' AND IS_DUPLICATE = 'N';
        
        SELECT COUNT(*) INTO v_dimension_count FROM PLANTS WHERE IS_CURRENT = 'Y';
        
        INSERT INTO ETL_RECONCILIATION (ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT)
        VALUES (p_etl_run_id, 'PLANTS', v_staging_count, v_dimension_count, 
                ABS(v_staging_count - v_dimension_count));
    END RECONCILE;
    
END PKG_PLANTS_ETL;
/

-- ISSUES ETL Package (needed for cascade deletions)
CREATE OR REPLACE PACKAGE PKG_ISSUES_ETL AS
    PROCEDURE VALIDATE(p_etl_run_id NUMBER);
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER);
    PROCEDURE RECONCILE(p_etl_run_id NUMBER);
END PKG_ISSUES_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_ISSUES_ETL AS
    
    PROCEDURE VALIDATE(p_etl_run_id NUMBER) AS
        v_invalid_count NUMBER;
    BEGIN
        UPDATE STG_ISSUES
        SET IS_VALID = CASE
                WHEN PLANT_ID IS NULL OR ISSUE_REVISION IS NULL THEN 'N'
                WHEN LENGTH(ISSUE_REVISION) > 20 THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN PLANT_ID IS NULL THEN 'Missing PLANT_ID'
                WHEN ISSUE_REVISION IS NULL THEN 'Missing ISSUE_REVISION'
                WHEN LENGTH(ISSUE_REVISION) > 20 THEN 'Revision too long'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        SELECT COUNT(*) INTO v_invalid_count
        FROM STG_ISSUES WHERE ETL_RUN_ID = p_etl_run_id AND IS_VALID = 'N';
        
        IF v_invalid_count > 0 THEN
            LOG_ETL_ERROR(p_etl_run_id, 'VALIDATE_ISSUES', 'VALIDATION', 
                         v_invalid_count || ' records failed validation');
        END IF;
    END VALIDATE;
    
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER) AS
        v_new_count NUMBER := 0;
        v_updated_count NUMBER := 0;
        v_unchanged_count NUMBER := 0;
        v_deleted_count NUMBER := 0;
    BEGIN
        -- Step 1: Cascade deletion - mark issues deleted for plants NOT in loader
        UPDATE ISSUES
        SET IS_CURRENT = 'N', VALID_TO = SYSDATE, CHANGE_TYPE = 'DELETE',
            DELETE_DATE = SYSDATE, ETL_RUN_ID = p_etl_run_id
        WHERE IS_CURRENT = 'Y'
          AND PLANT_ID NOT IN (SELECT PLANT_ID FROM ETL_PLANT_LOADER);
        
        v_deleted_count := SQL%ROWCOUNT;
        
        -- Step 2: Mark deleted records (missing from API)
        UPDATE ISSUES
        SET IS_CURRENT = 'N', VALID_TO = SYSDATE, CHANGE_TYPE = 'DELETE',
            DELETE_DATE = SYSDATE, ETL_RUN_ID = p_etl_run_id
        WHERE IS_CURRENT = 'Y'
          AND PLANT_ID IN (SELECT PLANT_ID FROM ETL_PLANT_LOADER)
          AND (PLANT_ID, ISSUE_REVISION) NOT IN (
              SELECT DISTINCT PLANT_ID, ISSUE_REVISION FROM STG_ISSUES
              WHERE ETL_RUN_ID = p_etl_run_id AND IS_VALID = 'Y' AND IS_DUPLICATE = 'N'
          );
        
        v_deleted_count := v_deleted_count + SQL%ROWCOUNT;
        
        -- Step 3: Handle updates with ALL enhanced fields
        FOR rec IN (
            SELECT s.*
            FROM STG_ISSUES s
            INNER JOIN ISSUES d ON s.PLANT_ID = d.PLANT_ID AND s.ISSUE_REVISION = d.ISSUE_REVISION 
                AND d.IS_CURRENT = 'Y'
            WHERE s.ETL_RUN_ID = p_etl_run_id AND s.IS_VALID = 'Y' AND s.IS_DUPLICATE = 'N'
              AND STANDARD_HASH(
                  NVL(s.STATUS,'')||'|'||NVL(s.REV_DATE,'')||'|'||NVL(s.PROTECT_STATUS,'')||'|'||
                  NVL(s.GENERAL_REVISION,'')||'|'||NVL(s.GENERAL_REV_DATE,'')||'|'||
                  NVL(s.PCS_REVISION,'')||'|'||NVL(s.PCS_REV_DATE,'')||'|'||
                  NVL(s.EDS_REVISION,'')||'|'||NVL(s.EDS_REV_DATE,'')||'|'||
                  NVL(s.VDS_REVISION,'')||'|'||NVL(s.VDS_REV_DATE,'')||'|'||
                  NVL(s.VSK_REVISION,'')||'|'||NVL(s.VSK_REV_DATE,'')||'|'||
                  NVL(s.MDS_REVISION,'')||'|'||NVL(s.MDS_REV_DATE,'')||'|'||
                  NVL(s.ESK_REVISION,'')||'|'||NVL(s.ESK_REV_DATE,'')||'|'||
                  NVL(s.SC_REVISION,'')||'|'||NVL(s.SC_REV_DATE,'')||'|'||
                  NVL(s.VSM_REVISION,'')||'|'||NVL(s.VSM_REV_DATE,'')||'|'||
                  NVL(s.USER_NAME,'')||'|'||NVL(s.USER_ENTRY_TIME,'')||'|'||
                  NVL(s.USER_PROTECTED,''), 
                  'SHA256') != d.SRC_HASH
        ) LOOP
            -- Expire current
            UPDATE ISSUES
            SET IS_CURRENT = 'N', VALID_TO = SYSDATE, CHANGE_TYPE = 'UPDATE', ETL_RUN_ID = p_etl_run_id
            WHERE PLANT_ID = rec.PLANT_ID AND ISSUE_REVISION = rec.ISSUE_REVISION AND IS_CURRENT = 'Y';
            
            -- Insert new version with ALL enhanced fields
            INSERT INTO ISSUES (
                PLANT_ID, ISSUE_REVISION, STATUS, REV_DATE, PROTECT_STATUS,
                GENERAL_REVISION, GENERAL_REV_DATE, PCS_REVISION, PCS_REV_DATE,
                EDS_REVISION, EDS_REV_DATE, VDS_REVISION, VDS_REV_DATE,
                VSK_REVISION, VSK_REV_DATE, MDS_REVISION, MDS_REV_DATE,
                ESK_REVISION, ESK_REV_DATE, SC_REVISION, SC_REV_DATE,
                VSM_REVISION, VSM_REV_DATE, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
                SRC_HASH, VALID_FROM, VALID_TO, IS_CURRENT, CHANGE_TYPE, DELETE_DATE, ETL_RUN_ID
            ) VALUES (
                rec.PLANT_ID, rec.ISSUE_REVISION, rec.STATUS, 
                PARSE_TR2000_DATE(rec.REV_DATE),
                rec.PROTECT_STATUS,
                rec.GENERAL_REVISION, 
                PARSE_TR2000_DATE(rec.GENERAL_REV_DATE),
                rec.PCS_REVISION,
                PARSE_TR2000_DATE(rec.PCS_REV_DATE),
                rec.EDS_REVISION,
                PARSE_TR2000_DATE(rec.EDS_REV_DATE),
                rec.VDS_REVISION,
                PARSE_TR2000_DATE(rec.VDS_REV_DATE),
                rec.VSK_REVISION,
                PARSE_TR2000_DATE(rec.VSK_REV_DATE),
                rec.MDS_REVISION,
                PARSE_TR2000_DATE(rec.MDS_REV_DATE),
                rec.ESK_REVISION,
                PARSE_TR2000_DATE(rec.ESK_REV_DATE),
                rec.SC_REVISION,
                PARSE_TR2000_DATE(rec.SC_REV_DATE),
                rec.VSM_REVISION,
                PARSE_TR2000_DATE(rec.VSM_REV_DATE),
                rec.USER_NAME,
                PARSE_TR2000_DATE(rec.USER_ENTRY_TIME),
                rec.USER_PROTECTED,
                STANDARD_HASH(
                    NVL(rec.STATUS,'')||'|'||NVL(rec.REV_DATE,'')||'|'||NVL(rec.PROTECT_STATUS,'')||'|'||
                    NVL(rec.GENERAL_REVISION,'')||'|'||NVL(rec.GENERAL_REV_DATE,'')||'|'||
                    NVL(rec.PCS_REVISION,'')||'|'||NVL(rec.PCS_REV_DATE,'')||'|'||
                    NVL(rec.EDS_REVISION,'')||'|'||NVL(rec.EDS_REV_DATE,'')||'|'||
                    NVL(rec.VDS_REVISION,'')||'|'||NVL(rec.VDS_REV_DATE,'')||'|'||
                    NVL(rec.VSK_REVISION,'')||'|'||NVL(rec.VSK_REV_DATE,'')||'|'||
                    NVL(rec.MDS_REVISION,'')||'|'||NVL(rec.MDS_REV_DATE,'')||'|'||
                    NVL(rec.ESK_REVISION,'')||'|'||NVL(rec.ESK_REV_DATE,'')||'|'||
                    NVL(rec.SC_REVISION,'')||'|'||NVL(rec.SC_REV_DATE,'')||'|'||
                    NVL(rec.VSM_REVISION,'')||'|'||NVL(rec.VSM_REV_DATE,'')||'|'||
                    NVL(rec.USER_NAME,'')||'|'||NVL(rec.USER_ENTRY_TIME,'')||'|'||
                    NVL(rec.USER_PROTECTED,''), 
                    'SHA256'),
                SYSDATE, NULL, 'Y', 'UPDATE', NULL, p_etl_run_id
            );
            v_updated_count := v_updated_count + 1;
        END LOOP;
        
        -- Step 4: Handle inserts with ALL enhanced fields
        INSERT INTO ISSUES (
            PLANT_ID, ISSUE_REVISION, STATUS, REV_DATE, PROTECT_STATUS,
            GENERAL_REVISION, GENERAL_REV_DATE, PCS_REVISION, PCS_REV_DATE,
            EDS_REVISION, EDS_REV_DATE, VDS_REVISION, VDS_REV_DATE,
            VSK_REVISION, VSK_REV_DATE, MDS_REVISION, MDS_REV_DATE,
            ESK_REVISION, ESK_REV_DATE, SC_REVISION, SC_REV_DATE,
            VSM_REVISION, VSM_REV_DATE, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
            SRC_HASH, VALID_FROM, VALID_TO, IS_CURRENT, CHANGE_TYPE, DELETE_DATE, ETL_RUN_ID
        )
        SELECT 
            s.PLANT_ID, s.ISSUE_REVISION, s.STATUS, 
            PARSE_TR2000_DATE(s.REV_DATE),
            s.PROTECT_STATUS,
            s.GENERAL_REVISION,
            PARSE_TR2000_DATE(s.GENERAL_REV_DATE),
            s.PCS_REVISION,
            PARSE_TR2000_DATE(s.PCS_REV_DATE),
            s.EDS_REVISION,
            PARSE_TR2000_DATE(s.EDS_REV_DATE),
            s.VDS_REVISION,
            PARSE_TR2000_DATE(s.VDS_REV_DATE),
            s.VSK_REVISION,
            PARSE_TR2000_DATE(s.VSK_REV_DATE),
            s.MDS_REVISION,
            PARSE_TR2000_DATE(s.MDS_REV_DATE),
            s.ESK_REVISION,
            PARSE_TR2000_DATE(s.ESK_REV_DATE),
            s.SC_REVISION,
            PARSE_TR2000_DATE(s.SC_REV_DATE),
            s.VSM_REVISION,
            PARSE_TR2000_DATE(s.VSM_REV_DATE),
            s.USER_NAME,
            PARSE_TR2000_DATE(s.USER_ENTRY_TIME),
            s.USER_PROTECTED,
            STANDARD_HASH(
                NVL(s.STATUS,'')||'|'||NVL(s.REV_DATE,'')||'|'||NVL(s.PROTECT_STATUS,'')||'|'||
                NVL(s.GENERAL_REVISION,'')||'|'||NVL(s.GENERAL_REV_DATE,'')||'|'||
                NVL(s.PCS_REVISION,'')||'|'||NVL(s.PCS_REV_DATE,'')||'|'||
                NVL(s.EDS_REVISION,'')||'|'||NVL(s.EDS_REV_DATE,'')||'|'||
                NVL(s.VDS_REVISION,'')||'|'||NVL(s.VDS_REV_DATE,'')||'|'||
                NVL(s.VSK_REVISION,'')||'|'||NVL(s.VSK_REV_DATE,'')||'|'||
                NVL(s.MDS_REVISION,'')||'|'||NVL(s.MDS_REV_DATE,'')||'|'||
                NVL(s.ESK_REVISION,'')||'|'||NVL(s.ESK_REV_DATE,'')||'|'||
                NVL(s.SC_REVISION,'')||'|'||NVL(s.SC_REV_DATE,'')||'|'||
                NVL(s.VSM_REVISION,'')||'|'||NVL(s.VSM_REV_DATE,'')||'|'||
                NVL(s.USER_NAME,'')||'|'||NVL(s.USER_ENTRY_TIME,'')||'|'||
                NVL(s.USER_PROTECTED,''), 
                'SHA256'),
            SYSDATE, NULL, 'Y', 'INSERT', NULL, p_etl_run_id
        FROM STG_ISSUES s
        LEFT JOIN ISSUES d ON s.PLANT_ID = d.PLANT_ID AND s.ISSUE_REVISION = d.ISSUE_REVISION 
            AND d.IS_CURRENT = 'Y'
        WHERE s.ETL_RUN_ID = p_etl_run_id AND s.IS_VALID = 'Y' AND s.IS_DUPLICATE = 'N'
          AND d.PLANT_ID IS NULL;
        
        v_new_count := SQL%ROWCOUNT;
        
        -- Count unchanged
        SELECT COUNT(*) INTO v_unchanged_count
        FROM STG_ISSUES s
        INNER JOIN ISSUES d ON s.PLANT_ID = d.PLANT_ID AND s.ISSUE_REVISION = d.ISSUE_REVISION 
            AND d.IS_CURRENT = 'Y'
        WHERE s.ETL_RUN_ID = p_etl_run_id AND s.IS_VALID = 'Y' AND s.IS_DUPLICATE = 'N'
          AND STANDARD_HASH(
              NVL(s.STATUS,'')||'|'||NVL(s.REV_DATE,'')||'|'||NVL(s.PROTECT_STATUS,'')||'|'||
              NVL(s.GENERAL_REVISION,'')||'|'||NVL(s.GENERAL_REV_DATE,'')||'|'||
              NVL(s.PCS_REVISION,'')||'|'||NVL(s.PCS_REV_DATE,'')||'|'||
              NVL(s.EDS_REVISION,'')||'|'||NVL(s.EDS_REV_DATE,'')||'|'||
              NVL(s.VDS_REVISION,'')||'|'||NVL(s.VDS_REV_DATE,'')||'|'||
              NVL(s.VSK_REVISION,'')||'|'||NVL(s.VSK_REV_DATE,'')||'|'||
              NVL(s.MDS_REVISION,'')||'|'||NVL(s.MDS_REV_DATE,'')||'|'||
              NVL(s.ESK_REVISION,'')||'|'||NVL(s.ESK_REV_DATE,'')||'|'||
              NVL(s.SC_REVISION,'')||'|'||NVL(s.SC_REV_DATE,'')||'|'||
              NVL(s.VSM_REVISION,'')||'|'||NVL(s.VSM_REV_DATE,'')||'|'||
              NVL(s.USER_NAME,'')||'|'||NVL(s.USER_ENTRY_TIME,'')||'|'||
              NVL(s.USER_PROTECTED,''), 
              'SHA256') = d.SRC_HASH;
        
        UPDATE ETL_CONTROL
        SET RECORDS_LOADED = v_new_count,
            RECORDS_UPDATED = v_updated_count,
            RECORDS_UNCHANGED = v_unchanged_count,
            RECORDS_DELETED = v_deleted_count
        WHERE ETL_RUN_ID = p_etl_run_id;
    END PROCESS_SCD2;
    
    PROCEDURE RECONCILE(p_etl_run_id NUMBER) AS
        v_staging_count NUMBER;
        v_dimension_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_staging_count
        FROM STG_ISSUES WHERE ETL_RUN_ID = p_etl_run_id AND IS_VALID = 'Y' AND IS_DUPLICATE = 'N';
        
        SELECT COUNT(*) INTO v_dimension_count FROM ISSUES WHERE IS_CURRENT = 'Y';
        
        INSERT INTO ETL_RECONCILIATION (ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT)
        VALUES (p_etl_run_id, 'ISSUES', v_staging_count, v_dimension_count, 
                ABS(v_staging_count - v_dimension_count));
    END RECONCILE;
    
END PKG_ISSUES_ETL;
/

-- Master ETL Orchestrator
CREATE OR REPLACE PROCEDURE SP_PROCESS_ETL_BATCH(
    p_etl_run_id IN NUMBER,
    p_entity_type IN VARCHAR2
) AS
    v_step VARCHAR2(100);
    v_start_time DATE;
    v_end_time DATE;
    v_processing_seconds NUMBER;
BEGIN
    v_start_time := SYSDATE;
    
    -- Step 0: Parse RAW_JSON to STG_TABLES (NEW INDUSTRY-STANDARD STEP)
    v_step := 'RAW_JSON_PARSING';
    CASE p_entity_type
        WHEN 'OPERATORS' THEN
            SP_PARSE_OPERATORS_FROM_RAW_JSON(p_etl_run_id);
        WHEN 'PLANTS' THEN
            SP_PARSE_PLANTS_FROM_RAW_JSON(p_etl_run_id);
        WHEN 'ISSUES' THEN
            SP_PARSE_ISSUES_FROM_RAW_JSON(p_etl_run_id);
        ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Unknown entity type: ' || p_entity_type);
    END CASE;
    
    -- Step 1: Deduplication
    v_step := 'DEDUPLICATION';
    SP_DEDUPLICATE_STAGING(p_etl_run_id, p_entity_type);
    
    -- Step 2-4: Entity-specific processing
    v_step := 'ENTITY_PROCESSING';
    CASE p_entity_type
        WHEN 'OPERATORS' THEN
            PKG_OPERATORS_ETL.VALIDATE(p_etl_run_id);
            PKG_OPERATORS_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_OPERATORS_ETL.RECONCILE(p_etl_run_id);
            
        WHEN 'PLANTS' THEN
            PKG_PLANTS_ETL.VALIDATE(p_etl_run_id);
            PKG_PLANTS_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_PLANTS_ETL.RECONCILE(p_etl_run_id);
            
        WHEN 'ISSUES' THEN
            PKG_ISSUES_ETL.VALIDATE(p_etl_run_id);
            PKG_ISSUES_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_ISSUES_ETL.RECONCILE(p_etl_run_id);
            
        ELSE
            RAISE_APPLICATION_ERROR(-20003, 'Unsupported entity type: ' || p_entity_type);
    END CASE;
    
    -- Step 5: Cleanup (best effort)
    BEGIN
        v_step := 'CLEANUP';
        SP_PURGE_RAW_JSON();
        
        DELETE FROM ETL_CONTROL 
        WHERE ETL_RUN_ID NOT IN (
            SELECT ETL_RUN_ID FROM (
                SELECT ETL_RUN_ID, ROW_NUMBER() OVER (ORDER BY ETL_RUN_ID DESC) as rn
                FROM ETL_CONTROL
            ) WHERE rn <= 10
        );
        
        DELETE FROM ETL_ERROR_LOG WHERE ERROR_TIME < SYSDATE - 30;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Cleanup failures don't break ETL
            LOG_ETL_ERROR(p_etl_run_id, 'CLEANUP', SQLCODE, SQLERRM);
    END;
    
    -- Step 6: Final commit and timing
    v_end_time := SYSDATE;
    v_processing_seconds := ROUND((v_end_time - v_start_time) * 86400, 2);
    
    UPDATE ETL_CONTROL
    SET STATUS = 'SUCCESS',
        END_TIME = v_end_time,
        PROCESSING_TIME_SEC = v_processing_seconds
    WHERE ETL_RUN_ID = p_etl_run_id;
    
    COMMIT;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        
        LOG_ETL_ERROR(p_etl_run_id, 'SP_PROCESS_ETL_BATCH:' || v_step, SQLCODE, SQLERRM);
        
        UPDATE ETL_CONTROL
        SET STATUS = 'FAILED',
            END_TIME = SYSDATE,
            PROCESSING_TIME_SEC = ROUND((SYSDATE - v_start_time) * 86400, 2)
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        COMMIT;
        RAISE;
END SP_PROCESS_ETL_BATCH;
/

COMMIT;

PROMPT '===================================================='
PROMPT 'COMPLETE MASTER DDL DEPLOYMENT FINISHED'
PROMPT '===================================================='
PROMPT 'Infrastructure Created:'
PROMPT '- Enhanced table structures with complete field coverage'
PROMPT '- PLANTS: 24+ fields (Project, Area, Category, PCS_QA, etc.)'
PROMPT '- ISSUES: 25+ fields (complete revision matrix + user audit)'
PROMPT '- Enhanced Reference Tables: RevDate, Status, OfficialRevision'
PROMPT '- NEW PCS Detail Tables: Header, Temp/Pressure, Pipe Sizes, Elements'
PROMPT '- RAW_JSON audit trail with compression'
PROMPT '- Performance indexes for current record lookups'
PROMPT '- Utility views and procedures'
PROMPT '- Error logging and deduplication infrastructure'
PROMPT '- ALL STORED PROCEDURES AND PACKAGES'
PROMPT '- SP_PROCESS_ETL_BATCH master orchestrator'
PROMPT '- PKG_OPERATORS_ETL and PKG_PLANTS_ETL packages'
PROMPT ''
PROMPT 'SYSTEM IS NOW FULLY FUNCTIONAL:'
PROMPT '1. Enhanced table structures deployed'
PROMPT '2. All stored procedures and packages created'
PROMPT '3. Ready for complete C# ETL testing'
PROMPT '4. LoadOperators and LoadPlants should now work'
PROMPT ''
PROMPT 'SUCCESS: Master DDL Script is now complete and self-sufficient!'
PROMPT '===================================================='