-- ===============================================================================
-- PKG_API_CLIENT_REFERENCES - API Client for Reference Data
-- Date: 2025-08-26
-- Purpose: Fetch reference data from API endpoints
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_api_client_references AS

    -- Fetch reference JSON for a specific type
    FUNCTION fetch_reference_json(
        p_plant_id       VARCHAR2,
        p_issue_rev      VARCHAR2,
        p_reference_type VARCHAR2,
        p_correlation_id VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

    -- Refresh references for a specific issue and type
    PROCEDURE refresh_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_reference_type  IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );

    -- Refresh ALL reference types for an issue
    PROCEDURE refresh_all_issue_references(
        p_plant_id        IN VARCHAR2,
        p_issue_rev       IN VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL
    );

END pkg_api_client_references;
/

-- Package body would be too long to include here, but contains the implementation
-- using APEX_WEB_SERVICE for API calls