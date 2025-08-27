-- ===============================================================================
-- Fix PKG_API_CLIENT Specification
-- Date: 2025-08-26
-- Purpose: Remove incorrectly added reference procedures from PKG_API_CLIENT
-- These belong in PKG_API_CLIENT_REFERENCES, not PKG_API_CLIENT
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_api_client AS
    -- Existing functions remain for compatibility
    FUNCTION fetch_plants_json RETURN CLOB;
    FUNCTION fetch_issues_json(p_plant_id VARCHAR2) RETURN CLOB;
    FUNCTION calculate_sha256(p_input CLOB) RETURN VARCHAR2;
    
    -- Enhanced functions with GUID support
    FUNCTION fetch_plants_json_v2(
        p_correlation_id  VARCHAR2 DEFAULT NULL,
        p_idempotency_key VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;
    
    FUNCTION fetch_issues_json_v2(
        p_plant_id        VARCHAR2,
        p_correlation_id  VARCHAR2 DEFAULT NULL,
        p_idempotency_key VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;
    
    -- Main procedures - enhanced with optional GUID parameters
    PROCEDURE refresh_plants_from_api(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL,
        p_idempotency_key IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE refresh_issues_from_api(
        p_plant_id        IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL,
        p_idempotency_key IN VARCHAR2 DEFAULT NULL
    );
    
    PROCEDURE refresh_selected_issues(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );
    
    -- Helper function
    FUNCTION get_base_url RETURN VARCHAR2;
    
    -- NOTE: Reference procedures removed - they belong in PKG_API_CLIENT_REFERENCES
    
END pkg_api_client;
/

-- Recompile the body
ALTER PACKAGE pkg_api_client COMPILE BODY;

-- Check compilation status
DECLARE
    v_status VARCHAR2(20);
BEGIN
    SELECT status INTO v_status
    FROM user_objects
    WHERE object_name = 'PKG_API_CLIENT'
    AND object_type = 'PACKAGE BODY';
    
    IF v_status = 'VALID' THEN
        DBMS_OUTPUT.PUT_LINE('SUCCESS: PKG_API_CLIENT restored and compiled successfully');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ERROR: PKG_API_CLIENT still has compilation errors');
    END IF;
END;
/

PROMPT
PROMPT ===============================================================================
PROMPT PKG_API_CLIENT spec fixed - reference procedures removed
PROMPT Reference procedures are correctly in PKG_API_CLIENT_REFERENCES
PROMPT ===============================================================================