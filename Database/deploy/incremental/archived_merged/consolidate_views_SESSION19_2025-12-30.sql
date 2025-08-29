-- ===============================================================================
-- Consolidate Views
-- Date: 2025-12-30
-- Purpose: Consolidate overlapping views into unified dashboards
-- ===============================================================================

-- Step 1: Drop redundant VDS views (will be replaced by consolidated versions)
DROP VIEW V_VDS_SUMMARY;
DROP VIEW V_VDS_BY_STATUS;
DROP VIEW V_VDS_DETAILS_STATUS;

-- Step 2: Create consolidated VDS Dashboard
CREATE OR REPLACE VIEW V_VDS_DASHBOARD AS
SELECT 
    -- Summary stats from VDS_LIST (the main tracking table)
    'VDS_LIST' as source_table,
    COUNT(*) as total_records,
    COUNT(DISTINCT plant_id) as total_plants,
    SUM(CASE WHEN is_official = 'Y' THEN 1 ELSE 0 END) as official_count,
    SUM(CASE WHEN is_official = 'N' THEN 1 ELSE 0 END) as unofficial_count,
    -- Status breakdown
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) as valid_count,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) as invalid_count,
    -- Data quality
    COUNT(DISTINCT vds_name) as unique_vds_names,
    COUNT(DISTINCT revision) as unique_revisions,
    -- Timing
    MIN(created_date) as earliest_record,
    MAX(created_date) as latest_record,
    MAX(last_modified_date) as last_update
FROM VDS_LIST
UNION ALL
SELECT 
    -- Summary from VDS_DETAILS (the detail records)
    'VDS_DETAILS' as source_table,
    COUNT(*) as total_records,
    COUNT(DISTINCT vds_name) as total_vds,
    NULL as official_count,
    NULL as unofficial_count,
    SUM(CASE WHEN is_valid = 'Y' THEN 1 ELSE 0 END) as valid_count,
    SUM(CASE WHEN is_valid = 'N' THEN 1 ELSE 0 END) as invalid_count,
    COUNT(DISTINCT vds_name) as unique_vds_names,
    COUNT(DISTINCT revision) as unique_revisions,
    MIN(created_date) as earliest_record,
    MAX(created_date) as latest_record,
    MAX(last_modified_date) as last_update
FROM VDS_DETAILS;

-- Step 3: Drop redundant PCS views
DROP VIEW V_PCS_DETAILS_SUMMARY;
DROP VIEW V_PCS_DETAILS_LOAD_STATUS;

-- Step 4: Create consolidated PCS Dashboard
CREATE OR REPLACE VIEW V_PCS_DASHBOARD AS
SELECT 
    'HEADER' as detail_type,
    COUNT(*) as record_count,
    COUNT(DISTINCT plant_id) as plants,
    COUNT(DISTINCT pcs_name) as pcs_names,
    MAX(created_date) as last_loaded
FROM PCS_HEADER_PROPERTIES
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'TEMP_PRESSURE' as detail_type,
    COUNT(*) as record_count,
    COUNT(DISTINCT plant_id) as plants,
    COUNT(DISTINCT pcs_name) as pcs_names,
    MAX(created_date) as last_loaded
FROM PCS_TEMP_PRESSURES
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'PIPE_SIZES' as detail_type,
    COUNT(*) as record_count,
    COUNT(DISTINCT plant_id) as plants,
    COUNT(DISTINCT pcs_name) as pcs_names,
    MAX(created_date) as last_loaded
FROM PCS_PIPE_SIZES
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'PIPE_ELEMENTS' as detail_type,
    COUNT(*) as record_count,
    COUNT(DISTINCT plant_id) as plants,
    COUNT(DISTINCT pcs_name) as pcs_names,
    MAX(created_date) as last_loaded
FROM PCS_PIPE_ELEMENTS
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'VALVE_ELEMENTS' as detail_type,
    COUNT(*) as record_count,
    COUNT(DISTINCT plant_id) as plants,
    COUNT(DISTINCT pcs_name) as pcs_names,
    MAX(created_date) as last_loaded
FROM PCS_VALVE_ELEMENTS
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'EMBEDDED_NOTES' as detail_type,
    COUNT(*) as record_count,
    COUNT(DISTINCT plant_id) as plants,
    COUNT(DISTINCT pcs_name) as pcs_names,
    MAX(created_date) as last_loaded
FROM PCS_EMBEDDED_NOTES
WHERE is_valid = 'Y';

-- Step 5: Create comprehensive ETL Health Dashboard
CREATE OR REPLACE VIEW V_ETL_HEALTH_DASHBOARD AS
SELECT 
    'ETL_RUNS' as metric_source,
    'Total Runs' as metric_name,
    TO_CHAR(COUNT(*)) as metric_value,
    NULL as additional_info
FROM ETL_RUN_LOG
UNION ALL
SELECT 
    'ETL_RUNS' as metric_source,
    'Success Rate' as metric_name,
    TO_CHAR(ROUND(100 * SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2)) || '%' as metric_value,
    'Last 24 hours' as additional_info
FROM ETL_RUN_LOG
WHERE start_time > SYSTIMESTAMP - INTERVAL '1' DAY
UNION ALL
SELECT 
    'API_CALLS' as metric_source,
    'Total API Calls' as metric_name,
    TO_CHAR(COUNT(*)) as metric_value,
    NULL as additional_info
FROM ETL_LOG
UNION ALL
SELECT 
    'API_CALLS' as metric_source,
    'Avg Response Time' as metric_name,
    TO_CHAR(ROUND(AVG(avg_response_time_ms), 2)) || ' ms' as metric_value,
    'From ETL_STATS' as additional_info
FROM ETL_STATS
WHERE avg_response_time_ms IS NOT NULL
UNION ALL
SELECT 
    'DATA_VOLUME' as metric_source,
    'Plants Loaded' as metric_name,
    TO_CHAR(COUNT(*)) as metric_value,
    NULL as additional_info
FROM PLANTS
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'DATA_VOLUME' as metric_source,
    'Issues Loaded' as metric_name,
    TO_CHAR(COUNT(*)) as metric_value,
    NULL as additional_info
FROM ISSUES
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'DATA_VOLUME' as metric_source,
    'Total References' as metric_name,
    TO_CHAR(
        (SELECT COUNT(*) FROM PCS_REFERENCES WHERE is_valid = 'Y') +
        (SELECT COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y') +
        (SELECT COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y') +
        (SELECT COUNT(*) FROM SC_REFERENCES WHERE is_valid = 'Y') +
        (SELECT COUNT(*) FROM VSM_REFERENCES WHERE is_valid = 'Y') +
        (SELECT COUNT(*) FROM EDS_REFERENCES WHERE is_valid = 'Y') +
        (SELECT COUNT(*) FROM ESK_REFERENCES WHERE is_valid = 'Y') +
        (SELECT COUNT(*) FROM VSK_REFERENCES WHERE is_valid = 'Y') +
        (SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y')
    ) as metric_value,
    'All 9 types' as additional_info
FROM DUAL;

-- Step 6: Create API Performance Metrics view
CREATE OR REPLACE VIEW V_API_PERFORMANCE_METRICS AS
SELECT 
    endpoint_key,
    plant_id,
    api_call_count,
    avg_response_time_ms,
    min_response_time_ms,
    max_response_time_ms,
    success_rate_pct,
    last_successful_run,
    last_error,
    data_volume_mb
FROM ETL_STATS
ORDER BY endpoint_key, plant_id;

-- Step 7: Check all views compile
SELECT view_name, text_length
FROM user_views
ORDER BY view_name;