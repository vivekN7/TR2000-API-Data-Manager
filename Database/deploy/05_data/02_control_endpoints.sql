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

-- Reference endpoints (Task 7)
INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, is_active, requires_selection)
VALUES ('pcs_references', 'plants/{plantid}/issues/rev/{issuerev}/pcs', 'REFERENCE', 'issues', 3, 'Y', 'Y');

INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, is_active, requires_selection)
VALUES ('sc_references', 'plants/{plantid}/issues/rev/{issuerev}/sc', 'REFERENCE', 'issues', 4, 'Y', 'Y');

INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, is_active, requires_selection)
VALUES ('vsm_references', 'plants/{plantid}/issues/rev/{issuerev}/vsm', 'REFERENCE', 'issues', 5, 'Y', 'Y');

INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, is_active, requires_selection)
VALUES ('vds_references', 'plants/{plantid}/issues/rev/{issuerev}/vds', 'REFERENCE', 'issues', 6, 'Y', 'Y');

INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, is_active, requires_selection)
VALUES ('eds_references', 'plants/{plantid}/issues/rev/{issuerev}/eds', 'REFERENCE', 'issues', 7, 'Y', 'Y');

INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, is_active, requires_selection)
VALUES ('mds_references', 'plants/{plantid}/issues/rev/{issuerev}/mds', 'REFERENCE', 'issues', 8, 'Y', 'Y');

INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, is_active, requires_selection)
VALUES ('vsk_references', 'plants/{plantid}/issues/rev/{issuerev}/vsk', 'REFERENCE', 'issues', 9, 'Y', 'Y');

INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, is_active, requires_selection)
VALUES ('esk_references', 'plants/{plantid}/issues/rev/{issuerev}/esk', 'REFERENCE', 'issues', 10, 'Y', 'Y');

INSERT INTO CONTROL_ENDPOINTS (endpoint_key, endpoint_url, endpoint_type, parent_endpoint, processing_order, is_active, requires_selection)
VALUES ('pipe_element_references', 'plants/{plantid}/issues/rev/{issuerev}/pipe-elements', 'REFERENCE', 'issues', 11, 'Y', 'Y');

-- VDS endpoints (Task 9 - Session 18)
-- VDS master list endpoint
MERGE INTO CONTROL_ENDPOINTS tgt
USING (SELECT 'VDS_LIST' as key FROM dual) src
ON (tgt.endpoint_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (endpoint_key, endpoint_url, endpoint_type, processing_order, is_active, 
            requires_selection, parse_package, parse_procedure, upsert_package, upsert_procedure)
    VALUES ('VDS_LIST', '/vds', 'VDS_LIST', 41, 'Y', 'N',
            'PKG_PARSE_VDS', 'PARSE_VDS_LIST', 'PKG_UPSERT_VDS', 'UPSERT_VDS_LIST');

-- VDS details endpoint
MERGE INTO CONTROL_ENDPOINTS tgt
USING (SELECT 'VDS_DETAILS' as key FROM dual) src
ON (tgt.endpoint_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (endpoint_key, endpoint_url, endpoint_type, processing_order, is_active,
            requires_selection, parse_package, parse_procedure, upsert_package, upsert_procedure)
    VALUES ('VDS_DETAILS', '/vds/{vds_name}/rev/{revision}', 'VDS_DETAILS', 42, 'Y', 'N',
            'PKG_PARSE_VDS', 'PARSE_VDS_DETAILS', 'PKG_UPSERT_VDS', 'UPSERT_VDS_DETAILS');

COMMIT;

PROMPT Control endpoints loaded successfully