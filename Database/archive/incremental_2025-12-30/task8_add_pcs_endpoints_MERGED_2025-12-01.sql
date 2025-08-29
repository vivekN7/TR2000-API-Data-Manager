-- ===============================================================================
-- Add PCS Detail Endpoints to CONTROL_ENDPOINTS
-- Date: 2025-08-28
-- Purpose: Configure endpoints for PCS detail data retrieval (Task 8)
-- ===============================================================================

-- Add PCS detail endpoints
INSERT INTO CONTROL_ENDPOINTS (
    endpoint_id, endpoint_key, endpoint_url, endpoint_type, is_active, processing_order,
    parse_package, parse_procedure, upsert_package, upsert_procedure
)
SELECT 301, 'PCS_HEADER_PROPERTIES', 'plants/{plantid}/pcs/{pcsname}/rev/{revision}', 'PCS_DETAIL', 'Y', 301,
       'PKG_PARSE_PCS_DETAILS', 'parse_header_properties', 'PKG_UPSERT_PCS_DETAILS', 'upsert_header_properties'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM CONTROL_ENDPOINTS WHERE endpoint_key = 'PCS_HEADER_PROPERTIES');

INSERT INTO CONTROL_ENDPOINTS (
    endpoint_id, endpoint_key, endpoint_url, endpoint_type, is_active, processing_order,
    parse_package, parse_procedure, upsert_package, upsert_procedure
)
SELECT 302, 'PCS_TEMP_PRESSURES', 'plants/{plantid}/pcs/{pcsname}/rev/{revision}/temp-pressures', 'PCS_DETAIL', 'Y', 302,
       'PKG_PARSE_PCS_DETAILS', 'parse_temp_pressures', 'PKG_UPSERT_PCS_DETAILS', 'upsert_temp_pressures'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM CONTROL_ENDPOINTS WHERE endpoint_key = 'PCS_TEMP_PRESSURES');

INSERT INTO CONTROL_ENDPOINTS (
    endpoint_id, endpoint_key, endpoint_url, endpoint_type, is_active, processing_order,
    parse_package, parse_procedure, upsert_package, upsert_procedure
)
SELECT 303, 'PCS_PIPE_SIZES', 'plants/{plantid}/pcs/{pcsname}/rev/{revision}/pipe-sizes', 'PCS_DETAIL', 'Y', 303,
       'PKG_PARSE_PCS_DETAILS', 'parse_pipe_sizes', 'PKG_UPSERT_PCS_DETAILS', 'upsert_pipe_sizes'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM CONTROL_ENDPOINTS WHERE endpoint_key = 'PCS_PIPE_SIZES');

INSERT INTO CONTROL_ENDPOINTS (
    endpoint_id, endpoint_key, endpoint_url, endpoint_type, is_active, processing_order,
    parse_package, parse_procedure, upsert_package, upsert_procedure
)
SELECT 304, 'PCS_PIPE_ELEMENTS', 'plants/{plantid}/pcs/{pcsname}/rev/{revision}/pipe-elements', 'PCS_DETAIL', 'Y', 304,
       'PKG_PARSE_PCS_DETAILS', 'parse_pipe_elements', 'PKG_UPSERT_PCS_DETAILS', 'upsert_pipe_elements'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM CONTROL_ENDPOINTS WHERE endpoint_key = 'PCS_PIPE_ELEMENTS');

INSERT INTO CONTROL_ENDPOINTS (
    endpoint_id, endpoint_key, endpoint_url, endpoint_type, is_active, processing_order,
    parse_package, parse_procedure, upsert_package, upsert_procedure
)
SELECT 305, 'PCS_VALVE_ELEMENTS', 'plants/{plantid}/pcs/{pcsname}/rev/{revision}/valve-elements', 'PCS_DETAIL', 'Y', 305,
       'PKG_PARSE_PCS_DETAILS', 'parse_valve_elements', 'PKG_UPSERT_PCS_DETAILS', 'upsert_valve_elements'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM CONTROL_ENDPOINTS WHERE endpoint_key = 'PCS_VALVE_ELEMENTS');

INSERT INTO CONTROL_ENDPOINTS (
    endpoint_id, endpoint_key, endpoint_url, endpoint_type, is_active, processing_order,
    parse_package, parse_procedure, upsert_package, upsert_procedure
)
SELECT 306, 'PCS_EMBEDDED_NOTES', 'plants/{plantid}/pcs/{pcsname}/rev/{revision}/embedded-notes', 'PCS_DETAIL', 'Y', 306,
       'PKG_PARSE_PCS_DETAILS', 'parse_embedded_notes', 'PKG_UPSERT_PCS_DETAILS', 'upsert_embedded_notes'
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM CONTROL_ENDPOINTS WHERE endpoint_key = 'PCS_EMBEDDED_NOTES');

COMMIT;

-- Display the added endpoints
SELECT endpoint_id, endpoint_key, endpoint_url, endpoint_type, is_active
FROM CONTROL_ENDPOINTS
WHERE endpoint_type = 'PCS_DETAIL'
ORDER BY processing_order;