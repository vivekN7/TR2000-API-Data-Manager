-- ===============================================================================
-- Fix Missing Columns in Reference Staging Tables
-- Date: 2025-08-27
-- Purpose: Add missing columns to staging tables to capture ALL API data
-- ===============================================================================

-- Add missing columns to STG_VDS_REFERENCES
ALTER TABLE STG_VDS_REFERENCES ADD (
    rating_class    VARCHAR2(100),
    material_group  VARCHAR2(100),
    bolt_material   VARCHAR2(100),
    gasket_type     VARCHAR2(100)
);

-- Add missing columns to STG_MDS_REFERENCES (if needed)
ALTER TABLE STG_MDS_REFERENCES ADD (
    rating_class    VARCHAR2(100),
    material_group  VARCHAR2(100)
);

-- Verify all staging tables have the columns they need
DECLARE
    v_count NUMBER;
BEGIN
    -- Check STG_VDS_REFERENCES
    SELECT COUNT(*) INTO v_count
    FROM user_tab_columns
    WHERE table_name = 'STG_VDS_REFERENCES'
    AND column_name IN ('RATING_CLASS', 'MATERIAL_GROUP', 'BOLT_MATERIAL', 'GASKET_TYPE');
    
    IF v_count = 4 THEN
        DBMS_OUTPUT.PUT_LINE('✅ STG_VDS_REFERENCES has all required columns');
    ELSE
        DBMS_OUTPUT.PUT_LINE('❌ STG_VDS_REFERENCES missing columns: ' || (4 - v_count));
    END IF;
    
    -- Check STG_MDS_REFERENCES
    SELECT COUNT(*) INTO v_count
    FROM user_tab_columns
    WHERE table_name = 'STG_MDS_REFERENCES'
    AND column_name IN ('RATING_CLASS', 'MATERIAL_GROUP', 'AREA');
    
    IF v_count = 3 THEN
        DBMS_OUTPUT.PUT_LINE('✅ STG_MDS_REFERENCES has all required columns');
    ELSE
        DBMS_OUTPUT.PUT_LINE('❌ STG_MDS_REFERENCES missing columns: ' || (3 - v_count));
    END IF;
END;
/

PROMPT
PROMPT ===============================================================================
PROMPT Staging table columns fixed - Now all API data will be captured
PROMPT ===============================================================================