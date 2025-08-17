-- =====================================================
-- TEST HASH FUNCTIONS IN ORACLE XE
-- =====================================================

-- Test 1: Direct ORA_HASH call
SELECT 'Test 1: ORA_HASH directly' as TEST FROM DUAL;
SELECT ORA_HASH('test string') as HASH_VALUE FROM DUAL;

-- Test 2: Direct STANDARD_HASH call (12c+)
SELECT 'Test 2: STANDARD_HASH directly' as TEST FROM DUAL;
SELECT STANDARD_HASH('test string', 'SHA256') as HASH_VALUE FROM DUAL;

-- Test 3: DBMS_CRYPTO (might need grants)
SELECT 'Test 3: DBMS_CRYPTO' as TEST FROM DUAL;
DECLARE
    v_hash RAW(32);
BEGIN
    v_hash := DBMS_CRYPTO.HASH(UTL_RAW.CAST_TO_RAW('test string'), DBMS_CRYPTO.HASH_SH256);
    DBMS_OUTPUT.PUT_LINE('Hash: ' || RAWTOHEX(v_hash));
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

-- Test 4: Check Oracle version
SELECT 'Oracle Version Info:' as INFO FROM DUAL;
SELECT * FROM v$version;

-- Test 5: Create a simple function with ORA_HASH
CREATE OR REPLACE FUNCTION TEST_ORA_HASH(p_input VARCHAR2) 
RETURN NUMBER
AS
BEGIN
    RETURN ORA_HASH(p_input);
END;
/

-- Test the function
SELECT TEST_ORA_HASH('test') as HASH_RESULT FROM DUAL;

-- Test 6: Create a simple function with STANDARD_HASH
CREATE OR REPLACE FUNCTION TEST_STANDARD_HASH(p_input VARCHAR2) 
RETURN VARCHAR2
AS
BEGIN
    RETURN STANDARD_HASH(p_input, 'SHA256');
END;
/

-- Test the function
SELECT TEST_STANDARD_HASH('test') as HASH_RESULT FROM DUAL;

-- Clean up test functions
DROP FUNCTION TEST_ORA_HASH;
DROP FUNCTION TEST_STANDARD_HASH;