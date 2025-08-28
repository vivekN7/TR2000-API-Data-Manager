-- ===============================================================================
-- Fix PCS Detail Tables - Remove issue_revision dependency
-- Date: 2025-12-01
-- Purpose: PCS details should link to PCS_LIST, not to specific issues
-- The flow is: Get ALL PCS revisions for plant, then load details for ALL
-- ===============================================================================

-- Drop existing foreign key constraints that reference issue_revision
BEGIN
    FOR c IN (
        SELECT constraint_name, table_name
        FROM user_constraints
        WHERE constraint_type = 'R'
        AND table_name IN (
            'PCS_HEADER_PROPERTIES', 'PCS_TEMP_PRESSURES', 'PCS_PIPE_SIZES',
            'PCS_PIPE_ELEMENTS', 'PCS_VALVE_ELEMENTS', 'PCS_EMBEDDED_NOTES'
        )
        AND constraint_name LIKE '%REF%'
    ) LOOP
        EXECUTE IMMEDIATE 'ALTER TABLE ' || c.table_name || ' DROP CONSTRAINT ' || c.constraint_name;
        DBMS_OUTPUT.PUT_LINE('Dropped constraint ' || c.constraint_name || ' from ' || c.table_name);
    END LOOP;
END;
/

-- Make issue_revision nullable in detail tables (for backward compatibility)
ALTER TABLE PCS_HEADER_PROPERTIES MODIFY issue_revision VARCHAR2(50) NULL;
ALTER TABLE PCS_TEMP_PRESSURES MODIFY issue_revision VARCHAR2(50) NULL;
ALTER TABLE PCS_PIPE_SIZES MODIFY issue_revision VARCHAR2(50) NULL;
ALTER TABLE PCS_PIPE_ELEMENTS MODIFY issue_revision VARCHAR2(50) NULL;
ALTER TABLE PCS_VALVE_ELEMENTS MODIFY issue_revision VARCHAR2(50) NULL;
ALTER TABLE PCS_EMBEDDED_NOTES MODIFY issue_revision VARCHAR2(50) NULL;

-- Add foreign key constraints to PCS_LIST instead
ALTER TABLE PCS_HEADER_PROPERTIES 
ADD CONSTRAINT FK_PCS_HEADER_LIST 
FOREIGN KEY (plant_id, pcs_name, revision) 
REFERENCES PCS_LIST(plant_id, pcs_name, revision);

ALTER TABLE PCS_TEMP_PRESSURES 
ADD CONSTRAINT FK_PCS_TEMP_LIST 
FOREIGN KEY (plant_id, pcs_name, revision) 
REFERENCES PCS_LIST(plant_id, pcs_name, revision);

ALTER TABLE PCS_PIPE_SIZES 
ADD CONSTRAINT FK_PCS_SIZES_LIST 
FOREIGN KEY (plant_id, pcs_name, revision) 
REFERENCES PCS_LIST(plant_id, pcs_name, revision);

ALTER TABLE PCS_PIPE_ELEMENTS 
ADD CONSTRAINT FK_PCS_ELEM_LIST 
FOREIGN KEY (plant_id, pcs_name, revision) 
REFERENCES PCS_LIST(plant_id, pcs_name, revision);

ALTER TABLE PCS_VALVE_ELEMENTS 
ADD CONSTRAINT FK_PCS_VALVE_LIST 
FOREIGN KEY (plant_id, pcs_name, revision) 
REFERENCES PCS_LIST(plant_id, pcs_name, revision);

ALTER TABLE PCS_EMBEDDED_NOTES 
ADD CONSTRAINT FK_PCS_NOTES_LIST 
FOREIGN KEY (plant_id, pcs_name, revision) 
REFERENCES PCS_LIST(plant_id, pcs_name, revision);