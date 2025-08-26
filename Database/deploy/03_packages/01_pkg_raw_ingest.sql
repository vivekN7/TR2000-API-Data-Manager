-- ===============================================================================
-- Package: PKG_RAW_INGEST
-- Purpose: Manages RAW_JSON table operations and SHA256 deduplication
-- ===============================================================================

-- Package Specification
CREATE OR REPLACE PACKAGE pkg_raw_ingest AS
    -- ===============================================================================
    -- Package: PKG_RAW_INGEST
    -- Purpose: Manages RAW_JSON table operations and SHA256 deduplication
    -- Author: TR2000 Development Team
    -- Created: 2025-08-24
    --
    -- This package handles the immutable storage layer for API responses:
    -- - Stores all API responses exactly as received
    -- - Implements SHA256 deduplication to prevent reprocessing
    -- - Maintains audit trail of all API calls
    -- - Provides foundation for reprocessing if needed
    -- ===============================================================================

    -- Check if response hash already exists (deduplication)
    FUNCTION is_duplicate_hash(p_hash VARCHAR2) RETURN BOOLEAN;

    -- Insert new API response into RAW_JSON
    PROCEDURE insert_raw_json(
        p_endpoint_key VARCHAR2,
        p_plant_id VARCHAR2 DEFAULT NULL,
        p_issue_revision VARCHAR2 DEFAULT NULL,
        p_api_url VARCHAR2,
        p_response_json CLOB,
        p_response_hash VARCHAR2,
        p_raw_json_id OUT NUMBER
    );

    -- Purge old responses based on retention policy
    PROCEDURE purge_old_responses(
        p_days_to_keep NUMBER DEFAULT 30,
        p_endpoint_key VARCHAR2 DEFAULT NULL
    );

END pkg_raw_ingest;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY pkg_raw_ingest AS

    FUNCTION is_duplicate_hash(p_hash VARCHAR2) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM RAW_JSON
        WHERE response_hash = p_hash;
        
        RETURN (v_count > 0);
    END is_duplicate_hash;

    PROCEDURE insert_raw_json(
        p_endpoint_key VARCHAR2,
        p_plant_id VARCHAR2 DEFAULT NULL,
        p_issue_revision VARCHAR2 DEFAULT NULL,
        p_api_url VARCHAR2,
        p_response_json CLOB,
        p_response_hash VARCHAR2,
        p_raw_json_id OUT NUMBER
    ) IS
    BEGIN
        INSERT INTO RAW_JSON (
            endpoint_key,
            plant_id,
            issue_revision,
            api_url,
            response_json,
            response_hash,
            api_call_timestamp,
            created_date
        ) VALUES (
            p_endpoint_key,
            p_plant_id,
            p_issue_revision,
            p_api_url,
            p_response_json,
            p_response_hash,
            SYSTIMESTAMP,
            SYSDATE
        ) RETURNING raw_json_id INTO p_raw_json_id;
        
        COMMIT;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            -- Hash already exists - this is expected for duplicates
            SELECT raw_json_id INTO p_raw_json_id
            FROM RAW_JSON
            WHERE response_hash = p_response_hash;
    END insert_raw_json;

    PROCEDURE purge_old_responses(
        p_days_to_keep NUMBER DEFAULT 30,
        p_endpoint_key VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        IF p_endpoint_key IS NOT NULL THEN
            DELETE FROM RAW_JSON
            WHERE endpoint_key = p_endpoint_key
            AND created_date < SYSDATE - p_days_to_keep;
        ELSE
            DELETE FROM RAW_JSON
            WHERE created_date < SYSDATE - p_days_to_keep;
        END IF;
        
        COMMIT;
    END purge_old_responses;

END pkg_raw_ingest;
/

SHOW ERRORS

PROMPT PKG_RAW_INGEST created successfully