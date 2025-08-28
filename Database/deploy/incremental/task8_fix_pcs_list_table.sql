-- ===============================================================================
-- PCS_LIST Tables for storing ALL PCS revisions for a plant
-- Date: 2025-08-29
-- Purpose: Fix Task 8 to use correct flow - store all plant PCS revisions
-- ===============================================================================

-- Drop existing tables if they exist (for clean restart)
BEGIN
    FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN ('STG_PCS_LIST', 'PCS_LIST')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
END;
/

-- ===============================================================================
-- STAGING TABLE for plant/{plantid}/pcs endpoint response
-- ===============================================================================
CREATE TABLE STG_PCS_LIST (
    plant_id            VARCHAR2(50),
    pcs                 VARCHAR2(100),
    revision            VARCHAR2(50),
    status              VARCHAR2(50),
    rev_date            VARCHAR2(50),
    rating_class        VARCHAR2(100),
    test_pressure       VARCHAR2(50),
    material_group      VARCHAR2(100),
    design_code         VARCHAR2(100),
    last_update         VARCHAR2(50),
    last_update_by      VARCHAR2(100),
    approver            VARCHAR2(100),
    notepad             VARCHAR2(4000),
    special_req_id      VARCHAR2(50),
    tube_pcs            VARCHAR2(100),
    new_vds_section     VARCHAR2(100)
);

COMMENT ON TABLE STG_PCS_LIST IS 'Staging table for ALL PCS revisions from plant-level API endpoint';

-- ===============================================================================
-- CORE TABLE for ALL PCS revisions for a plant
-- ===============================================================================
CREATE TABLE PCS_LIST (
    pcs_list_guid       RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    pcs_name            VARCHAR2(100) NOT NULL,
    revision            VARCHAR2(50) NOT NULL,
    status              VARCHAR2(50),
    rev_date            DATE,
    rating_class        VARCHAR2(100),
    test_pressure       NUMBER(10,2),
    material_group      VARCHAR2(100),
    design_code         VARCHAR2(100),
    last_update         DATE,
    last_update_by      VARCHAR2(100),
    approver            VARCHAR2(100),
    notepad             CLOB,
    special_req_id      NUMBER(10),
    tube_pcs            VARCHAR2(100),
    new_vds_section     VARCHAR2(100),
    -- Standard fields
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    last_api_sync       TIMESTAMP,
    api_correlation_id  VARCHAR2(36),
    -- Constraints
    CONSTRAINT PK_PCS_LIST PRIMARY KEY (pcs_list_guid),
    CONSTRAINT UK_PCS_LIST UNIQUE (plant_id, pcs_name, revision),
    CONSTRAINT FK_PCS_LIST_PLANT FOREIGN KEY (plant_id) 
        REFERENCES PLANTS(plant_id)
);

-- Create indexes for performance
CREATE INDEX IDX_PCS_LIST_PLANT ON PCS_LIST(plant_id);
CREATE INDEX IDX_PCS_LIST_PCS ON PCS_LIST(pcs_name);
CREATE INDEX IDX_PCS_LIST_REV ON PCS_LIST(revision);
CREATE INDEX IDX_PCS_LIST_VALID ON PCS_LIST(is_valid);

COMMENT ON TABLE PCS_LIST IS 'All PCS revisions for all plants from endpoint 3.1';
COMMENT ON COLUMN PCS_LIST.pcs_list_guid IS 'Unique identifier for this PCS revision record';
COMMENT ON COLUMN PCS_LIST.plant_id IS 'Plant identifier';
COMMENT ON COLUMN PCS_LIST.pcs_name IS 'PCS name/identifier';
COMMENT ON COLUMN PCS_LIST.revision IS 'PCS revision';
COMMENT ON COLUMN PCS_LIST.is_valid IS 'Soft delete flag (Y=active, N=deleted)';

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON STG_PCS_LIST TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON PCS_LIST TO TR2000_STAGING;