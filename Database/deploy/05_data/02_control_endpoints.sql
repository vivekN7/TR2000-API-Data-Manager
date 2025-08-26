-- ===============================================================================
-- Initial Data: Control Endpoints
-- ===============================================================================
-- Uses MERGE to preserve custom endpoints while ensuring defaults exist
-- ===============================================================================

-- Plants endpoint
MERGE INTO CONTROL_ENDPOINTS tgt
USING (SELECT 'plants' as key FROM dual) src
ON (tgt.endpoint_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (endpoint_key, endpoint_url, endpoint_type, processing_order, 
            parse_package, parse_procedure, upsert_package, upsert_procedure)
    VALUES ('plants', 'plants', 'MASTER', 1, 
            'PKG_PARSE_PLANTS', 'PARSE_PLANTS_JSON', 'PKG_UPSERT_PLANTS', 'UPSERT_PLANTS');

-- Issues endpoint
MERGE INTO CONTROL_ENDPOINTS tgt
USING (SELECT 'issues' as key FROM dual) src
ON (tgt.endpoint_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, 
            processing_order, requires_selection, parse_package, parse_procedure, 
            upsert_package, upsert_procedure)
    VALUES ('issues', 'plants/{plant_id}/issues', 'DETAIL', 'plants', 
            2, 'Y', 'PKG_PARSE_ISSUES', 'PARSE_ISSUES_JSON', 
            'PKG_UPSERT_ISSUES', 'UPSERT_ISSUES');

-- Future endpoints (commented out until implementation)
-- INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, requires_selection)
-- VALUES ('pcs_references', 'issues/{issue_id}/pcs', 'REFERENCE', 'issues', 3, 'Y');

-- INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, requires_selection)
-- VALUES ('vds_references', 'issues/{issue_id}/vds', 'REFERENCE', 'issues', 4, 'Y');

COMMIT;

PROMPT Control endpoints loaded successfully