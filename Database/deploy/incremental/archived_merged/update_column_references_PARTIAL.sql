-- ===============================================================================
-- Update All Package Bodies to Use New RAW_JSON Column Names
-- Date: 2025-08-27
-- Purpose: Update packages to use renamed columns
-- ===============================================================================

-- PKG_RAW_INGEST changes
CREATE OR REPLACE PACKAGE BODY pkg_raw_ingest AS
    FUNCTION is_duplicate_hash(p_hash VARCHAR2) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM RAW_JSON
        WHERE key_fingerprint = p_hash;  -- Changed from response_hash
        
        RETURN v_count > 0;
    END is_duplicate_hash;
    
    PROCEDURE refresh_all_selected_issues IS
        v_correlation_id VARCHAR2(36);
    BEGIN
        v_correlation_id := PKG_GUID_UTILS.create_correlation_id();
        PKG_API_CLIENT.refresh_selected_issues(
            p_status => v_correlation_id,
            p_message => v_correlation_id,
            p_correlation_id => v_correlation_id
        );
    END refresh_all_selected_issues;
END pkg_raw_ingest;
/

-- Update PKG_API_CLIENT to use new column names
-- This requires finding and replacing in the package body:
-- endpoint_key -> endpoint
-- response_json -> payload  
-- response_hash -> key_fingerprint
-- correlation_id -> batch_id (in RAW_JSON context only)

PROMPT Column reference updates will need to be done in individual package files
PROMPT The following packages need updates:
PROMPT - PKG_API_CLIENT
PROMPT - PKG_PARSE_PLANTS  
PROMPT - PKG_PARSE_ISSUES
PROMPT - PKG_PARSE_REFERENCES
PROMPT - PKG_ETL_OPERATIONS
PROMPT - PKG_API_CLIENT_REFERENCES