-- ===============================================================================
-- PCS Details Tables - Task 8
-- Date: 2025-12-01
-- Purpose: Core and staging tables for PCS list and 6 PCS detail types
-- Note: PCS_LIST contains ALL PCS revisions for a plant
--       Detail tables link to PCS_LIST via (plant_id, pcs_name, revision)
-- ===============================================================================

-- ===============================================================================
-- PCS_LIST TABLES - Store ALL PCS revisions for plants
-- ===============================================================================

-- Staging table for plant/{plantid}/pcs endpoint response
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

-- Core table for ALL PCS revisions for a plant
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

-- ===============================================================================
-- PCS DETAIL STAGING TABLES (All VARCHAR2 for JSON parsing)
-- ===============================================================================

-- STG_PCS_HEADER_PROPERTIES (Extended PCS information from endpoint 3.2)
CREATE TABLE STG_PCS_HEADER_PROPERTIES (
    plant_id                    VARCHAR2(50),
    issue_revision              VARCHAR2(50),
    pcs_name                    VARCHAR2(100),
    revision                    VARCHAR2(50),
    status                      VARCHAR2(50),
    rev_date                    VARCHAR2(50),
    rating_class                VARCHAR2(100),
    test_pressure               VARCHAR2(50),
    material_group              VARCHAR2(100),
    design_code                 VARCHAR2(100),
    last_update                 VARCHAR2(50),
    last_update_by              VARCHAR2(100),
    approver                    VARCHAR2(100),
    notepad                     VARCHAR2(4000),
    sc                          VARCHAR2(100),
    vsm                         VARCHAR2(100),
    design_code_rev_mark        VARCHAR2(50),
    corr_allowance              VARCHAR2(50),
    corr_allowance_rev_mark     VARCHAR2(50),
    long_weld_eff               VARCHAR2(50),
    long_weld_eff_rev_mark      VARCHAR2(50),
    wall_thk_tol                VARCHAR2(50),
    wall_thk_tol_rev_mark       VARCHAR2(50),
    service_remark              VARCHAR2(500),
    service_remark_rev_mark     VARCHAR2(50),
    -- Design pressures (12 columns)
    design_press01              VARCHAR2(50),
    design_press02              VARCHAR2(50),
    design_press03              VARCHAR2(50),
    design_press04              VARCHAR2(50),
    design_press05              VARCHAR2(50),
    design_press06              VARCHAR2(50),
    design_press07              VARCHAR2(50),
    design_press08              VARCHAR2(50),
    design_press09              VARCHAR2(50),
    design_press10              VARCHAR2(50),
    design_press11              VARCHAR2(50),
    design_press12              VARCHAR2(50),
    design_press_rev_mark       VARCHAR2(50),
    -- Design temperatures (12 columns)
    design_temp01               VARCHAR2(50),
    design_temp02               VARCHAR2(50),
    design_temp03               VARCHAR2(50),
    design_temp04               VARCHAR2(50),
    design_temp05               VARCHAR2(50),
    design_temp06               VARCHAR2(50),
    design_temp07               VARCHAR2(50),
    design_temp08               VARCHAR2(50),
    design_temp09               VARCHAR2(50),
    design_temp10               VARCHAR2(50),
    design_temp11               VARCHAR2(50),
    design_temp12               VARCHAR2(50),
    design_temp_rev_mark        VARCHAR2(50),
    -- Note IDs
    note_id_corr_allowance      VARCHAR2(50),
    note_id_service_code        VARCHAR2(50),
    note_id_wall_thk_tol        VARCHAR2(50),
    note_id_long_weld_eff       VARCHAR2(50),
    note_id_general_pcs         VARCHAR2(50),
    note_id_design_code         VARCHAR2(50),
    note_id_press_temp_table    VARCHAR2(50),
    note_id_pipe_size_wth_table VARCHAR2(50),
    -- Additional fields
    press_element_change        VARCHAR2(50),
    temp_element_change         VARCHAR2(50),
    material_group_id           VARCHAR2(50),
    special_req_id              VARCHAR2(50),
    special_req                 VARCHAR2(500),
    new_vds_section             VARCHAR2(100),
    tube_pcs                    VARCHAR2(100),
    eds_mj_matrix               VARCHAR2(100),
    mj_reduction_factor         VARCHAR2(50)
);

-- STG_PCS_TEMP_PRESSURES (Temperature/Pressure pairs from endpoint 3.3)
CREATE TABLE STG_PCS_TEMP_PRESSURES (
    plant_id                VARCHAR2(50),
    issue_revision          VARCHAR2(50),
    pcs_name                VARCHAR2(100),
    revision                VARCHAR2(50),
    temperature             VARCHAR2(50),
    pressure                VARCHAR2(50)
);

-- STG_PCS_PIPE_SIZES (Pipe size specifications from endpoint 3.4)
CREATE TABLE STG_PCS_PIPE_SIZES (
    plant_id                VARCHAR2(50),
    issue_revision          VARCHAR2(50),
    pcs_name                VARCHAR2(100),
    revision                VARCHAR2(50),
    nom_size                VARCHAR2(50),
    outer_diam              VARCHAR2(50),
    wall_thickness          VARCHAR2(50),
    schedule                VARCHAR2(50),
    under_tolerance         VARCHAR2(50),
    corrosion_allowance     VARCHAR2(50),
    welding_factor          VARCHAR2(50),
    dim_element_change      VARCHAR2(50),
    schedule_in_matrix      VARCHAR2(50)
);

-- STG_PCS_PIPE_ELEMENTS (Pipe element specifications from endpoint 3.5)
CREATE TABLE STG_PCS_PIPE_ELEMENTS (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    pcs_name            VARCHAR2(100),
    revision            VARCHAR2(50),
    material_group_id   VARCHAR2(50),
    element_group_no    VARCHAR2(50),
    line_no             VARCHAR2(50),
    element             VARCHAR2(200),
    dim_standard        VARCHAR2(100),
    from_size           VARCHAR2(50),
    to_size             VARCHAR2(50),
    product_form        VARCHAR2(100),
    material            VARCHAR2(200),
    mds                 VARCHAR2(100),
    eds                 VARCHAR2(100),
    eds_revision        VARCHAR2(50),
    esk                 VARCHAR2(100),
    revmark             VARCHAR2(50),
    remark              VARCHAR2(500),
    page_break          VARCHAR2(50),
    element_id          VARCHAR2(50),
    free_text           VARCHAR2(500),
    note_id             VARCHAR2(50),
    new_deleted_line    VARCHAR2(50),
    initial_info        VARCHAR2(200),
    initial_revmark     VARCHAR2(50),
    mds_variant         VARCHAR2(100),
    mds_revision        VARCHAR2(50),
    area                VARCHAR2(100)
);

-- STG_PCS_VALVE_ELEMENTS (Valve specifications from endpoint 3.6)
CREATE TABLE STG_PCS_VALVE_ELEMENTS (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    pcs_name            VARCHAR2(100),
    revision            VARCHAR2(50),
    valve_group_no      VARCHAR2(50),
    line_no             VARCHAR2(50),
    valve_type          VARCHAR2(100),
    vds                 VARCHAR2(100),
    valve_description   VARCHAR2(500),
    from_size           VARCHAR2(50),
    to_size             VARCHAR2(50),
    revmark             VARCHAR2(50),
    remark              VARCHAR2(500),
    page_break          VARCHAR2(50),
    note_id             VARCHAR2(50),
    previous_vds        VARCHAR2(100),
    new_deleted_line    VARCHAR2(50),
    initial_info        VARCHAR2(200),
    initial_revmark     VARCHAR2(50),
    size_range          VARCHAR2(100),
    status              VARCHAR2(50),
    valve_revision      VARCHAR2(50)
);

-- STG_PCS_EMBEDDED_NOTES (HTML notes from endpoint 3.7)
CREATE TABLE STG_PCS_EMBEDDED_NOTES (
    plant_id                VARCHAR2(50),
    issue_revision          VARCHAR2(50),
    pcs_name                VARCHAR2(100),
    revision                VARCHAR2(50),
    text_section_id         VARCHAR2(50),
    text_section_description VARCHAR2(500),
    page_break              VARCHAR2(50),
    html_clob               CLOB
);

-- ===============================================================================
-- PCS DETAIL CORE TABLES
-- ===============================================================================

-- PCS_HEADER_PROPERTIES (Extended PCS information)
CREATE TABLE PCS_HEADER_PROPERTIES (
    header_guid             RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id                VARCHAR2(50) NOT NULL,
    pcs_name                VARCHAR2(100) NOT NULL,
    revision                VARCHAR2(50) NOT NULL,
    status                  VARCHAR2(50),
    rev_date                DATE,
    rating_class            VARCHAR2(100),
    test_pressure           NUMBER(10,2),
    material_group          VARCHAR2(100),
    design_code             VARCHAR2(100),
    last_update             DATE,
    last_update_by          VARCHAR2(100),
    approver                VARCHAR2(100),
    notepad                 CLOB,
    sc                      VARCHAR2(100),
    vsm                     VARCHAR2(100),
    design_code_rev_mark    VARCHAR2(50),
    corr_allowance          NUMBER(10,2),
    corr_allowance_rev_mark VARCHAR2(50),
    long_weld_eff           NUMBER(10,2),
    long_weld_eff_rev_mark  VARCHAR2(50),
    wall_thk_tol            NUMBER(10,2),
    wall_thk_tol_rev_mark   VARCHAR2(50),
    service_remark          VARCHAR2(500),
    service_remark_rev_mark VARCHAR2(50),
    -- Design pressures
    design_press01          NUMBER(10,2),
    design_press02          NUMBER(10,2),
    design_press03          NUMBER(10,2),
    design_press04          NUMBER(10,2),
    design_press05          NUMBER(10,2),
    design_press06          NUMBER(10,2),
    design_press07          NUMBER(10,2),
    design_press08          NUMBER(10,2),
    design_press09          NUMBER(10,2),
    design_press10          NUMBER(10,2),
    design_press11          NUMBER(10,2),
    design_press12          NUMBER(10,2),
    design_press_rev_mark   VARCHAR2(50),
    -- Design temperatures
    design_temp01           NUMBER(10,2),
    design_temp02           NUMBER(10,2),
    design_temp03           NUMBER(10,2),
    design_temp04           NUMBER(10,2),
    design_temp05           NUMBER(10,2),
    design_temp06           NUMBER(10,2),
    design_temp07           NUMBER(10,2),
    design_temp08           NUMBER(10,2),
    design_temp09           NUMBER(10,2),
    design_temp10           NUMBER(10,2),
    design_temp11           NUMBER(10,2),
    design_temp12           NUMBER(10,2),
    design_temp_rev_mark    VARCHAR2(50),
    -- Note IDs
    note_id_corr_allowance  NUMBER(10),
    note_id_service_code    NUMBER(10),
    note_id_wall_thk_tol    NUMBER(10),
    note_id_long_weld_eff   NUMBER(10),
    note_id_general_pcs     NUMBER(10),
    note_id_design_code     NUMBER(10),
    note_id_press_temp_table NUMBER(10),
    note_id_pipe_size_wth_table NUMBER(10),
    -- Additional fields
    press_element_change    VARCHAR2(50),
    temp_element_change     VARCHAR2(50),
    material_group_id       VARCHAR2(50),
    special_req_id          NUMBER(10),
    special_req             VARCHAR2(500),
    new_vds_section         VARCHAR2(100),
    tube_pcs                VARCHAR2(100),
    eds_mj_matrix           VARCHAR2(100),
    mj_reduction_factor     NUMBER(10,2),
    -- Standard fields
    is_valid                CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date            DATE DEFAULT SYSDATE,
    last_modified_date      DATE DEFAULT SYSDATE,
    -- Constraints
    CONSTRAINT PK_PCS_HEADER PRIMARY KEY (header_guid),
    CONSTRAINT UK_PCS_HEADER UNIQUE (plant_id, pcs_name, revision),
    CONSTRAINT FK_PCS_HEADER_LIST FOREIGN KEY (plant_id, pcs_name, revision) 
        REFERENCES PCS_LIST(plant_id, pcs_name, revision)
);

-- PCS_TEMP_PRESSURES (Temperature/Pressure pairs)
CREATE TABLE PCS_TEMP_PRESSURES (
    temp_press_guid         RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id                VARCHAR2(50) NOT NULL,
    pcs_name                VARCHAR2(100) NOT NULL,
    revision                VARCHAR2(50) NOT NULL,
    temperature             NUMBER(10,2),
    pressure                NUMBER(10,2),
    -- Standard fields
    is_valid                CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date            DATE DEFAULT SYSDATE,
    last_modified_date      DATE DEFAULT SYSDATE,
    -- Constraints
    CONSTRAINT PK_PCS_TEMP_PRESS PRIMARY KEY (temp_press_guid),
    CONSTRAINT FK_PCS_TEMP_PRESS_LIST FOREIGN KEY (plant_id, pcs_name, revision) 
        REFERENCES PCS_LIST(plant_id, pcs_name, revision)
);

-- PCS_PIPE_SIZES (Pipe size specifications)
CREATE TABLE PCS_PIPE_SIZES (
    pipe_size_guid          RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id                VARCHAR2(50) NOT NULL,
    pcs_name                VARCHAR2(100) NOT NULL,
    revision                VARCHAR2(50) NOT NULL,
    nom_size                VARCHAR2(50),
    outer_diam              NUMBER(10,2),
    wall_thickness          NUMBER(10,4),
    schedule                VARCHAR2(50),
    under_tolerance         NUMBER(10,4),
    corrosion_allowance     NUMBER(10,4),
    welding_factor          NUMBER(10,2),
    dim_element_change      VARCHAR2(50),
    schedule_in_matrix      VARCHAR2(50),
    -- Standard fields
    is_valid                CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date            DATE DEFAULT SYSDATE,
    last_modified_date      DATE DEFAULT SYSDATE,
    -- Constraints
    CONSTRAINT PK_PCS_PIPE_SIZE PRIMARY KEY (pipe_size_guid),
    CONSTRAINT FK_PCS_PIPE_SIZE_LIST FOREIGN KEY (plant_id, pcs_name, revision) 
        REFERENCES PCS_LIST(plant_id, pcs_name, revision)
);

-- PCS_PIPE_ELEMENTS (Pipe elements)
CREATE TABLE PCS_PIPE_ELEMENTS (
    pipe_element_guid   RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    pcs_name            VARCHAR2(100) NOT NULL,
    revision            VARCHAR2(50) NOT NULL,
    material_group_id   NUMBER(10),
    element_group_no    NUMBER(10),
    line_no             NUMBER(10),
    element             VARCHAR2(200),
    dim_standard        VARCHAR2(100),
    from_size           VARCHAR2(50),
    to_size             VARCHAR2(50),
    product_form        VARCHAR2(100),
    material            VARCHAR2(200),
    mds                 VARCHAR2(100),
    eds                 VARCHAR2(100),
    eds_revision        VARCHAR2(50),
    esk                 VARCHAR2(100),
    revmark             VARCHAR2(50),
    remark              VARCHAR2(500),
    page_break          VARCHAR2(50),
    element_id          NUMBER(10),
    free_text           VARCHAR2(500),
    note_id             NUMBER(10),
    new_deleted_line    VARCHAR2(50),
    initial_info        VARCHAR2(200),
    initial_revmark     VARCHAR2(50),
    mds_variant         VARCHAR2(100),
    mds_revision        VARCHAR2(50),
    area                VARCHAR2(100),
    -- Standard fields
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    -- Constraints
    CONSTRAINT PK_PCS_PIPE_ELEM PRIMARY KEY (pipe_element_guid),
    CONSTRAINT FK_PCS_PIPE_ELEM_LIST FOREIGN KEY (plant_id, pcs_name, revision) 
        REFERENCES PCS_LIST(plant_id, pcs_name, revision)
);

-- PCS_VALVE_ELEMENTS (Valve elements)
CREATE TABLE PCS_VALVE_ELEMENTS (
    valve_element_guid  RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    pcs_name            VARCHAR2(100) NOT NULL,
    revision            VARCHAR2(50) NOT NULL,
    valve_group_no      NUMBER(10),
    line_no             NUMBER(10),
    valve_type          VARCHAR2(100),
    vds                 VARCHAR2(100),
    valve_description   VARCHAR2(500),
    from_size           VARCHAR2(50),
    to_size             VARCHAR2(50),
    revmark             VARCHAR2(50),
    remark              VARCHAR2(500),
    page_break          VARCHAR2(50),
    note_id             NUMBER(10),
    previous_vds        VARCHAR2(100),
    new_deleted_line    VARCHAR2(50),
    initial_info        VARCHAR2(200),
    initial_revmark     VARCHAR2(50),
    size_range          VARCHAR2(100),
    status              VARCHAR2(50),
    valve_revision      VARCHAR2(50),
    -- Standard fields
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    -- Constraints
    CONSTRAINT PK_PCS_VALVE_ELEM PRIMARY KEY (valve_element_guid),
    CONSTRAINT FK_PCS_VALVE_ELEM_LIST FOREIGN KEY (plant_id, pcs_name, revision) 
        REFERENCES PCS_LIST(plant_id, pcs_name, revision)
);

-- PCS_EMBEDDED_NOTES (Embedded notes)
CREATE TABLE PCS_EMBEDDED_NOTES (
    note_guid                RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id                 VARCHAR2(50) NOT NULL,
    pcs_name                 VARCHAR2(100) NOT NULL,
    revision                 VARCHAR2(50) NOT NULL,
    text_section_id          NUMBER(10),
    text_section_description VARCHAR2(500),
    page_break               VARCHAR2(50),
    html_clob                CLOB,
    -- Standard fields
    is_valid                 CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date             DATE DEFAULT SYSDATE,
    last_modified_date       DATE DEFAULT SYSDATE,
    -- Constraints
    CONSTRAINT PK_PCS_EMB_NOTE PRIMARY KEY (note_guid),
    CONSTRAINT FK_PCS_EMB_NOTE_LIST FOREIGN KEY (plant_id, pcs_name, revision) 
        REFERENCES PCS_LIST(plant_id, pcs_name, revision)
);

-- ===============================================================================
-- INDEXES FOR PERFORMANCE
-- ===============================================================================

-- Indexes for PCS_HEADER_PROPERTIES
CREATE INDEX IDX_PCS_HEADER_PLANT ON PCS_HEADER_PROPERTIES(plant_id);
CREATE INDEX IDX_PCS_HEADER_PCS ON PCS_HEADER_PROPERTIES(pcs_name);
CREATE INDEX IDX_PCS_HEADER_REV ON PCS_HEADER_PROPERTIES(revision);
CREATE INDEX IDX_PCS_HEADER_VALID ON PCS_HEADER_PROPERTIES(is_valid);

-- Indexes for PCS_TEMP_PRESSURES
CREATE INDEX IDX_PCS_TEMP_PLANT ON PCS_TEMP_PRESSURES(plant_id);
CREATE INDEX IDX_PCS_TEMP_PCS ON PCS_TEMP_PRESSURES(pcs_name);
CREATE INDEX IDX_PCS_TEMP_REV ON PCS_TEMP_PRESSURES(revision);

-- Indexes for PCS_PIPE_SIZES
CREATE INDEX IDX_PCS_PIPE_SIZE_PLANT ON PCS_PIPE_SIZES(plant_id);
CREATE INDEX IDX_PCS_PIPE_SIZE_PCS ON PCS_PIPE_SIZES(pcs_name);
CREATE INDEX IDX_PCS_PIPE_SIZE_REV ON PCS_PIPE_SIZES(revision);

-- Indexes for PCS_PIPE_ELEMENTS
CREATE INDEX IDX_PCS_PIPE_ELEM_PLANT ON PCS_PIPE_ELEMENTS(plant_id);
CREATE INDEX IDX_PCS_PIPE_ELEM_PCS ON PCS_PIPE_ELEMENTS(pcs_name);
CREATE INDEX IDX_PCS_PIPE_ELEM_REV ON PCS_PIPE_ELEMENTS(revision);

-- Indexes for PCS_VALVE_ELEMENTS
CREATE INDEX IDX_PCS_VALVE_ELEM_PLANT ON PCS_VALVE_ELEMENTS(plant_id);
CREATE INDEX IDX_PCS_VALVE_ELEM_PCS ON PCS_VALVE_ELEMENTS(pcs_name);
CREATE INDEX IDX_PCS_VALVE_ELEM_REV ON PCS_VALVE_ELEMENTS(revision);

-- Indexes for PCS_EMBEDDED_NOTES
CREATE INDEX IDX_PCS_NOTE_PLANT ON PCS_EMBEDDED_NOTES(plant_id);
CREATE INDEX IDX_PCS_NOTE_PCS ON PCS_EMBEDDED_NOTES(pcs_name);
CREATE INDEX IDX_PCS_NOTE_REV ON PCS_EMBEDDED_NOTES(revision);

-- ===============================================================================
-- CASCADE TRIGGER
-- ===============================================================================

-- When PCS_LIST record is invalidated, cascade to all detail tables
CREATE OR REPLACE TRIGGER TRG_CASCADE_PCS_LIST
AFTER UPDATE OF is_valid ON PCS_LIST
FOR EACH ROW
WHEN (NEW.is_valid = 'N' AND OLD.is_valid = 'Y')
BEGIN
    -- Invalidate header properties
    UPDATE PCS_HEADER_PROPERTIES
    SET is_valid = 'N',
        last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND pcs_name = :NEW.pcs_name
      AND revision = :NEW.revision
      AND is_valid = 'Y';
    
    -- Invalidate temperature/pressure data
    UPDATE PCS_TEMP_PRESSURES
    SET is_valid = 'N',
        last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND pcs_name = :NEW.pcs_name
      AND revision = :NEW.revision
      AND is_valid = 'Y';
    
    -- Invalidate pipe sizes
    UPDATE PCS_PIPE_SIZES
    SET is_valid = 'N',
        last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND pcs_name = :NEW.pcs_name
      AND revision = :NEW.revision
      AND is_valid = 'Y';
    
    -- Invalidate pipe elements
    UPDATE PCS_PIPE_ELEMENTS
    SET is_valid = 'N',
        last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND pcs_name = :NEW.pcs_name
      AND revision = :NEW.revision
      AND is_valid = 'Y';
    
    -- Invalidate valve elements
    UPDATE PCS_VALVE_ELEMENTS
    SET is_valid = 'N',
        last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND pcs_name = :NEW.pcs_name
      AND revision = :NEW.revision
      AND is_valid = 'Y';
    
    -- Invalidate embedded notes
    UPDATE PCS_EMBEDDED_NOTES
    SET is_valid = 'N',
        last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND pcs_name = :NEW.pcs_name
      AND revision = :NEW.revision
      AND is_valid = 'Y';
END;
/

-- ===============================================================================
-- GRANTS
-- ===============================================================================

-- Grant permissions on staging tables
GRANT SELECT, INSERT, UPDATE, DELETE ON STG_PCS_LIST TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON STG_PCS_HEADER_PROPERTIES TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON STG_PCS_TEMP_PRESSURES TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON STG_PCS_PIPE_SIZES TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON STG_PCS_PIPE_ELEMENTS TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON STG_PCS_VALVE_ELEMENTS TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON STG_PCS_EMBEDDED_NOTES TO TR2000_STAGING;

-- Grant permissions on core tables
GRANT SELECT, INSERT, UPDATE, DELETE ON PCS_LIST TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON PCS_HEADER_PROPERTIES TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON PCS_TEMP_PRESSURES TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON PCS_PIPE_SIZES TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON PCS_PIPE_ELEMENTS TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON PCS_VALVE_ELEMENTS TO TR2000_STAGING;
GRANT SELECT, INSERT, UPDATE, DELETE ON PCS_EMBEDDED_NOTES TO TR2000_STAGING;