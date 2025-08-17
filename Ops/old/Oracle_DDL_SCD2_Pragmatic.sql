-- =====================================================
-- PRAGMATIC SCD2 APPROACH - Simple & Effective
-- =====================================================
-- 
-- Philosophy: Handle 99% of cases simply
-- Edge cases: Handle manually or with separate cleanup jobs
--
-- What we handle:
-- 1. New records → INSERT
-- 2. Changed records → UPDATE history
-- 3. Unchanged → Nothing
-- 4. Deleted records → Simple soft delete
--
-- What we DON'T handle (because they're rare):
-- - Primary key changes (treat as delete + insert)
-- - Reactivations (just insert as new)
-- =====================================================

CREATE OR REPLACE PROCEDURE SP_PROCESS_OPERATORS_SCD2_PRAGMATIC(
    p_etl_run_id IN NUMBER
) AS
    v_records_unchanged NUMBER := 0;
    v_records_updated   NUMBER := 0;
    v_records_inserted  NUMBER := 0;
    v_records_deleted   NUMBER := 0;
BEGIN
    -- Step 1: Soft delete missing records (simple!)
    UPDATE OPERATORS o
    SET o.VALID_TO = SYSDATE,
        o.IS_CURRENT = 'N'
    WHERE o.IS_CURRENT = 'Y'
      AND NOT EXISTS (
        SELECT 1 FROM STG_OPERATORS s
        WHERE s.OPERATOR_ID = o.OPERATOR_ID
      );
    
    v_records_deleted := SQL%ROWCOUNT;
    
    -- Step 2: Count unchanged (compare actual data for integrity)
    SELECT COUNT(*) INTO v_records_unchanged
    FROM STG_OPERATORS s
    INNER JOIN OPERATORS o ON o.OPERATOR_ID = s.OPERATOR_ID
    WHERE o.IS_CURRENT = 'Y'
      AND STANDARD_HASH(
          NVL(TO_CHAR(o.OPERATOR_ID), '~') || '|' ||
          NVL(o.OPERATOR_NAME, '~'),
          'SHA256'
      ) = STANDARD_HASH(
          NVL(TO_CHAR(s.OPERATOR_ID), '~') || '|' ||
          NVL(s.OPERATOR_NAME, '~'),
          'SHA256'
      );
    
    -- Step 3: Expire changed records
    UPDATE OPERATORS o
    SET o.VALID_TO = SYSDATE,
        o.IS_CURRENT = 'N'
    WHERE o.IS_CURRENT = 'Y'
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
    
    -- Step 4: Insert new/changed records (simple!)
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
    WHERE (
        -- Changed records
        EXISTS (
            SELECT 1 FROM OPERATORS o
            WHERE o.OPERATOR_ID = s.OPERATOR_ID
              AND o.VALID_TO = SYSDATE
        )
        OR
        -- New records
        NOT EXISTS (
            SELECT 1 FROM OPERATORS o
            WHERE o.OPERATOR_ID = s.OPERATOR_ID
        )
    );
    
    v_records_inserted := SQL%ROWCOUNT - v_records_updated;
    
    -- Update ETL Control
    UPDATE ETL_CONTROL
    SET RECORDS_UNCHANGED = v_records_unchanged,
        RECORDS_UPDATED = v_records_updated,
        RECORDS_LOADED = v_records_inserted,
        RECORDS_DELETED = v_records_deleted
    WHERE ETL_RUN_ID = p_etl_run_id;
    
    DELETE FROM STG_OPERATORS WHERE ETL_RUN_ID = p_etl_run_id;
    
    COMMIT;
END;
/

-- =====================================================
-- OPTIONAL: Weekly Cleanup Job for Edge Cases
-- =====================================================

-- Run this weekly to handle rare scenarios
CREATE OR REPLACE PROCEDURE SP_CLEANUP_EDGE_CASES AS
BEGIN
    -- Find and log potential ID changes
    INSERT INTO ETL_ERROR_LOG (ERROR_SOURCE, ERROR_MESSAGE)
    SELECT 'ID_CHANGE_DETECTION', 
           'Possible ID change: ' || OPERATOR_NAME || ' appears with multiple IDs'
    FROM (
        SELECT OPERATOR_NAME, COUNT(DISTINCT OPERATOR_ID) as ID_COUNT
        FROM OPERATORS
        WHERE IS_CURRENT = 'Y'
        GROUP BY OPERATOR_NAME
        HAVING COUNT(DISTINCT OPERATOR_ID) > 1
    );
    
    -- Archive very old history (>1 year)
    DELETE FROM OPERATORS
    WHERE VALID_TO < ADD_MONTHS(SYSDATE, -12)
      AND IS_CURRENT = 'N';
    
    COMMIT;
END;
/