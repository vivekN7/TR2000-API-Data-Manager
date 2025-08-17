-- =====================================================
-- TR2000 STAGING DATABASE - COMPLETE DDL SCRIPT V4.0
-- Database: Oracle 
-- Schema: TR2000_STAGING
-- Updated: 2025-08-17
-- 
-- IMPORTANT: This script DROPS and RECREATES all objects
-- It handles non-existent objects gracefully
-- Run with caution in production environments
-- =====================================================

SET SERVEROUTPUT ON;

-- =====================================================
-- STEP 1: DROP ALL EXISTING OBJECTS (SAFE - Won't fail if objects don't exist)
-- =====================================================

DECLARE
    v_count NUMBER;
BEGIN
    -- Drop Views
    FOR v IN (SELECT view_name FROM user_views)
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
            DBMS_OUTPUT.PUT_LINE('Dropped view: ' || v.view_name);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Drop Tables (in reverse dependency order)
    -- Reference Tables
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN (
        'PIPE_ELEMENT_REFERENCES', 'ESK_REFERENCES', 'VSK_REFERENCES', 
        'MDS_REFERENCES', 'EDS_REFERENCES', 'VDS_REFERENCES', 
        'VSM_REFERENCES', 'SC_REFERENCES', 'PCS_REFERENCES'
    ))
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
            DBMS_OUTPUT.PUT_LINE('Dropped table: ' || t.table_name);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Master Tables
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN (
        'ISSUES', 'PLANTS', 'OPERATORS'
    ))
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
            DBMS_OUTPUT.PUT_LINE('Dropped table: ' || t.table_name);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Control Tables
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN (
        'ETL_ERROR_LOG', 'ETL_ENDPOINT_LOG', 'ETL_CONTROL', 'ETL_PLANT_LOADER'
    ))
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
            DBMS_OUTPUT.PUT_LINE('Dropped table: ' || t.table_name);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Drop Sequences
    FOR s IN (SELECT sequence_name FROM user_sequences WHERE sequence_name IN (
        'ETL_RUN_ID_SEQ', 'ETL_LOG_ID_SEQ', 'ETL_ERROR_ID_SEQ'
    ))
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
            DBMS_OUTPUT.PUT_LINE('Dropped sequence: ' || s.sequence_name);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Drop Indexes (cleanup any remaining indexes)
    FOR i IN (SELECT index_name FROM user_indexes WHERE index_name LIKE 'IDX_%')
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP INDEX ' || i.index_name;
            DBMS_OUTPUT.PUT_LINE('Dropped index: ' || i.index_name);
        EXCEPTION
            WHEN OTHERS THEN NULL;
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

-- ETL Control Table (Main ETL run tracking)
CREATE TABLE ETL_CONTROL (
    ETL_RUN_ID         NUMBER DEFAULT ETL_RUN_ID_SEQ.NEXTVAL PRIMARY KEY,
    RUN_TYPE           VARCHAR2(50),    -- FULL, INCREMENTAL, REFERENCE
    STATUS             VARCHAR2(20),    -- RUNNING, SUCCESS, FAILED
    START_TIME         DATE,
    END_TIME           DATE,
    RECORDS_LOADED     NUMBER,
    ERROR_COUNT        NUMBER,
    COMMENTS           VARCHAR2(500)
);

-- ETL Endpoint Log (Track individual endpoint loads)
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

-- ETL Error Log (Detailed error tracking)
CREATE TABLE ETL_ERROR_LOG (
    ERROR_ID           NUMBER DEFAULT ETL_ERROR_ID_SEQ.NEXTVAL PRIMARY KEY,
    ETL_RUN_ID         NUMBER REFERENCES ETL_CONTROL(ETL_RUN_ID),
    ERROR_TIME         DATE DEFAULT SYSDATE,
    ERROR_SOURCE       VARCHAR2(100),
    ERROR_CODE         VARCHAR2(20),
    ERROR_MESSAGE      VARCHAR2(4000),
    STACK_TRACE        CLOB,
    RECORD_DATA        CLOB
);

-- ETL Plant Loader Configuration
CREATE TABLE ETL_PLANT_LOADER (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    IS_ACTIVE          CHAR(1) DEFAULT 'Y' CHECK (IS_ACTIVE IN ('Y', 'N')),
    LOAD_PRIORITY      NUMBER DEFAULT 100,  -- Lower number = higher priority
    NOTES              VARCHAR2(500),
    CREATED_DATE       DATE DEFAULT SYSDATE,
    CREATED_BY         VARCHAR2(100) DEFAULT USER,
    MODIFIED_DATE      DATE DEFAULT SYSDATE,
    MODIFIED_BY        VARCHAR2(100) DEFAULT USER,
    CONSTRAINT PK_ETL_PLANT_LOADER PRIMARY KEY (PLANT_ID)
);

-- =====================================================
-- STEP 4: CREATE MASTER DATA TABLES
-- =====================================================

-- Operators Table
CREATE TABLE OPERATORS (
    OPERATOR_ID        NUMBER NOT NULL,
    OPERATOR_NAME      VARCHAR2(200),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CONSTRAINT PK_OPERATORS PRIMARY KEY (OPERATOR_ID, EXTRACTION_DATE)
);

-- Plants Table
CREATE TABLE PLANTS (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    LONG_DESCRIPTION   VARCHAR2(500),
    OPERATOR_ID        NUMBER,
    COMMON_LIB_PLANT_CODE VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CONSTRAINT PK_PLANTS PRIMARY KEY (PLANT_ID, EXTRACTION_DATE)
);

-- Issues Table
CREATE TABLE ISSUES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    CONSTRAINT PK_ISSUES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, EXTRACTION_DATE)
);

-- =====================================================
-- STEP 5: CREATE REFERENCE TABLES
-- =====================================================

-- PCS References
CREATE TABLE PCS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    PCS_NAME           VARCHAR2(100),
    PCS_REVISION       VARCHAR2(20),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    CONSTRAINT PK_PCS_REF PRIMARY KEY (PLANT_ID, ISSUE_REVISION, PCS_NAME, PCS_REVISION, EXTRACTION_DATE),
    CONSTRAINT CHK_PCS_REF_CURRENT CHECK (IS_CURRENT IN ('Y', 'N'))
);

-- SC References
CREATE TABLE SC_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    SC_NAME            VARCHAR2(100),
    SC_REVISION        VARCHAR2(20),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(100),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    CONSTRAINT PK_SC_REF PRIMARY KEY (PLANT_ID, ISSUE_REVISION, SC_NAME, SC_REVISION, EXTRACTION_DATE),
    CONSTRAINT CHK_SC_REF_CURRENT CHECK (IS_CURRENT IN ('Y', 'N'))
);

-- VSM References
CREATE TABLE VSM_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VSM_NAME           VARCHAR2(100),
    VSM_REVISION       VARCHAR2(20),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(100),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    CONSTRAINT PK_VSM_REF PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VSM_NAME, VSM_REVISION, EXTRACTION_DATE),
    CONSTRAINT CHK_VSM_REF_CURRENT CHECK (IS_CURRENT IN ('Y', 'N'))
);

-- VDS References
CREATE TABLE VDS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VDS_NAME           VARCHAR2(100),
    VDS_REVISION       VARCHAR2(20),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(100),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    CONSTRAINT PK_VDS_REF PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VDS_NAME, VDS_REVISION, EXTRACTION_DATE),
    CONSTRAINT CHK_VDS_REF_CURRENT CHECK (IS_CURRENT IN ('Y', 'N'))
);

-- EDS References
CREATE TABLE EDS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    EDS_NAME           VARCHAR2(100),
    EDS_REVISION       VARCHAR2(20),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(100),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    CONSTRAINT PK_EDS_REF PRIMARY KEY (PLANT_ID, ISSUE_REVISION, EDS_NAME, EDS_REVISION, EXTRACTION_DATE),
    CONSTRAINT CHK_EDS_REF_CURRENT CHECK (IS_CURRENT IN ('Y', 'N'))
);

-- MDS References
CREATE TABLE MDS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    MDS_NAME           VARCHAR2(100),
    MDS_REVISION       VARCHAR2(20),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(100),
    AREA               VARCHAR2(100),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    CONSTRAINT PK_MDS_REF PRIMARY KEY (PLANT_ID, ISSUE_REVISION, MDS_NAME, MDS_REVISION, EXTRACTION_DATE),
    CONSTRAINT CHK_MDS_REF_CURRENT CHECK (IS_CURRENT IN ('Y', 'N'))
);

-- VSK References
CREATE TABLE VSK_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    VSK_NAME           VARCHAR2(100),
    VSK_REVISION       VARCHAR2(20),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(100),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    CONSTRAINT PK_VSK_REF PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VSK_NAME, VSK_REVISION, EXTRACTION_DATE),
    CONSTRAINT CHK_VSK_REF_CURRENT CHECK (IS_CURRENT IN ('Y', 'N'))
);

-- ESK References
CREATE TABLE ESK_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    ESK_NAME           VARCHAR2(100),
    ESK_REVISION       VARCHAR2(20),
    OFFICIAL_REVISION  VARCHAR2(20),
    DELTA              VARCHAR2(100),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    CONSTRAINT PK_ESK_REF PRIMARY KEY (PLANT_ID, ISSUE_REVISION, ESK_NAME, ESK_REVISION, EXTRACTION_DATE),
    CONSTRAINT CHK_ESK_REF_CURRENT CHECK (IS_CURRENT IN ('Y', 'N'))
);

-- Pipe Element References
CREATE TABLE PIPE_ELEMENT_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    ELEMENT_NAME       VARCHAR2(100),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    ETL_RUN_ID         NUMBER,
    EXTRACTION_DATE    DATE DEFAULT SYSDATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    CONSTRAINT PK_PIPE_ELEM_REF PRIMARY KEY (PLANT_ID, ISSUE_REVISION, ELEMENT_NAME, EXTRACTION_DATE),
    CONSTRAINT CHK_PIPE_ELEM_REF_CURRENT CHECK (IS_CURRENT IN ('Y', 'N'))
);

-- =====================================================
-- STEP 6: CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Master table indexes
CREATE INDEX IDX_OPERATORS_CURRENT ON OPERATORS(IS_CURRENT);
CREATE INDEX IDX_PLANTS_CURRENT ON PLANTS(IS_CURRENT);
CREATE INDEX IDX_PLANTS_OPERATOR ON PLANTS(OPERATOR_ID, IS_CURRENT);
CREATE INDEX IDX_ISSUES_CURRENT ON ISSUES(IS_CURRENT);
CREATE INDEX IDX_ISSUES_PLANT ON ISSUES(PLANT_ID, IS_CURRENT);

-- Reference table indexes
CREATE INDEX IDX_PCS_REF_CURRENT ON PCS_REFERENCES(IS_CURRENT);
CREATE INDEX IDX_PCS_REF_PLANT ON PCS_REFERENCES(PLANT_ID, IS_CURRENT);
CREATE INDEX IDX_SC_REF_CURRENT ON SC_REFERENCES(IS_CURRENT);
CREATE INDEX IDX_SC_REF_PLANT ON SC_REFERENCES(PLANT_ID, IS_CURRENT);
CREATE INDEX IDX_VSM_REF_CURRENT ON VSM_REFERENCES(IS_CURRENT);
CREATE INDEX IDX_VSM_REF_PLANT ON VSM_REFERENCES(PLANT_ID, IS_CURRENT);

-- Control table indexes
CREATE INDEX IDX_ETL_CONTROL_STATUS ON ETL_CONTROL(STATUS);
CREATE INDEX IDX_ETL_CONTROL_DATE ON ETL_CONTROL(START_TIME);
CREATE INDEX IDX_ETL_ENDPOINT_RUN ON ETL_ENDPOINT_LOG(ETL_RUN_ID);
CREATE INDEX IDX_ETL_ERROR_RUN ON ETL_ERROR_LOG(ETL_RUN_ID);
CREATE INDEX IDX_ETL_PLANT_ACTIVE ON ETL_PLANT_LOADER(IS_ACTIVE, LOAD_PRIORITY);

-- =====================================================
-- STEP 7: CREATE VIEWS FOR EASIER QUERYING
-- =====================================================

-- View for current operators
CREATE OR REPLACE VIEW V_CURRENT_OPERATORS AS
SELECT OPERATOR_ID, OPERATOR_NAME, ETL_RUN_ID, EXTRACTION_DATE
FROM OPERATORS
WHERE IS_CURRENT = 'Y';

-- View for current plants
CREATE OR REPLACE VIEW V_CURRENT_PLANTS AS
SELECT PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID, 
       COMMON_LIB_PLANT_CODE, ETL_RUN_ID, EXTRACTION_DATE
FROM PLANTS
WHERE IS_CURRENT = 'Y';

-- View for current issues
CREATE OR REPLACE VIEW V_CURRENT_ISSUES AS
SELECT PLANT_ID, ISSUE_REVISION, USER_NAME, USER_ENTRY_TIME, 
       USER_PROTECTED, ETL_RUN_ID, EXTRACTION_DATE
FROM ISSUES
WHERE IS_CURRENT = 'Y';

-- View for active ETL plants with details
CREATE OR REPLACE VIEW V_ACTIVE_ETL_PLANTS AS
SELECT 
    L.PLANT_ID,
    L.PLANT_NAME,
    L.LOAD_PRIORITY,
    L.NOTES,
    P.LONG_DESCRIPTION,
    P.OPERATOR_ID,
    (SELECT COUNT(*) FROM ISSUES I WHERE I.PLANT_ID = L.PLANT_ID AND I.IS_CURRENT = 'Y') AS ISSUE_COUNT
FROM ETL_PLANT_LOADER L
LEFT JOIN PLANTS P ON L.PLANT_ID = P.PLANT_ID AND P.IS_CURRENT = 'Y'
WHERE L.IS_ACTIVE = 'Y'
ORDER BY L.LOAD_PRIORITY, L.PLANT_ID;

-- =====================================================
-- STEP 8: GRANT PERMISSIONS (Adjust as needed)
-- =====================================================

-- Example: Grant permissions to application user
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES TO APP_USER;

-- =====================================================
-- STEP 9: INSERT INITIAL DATA (Optional)
-- =====================================================

-- Insert some initial plants for testing (adjust as needed)
-- Oracle requires separate INSERT statements or INSERT ALL syntax
INSERT INTO ETL_PLANT_LOADER (PLANT_ID, PLANT_NAME, LOAD_PRIORITY, NOTES) 
VALUES ('34', 'Gullfaks A', 10, 'High priority - active project');

INSERT INTO ETL_PLANT_LOADER (PLANT_ID, PLANT_NAME, LOAD_PRIORITY, NOTES) 
VALUES ('47', 'Oseberg Øst', 20, 'Active development');

INSERT INTO ETL_PLANT_LOADER (PLANT_ID, PLANT_NAME, LOAD_PRIORITY, NOTES) 
VALUES ('92', 'Åsgard B', 30, 'Regular updates needed');

COMMIT;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check all tables created
SELECT table_name FROM user_tables ORDER BY table_name;

-- Check all sequences created
SELECT sequence_name FROM user_sequences ORDER BY sequence_name;

-- Check all indexes created
SELECT index_name, table_name FROM user_indexes ORDER BY table_name, index_name;

-- Check all views created
SELECT view_name FROM user_views ORDER BY view_name;

-- Display completion message
DECLARE
    v_table_count NUMBER;
    v_view_count NUMBER;
    v_index_count NUMBER;
    v_sequence_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_count FROM user_tables;
    SELECT COUNT(*) INTO v_view_count FROM user_views;
    SELECT COUNT(*) INTO v_index_count FROM user_indexes;
    SELECT COUNT(*) INTO v_sequence_count FROM user_sequences;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('TR2000 STAGING DATABASE CREATION COMPLETE');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Tables created: ' || v_table_count);
    DBMS_OUTPUT.PUT_LINE('Views created: ' || v_view_count);
    DBMS_OUTPUT.PUT_LINE('Indexes created: ' || v_index_count);
    DBMS_OUTPUT.PUT_LINE('Sequences created: ' || v_sequence_count);
    DBMS_OUTPUT.PUT_LINE('===============================================');
END;
/