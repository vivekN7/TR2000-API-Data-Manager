-- =====================================================
-- TEST SCD2 CHANGE DETECTION
-- =====================================================

-- 1. View current operators with their hashes
SELECT 
    OPERATOR_ID,
    OPERATOR_NAME,
    SRC_HASH,
    VALID_FROM,
    VALID_TO,
    IS_CURRENT
FROM OPERATORS
ORDER BY OPERATOR_ID, VALID_FROM;

-- 2. Check what the hash SHOULD be for a changed name
SELECT 
    OPERATOR_ID,
    OPERATOR_NAME,
    STANDARD_HASH(
        NVL(TO_CHAR(OPERATOR_ID), '~') || '|' ||
        NVL(OPERATOR_NAME, '~'),
        'SHA256'
    ) as COMPUTED_HASH,
    SRC_HASH as STORED_HASH
FROM OPERATORS
WHERE IS_CURRENT = 'Y'
AND OPERATOR_ID = 1;

-- 3. Simulate an API change by modifying operator name
-- This will make the stored hash mismatch what the ETL computes
UPDATE OPERATORS 
SET OPERATOR_NAME = OPERATOR_NAME || ' (Modified)'
WHERE OPERATOR_ID = 1 
AND IS_CURRENT = 'Y';

-- 4. Verify the change
SELECT 
    OPERATOR_ID,
    OPERATOR_NAME,
    STANDARD_HASH(
        NVL(TO_CHAR(OPERATOR_ID), '~') || '|' ||
        NVL(OPERATOR_NAME, '~'),
        'SHA256'
    ) as NEW_HASH_WOULD_BE,
    SRC_HASH as OLD_HASH_STORED
FROM OPERATORS
WHERE OPERATOR_ID = 1 
AND IS_CURRENT = 'Y';

-- Now when you reload operators via the UI, it should detect this as a change!

-- 5. After testing, view the history
SELECT 
    OPERATOR_ID,
    OPERATOR_NAME,
    VALID_FROM,
    VALID_TO,
    IS_CURRENT,
    CASE 
        WHEN IS_CURRENT = 'Y' THEN 'Current Version'
        ELSE 'Historical Version'
    END as VERSION_STATUS
FROM OPERATORS
WHERE OPERATOR_ID = 1
ORDER BY VALID_FROM DESC;

-- 6. To reset and test again:
-- Delete the modified record
DELETE FROM OPERATORS 
WHERE OPERATOR_ID = 1 
AND OPERATOR_NAME LIKE '%(Modified)%';

-- Restore the original as current
UPDATE OPERATORS 
SET IS_CURRENT = 'Y', VALID_TO = NULL
WHERE OPERATOR_ID = 1
AND IS_CURRENT = 'N';