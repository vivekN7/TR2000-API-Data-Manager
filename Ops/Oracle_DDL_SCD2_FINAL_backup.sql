-- =====================================================
-- TR2000 STAGING DATABASE - PRODUCTION-READY SCD2
-- Database: Oracle 21c Express Edition
-- Schema: TR2000_STAGING  
-- Version: FINAL - Complete SCD2 with All Production Improvements + Issue Loader
-- Updated: 2025-08-17 (Session 15)
-- 
-- This DDL implements PRODUCTION-READY SCD Type 2 with:
-- - Complete CRUD coverage (INSERT, UPDATE, DELETE, REACTIVATE)
-- - Oracle-centric architecture (all logic in DB)
-- - Atomic transactions with single COMMIT
-- - Autonomous error logging (survives rollbacks)
-- - Deterministic deduplication with STG_ID
-- - Minimal RAW_JSON with compression
-- - RBAC security model
-- - Performance optimized with set-based operations
-- - ETL_ISSUE_LOADER for reference table scope control
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
-- Simplified: If issue is in table, load its references. If not, don't.
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
-- STEP 4: CREATE STAGING TABLES WITH IMPROVED STRUCTURE
-- =====================================================

-- Staging for Operators (with dedup/validation columns)
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

-- Staging for Plants
CREATE TABLE STG_PLANTS (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    LONG_DESCRIPTION   VARCHAR2(500),
    OPERATOR_ID        NUMBER,
    COMMON_LIB_PLANT_CODE VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Staging for Issues
CREATE TABLE STG_ISSUES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Staging for PCS References
CREATE TABLE STG_PCS_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    PCS_NAME           VARCHAR2(100),
    PCS_REVISION       VARCHAR2(20),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Staging for SC References
CREATE TABLE STG_SC_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    SC_NAME            VARCHAR2(100),
    SC_REVISION        VARCHAR2(20),
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

-- Staging for VSM References
CREATE TABLE STG_VSM_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VSM_NAME           VARCHAR2(100),
    VSM_REVISION       VARCHAR2(20),
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

-- Staging for VDS References
CREATE TABLE STG_VDS_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VDS_NAME           VARCHAR2(100),
    VDS_REVISION       VARCHAR2(20),
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

-- Staging for EDS References
CREATE TABLE STG_EDS_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    EDS_NAME           VARCHAR2(100),
    EDS_REVISION       VARCHAR2(20),
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

-- Staging for MDS References
CREATE TABLE STG_MDS_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    MDS_NAME           VARCHAR2(100),
    MDS_REVISION       VARCHAR2(20),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    AREA               VARCHAR2(50),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- Staging for VSK References
CREATE TABLE STG_VSK_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VSK_NAME           VARCHAR2(100),
    VSK_REVISION       VARCHAR2(20),
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

-- Staging for ESK References
CREATE TABLE STG_ESK_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    ESK_NAME           VARCHAR2(100),
    ESK_REVISION       VARCHAR2(20),
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

-- Staging for Pipe Element References
CREATE TABLE STG_PIPE_ELEMENT_REFERENCES (
    STG_ID             NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    TAG_NO             VARCHAR2(100),
    ELEMENT_TYPE       VARCHAR2(50),
    ELEMENT_SIZE       VARCHAR2(50),
    RATING             VARCHAR2(50),
    MATERIAL           VARCHAR2(100),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    IS_DUPLICATE       CHAR(1) DEFAULT 'N',
    IS_VALID           CHAR(1) DEFAULT 'Y',
    VALIDATION_ERROR   VARCHAR2(500),
    PROCESSED_FLAG     CHAR(1) DEFAULT 'N'
);

-- =====================================================
-- STEP 5: CREATE DIMENSION TABLES (COMPLETE SCD2)
-- =====================================================

-- OPERATORS Dimension (Full SCD2 with audit)
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

-- PLANTS Dimension (Full SCD2 with audit)
CREATE TABLE PLANTS (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    LONG_DESCRIPTION   VARCHAR2(500),
    OPERATOR_ID        NUMBER,
    COMMON_LIB_PLANT_CODE VARCHAR2(20),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CHANGE_TYPE        VARCHAR2(20),
    DELETE_DATE        DATE,
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_PLANTS PRIMARY KEY (PLANT_ID, VALID_FROM)
);

-- ISSUES Dimension (Full SCD2 with audit)
CREATE TABLE ISSUES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
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
    CONSTRAINT PK_ISSUES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VALID_FROM)
);

-- PCS_REFERENCES Dimension (Full SCD2 with audit)
CREATE TABLE PCS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    PCS_NAME           VARCHAR2(100),
    PCS_REVISION       VARCHAR2(20),
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

-- SC_REFERENCES Dimension (Full SCD2 with audit)
CREATE TABLE SC_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    SC_NAME            VARCHAR2(100),
    SC_REVISION        VARCHAR2(20),
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

-- VSM_REFERENCES Dimension (Full SCD2 with audit)
CREATE TABLE VSM_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VSM_NAME           VARCHAR2(100),
    VSM_REVISION       VARCHAR2(20),
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

-- VDS_REFERENCES Dimension (Full SCD2 with audit)
CREATE TABLE VDS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VDS_NAME           VARCHAR2(100),
    VDS_REVISION       VARCHAR2(20),
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

-- EDS_REFERENCES Dimension (Full SCD2 with audit)
CREATE TABLE EDS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    EDS_NAME           VARCHAR2(100),
    EDS_REVISION       VARCHAR2(20),
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

-- MDS_REFERENCES Dimension (Full SCD2 with audit)
CREATE TABLE MDS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    MDS_NAME           VARCHAR2(100),
    MDS_REVISION       VARCHAR2(20),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(50),
    AREA               VARCHAR2(50),
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

-- VSK_REFERENCES Dimension (Full SCD2 with audit)
CREATE TABLE VSK_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VSK_NAME           VARCHAR2(100),
    VSK_REVISION       VARCHAR2(20),
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

-- ESK_REFERENCES Dimension (Full SCD2 with audit)
CREATE TABLE ESK_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    ESK_NAME           VARCHAR2(100),
    ESK_REVISION       VARCHAR2(20),
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

-- PIPE_ELEMENT_REFERENCES Dimension (Full SCD2 with audit)
CREATE TABLE PIPE_ELEMENT_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    TAG_NO             VARCHAR2(100),
    ELEMENT_TYPE       VARCHAR2(50),
    ELEMENT_SIZE       VARCHAR2(50),
    RATING             VARCHAR2(50),
    MATERIAL           VARCHAR2(100),
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
    CONSTRAINT PK_PIPE_ELEMENT_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, TAG_NO, VALID_FROM)
);

-- =====================================================
-- STEP 6: CREATE RAW_JSON TABLE (Phase 1 - No privileges required)
-- =====================================================

CREATE TABLE RAW_JSON (
    ID              NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    ENDPOINT        VARCHAR2(200) NOT NULL,
    KEY_FINGERPRINT RAW(32)       NOT NULL,
    ETL_RUN_ID      NUMBER        NOT NULL,
    LOAD_TS         DATE          DEFAULT SYSDATE NOT NULL,
    HTTP_STATUS     NUMBER,
    DURATION_MS     NUMBER,
    HEADERS_JSON    CLOB CHECK (HEADERS_JSON IS JSON),
    PAYLOAD         CLOB CHECK (PAYLOAD IS JSON)
)
LOB (HEADERS_JSON) STORE AS SECUREFILE (COMPRESS MEDIUM DEDUPLICATE)
LOB (PAYLOAD) STORE AS SECUREFILE (COMPRESS MEDIUM DEDUPLICATE);

-- Unique constraint to prevent duplicates
ALTER TABLE RAW_JSON ADD CONSTRAINT UK_RAWJSON 
    UNIQUE (ENDPOINT, KEY_FINGERPRINT, ETL_RUN_ID);

-- Purge procedure (no scheduler needed!)
CREATE OR REPLACE PROCEDURE SP_PURGE_RAW_JSON(
    p_days IN PLS_INTEGER DEFAULT 30
) AS
    v_deleted_count NUMBER;
BEGIN
    DELETE /*+ INDEX(RAW_JSON IX_RAWJSON_TS) */
    FROM RAW_JSON
    WHERE LOAD_TS < SYSDATE - p_days;
    
    v_deleted_count := SQL%ROWCOUNT;
    
    IF v_deleted_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Purged ' || v_deleted_count || ' RAW_JSON records older than ' || p_days || ' days');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('RAW_JSON purge error (non-critical): ' || SQLERRM);
END SP_PURGE_RAW_JSON;
/

-- Helper for C# inserts
CREATE OR REPLACE PROCEDURE SP_INSERT_RAW_JSON(
    p_endpoint      VARCHAR2,
    p_key_string    VARCHAR2,
    p_etl_run_id    NUMBER,
    p_http_status   NUMBER,
    p_duration_ms   NUMBER,
    p_headers_json  CLOB,
    p_payload       CLOB
) AS
BEGIN
    INSERT INTO RAW_JSON (
        ENDPOINT, KEY_FINGERPRINT, ETL_RUN_ID, 
        HTTP_STATUS, DURATION_MS, HEADERS_JSON, PAYLOAD
    ) VALUES (
        p_endpoint,
        STANDARD_HASH(p_key_string, 'SHA256'),
        p_etl_run_id,
        p_http_status,
        p_duration_ms,
        p_headers_json,
        p_payload
    );
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        NULL; -- Duplicate - ignore
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('RAW_JSON insert error: ' || SQLERRM);
END SP_INSERT_RAW_JSON;
/

-- =====================================================
-- STEP 7: CREATE PERFORMANCE INDEXES
-- =====================================================

-- Current record lookups
CREATE INDEX IX_OPERATORS_CURRENT ON OPERATORS(OPERATOR_ID, IS_CURRENT);
CREATE INDEX IX_PLANTS_CURRENT ON PLANTS(PLANT_ID, IS_CURRENT);
CREATE INDEX IX_ISSUES_CURRENT ON ISSUES(PLANT_ID, ISSUE_REVISION, IS_CURRENT);
CREATE INDEX IX_PCS_REF_CURRENT ON PCS_REFERENCES(PLANT_ID, ISSUE_REVISION, IS_CURRENT);
CREATE INDEX IX_SC_REF_CURRENT ON SC_REFERENCES(PLANT_ID, ISSUE_REVISION, IS_CURRENT);
CREATE INDEX IX_VSM_REF_CURRENT ON VSM_REFERENCES(PLANT_ID, ISSUE_REVISION, IS_CURRENT);

-- Temporal queries (commented out as PK already includes these columns)
-- CREATE INDEX IX_OPERATORS_TEMPORAL ON OPERATORS(OPERATOR_ID, VALID_FROM);
-- CREATE INDEX IX_PLANTS_TEMPORAL ON PLANTS(PLANT_ID, VALID_FROM);
-- CREATE INDEX IX_ISSUES_TEMPORAL ON ISSUES(PLANT_ID, ISSUE_REVISION, VALID_FROM);

-- Audit queries
CREATE INDEX IX_OPERATORS_CHANGE ON OPERATORS(CHANGE_TYPE, ETL_RUN_ID);
CREATE INDEX IX_PLANTS_CHANGE ON PLANTS(CHANGE_TYPE, ETL_RUN_ID);
CREATE INDEX IX_ISSUES_CHANGE ON ISSUES(CHANGE_TYPE, ETL_RUN_ID);

-- Staging indexes for performance
CREATE INDEX IX_STG_OPERATORS ON STG_OPERATORS(OPERATOR_ID, ETL_RUN_ID);
CREATE INDEX IX_STG_PLANTS ON STG_PLANTS(PLANT_ID, ETL_RUN_ID);
CREATE INDEX IX_STG_ISSUES ON STG_ISSUES(PLANT_ID, ISSUE_REVISION, ETL_RUN_ID);

-- RAW_JSON indexes
CREATE INDEX IX_RAWJSON_LOOKUP ON RAW_JSON (ENDPOINT, KEY_FINGERPRINT);
CREATE INDEX IX_RAWJSON_TS     ON RAW_JSON (LOAD_TS);
CREATE INDEX IX_RAWJSON_RUNID  ON RAW_JSON (ETL_RUN_ID);

-- =====================================================
-- STEP 8: CREATE VIEWS FOR EASY ACCESS
-- =====================================================

-- Current data views
CREATE OR REPLACE VIEW V_OPERATORS_CURRENT AS
SELECT 
    OPERATOR_ID,
    OPERATOR_NAME,
    VALID_FROM,
    CHANGE_TYPE,
    ETL_RUN_ID
FROM OPERATORS
WHERE IS_CURRENT = 'Y';

CREATE OR REPLACE VIEW V_PLANTS_CURRENT AS
SELECT 
    PLANT_ID,
    PLANT_NAME,
    LONG_DESCRIPTION,
    OPERATOR_ID,
    COMMON_LIB_PLANT_CODE,
    VALID_FROM,
    CHANGE_TYPE,
    ETL_RUN_ID
FROM PLANTS
WHERE IS_CURRENT = 'Y';

CREATE OR REPLACE VIEW V_ISSUES_CURRENT AS
SELECT 
    PLANT_ID,
    ISSUE_REVISION,
    USER_NAME,
    USER_ENTRY_TIME,
    USER_PROTECTED,
    VALID_FROM,
    CHANGE_TYPE,
    ETL_RUN_ID
FROM ISSUES
WHERE IS_CURRENT = 'Y';

-- NEW VIEW: Issues for active plants only (use this for downstream processing)
CREATE OR REPLACE VIEW V_ISSUES_ACTIVE_PLANTS AS
SELECT 
    i.PLANT_ID,
    i.ISSUE_REVISION,
    i.USER_NAME,
    i.USER_ENTRY_TIME,
    i.USER_PROTECTED,
    i.VALID_FROM,
    i.CHANGE_TYPE,
    i.ETL_RUN_ID
FROM ISSUES i
INNER JOIN ETL_PLANT_LOADER pl ON i.PLANT_ID = pl.PLANT_ID
WHERE i.IS_CURRENT = 'Y';

-- NEW VIEW: Issues selected for reference loading
CREATE OR REPLACE VIEW V_ISSUES_FOR_REFERENCES AS
SELECT 
    i.PLANT_ID,
    i.ISSUE_REVISION,
    i.USER_NAME,
    i.USER_ENTRY_TIME,
    i.USER_PROTECTED,
    i.VALID_FROM,
    i.CHANGE_TYPE,
    i.ETL_RUN_ID,
    il.CREATED_DATE as LOADER_CREATED_DATE
FROM ISSUES i
INNER JOIN ETL_ISSUE_LOADER il ON i.PLANT_ID = il.PLANT_ID 
                               AND i.ISSUE_REVISION = il.ISSUE_REVISION
WHERE i.IS_CURRENT = 'Y';

-- Audit trail view (with consistent datatypes)
CREATE OR REPLACE VIEW V_AUDIT_TRAIL AS
SELECT 
    'OPERATORS' as TABLE_NAME,
    TO_CHAR(OPERATOR_ID) as PRIMARY_KEY,  -- Convert NUMBER to VARCHAR
    CHANGE_TYPE,
    VALID_FROM,
    VALID_TO,
    DELETE_DATE,
    ETL_RUN_ID
FROM OPERATORS
UNION ALL
SELECT 
    'PLANTS' as TABLE_NAME,
    PLANT_ID as PRIMARY_KEY,  -- Already VARCHAR
    CHANGE_TYPE,
    VALID_FROM,
    VALID_TO,
    DELETE_DATE,
    ETL_RUN_ID
FROM PLANTS
UNION ALL
SELECT 
    'ISSUES' as TABLE_NAME,
    PLANT_ID || '|' || ISSUE_REVISION as PRIMARY_KEY,
    CHANGE_TYPE,
    VALID_FROM,
    VALID_TO,
    DELETE_DATE,
    ETL_RUN_ID
FROM ISSUES
ORDER BY VALID_FROM DESC;

-- Reconciliation view
CREATE OR REPLACE VIEW V_ETL_RECONCILIATION AS
SELECT 
    r.ETL_RUN_ID,
    r.ENTITY_TYPE,
    r.SOURCE_COUNT,
    r.TARGET_COUNT,
    r.DIFF_COUNT,
    CASE 
        WHEN ABS(r.DIFF_COUNT) > r.SOURCE_COUNT * 0.1 THEN 'WARNING'
        ELSE 'OK'
    END as STATUS,
    r.CHECK_TIME
FROM ETL_RECONCILIATION r
ORDER BY r.CHECK_TIME DESC;

-- =====================================================
-- STEP 9: CREATE AUTONOMOUS TRANSACTION PROCEDURES
-- =====================================================

-- Error logging that survives rollbacks
CREATE OR REPLACE PROCEDURE LOG_ETL_ERROR(
    p_run_id NUMBER,
    p_src VARCHAR2,
    p_code NUMBER,
    p_msg VARCHAR2,
    p_stack CLOB
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO ETL_ERROR_LOG (
        ETL_RUN_ID, ERROR_SOURCE, ERROR_CODE, ERROR_MESSAGE, STACK_TRACE
    ) VALUES (
        p_run_id, p_src, p_code, p_msg, p_stack
    );
    COMMIT;
END LOG_ETL_ERROR;
/

-- Update control on failure (autonomous)
CREATE OR REPLACE PROCEDURE UPDATE_ETL_CONTROL_FAILED(
    p_run_id NUMBER,
    p_step VARCHAR2,
    p_error VARCHAR2
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    UPDATE ETL_CONTROL
    SET STATUS = 'FAILED',
        END_TIME = SYSDATE,
        COMMENTS = 'Failed at ' || p_step || ': ' || SUBSTR(p_error, 1, 200)
    WHERE ETL_RUN_ID = p_run_id;
    COMMIT;
END UPDATE_ETL_CONTROL_FAILED;
/

-- =====================================================
-- STEP 10: CREATE DEDUPLICATION PROCEDURE
-- =====================================================

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
            MERGE INTO STG_EDS_REFERENCES tgt
            USING (
                SELECT STG_ID,
                       ROW_NUMBER() OVER (
                           PARTITION BY PLANT_ID, ISSUE_REVISION, EDS_NAME, EDS_REVISION 
                           ORDER BY ETL_RUN_ID DESC, STG_ID DESC
                       ) as rn
                FROM STG_EDS_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
            ) src
            ON (tgt.STG_ID = src.STG_ID)
            WHEN MATCHED THEN
                UPDATE SET IS_DUPLICATE = CASE WHEN src.rn > 1 THEN 'Y' ELSE 'N' END;
                
        WHEN 'MDS_REFERENCES' THEN
            MERGE INTO STG_MDS_REFERENCES tgt
            USING (
                SELECT STG_ID,
                       ROW_NUMBER() OVER (
                           PARTITION BY PLANT_ID, ISSUE_REVISION, MDS_NAME, MDS_REVISION 
                           ORDER BY ETL_RUN_ID DESC, STG_ID DESC
                       ) as rn
                FROM STG_MDS_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
            ) src
            ON (tgt.STG_ID = src.STG_ID)
            WHEN MATCHED THEN
                UPDATE SET IS_DUPLICATE = CASE WHEN src.rn > 1 THEN 'Y' ELSE 'N' END;
                
        WHEN 'VSK_REFERENCES' THEN
            MERGE INTO STG_VSK_REFERENCES tgt
            USING (
                SELECT STG_ID,
                       ROW_NUMBER() OVER (
                           PARTITION BY PLANT_ID, ISSUE_REVISION, VSK_NAME, VSK_REVISION 
                           ORDER BY ETL_RUN_ID DESC, STG_ID DESC
                       ) as rn
                FROM STG_VSK_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
            ) src
            ON (tgt.STG_ID = src.STG_ID)
            WHEN MATCHED THEN
                UPDATE SET IS_DUPLICATE = CASE WHEN src.rn > 1 THEN 'Y' ELSE 'N' END;
                
        WHEN 'ESK_REFERENCES' THEN
            MERGE INTO STG_ESK_REFERENCES tgt
            USING (
                SELECT STG_ID,
                       ROW_NUMBER() OVER (
                           PARTITION BY PLANT_ID, ISSUE_REVISION, ESK_NAME, ESK_REVISION 
                           ORDER BY ETL_RUN_ID DESC, STG_ID DESC
                       ) as rn
                FROM STG_ESK_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
            ) src
            ON (tgt.STG_ID = src.STG_ID)
            WHEN MATCHED THEN
                UPDATE SET IS_DUPLICATE = CASE WHEN src.rn > 1 THEN 'Y' ELSE 'N' END;
                
        WHEN 'PIPE_ELEMENT_REFERENCES' THEN
            MERGE INTO STG_PIPE_ELEMENT_REFERENCES tgt
            USING (
                SELECT STG_ID,
                       ROW_NUMBER() OVER (
                           PARTITION BY PLANT_ID, ISSUE_REVISION, TAG_NO 
                           ORDER BY ETL_RUN_ID DESC, STG_ID DESC
                       ) as rn
                FROM STG_PIPE_ELEMENT_REFERENCES
                WHERE ETL_RUN_ID = p_etl_run_id
            ) src
            ON (tgt.STG_ID = src.STG_ID)
            WHEN MATCHED THEN
                UPDATE SET IS_DUPLICATE = CASE WHEN src.rn > 1 THEN 'Y' ELSE 'N' END;
                
        ELSE
            RAISE_APPLICATION_ERROR(-20002, 'Unknown entity type: ' || p_entity_type);
    END CASE;
END SP_DEDUPLICATE_STAGING;
/

-- =====================================================
-- STEP 11: CREATE ENTITY PACKAGES
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
        -- Count invalid records first
        SELECT COUNT(*) INTO v_invalid_count
        FROM STG_OPERATORS
        WHERE ETL_RUN_ID = p_etl_run_id
          AND (OPERATOR_ID IS NULL
               OR LENGTH(OPERATOR_NAME) > 200
               OR REGEXP_LIKE(OPERATOR_NAME, '[<>"]'));
        
        -- Update validation status
        UPDATE STG_OPERATORS
        SET IS_VALID = CASE
                WHEN OPERATOR_ID IS NULL THEN 'N'
                WHEN LENGTH(OPERATOR_NAME) > 200 THEN 'N'
                WHEN REGEXP_LIKE(OPERATOR_NAME, '[<>"]') THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN OPERATOR_ID IS NULL THEN 'Missing OPERATOR_ID'
                WHEN LENGTH(OPERATOR_NAME) > 200 THEN 'Name exceeds 200 chars'
                WHEN REGEXP_LIKE(OPERATOR_NAME, '[<>"]') THEN 'Invalid characters'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        -- Log validation results if issues found
        IF v_invalid_count > 0 THEN
            LOG_ETL_ERROR(
                p_etl_run_id, 
                'VALIDATE_OPERATORS', 
                -20100, 
                v_invalid_count || ' records failed validation',
                NULL
            );
        END IF;
    END VALIDATE;
    
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER) AS
        v_records_unchanged NUMBER := 0;
        v_records_updated   NUMBER := 0;
        v_records_inserted  NUMBER := 0;
        v_records_deleted   NUMBER := 0;
        v_records_reactivated NUMBER := 0;
    BEGIN
        -- Step 1: Handle deletions
        UPDATE OPERATORS o
        SET o.VALID_TO = SYSDATE,
            o.IS_CURRENT = 'N',
            o.DELETE_DATE = SYSDATE,
            o.CHANGE_TYPE = 'DELETE'
        WHERE o.IS_CURRENT = 'Y'
          AND NOT EXISTS (
            SELECT 1 FROM STG_OPERATORS s
            WHERE s.OPERATOR_ID = o.OPERATOR_ID
              AND s.ETL_RUN_ID = p_etl_run_id
              AND s.IS_DUPLICATE = 'N'
              AND s.IS_VALID = 'Y'
          );
        v_records_deleted := SQL%ROWCOUNT;
        
        -- Step 2: Handle reactivations
        INSERT INTO OPERATORS (
            OPERATOR_ID, OPERATOR_NAME, SRC_HASH,
            VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
        )
        SELECT 
            s.OPERATOR_ID,
            s.OPERATOR_NAME,
            STANDARD_HASH(
                NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
                NVL(s.OPERATOR_NAME, '~'),
                'SHA256'
            ),
            SYSDATE,
            'Y',
            'REACTIVATE',
            p_etl_run_id
        FROM STG_OPERATORS s
        WHERE s.ETL_RUN_ID = p_etl_run_id
          AND s.IS_DUPLICATE = 'N'
          AND s.IS_VALID = 'Y'
          AND EXISTS (
            SELECT 1 FROM OPERATORS o
            WHERE o.OPERATOR_ID = s.OPERATOR_ID
              AND o.DELETE_DATE IS NOT NULL
              AND o.IS_CURRENT = 'N'
              AND NOT EXISTS (
                SELECT 1 FROM OPERATORS o2
                WHERE o2.OPERATOR_ID = s.OPERATOR_ID
                  AND o2.IS_CURRENT = 'Y'
              )
          );
        v_records_reactivated := SQL%ROWCOUNT;
        
        -- Step 3: Count unchanged
        SELECT COUNT(*) INTO v_records_unchanged
        FROM STG_OPERATORS s
        INNER JOIN OPERATORS o ON o.OPERATOR_ID = s.OPERATOR_ID
        WHERE o.IS_CURRENT = 'Y'
          AND s.ETL_RUN_ID = p_etl_run_id
          AND s.IS_DUPLICATE = 'N'
          AND s.IS_VALID = 'Y'
          AND STANDARD_HASH(
              NVL(TO_CHAR(o.OPERATOR_ID), '~') || '|' ||
              NVL(o.OPERATOR_NAME, '~'),
              'SHA256'
          ) = STANDARD_HASH(
              NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
              NVL(s.OPERATOR_NAME, '~'),
              'SHA256'
          );
        
        -- Step 4: Handle updates
        UPDATE OPERATORS o
        SET o.VALID_TO = SYSDATE, 
            o.IS_CURRENT = 'N'
        WHERE o.IS_CURRENT = 'Y'
          AND EXISTS (
            SELECT 1 FROM STG_OPERATORS s
            WHERE s.OPERATOR_ID = o.OPERATOR_ID
              AND s.ETL_RUN_ID = p_etl_run_id
              AND s.IS_DUPLICATE = 'N'
              AND s.IS_VALID = 'Y'
              AND STANDARD_HASH(
                  NVL(TO_CHAR(o.OPERATOR_ID), '~') || '|' ||
                  NVL(o.OPERATOR_NAME, '~'),
                  'SHA256'
              ) != STANDARD_HASH(
                  NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
                  NVL(s.OPERATOR_NAME, '~'),
                  'SHA256'
              )
          );
        v_records_updated := SQL%ROWCOUNT;
        
        -- Insert new versions for updates
        INSERT INTO OPERATORS (
            OPERATOR_ID, OPERATOR_NAME, SRC_HASH,
            VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
        )
        SELECT 
            s.OPERATOR_ID,
            s.OPERATOR_NAME,
            STANDARD_HASH(
                NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
                NVL(s.OPERATOR_NAME, '~'),
                'SHA256'
            ),
            SYSDATE,
            'Y',
            'UPDATE',
            p_etl_run_id
        FROM STG_OPERATORS s
        WHERE s.ETL_RUN_ID = p_etl_run_id
          AND s.IS_DUPLICATE = 'N'
          AND s.IS_VALID = 'Y'
          AND EXISTS (
            SELECT 1 FROM OPERATORS o
            WHERE o.OPERATOR_ID = s.OPERATOR_ID
              AND o.VALID_TO = SYSDATE
              AND o.CHANGE_TYPE IS NULL
          );
        
        -- Step 5: Handle new inserts
        INSERT INTO OPERATORS (
            OPERATOR_ID, OPERATOR_NAME, SRC_HASH,
            VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
        )
        SELECT 
            s.OPERATOR_ID,
            s.OPERATOR_NAME,
            STANDARD_HASH(
                NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
                NVL(s.OPERATOR_NAME, '~'),
                'SHA256'
            ),
            SYSDATE,
            'Y',
            'INSERT',
            p_etl_run_id
        FROM STG_OPERATORS s
        WHERE s.ETL_RUN_ID = p_etl_run_id
          AND s.IS_DUPLICATE = 'N'
          AND s.IS_VALID = 'Y'
          AND NOT EXISTS (
            SELECT 1 FROM OPERATORS o
            WHERE o.OPERATOR_ID = s.OPERATOR_ID
          );
        v_records_inserted := SQL%ROWCOUNT;
        
        -- Update ETL control
        UPDATE ETL_CONTROL
        SET RECORDS_UNCHANGED = v_records_unchanged,
            RECORDS_UPDATED = v_records_updated,
            RECORDS_LOADED = v_records_inserted,
            RECORDS_DELETED = v_records_deleted,
            RECORDS_REACTIVATED = v_records_reactivated
        WHERE ETL_RUN_ID = p_etl_run_id;
        
    END PROCESS_SCD2;
    
    PROCEDURE RECONCILE(p_etl_run_id NUMBER) AS
        v_source_count NUMBER;
        v_target_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_source_count
        FROM STG_OPERATORS
        WHERE ETL_RUN_ID = p_etl_run_id
          AND IS_DUPLICATE = 'N'
          AND IS_VALID = 'Y';
        
        SELECT COUNT(*) INTO v_target_count
        FROM OPERATORS
        WHERE IS_CURRENT = 'Y';
        
        INSERT INTO ETL_RECONCILIATION (
            ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
        ) VALUES (
            p_etl_run_id, 'OPERATORS', v_source_count, v_target_count, 
            ABS(v_source_count - v_target_count)
        );
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
        SELECT COUNT(*) INTO v_invalid_count
        FROM STG_PLANTS
        WHERE ETL_RUN_ID = p_etl_run_id
          AND (PLANT_ID IS NULL
               OR LENGTH(PLANT_NAME) > 200);
        
        UPDATE STG_PLANTS
        SET IS_VALID = CASE
                WHEN PLANT_ID IS NULL THEN 'N'
                WHEN LENGTH(PLANT_NAME) > 200 THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN PLANT_ID IS NULL THEN 'Missing PLANT_ID'
                WHEN LENGTH(PLANT_NAME) > 200 THEN 'Name exceeds 200 chars'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        IF v_invalid_count > 0 THEN
            LOG_ETL_ERROR(
                p_etl_run_id, 
                'VALIDATE_PLANTS', 
                -20100, 
                v_invalid_count || ' records failed validation',
                NULL
            );
        END IF;
    END VALIDATE;
    
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER) AS
        v_records_unchanged NUMBER := 0;
        v_records_updated   NUMBER := 0;
        v_records_inserted  NUMBER := 0;
        v_records_deleted   NUMBER := 0;
        v_records_reactivated NUMBER := 0;
    BEGIN
        -- Step 1: Handle deletions
        UPDATE PLANTS p
        SET p.VALID_TO = SYSDATE,
            p.IS_CURRENT = 'N',
            p.DELETE_DATE = SYSDATE,
            p.CHANGE_TYPE = 'DELETE'
        WHERE p.IS_CURRENT = 'Y'
          AND NOT EXISTS (
            SELECT 1 FROM STG_PLANTS s
            WHERE s.PLANT_ID = p.PLANT_ID
              AND s.ETL_RUN_ID = p_etl_run_id
              AND s.IS_DUPLICATE = 'N'
              AND s.IS_VALID = 'Y'
          );
        v_records_deleted := SQL%ROWCOUNT;
        
        -- Step 2: Handle reactivations
        INSERT INTO PLANTS (
            PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID, 
            COMMON_LIB_PLANT_CODE, SRC_HASH,
            VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
        )
        SELECT 
            s.PLANT_ID,
            s.PLANT_NAME,
            s.LONG_DESCRIPTION,
            s.OPERATOR_ID,
            s.COMMON_LIB_PLANT_CODE,
            STANDARD_HASH(
                NVL(s.PLANT_ID, '~') || '|' ||
                NVL(s.PLANT_NAME, '~') || '|' ||
                NVL(s.LONG_DESCRIPTION, '~') || '|' ||
                NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
                NVL(s.COMMON_LIB_PLANT_CODE, '~'),
                'SHA256'
            ),
            SYSDATE,
            'Y',
            'REACTIVATE',
            p_etl_run_id
        FROM STG_PLANTS s
        WHERE s.ETL_RUN_ID = p_etl_run_id
          AND s.IS_DUPLICATE = 'N'
          AND s.IS_VALID = 'Y'
          AND EXISTS (
            SELECT 1 FROM PLANTS p
            WHERE p.PLANT_ID = s.PLANT_ID
              AND p.DELETE_DATE IS NOT NULL
              AND p.IS_CURRENT = 'N'
              AND NOT EXISTS (
                SELECT 1 FROM PLANTS p2
                WHERE p2.PLANT_ID = s.PLANT_ID
                  AND p2.IS_CURRENT = 'Y'
              )
          );
        v_records_reactivated := SQL%ROWCOUNT;
        
        -- Step 3: Count unchanged
        SELECT COUNT(*) INTO v_records_unchanged
        FROM STG_PLANTS s
        INNER JOIN PLANTS p ON p.PLANT_ID = s.PLANT_ID
        WHERE p.IS_CURRENT = 'Y'
          AND s.ETL_RUN_ID = p_etl_run_id
          AND s.IS_DUPLICATE = 'N'
          AND s.IS_VALID = 'Y'
          AND STANDARD_HASH(
              NVL(p.PLANT_ID, '~') || '|' ||
              NVL(p.PLANT_NAME, '~') || '|' ||
              NVL(p.LONG_DESCRIPTION, '~') || '|' ||
              NVL(TO_CHAR(p.OPERATOR_ID), '~') || '|' ||
              NVL(p.COMMON_LIB_PLANT_CODE, '~'),
              'SHA256'
          ) = STANDARD_HASH(
              NVL(s.PLANT_ID, '~') || '|' ||
              NVL(s.PLANT_NAME, '~') || '|' ||
              NVL(s.LONG_DESCRIPTION, '~') || '|' ||
              NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
              NVL(s.COMMON_LIB_PLANT_CODE, '~'),
              'SHA256'
          );
        
        -- Step 4: Handle updates
        UPDATE PLANTS p
        SET p.VALID_TO = SYSDATE, 
            p.IS_CURRENT = 'N'
        WHERE p.IS_CURRENT = 'Y'
          AND EXISTS (
            SELECT 1 FROM STG_PLANTS s
            WHERE s.PLANT_ID = p.PLANT_ID
              AND s.ETL_RUN_ID = p_etl_run_id
              AND s.IS_DUPLICATE = 'N'
              AND s.IS_VALID = 'Y'
              AND STANDARD_HASH(
                  NVL(p.PLANT_ID, '~') || '|' ||
                  NVL(p.PLANT_NAME, '~') || '|' ||
                  NVL(p.LONG_DESCRIPTION, '~') || '|' ||
                  NVL(TO_CHAR(p.OPERATOR_ID), '~') || '|' ||
                  NVL(p.COMMON_LIB_PLANT_CODE, '~'),
                  'SHA256'
              ) != STANDARD_HASH(
                  NVL(s.PLANT_ID, '~') || '|' ||
                  NVL(s.PLANT_NAME, '~') || '|' ||
                  NVL(s.LONG_DESCRIPTION, '~') || '|' ||
                  NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
                  NVL(s.COMMON_LIB_PLANT_CODE, '~'),
                  'SHA256'
              )
          );
        v_records_updated := SQL%ROWCOUNT;
        
        -- Insert new versions for updates
        INSERT INTO PLANTS (
            PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID, 
            COMMON_LIB_PLANT_CODE, SRC_HASH,
            VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
        )
        SELECT 
            s.PLANT_ID,
            s.PLANT_NAME,
            s.LONG_DESCRIPTION,
            s.OPERATOR_ID,
            s.COMMON_LIB_PLANT_CODE,
            STANDARD_HASH(
                NVL(s.PLANT_ID, '~') || '|' ||
                NVL(s.PLANT_NAME, '~') || '|' ||
                NVL(s.LONG_DESCRIPTION, '~') || '|' ||
                NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
                NVL(s.COMMON_LIB_PLANT_CODE, '~'),
                'SHA256'
            ),
            SYSDATE,
            'Y',
            'UPDATE',
            p_etl_run_id
        FROM STG_PLANTS s
        WHERE s.ETL_RUN_ID = p_etl_run_id
          AND s.IS_DUPLICATE = 'N'
          AND s.IS_VALID = 'Y'
          AND EXISTS (
            SELECT 1 FROM PLANTS p
            WHERE p.PLANT_ID = s.PLANT_ID
              AND p.VALID_TO = SYSDATE
              AND p.CHANGE_TYPE IS NULL
          );
        
        -- Step 5: Handle new inserts
        INSERT INTO PLANTS (
            PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID, 
            COMMON_LIB_PLANT_CODE, SRC_HASH,
            VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
        )
        SELECT 
            s.PLANT_ID,
            s.PLANT_NAME,
            s.LONG_DESCRIPTION,
            s.OPERATOR_ID,
            s.COMMON_LIB_PLANT_CODE,
            STANDARD_HASH(
                NVL(s.PLANT_ID, '~') || '|' ||
                NVL(s.PLANT_NAME, '~') || '|' ||
                NVL(s.LONG_DESCRIPTION, '~') || '|' ||
                NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
                NVL(s.COMMON_LIB_PLANT_CODE, '~'),
                'SHA256'
            ),
            SYSDATE,
            'Y',
            'INSERT',
            p_etl_run_id
        FROM STG_PLANTS s
        WHERE s.ETL_RUN_ID = p_etl_run_id
          AND s.IS_DUPLICATE = 'N'
          AND s.IS_VALID = 'Y'
          AND NOT EXISTS (
            SELECT 1 FROM PLANTS p
            WHERE p.PLANT_ID = s.PLANT_ID
          );
        v_records_inserted := SQL%ROWCOUNT;
        
        -- Update ETL control
        UPDATE ETL_CONTROL
        SET RECORDS_UNCHANGED = v_records_unchanged,
            RECORDS_UPDATED = v_records_updated,
            RECORDS_LOADED = v_records_inserted,
            RECORDS_DELETED = v_records_deleted,
            RECORDS_REACTIVATED = v_records_reactivated
        WHERE ETL_RUN_ID = p_etl_run_id;
    END PROCESS_SCD2;
    
    PROCEDURE RECONCILE(p_etl_run_id NUMBER) AS
        v_source_count NUMBER;
        v_target_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_source_count
        FROM STG_PLANTS
        WHERE ETL_RUN_ID = p_etl_run_id
          AND IS_DUPLICATE = 'N'
          AND IS_VALID = 'Y';
        
        SELECT COUNT(*) INTO v_target_count
        FROM PLANTS
        WHERE IS_CURRENT = 'Y';
        
        INSERT INTO ETL_RECONCILIATION (
            ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
        ) VALUES (
            p_etl_run_id, 'PLANTS', v_source_count, v_target_count, 
            ABS(v_source_count - v_target_count)
        );
    END RECONCILE;
    
END PKG_PLANTS_ETL;
/

-- ISSUES ETL Package (similar structure)
CREATE OR REPLACE PACKAGE PKG_ISSUES_ETL AS
    PROCEDURE VALIDATE(p_etl_run_id NUMBER);
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER);
    PROCEDURE RECONCILE(p_etl_run_id NUMBER);
END PKG_ISSUES_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_ISSUES_ETL AS
    
    PROCEDURE VALIDATE(p_etl_run_id NUMBER) AS
    BEGIN
        UPDATE STG_ISSUES
        SET IS_VALID = CASE
                WHEN PLANT_ID IS NULL OR ISSUE_REVISION IS NULL THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN PLANT_ID IS NULL THEN 'Missing PLANT_ID'
                WHEN ISSUE_REVISION IS NULL THEN 'Missing ISSUE_REVISION'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
    END VALIDATE;
    
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER) AS
        v_count NUMBER;
        v_deleted_out_of_scope NUMBER;
    BEGIN
        -- Step 1: Mark issues deleted for plants NOT in the loader (deletion cascade)
        UPDATE ISSUES 
        SET IS_CURRENT = 'N',
            VALID_TO = SYSDATE,
            DELETE_DATE = SYSDATE,
            CHANGE_TYPE = 'DELETE',
            ETL_RUN_ID = p_etl_run_id
        WHERE IS_CURRENT = 'Y'
        AND DELETE_DATE IS NULL
        AND PLANT_ID NOT IN (
            SELECT PLANT_ID FROM ETL_PLANT_LOADER
        );
        v_deleted_out_of_scope := SQL%ROWCOUNT;
        
        IF v_deleted_out_of_scope > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Marked ' || v_deleted_out_of_scope || ' issues as deleted (plants removed from loader)');
        END IF;
        
        -- Step 2: Mark existing deleted if not in source (only for plants being processed)
        UPDATE ISSUES 
        SET IS_CURRENT = 'N',
            VALID_TO = SYSDATE,
            DELETE_DATE = SYSDATE,
            CHANGE_TYPE = 'DELETE'
        WHERE IS_CURRENT = 'Y'
        AND DELETE_DATE IS NULL
        AND PLANT_ID IN (
            SELECT DISTINCT PLANT_ID 
            FROM STG_ISSUES 
            WHERE ETL_RUN_ID = p_etl_run_id
        )
        AND (PLANT_ID, ISSUE_REVISION) NOT IN (
            SELECT DISTINCT PLANT_ID, ISSUE_REVISION 
            FROM STG_ISSUES 
            WHERE ETL_RUN_ID = p_etl_run_id
            AND IS_VALID = 'Y'
        );
        
        -- Handle reactivations (for issues that were deleted but now coming back)
        MERGE INTO ISSUES tgt
        USING (
            SELECT s.PLANT_ID, s.ISSUE_REVISION, s.USER_NAME, 
                   s.USER_ENTRY_TIME, s.USER_PROTECTED
            FROM STG_ISSUES s
            WHERE s.ETL_RUN_ID = p_etl_run_id
            AND s.IS_VALID = 'Y'
            AND EXISTS (
                SELECT 1 FROM ISSUES i
                WHERE i.PLANT_ID = s.PLANT_ID
                AND i.ISSUE_REVISION = s.ISSUE_REVISION
                AND i.DELETE_DATE IS NOT NULL
                AND i.IS_CURRENT = 'N'
            )
        ) src
        ON (1=0) -- Always insert for reactivations
        WHEN NOT MATCHED THEN
            INSERT (PLANT_ID, ISSUE_REVISION, USER_NAME, USER_ENTRY_TIME, 
                   USER_PROTECTED, IS_CURRENT, VALID_FROM, VALID_TO, 
                   CHANGE_TYPE, SRC_HASH, ETL_RUN_ID)
            VALUES (src.PLANT_ID, src.ISSUE_REVISION, src.USER_NAME,
                   src.USER_ENTRY_TIME, src.USER_PROTECTED, 'Y', SYSDATE, 
                   DATE '9999-12-31', 'REACTIVATE', 
                   STANDARD_HASH(NVL(src.USER_NAME, '~') || '|' || NVL(TO_CHAR(src.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' || NVL(src.USER_PROTECTED, '~'), 'SHA256'),
                   p_etl_run_id);
        
        -- Handle updates
        UPDATE ISSUES 
        SET IS_CURRENT = 'N',
            VALID_TO = SYSDATE
        WHERE IS_CURRENT = 'Y'
        AND DELETE_DATE IS NULL
        AND EXISTS (
            SELECT 1 FROM STG_ISSUES s
            WHERE s.PLANT_ID = ISSUES.PLANT_ID
            AND s.ISSUE_REVISION = ISSUES.ISSUE_REVISION
            AND s.ETL_RUN_ID = p_etl_run_id
            AND s.IS_VALID = 'Y'
            AND (ISSUES.SRC_HASH IS NULL 
                OR ISSUES.SRC_HASH != STANDARD_HASH(
                    NVL(s.USER_NAME, '~') || '|' || 
                    NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' || 
                    NVL(s.USER_PROTECTED, '~'), 'SHA256'))
        );
        
        -- Insert new/updated records
        INSERT INTO ISSUES (
            PLANT_ID, ISSUE_REVISION, USER_NAME, USER_ENTRY_TIME, 
            USER_PROTECTED, IS_CURRENT, VALID_FROM, VALID_TO, 
            CHANGE_TYPE, SRC_HASH, ETL_RUN_ID
        )
        SELECT DISTINCT
            s.PLANT_ID, s.ISSUE_REVISION, s.USER_NAME, s.USER_ENTRY_TIME,
            s.USER_PROTECTED, 'Y', SYSDATE, DATE '9999-12-31',
            CASE 
                WHEN NOT EXISTS (
                    SELECT 1 FROM ISSUES i 
                    WHERE i.PLANT_ID = s.PLANT_ID 
                    AND i.ISSUE_REVISION = s.ISSUE_REVISION
                ) THEN 'INSERT'
                ELSE 'UPDATE'
            END,
            STANDARD_HASH(NVL(s.USER_NAME, '~') || '|' || NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' || NVL(s.USER_PROTECTED, '~'), 'SHA256'),
            p_etl_run_id
        FROM STG_ISSUES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND NOT EXISTS (
            SELECT 1 FROM ISSUES i
            WHERE i.PLANT_ID = s.PLANT_ID
            AND i.ISSUE_REVISION = s.ISSUE_REVISION
            AND i.IS_CURRENT = 'Y'
            AND i.SRC_HASH = STANDARD_HASH(NVL(s.USER_NAME, '~') || '|' || NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' || NVL(s.USER_PROTECTED, '~'), 'SHA256')
        );
        
        -- Count results
        SELECT COUNT(*) INTO v_count
        FROM ISSUES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND CHANGE_TYPE = 'INSERT';
        
        UPDATE ETL_CONTROL
        SET RECORDS_LOADED = v_count
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        SELECT COUNT(*) INTO v_count
        FROM ISSUES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND CHANGE_TYPE = 'UPDATE';
        
        UPDATE ETL_CONTROL
        SET RECORDS_UPDATED = v_count
        WHERE ETL_RUN_ID = p_etl_run_id;
        
    END PROCESS_SCD2;
    
    PROCEDURE RECONCILE(p_etl_run_id NUMBER) AS
        v_source_count NUMBER;
        v_target_count NUMBER;
        v_unchanged_count NUMBER;
        v_deleted_count NUMBER;
        v_reactivated_count NUMBER;
    BEGIN
        -- Count source records
        SELECT COUNT(DISTINCT PLANT_ID || '~' || ISSUE_REVISION) 
        INTO v_source_count
        FROM STG_ISSUES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND IS_VALID = 'Y';
        
        -- Count current target records
        SELECT COUNT(*) INTO v_target_count
        FROM ISSUES
        WHERE IS_CURRENT = 'Y';
        
        -- Count unchanged records
        SELECT COUNT(*) INTO v_unchanged_count
        FROM STG_ISSUES s
        WHERE ETL_RUN_ID = p_etl_run_id
        AND IS_VALID = 'Y'
        AND EXISTS (
            SELECT 1 FROM ISSUES i
            WHERE i.PLANT_ID = s.PLANT_ID
            AND i.ISSUE_REVISION = s.ISSUE_REVISION
            AND i.IS_CURRENT = 'Y'
            AND i.SRC_HASH = STANDARD_HASH(NVL(s.USER_NAME, '~') || '|' || NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' || NVL(s.USER_PROTECTED, '~'), 'SHA256')
            AND i.ETL_RUN_ID != p_etl_run_id
        );
        
        -- Count deleted records
        SELECT COUNT(*) INTO v_deleted_count
        FROM ISSUES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND CHANGE_TYPE = 'DELETE';
        
        -- Count reactivated records
        SELECT COUNT(*) INTO v_reactivated_count
        FROM ISSUES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND CHANGE_TYPE = 'REACTIVATE';
        
        -- Insert reconciliation record
        INSERT INTO ETL_RECONCILIATION (
            ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
        ) VALUES (
            p_etl_run_id, 'ISSUES', v_source_count, v_target_count,
            ABS(v_source_count - v_target_count)
        );
        
        -- Update ETL_CONTROL with counts
        UPDATE ETL_CONTROL
        SET RECORDS_UNCHANGED = v_unchanged_count,
            RECORDS_DELETED = v_deleted_count,
            RECORDS_REACTIVATED = v_reactivated_count
        WHERE ETL_RUN_ID = p_etl_run_id;
        
    END RECONCILE;
    
END PKG_ISSUES_ETL;
/

-- =====================================================
-- REFERENCE TABLE ETL PACKAGES
-- =====================================================

-- VDS References ETL Package
CREATE OR REPLACE PACKAGE PKG_VDS_REF_ETL AS
    PROCEDURE VALIDATE(p_etl_run_id NUMBER);
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER);
    PROCEDURE RECONCILE(p_etl_run_id NUMBER);
END PKG_VDS_REF_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_VDS_REF_ETL AS
    
    PROCEDURE VALIDATE(p_etl_run_id NUMBER) AS
    BEGIN
        UPDATE STG_VDS_REFERENCES
        SET IS_VALID = CASE
                WHEN PLANT_ID IS NULL OR ISSUE_REVISION IS NULL THEN 'N'
                WHEN VDS_NAME IS NULL THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN PLANT_ID IS NULL THEN 'Missing PLANT_ID'
                WHEN ISSUE_REVISION IS NULL THEN 'Missing ISSUE_REVISION'
                WHEN VDS_NAME IS NULL THEN 'Missing VDS_NAME'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        -- Mark duplicates within this batch
        UPDATE STG_VDS_REFERENCES s1
        SET IS_DUPLICATE = 'Y'
        WHERE ETL_RUN_ID = p_etl_run_id
        AND STG_ID > (
            SELECT MIN(s2.STG_ID)
            FROM STG_VDS_REFERENCES s2
            WHERE s2.ETL_RUN_ID = p_etl_run_id
            AND s2.PLANT_ID = s1.PLANT_ID
            AND s2.ISSUE_REVISION = s1.ISSUE_REVISION
            AND NVL(s2.VDS_NAME, 'NULL') = NVL(s1.VDS_NAME, 'NULL')
            AND NVL(s2.VDS_REVISION, 'NULL') = NVL(s1.VDS_REVISION, 'NULL')
        );
    END VALIDATE;
    
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER) AS
        v_rows_inserted NUMBER := 0;
        v_rows_updated NUMBER := 0;
        v_rows_deleted NUMBER := 0;
        v_rows_reactivated NUMBER := 0;
        v_rows_unchanged NUMBER := 0;
    BEGIN
        -- STEP 1: Handle CASCADE DELETION
        -- Mark references as deleted for issues NOT in the loader
        UPDATE VDS_REFERENCES 
        SET IS_CURRENT = 'N', 
            VALID_TO = SYSDATE,
            DELETE_DATE = SYSDATE, 
            CHANGE_TYPE = 'DELETE'
        WHERE IS_CURRENT = 'Y' 
        AND DELETE_DATE IS NULL
        AND (PLANT_ID, ISSUE_REVISION) NOT IN (
            SELECT PLANT_ID, ISSUE_REVISION FROM ETL_ISSUE_LOADER
        );
        
        v_rows_deleted := SQL%ROWCOUNT;
        
        -- STEP 2: Close existing records that have changed
        UPDATE VDS_REFERENCES d
        SET IS_CURRENT = 'N',
            VALID_TO = SYSDATE,
            CHANGE_TYPE = 'UPDATE'
        WHERE d.IS_CURRENT = 'Y'
        AND d.DELETE_DATE IS NULL
        AND EXISTS (
            SELECT 1 FROM STG_VDS_REFERENCES s
            WHERE s.ETL_RUN_ID = p_etl_run_id
            AND s.IS_VALID = 'Y'
            AND s.IS_DUPLICATE = 'N'
            AND s.PLANT_ID = d.PLANT_ID
            AND s.ISSUE_REVISION = d.ISSUE_REVISION
            AND NVL(s.VDS_NAME, 'NULL') = NVL(d.VDS_NAME, 'NULL')
            AND NVL(s.VDS_REVISION, 'NULL') = NVL(d.VDS_REVISION, 'NULL')
            AND STANDARD_HASH(
                NVL(s.VDS_NAME, '~') || '|' ||
                NVL(s.VDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ) != d.SRC_HASH
        );
        
        v_rows_updated := SQL%ROWCOUNT;
        
        -- STEP 3: Reactivate previously deleted records
        UPDATE VDS_REFERENCES d
        SET IS_CURRENT = 'Y',
            VALID_TO = NULL,
            DELETE_DATE = NULL,
            CHANGE_TYPE = 'REACTIVATE'
        WHERE d.IS_CURRENT = 'N'
        AND d.DELETE_DATE IS NOT NULL
        AND EXISTS (
            SELECT 1 FROM STG_VDS_REFERENCES s
            WHERE s.ETL_RUN_ID = p_etl_run_id
            AND s.IS_VALID = 'Y'
            AND s.IS_DUPLICATE = 'N'
            AND s.PLANT_ID = d.PLANT_ID
            AND s.ISSUE_REVISION = d.ISSUE_REVISION
            AND NVL(s.VDS_NAME, 'NULL') = NVL(d.VDS_NAME, 'NULL')
            AND NVL(s.VDS_REVISION, 'NULL') = NVL(d.VDS_REVISION, 'NULL')
            AND STANDARD_HASH(
                NVL(s.VDS_NAME, '~') || '|' ||
                NVL(s.VDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ) = d.SRC_HASH
        );
        
        v_rows_reactivated := SQL%ROWCOUNT;
        
        -- Count unchanged records
        SELECT COUNT(*) INTO v_rows_unchanged
        FROM STG_VDS_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND EXISTS (
            SELECT 1 FROM VDS_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.VDS_NAME, 'NULL') = NVL(s.VDS_NAME, 'NULL')
            AND NVL(d.VDS_REVISION, 'NULL') = NVL(s.VDS_REVISION, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.VDS_NAME, '~') || '|' ||
                NVL(s.VDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        -- STEP 4: Insert new records
        INSERT INTO VDS_REFERENCES (
            PLANT_ID, ISSUE_REVISION, VDS_NAME, VDS_REVISION,
            OFFICIAL_REVISION, DELTA, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
            SRC_HASH, VALID_FROM, VALID_TO, IS_CURRENT, CHANGE_TYPE, 
            DELETE_DATE, ETL_RUN_ID
        )
        SELECT DISTINCT
            s.PLANT_ID, s.ISSUE_REVISION, s.VDS_NAME, s.VDS_REVISION,
            s.OFFICIAL_REVISION, s.DELTA, s.USER_NAME, s.USER_ENTRY_TIME, s.USER_PROTECTED,
            STANDARD_HASH(
                NVL(s.VDS_NAME, '~') || '|' ||
                NVL(s.VDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ), SYSDATE, NULL, 'Y', 'INSERT',
            NULL, p_etl_run_id
        FROM STG_VDS_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND NOT EXISTS (
            SELECT 1 FROM VDS_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.VDS_NAME, 'NULL') = NVL(s.VDS_NAME, 'NULL')
            AND NVL(d.VDS_REVISION, 'NULL') = NVL(s.VDS_REVISION, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.VDS_NAME, '~') || '|' ||
                NVL(s.VDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        v_rows_inserted := SQL%ROWCOUNT;
        
        -- Mark staging records as processed
        UPDATE STG_VDS_REFERENCES
        SET PROCESSED_FLAG = 'Y'
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        -- Update ETL control with counts
        UPDATE ETL_CONTROL
        SET RECORDS_LOADED = v_rows_inserted,
            RECORDS_UPDATED = v_rows_updated,
            RECORDS_DELETED = v_rows_deleted,
            RECORDS_REACTIVATED = v_rows_reactivated,
            RECORDS_UNCHANGED = v_rows_unchanged
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        DBMS_OUTPUT.PUT_LINE('VDS References SCD2 completed: ' || 
            v_rows_inserted || ' inserted, ' ||
            v_rows_updated || ' updated, ' ||
            v_rows_deleted || ' deleted, ' ||
            v_rows_reactivated || ' reactivated');
            
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            LOG_ETL_ERROR(
                p_etl_run_id, 
                'PKG_VDS_REF_ETL.PROCESS_SCD2', 
                SQLCODE, 
                SQLERRM, 
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
            );
            RAISE;
    END PROCESS_SCD2;
    
    PROCEDURE RECONCILE(p_etl_run_id NUMBER) AS
        v_source_count NUMBER;
        v_target_count NUMBER;
    BEGIN
        -- Count valid staging records
        SELECT COUNT(*)
        INTO v_source_count
        FROM STG_VDS_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND IS_VALID = 'Y'
        AND IS_DUPLICATE = 'N';
        
        -- Count current dimension records
        SELECT COUNT(*)
        INTO v_target_count
        FROM VDS_REFERENCES
        WHERE IS_CURRENT = 'Y'
        AND DELETE_DATE IS NULL;
        
        -- Log reconciliation
        INSERT INTO ETL_RECONCILIATION (
            ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
        ) VALUES (
            p_etl_run_id, 'VDS_REFERENCES', v_source_count, v_target_count,
            ABS(v_source_count - v_target_count)
        );
    END RECONCILE;
    
END PKG_VDS_REF_ETL;
/

-- =====================================================
-- STEP 12: CREATE MASTER ORCHESTRATOR
-- =====================================================

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
    
    -- Set module info for monitoring
    DBMS_APPLICATION_INFO.SET_MODULE('ETL', p_entity_type || ':START');
    
    -- Step 1: Deduplication
    v_step := 'DEDUPLICATION';
    DBMS_APPLICATION_INFO.SET_ACTION(p_entity_type || ':DEDUP');
    SP_DEDUPLICATE_STAGING(p_etl_run_id, p_entity_type);
    
    -- Step 2-4: Entity-specific processing
    v_step := 'ENTITY_PROCESSING';
    CASE p_entity_type
        WHEN 'OPERATORS' THEN
            DBMS_APPLICATION_INFO.SET_ACTION('OPERATORS:VALIDATE');
            PKG_OPERATORS_ETL.VALIDATE(p_etl_run_id);
            
            DBMS_APPLICATION_INFO.SET_ACTION('OPERATORS:SCD2');
            PKG_OPERATORS_ETL.PROCESS_SCD2(p_etl_run_id);
            
            DBMS_APPLICATION_INFO.SET_ACTION('OPERATORS:RECONCILE');
            PKG_OPERATORS_ETL.RECONCILE(p_etl_run_id);
            
        WHEN 'PLANTS' THEN
            PKG_PLANTS_ETL.VALIDATE(p_etl_run_id);
            PKG_PLANTS_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_PLANTS_ETL.RECONCILE(p_etl_run_id);
            
        WHEN 'ISSUES' THEN
            PKG_ISSUES_ETL.VALIDATE(p_etl_run_id);
            PKG_ISSUES_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_ISSUES_ETL.RECONCILE(p_etl_run_id);
            
        WHEN 'VDS_REFERENCES' THEN
            PKG_VDS_REF_ETL.VALIDATE(p_etl_run_id);
            PKG_VDS_REF_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_VDS_REF_ETL.RECONCILE(p_etl_run_id);
            
        WHEN 'EDS_REFERENCES' THEN
            PKG_EDS_REF_ETL.VALIDATE(p_etl_run_id);
            PKG_EDS_REF_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_EDS_REF_ETL.RECONCILE(p_etl_run_id);
            
        WHEN 'MDS_REFERENCES' THEN
            PKG_MDS_REF_ETL.VALIDATE(p_etl_run_id);
            PKG_MDS_REF_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_MDS_REF_ETL.RECONCILE(p_etl_run_id);
            
        WHEN 'VSK_REFERENCES' THEN
            PKG_VSK_REF_ETL.VALIDATE(p_etl_run_id);
            PKG_VSK_REF_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_VSK_REF_ETL.RECONCILE(p_etl_run_id);
            
        WHEN 'ESK_REFERENCES' THEN
            PKG_ESK_REF_ETL.VALIDATE(p_etl_run_id);
            PKG_ESK_REF_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_ESK_REF_ETL.RECONCILE(p_etl_run_id);
            
        WHEN 'PIPE_ELEMENT_REFERENCES' THEN
            PKG_PIPE_ELEMENT_REF_ETL.VALIDATE(p_etl_run_id);
            PKG_PIPE_ELEMENT_REF_ETL.PROCESS_SCD2(p_etl_run_id);
            PKG_PIPE_ELEMENT_REF_ETL.RECONCILE(p_etl_run_id);
            
        ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Unknown entity type: ' || p_entity_type);
    END CASE;
    
    -- Step 5: Calculate processing time correctly
    v_end_time := SYSDATE;
    -- Calculate processing time in seconds (DATE subtraction returns days)
    v_processing_seconds := ROUND((v_end_time - v_start_time) * 86400);
    
    -- Update control
    UPDATE ETL_CONTROL
    SET STATUS = 'SUCCESS',
        END_TIME = v_end_time,
        PROCESSING_TIME_SEC = v_processing_seconds
    WHERE ETL_RUN_ID = p_etl_run_id;
    
    -- SINGLE ATOMIC COMMIT
    COMMIT;
    
    -- CLEANUP OLD DATA (After successful commit)
    -- Non-critical - doesn't fail ETL if cleanup fails
    BEGIN
        -- Keep only last 10 ETL runs
        DELETE FROM ETL_CONTROL
        WHERE ETL_RUN_ID < (
            SELECT MIN(ETL_RUN_ID) 
            FROM (
                SELECT ETL_RUN_ID 
                FROM ETL_CONTROL 
                ORDER BY ETL_RUN_ID DESC
            ) 
            WHERE ROWNUM <= 10
        );
        
        -- Clean error logs older than 30 days
        DELETE FROM ETL_ERROR_LOG 
        WHERE ERROR_TIME < SYSDATE - 30;
        
        -- Clean orphaned staging (safety - should be empty)
        DELETE FROM STG_OPERATORS WHERE ETL_RUN_ID < p_etl_run_id - 10;
        DELETE FROM STG_PLANTS WHERE ETL_RUN_ID < p_etl_run_id - 10;
        DELETE FROM STG_ISSUES WHERE ETL_RUN_ID < p_etl_run_id - 10;
        
        COMMIT; -- Separate commit for cleanup
    EXCEPTION
        WHEN OTHERS THEN
            -- Cleanup errors are logged but don't fail ETL
            LOG_ETL_ERROR(
                p_etl_run_id,
                'POST_ETL_CLEANUP',
                SQLCODE,
                'Non-critical cleanup error: ' || SQLERRM,
                NULL
            );
    END;
    
    -- RAW_JSON Cleanup (best-effort, non-critical)
    BEGIN
        SP_PURGE_RAW_JSON(30);  -- Keep 30 days
        COMMIT;  -- Separate commit for purge
    EXCEPTION 
        WHEN OTHERS THEN 
            -- Ignore errors - don't affect ETL outcome
            LOG_ETL_ERROR(
                p_etl_run_id,
                'RAW_JSON_PURGE',
                SQLCODE,
                'Non-critical RAW_JSON purge error: ' || SQLERRM,
                NULL
            );
    END;
    
    DBMS_APPLICATION_INFO.SET_MODULE(NULL, NULL);
    
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback transaction
        ROLLBACK;
        
        -- Log error (autonomous)
        LOG_ETL_ERROR(
            p_etl_run_id,
            'SP_PROCESS_ETL_BATCH.' || v_step,
            SQLCODE,
            SQLERRM,
            DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
        );
        
        -- Update control (autonomous)
        UPDATE_ETL_CONTROL_FAILED(p_etl_run_id, v_step, SQLERRM);
        
        DBMS_APPLICATION_INFO.SET_MODULE(NULL, NULL);
        RAISE;
END SP_PROCESS_ETL_BATCH;
/

-- =====================================================
-- STEP 13: CREATE CLEANUP PROCEDURES
-- =====================================================

-- Cleanup staging after successful ETL
CREATE OR REPLACE PROCEDURE SP_CLEANUP_STAGING(
    p_etl_run_id IN NUMBER
) AS
BEGIN
    DELETE FROM STG_OPERATORS WHERE ETL_RUN_ID = p_etl_run_id;
    DELETE FROM STG_PLANTS WHERE ETL_RUN_ID = p_etl_run_id;
    DELETE FROM STG_ISSUES WHERE ETL_RUN_ID = p_etl_run_id;
    DELETE FROM STG_PCS_REFERENCES WHERE ETL_RUN_ID = p_etl_run_id;
    DELETE FROM STG_SC_REFERENCES WHERE ETL_RUN_ID = p_etl_run_id;
    DELETE FROM STG_VSM_REFERENCES WHERE ETL_RUN_ID = p_etl_run_id;
    DELETE FROM STG_VDS_REFERENCES WHERE ETL_RUN_ID = p_etl_run_id;
    -- Don't commit - let orchestrator handle it
END SP_CLEANUP_STAGING;
/

-- Keep only last 10 ETL runs
CREATE OR REPLACE PROCEDURE SP_CLEANUP_ETL_HISTORY AS
BEGIN
    DELETE FROM ETL_CONTROL
    WHERE ETL_RUN_ID NOT IN (
        SELECT ETL_RUN_ID 
        FROM (
            SELECT ETL_RUN_ID
            FROM ETL_CONTROL
            ORDER BY ETL_RUN_ID DESC
        )
        WHERE ROWNUM <= 10
    );
    COMMIT;
END SP_CLEANUP_ETL_HISTORY;
/

-- =====================================================
-- STEP 14: CREATE SCHEDULED JOBS (OPTIONAL - Requires DBMS_SCHEDULER privileges)
-- =====================================================
-- Note: These require CREATE JOB privilege. If you get ORA-27486, 
-- you can skip these and run the cleanup procedures manually.

-- Job to purge old RAW_JSON (30 days)
-- Uncomment if you have scheduler privileges:
/*
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'PURGE_RAW_JSON_30D',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN DELETE FROM RAW_JSON WHERE LOAD_TS < SYSDATE - 30; COMMIT; END;',
        start_date      => SYSDATE,
        repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0;BYSECOND=0',
        enabled         => TRUE
    );
END;
/
*/

-- Job to cleanup ETL history
-- Uncomment if you have scheduler privileges:
/*
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'CLEANUP_ETL_HISTORY',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN SP_CLEANUP_ETL_HISTORY; END;',
        start_date      => SYSDATE,
        repeat_interval => 'FREQ=DAILY;BYHOUR=3;BYMINUTE=0;BYSECOND=0',
        enabled         => TRUE
    );
END;
/
*/

-- Manual cleanup alternatives (run these periodically):
-- EXEC SP_CLEANUP_ETL_HISTORY;
-- DELETE FROM RAW_JSON WHERE LOAD_TS < SYSTIMESTAMP - 30;

-- =====================================================
-- STEP 15: CREATE SECURITY TRIGGERS (OPTIONAL - Requires CREATE TRIGGER privilege)
-- =====================================================
-- Note: These require CREATE TRIGGER privilege. If you get ORA-01031,
-- you can skip these and rely on database roles/grants for security.

-- Block manual DML on critical tables
-- Uncomment if you have trigger privileges and want extra protection:
/*
CREATE OR REPLACE TRIGGER OPERATORS_BLOCK_MANUAL_DML
BEFORE INSERT OR UPDATE OR DELETE ON OPERATORS
BEGIN
    IF SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('TR2000_ETL', 'SYS', 'SYSTEM') THEN
        RAISE_APPLICATION_ERROR(-20001, 'Direct DML not allowed. Use ETL procedures.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER PLANTS_BLOCK_MANUAL_DML
BEFORE INSERT OR UPDATE OR DELETE ON PLANTS
BEGIN
    IF SYS_CONTEXT('USERENV','SESSION_USER') NOT IN ('TR2000_ETL', 'SYS', 'SYSTEM') THEN
        RAISE_APPLICATION_ERROR(-20001, 'Direct DML not allowed. Use ETL procedures.');
    END IF;
END;
/
*/

-- =====================================================
-- IMPORTANT: DOWNSTREAM PROCESSING PATTERN
-- =====================================================
-- When loading reference tables (PCS_REFERENCES, SC_REFERENCES, etc.),
-- ALWAYS use V_ISSUES_FOR_REFERENCES view instead of ISSUES table directly.
-- This ensures you only process issues selected in ETL_ISSUE_LOADER.
--
-- Example for reference table loading:
-- INSERT INTO STG_PCS_REFERENCES (...)
-- SELECT ... 
-- FROM V_ISSUES_FOR_REFERENCES i  -- Use this view for maximum performance
-- WHERE ...
--
-- This pattern ensures:
-- 1. Dramatic reduction in API calls (70%+ improvement)
-- 2. User control over which issues load references  
-- 3. Full history preservation (SCD2 intact)
-- 4. Clean scope control via ETL_PLANT_LOADER → ETL_ISSUE_LOADER cascade
-- =====================================================

-- =====================================================
-- STEP 16: VERIFICATION QUERIES
-- =====================================================

-- Check all objects created
SELECT object_type, object_name, status
FROM user_objects 
WHERE created >= TRUNC(SYSDATE)
  AND object_name NOT LIKE 'SYS_%'
ORDER BY object_type, object_name;

-- Verify hash function
SELECT 'Hash Test' as TEST, 
       STANDARD_HASH('test', 'SHA256') as HASH_VALUE 
FROM DUAL;

-- Show table counts
SELECT 'Table Counts' as REPORT FROM DUAL;
SELECT 'OPERATORS' as TABLE_NAME, COUNT(*) as ROW_COUNT FROM OPERATORS
UNION ALL
SELECT 'PLANTS', COUNT(*) FROM PLANTS
UNION ALL
SELECT 'ISSUES', COUNT(*) FROM ISSUES;

COMMIT;

-- =====================================================
-- END OF PRODUCTION-READY SCD2 DDL
-- =====================================================

PROMPT 'Production SCD2 DDL Complete!';
PROMPT 'Ready to process ETL batches with SP_PROCESS_ETL_BATCH';
PROMPT 'C# should only fetch data and call the orchestrator';