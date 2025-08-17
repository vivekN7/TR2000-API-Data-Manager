-- =====================================================
-- EDS References ETL Package
-- =====================================================
CREATE OR REPLACE PACKAGE PKG_EDS_REF_ETL AS
    PROCEDURE VALIDATE(p_etl_run_id NUMBER);
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER);
    PROCEDURE RECONCILE(p_etl_run_id NUMBER);
END PKG_EDS_REF_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_EDS_REF_ETL AS
    
    PROCEDURE VALIDATE(p_etl_run_id NUMBER) AS
    BEGIN
        UPDATE STG_EDS_REFERENCES
        SET IS_VALID = CASE
                WHEN PLANT_ID IS NULL OR ISSUE_REVISION IS NULL THEN 'N'
                WHEN EDS_NAME IS NULL THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN PLANT_ID IS NULL THEN 'Missing PLANT_ID'
                WHEN ISSUE_REVISION IS NULL THEN 'Missing ISSUE_REVISION'
                WHEN EDS_NAME IS NULL THEN 'Missing EDS_NAME'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        -- Mark duplicates within this batch
        UPDATE STG_EDS_REFERENCES s1
        SET IS_DUPLICATE = 'Y'
        WHERE ETL_RUN_ID = p_etl_run_id
        AND STG_ID > (
            SELECT MIN(s2.STG_ID)
            FROM STG_EDS_REFERENCES s2
            WHERE s2.ETL_RUN_ID = p_etl_run_id
            AND s2.PLANT_ID = s1.PLANT_ID
            AND s2.ISSUE_REVISION = s1.ISSUE_REVISION
            AND NVL(s2.EDS_NAME, 'NULL') = NVL(s1.EDS_NAME, 'NULL')
            AND NVL(s2.EDS_REVISION, 'NULL') = NVL(s1.EDS_REVISION, 'NULL')
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
        UPDATE EDS_REFERENCES 
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
        UPDATE EDS_REFERENCES d
        SET IS_CURRENT = 'N',
            VALID_TO = SYSDATE,
            CHANGE_TYPE = 'UPDATE'
        WHERE d.IS_CURRENT = 'Y'
        AND d.DELETE_DATE IS NULL
        AND EXISTS (
            SELECT 1 FROM STG_EDS_REFERENCES s
            WHERE s.ETL_RUN_ID = p_etl_run_id
            AND s.IS_VALID = 'Y'
            AND s.IS_DUPLICATE = 'N'
            AND s.PLANT_ID = d.PLANT_ID
            AND s.ISSUE_REVISION = d.ISSUE_REVISION
            AND NVL(s.EDS_NAME, 'NULL') = NVL(d.EDS_NAME, 'NULL')
            AND NVL(s.EDS_REVISION, 'NULL') = NVL(d.EDS_REVISION, 'NULL')
            AND STANDARD_HASH(
                NVL(s.EDS_NAME, '~') || '|' ||
                NVL(s.EDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ) != d.SRC_HASH
        );
        
        v_rows_updated := SQL%ROWCOUNT;
        
        -- STEP 3: Count unchanged records
        SELECT COUNT(*) INTO v_rows_unchanged
        FROM STG_EDS_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND EXISTS (
            SELECT 1 FROM EDS_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.EDS_NAME, 'NULL') = NVL(s.EDS_NAME, 'NULL')
            AND NVL(d.EDS_REVISION, 'NULL') = NVL(s.EDS_REVISION, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.EDS_NAME, '~') || '|' ||
                NVL(s.EDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        -- STEP 4: Insert new records (including updates and new inserts)
        INSERT INTO EDS_REFERENCES (
            PLANT_ID, ISSUE_REVISION, EDS_NAME, EDS_REVISION,
            OFFICIAL_REVISION, DELTA, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
            SRC_HASH, VALID_FROM, VALID_TO, IS_CURRENT, CHANGE_TYPE, 
            DELETE_DATE, ETL_RUN_ID
        )
        SELECT DISTINCT
            s.PLANT_ID, s.ISSUE_REVISION, s.EDS_NAME, s.EDS_REVISION,
            s.OFFICIAL_REVISION, s.DELTA, s.USER_NAME, s.USER_ENTRY_TIME, s.USER_PROTECTED,
            STANDARD_HASH(
                NVL(s.EDS_NAME, '~') || '|' ||
                NVL(s.EDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ), SYSDATE, NULL, 'Y', 'INSERT',
            NULL, p_etl_run_id
        FROM STG_EDS_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND NOT EXISTS (
            SELECT 1 FROM EDS_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.EDS_NAME, 'NULL') = NVL(s.EDS_NAME, 'NULL')
            AND NVL(d.EDS_REVISION, 'NULL') = NVL(s.EDS_REVISION, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.EDS_NAME, '~') || '|' ||
                NVL(s.EDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        v_rows_inserted := SQL%ROWCOUNT;
        
        -- Update ETL control with counts
        UPDATE ETL_CONTROL
        SET RECORDS_LOADED = v_rows_inserted,
            RECORDS_UPDATED = v_rows_updated,
            RECORDS_DELETED = v_rows_deleted,
            RECORDS_REACTIVATED = v_rows_reactivated,
            RECORDS_UNCHANGED = v_rows_unchanged
        WHERE ETL_RUN_ID = p_etl_run_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            LOG_ETL_ERROR(
                p_etl_run_id, 
                'PKG_EDS_REF_ETL.PROCESS_SCD2', 
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
        SELECT COUNT(*)
        INTO v_source_count
        FROM STG_EDS_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND IS_VALID = 'Y'
        AND IS_DUPLICATE = 'N';
        
        SELECT COUNT(*)
        INTO v_target_count
        FROM EDS_REFERENCES
        WHERE IS_CURRENT = 'Y'
        AND DELETE_DATE IS NULL;
        
        INSERT INTO ETL_RECONCILIATION (
            ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
        ) VALUES (
            p_etl_run_id, 'EDS_REFERENCES', v_source_count, v_target_count,
            ABS(v_source_count - v_target_count)
        );
    END RECONCILE;
    
END PKG_EDS_REF_ETL;
/
-- =====================================================
-- MDS References ETL Package
-- =====================================================
CREATE OR REPLACE PACKAGE PKG_MDS_REF_ETL AS
    PROCEDURE VALIDATE(p_etl_run_id NUMBER);
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER);
    PROCEDURE RECONCILE(p_etl_run_id NUMBER);
END PKG_MDS_REF_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_MDS_REF_ETL AS
    
    PROCEDURE VALIDATE(p_etl_run_id NUMBER) AS
    BEGIN
        UPDATE STG_MDS_REFERENCES
        SET IS_VALID = CASE
                WHEN PLANT_ID IS NULL OR ISSUE_REVISION IS NULL THEN 'N'
                WHEN MDS_NAME IS NULL THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN PLANT_ID IS NULL THEN 'Missing PLANT_ID'
                WHEN ISSUE_REVISION IS NULL THEN 'Missing ISSUE_REVISION'
                WHEN MDS_NAME IS NULL THEN 'Missing MDS_NAME'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        -- Mark duplicates within this batch
        UPDATE STG_MDS_REFERENCES s1
        SET IS_DUPLICATE = 'Y'
        WHERE ETL_RUN_ID = p_etl_run_id
        AND STG_ID > (
            SELECT MIN(s2.STG_ID)
            FROM STG_MDS_REFERENCES s2
            WHERE s2.ETL_RUN_ID = p_etl_run_id
            AND s2.PLANT_ID = s1.PLANT_ID
            AND s2.ISSUE_REVISION = s1.ISSUE_REVISION
            AND NVL(s2.MDS_NAME, 'NULL') = NVL(s1.MDS_NAME, 'NULL')
            AND NVL(s2.MDS_REVISION, 'NULL') = NVL(s1.MDS_REVISION, 'NULL')
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
        UPDATE MDS_REFERENCES 
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
        
        -- STEP 2: Close existing records that have changed (with AREA field)
        UPDATE MDS_REFERENCES d
        SET IS_CURRENT = 'N',
            VALID_TO = SYSDATE,
            CHANGE_TYPE = 'UPDATE'
        WHERE d.IS_CURRENT = 'Y'
        AND d.DELETE_DATE IS NULL
        AND EXISTS (
            SELECT 1 FROM STG_MDS_REFERENCES s
            WHERE s.ETL_RUN_ID = p_etl_run_id
            AND s.IS_VALID = 'Y'
            AND s.IS_DUPLICATE = 'N'
            AND s.PLANT_ID = d.PLANT_ID
            AND s.ISSUE_REVISION = d.ISSUE_REVISION
            AND NVL(s.MDS_NAME, 'NULL') = NVL(d.MDS_NAME, 'NULL')
            AND NVL(s.MDS_REVISION, 'NULL') = NVL(d.MDS_REVISION, 'NULL')
            AND STANDARD_HASH(
                NVL(s.MDS_NAME, '~') || '|' ||
                NVL(s.MDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.AREA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ) != d.SRC_HASH
        );
        
        v_rows_updated := SQL%ROWCOUNT;
        
        -- STEP 3: Count unchanged records
        SELECT COUNT(*) INTO v_rows_unchanged
        FROM STG_MDS_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND EXISTS (
            SELECT 1 FROM MDS_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.MDS_NAME, 'NULL') = NVL(s.MDS_NAME, 'NULL')
            AND NVL(d.MDS_REVISION, 'NULL') = NVL(s.MDS_REVISION, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.MDS_NAME, '~') || '|' ||
                NVL(s.MDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.AREA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        -- STEP 4: Insert new records
        INSERT INTO MDS_REFERENCES (
            PLANT_ID, ISSUE_REVISION, MDS_NAME, MDS_REVISION,
            OFFICIAL_REVISION, DELTA, AREA, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
            SRC_HASH, VALID_FROM, VALID_TO, IS_CURRENT, CHANGE_TYPE, 
            DELETE_DATE, ETL_RUN_ID
        )
        SELECT DISTINCT
            s.PLANT_ID, s.ISSUE_REVISION, s.MDS_NAME, s.MDS_REVISION,
            s.OFFICIAL_REVISION, s.DELTA, s.AREA, s.USER_NAME, s.USER_ENTRY_TIME, s.USER_PROTECTED,
            STANDARD_HASH(
                NVL(s.MDS_NAME, '~') || '|' ||
                NVL(s.MDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.AREA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ), SYSDATE, NULL, 'Y', 'INSERT',
            NULL, p_etl_run_id
        FROM STG_MDS_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND NOT EXISTS (
            SELECT 1 FROM MDS_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.MDS_NAME, 'NULL') = NVL(s.MDS_NAME, 'NULL')
            AND NVL(d.MDS_REVISION, 'NULL') = NVL(s.MDS_REVISION, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.MDS_NAME, '~') || '|' ||
                NVL(s.MDS_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.AREA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        v_rows_inserted := SQL%ROWCOUNT;
        
        -- Update ETL control with counts
        UPDATE ETL_CONTROL
        SET RECORDS_LOADED = v_rows_inserted,
            RECORDS_UPDATED = v_rows_updated,
            RECORDS_DELETED = v_rows_deleted,
            RECORDS_REACTIVATED = v_rows_reactivated,
            RECORDS_UNCHANGED = v_rows_unchanged
        WHERE ETL_RUN_ID = p_etl_run_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            LOG_ETL_ERROR(
                p_etl_run_id, 
                'PKG_MDS_REF_ETL.PROCESS_SCD2', 
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
        SELECT COUNT(*)
        INTO v_source_count
        FROM STG_MDS_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND IS_VALID = 'Y'
        AND IS_DUPLICATE = 'N';
        
        SELECT COUNT(*)
        INTO v_target_count
        FROM MDS_REFERENCES
        WHERE IS_CURRENT = 'Y'
        AND DELETE_DATE IS NULL;
        
        INSERT INTO ETL_RECONCILIATION (
            ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
        ) VALUES (
            p_etl_run_id, 'MDS_REFERENCES', v_source_count, v_target_count,
            ABS(v_source_count - v_target_count)
        );
    END RECONCILE;
    
END PKG_MDS_REF_ETL;
/

-- =====================================================
-- VSK References ETL Package  
-- =====================================================
CREATE OR REPLACE PACKAGE PKG_VSK_REF_ETL AS
    PROCEDURE VALIDATE(p_etl_run_id NUMBER);
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER);
    PROCEDURE RECONCILE(p_etl_run_id NUMBER);
END PKG_VSK_REF_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_VSK_REF_ETL AS
    
    PROCEDURE VALIDATE(p_etl_run_id NUMBER) AS
    BEGIN
        UPDATE STG_VSK_REFERENCES
        SET IS_VALID = CASE
                WHEN PLANT_ID IS NULL OR ISSUE_REVISION IS NULL THEN 'N'
                WHEN VSK_NAME IS NULL THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN PLANT_ID IS NULL THEN 'Missing PLANT_ID'
                WHEN ISSUE_REVISION IS NULL THEN 'Missing ISSUE_REVISION'
                WHEN VSK_NAME IS NULL THEN 'Missing VSK_NAME'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        -- Mark duplicates within this batch
        UPDATE STG_VSK_REFERENCES s1
        SET IS_DUPLICATE = 'Y'
        WHERE ETL_RUN_ID = p_etl_run_id
        AND STG_ID > (
            SELECT MIN(s2.STG_ID)
            FROM STG_VSK_REFERENCES s2
            WHERE s2.ETL_RUN_ID = p_etl_run_id
            AND s2.PLANT_ID = s1.PLANT_ID
            AND s2.ISSUE_REVISION = s1.ISSUE_REVISION
            AND NVL(s2.VSK_NAME, 'NULL') = NVL(s1.VSK_NAME, 'NULL')
            AND NVL(s2.VSK_REVISION, 'NULL') = NVL(s1.VSK_REVISION, 'NULL')
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
        UPDATE VSK_REFERENCES 
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
        UPDATE VSK_REFERENCES d
        SET IS_CURRENT = 'N',
            VALID_TO = SYSDATE,
            CHANGE_TYPE = 'UPDATE'
        WHERE d.IS_CURRENT = 'Y'
        AND d.DELETE_DATE IS NULL
        AND EXISTS (
            SELECT 1 FROM STG_VSK_REFERENCES s
            WHERE s.ETL_RUN_ID = p_etl_run_id
            AND s.IS_VALID = 'Y'
            AND s.IS_DUPLICATE = 'N'
            AND s.PLANT_ID = d.PLANT_ID
            AND s.ISSUE_REVISION = d.ISSUE_REVISION
            AND NVL(s.VSK_NAME, 'NULL') = NVL(d.VSK_NAME, 'NULL')
            AND NVL(s.VSK_REVISION, 'NULL') = NVL(d.VSK_REVISION, 'NULL')
            AND STANDARD_HASH(
                NVL(s.VSK_NAME, '~') || '|' ||
                NVL(s.VSK_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ) != d.SRC_HASH
        );
        
        v_rows_updated := SQL%ROWCOUNT;
        
        -- STEP 3: Count unchanged records
        SELECT COUNT(*) INTO v_rows_unchanged
        FROM STG_VSK_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND EXISTS (
            SELECT 1 FROM VSK_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.VSK_NAME, 'NULL') = NVL(s.VSK_NAME, 'NULL')
            AND NVL(d.VSK_REVISION, 'NULL') = NVL(s.VSK_REVISION, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.VSK_NAME, '~') || '|' ||
                NVL(s.VSK_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        -- STEP 4: Insert new records
        INSERT INTO VSK_REFERENCES (
            PLANT_ID, ISSUE_REVISION, VSK_NAME, VSK_REVISION,
            OFFICIAL_REVISION, DELTA, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
            SRC_HASH, VALID_FROM, VALID_TO, IS_CURRENT, CHANGE_TYPE, 
            DELETE_DATE, ETL_RUN_ID
        )
        SELECT DISTINCT
            s.PLANT_ID, s.ISSUE_REVISION, s.VSK_NAME, s.VSK_REVISION,
            s.OFFICIAL_REVISION, s.DELTA, s.USER_NAME, s.USER_ENTRY_TIME, s.USER_PROTECTED,
            STANDARD_HASH(
                NVL(s.VSK_NAME, '~') || '|' ||
                NVL(s.VSK_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ), SYSDATE, NULL, 'Y', 'INSERT',
            NULL, p_etl_run_id
        FROM STG_VSK_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND NOT EXISTS (
            SELECT 1 FROM VSK_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.VSK_NAME, 'NULL') = NVL(s.VSK_NAME, 'NULL')
            AND NVL(d.VSK_REVISION, 'NULL') = NVL(s.VSK_REVISION, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.VSK_NAME, '~') || '|' ||
                NVL(s.VSK_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        v_rows_inserted := SQL%ROWCOUNT;
        
        -- Update ETL control with counts
        UPDATE ETL_CONTROL
        SET RECORDS_LOADED = v_rows_inserted,
            RECORDS_UPDATED = v_rows_updated,
            RECORDS_DELETED = v_rows_deleted,
            RECORDS_REACTIVATED = v_rows_reactivated,
            RECORDS_UNCHANGED = v_rows_unchanged
        WHERE ETL_RUN_ID = p_etl_run_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            LOG_ETL_ERROR(
                p_etl_run_id, 
                'PKG_VSK_REF_ETL.PROCESS_SCD2', 
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
        SELECT COUNT(*)
        INTO v_source_count
        FROM STG_VSK_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND IS_VALID = 'Y'
        AND IS_DUPLICATE = 'N';
        
        SELECT COUNT(*)
        INTO v_target_count
        FROM VSK_REFERENCES
        WHERE IS_CURRENT = 'Y'
        AND DELETE_DATE IS NULL;
        
        INSERT INTO ETL_RECONCILIATION (
            ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
        ) VALUES (
            p_etl_run_id, 'VSK_REFERENCES', v_source_count, v_target_count,
            ABS(v_source_count - v_target_count)
        );
    END RECONCILE;
    
END PKG_VSK_REF_ETL;
/

-- =====================================================
-- ESK References ETL Package
-- =====================================================
CREATE OR REPLACE PACKAGE PKG_ESK_REF_ETL AS
    PROCEDURE VALIDATE(p_etl_run_id NUMBER);
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER);
    PROCEDURE RECONCILE(p_etl_run_id NUMBER);
END PKG_ESK_REF_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_ESK_REF_ETL AS
    
    PROCEDURE VALIDATE(p_etl_run_id NUMBER) AS
    BEGIN
        UPDATE STG_ESK_REFERENCES
        SET IS_VALID = CASE
                WHEN PLANT_ID IS NULL OR ISSUE_REVISION IS NULL THEN 'N'
                WHEN ESK_NAME IS NULL THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN PLANT_ID IS NULL THEN 'Missing PLANT_ID'
                WHEN ISSUE_REVISION IS NULL THEN 'Missing ISSUE_REVISION'
                WHEN ESK_NAME IS NULL THEN 'Missing ESK_NAME'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        -- Mark duplicates within this batch
        UPDATE STG_ESK_REFERENCES s1
        SET IS_DUPLICATE = 'Y'
        WHERE ETL_RUN_ID = p_etl_run_id
        AND STG_ID > (
            SELECT MIN(s2.STG_ID)
            FROM STG_ESK_REFERENCES s2
            WHERE s2.ETL_RUN_ID = p_etl_run_id
            AND s2.PLANT_ID = s1.PLANT_ID
            AND s2.ISSUE_REVISION = s1.ISSUE_REVISION
            AND NVL(s2.ESK_NAME, 'NULL') = NVL(s1.ESK_NAME, 'NULL')
            AND NVL(s2.ESK_REVISION, 'NULL') = NVL(s1.ESK_REVISION, 'NULL')
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
        UPDATE ESK_REFERENCES 
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
        UPDATE ESK_REFERENCES d
        SET IS_CURRENT = 'N',
            VALID_TO = SYSDATE,
            CHANGE_TYPE = 'UPDATE'
        WHERE d.IS_CURRENT = 'Y'
        AND d.DELETE_DATE IS NULL
        AND EXISTS (
            SELECT 1 FROM STG_ESK_REFERENCES s
            WHERE s.ETL_RUN_ID = p_etl_run_id
            AND s.IS_VALID = 'Y'
            AND s.IS_DUPLICATE = 'N'
            AND s.PLANT_ID = d.PLANT_ID
            AND s.ISSUE_REVISION = d.ISSUE_REVISION
            AND NVL(s.ESK_NAME, 'NULL') = NVL(d.ESK_NAME, 'NULL')
            AND NVL(s.ESK_REVISION, 'NULL') = NVL(d.ESK_REVISION, 'NULL')
            AND STANDARD_HASH(
                NVL(s.ESK_NAME, '~') || '|' ||
                NVL(s.ESK_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ) != d.SRC_HASH
        );
        
        v_rows_updated := SQL%ROWCOUNT;
        
        -- STEP 3: Count unchanged records
        SELECT COUNT(*) INTO v_rows_unchanged
        FROM STG_ESK_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND EXISTS (
            SELECT 1 FROM ESK_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.ESK_NAME, 'NULL') = NVL(s.ESK_NAME, 'NULL')
            AND NVL(d.ESK_REVISION, 'NULL') = NVL(s.ESK_REVISION, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.ESK_NAME, '~') || '|' ||
                NVL(s.ESK_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        -- STEP 4: Insert new records
        INSERT INTO ESK_REFERENCES (
            PLANT_ID, ISSUE_REVISION, ESK_NAME, ESK_REVISION,
            OFFICIAL_REVISION, DELTA, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
            SRC_HASH, VALID_FROM, VALID_TO, IS_CURRENT, CHANGE_TYPE, 
            DELETE_DATE, ETL_RUN_ID
        )
        SELECT DISTINCT
            s.PLANT_ID, s.ISSUE_REVISION, s.ESK_NAME, s.ESK_REVISION,
            s.OFFICIAL_REVISION, s.DELTA, s.USER_NAME, s.USER_ENTRY_TIME, s.USER_PROTECTED,
            STANDARD_HASH(
                NVL(s.ESK_NAME, '~') || '|' ||
                NVL(s.ESK_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ), SYSDATE, NULL, 'Y', 'INSERT',
            NULL, p_etl_run_id
        FROM STG_ESK_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND NOT EXISTS (
            SELECT 1 FROM ESK_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.ESK_NAME, 'NULL') = NVL(s.ESK_NAME, 'NULL')
            AND NVL(d.ESK_REVISION, 'NULL') = NVL(s.ESK_REVISION, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.ESK_NAME, '~') || '|' ||
                NVL(s.ESK_REVISION, '~') || '|' ||
                NVL(s.OFFICIAL_REVISION, '~') || '|' ||
                NVL(s.DELTA, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        v_rows_inserted := SQL%ROWCOUNT;
        
        -- Update ETL control with counts
        UPDATE ETL_CONTROL
        SET RECORDS_LOADED = v_rows_inserted,
            RECORDS_UPDATED = v_rows_updated,
            RECORDS_DELETED = v_rows_deleted,
            RECORDS_REACTIVATED = v_rows_reactivated,
            RECORDS_UNCHANGED = v_rows_unchanged
        WHERE ETL_RUN_ID = p_etl_run_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            LOG_ETL_ERROR(
                p_etl_run_id, 
                'PKG_ESK_REF_ETL.PROCESS_SCD2', 
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
        SELECT COUNT(*)
        INTO v_source_count
        FROM STG_ESK_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND IS_VALID = 'Y'
        AND IS_DUPLICATE = 'N';
        
        SELECT COUNT(*)
        INTO v_target_count
        FROM ESK_REFERENCES
        WHERE IS_CURRENT = 'Y'
        AND DELETE_DATE IS NULL;
        
        INSERT INTO ETL_RECONCILIATION (
            ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
        ) VALUES (
            p_etl_run_id, 'ESK_REFERENCES', v_source_count, v_target_count,
            ABS(v_source_count - v_target_count)
        );
    END RECONCILE;
    
END PKG_ESK_REF_ETL;
/

-- =====================================================
-- PIPE_ELEMENT References ETL Package
-- =====================================================
CREATE OR REPLACE PACKAGE PKG_PIPE_ELEMENT_REF_ETL AS
    PROCEDURE VALIDATE(p_etl_run_id NUMBER);
    PROCEDURE PROCESS_SCD2(p_etl_run_id NUMBER);
    PROCEDURE RECONCILE(p_etl_run_id NUMBER);
END PKG_PIPE_ELEMENT_REF_ETL;
/

CREATE OR REPLACE PACKAGE BODY PKG_PIPE_ELEMENT_REF_ETL AS
    
    PROCEDURE VALIDATE(p_etl_run_id NUMBER) AS
    BEGIN
        UPDATE STG_PIPE_ELEMENT_REFERENCES
        SET IS_VALID = CASE
                WHEN PLANT_ID IS NULL OR ISSUE_REVISION IS NULL THEN 'N'
                WHEN TAG_NO IS NULL THEN 'N'
                ELSE 'Y'
            END,
            VALIDATION_ERROR = CASE
                WHEN PLANT_ID IS NULL THEN 'Missing PLANT_ID'
                WHEN ISSUE_REVISION IS NULL THEN 'Missing ISSUE_REVISION'
                WHEN TAG_NO IS NULL THEN 'Missing TAG_NO'
                ELSE NULL
            END
        WHERE ETL_RUN_ID = p_etl_run_id;
        
        -- Mark duplicates within this batch
        UPDATE STG_PIPE_ELEMENT_REFERENCES s1
        SET IS_DUPLICATE = 'Y'
        WHERE ETL_RUN_ID = p_etl_run_id
        AND STG_ID > (
            SELECT MIN(s2.STG_ID)
            FROM STG_PIPE_ELEMENT_REFERENCES s2
            WHERE s2.ETL_RUN_ID = p_etl_run_id
            AND s2.PLANT_ID = s1.PLANT_ID
            AND s2.ISSUE_REVISION = s1.ISSUE_REVISION
            AND NVL(s2.TAG_NO, 'NULL') = NVL(s1.TAG_NO, 'NULL')
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
        UPDATE PIPE_ELEMENT_REFERENCES 
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
        UPDATE PIPE_ELEMENT_REFERENCES d
        SET IS_CURRENT = 'N',
            VALID_TO = SYSDATE,
            CHANGE_TYPE = 'UPDATE'
        WHERE d.IS_CURRENT = 'Y'
        AND d.DELETE_DATE IS NULL
        AND EXISTS (
            SELECT 1 FROM STG_PIPE_ELEMENT_REFERENCES s
            WHERE s.ETL_RUN_ID = p_etl_run_id
            AND s.IS_VALID = 'Y'
            AND s.IS_DUPLICATE = 'N'
            AND s.PLANT_ID = d.PLANT_ID
            AND s.ISSUE_REVISION = d.ISSUE_REVISION
            AND NVL(s.TAG_NO, 'NULL') = NVL(d.TAG_NO, 'NULL')
            AND STANDARD_HASH(
                NVL(s.TAG_NO, '~') || '|' ||
                NVL(s.ELEMENT_TYPE, '~') || '|' ||
                NVL(s.ELEMENT_SIZE, '~') || '|' ||
                NVL(s.RATING, '~') || '|' ||
                NVL(s.MATERIAL, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ) != d.SRC_HASH
        );
        
        v_rows_updated := SQL%ROWCOUNT;
        
        -- STEP 3: Count unchanged records
        SELECT COUNT(*) INTO v_rows_unchanged
        FROM STG_PIPE_ELEMENT_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND EXISTS (
            SELECT 1 FROM PIPE_ELEMENT_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.TAG_NO, 'NULL') = NVL(s.TAG_NO, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.TAG_NO, '~') || '|' ||
                NVL(s.ELEMENT_TYPE, '~') || '|' ||
                NVL(s.ELEMENT_SIZE, '~') || '|' ||
                NVL(s.RATING, '~') || '|' ||
                NVL(s.MATERIAL, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        -- STEP 4: Insert new records
        INSERT INTO PIPE_ELEMENT_REFERENCES (
            PLANT_ID, ISSUE_REVISION, TAG_NO, ELEMENT_TYPE, ELEMENT_SIZE,
            RATING, MATERIAL, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
            SRC_HASH, VALID_FROM, VALID_TO, IS_CURRENT, CHANGE_TYPE, 
            DELETE_DATE, ETL_RUN_ID
        )
        SELECT DISTINCT
            s.PLANT_ID, s.ISSUE_REVISION, s.TAG_NO, s.ELEMENT_TYPE, s.ELEMENT_SIZE,
            s.RATING, s.MATERIAL, s.USER_NAME, s.USER_ENTRY_TIME, s.USER_PROTECTED,
            STANDARD_HASH(
                NVL(s.TAG_NO, '~') || '|' ||
                NVL(s.ELEMENT_TYPE, '~') || '|' ||
                NVL(s.ELEMENT_SIZE, '~') || '|' ||
                NVL(s.RATING, '~') || '|' ||
                NVL(s.MATERIAL, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            ), SYSDATE, NULL, 'Y', 'INSERT',
            NULL, p_etl_run_id
        FROM STG_PIPE_ELEMENT_REFERENCES s
        WHERE s.ETL_RUN_ID = p_etl_run_id
        AND s.IS_VALID = 'Y'
        AND s.IS_DUPLICATE = 'N'
        AND NOT EXISTS (
            SELECT 1 FROM PIPE_ELEMENT_REFERENCES d
            WHERE d.IS_CURRENT = 'Y'
            AND d.DELETE_DATE IS NULL
            AND d.PLANT_ID = s.PLANT_ID
            AND d.ISSUE_REVISION = s.ISSUE_REVISION
            AND NVL(d.TAG_NO, 'NULL') = NVL(s.TAG_NO, 'NULL')
            AND d.SRC_HASH = STANDARD_HASH(
                NVL(s.TAG_NO, '~') || '|' ||
                NVL(s.ELEMENT_TYPE, '~') || '|' ||
                NVL(s.ELEMENT_SIZE, '~') || '|' ||
                NVL(s.RATING, '~') || '|' ||
                NVL(s.MATERIAL, '~') || '|' ||
                NVL(s.USER_NAME, '~') || '|' ||
                NVL(TO_CHAR(s.USER_ENTRY_TIME, 'YYYY-MM-DD HH24:MI:SS'), '~') || '|' ||
                NVL(s.USER_PROTECTED, '~'),
                'SHA256'
            )
        );
        
        v_rows_inserted := SQL%ROWCOUNT;
        
        -- Update ETL control with counts
        UPDATE ETL_CONTROL
        SET RECORDS_LOADED = v_rows_inserted,
            RECORDS_UPDATED = v_rows_updated,
            RECORDS_DELETED = v_rows_deleted,
            RECORDS_REACTIVATED = v_rows_reactivated,
            RECORDS_UNCHANGED = v_rows_unchanged
        WHERE ETL_RUN_ID = p_etl_run_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            LOG_ETL_ERROR(
                p_etl_run_id, 
                'PKG_PIPE_ELEMENT_REF_ETL.PROCESS_SCD2', 
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
        SELECT COUNT(*)
        INTO v_source_count
        FROM STG_PIPE_ELEMENT_REFERENCES
        WHERE ETL_RUN_ID = p_etl_run_id
        AND IS_VALID = 'Y'
        AND IS_DUPLICATE = 'N';
        
        SELECT COUNT(*)
        INTO v_target_count
        FROM PIPE_ELEMENT_REFERENCES
        WHERE IS_CURRENT = 'Y'
        AND DELETE_DATE IS NULL;
        
        INSERT INTO ETL_RECONCILIATION (
            ETL_RUN_ID, ENTITY_TYPE, SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
        ) VALUES (
            p_etl_run_id, 'PIPE_ELEMENT_REFERENCES', v_source_count, v_target_count,
            ABS(v_source_count - v_target_count)
        );
    END RECONCILE;
    
END PKG_PIPE_ELEMENT_REF_ETL;
/
