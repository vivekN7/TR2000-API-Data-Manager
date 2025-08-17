-- =====================================================
-- TR2000 STAGING DATABASE - SCD TYPE 2 (SIMPLIFIED)
-- Database: Oracle 
-- Schema: TR2000_STAGING
-- Version: SCD2 Simple - Using ORA_HASH for compatibility
-- Updated: 2025-08-17
-- 
-- This version uses ORA_HASH which works on all Oracle versions
-- =====================================================

SET SERVEROUTPUT ON;

-- =====================================================
-- STEP 1: DROP ALL EXISTING OBJECTS
-- =====================================================

BEGIN
    -- Drop all views
    FOR v IN (SELECT view_name FROM user_views) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
            DBMS_OUTPUT.PUT_LINE('Dropped view: ' || v.view_name);
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

-- ETL Control Table
CREATE TABLE ETL_CONTROL (
    ETL_RUN_ID         NUMBER DEFAULT ETL_RUN_ID_SEQ.NEXTVAL PRIMARY KEY,
    RUN_TYPE           VARCHAR2(50),
    STATUS             VARCHAR2(20),
    START_TIME         DATE,
    END_TIME           DATE,
    RECORDS_LOADED     NUMBER DEFAULT 0,
    RECORDS_UPDATED    NUMBER DEFAULT 0,
    RECORDS_UNCHANGED  NUMBER DEFAULT 0,
    ERROR_COUNT        NUMBER DEFAULT 0,
    API_CALL_COUNT     NUMBER DEFAULT 0,
    COMMENTS           VARCHAR2(500)
);

-- ETL Endpoint Log
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

-- ETL Error Log
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
    LOAD_PRIORITY      NUMBER DEFAULT 100,
    NOTES              VARCHAR2(500),
    CREATED_DATE       DATE DEFAULT SYSDATE,
    CREATED_BY         VARCHAR2(100) DEFAULT USER,
    MODIFIED_DATE      DATE DEFAULT SYSDATE,
    MODIFIED_BY        VARCHAR2(100) DEFAULT USER,
    CONSTRAINT PK_ETL_PLANT_LOADER PRIMARY KEY (PLANT_ID)
);

-- =====================================================
-- STEP 4: CREATE STAGING TABLES
-- =====================================================

-- Staging for Operators
CREATE TABLE STG_OPERATORS (
    OPERATOR_ID        NUMBER NOT NULL,
    OPERATOR_NAME      VARCHAR2(200),
    SRC_HASH           VARCHAR2(64),
    ETL_RUN_ID         NUMBER
);

-- Staging for Plants  
CREATE TABLE STG_PLANTS (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    LONG_DESCRIPTION   VARCHAR2(500),
    OPERATOR_ID        NUMBER,
    COMMON_LIB_PLANT_CODE VARCHAR2(20),
    SRC_HASH           VARCHAR2(64),
    ETL_RUN_ID         NUMBER
);

-- Staging for Issues
CREATE TABLE STG_ISSUES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    SRC_HASH           VARCHAR2(64),
    ETL_RUN_ID         NUMBER
);

-- =====================================================
-- STEP 5: CREATE MAIN TABLES WITH SCD2
-- =====================================================

-- Operators (SCD Type 2)
CREATE TABLE OPERATORS (
    OPERATOR_KEY       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    OPERATOR_ID        NUMBER NOT NULL,
    OPERATOR_NAME      VARCHAR2(200),
    SRC_HASH           VARCHAR2(64),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT UK_OPERATORS UNIQUE (OPERATOR_ID, VALID_FROM)
);

-- Plants (SCD Type 2)
CREATE TABLE PLANTS (
    PLANT_KEY          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    LONG_DESCRIPTION   VARCHAR2(500),
    OPERATOR_ID        NUMBER,
    COMMON_LIB_PLANT_CODE VARCHAR2(20),
    SRC_HASH           VARCHAR2(64),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT UK_PLANTS UNIQUE (PLANT_ID, VALID_FROM)
);

-- Issues (SCD Type 2)
CREATE TABLE ISSUES (
    ISSUE_KEY          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    SRC_HASH           VARCHAR2(64),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT UK_ISSUES UNIQUE (PLANT_ID, ISSUE_REVISION, VALID_FROM)
);

-- Reference tables (simplified for now)
CREATE TABLE PCS_REFERENCES (
    PCS_REF_KEY        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    PCS_NAME           VARCHAR2(100),
    PCS_REVISION       VARCHAR2(20),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    SRC_HASH           VARCHAR2(64),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT UK_PCS_REF UNIQUE (PLANT_ID, ISSUE_REVISION, PCS_NAME, PCS_REVISION, VALID_FROM)
);

-- =====================================================
-- STEP 6: CREATE INDEXES
-- =====================================================

-- Current record lookups (most common pattern)
CREATE INDEX IDX_OPERATORS_CURRENT ON OPERATORS(OPERATOR_ID, IS_CURRENT);
CREATE INDEX IDX_PLANTS_CURRENT ON PLANTS(PLANT_ID, IS_CURRENT);
CREATE INDEX IDX_ISSUES_CURRENT ON ISSUES(PLANT_ID, ISSUE_REVISION, IS_CURRENT);
CREATE INDEX IDX_PCS_REF_CURRENT ON PCS_REFERENCES(PLANT_ID, IS_CURRENT);

-- Hash lookups for change detection
CREATE INDEX IDX_OPERATORS_HASH ON OPERATORS(OPERATOR_ID, SRC_HASH, IS_CURRENT);
CREATE INDEX IDX_PLANTS_HASH ON PLANTS(PLANT_ID, SRC_HASH, IS_CURRENT);
CREATE INDEX IDX_ISSUES_HASH ON ISSUES(PLANT_ID, ISSUE_REVISION, SRC_HASH, IS_CURRENT);

-- Control tables
CREATE INDEX IDX_ETL_CONTROL_STATUS ON ETL_CONTROL(STATUS);
CREATE INDEX IDX_ETL_CONTROL_DATE ON ETL_CONTROL(START_TIME);
CREATE INDEX IDX_ETL_PLANT_ACTIVE ON ETL_PLANT_LOADER(IS_ACTIVE, LOAD_PRIORITY);

-- =====================================================
-- STEP 7: CREATE VIEWS
-- =====================================================

-- Current operators view
CREATE OR REPLACE VIEW V_CURRENT_OPERATORS AS
SELECT OPERATOR_ID, OPERATOR_NAME, ETL_RUN_ID, VALID_FROM
FROM OPERATORS
WHERE IS_CURRENT = 'Y';

-- Current plants view
CREATE OR REPLACE VIEW V_CURRENT_PLANTS AS
SELECT PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID, 
       COMMON_LIB_PLANT_CODE, ETL_RUN_ID, VALID_FROM
FROM PLANTS
WHERE IS_CURRENT = 'Y';

-- Current issues view
CREATE OR REPLACE VIEW V_CURRENT_ISSUES AS
SELECT PLANT_ID, ISSUE_REVISION, USER_NAME, USER_ENTRY_TIME, 
       USER_PROTECTED, ETL_RUN_ID, VALID_FROM
FROM ISSUES
WHERE IS_CURRENT = 'Y';

-- Active ETL plants
CREATE OR REPLACE VIEW V_ACTIVE_ETL_PLANTS AS
SELECT 
    L.PLANT_ID,
    L.PLANT_NAME,
    L.LOAD_PRIORITY,
    L.NOTES,
    P.LONG_DESCRIPTION,
    P.OPERATOR_ID,
    (SELECT COUNT(*) FROM ISSUES I 
     WHERE I.PLANT_ID = L.PLANT_ID AND I.IS_CURRENT = 'Y') AS ISSUE_COUNT
FROM ETL_PLANT_LOADER L
LEFT JOIN PLANTS P ON L.PLANT_ID = P.PLANT_ID AND P.IS_CURRENT = 'Y'
WHERE L.IS_ACTIVE = 'Y'
ORDER BY L.LOAD_PRIORITY, L.PLANT_ID;

-- ETL Statistics view
CREATE OR REPLACE VIEW V_ETL_STATISTICS AS
SELECT 
    'OPERATORS' as TABLE_NAME,
    COUNT(*) as TOTAL_RECORDS,
    SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_RECORDS,
    SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as HISTORICAL_RECORDS
FROM OPERATORS
UNION ALL
SELECT 
    'PLANTS' as TABLE_NAME,
    COUNT(*) as TOTAL_RECORDS,
    SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_RECORDS,
    SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as HISTORICAL_RECORDS
FROM PLANTS
UNION ALL
SELECT 
    'ISSUES' as TABLE_NAME,
    COUNT(*) as TOTAL_RECORDS,
    SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_RECORDS,
    SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as HISTORICAL_RECORDS
FROM ISSUES;

-- =====================================================
-- STEP 8: CREATE SIMPLE HASH FUNCTIONS (Using ORA_HASH)
-- =====================================================

-- Function to compute operator hash (simplified using ORA_HASH)
CREATE OR REPLACE FUNCTION COMPUTE_OPERATOR_HASH(
    p_operator_id NUMBER,
    p_operator_name VARCHAR2
) RETURN VARCHAR2
DETERMINISTIC
AS
    v_input VARCHAR2(4000);
BEGIN
    v_input := NVL(TO_CHAR(p_operator_id), '~') || '|' ||
               NVL(LOWER(TRIM(p_operator_name)), '~');
    
    -- ORA_HASH returns a number, convert to string
    -- Using two hashes with different seeds for better distribution
    RETURN TO_CHAR(ORA_HASH(v_input, 999999999)) || 
           TO_CHAR(ORA_HASH(v_input, 888888888));
END;
/

-- Function to compute plant hash
CREATE OR REPLACE FUNCTION COMPUTE_PLANT_HASH(
    p_plant_id VARCHAR2,
    p_plant_name VARCHAR2,
    p_long_desc VARCHAR2,
    p_operator_id NUMBER,
    p_common_lib VARCHAR2
) RETURN VARCHAR2
DETERMINISTIC
AS
    v_input VARCHAR2(4000);
BEGIN
    v_input := NVL(LOWER(TRIM(p_plant_id)), '~') || '|' ||
               NVL(LOWER(TRIM(p_plant_name)), '~') || '|' ||
               NVL(LOWER(TRIM(p_long_desc)), '~') || '|' ||
               NVL(TO_CHAR(p_operator_id), '~') || '|' ||
               NVL(LOWER(TRIM(p_common_lib)), '~');
    
    RETURN TO_CHAR(ORA_HASH(v_input, 999999999)) || 
           TO_CHAR(ORA_HASH(v_input, 888888888));
END;
/

-- Function to compute issue hash
CREATE OR REPLACE FUNCTION COMPUTE_ISSUE_HASH(
    p_plant_id VARCHAR2,
    p_issue_revision VARCHAR2,
    p_user_name VARCHAR2,
    p_user_entry_time DATE,
    p_user_protected CHAR
) RETURN VARCHAR2
DETERMINISTIC
AS
    v_input VARCHAR2(4000);
BEGIN
    v_input := NVL(LOWER(TRIM(p_plant_id)), '~') || '|' ||
               NVL(LOWER(TRIM(p_issue_revision)), '~') || '|' ||
               NVL(LOWER(TRIM(p_user_name)), '~') || '|' ||
               NVL(TO_CHAR(p_user_entry_time, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
               NVL(p_user_protected, '~');
    
    RETURN TO_CHAR(ORA_HASH(v_input, 999999999)) || 
           TO_CHAR(ORA_HASH(v_input, 888888888));
END;
/

-- =====================================================
-- STEP 9: INITIAL DATA
-- =====================================================

-- Insert test plants for loader
INSERT INTO ETL_PLANT_LOADER (PLANT_ID, PLANT_NAME, LOAD_PRIORITY, NOTES) 
VALUES ('34', 'Gullfaks A', 10, 'High priority - active project');

INSERT INTO ETL_PLANT_LOADER (PLANT_ID, PLANT_NAME, LOAD_PRIORITY, NOTES) 
VALUES ('47', 'Oseberg Øst', 20, 'Active development');

INSERT INTO ETL_PLANT_LOADER (PLANT_ID, PLANT_NAME, LOAD_PRIORITY, NOTES) 
VALUES ('92', 'Åsgard B', 30, 'Regular updates needed');

COMMIT;

-- =====================================================
-- VERIFICATION
-- =====================================================

DECLARE
    v_table_count NUMBER;
    v_view_count NUMBER;
    v_index_count NUMBER;
    v_sequence_count NUMBER;
    v_function_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_count FROM user_tables;
    SELECT COUNT(*) INTO v_view_count FROM user_views;
    SELECT COUNT(*) INTO v_index_count FROM user_indexes;
    SELECT COUNT(*) INTO v_sequence_count FROM user_sequences;
    SELECT COUNT(*) INTO v_function_count FROM user_objects WHERE object_type = 'FUNCTION';
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('TR2000 SCD2 DATABASE CREATION COMPLETE');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Tables created: ' || v_table_count);
    DBMS_OUTPUT.PUT_LINE('Views created: ' || v_view_count);
    DBMS_OUTPUT.PUT_LINE('Indexes created: ' || v_index_count);
    DBMS_OUTPUT.PUT_LINE('Sequences created: ' || v_sequence_count);
    DBMS_OUTPUT.PUT_LINE('Functions created: ' || v_function_count);
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Key Features:');
    DBMS_OUTPUT.PUT_LINE('✓ SCD Type 2 with VALID_FROM/VALID_TO');
    DBMS_OUTPUT.PUT_LINE('✓ Hash using ORA_HASH (compatible with all Oracle versions)');
    DBMS_OUTPUT.PUT_LINE('✓ Staging tables for ETL processing');
    DBMS_OUTPUT.PUT_LINE('✓ Performance indexes on all key columns');
    DBMS_OUTPUT.PUT_LINE('===============================================');
END;
/

-- Test the hash functions
SELECT 'Testing hash functions:' as INFO FROM DUAL;
SELECT COMPUTE_OPERATOR_HASH(1, 'Test Operator') as OPERATOR_HASH FROM DUAL;
SELECT COMPUTE_PLANT_HASH('34', 'Test Plant', 'Long Description', 1, 'ABC') as PLANT_HASH FROM DUAL;
SELECT COMPUTE_ISSUE_HASH('34', '1', 'User', SYSDATE, 'Y') as ISSUE_HASH FROM DUAL;