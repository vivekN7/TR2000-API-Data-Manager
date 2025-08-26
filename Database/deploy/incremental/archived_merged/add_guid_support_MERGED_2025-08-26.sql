-- ===============================================================================
-- GUID Enhancement for TR2000 ETL System
-- Purpose: Add GUID support for future REST API interactions
-- Date: 2025-08-25
-- ===============================================================================

-- ===============================================================================
-- 1. Add GUID columns to existing tables
-- ===============================================================================

-- Add GUIDs to PLANTS table
ALTER TABLE PLANTS ADD (
    plant_guid     RAW(16) DEFAULT SYS_GUID(),
    external_guid  VARCHAR2(36),  -- If external system provides their GUID
    api_sync_guid  VARCHAR2(36)   -- For tracking API synchronization
);

-- Create unique index on GUID
CREATE UNIQUE INDEX UK_PLANTS_GUID ON PLANTS(plant_guid);

-- Add GUIDs to ISSUES table  
ALTER TABLE ISSUES ADD (
    issue_guid     RAW(16) DEFAULT SYS_GUID(),
    external_guid  VARCHAR2(36),
    api_sync_guid  VARCHAR2(36)
);

CREATE UNIQUE INDEX UK_ISSUES_GUID ON ISSUES(issue_guid);

-- Add GUIDs to RAW_JSON for API correlation
ALTER TABLE RAW_JSON ADD (
    transaction_guid  RAW(16) DEFAULT SYS_GUID(),
    correlation_id    VARCHAR2(36),  -- To link related API calls
    request_id        VARCHAR2(36)   -- From API request headers
);

-- ===============================================================================
-- 2. Create API Transaction Tracking Tables
-- ===============================================================================

CREATE TABLE API_TRANSACTIONS (
    transaction_guid    RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    correlation_id      VARCHAR2(36) NOT NULL,  -- Links related operations
    idempotency_key     VARCHAR2(36),           -- Prevents duplicate operations
    operation_type      VARCHAR2(50) NOT NULL,  -- 'FETCH_PLANTS', 'UPDATE_ISSUE', etc.
    entity_type         VARCHAR2(50),           -- 'PLANT', 'ISSUE', etc.
    entity_id           VARCHAR2(100),          -- Business key
    entity_guid         RAW(16),                -- Internal GUID reference
    request_method      VARCHAR2(10),           -- GET, POST, PUT, DELETE
    request_url         VARCHAR2(500),
    request_headers     CLOB,                   -- JSON of headers
    request_body        CLOB,                   -- Request payload
    response_code       NUMBER,
    response_headers    CLOB,                   -- JSON of response headers
    response_body       CLOB,                   -- Response payload
    started_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    completed_at        TIMESTAMP,
    duration_ms         NUMBER,
    status              VARCHAR2(20) DEFAULT 'PENDING',  -- PENDING, SUCCESS, FAILED
    error_message       VARCHAR2(4000),
    created_by          VARCHAR2(50) DEFAULT USER,
    CONSTRAINT CHK_API_STATUS CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'TIMEOUT'))
);

-- Index for quick lookups
CREATE INDEX IDX_API_TRANS_CORRELATION ON API_TRANSACTIONS(correlation_id);
CREATE INDEX IDX_API_TRANS_IDEMPOTENCY ON API_TRANSACTIONS(idempotency_key);
CREATE INDEX IDX_API_TRANS_STATUS ON API_TRANSACTIONS(status, started_at);

-- Prevent duplicate operations
CREATE UNIQUE INDEX UK_API_IDEMPOTENCY ON API_TRANSACTIONS(
    CASE WHEN idempotency_key IS NOT NULL THEN idempotency_key END
);

-- ===============================================================================
-- 3. External System Reference Tracking
-- ===============================================================================

CREATE TABLE EXTERNAL_SYSTEM_REFS (
    ref_guid           RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    internal_guid      RAW(16) NOT NULL,        -- Our GUID (plant_guid, issue_guid)
    entity_type        VARCHAR2(50) NOT NULL,   -- 'PLANT', 'ISSUE', etc.
    external_system    VARCHAR2(50) NOT NULL,   -- 'SAP', 'MAXIMO', 'TEAMS', etc.
    external_id        VARCHAR2(100),           -- Their ID for our record
    external_guid      VARCHAR2(36),            -- Their GUID if they use one
    external_url       VARCHAR2(500),           -- Direct link to record in their system
    last_pushed_at     TIMESTAMP,               -- When we sent data to them
    last_pulled_at     TIMESTAMP,               -- When we got data from them
    sync_status        VARCHAR2(20) DEFAULT 'PENDING',
    sync_error         VARCHAR2(4000),
    metadata           CLOB,                    -- JSON for additional fields
    created_date       DATE DEFAULT SYSDATE,
    modified_date      DATE DEFAULT SYSDATE,
    CONSTRAINT CHK_SYNC_STATUS CHECK (sync_status IN ('PENDING', 'SYNCED', 'ERROR', 'CONFLICT'))
);

CREATE INDEX IDX_EXT_REF_INTERNAL ON EXTERNAL_SYSTEM_REFS(internal_guid, entity_type);
CREATE INDEX IDX_EXT_REF_EXTERNAL ON EXTERNAL_SYSTEM_REFS(external_system, external_id);

-- ===============================================================================
-- 4. Package for GUID Operations
-- ===============================================================================

CREATE OR REPLACE PACKAGE PKG_GUID_UTILS AS
    
    -- Convert RAW(16) GUID to standard VARCHAR2(36) format with hyphens
    FUNCTION raw_to_guid(p_raw RAW) RETURN VARCHAR2;
    
    -- Convert VARCHAR2(36) GUID to RAW(16) for storage
    FUNCTION guid_to_raw(p_guid VARCHAR2) RETURN RAW;
    
    -- Generate a new GUID in VARCHAR2(36) format
    FUNCTION generate_guid RETURN VARCHAR2;
    
    -- Create correlation ID for related operations
    FUNCTION create_correlation_id RETURN VARCHAR2;
    
    -- Check if operation already exists (idempotency)
    FUNCTION is_duplicate_operation(
        p_idempotency_key VARCHAR2
    ) RETURN BOOLEAN;
    
    -- Log API transaction
    PROCEDURE log_api_transaction(
        p_correlation_id   VARCHAR2,
        p_operation_type   VARCHAR2,
        p_request_url      VARCHAR2,
        p_request_method   VARCHAR2,
        p_request_body     CLOB DEFAULT NULL,
        p_idempotency_key  VARCHAR2 DEFAULT NULL
    );
    
    -- Update transaction with response
    PROCEDURE update_api_response(
        p_correlation_id  VARCHAR2,
        p_response_code   NUMBER,
        p_response_body   CLOB,
        p_status          VARCHAR2,
        p_error_message   VARCHAR2 DEFAULT NULL
    );

END PKG_GUID_UTILS;
/

CREATE OR REPLACE PACKAGE BODY PKG_GUID_UTILS AS
    
    FUNCTION raw_to_guid(p_raw RAW) RETURN VARCHAR2 IS
        v_hex VARCHAR2(32);
    BEGIN
        v_hex := RAWTOHEX(p_raw);
        -- Format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
        RETURN LOWER(
            SUBSTR(v_hex, 1, 8) || '-' ||
            SUBSTR(v_hex, 9, 4) || '-' ||
            SUBSTR(v_hex, 13, 4) || '-' ||
            SUBSTR(v_hex, 17, 4) || '-' ||
            SUBSTR(v_hex, 21, 12)
        );
    END raw_to_guid;
    
    FUNCTION guid_to_raw(p_guid VARCHAR2) RETURN RAW IS
        v_clean VARCHAR2(32);
    BEGIN
        -- Remove hyphens and convert to RAW
        v_clean := REPLACE(UPPER(p_guid), '-', '');
        RETURN HEXTORAW(v_clean);
    END guid_to_raw;
    
    FUNCTION generate_guid RETURN VARCHAR2 IS
    BEGIN
        RETURN raw_to_guid(SYS_GUID());
    END generate_guid;
    
    FUNCTION create_correlation_id RETURN VARCHAR2 IS
    BEGIN
        RETURN generate_guid();
    END create_correlation_id;
    
    FUNCTION is_duplicate_operation(
        p_idempotency_key VARCHAR2
    ) RETURN BOOLEAN IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM API_TRANSACTIONS
        WHERE idempotency_key = p_idempotency_key
        AND status = 'SUCCESS';
        
        RETURN (v_count > 0);
    END is_duplicate_operation;
    
    PROCEDURE log_api_transaction(
        p_correlation_id   VARCHAR2,
        p_operation_type   VARCHAR2,
        p_request_url      VARCHAR2,
        p_request_method   VARCHAR2,
        p_request_body     CLOB DEFAULT NULL,
        p_idempotency_key  VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO API_TRANSACTIONS (
            correlation_id,
            idempotency_key,
            operation_type,
            request_method,
            request_url,
            request_body,
            status
        ) VALUES (
            p_correlation_id,
            p_idempotency_key,
            p_operation_type,
            p_request_method,
            p_request_url,
            p_request_body,
            'PENDING'
        );
        COMMIT;
    END log_api_transaction;
    
    PROCEDURE update_api_response(
        p_correlation_id  VARCHAR2,
        p_response_code   NUMBER,
        p_response_body   CLOB,
        p_status          VARCHAR2,
        p_error_message   VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE API_TRANSACTIONS
        SET response_code = p_response_code,
            response_body = p_response_body,
            status = p_status,
            error_message = p_error_message,
            completed_at = SYSTIMESTAMP,
            duration_ms = EXTRACT(SECOND FROM (SYSTIMESTAMP - started_at)) * 1000
        WHERE correlation_id = p_correlation_id
        AND status = 'PENDING';
        COMMIT;
    END update_api_response;

END PKG_GUID_UTILS;
/

-- ===============================================================================
-- 5. Enhance pkg_api_client to use GUIDs
-- ===============================================================================

-- Example of how to modify your API calls to use GUIDs:
/*
CREATE OR REPLACE PACKAGE BODY pkg_api_client AS
    
    PROCEDURE refresh_plants_from_api(
        p_status OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        l_correlation_id VARCHAR2(36);
        l_idempotency_key VARCHAR2(36);
        l_json CLOB;
        -- ... other variables ...
    BEGIN
        -- Generate correlation ID for this operation
        l_correlation_id := PKG_GUID_UTILS.create_correlation_id();
        
        -- Generate idempotency key (or receive from caller)
        l_idempotency_key := PKG_GUID_UTILS.generate_guid();
        
        -- Check for duplicate operation
        IF PKG_GUID_UTILS.is_duplicate_operation(l_idempotency_key) THEN
            p_status := 'SKIPPED';
            p_message := 'Operation already completed with key: ' || l_idempotency_key;
            RETURN;
        END IF;
        
        -- Log the API call
        PKG_GUID_UTILS.log_api_transaction(
            p_correlation_id => l_correlation_id,
            p_operation_type => 'FETCH_PLANTS',
            p_request_url => get_base_url() || '/plants',
            p_request_method => 'GET',
            p_idempotency_key => l_idempotency_key
        );
        
        BEGIN
            -- Make the API call (existing code)
            l_json := fetch_plants_json();
            
            -- Update with success
            PKG_GUID_UTILS.update_api_response(
                p_correlation_id => l_correlation_id,
                p_response_code => 200,
                p_response_body => l_json,
                p_status => 'SUCCESS'
            );
            
            -- Continue with existing processing...
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Log the failure
                PKG_GUID_UTILS.update_api_response(
                    p_correlation_id => l_correlation_id,
                    p_response_code => 500,
                    p_response_body => NULL,
                    p_status => 'FAILED',
                    p_error_message => SQLERRM
                );
                RAISE;
        END;
    END refresh_plants_from_api;
    
END pkg_api_client;
*/

-- ===============================================================================
-- 6. Sample REST API Endpoint (using ORDS)
-- ===============================================================================

-- This shows how TR2000 could expose its own REST API:
/*
BEGIN
    ORDS.define_module(
        p_module_name    => 'tr2000.api.v1',
        p_base_path      => '/tr2000/api/v1/'
    );
    
    ORDS.define_template(
        p_module_name    => 'tr2000.api.v1',
        p_pattern        => 'plants/:guid'
    );
    
    ORDS.define_handler(
        p_module_name    => 'tr2000.api.v1',
        p_pattern        => 'plants/:guid',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_plsql,
        p_source         => '
        DECLARE
            l_plant_guid RAW(16);
            l_response CLOB;
        BEGIN
            -- Convert string GUID to RAW
            l_plant_guid := PKG_GUID_UTILS.guid_to_raw(:guid);
            
            -- Build JSON response
            SELECT JSON_OBJECT(
                ''guid'' VALUE PKG_GUID_UTILS.raw_to_guid(plant_guid),
                ''plant_id'' VALUE plant_id,
                ''short_description'' VALUE short_description,
                ''operator'' VALUE operator,
                ''created_date'' VALUE created_date,
                ''_links'' VALUE JSON_OBJECT(
                    ''self'' VALUE ''/tr2000/api/v1/plants/'' || :guid,
                    ''issues'' VALUE ''/tr2000/api/v1/plants/'' || :guid || ''/issues''
                )
            )
            INTO l_response
            FROM PLANTS
            WHERE plant_guid = l_plant_guid
            AND is_valid = ''Y'';
            
            -- Set response headers
            OWA_UTIL.mime_header(''application/json'', FALSE);
            HTP.p(''X-Correlation-Id: '' || PKG_GUID_UTILS.generate_guid());
            OWA_UTIL.http_header_close;
            
            -- Return JSON
            HTP.p(l_response);
        END;'
    );
END;
/
*/

-- ===============================================================================
-- 7. Add Comments
-- ===============================================================================

COMMENT ON COLUMN PLANTS.plant_guid IS 'Globally unique identifier for internal use and API references';
COMMENT ON COLUMN PLANTS.external_guid IS 'GUID provided by external systems for this plant';
COMMENT ON COLUMN PLANTS.api_sync_guid IS 'GUID for tracking API synchronization state';

COMMENT ON COLUMN ISSUES.issue_guid IS 'Globally unique identifier for internal use and API references';
COMMENT ON COLUMN ISSUES.external_guid IS 'GUID provided by external systems for this issue';
COMMENT ON COLUMN ISSUES.api_sync_guid IS 'GUID for tracking API synchronization state';

COMMENT ON TABLE API_TRANSACTIONS IS 'Comprehensive audit trail for all API interactions with GUID correlation';
COMMENT ON TABLE EXTERNAL_SYSTEM_REFS IS 'Maps internal GUIDs to external system identifiers';

PROMPT
PROMPT ===============================================================================
PROMPT GUID Enhancement Complete!
PROMPT ===============================================================================
PROMPT 
PROMPT Benefits added:
PROMPT 1. Unique GUIDs for all entities (plants, issues)
PROMPT 2. API transaction tracking with correlation IDs
PROMPT 3. Idempotency support to prevent duplicate operations
PROMPT 4. External system reference mapping
PROMPT 5. Utility package for GUID operations
PROMPT 
PROMPT Next steps:
PROMPT 1. Run this script to add GUID support
PROMPT 2. Backfill GUIDs for existing records (automatic with DEFAULT)
PROMPT 3. Update pkg_api_client to use correlation IDs
PROMPT 4. Consider exposing REST endpoints using ORDS
PROMPT ===============================================================================