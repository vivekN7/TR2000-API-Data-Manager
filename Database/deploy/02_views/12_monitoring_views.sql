-- ===============================================================================
-- Additional Monitoring Views
-- Date: 2025-08-27
-- Purpose: Provide better visibility into ETL operations and test results
-- ===============================================================================

-- ===============================================================================
-- ETL Success Rate View
-- ===============================================================================
CREATE OR REPLACE VIEW V_ETL_SUCCESS_RATE AS
SELECT 
    run_type,
    COUNT(*) as total_runs,
    COUNT(CASE WHEN status = 'SUCCESS' THEN 1 END) as successful,
    COUNT(CASE WHEN status = 'FAILED' THEN 1 END) as failed,
    COUNT(CASE WHEN status = 'PARTIAL' THEN 1 END) as partial,
    ROUND(COUNT(CASE WHEN status = 'SUCCESS' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 2) as success_rate
FROM ETL_RUN_LOG
GROUP BY run_type
ORDER BY run_type;

COMMENT ON TABLE V_ETL_SUCCESS_RATE IS 'Shows success rates for each ETL run type';

-- ===============================================================================
-- Reference Summary View
-- ===============================================================================
CREATE OR REPLACE VIEW V_REFERENCE_SUMMARY AS
SELECT 
    plant_id,
    issue_revision,
    COUNT(DISTINCT reference_type) as ref_types_count,
    SUM(ref_count) as total_refs,
    LISTAGG(reference_type || '(' || ref_count || ')', ', ') 
        WITHIN GROUP (ORDER BY reference_type) as reference_breakdown
FROM (
    SELECT plant_id, issue_revision, 'PCS' as reference_type, COUNT(*) as ref_count
    FROM PCS_REFERENCES WHERE is_valid = 'Y'
    GROUP BY plant_id, issue_revision
    UNION ALL
    SELECT plant_id, issue_revision, 'VDS', COUNT(*)
    FROM VDS_REFERENCES WHERE is_valid = 'Y'
    GROUP BY plant_id, issue_revision
    UNION ALL
    SELECT plant_id, issue_revision, 'MDS', COUNT(*)
    FROM MDS_REFERENCES WHERE is_valid = 'Y'
    GROUP BY plant_id, issue_revision
    UNION ALL
    SELECT plant_id, issue_revision, 'PIPE', COUNT(*)
    FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
    GROUP BY plant_id, issue_revision
    UNION ALL
    SELECT plant_id, issue_revision, 'VSK', COUNT(*)
    FROM VSK_REFERENCES WHERE is_valid = 'Y'
    GROUP BY plant_id, issue_revision
    UNION ALL
    SELECT plant_id, issue_revision, 'EDS', COUNT(*)
    FROM EDS_REFERENCES WHERE is_valid = 'Y'
    GROUP BY plant_id, issue_revision
    UNION ALL
    SELECT plant_id, issue_revision, 'SC', COUNT(*)
    FROM SC_REFERENCES WHERE is_valid = 'Y'
    GROUP BY plant_id, issue_revision
    UNION ALL
    SELECT plant_id, issue_revision, 'VSM', COUNT(*)
    FROM VSM_REFERENCES WHERE is_valid = 'Y'
    GROUP BY plant_id, issue_revision
    UNION ALL
    SELECT plant_id, issue_revision, 'ESK', COUNT(*)
    FROM ESK_REFERENCES WHERE is_valid = 'Y'
    GROUP BY plant_id, issue_revision
)
WHERE ref_count > 0
GROUP BY plant_id, issue_revision
ORDER BY plant_id, issue_revision;

COMMENT ON TABLE V_REFERENCE_SUMMARY IS 'Summarizes all reference types by plant and issue';

-- ===============================================================================
-- ETL Performance View
-- ===============================================================================
CREATE OR REPLACE VIEW V_ETL_PERFORMANCE AS
SELECT 
    run_type,
    endpoint_key,
    COUNT(*) as execution_count,
    ROUND(AVG(duration_seconds), 2) as avg_duration_sec,
    ROUND(MIN(duration_seconds), 2) as min_duration_sec,
    ROUND(MAX(duration_seconds), 2) as max_duration_sec,
    ROUND(AVG(records_processed), 0) as avg_records,
    MAX(end_time) as last_run
FROM ETL_RUN_LOG
WHERE status IN ('SUCCESS', 'PARTIAL')
  AND duration_seconds IS NOT NULL
GROUP BY run_type, endpoint_key
ORDER BY run_type, endpoint_key;

COMMENT ON TABLE V_ETL_PERFORMANCE IS 'Shows ETL performance metrics by type and endpoint';

-- ===============================================================================
-- Recent ETL Activity View
-- ===============================================================================
CREATE OR REPLACE VIEW V_RECENT_ETL_ACTIVITY AS
SELECT 
    run_id,
    run_type,
    endpoint_key,
    plant_id,
    issue_revision,
    status,
    duration_seconds,
    records_processed,
    TO_CHAR(start_time, 'MM/DD HH24:MI:SS') as started,
    TO_CHAR(end_time, 'HH24:MI:SS') as ended,
    SUBSTR(notes, 1, 50) as notes_snippet
FROM ETL_RUN_LOG
WHERE start_time > SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY start_time DESC;

COMMENT ON TABLE V_RECENT_ETL_ACTIVITY IS 'Shows ETL activity from the last 24 hours';

-- ===============================================================================
-- System Health Dashboard View
-- ===============================================================================
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
        UNION ALL SELECT 1 FROM VDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM MDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM VSK_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM EDS_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM SC_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM VSM_REFERENCES WHERE is_valid = 'Y'
        UNION ALL SELECT 1 FROM ESK_REFERENCES WHERE is_valid = 'Y'
    )),
    NULL,
    (SELECT COUNT(DISTINCT reference_type) FROM (
        SELECT 'PCS' as reference_type FROM PCS_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'VDS' FROM VDS_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'MDS' FROM MDS_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'PIPE' FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'VSK' FROM VSK_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'EDS' FROM EDS_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'SC' FROM SC_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'VSM' FROM VSM_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
        UNION SELECT 'ESK' FROM ESK_REFERENCES WHERE is_valid = 'Y' AND ROWNUM = 1
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
    (SELECT COUNT(*) FROM ETL_ERROR_LOG WHERE error_timestamp > SYSTIMESTAMP - INTERVAL '24' HOUR),
    NULL,
    NULL
FROM DUAL;

COMMENT ON TABLE V_SYSTEM_HEALTH_DASHBOARD IS 'Overview of system health metrics';

PROMPT
PROMPT ===============================================================================
PROMPT Monitoring Views Created:
PROMPT - V_ETL_SUCCESS_RATE: Shows success rates by ETL type
PROMPT - V_REFERENCE_SUMMARY: Summarizes references by plant/issue
PROMPT - V_ETL_PERFORMANCE: Performance metrics for ETL operations
PROMPT - V_RECENT_ETL_ACTIVITY: Last 24 hours of ETL activity
PROMPT - V_SYSTEM_HEALTH_DASHBOARD: Overall system health overview
PROMPT ===============================================================================
PROMPT