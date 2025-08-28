-- ===============================================================================
-- PCS Details Monitoring Views
-- Date: 2025-12-01
-- Purpose: Create views for monitoring PCS detail data (Task 8)
-- ===============================================================================

-- View for PCS List Summary
CREATE OR REPLACE VIEW V_PCS_LIST_SUMMARY AS
SELECT 
    pl.plant_id,
    p.plant_name,
    COUNT(DISTINCT pl.pcs_name) as unique_pcs_count,
    COUNT(*) as total_revision_count,
    MAX(pl.last_api_sync) as last_sync
FROM PCS_LIST pl
LEFT JOIN PLANTS p ON pl.plant_id = p.plant_id
WHERE pl.is_valid = 'Y'
GROUP BY pl.plant_id, p.plant_name
ORDER BY pl.plant_id;

COMMENT ON VIEW V_PCS_LIST_SUMMARY IS 'Summary of PCS counts by plant';

-- View for PCS Details Completeness
CREATE OR REPLACE VIEW V_PCS_DETAILS_COMPLETENESS AS
SELECT 
    pl.plant_id,
    pl.pcs_name,
    pl.revision,
    pl.status as pcs_status,
    pl.rating_class,
    pl.material_group,
    -- Check if details exist
    CASE WHEN EXISTS (
        SELECT 1 FROM PCS_HEADER_PROPERTIES hp 
        WHERE hp.plant_id = pl.plant_id 
        AND hp.pcs_name = pl.pcs_name 
        AND hp.revision = pl.revision 
        AND hp.is_valid = 'Y'
    ) THEN 'Y' ELSE 'N' END as has_header,
    CASE WHEN EXISTS (
        SELECT 1 FROM PCS_TEMP_PRESSURES tp 
        WHERE tp.plant_id = pl.plant_id 
        AND tp.pcs_name = pl.pcs_name 
        AND tp.revision = pl.revision 
        AND tp.is_valid = 'Y'
    ) THEN 'Y' ELSE 'N' END as has_temp_pressure,
    CASE WHEN EXISTS (
        SELECT 1 FROM PCS_PIPE_SIZES ps 
        WHERE ps.plant_id = pl.plant_id 
        AND ps.pcs_name = pl.pcs_name 
        AND ps.revision = pl.revision 
        AND ps.is_valid = 'Y'
    ) THEN 'Y' ELSE 'N' END as has_pipe_sizes,
    CASE WHEN EXISTS (
        SELECT 1 FROM PCS_PIPE_ELEMENTS pe 
        WHERE pe.plant_id = pl.plant_id 
        AND pe.pcs_name = pl.pcs_name 
        AND pe.revision = pl.revision 
        AND pe.is_valid = 'Y'
    ) THEN 'Y' ELSE 'N' END as has_pipe_elements,
    CASE WHEN EXISTS (
        SELECT 1 FROM PCS_VALVE_ELEMENTS ve 
        WHERE ve.plant_id = pl.plant_id 
        AND ve.pcs_name = pl.pcs_name 
        AND ve.revision = pl.revision 
        AND ve.is_valid = 'Y'
    ) THEN 'Y' ELSE 'N' END as has_valve_elements,
    CASE WHEN EXISTS (
        SELECT 1 FROM PCS_EMBEDDED_NOTES en 
        WHERE en.plant_id = pl.plant_id 
        AND en.pcs_name = pl.pcs_name 
        AND en.revision = pl.revision 
        AND en.is_valid = 'Y'
    ) THEN 'Y' ELSE 'N' END as has_embedded_notes,
    pl.last_api_sync
FROM PCS_LIST pl
WHERE pl.is_valid = 'Y'
ORDER BY pl.plant_id, pl.pcs_name, pl.revision;

COMMENT ON VIEW V_PCS_DETAILS_COMPLETENESS IS 'Shows which PCS revisions have complete detail data';

-- View for PCS Detail Record Counts
CREATE OR REPLACE VIEW V_PCS_DETAIL_COUNTS AS
SELECT 
    pl.plant_id,
    pl.pcs_name,
    pl.revision,
    (SELECT COUNT(*) FROM PCS_TEMP_PRESSURES tp 
     WHERE tp.plant_id = pl.plant_id 
     AND tp.pcs_name = pl.pcs_name 
     AND tp.revision = pl.revision 
     AND tp.is_valid = 'Y') as temp_pressure_count,
    (SELECT COUNT(*) FROM PCS_PIPE_SIZES ps 
     WHERE ps.plant_id = pl.plant_id 
     AND ps.pcs_name = pl.pcs_name 
     AND ps.revision = pl.revision 
     AND ps.is_valid = 'Y') as pipe_size_count,
    (SELECT COUNT(*) FROM PCS_PIPE_ELEMENTS pe 
     WHERE pe.plant_id = pl.plant_id 
     AND pe.pcs_name = pl.pcs_name 
     AND pe.revision = pl.revision 
     AND pe.is_valid = 'Y') as pipe_element_count,
    (SELECT COUNT(*) FROM PCS_VALVE_ELEMENTS ve 
     WHERE ve.plant_id = pl.plant_id 
     AND ve.pcs_name = pl.pcs_name 
     AND ve.revision = pl.revision 
     AND ve.is_valid = 'Y') as valve_element_count,
    (SELECT COUNT(*) FROM PCS_EMBEDDED_NOTES en 
     WHERE en.plant_id = pl.plant_id 
     AND en.pcs_name = pl.pcs_name 
     AND en.revision = pl.revision 
     AND en.is_valid = 'Y') as embedded_note_count
FROM PCS_LIST pl
WHERE pl.is_valid = 'Y'
  AND EXISTS (  -- Only show PCS that have at least some details
    SELECT 1 FROM PCS_HEADER_PROPERTIES hp 
    WHERE hp.plant_id = pl.plant_id 
    AND hp.pcs_name = pl.pcs_name 
    AND hp.revision = pl.revision 
    AND hp.is_valid = 'Y'
  )
ORDER BY pl.plant_id, pl.pcs_name, pl.revision;

COMMENT ON VIEW V_PCS_DETAIL_COUNTS IS 'Count of detail records for each PCS revision';

-- View for PCS Processing Status
CREATE OR REPLACE VIEW V_PCS_PROCESSING_STATUS AS
SELECT 
    pl.plant_id,
    COUNT(*) as total_pcs_revisions,
    SUM(CASE WHEN hp.header_guid IS NOT NULL THEN 1 ELSE 0 END) as pcs_with_details,
    COUNT(*) - SUM(CASE WHEN hp.header_guid IS NOT NULL THEN 1 ELSE 0 END) as pcs_pending_details,
    ROUND((SUM(CASE WHEN hp.header_guid IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) as completion_pct
FROM PCS_LIST pl
LEFT JOIN PCS_HEADER_PROPERTIES hp ON (
    pl.plant_id = hp.plant_id 
    AND pl.pcs_name = hp.pcs_name 
    AND pl.revision = hp.revision 
    AND hp.is_valid = 'Y'
)
WHERE pl.is_valid = 'Y'
GROUP BY pl.plant_id
ORDER BY pl.plant_id;

COMMENT ON VIEW V_PCS_PROCESSING_STATUS IS 'Shows PCS processing completion status by plant';

-- View for Material Groups Used in PCS
CREATE OR REPLACE VIEW V_PCS_MATERIAL_GROUPS AS
SELECT 
    material_group,
    COUNT(DISTINCT plant_id) as plant_count,
    COUNT(DISTINCT pcs_name) as unique_pcs_count,
    COUNT(*) as revision_count
FROM PCS_LIST
WHERE is_valid = 'Y'
  AND material_group IS NOT NULL
GROUP BY material_group
ORDER BY revision_count DESC, material_group;

COMMENT ON VIEW V_PCS_MATERIAL_GROUPS IS 'Summary of material groups used across PCS';

-- View for PCS Pipe Elements with MDS/EDS References
CREATE OR REPLACE VIEW V_PCS_PIPE_ELEMENT_MATERIALS AS
SELECT 
    pe.plant_id,
    pe.pcs_name,
    pe.revision,
    pe.element,
    pe.material,
    pe.mds,
    pe.eds,
    pe.esk,
    pe.from_size,
    pe.to_size,
    pl.material_group as pcs_material_group
FROM PCS_PIPE_ELEMENTS pe
JOIN PCS_LIST pl ON (
    pe.plant_id = pl.plant_id 
    AND pe.pcs_name = pl.pcs_name 
    AND pe.revision = pl.revision
)
WHERE pe.is_valid = 'Y'
  AND pl.is_valid = 'Y'
  AND (pe.mds IS NOT NULL OR pe.eds IS NOT NULL)
ORDER BY pe.plant_id, pe.pcs_name, pe.revision, pe.element_group_no, pe.line_no;

COMMENT ON VIEW V_PCS_PIPE_ELEMENT_MATERIALS IS 'PCS pipe elements with material data sheet references';

-- View for Recent PCS Updates
CREATE OR REPLACE VIEW V_PCS_RECENT_UPDATES AS
SELECT 
    plant_id,
    pcs_name,
    revision,
    status,
    last_update,
    last_update_by,
    last_api_sync
FROM PCS_LIST
WHERE is_valid = 'Y'
  AND last_update IS NOT NULL
ORDER BY last_update DESC
FETCH FIRST 100 ROWS ONLY;

COMMENT ON VIEW V_PCS_RECENT_UPDATES IS 'Most recently updated PCS revisions (top 100)';

-- View to identify which PCS revisions to load based on loading mode
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

COMMENT ON VIEW V_PCS_TO_LOAD IS 'Identifies which PCS revisions should be loaded based on PCS_LOADING_MODE setting';

-- Grant select permissions on all views
GRANT SELECT ON V_PCS_LIST_SUMMARY TO TR2000_STAGING;
GRANT SELECT ON V_PCS_DETAILS_COMPLETENESS TO TR2000_STAGING;
GRANT SELECT ON V_PCS_DETAIL_COUNTS TO TR2000_STAGING;
GRANT SELECT ON V_PCS_PROCESSING_STATUS TO TR2000_STAGING;
GRANT SELECT ON V_PCS_MATERIAL_GROUPS TO TR2000_STAGING;
GRANT SELECT ON V_PCS_PIPE_ELEMENT_MATERIALS TO TR2000_STAGING;
GRANT SELECT ON V_PCS_RECENT_UPDATES TO TR2000_STAGING;
GRANT SELECT ON V_PCS_TO_LOAD TO TR2000_STAGING;