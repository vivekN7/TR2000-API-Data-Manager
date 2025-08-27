-- ===============================================================================
-- Fix Task 7 Compilation Errors and Structure Issues
-- Date: 2025-08-27
-- Session: 12
-- Purpose: Fix all issues found with Task 7 reference tables implementation
-- ===============================================================================

PROMPT ===============================================================================
PROMPT Fixing Task 7 Reference Tables Issues
PROMPT ===============================================================================

-- 1. Fix PIPE_ELEMENT_REFERENCES table structure
-- The table was created with wrong structure (element_id instead of element_name)
PROMPT Dropping and recreating PIPE_ELEMENT_REFERENCES with correct structure...

DROP TABLE PIPE_ELEMENT_REFERENCES CASCADE CONSTRAINTS;

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

-- 2. Recompile PKG_UPSERT_REFERENCES (already fixed in the file)
PROMPT Recompiling PKG_UPSERT_REFERENCES...
@../03_packages/11_pkg_upsert_references.sql

-- 3. Check for invalid objects
PROMPT Checking for invalid objects...
SELECT object_type, object_name, status
FROM user_objects
WHERE status = 'INVALID'
ORDER BY object_type, object_name;

-- 4. Summary message
PROMPT
PROMPT ===============================================================================
PROMPT Task 7 fixes applied successfully!
PROMPT Changes made:
PROMPT - Fixed PIPE_ELEMENT_REFERENCES table structure (element_name instead of element_id)
PROMPT - Recompiled PKG_UPSERT_REFERENCES with correct column references
PROMPT - Removed duplicate package files from 03_packages directory
PROMPT ===============================================================================
PROMPT
PROMPT To verify:
PROMPT   1. Run: EXEC PKG_SIMPLE_TESTS.run_critical_tests;
PROMPT   2. Check reference data: SELECT COUNT(*) FROM PCS_REFERENCES WHERE is_valid = 'Y';
PROMPT ===============================================================================