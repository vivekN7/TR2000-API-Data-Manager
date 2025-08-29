-- ===============================================================================
-- Run ETL Process Naturally
-- Date: 2025-12-30
-- Purpose: Let the ETL run as designed without manual data insertion
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
BEGIN
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('Starting Natural ETL Process');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
    -- The ETL should handle everything:
    -- 1. Load plants if needed
    -- 2. Process selections
    -- 3. Load issues for selected plants
    -- 4. Load references for selected issues
    -- 5. Load details as configured
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Calling run_full_etl to let it handle everything...');
    
    pkg_etl_operations.run_full_etl(v_status, v_msg);
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('ETL Result: ' || v_status);
    IF v_msg IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Message: ' || v_msg);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    DBMS_OUTPUT.PUT_LINE('ETL Process Complete');
    DBMS_OUTPUT.PUT_LINE('===============================================');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Stack: ' || DBMS_UTILITY.FORMAT_ERROR_STACK());
        RAISE;
END;
/

-- Check what was loaded
PROMPT
PROMPT Data Loaded by ETL:
PROMPT ===================

SELECT 'Plants' as entity, COUNT(*) as count FROM PLANTS WHERE is_valid = 'Y'
UNION ALL
SELECT 'Issues', COUNT(*) FROM ISSUES WHERE is_valid = 'Y'
UNION ALL
SELECT 'PCS References', COUNT(*) FROM PCS_REFERENCES WHERE is_valid = 'Y'
UNION ALL
SELECT 'VDS References', COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y'
UNION ALL
SELECT 'MDS References', COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y'
UNION ALL
SELECT 'Total References', 
    (SELECT COUNT(*) FROM PCS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM SC_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM VSM_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM EDS_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM ESK_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM VSK_REFERENCES WHERE is_valid = 'Y') +
    (SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y')
FROM DUAL;

EXIT;