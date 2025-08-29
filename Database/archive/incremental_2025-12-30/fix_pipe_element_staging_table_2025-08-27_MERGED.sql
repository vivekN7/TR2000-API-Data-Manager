-- ===============================================================================
-- Fix STG_PIPE_ELEMENT_REFERENCES Table Structure
-- Date: 2025-08-27
-- Purpose: Recreate table with correct columns to match API and parsing logic
-- ===============================================================================

-- Drop the incorrectly structured table
DROP TABLE STG_PIPE_ELEMENT_REFERENCES CASCADE CONSTRAINTS;

-- Recreate with correct structure
CREATE TABLE STG_PIPE_ELEMENT_REFERENCES (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    mds                 VARCHAR2(100),
    name                VARCHAR2(200),
    revision            VARCHAR2(50),
    rev_date            VARCHAR2(50),
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50)
);

COMMENT ON TABLE STG_PIPE_ELEMENT_REFERENCES IS 'Staging table for Pipe Element references from API';

-- Verify the structure
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM user_tab_columns
    WHERE table_name = 'STG_PIPE_ELEMENT_REFERENCES'
    AND column_name IN ('MDS', 'NAME', 'OFFICIAL_REVISION');
    
    IF v_count = 3 THEN
        DBMS_OUTPUT.PUT_LINE('✅ STG_PIPE_ELEMENT_REFERENCES recreated with correct structure');
    ELSE
        DBMS_OUTPUT.PUT_LINE('❌ STG_PIPE_ELEMENT_REFERENCES structure issue');
    END IF;
END;
/

PROMPT
PROMPT ===============================================================================
PROMPT STG_PIPE_ELEMENT_REFERENCES fixed with correct structure
PROMPT ===============================================================================