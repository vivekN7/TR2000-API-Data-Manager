-- ===============================================================================
-- Deploy All Packages - TR2000 ETL System
-- ===============================================================================
-- Purpose: Creates or replaces all PL/SQL packages
-- Note: Safe to run - uses CREATE OR REPLACE (no data loss)
-- ===============================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ===============================================================================
PROMPT Creating/Replacing All Packages
PROMPT ===============================================================================

-- Core packages
@01_pkg_raw_ingest.sql
@02_pkg_parse_plants.sql
@03_pkg_parse_issues.sql
@04_pkg_upsert_plants.sql
@05_pkg_upsert_issues.sql
@06_pkg_api_client.sql
@07_pkg_selection_mgmt.sql
@08_pkg_etl_operations.sql

-- Reference packages (Task 7)
@10_pkg_parse_references.sql
@11_pkg_upsert_references.sql
@13_pkg_api_client_references.sql

-- CASCADE management
@11_pkg_cascade_manager.sql

-- GUID utilities
@12_pkg_guid_utils.sql

PROMPT
PROMPT ===============================================================================
PROMPT Package deployment complete
PROMPT ===============================================================================

-- Show package status
SELECT object_name, object_type, status 
FROM user_objects 
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')
ORDER BY object_name, object_type;

EXIT;