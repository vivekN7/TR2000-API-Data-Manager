-- ===============================================================================
-- Add PCS Loading Mode Control Setting
-- Date: 2025-12-01
-- Purpose: Control whether to load ALL PCS revisions or only OFFICIAL revisions
-- Default: OFFICIAL_ONLY (significantly reduces API calls from 2,172 to 396)
-- ===============================================================================

-- Add control setting for PCS loading mode
INSERT INTO CONTROL_SETTINGS (setting_key, setting_value, description)
SELECT 'PCS_LOADING_MODE', 'OFFICIAL_ONLY', 
       'Controls PCS detail loading: OFFICIAL_ONLY (default - only revisions in PCS_REFERENCES) or ALL_REVISIONS (all from PCS_LIST)'
FROM dual
WHERE NOT EXISTS (
    SELECT 1 FROM CONTROL_SETTINGS WHERE setting_key = 'PCS_LOADING_MODE'
);

-- Add similar control for other reference types
INSERT INTO CONTROL_SETTINGS (setting_key, setting_value, description)
SELECT 'REFERENCE_LOADING_MODE', 'OFFICIAL_ONLY',
       'Controls reference detail loading: OFFICIAL_ONLY (default - only official revisions) or ALL_REVISIONS'
FROM dual
WHERE NOT EXISTS (
    SELECT 1 FROM CONTROL_SETTINGS WHERE setting_key = 'REFERENCE_LOADING_MODE'
);

COMMIT;

-- Show the settings
SELECT setting_key, setting_value, description
FROM CONTROL_SETTINGS
WHERE setting_key LIKE '%LOADING_MODE%';

-- Create a view to identify which PCS revisions to load based on mode
CREATE OR REPLACE VIEW V_PCS_TO_LOAD AS
SELECT DISTINCT
    pl.plant_id,
    pl.pcs_name,
    pl.revision,
    CASE 
        WHEN cs.setting_value = 'OFFICIAL_ONLY' THEN
            CASE WHEN pr.pcs_name IS NOT NULL THEN 'Y' ELSE 'N' END
        ELSE 'Y'
    END as should_load,
    CASE 
        WHEN pr.pcs_name IS NOT NULL THEN 'OFFICIAL' 
        ELSE 'ADDITIONAL' 
    END as revision_type
FROM PCS_LIST pl
LEFT JOIN (
    -- Get unique official revisions from PCS_REFERENCES
    SELECT DISTINCT plant_id, pcs_name, 
           NVL(official_revision, revision) as revision
    FROM PCS_REFERENCES
    WHERE is_valid = 'Y'
) pr ON pl.plant_id = pr.plant_id 
    AND pl.pcs_name = pr.pcs_name 
    AND pl.revision = pr.revision
CROSS JOIN (
    SELECT NVL(setting_value, 'OFFICIAL_ONLY') as setting_value
    FROM CONTROL_SETTINGS
    WHERE setting_key = 'PCS_LOADING_MODE'
) cs
WHERE pl.is_valid = 'Y';

-- Check the impact
SELECT 
    revision_type,
    should_load,
    COUNT(*) as pcs_count,
    COUNT(*) * 6 as api_calls_required
FROM V_PCS_TO_LOAD
WHERE plant_id = '34'
GROUP BY revision_type, should_load
ORDER BY revision_type, should_load;

-- Summary
SELECT 
    'Current Mode: ' || NVL(setting_value, 'OFFICIAL_ONLY') as mode,
    (SELECT COUNT(*) FROM V_PCS_TO_LOAD WHERE plant_id = '34' AND should_load = 'Y') as pcs_to_load,
    (SELECT COUNT(*) FROM V_PCS_TO_LOAD WHERE plant_id = '34' AND should_load = 'Y') * 6 as total_api_calls
FROM CONTROL_SETTINGS
WHERE setting_key = 'PCS_LOADING_MODE';