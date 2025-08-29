-- ===============================================================================
-- Add VDS Endpoints to CONTROL_ENDPOINTS
-- Session 18: VDS Details Implementation
-- Date: 2025-12-30
-- ===============================================================================

-- Add VDS list endpoint (for getting all 44k VDS)
INSERT INTO CONTROL_ENDPOINTS (
    endpoint_id,
    endpoint_key,
    endpoint_url,
    endpoint_type,
    processing_order,
    is_active,
    requires_selection,
    parse_package,
    parse_procedure,
    upsert_package,
    upsert_procedure,
    created_date
) 
SELECT 
    (SELECT NVL(MAX(endpoint_id), 0) + 1 FROM CONTROL_ENDPOINTS),
    'VDS_LIST',
    '/vds',
    'VDS_LIST',
    41,  -- After reference tables
    'Y',
    'N',  -- Does not require selection
    'PKG_PARSE_VDS',
    'PARSE_VDS_LIST',
    'PKG_UPSERT_VDS',
    'UPSERT_VDS_LIST',
    SYSDATE
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM CONTROL_ENDPOINTS WHERE endpoint_key = 'VDS_LIST'
);

-- Add VDS details endpoint (for individual VDS details)
INSERT INTO CONTROL_ENDPOINTS (
    endpoint_id,
    endpoint_key,
    endpoint_url,
    endpoint_type,
    processing_order,
    is_active,
    requires_selection,
    parse_package,
    parse_procedure,
    upsert_package,
    upsert_procedure,
    created_date
) 
SELECT 
    (SELECT NVL(MAX(endpoint_id), 0) + 1 FROM CONTROL_ENDPOINTS),
    'VDS_DETAILS',
    '/vds/{vds_name}/rev/{revision}',
    'VDS_DETAILS',
    42,  -- After VDS list
    'Y',
    'N',  -- Does not require selection
    'PKG_PARSE_VDS',
    'PARSE_VDS_DETAILS',
    'PKG_UPSERT_VDS',
    'UPSERT_VDS_DETAILS',
    SYSDATE
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM CONTROL_ENDPOINTS WHERE endpoint_key = 'VDS_DETAILS'
);

COMMIT;

-- Verify endpoints added
SELECT endpoint_key, endpoint_url, endpoint_type, is_active
FROM CONTROL_ENDPOINTS
WHERE endpoint_key LIKE 'VDS%'
ORDER BY endpoint_key;
/