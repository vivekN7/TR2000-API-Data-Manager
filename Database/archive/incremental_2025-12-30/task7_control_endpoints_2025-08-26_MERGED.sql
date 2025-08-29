-- ===============================================================================
-- Incremental Update: Task 7.4 - Add Reference Endpoints to CONTROL_ENDPOINTS
-- Date: 2025-08-26
-- ===============================================================================
-- This script adds 9 reference endpoint configurations to CONTROL_ENDPOINTS
-- ===============================================================================

SET SERVEROUTPUT ON

PROMPT ===============================================================================
PROMPT Adding Reference Endpoints to CONTROL_ENDPOINTS (Task 7.4)
PROMPT ===============================================================================

DECLARE
    v_count NUMBER;
    v_endpoint_id NUMBER;
BEGIN
    -- Check if reference endpoints already exist
    SELECT COUNT(*) INTO v_count 
    FROM CONTROL_ENDPOINTS 
    WHERE endpoint_key LIKE '%_references';
    
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Reference endpoints already exist: ' || v_count || ' found. Skipping insert.');
    ELSE
        -- Get next ID
        SELECT NVL(MAX(endpoint_id), 0) + 1 INTO v_endpoint_id FROM CONTROL_ENDPOINTS;
        
        DBMS_OUTPUT.PUT_LINE('Starting endpoint_id: ' || v_endpoint_id);
        
        -- Insert PCS references endpoint
        INSERT INTO CONTROL_ENDPOINTS (
            endpoint_id, endpoint_key, endpoint_url, endpoint_type, 
            parent_endpoint, processing_order, is_active, requires_selection,
            parse_package, parse_procedure, upsert_package, upsert_procedure,
            created_date
        ) VALUES (
            v_endpoint_id, 'pcs_references', 
            'plants/{plantid}/issues/rev/{issuerev}/pcs', 
            'REFERENCE', 'issues', 1, 'Y', 'Y',
            'pkg_parse_references', 'parse_pcs_json',
            'pkg_upsert_references', 'upsert_pcs_references',
            SYSDATE
        );
        
        -- Insert SC references endpoint
        INSERT INTO CONTROL_ENDPOINTS (
            endpoint_id, endpoint_key, endpoint_url, endpoint_type, 
            parent_endpoint, processing_order, is_active, requires_selection,
            parse_package, parse_procedure, upsert_package, upsert_procedure,
            created_date
        ) VALUES (
            v_endpoint_id + 1, 'sc_references', 
            'plants/{plantid}/issues/rev/{issuerev}/sc', 
            'REFERENCE', 'issues', 2, 'Y', 'Y',
            'pkg_parse_references', 'parse_sc_json',
            'pkg_upsert_references', 'upsert_sc_references',
            SYSDATE
        );
        
        -- Insert VSM references endpoint
        INSERT INTO CONTROL_ENDPOINTS (
            endpoint_id, endpoint_key, endpoint_url, endpoint_type, 
            parent_endpoint, processing_order, is_active, requires_selection,
            parse_package, parse_procedure, upsert_package, upsert_procedure,
            created_date
        ) VALUES (
            v_endpoint_id + 2, 'vsm_references', 
            'plants/{plantid}/issues/rev/{issuerev}/vsm', 
            'REFERENCE', 'issues', 3, 'Y', 'Y',
            'pkg_parse_references', 'parse_vsm_json',
            'pkg_upsert_references', 'upsert_vsm_references',
            SYSDATE
        );
        
        -- Insert VDS references endpoint
        INSERT INTO CONTROL_ENDPOINTS (
            endpoint_id, endpoint_key, endpoint_url, endpoint_type, 
            parent_endpoint, processing_order, is_active, requires_selection,
            parse_package, parse_procedure, upsert_package, upsert_procedure,
            created_date
        ) VALUES (
            v_endpoint_id + 3, 'vds_references', 
            'plants/{plantid}/issues/rev/{issuerev}/vds', 
            'REFERENCE', 'issues', 4, 'Y', 'Y',
            'pkg_parse_references', 'parse_vds_json',
            'pkg_upsert_references', 'upsert_vds_references',
            SYSDATE
        );
        
        -- Insert EDS references endpoint
        INSERT INTO CONTROL_ENDPOINTS (
            endpoint_id, endpoint_key, endpoint_url, endpoint_type, 
            parent_endpoint, processing_order, is_active, requires_selection,
            parse_package, parse_procedure, upsert_package, upsert_procedure,
            created_date
        ) VALUES (
            v_endpoint_id + 4, 'eds_references', 
            'plants/{plantid}/issues/rev/{issuerev}/eds', 
            'REFERENCE', 'issues', 5, 'Y', 'Y',
            'pkg_parse_references', 'parse_eds_json',
            'pkg_upsert_references', 'upsert_eds_references',
            SYSDATE
        );
        
        -- Insert MDS references endpoint
        INSERT INTO CONTROL_ENDPOINTS (
            endpoint_id, endpoint_key, endpoint_url, endpoint_type, 
            parent_endpoint, processing_order, is_active, requires_selection,
            parse_package, parse_procedure, upsert_package, upsert_procedure,
            created_date
        ) VALUES (
            v_endpoint_id + 5, 'mds_references', 
            'plants/{plantid}/issues/rev/{issuerev}/mds', 
            'REFERENCE', 'issues', 6, 'Y', 'Y',
            'pkg_parse_references', 'parse_mds_json',
            'pkg_upsert_references', 'upsert_mds_references',
            SYSDATE
        );
        
        -- Insert VSK references endpoint
        INSERT INTO CONTROL_ENDPOINTS (
            endpoint_id, endpoint_key, endpoint_url, endpoint_type, 
            parent_endpoint, processing_order, is_active, requires_selection,
            parse_package, parse_procedure, upsert_package, upsert_procedure,
            created_date
        ) VALUES (
            v_endpoint_id + 6, 'vsk_references', 
            'plants/{plantid}/issues/rev/{issuerev}/vsk', 
            'REFERENCE', 'issues', 7, 'Y', 'Y',
            'pkg_parse_references', 'parse_vsk_json',
            'pkg_upsert_references', 'upsert_vsk_references',
            SYSDATE
        );
        
        -- Insert ESK references endpoint
        INSERT INTO CONTROL_ENDPOINTS (
            endpoint_id, endpoint_key, endpoint_url, endpoint_type, 
            parent_endpoint, processing_order, is_active, requires_selection,
            parse_package, parse_procedure, upsert_package, upsert_procedure,
            created_date
        ) VALUES (
            v_endpoint_id + 7, 'esk_references', 
            'plants/{plantid}/issues/rev/{issuerev}/esk', 
            'REFERENCE', 'issues', 8, 'Y', 'Y',
            'pkg_parse_references', 'parse_esk_json',
            'pkg_upsert_references', 'upsert_esk_references',
            SYSDATE
        );
        
        -- Insert Pipe Element references endpoint
        INSERT INTO CONTROL_ENDPOINTS (
            endpoint_id, endpoint_key, endpoint_url, endpoint_type, 
            parent_endpoint, processing_order, is_active, requires_selection,
            parse_package, parse_procedure, upsert_package, upsert_procedure,
            created_date
        ) VALUES (
            v_endpoint_id + 8, 'pipe_element_references', 
            'plants/{plantid}/issues/rev/{issuerev}/pipe-elements', 
            'REFERENCE', 'issues', 9, 'Y', 'Y',
            'pkg_parse_references', 'parse_pipe_element_json',
            'pkg_upsert_references', 'upsert_pipe_element_references',
            SYSDATE
        );
        
        DBMS_OUTPUT.PUT_LINE('Successfully added 9 reference endpoints to CONTROL_ENDPOINTS');
        COMMIT;
    END IF;
END;
/

-- Show the reference endpoints
PROMPT
PROMPT Reference endpoints in CONTROL_ENDPOINTS:
PROMPT =========================================

COLUMN endpoint_key FORMAT A25
COLUMN endpoint_url FORMAT A50
COLUMN endpoint_type FORMAT A12
COLUMN is_active FORMAT A8

SELECT endpoint_key, endpoint_url, endpoint_type, is_active
FROM CONTROL_ENDPOINTS
WHERE endpoint_key LIKE '%_references'
ORDER BY processing_order, endpoint_key;

PROMPT
PROMPT ===============================================================================
PROMPT Task 7.4 Complete: Reference endpoints added to CONTROL_ENDPOINTS
PROMPT ===============================================================================