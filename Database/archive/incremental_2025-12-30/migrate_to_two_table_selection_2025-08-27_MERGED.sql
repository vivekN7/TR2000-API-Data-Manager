-- ===============================================================================
-- Migration to Two-Table Selection Design
-- Date: 2025-08-27
-- Purpose: Replace single SELECTION_LOADER table with SELECTED_PLANTS and SELECTED_ISSUES
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ===============================================================================
PROMPT Starting Migration to Two-Table Selection Design
PROMPT ===============================================================================

-- ===============================================================================
-- STEP 1: Create New Tables
-- ===============================================================================

PROMPT Creating SELECTED_PLANTS table...

CREATE TABLE SELECTED_PLANTS (
    plant_id            VARCHAR2(50) NOT NULL,
    is_active           CHAR(1) DEFAULT 'Y' NOT NULL,
    selected_by         VARCHAR2(50),
    selection_date      DATE DEFAULT SYSDATE,
    last_refresh        TIMESTAMP,
    plant_guid          RAW(16),
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_SELECTED_PLANTS PRIMARY KEY (plant_id),
    CONSTRAINT CHK_SEL_PLANT_ACTIVE CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT FK_SELECTED_PLANT_GUID FOREIGN KEY (plant_guid) 
        REFERENCES PLANTS(plant_guid)
);

CREATE INDEX IDX_SEL_PLANTS_ACTIVE ON SELECTED_PLANTS(is_active);
CREATE INDEX IDX_SEL_PLANTS_GUID ON SELECTED_PLANTS(plant_guid);

COMMENT ON TABLE SELECTED_PLANTS IS 'Plants selected for ETL processing';
COMMENT ON COLUMN SELECTED_PLANTS.plant_id IS 'Plant identifier (primary key)';
COMMENT ON COLUMN SELECTED_PLANTS.is_active IS 'Y=Selected for processing, N=Deselected';
COMMENT ON COLUMN SELECTED_PLANTS.selected_by IS 'User who selected this plant';
COMMENT ON COLUMN SELECTED_PLANTS.selection_date IS 'When plant was first selected';
COMMENT ON COLUMN SELECTED_PLANTS.last_refresh IS 'Last time plant data was refreshed from API';
COMMENT ON COLUMN SELECTED_PLANTS.plant_guid IS 'Link to PLANTS table';

PROMPT Creating SELECTED_ISSUES table...

CREATE TABLE SELECTED_ISSUES (
    plant_id            VARCHAR2(50) NOT NULL,
    issue_revision      VARCHAR2(50) NOT NULL,
    is_active           CHAR(1) DEFAULT 'Y' NOT NULL,
    selected_by         VARCHAR2(50),
    selection_date      DATE DEFAULT SYSDATE,
    last_etl_run        TIMESTAMP,
    etl_status          VARCHAR2(50),
    issue_guid          RAW(16),
    reference_count     NUMBER DEFAULT 0,
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_SELECTED_ISSUES PRIMARY KEY (plant_id, issue_revision),
    CONSTRAINT CHK_SEL_ISSUE_ACTIVE CHECK (is_active IN ('Y', 'N')),
    CONSTRAINT FK_SEL_ISSUE_PLANT FOREIGN KEY (plant_id) 
        REFERENCES SELECTED_PLANTS(plant_id),
    CONSTRAINT FK_SELECTED_ISSUE_GUID FOREIGN KEY (issue_guid) 
        REFERENCES ISSUES(issue_guid)
);

CREATE INDEX IDX_SEL_ISSUES_ACTIVE ON SELECTED_ISSUES(is_active);
CREATE INDEX IDX_SEL_ISSUES_PLANT ON SELECTED_ISSUES(plant_id);
CREATE INDEX IDX_SEL_ISSUES_GUID ON SELECTED_ISSUES(issue_guid);

COMMENT ON TABLE SELECTED_ISSUES IS 'Issues within selected plants chosen for ETL processing';
COMMENT ON COLUMN SELECTED_ISSUES.plant_id IS 'Plant this issue belongs to';
COMMENT ON COLUMN SELECTED_ISSUES.issue_revision IS 'Issue revision identifier';
COMMENT ON COLUMN SELECTED_ISSUES.is_active IS 'Y=Selected for processing, N=Deselected';
COMMENT ON COLUMN SELECTED_ISSUES.selected_by IS 'User who selected this issue';
COMMENT ON COLUMN SELECTED_ISSUES.selection_date IS 'When issue was first selected';
COMMENT ON COLUMN SELECTED_ISSUES.last_etl_run IS 'Last time ETL ran for this issue';
COMMENT ON COLUMN SELECTED_ISSUES.etl_status IS 'Status of last ETL run';
COMMENT ON COLUMN SELECTED_ISSUES.issue_guid IS 'Link to ISSUES table';
COMMENT ON COLUMN SELECTED_ISSUES.reference_count IS 'Total number of references loaded';

-- ===============================================================================
-- STEP 2: Create Cascade Trigger (Plant → Issues)
-- ===============================================================================

PROMPT Creating cascade trigger for plant deselection...

CREATE OR REPLACE TRIGGER TRG_CASCADE_PLANT_TO_ISSUES
AFTER UPDATE OF is_active ON SELECTED_PLANTS
FOR EACH ROW
WHEN (NEW.is_active = 'N' AND OLD.is_active = 'Y')
BEGIN
    -- When a plant is deselected, deselect all its issues
    UPDATE SELECTED_ISSUES
    SET is_active = 'N',
        etl_status = 'DESELECTED_BY_CASCADE'
    WHERE plant_id = :NEW.plant_id
      AND is_active = 'Y';
    
    -- Log the cascade
    INSERT INTO CASCADE_LOG (
        cascade_type, source_table, source_id, 
        target_table, affected_count, cascade_timestamp,
        trigger_name, action_taken
    ) VALUES (
        'PLANT_TO_ISSUES', 'SELECTED_PLANTS', :NEW.plant_id,
        'SELECTED_ISSUES', SQL%ROWCOUNT, SYSTIMESTAMP,
        'TRG_CASCADE_PLANT_TO_ISSUES', 
        'Deselected ' || SQL%ROWCOUNT || ' issues due to plant deselection'
    );
END;
/

-- ===============================================================================
-- STEP 3: Migrate Data from SELECTION_LOADER
-- ===============================================================================

PROMPT Migrating existing data...

DECLARE
    v_plant_count NUMBER := 0;
    v_issue_count NUMBER := 0;
BEGIN
    -- Migrate plant selections (records with NULL issue_revision)
    FOR rec IN (
        SELECT DISTINCT plant_id, is_active, selected_by, selection_date, 
               last_etl_run, plant_guid
        FROM SELECTION_LOADER
        WHERE issue_revision IS NULL
    ) LOOP
        INSERT INTO SELECTED_PLANTS (
            plant_id, is_active, selected_by, selection_date, 
            last_refresh, plant_guid
        ) VALUES (
            rec.plant_id, rec.is_active, rec.selected_by, 
            rec.selection_date, rec.last_etl_run, rec.plant_guid
        );
        v_plant_count := v_plant_count + 1;
    END LOOP;
    
    -- Also ensure all plants with issues are in SELECTED_PLANTS
    FOR rec IN (
        SELECT DISTINCT plant_id, plant_guid
        FROM SELECTION_LOADER
        WHERE issue_revision IS NOT NULL
          AND plant_id NOT IN (SELECT plant_id FROM SELECTED_PLANTS)
    ) LOOP
        INSERT INTO SELECTED_PLANTS (
            plant_id, is_active, selected_by, selection_date, plant_guid
        ) VALUES (
            rec.plant_id, 'Y', 'MIGRATION', SYSDATE, rec.plant_guid
        );
        v_plant_count := v_plant_count + 1;
    END LOOP;
    
    -- Migrate issue selections (records with issue_revision)
    FOR rec IN (
        SELECT plant_id, issue_revision, is_active, selected_by, 
               selection_date, last_etl_run, etl_status, issue_guid
        FROM SELECTION_LOADER
        WHERE issue_revision IS NOT NULL
    ) LOOP
        INSERT INTO SELECTED_ISSUES (
            plant_id, issue_revision, is_active, selected_by, 
            selection_date, last_etl_run, etl_status, issue_guid
        ) VALUES (
            rec.plant_id, rec.issue_revision, rec.is_active, 
            rec.selected_by, rec.selection_date, rec.last_etl_run, 
            rec.etl_status, rec.issue_guid
        );
        v_issue_count := v_issue_count + 1;
    END LOOP;
    
    -- Update reference counts for selected issues
    UPDATE SELECTED_ISSUES si
    SET reference_count = (
        SELECT COUNT(*) FROM (
            SELECT COUNT(*) FROM PCS_REFERENCES WHERE plant_id = si.plant_id AND issue_revision = si.issue_revision AND is_valid = 'Y'
            UNION ALL
            SELECT COUNT(*) FROM VDS_REFERENCES WHERE plant_id = si.plant_id AND issue_revision = si.issue_revision AND is_valid = 'Y'
            UNION ALL
            SELECT COUNT(*) FROM MDS_REFERENCES WHERE plant_id = si.plant_id AND issue_revision = si.issue_revision AND is_valid = 'Y'
            UNION ALL
            SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE plant_id = si.plant_id AND issue_revision = si.issue_revision AND is_valid = 'Y'
        )
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Migration complete:');
    DBMS_OUTPUT.PUT_LINE('  Plants migrated: ' || v_plant_count);
    DBMS_OUTPUT.PUT_LINE('  Issues migrated: ' || v_issue_count);
END;
/

-- ===============================================================================
-- STEP 4: Verify Migration
-- ===============================================================================

PROMPT Verifying migration...

SELECT 'SELECTED_PLANTS' as table_name, COUNT(*) as record_count FROM SELECTED_PLANTS
UNION ALL
SELECT 'SELECTED_ISSUES', COUNT(*) FROM SELECTED_ISSUES
UNION ALL
SELECT 'Old SELECTION_LOADER', COUNT(*) FROM SELECTION_LOADER;

-- ===============================================================================
-- STEP 5: Create helper views for compatibility
-- ===============================================================================

PROMPT Creating compatibility view...

CREATE OR REPLACE VIEW V_SELECTED_ITEMS AS
SELECT 
    sp.plant_id,
    si.issue_revision,
    CASE 
        WHEN si.issue_revision IS NOT NULL THEN si.is_active
        ELSE sp.is_active
    END as is_active,
    CASE 
        WHEN si.issue_revision IS NOT NULL THEN 'ISSUE'
        ELSE 'PLANT'
    END as selection_type,
    COALESCE(si.selected_by, sp.selected_by) as selected_by,
    COALESCE(si.selection_date, sp.selection_date) as selection_date,
    si.last_etl_run,
    si.etl_status,
    si.reference_count
FROM SELECTED_PLANTS sp
LEFT JOIN SELECTED_ISSUES si ON sp.plant_id = si.plant_id;

COMMENT ON VIEW V_SELECTED_ITEMS IS 'Unified view of selected plants and issues';

PROMPT
PROMPT ===============================================================================
PROMPT Migration Script Complete - DO NOT DROP SELECTION_LOADER YET!
PROMPT ===============================================================================
PROMPT Next steps:
PROMPT   1. Update PKG_API_CLIENT to use SELECTED_ISSUES
PROMPT   2. Update refresh_all_data_from_api to use SELECTED_ISSUES
PROMPT   3. Update PKG_TEST_ISOLATION
PROMPT   4. Test thoroughly
PROMPT   5. Then run: DROP TABLE SELECTION_LOADER CASCADE CONSTRAINTS;
PROMPT ===============================================================================