-- ===============================================================================
-- VDS Monitoring Views
-- Session 18: Task 9.9 - Create analysis views for VDS data
-- Purpose: Monitor VDS data quality, coverage, and ETL performance
-- ===============================================================================

-- ============================================
-- V_VDS_SUMMARY: Overall VDS statistics
-- ============================================
CREATE OR REPLACE VIEW V_VDS_SUMMARY AS
SELECT 
    'VDS_LIST' as entity_type,
    COUNT(*) as total_count,
    COUNT(CASE WHEN is_valid = 'Y' THEN 1 END) as valid_count,
    COUNT(CASE WHEN status = 'O' THEN 1 END) as official_count,
    COUNT(CASE WHEN status = 'R' THEN 1 END) as review_count,
    COUNT(CASE WHEN status = 'W' THEN 1 END) as working_count,
    MAX(last_api_sync) as last_sync
FROM VDS_LIST
UNION ALL
SELECT 
    'VDS_DETAILS' as entity_type,
    COUNT(*) as total_count,
    COUNT(CASE WHEN is_valid = 'Y' THEN 1 END) as valid_count,
    NULL as official_count,
    NULL as review_count,
    NULL as working_count,
    MAX(last_api_sync) as last_sync
FROM VDS_DETAILS
UNION ALL
SELECT 
    'VDS_REFERENCES' as entity_type,
    COUNT(*) as total_count,
    COUNT(CASE WHEN is_valid = 'Y' THEN 1 END) as valid_count,
    COUNT(CASE WHEN status = 'Official' THEN 1 END) as official_count,
    COUNT(CASE WHEN status = 'Review' THEN 1 END) as review_count,
    NULL as working_count,
    MAX(last_api_sync) as last_sync
FROM VDS_REFERENCES;

-- Summary statistics for all VDS entities

-- ============================================
-- V_VDS_COVERAGE: VDS data coverage analysis
-- ============================================
CREATE OR REPLACE VIEW V_VDS_COVERAGE AS
WITH total_vds AS (
    SELECT COUNT(*) as total FROM VDS_LIST WHERE is_valid='Y'
),
with_details AS (
    SELECT COUNT(DISTINCT vl.vds_name) as cnt
    FROM VDS_LIST vl
    INNER JOIN VDS_DETAILS vd ON vl.vds_guid = vd.vds_guid
    WHERE vl.is_valid = 'Y' AND vd.is_valid = 'Y'
)
SELECT 
    'VDS with Details' as coverage_type,
    wd.cnt as vds_count,
    ROUND(wd.cnt * 100.0 / NULLIF(t.total, 0), 2) as percentage
FROM with_details wd, total_vds t
UNION ALL
SELECT 
    'Referenced VDS with Details' as coverage_type,
    COUNT(DISTINCT vr.vds_name) as vds_count,
    ROUND(COUNT(DISTINCT vr.vds_name) * 100.0 / 
          NULLIF((SELECT COUNT(DISTINCT vds_name) FROM VDS_REFERENCES WHERE is_valid='Y'), 0), 2) as percentage
FROM VDS_REFERENCES vr
INNER JOIN VDS_DETAILS vd ON vr.vds_name = vd.vds_name
WHERE vr.is_valid = 'Y' AND vd.is_valid = 'Y'
UNION ALL
SELECT 
    'Official VDS in List' as coverage_type,
    COUNT(*) as vds_count,
    ROUND(COUNT(*) * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM VDS_LIST WHERE is_valid='Y'), 0), 2) as percentage
FROM VDS_LIST
WHERE is_valid = 'Y' AND status = 'O';

-- COMMENT: V_VDS_COVERAGE IS 'VDS data coverage and completeness metrics';

-- ============================================
-- V_VDS_BY_STATUS: VDS distribution by status
-- ============================================
CREATE OR REPLACE VIEW V_VDS_BY_STATUS AS
SELECT 
    status,
    COUNT(*) as vds_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage,
    MIN(rev_date) as earliest_revision,
    MAX(rev_date) as latest_revision
FROM VDS_LIST
WHERE is_valid = 'Y'
GROUP BY status
ORDER BY vds_count DESC;

-- COMMENT: V_VDS_BY_STATUS IS 'VDS distribution by status with date ranges';

-- ============================================
-- V_VDS_DETAILS_STATUS: VDS details loading status
-- ============================================
CREATE OR REPLACE VIEW V_VDS_DETAILS_STATUS AS
WITH vds_stats AS (
    SELECT 
        vl.vds_name,
        vl.revision,
        vl.status,
        CASE WHEN vd.detail_guid IS NOT NULL THEN 'Loaded' ELSE 'Not Loaded' END as detail_status,
        vd.last_api_sync as detail_sync_time
    FROM VDS_LIST vl
    LEFT JOIN VDS_DETAILS vd ON vl.vds_guid = vd.vds_guid AND vd.is_valid = 'Y'
    WHERE vl.is_valid = 'Y'
)
SELECT 
    status as vds_status,
    detail_status,
    COUNT(*) as count,
    MAX(detail_sync_time) as last_loaded
FROM vds_stats
GROUP BY status, detail_status
ORDER BY status, detail_status;

-- COMMENT: V_VDS_DETAILS_STATUS IS 'VDS details loading status by VDS status';

-- ============================================
-- V_VDS_REFERENCE_USAGE: How VDS are referenced
-- ============================================
CREATE OR REPLACE VIEW V_VDS_REFERENCE_USAGE AS
SELECT 
    vr.plant_id,
    vr.issue_revision,
    COUNT(DISTINCT vr.vds_name) as unique_vds,
    COUNT(*) as total_references,
    COUNT(DISTINCT vr.official_revision) as unique_official_revisions,
    LISTAGG(DISTINCT vr.status, ', ') WITHIN GROUP (ORDER BY vr.status) as status_types
FROM VDS_REFERENCES vr
WHERE vr.is_valid = 'Y'
GROUP BY vr.plant_id, vr.issue_revision
ORDER BY unique_vds DESC;

-- COMMENT: V_VDS_REFERENCE_USAGE IS 'VDS usage by plant and issue';

-- ============================================
-- V_VDS_API_PERFORMANCE: API call performance metrics
-- ============================================
CREATE OR REPLACE VIEW V_VDS_API_PERFORMANCE AS
SELECT 
    endpoint,
    COUNT(*) as api_calls,
    MIN(api_call_timestamp) as first_call,
    MAX(api_call_timestamp) as last_call,
    ROUND(AVG(DBMS_LOB.GETLENGTH(payload))/1024/1024, 2) as avg_payload_mb,
    ROUND(MAX(DBMS_LOB.GETLENGTH(payload))/1024/1024, 2) as max_payload_mb,
    ROUND(SUM(DBMS_LOB.GETLENGTH(payload))/1024/1024, 2) as total_payload_mb
FROM RAW_JSON
WHERE endpoint IN ('VDS_LIST', 'VDS_DETAILS')
GROUP BY endpoint;

-- COMMENT: V_VDS_API_PERFORMANCE IS 'VDS API call performance and payload metrics';

-- ============================================
-- V_VDS_MISSING_DETAILS: VDS that need details loaded
-- ============================================
CREATE OR REPLACE VIEW V_VDS_MISSING_DETAILS AS
SELECT 
    vr.vds_name,
    vr.official_revision,
    vr.plant_id,
    vr.issue_revision,
    vl.status as vds_status,
    'Missing in VDS_LIST' as reason
FROM VDS_REFERENCES vr
LEFT JOIN VDS_LIST vl ON vr.vds_name = vl.vds_name 
    AND vr.official_revision = vl.revision
    AND vl.is_valid = 'Y'
WHERE vr.is_valid = 'Y'
  AND vr.official_revision IS NOT NULL
  AND vl.vds_guid IS NULL
UNION ALL
SELECT 
    vl.vds_name,
    vl.revision,
    NULL as plant_id,
    NULL as issue_revision,
    vl.status as vds_status,
    'Missing Details' as reason
FROM VDS_LIST vl
LEFT JOIN VDS_DETAILS vd ON vl.vds_guid = vd.vds_guid AND vd.is_valid = 'Y'
WHERE vl.is_valid = 'Y'
  AND vl.status = 'O'  -- Official only
  AND vd.detail_guid IS NULL
  AND EXISTS (
      SELECT 1 FROM VDS_REFERENCES vr 
      WHERE vr.vds_name = vl.vds_name 
        AND vr.is_valid = 'Y'
  );

-- COMMENT: V_VDS_MISSING_DETAILS IS 'VDS records that need details loaded';

-- ============================================
-- V_VDS_DATA_QUALITY: Data quality checks
-- ============================================
CREATE OR REPLACE VIEW V_VDS_DATA_QUALITY AS
SELECT 'VDS_LIST with null names' as quality_check, COUNT(*) as issue_count
FROM VDS_LIST WHERE vds_name IS NULL
UNION ALL
SELECT 'VDS_LIST with null status' as quality_check, COUNT(*) as issue_count
FROM VDS_LIST WHERE status IS NULL AND is_valid = 'Y'
UNION ALL
SELECT 'VDS_DETAILS without parent' as quality_check, COUNT(*) as issue_count
FROM VDS_DETAILS vd
WHERE NOT EXISTS (
    SELECT 1 FROM VDS_LIST vl 
    WHERE vl.vds_guid = vd.vds_guid AND vl.is_valid = 'Y'
) AND vd.is_valid = 'Y'
UNION ALL
SELECT 'VDS_REFERENCES without official revision' as quality_check, COUNT(*) as issue_count
FROM VDS_REFERENCES WHERE official_revision IS NULL AND is_valid = 'Y'
UNION ALL
SELECT 'Duplicate VDS_LIST entries' as quality_check, COUNT(*) as issue_count
FROM (
    SELECT vds_name, revision, COUNT(*) as cnt
    FROM VDS_LIST WHERE is_valid = 'Y'
    GROUP BY vds_name, revision
    HAVING COUNT(*) > 1
);

-- COMMENT: V_VDS_DATA_QUALITY IS 'VDS data quality validation checks';

-- ============================================
-- V_VDS_ETL_DASHBOARD: Executive dashboard
-- ============================================
CREATE OR REPLACE VIEW V_VDS_ETL_DASHBOARD AS
SELECT 
    (SELECT COUNT(*) FROM VDS_LIST WHERE is_valid='Y') as total_vds,
    (SELECT COUNT(*) FROM VDS_LIST WHERE is_valid='Y' AND status='O') as official_vds,
    (SELECT COUNT(*) FROM VDS_DETAILS WHERE is_valid='Y') as loaded_details,
    (SELECT COUNT(DISTINCT vds_name) FROM VDS_REFERENCES WHERE is_valid='Y') as referenced_vds,
    (SELECT ROUND(SUM(DBMS_LOB.GETLENGTH(payload))/1024/1024, 2) 
     FROM RAW_JSON WHERE endpoint LIKE 'VDS%') as total_data_mb,
    (SELECT MAX(last_api_sync) FROM VDS_LIST) as last_list_sync,
    (SELECT MAX(last_api_sync) FROM VDS_DETAILS) as last_detail_sync,
    (SELECT setting_value FROM CONTROL_SETTINGS WHERE setting_key='VDS_LOADING_MODE') as loading_mode
FROM DUAL;

-- COMMENT: V_VDS_ETL_DASHBOARD IS 'VDS ETL executive dashboard with key metrics';

-- Grant permissions
GRANT SELECT ON V_VDS_SUMMARY TO TR2000_STAGING;
GRANT SELECT ON V_VDS_COVERAGE TO TR2000_STAGING;
GRANT SELECT ON V_VDS_BY_STATUS TO TR2000_STAGING;
GRANT SELECT ON V_VDS_DETAILS_STATUS TO TR2000_STAGING;
GRANT SELECT ON V_VDS_REFERENCE_USAGE TO TR2000_STAGING;
GRANT SELECT ON V_VDS_API_PERFORMANCE TO TR2000_STAGING;
GRANT SELECT ON V_VDS_MISSING_DETAILS TO TR2000_STAGING;
GRANT SELECT ON V_VDS_DATA_QUALITY TO TR2000_STAGING;
GRANT SELECT ON V_VDS_ETL_DASHBOARD TO TR2000_STAGING;
/