-- =====================================================
-- TR2000 STAGING DATABASE - SCD TYPE 2 WITH NATIVE HASH
-- Database: Oracle 21c Express Edition
-- Schema: TR2000_STAGING  
-- Version: SCD2 with Oracle-native STANDARD_HASH (SAFE VERSION)
-- Updated: 2025-08-17
-- 
-- This DDL implements SAFE SCD Type 2 with:
-- - Oracle-native STANDARD_HASH for change detection
-- - On-the-fly hash computation (detects manual DB changes)
-- - Self-healing: Corrects data corruption automatically
-- - VALID_FROM/VALID_TO for temporal tracking
-- - IS_CURRENT flag for easy current record queries
-- - Optimized indexes for performance
--
-- IMPORTANT: Stored procedures compare ACTUAL DATA, not stored hashes
-- This ensures manual database changes are detected and corrected
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
    
    -- Drop all procedures
    FOR p IN (SELECT object_name FROM user_objects WHERE object_type = 'PROCEDURE') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP PROCEDURE ' || p.object_name;
            DBMS_OUTPUT.PUT_LINE('Dropped procedure: ' || p.object_name);
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
    ETL_RUN_ID         NUMBER
);

-- Staging for Plants  
CREATE TABLE STG_PLANTS (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    LONG_DESCRIPTION   VARCHAR2(500),
    OPERATOR_ID        NUMBER,
    COMMON_LIB_PLANT_CODE VARCHAR2(20),
    ETL_RUN_ID         NUMBER
);

-- Staging for Issues
CREATE TABLE STG_ISSUES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER
);

-- Staging for PCS References
CREATE TABLE STG_PCS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    PCS_NAME           VARCHAR2(100),
    PCS_REVISION       VARCHAR2(20),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    ETL_RUN_ID         NUMBER
);

-- =====================================================
-- STEP 5: CREATE DIMENSION TABLES (SCD TYPE 2)
-- =====================================================

-- OPERATORS Dimension (SCD Type 2)
CREATE TABLE OPERATORS (
    OPERATOR_ID        NUMBER NOT NULL,
    OPERATOR_NAME      VARCHAR2(200),
    SRC_HASH           RAW(32),  -- Oracle-native hash
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_OPERATORS PRIMARY KEY (OPERATOR_ID, VALID_FROM)
);

-- PLANTS Dimension (SCD Type 2)
CREATE TABLE PLANTS (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    LONG_DESCRIPTION   VARCHAR2(500),
    OPERATOR_ID        NUMBER,
    COMMON_LIB_PLANT_CODE VARCHAR2(20),
    SRC_HASH           RAW(32),  -- Oracle-native hash
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_PLANTS PRIMARY KEY (PLANT_ID, VALID_FROM)
);

-- ISSUES Dimension (SCD Type 2)
CREATE TABLE ISSUES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),  -- Oracle-native hash
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_ISSUES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VALID_FROM)
);

-- PCS_REFERENCES Dimension (SCD Type 2)
CREATE TABLE PCS_REFERENCES (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    ISSUE_REVISION     VARCHAR2(20) NOT NULL,
    PCS_NAME           VARCHAR2(100),
    PCS_REVISION       VARCHAR2(20),
    USER_NAME          VARCHAR2(100),
    USER_ENTRY_TIME    DATE,
    USER_PROTECTED     VARCHAR2(20),
    SRC_HASH           RAW(32),  -- Oracle-native hash
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_PCS_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, PCS_NAME, PCS_REVISION, VALID_FROM)
);

-- SC_REFERENCES Dimension (SCD Type 2)
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
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_SC_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, SC_NAME, SC_REVISION, VALID_FROM)
);

-- VSM_REFERENCES Dimension (SCD Type 2)
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
    IS_CURRENT         CHAR(1) DEFAULT 'Y',
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_VSM_REFERENCES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VSM_NAME, VSM_REVISION, VALID_FROM)
);

-- =====================================================
-- STEP 6: CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Indexes for current record lookups
CREATE INDEX IX_OPERATORS_CURRENT ON OPERATORS(OPERATOR_ID, IS_CURRENT);
CREATE INDEX IX_PLANTS_CURRENT ON PLANTS(PLANT_ID, IS_CURRENT);
CREATE INDEX IX_ISSUES_CURRENT ON ISSUES(PLANT_ID, ISSUE_REVISION, IS_CURRENT);
CREATE INDEX IX_PCS_REF_CURRENT ON PCS_REFERENCES(PLANT_ID, ISSUE_REVISION, IS_CURRENT);

-- Indexes for hash comparisons
CREATE INDEX IX_OPERATORS_HASH ON OPERATORS(OPERATOR_ID, SRC_HASH) WHERE IS_CURRENT = 'Y';
CREATE INDEX IX_PLANTS_HASH ON PLANTS(PLANT_ID, SRC_HASH) WHERE IS_CURRENT = 'Y';
CREATE INDEX IX_ISSUES_HASH ON ISSUES(PLANT_ID, ISSUE_REVISION, SRC_HASH) WHERE IS_CURRENT = 'Y';

-- Indexes for temporal queries
CREATE INDEX IX_OPERATORS_TEMPORAL ON OPERATORS(OPERATOR_ID, VALID_FROM, VALID_TO);
CREATE INDEX IX_PLANTS_TEMPORAL ON PLANTS(PLANT_ID, VALID_FROM, VALID_TO);
CREATE INDEX IX_ISSUES_TEMPORAL ON ISSUES(PLANT_ID, ISSUE_REVISION, VALID_FROM, VALID_TO);

-- =====================================================
-- STEP 7: CREATE VIEWS FOR CURRENT DATA
-- =====================================================

-- Current Operators View
CREATE OR REPLACE VIEW V_OPERATORS_CURRENT AS
SELECT 
    OPERATOR_ID,
    OPERATOR_NAME,
    VALID_FROM,
    ETL_RUN_ID
FROM OPERATORS
WHERE IS_CURRENT = 'Y';

-- Current Plants View
CREATE OR REPLACE VIEW V_PLANTS_CURRENT AS
SELECT 
    PLANT_ID,
    PLANT_NAME,
    LONG_DESCRIPTION,
    OPERATOR_ID,
    COMMON_LIB_PLANT_CODE,
    VALID_FROM,
    ETL_RUN_ID
FROM PLANTS
WHERE IS_CURRENT = 'Y';

-- Current Issues View
CREATE OR REPLACE VIEW V_ISSUES_CURRENT AS
SELECT 
    PLANT_ID,
    ISSUE_REVISION,
    USER_NAME,
    USER_ENTRY_TIME,
    USER_PROTECTED,
    VALID_FROM,
    ETL_RUN_ID
FROM ISSUES
WHERE IS_CURRENT = 'Y';

-- Current PCS References View
CREATE OR REPLACE VIEW V_PCS_REFERENCES_CURRENT AS
SELECT 
    PLANT_ID,
    ISSUE_REVISION,
    PCS_NAME,
    PCS_REVISION,
    USER_NAME,
    USER_ENTRY_TIME,
    USER_PROTECTED,
    VALID_FROM,
    ETL_RUN_ID
FROM PCS_REFERENCES
WHERE IS_CURRENT = 'Y';

-- =====================================================
-- STEP 8: CREATE STORED PROCEDURES FOR SCD2 LOGIC
-- =====================================================

-- Procedure to process OPERATORS with SCD2
CREATE OR REPLACE PROCEDURE SP_PROCESS_OPERATORS_SCD2(
    p_etl_run_id IN NUMBER
) AS
    v_records_unchanged NUMBER := 0;
    v_records_updated   NUMBER := 0;
    v_records_inserted  NUMBER := 0;
BEGIN
    -- Step 1: Identify unchanged records
    -- Compare hash of CURRENT data with hash of STAGING data
    -- This detects both API changes AND manual DB modifications
    SELECT COUNT(*) INTO v_records_unchanged
    FROM STG_OPERATORS s
    INNER JOIN OPERATORS o ON o.OPERATOR_ID = s.OPERATOR_ID
    WHERE o.IS_CURRENT = 'Y'
      -- Compare actual data, not stored hash (detects manual changes)
      AND STANDARD_HASH(
          NVL(TO_CHAR(o.OPERATOR_ID), '~') || '|' ||
          NVL(o.OPERATOR_NAME, '~'),
          'SHA256'
      ) = STANDARD_HASH(
          NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
          NVL(s.OPERATOR_NAME, '~'),
          'SHA256'
      );
    
    -- Step 2: Expire changed records
    -- This catches both API changes AND manual database modifications
    UPDATE OPERATORS o
    SET o.VALID_TO = SYSDATE, 
        o.IS_CURRENT = 'N'
    WHERE o.IS_CURRENT = 'Y'
      AND EXISTS (
        SELECT 1 FROM STG_OPERATORS s
        WHERE s.OPERATOR_ID = o.OPERATOR_ID
          -- Compare actual data, not stored hash
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
    
    -- Step 3: Insert new versions for changed records
    INSERT INTO OPERATORS (
        OPERATOR_ID, OPERATOR_NAME, SRC_HASH, 
        VALID_FROM, IS_CURRENT, ETL_RUN_ID
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
        p_etl_run_id
    FROM STG_OPERATORS s
    WHERE EXISTS (
        SELECT 1 FROM OPERATORS o
        WHERE o.OPERATOR_ID = s.OPERATOR_ID
          AND o.VALID_TO = SYSDATE
    );
    
    -- Step 4: Insert completely new records
    INSERT INTO OPERATORS (
        OPERATOR_ID, OPERATOR_NAME, SRC_HASH,
        VALID_FROM, IS_CURRENT, ETL_RUN_ID
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
        p_etl_run_id
    FROM STG_OPERATORS s
    WHERE NOT EXISTS (
        SELECT 1 FROM OPERATORS o
        WHERE o.OPERATOR_ID = s.OPERATOR_ID
    );
    
    v_records_inserted := SQL%ROWCOUNT;
    
    -- Update ETL Control with counts
    UPDATE ETL_CONTROL
    SET RECORDS_UNCHANGED = v_records_unchanged,
        RECORDS_UPDATED = v_records_updated,
        RECORDS_LOADED = v_records_inserted
    WHERE ETL_RUN_ID = p_etl_run_id;
    
    -- Clear staging table
    DELETE FROM STG_OPERATORS WHERE ETL_RUN_ID = p_etl_run_id;
    
    COMMIT;
END SP_PROCESS_OPERATORS_SCD2;
/

-- Procedure to process PLANTS with SCD2
CREATE OR REPLACE PROCEDURE SP_PROCESS_PLANTS_SCD2(
    p_etl_run_id IN NUMBER
) AS
    v_records_unchanged NUMBER := 0;
    v_records_updated   NUMBER := 0;
    v_records_inserted  NUMBER := 0;
BEGIN
    -- Step 1: Count unchanged records
    -- Compare actual data to detect manual changes
    SELECT COUNT(*) INTO v_records_unchanged
    FROM STG_PLANTS s
    INNER JOIN PLANTS p ON p.PLANT_ID = s.PLANT_ID
    WHERE p.IS_CURRENT = 'Y'
      -- Compare actual data, not stored hash
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
    
    -- Step 2: Expire changed records
    UPDATE PLANTS p
    SET p.VALID_TO = SYSDATE,
        p.IS_CURRENT = 'N'
    WHERE p.IS_CURRENT = 'Y'
      AND EXISTS (
        SELECT 1 FROM STG_PLANTS s
        WHERE s.PLANT_ID = p.PLANT_ID
          -- Compare actual data, not stored hash
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
    
    -- Step 3: Insert new versions for changed records
    INSERT INTO PLANTS (
        PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID,
        COMMON_LIB_PLANT_CODE, SRC_HASH, VALID_FROM, IS_CURRENT, ETL_RUN_ID
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
        p_etl_run_id
    FROM STG_PLANTS s
    WHERE EXISTS (
        SELECT 1 FROM PLANTS p
        WHERE p.PLANT_ID = s.PLANT_ID
          AND p.VALID_TO = SYSDATE
    );
    
    -- Step 4: Insert completely new records
    INSERT INTO PLANTS (
        PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID,
        COMMON_LIB_PLANT_CODE, SRC_HASH, VALID_FROM, IS_CURRENT, ETL_RUN_ID
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
        p_etl_run_id
    FROM STG_PLANTS s
    WHERE NOT EXISTS (
        SELECT 1 FROM PLANTS p
        WHERE p.PLANT_ID = s.PLANT_ID
    );
    
    v_records_inserted := SQL%ROWCOUNT;
    
    -- Update ETL Control
    UPDATE ETL_CONTROL
    SET RECORDS_UNCHANGED = v_records_unchanged,
        RECORDS_UPDATED = v_records_updated,
        RECORDS_LOADED = v_records_inserted
    WHERE ETL_RUN_ID = p_etl_run_id;
    
    -- Clear staging
    DELETE FROM STG_PLANTS WHERE ETL_RUN_ID = p_etl_run_id;
    
    COMMIT;
END SP_PROCESS_PLANTS_SCD2;
/

-- =====================================================
-- STEP 9: GRANT PERMISSIONS (if needed)
-- =====================================================
-- GRANT EXECUTE ON SP_PROCESS_OPERATORS_SCD2 TO TR2000_APP;
-- GRANT EXECUTE ON SP_PROCESS_PLANTS_SCD2 TO TR2000_APP;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check if hash functions work
SELECT 'Hash Test:' as TEST_NAME, 
       STANDARD_HASH('test', 'SHA256') as HASH_VALUE 
FROM DUAL;

-- Show all created objects
SELECT object_type, object_name 
FROM user_objects 
WHERE object_name NOT LIKE 'SYS_%'
ORDER BY object_type, object_name;

COMMIT;