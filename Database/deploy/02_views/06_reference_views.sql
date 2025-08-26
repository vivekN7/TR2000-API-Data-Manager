-- ===============================================================================
-- Views: Reference Data Monitoring Views
-- Purpose: Monitor and analyze reference data across all 9 types
-- Author: TR2000 ETL Team
-- Date: 2025-08-26
-- ===============================================================================

-- =========================================================================
-- V_REFERENCE_COUNTS: Summary of all reference types by issue
-- =========================================================================
CREATE OR REPLACE VIEW V_REFERENCE_COUNTS AS
SELECT 
    i.plant_id,
    i.issue_revision,
    i.status AS issue_status,
    i.is_valid AS issue_valid,
    -- Count each reference type
    (SELECT COUNT(*) FROM PCS_REFERENCES p 
     WHERE p.plant_id = i.plant_id 
       AND p.issue_revision = i.issue_revision 
       AND p.is_valid = 'Y') AS pcs_count,
    (SELECT COUNT(*) FROM SC_REFERENCES s 
     WHERE s.plant_id = i.plant_id 
       AND s.issue_revision = i.issue_revision 
       AND s.is_valid = 'Y') AS sc_count,
    (SELECT COUNT(*) FROM VSM_REFERENCES v 
     WHERE v.plant_id = i.plant_id 
       AND v.issue_revision = i.issue_revision 
       AND v.is_valid = 'Y') AS vsm_count,
    (SELECT COUNT(*) FROM VDS_REFERENCES vd 
     WHERE vd.plant_id = i.plant_id 
       AND vd.issue_revision = i.issue_revision 
       AND vd.is_valid = 'Y') AS vds_count,
    (SELECT COUNT(*) FROM EDS_REFERENCES e 
     WHERE e.plant_id = i.plant_id 
       AND e.issue_revision = i.issue_revision 
       AND e.is_valid = 'Y') AS eds_count,
    (SELECT COUNT(*) FROM MDS_REFERENCES m 
     WHERE m.plant_id = i.plant_id 
       AND m.issue_revision = i.issue_revision 
       AND m.is_valid = 'Y') AS mds_count,
    (SELECT COUNT(*) FROM VSK_REFERENCES vk 
     WHERE vk.plant_id = i.plant_id 
       AND vk.issue_revision = i.issue_revision 
       AND vk.is_valid = 'Y') AS vsk_count,
    (SELECT COUNT(*) FROM ESK_REFERENCES ek 
     WHERE ek.plant_id = i.plant_id 
       AND ek.issue_revision = i.issue_revision 
       AND ek.is_valid = 'Y') AS esk_count,
    (SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES pe 
     WHERE pe.plant_id = i.plant_id 
       AND pe.issue_revision = i.issue_revision 
       AND pe.is_valid = 'Y') AS pipe_element_count
FROM ISSUES i
WHERE i.is_valid = 'Y';

COMMENT ON VIEW V_REFERENCE_COUNTS IS 'Summary of reference counts for each issue';

-- =========================================================================
-- V_REFERENCE_STATUS: Overall status of reference data loading
-- =========================================================================
CREATE OR REPLACE VIEW V_REFERENCE_STATUS AS
SELECT 
    'PCS_REFERENCES' AS reference_type,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) AS active_records,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) AS invalid_records,
    MAX(last_modified_date) AS last_update,
    MAX(last_api_sync) AS last_sync
FROM PCS_REFERENCES
UNION ALL
SELECT 
    'SC_REFERENCES' AS reference_type,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) AS active_records,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) AS invalid_records,
    MAX(last_modified_date) AS last_update,
    MAX(last_api_sync) AS last_sync
FROM SC_REFERENCES
UNION ALL
SELECT 
    'VSM_REFERENCES' AS reference_type,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) AS active_records,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) AS invalid_records,
    MAX(last_modified_date) AS last_update,
    MAX(last_api_sync) AS last_sync
FROM VSM_REFERENCES
UNION ALL
SELECT 
    'VDS_REFERENCES' AS reference_type,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) AS active_records,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) AS invalid_records,
    MAX(last_modified_date) AS last_update,
    MAX(last_api_sync) AS last_sync
FROM VDS_REFERENCES
UNION ALL
SELECT 
    'EDS_REFERENCES' AS reference_type,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) AS active_records,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) AS invalid_records,
    MAX(last_modified_date) AS last_update,
    MAX(last_api_sync) AS last_sync
FROM EDS_REFERENCES
UNION ALL
SELECT 
    'MDS_REFERENCES' AS reference_type,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) AS active_records,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) AS invalid_records,
    MAX(last_modified_date) AS last_update,
    MAX(last_api_sync) AS last_sync
FROM MDS_REFERENCES
UNION ALL
SELECT 
    'VSK_REFERENCES' AS reference_type,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) AS active_records,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) AS invalid_records,
    MAX(last_modified_date) AS last_update,
    MAX(last_api_sync) AS last_sync
FROM VSK_REFERENCES
UNION ALL
SELECT 
    'ESK_REFERENCES' AS reference_type,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) AS active_records,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) AS invalid_records,
    MAX(last_modified_date) AS last_update,
    MAX(last_api_sync) AS last_sync
FROM ESK_REFERENCES
UNION ALL
SELECT 
    'PIPE_ELEMENT_REFERENCES' AS reference_type,
    COUNT(*) AS total_records,
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) AS active_records,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) AS invalid_records,
    MAX(last_modified_date) AS last_update,
    MAX(last_api_sync) AS last_sync
FROM PIPE_ELEMENT_REFERENCES;

COMMENT ON VIEW V_REFERENCE_STATUS IS 'Overall status of all reference table data';

-- =========================================================================
-- V_REFERENCE_ETL_LOG: ETL history for reference data loads
-- =========================================================================
CREATE OR REPLACE VIEW V_REFERENCE_ETL_LOG AS
SELECT 
    run_id,
    run_type,
    endpoint_key,
    plant_id,
    issue_revision,
    start_time,
    end_time,
    status,
    records_processed,
    ROUND((end_time - start_time) * 24 * 60 * 60, 2) AS duration_seconds,
    notes
FROM ETL_RUN_LOG
WHERE endpoint_key LIKE '%_references'
ORDER BY start_time DESC;

COMMENT ON VIEW V_REFERENCE_ETL_LOG IS 'ETL run history for reference data loads';

-- =========================================================================
-- V_PCS_REFERENCE_DETAILS: Detailed view of PCS references
-- =========================================================================
CREATE OR REPLACE VIEW V_PCS_REFERENCE_DETAILS AS
SELECT 
    p.plant_id,
    pl.short_description AS plant_name,
    p.issue_revision,
    p.pcs_name,
    p.revision,
    p.rev_date,
    p.status,
    p.rating_class,
    p.material_group,
    p.is_valid,
    p.last_modified_date,
    p.last_api_sync
FROM PCS_REFERENCES p
LEFT JOIN PLANTS pl ON p.plant_id = pl.plant_id
WHERE p.is_valid = 'Y';

COMMENT ON VIEW V_PCS_REFERENCE_DETAILS IS 'Detailed view of active PCS references with plant names';

-- =========================================================================
-- V_REFERENCE_CASCADE_LOG: Track cascade operations on references
-- =========================================================================
CREATE OR REPLACE VIEW V_REFERENCE_CASCADE_LOG AS
SELECT 
    cascade_id,
    cascade_type,
    source_table,
    source_id,
    target_table,
    affected_count,
    cascade_timestamp,
    trigger_name,
    action_taken
FROM CASCADE_LOG
WHERE cascade_type = 'ISSUE_TO_REFERENCES'
   OR target_table = 'REFERENCE_TABLES'
ORDER BY cascade_timestamp DESC;

COMMENT ON VIEW V_REFERENCE_CASCADE_LOG IS 'History of cascade operations affecting reference tables';

-- =========================================================================
-- V_REFERENCE_SYNC_STATUS: Check which issues need reference sync
-- =========================================================================
CREATE OR REPLACE VIEW V_REFERENCE_SYNC_STATUS AS
SELECT 
    i.plant_id,
    i.issue_revision,
    i.last_modified_date AS issue_last_modified,
    NVL(rc.last_sync_date, TO_DATE('1900-01-01', 'YYYY-MM-DD')) AS references_last_sync,
    CASE 
        WHEN rc.last_sync_date IS NULL THEN 'NEVER_SYNCED'
        WHEN i.last_modified_date > rc.last_sync_date THEN 'NEEDS_SYNC'
        ELSE 'UP_TO_DATE'
    END AS sync_status
FROM ISSUES i
LEFT JOIN (
    SELECT 
        plant_id,
        issue_revision,
        MAX(last_api_sync) AS last_sync_date
    FROM (
        SELECT plant_id, issue_revision, MAX(last_api_sync) AS last_api_sync FROM PCS_REFERENCES GROUP BY plant_id, issue_revision
        UNION ALL
        SELECT plant_id, issue_revision, MAX(last_api_sync) FROM SC_REFERENCES GROUP BY plant_id, issue_revision
        UNION ALL
        SELECT plant_id, issue_revision, MAX(last_api_sync) FROM VSM_REFERENCES GROUP BY plant_id, issue_revision
        UNION ALL
        SELECT plant_id, issue_revision, MAX(last_api_sync) FROM VDS_REFERENCES GROUP BY plant_id, issue_revision
        UNION ALL
        SELECT plant_id, issue_revision, MAX(last_api_sync) FROM EDS_REFERENCES GROUP BY plant_id, issue_revision
        UNION ALL
        SELECT plant_id, issue_revision, MAX(last_api_sync) FROM MDS_REFERENCES GROUP BY plant_id, issue_revision
        UNION ALL
        SELECT plant_id, issue_revision, MAX(last_api_sync) FROM VSK_REFERENCES GROUP BY plant_id, issue_revision
        UNION ALL
        SELECT plant_id, issue_revision, MAX(last_api_sync) FROM ESK_REFERENCES GROUP BY plant_id, issue_revision
        UNION ALL
        SELECT plant_id, issue_revision, MAX(last_api_sync) FROM PIPE_ELEMENT_REFERENCES GROUP BY plant_id, issue_revision
    )
    GROUP BY plant_id, issue_revision
) rc ON i.plant_id = rc.plant_id AND i.issue_revision = rc.issue_revision
WHERE i.is_valid = 'Y';

COMMENT ON VIEW V_REFERENCE_SYNC_STATUS IS 'Shows which issues need their references synchronized';

-- =========================================================================
-- Show created views
-- =========================================================================
SELECT view_name, comments 
FROM user_views uv
LEFT JOIN user_tab_comments utc ON uv.view_name = utc.table_name
WHERE view_name LIKE 'V_%REFERENCE%'
ORDER BY view_name;

PROMPT Views for reference monitoring created successfully.