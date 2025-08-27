-- ===============================================================================
-- Recompile All Invalid Objects
-- Date: 2025-08-27
-- ===============================================================================

-- Recompile invalid views first (they might depend on tables)
ALTER VIEW VETL_EFFECTIVE_SELECTIONS COMPILE;
ALTER VIEW V_ACTIVE_PLANT_SELECTIONS COMPILE;

-- Recompile invalid triggers
ALTER TRIGGER TRG_ISSUES_TO_SELECTION COMPILE;
ALTER TRIGGER TRG_PLANTS_TO_SELECTION COMPILE;

-- Recompile invalid package bodies
ALTER PACKAGE PKG_RAW_INGEST COMPILE BODY;
ALTER PACKAGE PKG_PARSE_PLANTS COMPILE BODY;
ALTER PACKAGE PKG_PARSE_ISSUES COMPILE BODY;
ALTER PACKAGE PKG_PARSE_REFERENCES COMPILE BODY;
ALTER PACKAGE PKG_API_CLIENT COMPILE BODY;
ALTER PACKAGE PKG_API_CLIENT_REFERENCES COMPILE BODY;
ALTER PACKAGE PKG_SIMPLE_TESTS COMPILE BODY;
ALTER PACKAGE PKG_ADDITIONAL_TESTS COMPILE BODY;
ALTER PACKAGE PKG_TEST_ISOLATION COMPILE BODY;

-- Show remaining invalid objects
SELECT object_name, object_type, status
FROM user_objects
WHERE status = 'INVALID'
ORDER BY object_type, object_name;