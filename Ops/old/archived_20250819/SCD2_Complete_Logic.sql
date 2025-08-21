-- =====================================================
-- COMPLETE SCD2 LOGIC - Handles ALL Change Scenarios
-- =====================================================

-- This shows the COMPLETE logic needed for proper SCD2:
-- 1. NEW records - Insert with IS_CURRENT='Y'
-- 2. CHANGED records - Expire old, insert new
-- 3. UNCHANGED records - Do nothing
-- 4. DELETED records - Mark as logically deleted (IS_DELETED='Y')

CREATE OR REPLACE PROCEDURE SP_PROCESS_OPERATORS_SCD2_COMPLETE(
    p_etl_run_id IN NUMBER
) AS
    v_records_unchanged NUMBER := 0;
    v_records_updated   NUMBER := 0;
    v_records_inserted  NUMBER := 0;
    v_records_deleted   NUMBER := 0;
BEGIN
    -- Step 1: Mark DELETED records (in DB but not in staging)
    -- These are records that disappeared from the API
    UPDATE OPERATORS o
    SET o.VALID_TO = SYSDATE, 
        o.IS_CURRENT = 'N',
        o.IS_DELETED = 'Y'  -- Need to add this column!
    WHERE o.IS_CURRENT = 'Y'
      AND NOT EXISTS (
        SELECT 1 FROM STG_OPERATORS s
        WHERE s.OPERATOR_ID = o.OPERATOR_ID
      );
    
    v_records_deleted := SQL%ROWCOUNT;
    
    -- Step 2: Count unchanged records
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
    
    -- Step 4: Insert new versions for changed records
    INSERT INTO OPERATORS (
        OPERATOR_ID, OPERATOR_NAME, SRC_HASH, 
        VALID_FROM, IS_CURRENT, IS_DELETED, ETL_RUN_ID
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
        'N',
        p_etl_run_id
    FROM STG_OPERATORS s
    WHERE EXISTS (
        SELECT 1 FROM OPERATORS o
        WHERE o.OPERATOR_ID = s.OPERATOR_ID
          AND o.VALID_TO = SYSDATE
          AND o.IS_DELETED = 'N'  -- Don't reinsert if it was a delete
    );
    
    -- Step 5: Insert completely new records
    INSERT INTO OPERATORS (
        OPERATOR_ID, OPERATOR_NAME, SRC_HASH,
        VALID_FROM, IS_CURRENT, IS_DELETED, ETL_RUN_ID
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
        'N',
        p_etl_run_id
    FROM STG_OPERATORS s
    WHERE NOT EXISTS (
        SELECT 1 FROM OPERATORS o
        WHERE o.OPERATOR_ID = s.OPERATOR_ID
    );
    
    v_records_inserted := SQL%ROWCOUNT;
    
    -- Update ETL Control
    UPDATE ETL_CONTROL
    SET RECORDS_UNCHANGED = v_records_unchanged,
        RECORDS_UPDATED = v_records_updated,
        RECORDS_LOADED = v_records_inserted,
        RECORDS_DELETED = v_records_deleted  -- Need to add this column
    WHERE ETL_RUN_ID = p_etl_run_id;
    
    DELETE FROM STG_OPERATORS WHERE ETL_RUN_ID = p_etl_run_id;
    
    COMMIT;
END;
/

-- =====================================================
-- Alternative: Soft Delete Approach (Simpler)
-- =====================================================

-- Instead of IS_DELETED column, just mark as not current
-- and add a DELETE_DATE column

ALTER TABLE OPERATORS ADD (DELETE_DATE DATE);
ALTER TABLE PLANTS ADD (DELETE_DATE DATE);
ALTER TABLE ISSUES ADD (DELETE_DATE DATE);

-- Then in Step 1:
UPDATE OPERATORS o
SET o.VALID_TO = SYSDATE, 
    o.IS_CURRENT = 'N',
    o.DELETE_DATE = SYSDATE  -- Mark when it was deleted
WHERE o.IS_CURRENT = 'Y'
  AND NOT EXISTS (
    SELECT 1 FROM STG_OPERATORS s
    WHERE s.OPERATOR_ID = o.OPERATOR_ID
  );

-- =====================================================
-- View to Show Only Active (Non-Deleted) Records
-- =====================================================

CREATE OR REPLACE VIEW V_OPERATORS_ACTIVE AS
SELECT * FROM OPERATORS
WHERE IS_CURRENT = 'Y'
  AND DELETE_DATE IS NULL;  -- Exclude logically deleted