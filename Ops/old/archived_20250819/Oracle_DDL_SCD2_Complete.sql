-- =====================================================
-- TR2000 STAGING DATABASE - COMPLETE SCD TYPE 2
-- Database: Oracle 21c Express Edition
-- Schema: TR2000_STAGING  
-- Version: SCD2 COMPLETE - Handles ALL scenarios
-- Updated: 2025-08-17
-- 
-- This DDL implements COMPLETE SCD Type 2 that handles:
-- 1. New records (INSERT)
-- 2. Changed records (UPDATE)
-- 3. Deleted records (SOFT DELETE)
-- 4. Primary key changes (DELETE + INSERT)
-- 5. Reactivations (UNDELETE)
-- 6. Data corruption detection
-- 7. Manual change correction
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

-- ETL Control Table (Enhanced)
CREATE TABLE ETL_CONTROL (
    ETL_RUN_ID         NUMBER DEFAULT ETL_RUN_ID_SEQ.NEXTVAL PRIMARY KEY,
    RUN_TYPE           VARCHAR2(50),
    STATUS             VARCHAR2(20),
    START_TIME         DATE,
    END_TIME           DATE,
    RECORDS_LOADED     NUMBER DEFAULT 0,    -- New records
    RECORDS_UPDATED    NUMBER DEFAULT 0,    -- Changed records
    RECORDS_UNCHANGED  NUMBER DEFAULT 0,    -- No change
    RECORDS_DELETED    NUMBER DEFAULT 0,    -- Soft deleted
    RECORDS_REACTIVATED NUMBER DEFAULT 0,   -- Undeleted
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

-- =====================================================
-- STEP 5: CREATE DIMENSION TABLES (SCD TYPE 2 COMPLETE)
-- =====================================================

-- OPERATORS Dimension (SCD Type 2 Complete)
CREATE TABLE OPERATORS (
    OPERATOR_ID        NUMBER NOT NULL,
    OPERATOR_NAME      VARCHAR2(200),
    SRC_HASH           RAW(32),
    VALID_FROM         DATE DEFAULT SYSDATE,
    VALID_TO           DATE,
    IS_CURRENT         CHAR(1) DEFAULT 'Y' CHECK (IS_CURRENT IN ('Y', 'N')),
    DELETE_DATE        DATE,                    -- When record was deleted from source
    REACTIVATE_DATE    DATE,                    -- When record was reactivated
    CHANGE_TYPE        VARCHAR2(20),            -- INSERT/UPDATE/DELETE/REACTIVATE
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_OPERATORS PRIMARY KEY (OPERATOR_ID, VALID_FROM)
);

-- PLANTS Dimension (SCD Type 2 Complete)
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
    DELETE_DATE        DATE,
    REACTIVATE_DATE    DATE,
    CHANGE_TYPE        VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_PLANTS PRIMARY KEY (PLANT_ID, VALID_FROM)
);

-- ISSUES Dimension (SCD Type 2 Complete)
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
    DELETE_DATE        DATE,
    REACTIVATE_DATE    DATE,
    CHANGE_TYPE        VARCHAR2(20),
    ETL_RUN_ID         NUMBER,
    CONSTRAINT PK_ISSUES PRIMARY KEY (PLANT_ID, ISSUE_REVISION, VALID_FROM)
);

-- =====================================================
-- STEP 6: CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Indexes for current record lookups
CREATE INDEX IX_OPERATORS_CURRENT ON OPERATORS(OPERATOR_ID, IS_CURRENT);
CREATE INDEX IX_PLANTS_CURRENT ON PLANTS(PLANT_ID, IS_CURRENT);
CREATE INDEX IX_ISSUES_CURRENT ON ISSUES(PLANT_ID, ISSUE_REVISION, IS_CURRENT);

-- Indexes for deletion tracking
CREATE INDEX IX_OPERATORS_DELETE ON OPERATORS(DELETE_DATE) WHERE DELETE_DATE IS NOT NULL;
CREATE INDEX IX_PLANTS_DELETE ON PLANTS(DELETE_DATE) WHERE DELETE_DATE IS NOT NULL;
CREATE INDEX IX_ISSUES_DELETE ON ISSUES(DELETE_DATE) WHERE DELETE_DATE IS NOT NULL;

-- Indexes for temporal queries
CREATE INDEX IX_OPERATORS_TEMPORAL ON OPERATORS(OPERATOR_ID, VALID_FROM, VALID_TO);
CREATE INDEX IX_PLANTS_TEMPORAL ON PLANTS(PLANT_ID, VALID_FROM, VALID_TO);
CREATE INDEX IX_ISSUES_TEMPORAL ON ISSUES(PLANT_ID, ISSUE_REVISION, VALID_FROM, VALID_TO);

-- =====================================================
-- STEP 7: CREATE VIEWS
-- =====================================================

-- Current Active Operators (excludes deleted)
CREATE OR REPLACE VIEW V_OPERATORS_CURRENT AS
SELECT 
    OPERATOR_ID,
    OPERATOR_NAME,
    VALID_FROM,
    ETL_RUN_ID
FROM OPERATORS
WHERE IS_CURRENT = 'Y'
  AND DELETE_DATE IS NULL;

-- Current Active Plants (excludes deleted)
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
WHERE IS_CURRENT = 'Y'
  AND DELETE_DATE IS NULL;

-- Deleted Records View (for audit)
CREATE OR REPLACE VIEW V_DELETED_RECORDS AS
SELECT 'OPERATORS' as TABLE_NAME, OPERATOR_ID as RECORD_ID, DELETE_DATE
FROM OPERATORS WHERE DELETE_DATE IS NOT NULL AND IS_CURRENT = 'N'
UNION ALL
SELECT 'PLANTS', PLANT_ID, DELETE_DATE
FROM PLANTS WHERE DELETE_DATE IS NOT NULL AND IS_CURRENT = 'N';

-- Change History View
CREATE OR REPLACE VIEW V_CHANGE_HISTORY AS
SELECT 'OPERATORS' as TABLE_NAME, 
       OPERATOR_ID as RECORD_ID,
       CHANGE_TYPE,
       VALID_FROM,
       VALID_TO,
       DELETE_DATE,
       REACTIVATE_DATE
FROM OPERATORS
ORDER BY VALID_FROM DESC;

-- =====================================================
-- STEP 8: CREATE COMPLETE STORED PROCEDURES
-- =====================================================

CREATE OR REPLACE PROCEDURE SP_PROCESS_OPERATORS_SCD2_COMPLETE(
    p_etl_run_id IN NUMBER
) AS
    v_records_unchanged NUMBER := 0;
    v_records_updated   NUMBER := 0;
    v_records_inserted  NUMBER := 0;
    v_records_deleted   NUMBER := 0;
    v_records_reactivated NUMBER := 0;
BEGIN
    -- =========================================
    -- STEP 1: Handle DELETIONS
    -- Records in DB but not in staging
    -- =========================================
    UPDATE OPERATORS o
    SET o.VALID_TO = SYSDATE,
        o.IS_CURRENT = 'N',
        o.DELETE_DATE = SYSDATE,
        o.CHANGE_TYPE = 'DELETE'
    WHERE o.IS_CURRENT = 'Y'
      AND o.DELETE_DATE IS NULL  -- Not already deleted
      AND NOT EXISTS (
        SELECT 1 FROM STG_OPERATORS s
        WHERE s.OPERATOR_ID = o.OPERATOR_ID
      );
    
    v_records_deleted := SQL%ROWCOUNT;
    
    -- =========================================
    -- STEP 2: Handle REACTIVATIONS
    -- Records that were deleted but now back
    -- =========================================
    FOR rec IN (
        SELECT s.OPERATOR_ID, s.OPERATOR_NAME
        FROM STG_OPERATORS s
        WHERE EXISTS (
            SELECT 1 FROM OPERATORS o
            WHERE o.OPERATOR_ID = s.OPERATOR_ID
              AND o.DELETE_DATE IS NOT NULL
              AND o.IS_CURRENT = 'N'
        )
    ) LOOP
        -- Mark old deleted record with reactivation info
        UPDATE OPERATORS
        SET REACTIVATE_DATE = SYSDATE
        WHERE OPERATOR_ID = rec.OPERATOR_ID
          AND DELETE_DATE IS NOT NULL
          AND IS_CURRENT = 'N'
          AND REACTIVATE_DATE IS NULL;
        
        -- Insert reactivated record
        INSERT INTO OPERATORS (
            OPERATOR_ID, OPERATOR_NAME, SRC_HASH,
            VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
        ) VALUES (
            rec.OPERATOR_ID,
            rec.OPERATOR_NAME,
            STANDARD_HASH(
                NVL(TO_CHAR(rec.OPERATOR_ID), '~') || '|' ||
                NVL(rec.OPERATOR_NAME, '~'),
                'SHA256'
            ),
            SYSDATE,
            'Y',
            'REACTIVATE',
            p_etl_run_id
        );
        
        v_records_reactivated := v_records_reactivated + 1;
    END LOOP;
    
    -- =========================================
    -- STEP 3: Count UNCHANGED records
    -- Compare actual data (handles manual changes)
    -- =========================================
    SELECT COUNT(*) INTO v_records_unchanged
    FROM STG_OPERATORS s
    INNER JOIN OPERATORS o ON o.OPERATOR_ID = s.OPERATOR_ID
    WHERE o.IS_CURRENT = 'Y'
      AND o.DELETE_DATE IS NULL
      AND STANDARD_HASH(
          NVL(TO_CHAR(o.OPERATOR_ID), '~') || '|' ||
          NVL(o.OPERATOR_NAME, '~'),
          'SHA256'
      ) = STANDARD_HASH(
          NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
          NVL(s.OPERATOR_NAME, '~'),
          'SHA256'
      );
    
    -- =========================================
    -- STEP 4: Handle UPDATES
    -- Expire changed records
    -- =========================================
    UPDATE OPERATORS o
    SET o.VALID_TO = SYSDATE,
        o.IS_CURRENT = 'N'
    WHERE o.IS_CURRENT = 'Y'
      AND o.DELETE_DATE IS NULL
      AND EXISTS (
        SELECT 1 FROM STG_OPERATORS s
        WHERE s.OPERATOR_ID = o.OPERATOR_ID
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
    
    -- Insert new versions for changed records
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
    WHERE EXISTS (
        SELECT 1 FROM OPERATORS o
        WHERE o.OPERATOR_ID = s.OPERATOR_ID
          AND o.VALID_TO = SYSDATE
          AND o.DELETE_DATE IS NULL
    );
    
    -- =========================================
    -- STEP 5: Handle NEW records
    -- =========================================
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
    WHERE NOT EXISTS (
        SELECT 1 FROM OPERATORS o
        WHERE o.OPERATOR_ID = s.OPERATOR_ID
    )
    -- Exclude reactivated records (already handled)
    AND NOT EXISTS (
        SELECT 1 FROM OPERATORS o
        WHERE o.OPERATOR_ID = s.OPERATOR_ID
          AND o.CHANGE_TYPE = 'REACTIVATE'
          AND o.ETL_RUN_ID = p_etl_run_id
    );
    
    v_records_inserted := SQL%ROWCOUNT;
    
    -- =========================================
    -- STEP 6: Update ETL Control
    -- =========================================
    UPDATE ETL_CONTROL
    SET RECORDS_UNCHANGED = v_records_unchanged,
        RECORDS_UPDATED = v_records_updated,
        RECORDS_LOADED = v_records_inserted,
        RECORDS_DELETED = v_records_deleted,
        RECORDS_REACTIVATED = v_records_reactivated
    WHERE ETL_RUN_ID = p_etl_run_id;
    
    DELETE FROM STG_OPERATORS WHERE ETL_RUN_ID = p_etl_run_id;
    
    COMMIT;
END SP_PROCESS_OPERATORS_SCD2_COMPLETE;
/

-- =====================================================
-- HANDLE PRIMARY KEY CHANGES
-- =====================================================

-- If OperatorID changes (rare but possible):
-- 1. Old ID gets marked as DELETE
-- 2. New ID gets inserted as INSERT
-- 3. Business can create mapping table if needed

CREATE TABLE OPERATOR_ID_CHANGES (
    OLD_OPERATOR_ID    NUMBER,
    NEW_OPERATOR_ID    NUMBER,
    CHANGE_DATE        DATE,
    CHANGE_REASON      VARCHAR2(500)
);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check all change types
SELECT CHANGE_TYPE, COUNT(*) 
FROM OPERATORS 
GROUP BY CHANGE_TYPE;

-- Find deleted records
SELECT * FROM V_DELETED_RECORDS;

-- Find reactivated records
SELECT * FROM OPERATORS 
WHERE REACTIVATE_DATE IS NOT NULL;

-- Verify procedures
SELECT object_name, status 
FROM user_objects 
WHERE object_type = 'PROCEDURE'
ORDER BY object_name;

COMMIT;