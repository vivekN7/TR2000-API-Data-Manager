-- =====================================================
-- TR2000 STAGING DATABASE - SCD TYPE 2 IMPLEMENTATION
-- Database: Oracle 
-- Schema: TR2000_STAGING
-- Version: 5.0 - Full SCD Type 2 with Hash-based Change Detection
-- Updated: 2025-08-17
-- 
-- Key Changes:
-- 1. Added SRC_HASH for change detection
-- 2. Added VALID_FROM/VALID_TO for temporal tracking
-- 3. Removed EXTRACTION_DATE (replaced by VALID_FROM)
-- 4. Added staging tables for ETL processing
-- =====================================================

SET SERVEROUTPUT ON;

-- =====================================================
-- STEP 1: DROP ALL EXISTING OBJECTS (SAFE)
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
    
    -- Drop Tables
    FOR t IN (SELECT table_name FROM user_tables)
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
            DBMS_OUTPUT.PUT_LINE('Dropped table: ' || t.table_name);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    
    -- Drop Sequences
    FOR s IN (SELECT sequence_name FROM user_sequences)
    LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
            DBMS_OUTPUT.PUT_LINE('Dropped sequence: ' || s.sequence_name);
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
    RECORDS_UPDATED    NUMBER,          -- New: track updates vs inserts
    RECORDS_UNCHANGED  NUMBER,          -- New: track unchanged records
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
-- Used for temporary storage during ETL processing
-- =====================================================

-- Staging table for Operators
CREATE TABLE STG_OPERATORS (
    OPERATOR_ID        NUMBER NOT NULL,
    OPERATOR_NAME      VARCHAR2(200),
    SRC_HASH           VARCHAR2(64),    -- SHA256 hash of business columns
    ETL_RUN_ID         NUMBER
);

-- Staging table for Plants
CREATE TABLE STG_PLANTS (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    LONG_DESCRIPTION   VARCHAR2(500),
    OPERATOR_ID        NUMBER,
    COMMON_LIB_PLANT_CODE VARCHAR2(20),
    SRC_HASH           VARCHAR2(64),
    ETL_RUN_ID         NUMBER
);

-- Staging table for Issues
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
-- STEP 5: CREATE DIMENSION TABLES (SCD Type 2)
-- =====================================================

-- Operators Dimension Table (SCD Type 2)
CREATE TABLE DIM_OPERATORS (
    OPERATOR_KEY       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- Surrogate key
    OPERATOR_ID        NUMBER NOT NULL,                                  -- Business key
    OPERATOR_NAME      VARCHAR2(200),
    SRC_HASH           VARCHAR2(64),                                     -- For change detection
    VALID_FROM         DATE NOT NULL,                                    -- SCD2 effective date
    VALID_TO           DATE,                                             -- SCD2 expiry date (NULL = current)
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT UK_DIM_OPERATORS UNIQUE (OPERATOR_ID, VALID_FROM)
);

-- Plants Dimension Table (SCD Type 2)
CREATE TABLE DIM_PLANTS (
    PLANT_KEY          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- Surrogate key
    PLANT_ID           VARCHAR2(50) NOT NULL,                            -- Business key
    PLANT_NAME         VARCHAR2(200),
    LONG_DESCRIPTION   VARCHAR2(500),
    OPERATOR_ID        NUMBER,
    COMMON_LIB_PLANT_CODE VARCHAR2(20),
    SRC_HASH           VARCHAR2(64),
    VALID_FROM         DATE NOT NULL,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT UK_DIM_PLANTS UNIQUE (PLANT_ID, VALID_FROM)
);

-- Issues Dimension Table (SCD Type 2)
CREATE TABLE DIM_ISSUES (
    ISSUE_KEY          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- Surrogate key
    PLANT_ID           VARCHAR2(50) NOT NULL,                            -- Business key part 1
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,                            -- Business key part 2
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    SRC_HASH           VARCHAR2(64),
    VALID_FROM         DATE NOT NULL,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT UK_DIM_ISSUES UNIQUE (PLANT_ID, ISSUE_REVISION, VALID_FROM)
);

-- =====================================================
-- STEP 6: CREATE FACT/REFERENCE TABLES (SCD Type 2)
-- =====================================================

-- PCS References Fact Table (SCD Type 2)
CREATE TABLE FACT_PCS_REFERENCES (
    PCS_REF_KEY        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    PCS_NAME           VARCHAR2(100),
    PCS_REVISION       VARCHAR2(20),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     CHAR(1),
    SRC_HASH           VARCHAR2(64),
    VALID_FROM         DATE NOT NULL,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    ETL_RUN_ID         NUMBER,
    CONSTRAINT UK_FACT_PCS_REF UNIQUE (PLANT_ID, ISSUE_REVISION, PCS_NAME, PCS_REVISION, VALID_FROM)
);

-- Similar structure for other reference tables...
-- (SC, VSM, VDS, EDS, MDS, VSK, ESK, PIPE_ELEMENT)

-- =====================================================
-- STEP 7: CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Current record lookups (most common query pattern)
CREATE INDEX IDX_DIM_OPERATORS_CURRENT ON DIM_OPERATORS(OPERATOR_ID, IS_CURRENT);
CREATE INDEX IDX_DIM_PLANTS_CURRENT ON DIM_PLANTS(PLANT_ID, IS_CURRENT);
CREATE INDEX IDX_DIM_ISSUES_CURRENT ON DIM_ISSUES(PLANT_ID, ISSUE_REVISION, IS_CURRENT);

-- Hash comparison indexes (for change detection)
CREATE INDEX IDX_DIM_OPERATORS_HASH ON DIM_OPERATORS(OPERATOR_ID, SRC_HASH) WHERE IS_CURRENT = 'Y';
CREATE INDEX IDX_DIM_PLANTS_HASH ON DIM_PLANTS(PLANT_ID, SRC_HASH) WHERE IS_CURRENT = 'Y';
CREATE INDEX IDX_DIM_ISSUES_HASH ON DIM_ISSUES(PLANT_ID, ISSUE_REVISION, SRC_HASH) WHERE IS_CURRENT = 'Y';

-- Temporal query indexes
CREATE INDEX IDX_DIM_OPERATORS_TEMPORAL ON DIM_OPERATORS(OPERATOR_ID, VALID_FROM, VALID_TO);
CREATE INDEX IDX_DIM_PLANTS_TEMPORAL ON DIM_PLANTS(PLANT_ID, VALID_FROM, VALID_TO);
CREATE INDEX IDX_DIM_ISSUES_TEMPORAL ON DIM_ISSUES(PLANT_ID, ISSUE_REVISION, VALID_FROM, VALID_TO);

-- Control table indexes
CREATE INDEX IDX_ETL_CONTROL_STATUS ON ETL_CONTROL(STATUS);
CREATE INDEX IDX_ETL_CONTROL_DATE ON ETL_CONTROL(START_TIME);
CREATE INDEX IDX_ETL_PLANT_ACTIVE ON ETL_PLANT_LOADER(IS_ACTIVE, LOAD_PRIORITY);

-- =====================================================
-- STEP 8: CREATE VIEWS FOR CURRENT DATA
-- =====================================================

-- View for current operators (most common use case)
CREATE OR REPLACE VIEW V_CURRENT_OPERATORS AS
SELECT OPERATOR_ID, OPERATOR_NAME, ETL_RUN_ID, VALID_FROM
FROM DIM_OPERATORS
WHERE IS_CURRENT = 'Y';

-- View for current plants
CREATE OR REPLACE VIEW V_CURRENT_PLANTS AS
SELECT PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID, 
       COMMON_LIB_PLANT_CODE, ETL_RUN_ID, VALID_FROM
FROM DIM_PLANTS
WHERE IS_CURRENT = 'Y';

-- View for current issues
CREATE OR REPLACE VIEW V_CURRENT_ISSUES AS
SELECT PLANT_ID, ISSUE_REVISION, USER_NAME, USER_ENTRY_TIME, 
       USER_PROTECTED, ETL_RUN_ID, VALID_FROM
FROM DIM_ISSUES
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
    (SELECT COUNT(*) FROM DIM_ISSUES I 
     WHERE I.PLANT_ID = L.PLANT_ID AND I.IS_CURRENT = 'Y') AS ISSUE_COUNT
FROM ETL_PLANT_LOADER L
LEFT JOIN DIM_PLANTS P ON L.PLANT_ID = P.PLANT_ID AND P.IS_CURRENT = 'Y'
WHERE L.IS_ACTIVE = 'Y'
ORDER BY L.LOAD_PRIORITY, L.PLANT_ID;

-- =====================================================
-- STEP 9: CREATE STORED PROCEDURES FOR SCD2 LOGIC
-- =====================================================

-- Procedure to compute hash for operators
CREATE OR REPLACE FUNCTION COMPUTE_OPERATOR_HASH(
    p_operator_id NUMBER,
    p_operator_name VARCHAR2
) RETURN VARCHAR2
AS
BEGIN
    RETURN STANDARD_HASH(
        NVL(TO_CHAR(p_operator_id), '~') || '|' ||
        NVL(LOWER(TRIM(p_operator_name)), '~'),
        'SHA256'
    );
END;
/

-- Procedure to compute hash for plants
CREATE OR REPLACE FUNCTION COMPUTE_PLANT_HASH(
    p_plant_id VARCHAR2,
    p_plant_name VARCHAR2,
    p_long_desc VARCHAR2,
    p_operator_id NUMBER,
    p_common_lib VARCHAR2
) RETURN VARCHAR2
AS
BEGIN
    RETURN STANDARD_HASH(
        NVL(LOWER(TRIM(p_plant_id)), '~') || '|' ||
        NVL(LOWER(TRIM(p_plant_name)), '~') || '|' ||
        NVL(LOWER(TRIM(p_long_desc)), '~') || '|' ||
        NVL(TO_CHAR(p_operator_id), '~') || '|' ||
        NVL(LOWER(TRIM(p_common_lib)), '~'),
        'SHA256'
    );
END;
/

-- Procedure to process SCD2 for operators
CREATE OR REPLACE PROCEDURE PROCESS_OPERATORS_SCD2(
    p_etl_run_id NUMBER
)
AS
    v_count_new NUMBER := 0;
    v_count_changed NUMBER := 0;
    v_count_unchanged NUMBER := 0;
BEGIN
    -- Step 1: Identify and count unchanged records
    SELECT COUNT(*)
    INTO v_count_unchanged
    FROM STG_OPERATORS s
    INNER JOIN DIM_OPERATORS d ON d.OPERATOR_ID = s.OPERATOR_ID
    WHERE d.IS_CURRENT = 'Y'
      AND d.SRC_HASH = s.SRC_HASH;
    
    -- Step 2: Expire changed records
    UPDATE DIM_OPERATORS d
    SET d.VALID_TO = SYSDATE, 
        d.IS_CURRENT = 'N'
    WHERE d.IS_CURRENT = 'Y'
      AND EXISTS (
        SELECT 1 FROM STG_OPERATORS s
        WHERE s.OPERATOR_ID = d.OPERATOR_ID
          AND s.SRC_HASH != d.SRC_HASH
      );
    
    v_count_changed := SQL%ROWCOUNT;
    
    -- Step 3: Insert new versions for changed records
    INSERT INTO DIM_OPERATORS (OPERATOR_ID, OPERATOR_NAME, SRC_HASH, 
                               VALID_FROM, VALID_TO, IS_CURRENT, ETL_RUN_ID)
    SELECT s.OPERATOR_ID, s.OPERATOR_NAME, s.SRC_HASH,
           SYSDATE, NULL, 'Y', p_etl_run_id
    FROM STG_OPERATORS s
    INNER JOIN DIM_OPERATORS d ON d.OPERATOR_ID = s.OPERATOR_ID
    WHERE d.VALID_TO = SYSDATE  -- Just expired
      AND s.SRC_HASH != d.SRC_HASH;
    
    -- Step 4: Insert completely new records
    INSERT INTO DIM_OPERATORS (OPERATOR_ID, OPERATOR_NAME, SRC_HASH, 
                               VALID_FROM, VALID_TO, IS_CURRENT, ETL_RUN_ID)
    SELECT s.OPERATOR_ID, s.OPERATOR_NAME, s.SRC_HASH,
           SYSDATE, NULL, 'Y', p_etl_run_id
    FROM STG_OPERATORS s
    WHERE NOT EXISTS (
        SELECT 1 FROM DIM_OPERATORS d
        WHERE d.OPERATOR_ID = s.OPERATOR_ID
    );
    
    v_count_new := SQL%ROWCOUNT;
    
    -- Update ETL Control with counts
    UPDATE ETL_CONTROL
    SET RECORDS_LOADED = v_count_new,
        RECORDS_UPDATED = v_count_changed,
        RECORDS_UNCHANGED = v_count_unchanged
    WHERE ETL_RUN_ID = p_etl_run_id;
    
    COMMIT;
END;
/

-- =====================================================
-- STEP 10: INSERT INITIAL DATA
-- =====================================================

-- Insert some initial plants for testing
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
BEGIN
    SELECT COUNT(*) INTO v_table_count FROM user_tables;
    SELECT COUNT(*) INTO v_view_count FROM user_views;
    SELECT COUNT(*) INTO v_index_count FROM user_indexes;
    SELECT COUNT(*) INTO v_sequence_count FROM user_sequences;
    
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('TR2000 SCD2 DATABASE CREATION COMPLETE');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Tables created: ' || v_table_count);
    DBMS_OUTPUT.PUT_LINE('Views created: ' || v_view_count);
    DBMS_OUTPUT.PUT_LINE('Indexes created: ' || v_index_count);
    DBMS_OUTPUT.PUT_LINE('Sequences created: ' || v_sequence_count);
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Key Features:');
    DBMS_OUTPUT.PUT_LINE('- SCD Type 2 with VALID_FROM/VALID_TO');
    DBMS_OUTPUT.PUT_LINE('- Hash-based change detection');
    DBMS_OUTPUT.PUT_LINE('- Staging tables for ETL processing');
    DBMS_OUTPUT.PUT_LINE('- Stored procedures for SCD2 logic');
    DBMS_OUTPUT.PUT_LINE('===============================================');
END;
/