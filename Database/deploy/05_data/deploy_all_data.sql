-- ===============================================================================
-- Deploy All Initial Data - TR2000 ETL System
-- ===============================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ===============================================================================
PROMPT Loading initial data...
PROMPT ===============================================================================

-- Control settings
@01_control_settings.sql

-- Control endpoints configuration
@02_control_endpoints.sql

-- Test selection data for development (until APEX UI is ready)
@03_selection_loader.sql

PROMPT
PROMPT ===============================================================================
PROMPT Initial data load complete
PROMPT ===============================================================================

-- Verify data loaded
SELECT 'CONTROL_SETTINGS' as table_name, COUNT(*) as row_count FROM CONTROL_SETTINGS
UNION ALL
SELECT 'CONTROL_ENDPOINTS', COUNT(*) FROM CONTROL_ENDPOINTS
UNION ALL
SELECT 'SELECTION_LOADER', COUNT(*) FROM SELECTION_LOADER WHERE is_active = 'Y';

EXIT;