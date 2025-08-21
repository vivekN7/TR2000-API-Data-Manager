-- Simple test to check Oracle XE hash support
-- Run this directly in Oracle XE

-- Test 1: Check version
SELECT BANNER FROM V$VERSION WHERE ROWNUM = 1;

-- Test 2: Try STANDARD_HASH (12c+)
SELECT STANDARD_HASH('test string', 'SHA256') as HASH_VALUE FROM DUAL;

-- Test 3: Try ORA_HASH (older versions)
SELECT ORA_HASH('test string') as HASH_VALUE FROM DUAL;

-- Test 4: Test with concatenated values (like our ETL would use)
SELECT STANDARD_HASH('123|Plant Name|Description|5|CODE', 'SHA256') as HASH_VALUE FROM DUAL;