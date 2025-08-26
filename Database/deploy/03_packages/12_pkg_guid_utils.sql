-- ===============================================================================
-- Package: PKG_GUID_UTILS
-- Purpose: GUID operations and API transaction tracking utilities
-- Date: 2025-08-26
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

PROMPT PKG_GUID_UTILS package created successfully