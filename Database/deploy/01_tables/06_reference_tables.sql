-- ===============================================================================
-- Reference Tables for Issue References (Task 7)
-- Date: 2025-08-26
-- Purpose: Core and staging tables for 9 reference types
-- ===============================================================================

-- ===============================================================================
-- STAGING TABLES (All VARCHAR2 for JSON parsing)
-- ===============================================================================

-- STG_PCS_REFERENCES
CREATE TABLE STG_PCS_REFERENCES (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    pcs                 VARCHAR2(100),
    revision            VARCHAR2(50),
    rev_date            VARCHAR2(50),
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    revision_suffix     VARCHAR2(50),
    rating_class        VARCHAR2(100),
    material_group      VARCHAR2(100),
    historical_pcs      VARCHAR2(100),
    delta               VARCHAR2(50)
);

COMMENT ON TABLE STG_PCS_REFERENCES IS 'Staging table for PCS references from API';

-- STG_SC_REFERENCES
CREATE TABLE STG_SC_REFERENCES (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    sc                  VARCHAR2(100),
    revision            VARCHAR2(50),
    rev_date            VARCHAR2(50),
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50)
);

COMMENT ON TABLE STG_SC_REFERENCES IS 'Staging table for SC references from API';

-- STG_VSM_REFERENCES
CREATE TABLE STG_VSM_REFERENCES (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    vsm                 VARCHAR2(100),
    revision            VARCHAR2(50),
    rev_date            VARCHAR2(50),
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50)
);

COMMENT ON TABLE STG_VSM_REFERENCES IS 'Staging table for VSM references from API';

-- STG_VDS_REFERENCES
CREATE TABLE STG_VDS_REFERENCES (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    vds                 VARCHAR2(100),
    revision            VARCHAR2(50),
    rev_date            VARCHAR2(50),
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    rating_class        VARCHAR2(100),
    material_group      VARCHAR2(100),
    bolt_material       VARCHAR2(100),
    gasket_type         VARCHAR2(100),
    delta               VARCHAR2(50)
);

COMMENT ON TABLE STG_VDS_REFERENCES IS 'Staging table for VDS references from API';

-- STG_EDS_REFERENCES
CREATE TABLE STG_EDS_REFERENCES (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    eds                 VARCHAR2(100),
    revision            VARCHAR2(50),
    rev_date            VARCHAR2(50),
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50)
);

COMMENT ON TABLE STG_EDS_REFERENCES IS 'Staging table for EDS references from API';

-- STG_MDS_REFERENCES
CREATE TABLE STG_MDS_REFERENCES (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    mds                 VARCHAR2(100),
    area                VARCHAR2(100),
    revision            VARCHAR2(50),
    rev_date            VARCHAR2(50),
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    rating_class        VARCHAR2(100),
    material_group      VARCHAR2(100),
    delta               VARCHAR2(50)
);

COMMENT ON TABLE STG_MDS_REFERENCES IS 'Staging table for MDS references from API';

-- STG_VSK_REFERENCES
CREATE TABLE STG_VSK_REFERENCES (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    vsk                 VARCHAR2(100),
    revision            VARCHAR2(50),
    rev_date            VARCHAR2(50),
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50)
);

COMMENT ON TABLE STG_VSK_REFERENCES IS 'Staging table for VSK references from API';

-- STG_ESK_REFERENCES
CREATE TABLE STG_ESK_REFERENCES (
    plant_id            VARCHAR2(50),
    issue_revision      VARCHAR2(50),
    esk                 VARCHAR2(100),
    revision            VARCHAR2(50),
    rev_date            VARCHAR2(50),
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50)
);

COMMENT ON TABLE STG_ESK_REFERENCES IS 'Staging table for ESK references from API';

-- STG_PIPE_ELEMENT_REFERENCES
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

-- ===============================================================================
-- CORE REFERENCE TABLES
-- ===============================================================================

-- PCS_REFERENCES
CREATE TABLE PCS_REFERENCES (
    reference_guid      RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    issue_revision      VARCHAR2(50) NOT NULL,
    pcs_name            VARCHAR2(100) NOT NULL,
    revision            VARCHAR2(50),
    rev_date            DATE,
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    revision_suffix     VARCHAR2(50),
    rating_class        VARCHAR2(100),
    material_group      VARCHAR2(100),
    historical_pcs      VARCHAR2(100),
    delta               VARCHAR2(50),
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    last_api_sync       TIMESTAMP,
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_PCS_REFERENCES PRIMARY KEY (reference_guid),
    CONSTRAINT UK_PCS_REF UNIQUE (plant_id, issue_revision, pcs_name),
    CONSTRAINT FK_PCS_REF_ISSUE FOREIGN KEY (plant_id, issue_revision) 
        REFERENCES ISSUES(plant_id, issue_revision)
);

CREATE INDEX IDX_PCS_REF_PLANT ON PCS_REFERENCES(plant_id);
CREATE INDEX IDX_PCS_REF_ISSUE ON PCS_REFERENCES(issue_revision);
CREATE INDEX IDX_PCS_REF_VALID ON PCS_REFERENCES(is_valid);

COMMENT ON TABLE PCS_REFERENCES IS 'PCS references linked to issues';
COMMENT ON COLUMN PCS_REFERENCES.reference_guid IS 'Unique identifier for this reference';
COMMENT ON COLUMN PCS_REFERENCES.pcs_name IS 'PCS identifier';
COMMENT ON COLUMN PCS_REFERENCES.is_valid IS 'Soft delete flag (Y=active, N=deleted)';

-- SC_REFERENCES
CREATE TABLE SC_REFERENCES (
    reference_guid      RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    issue_revision      VARCHAR2(50) NOT NULL,
    sc_name             VARCHAR2(100) NOT NULL,
    revision            VARCHAR2(50),
    rev_date            DATE,
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50),
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    last_api_sync       TIMESTAMP,
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_SC_REFERENCES PRIMARY KEY (reference_guid),
    CONSTRAINT UK_SC_REF UNIQUE (plant_id, issue_revision, sc_name),
    CONSTRAINT FK_SC_REF_ISSUE FOREIGN KEY (plant_id, issue_revision) 
        REFERENCES ISSUES(plant_id, issue_revision)
);

CREATE INDEX IDX_SC_REF_PLANT ON SC_REFERENCES(plant_id);
CREATE INDEX IDX_SC_REF_ISSUE ON SC_REFERENCES(issue_revision);
CREATE INDEX IDX_SC_REF_VALID ON SC_REFERENCES(is_valid);

COMMENT ON TABLE SC_REFERENCES IS 'SC references linked to issues';

-- VSM_REFERENCES
CREATE TABLE VSM_REFERENCES (
    reference_guid      RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    issue_revision      VARCHAR2(50) NOT NULL,
    vsm_name            VARCHAR2(100) NOT NULL,
    revision            VARCHAR2(50),
    rev_date            DATE,
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50),
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    last_api_sync       TIMESTAMP,
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_VSM_REFERENCES PRIMARY KEY (reference_guid),
    CONSTRAINT UK_VSM_REF UNIQUE (plant_id, issue_revision, vsm_name),
    CONSTRAINT FK_VSM_REF_ISSUE FOREIGN KEY (plant_id, issue_revision) 
        REFERENCES ISSUES(plant_id, issue_revision)
);

CREATE INDEX IDX_VSM_REF_PLANT ON VSM_REFERENCES(plant_id);
CREATE INDEX IDX_VSM_REF_ISSUE ON VSM_REFERENCES(issue_revision);
CREATE INDEX IDX_VSM_REF_VALID ON VSM_REFERENCES(is_valid);

COMMENT ON TABLE VSM_REFERENCES IS 'VSM references linked to issues';

-- VDS_REFERENCES
CREATE TABLE VDS_REFERENCES (
    reference_guid      RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    issue_revision      VARCHAR2(50) NOT NULL,
    vds_name            VARCHAR2(100) NOT NULL,
    revision            VARCHAR2(50),
    rev_date            DATE,
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    rating_class        VARCHAR2(100),
    material_group      VARCHAR2(100),
    bolt_material       VARCHAR2(100),
    gasket_type         VARCHAR2(100),
    delta               VARCHAR2(50),
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    last_api_sync       TIMESTAMP,
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_VDS_REFERENCES PRIMARY KEY (reference_guid),
    CONSTRAINT UK_VDS_REF UNIQUE (plant_id, issue_revision, vds_name),
    CONSTRAINT FK_VDS_REF_ISSUE FOREIGN KEY (plant_id, issue_revision) 
        REFERENCES ISSUES(plant_id, issue_revision)
);

CREATE INDEX IDX_VDS_REF_PLANT ON VDS_REFERENCES(plant_id);
CREATE INDEX IDX_VDS_REF_ISSUE ON VDS_REFERENCES(issue_revision);
CREATE INDEX IDX_VDS_REF_VALID ON VDS_REFERENCES(is_valid);

COMMENT ON TABLE VDS_REFERENCES IS 'VDS references linked to issues';

-- EDS_REFERENCES
CREATE TABLE EDS_REFERENCES (
    reference_guid      RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    issue_revision      VARCHAR2(50) NOT NULL,
    eds_name            VARCHAR2(100) NOT NULL,
    revision            VARCHAR2(50),
    rev_date            DATE,
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50),
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    last_api_sync       TIMESTAMP,
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_EDS_REFERENCES PRIMARY KEY (reference_guid),
    CONSTRAINT UK_EDS_REF UNIQUE (plant_id, issue_revision, eds_name),
    CONSTRAINT FK_EDS_REF_ISSUE FOREIGN KEY (plant_id, issue_revision) 
        REFERENCES ISSUES(plant_id, issue_revision)
);

CREATE INDEX IDX_EDS_REF_PLANT ON EDS_REFERENCES(plant_id);
CREATE INDEX IDX_EDS_REF_ISSUE ON EDS_REFERENCES(issue_revision);
CREATE INDEX IDX_EDS_REF_VALID ON EDS_REFERENCES(is_valid);

COMMENT ON TABLE EDS_REFERENCES IS 'EDS references linked to issues';

-- MDS_REFERENCES
CREATE TABLE MDS_REFERENCES (
    reference_guid      RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    issue_revision      VARCHAR2(50) NOT NULL,
    mds_name            VARCHAR2(100) NOT NULL,
    area                VARCHAR2(100),
    revision            VARCHAR2(50),
    rev_date            DATE,
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    rating_class        VARCHAR2(100),
    material_group      VARCHAR2(100),
    delta               VARCHAR2(50),
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    last_api_sync       TIMESTAMP,
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_MDS_REFERENCES PRIMARY KEY (reference_guid),
    CONSTRAINT UK_MDS_REF UNIQUE (plant_id, issue_revision, mds_name),
    CONSTRAINT FK_MDS_REF_ISSUE FOREIGN KEY (plant_id, issue_revision) 
        REFERENCES ISSUES(plant_id, issue_revision)
);

CREATE INDEX IDX_MDS_REF_PLANT ON MDS_REFERENCES(plant_id);
CREATE INDEX IDX_MDS_REF_ISSUE ON MDS_REFERENCES(issue_revision);
CREATE INDEX IDX_MDS_REF_VALID ON MDS_REFERENCES(is_valid);
CREATE INDEX IDX_MDS_REF_AREA ON MDS_REFERENCES(area);

COMMENT ON TABLE MDS_REFERENCES IS 'MDS references linked to issues';
COMMENT ON COLUMN MDS_REFERENCES.area IS 'Area classification for MDS';

-- VSK_REFERENCES
CREATE TABLE VSK_REFERENCES (
    reference_guid      RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    issue_revision      VARCHAR2(50) NOT NULL,
    vsk_name            VARCHAR2(100) NOT NULL,
    revision            VARCHAR2(50),
    rev_date            DATE,
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50),
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    last_api_sync       TIMESTAMP,
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_VSK_REFERENCES PRIMARY KEY (reference_guid),
    CONSTRAINT UK_VSK_REF UNIQUE (plant_id, issue_revision, vsk_name),
    CONSTRAINT FK_VSK_REF_ISSUE FOREIGN KEY (plant_id, issue_revision) 
        REFERENCES ISSUES(plant_id, issue_revision)
);

CREATE INDEX IDX_VSK_REF_PLANT ON VSK_REFERENCES(plant_id);
CREATE INDEX IDX_VSK_REF_ISSUE ON VSK_REFERENCES(issue_revision);
CREATE INDEX IDX_VSK_REF_VALID ON VSK_REFERENCES(is_valid);

COMMENT ON TABLE VSK_REFERENCES IS 'VSK references linked to issues';

-- ESK_REFERENCES
CREATE TABLE ESK_REFERENCES (
    reference_guid      RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    issue_revision      VARCHAR2(50) NOT NULL,
    esk_name            VARCHAR2(100) NOT NULL,
    revision            VARCHAR2(50),
    rev_date            DATE,
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50),
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    last_api_sync       TIMESTAMP,
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_ESK_REFERENCES PRIMARY KEY (reference_guid),
    CONSTRAINT UK_ESK_REF UNIQUE (plant_id, issue_revision, esk_name),
    CONSTRAINT FK_ESK_REF_ISSUE FOREIGN KEY (plant_id, issue_revision) 
        REFERENCES ISSUES(plant_id, issue_revision)
);

CREATE INDEX IDX_ESK_REF_PLANT ON ESK_REFERENCES(plant_id);
CREATE INDEX IDX_ESK_REF_ISSUE ON ESK_REFERENCES(issue_revision);
CREATE INDEX IDX_ESK_REF_VALID ON ESK_REFERENCES(is_valid);

COMMENT ON TABLE ESK_REFERENCES IS 'ESK references linked to issues';

-- PIPE_ELEMENT_REFERENCES
CREATE TABLE PIPE_ELEMENT_REFERENCES (
    reference_guid      RAW(16) DEFAULT SYS_GUID() NOT NULL,
    plant_id            VARCHAR2(50) NOT NULL,
    issue_revision      VARCHAR2(50) NOT NULL,
    mds                 VARCHAR2(100) NOT NULL,
    element_name        VARCHAR2(200) NOT NULL,
    revision            VARCHAR2(50),
    rev_date            DATE,
    status              VARCHAR2(50),
    official_revision   VARCHAR2(50),
    delta               VARCHAR2(50),
    is_valid            CHAR(1) DEFAULT 'Y' CHECK (is_valid IN ('Y', 'N')),
    created_date        DATE DEFAULT SYSDATE,
    last_modified_date  DATE DEFAULT SYSDATE,
    last_api_sync       TIMESTAMP,
    api_correlation_id  VARCHAR2(36),
    CONSTRAINT PK_PIPE_ELEM_REFERENCES PRIMARY KEY (reference_guid),
    CONSTRAINT UK_PIPE_ELEM_REF UNIQUE (plant_id, issue_revision, mds, element_name),
    CONSTRAINT FK_PIPE_ELEM_REF_ISSUE FOREIGN KEY (plant_id, issue_revision) 
        REFERENCES ISSUES(plant_id, issue_revision)
);

CREATE INDEX IDX_PIPE_ELEM_REF_PLANT ON PIPE_ELEMENT_REFERENCES(plant_id);
CREATE INDEX IDX_PIPE_ELEM_REF_ISSUE ON PIPE_ELEMENT_REFERENCES(issue_revision);
CREATE INDEX IDX_PIPE_ELEM_REF_VALID ON PIPE_ELEMENT_REFERENCES(is_valid);
CREATE INDEX IDX_PIPE_ELEM_REF_MDS ON PIPE_ELEMENT_REFERENCES(mds);

COMMENT ON TABLE PIPE_ELEMENT_REFERENCES IS 'Pipe Element references linked to issues';
COMMENT ON COLUMN PIPE_ELEMENT_REFERENCES.mds IS 'Associated MDS reference';

-- End of reference tables