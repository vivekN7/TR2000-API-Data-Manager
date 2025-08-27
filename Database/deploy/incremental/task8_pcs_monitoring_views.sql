-- ===============================================================================
-- PCS Details Monitoring Views
-- Date: 2025-08-28
-- Purpose: Create views for monitoring PCS detail data (Task 8)
-- ===============================================================================

-- View for PCS Details Summary
CREATE OR REPLACE VIEW V_PCS_DETAILS_SUMMARY AS
SELECT 
    pr.plant_id,
    pr.issue_revision,
    pr.pcs_name,
    pr.revision,
    pr.status as pcs_status,
    pr.rating_class,
    pr.material_group,
    -- Count details from each table
    (SELECT COUNT(*) FROM PCS_HEADER_PROPERTIES hp 
     WHERE hp.plant_id = pr.plant_id 
     AND hp.issue_revision = pr.issue_revision 
     AND hp.pcs_name = pr.pcs_name 
     AND hp.revision = pr.revision 
     AND hp.is_valid = 'Y') as header_count,
    (SELECT COUNT(*) FROM PCS_TEMP_PRESSURES tp 
     WHERE tp.plant_id = pr.plant_id 
     AND tp.issue_revision = pr.issue_revision 
     AND tp.pcs_name = pr.pcs_name 
     AND tp.revision = pr.revision 
     AND tp.is_valid = 'Y') as temp_pressure_count,
    (SELECT COUNT(*) FROM PCS_PIPE_SIZES ps 
     WHERE ps.plant_id = pr.plant_id 
     AND ps.issue_revision = pr.issue_revision 
     AND ps.pcs_name = pr.pcs_name 
     AND ps.revision = pr.revision 
     AND ps.is_valid = 'Y') as pipe_size_count,
    (SELECT COUNT(*) FROM PCS_PIPE_ELEMENTS pe 
     WHERE pe.plant_id = pr.plant_id 
     AND pe.issue_revision = pr.issue_revision 
     AND pe.pcs_name = pr.pcs_name 
     AND pe.revision = pr.revision 
     AND pe.is_valid = 'Y') as pipe_element_count,
    (SELECT COUNT(*) FROM PCS_VALVE_ELEMENTS ve 
     WHERE ve.plant_id = pr.plant_id 
     AND ve.issue_revision = pr.issue_revision 
     AND ve.pcs_name = pr.pcs_name 
     AND ve.revision = pr.revision 
     AND ve.is_valid = 'Y') as valve_element_count,
    (SELECT COUNT(*) FROM PCS_EMBEDDED_NOTES en 
     WHERE en.plant_id = pr.plant_id 
     AND en.issue_revision = pr.issue_revision 
     AND en.pcs_name = pr.pcs_name 
     AND en.revision = pr.revision 
     AND en.is_valid = 'Y') as embedded_notes_count,
    pr.last_api_sync
FROM PCS_REFERENCES pr
WHERE pr.is_valid = 'Y'
ORDER BY pr.plant_id, pr.issue_revision, pr.pcs_name;

COMMENT ON VIEW V_PCS_DETAILS_SUMMARY IS 'Summary of PCS references and their detail counts';

-- View for PCS Header Properties with Key Information
CREATE OR REPLACE VIEW V_PCS_HEADER_INFO AS
SELECT 
    hp.plant_id,
    hp.issue_revision,
    hp.pcs_name,
    hp.revision,
    hp.status,
    hp.rev_date,
    hp.rating_class,
    hp.test_pressure,
    hp.material_group,
    hp.design_code,
    hp.sc,
    hp.vsm,
    hp.corr_allowance,
    hp.design_press01 as design_pressure_1,
    hp.design_temp01 as design_temp_1,
    hp.last_update,
    hp.last_update_by,
    hp.approver,
    hp.last_api_sync
FROM PCS_HEADER_PROPERTIES hp
WHERE hp.is_valid = 'Y'
ORDER BY hp.plant_id, hp.issue_revision, hp.pcs_name;

COMMENT ON VIEW V_PCS_HEADER_INFO IS 'PCS header properties with key design information';

-- View for PCS Temperature/Pressure Operating Conditions
CREATE OR REPLACE VIEW V_PCS_OPERATING_CONDITIONS AS
SELECT 
    tp.plant_id,
    tp.issue_revision,
    tp.pcs_name,
    tp.revision,
    tp.temperature,
    tp.pressure,
    pr.rating_class,
    pr.material_group
FROM PCS_TEMP_PRESSURES tp
JOIN PCS_REFERENCES pr ON (
    pr.plant_id = tp.plant_id 
    AND pr.issue_revision = tp.issue_revision 
    AND pr.pcs_name = tp.pcs_name
    AND pr.is_valid = 'Y'
)
WHERE tp.is_valid = 'Y'
ORDER BY tp.plant_id, tp.pcs_name, tp.temperature;

COMMENT ON VIEW V_PCS_OPERATING_CONDITIONS IS 'PCS temperature and pressure operating conditions';

-- View for PCS Pipe Sizing Details
CREATE OR REPLACE VIEW V_PCS_PIPE_SIZING AS
SELECT 
    ps.plant_id,
    ps.issue_revision,
    ps.pcs_name,
    ps.revision,
    ps.nom_size,
    ps.outer_diam,
    ps.wall_thickness,
    ps.schedule,
    ps.under_tolerance,
    ps.corrosion_allowance,
    ps.welding_factor,
    pr.rating_class,
    pr.material_group
FROM PCS_PIPE_SIZES ps
JOIN PCS_REFERENCES pr ON (
    pr.plant_id = ps.plant_id 
    AND pr.issue_revision = ps.issue_revision 
    AND pr.pcs_name = ps.pcs_name
    AND pr.is_valid = 'Y'
)
WHERE ps.is_valid = 'Y'
ORDER BY ps.plant_id, ps.pcs_name, ps.nom_size;

COMMENT ON VIEW V_PCS_PIPE_SIZING IS 'PCS pipe sizing specifications';

-- View for PCS Element Cross-Reference (Pipe and Valve Elements)
CREATE OR REPLACE VIEW V_PCS_ELEMENT_XREF AS
SELECT 
    'PIPE' as element_type,
    pe.plant_id,
    pe.issue_revision,
    pe.pcs_name,
    pe.revision,
    pe.element_group_no as group_no,
    pe.line_no,
    pe.element as description,
    pe.from_size,
    pe.to_size,
    pe.mds,
    pe.eds,
    pe.esk,
    NULL as vds
FROM PCS_PIPE_ELEMENTS pe
WHERE pe.is_valid = 'Y'
UNION ALL
SELECT 
    'VALVE' as element_type,
    ve.plant_id,
    ve.issue_revision,
    ve.pcs_name,
    ve.revision,
    ve.valve_group_no as group_no,
    ve.line_no,
    ve.valve_description as description,
    ve.from_size,
    ve.to_size,
    NULL as mds,
    NULL as eds,
    NULL as esk,
    ve.vds
FROM PCS_VALVE_ELEMENTS ve
WHERE ve.is_valid = 'Y'
ORDER BY plant_id, pcs_name, element_type, group_no, line_no;

COMMENT ON VIEW V_PCS_ELEMENT_XREF IS 'Cross-reference of all PCS pipe and valve elements';

-- View for PCS Details Load Status
CREATE OR REPLACE VIEW V_PCS_DETAILS_LOAD_STATUS AS
SELECT 
    'PCS_HEADER_PROPERTIES' as table_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT plant_id || '|' || issue_revision || '|' || pcs_name) as unique_pcs_count,
    MAX(last_api_sync) as latest_sync
FROM PCS_HEADER_PROPERTIES
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'PCS_TEMP_PRESSURES',
    COUNT(*),
    COUNT(DISTINCT plant_id || '|' || issue_revision || '|' || pcs_name),
    MAX(last_api_sync)
FROM PCS_TEMP_PRESSURES
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'PCS_PIPE_SIZES',
    COUNT(*),
    COUNT(DISTINCT plant_id || '|' || issue_revision || '|' || pcs_name),
    MAX(last_api_sync)
FROM PCS_PIPE_SIZES
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'PCS_PIPE_ELEMENTS',
    COUNT(*),
    COUNT(DISTINCT plant_id || '|' || issue_revision || '|' || pcs_name),
    MAX(last_api_sync)
FROM PCS_PIPE_ELEMENTS
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'PCS_VALVE_ELEMENTS',
    COUNT(*),
    COUNT(DISTINCT plant_id || '|' || issue_revision || '|' || pcs_name),
    MAX(last_api_sync)
FROM PCS_VALVE_ELEMENTS
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'PCS_EMBEDDED_NOTES',
    COUNT(*),
    COUNT(DISTINCT plant_id || '|' || issue_revision || '|' || pcs_name),
    MAX(last_api_sync)
FROM PCS_EMBEDDED_NOTES
WHERE is_valid = 'Y';

COMMENT ON VIEW V_PCS_DETAILS_LOAD_STATUS IS 'Load status for all PCS detail tables';

-- View for System Health Dashboard (Updated to include PCS Details)
CREATE OR REPLACE VIEW V_SYSTEM_HEALTH_DASHBOARD AS
SELECT 
    'Plants' as entity_type,
    (SELECT COUNT(*) FROM PLANTS WHERE is_valid = 'Y') as valid_count,
    (SELECT COUNT(*) FROM SELECTED_PLANTS WHERE is_active = 'Y') as selected_count,
    NULL as reference_count
FROM DUAL
UNION ALL
SELECT 
    'Issues',
    (SELECT COUNT(*) FROM ISSUES WHERE is_valid = 'Y'),
    (SELECT COUNT(*) FROM SELECTED_ISSUES WHERE is_active = 'Y'),
    NULL
FROM DUAL
UNION ALL
SELECT 
    'References',
    (SELECT COUNT(*) FROM (
        SELECT 1 FROM PCS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM SC_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM VSM_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM VDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM EDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM MDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM VSK_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM ESK_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
    )),
    NULL,
    (SELECT COUNT(DISTINCT reference_type) FROM (
        SELECT 'PCS' as reference_type FROM PCS_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'SC' FROM SC_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'VSM' FROM VSM_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'VDS' FROM VDS_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'EDS' FROM EDS_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'MDS' FROM MDS_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'VSK' FROM VSK_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'ESK' FROM ESK_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'PIPE' FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
    ))
FROM DUAL
UNION ALL
SELECT 
    'PCS Details',
    (SELECT COUNT(*) FROM (
        SELECT 1 FROM PCS_HEADER_PROPERTIES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM PCS_TEMP_PRESSURES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM PCS_PIPE_SIZES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM PCS_PIPE_ELEMENTS WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM PCS_VALVE_ELEMENTS WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM PCS_EMBEDDED_NOTES WHERE is_valid = 'Y'
    )),
    NULL,
    (SELECT COUNT(DISTINCT table_type) FROM (
        SELECT 'HEADER' as table_type FROM PCS_HEADER_PROPERTIES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'TEMP' FROM PCS_TEMP_PRESSURES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'SIZE' FROM PCS_PIPE_SIZES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'PIPE' FROM PCS_PIPE_ELEMENTS WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'VALVE' FROM PCS_VALVE_ELEMENTS WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'NOTE' FROM PCS_EMBEDDED_NOTES WHERE is_valid = 'Y' AND ROWNUM = 1
    ))
FROM DUAL
UNION ALL
SELECT 
    'Invalid Objects',
    (SELECT COUNT(*) FROM user_objects WHERE status = 'INVALID'),
    NULL,
    NULL
FROM DUAL
UNION ALL
SELECT 
    'Recent Errors (24h)',
    (SELECT COUNT(*) FROM ETL_ERROR_LOG 
     WHERE error_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY),
    NULL,
    NULL
FROM DUAL;

COMMENT ON VIEW V_SYSTEM_HEALTH_DASHBOARD IS 'Overall system health including PCS details';

-- Grant permissions
GRANT SELECT ON V_PCS_DETAILS_SUMMARY TO TR2000_STAGING;
GRANT SELECT ON V_PCS_HEADER_INFO TO TR2000_STAGING;
GRANT SELECT ON V_PCS_OPERATING_CONDITIONS TO TR2000_STAGING;
GRANT SELECT ON V_PCS_PIPE_SIZING TO TR2000_STAGING;
GRANT SELECT ON V_PCS_ELEMENT_XREF TO TR2000_STAGING;
GRANT SELECT ON V_PCS_DETAILS_LOAD_STATUS TO TR2000_STAGING;
GRANT SELECT ON V_SYSTEM_HEALTH_DASHBOARD TO TR2000_STAGING;