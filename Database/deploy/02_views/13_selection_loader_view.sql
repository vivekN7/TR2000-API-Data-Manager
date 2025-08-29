-- ===============================================================================
-- SELECTION_LOADER View
-- Date: 2025-12-30
-- Purpose: Bridge view to maintain compatibility with packages expecting SELECTION_LOADER
-- ===============================================================================

CREATE OR REPLACE VIEW SELECTION_LOADER AS
SELECT 
    'PLANT' as entity_type,
    plant_id,
    NULL as issue_revision,
    is_active,
    selection_date
FROM SELECTED_PLANTS
WHERE is_active = 'Y'
UNION ALL
SELECT 
    'ISSUE' as entity_type,
    plant_id,
    issue_revision,
    is_active,
    selection_date
FROM SELECTED_ISSUES
WHERE is_active = 'Y';

COMMENT ON VIEW SELECTION_LOADER IS 'Compatibility view combining SELECTED_PLANTS and SELECTED_ISSUES for packages';