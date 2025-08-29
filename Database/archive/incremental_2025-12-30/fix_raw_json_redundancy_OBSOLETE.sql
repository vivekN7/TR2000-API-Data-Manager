-- ===============================================================================
-- Fix RAW_JSON Redundancy - Use Views Instead of Duplicate Columns
-- Date: 2025-08-27
-- Purpose: Remove redundant columns and create view for TR2000_UTIL compatibility
-- ===============================================================================

-- First, drop the redundant columns we added
ALTER TABLE RAW_JSON DROP COLUMN endpoint;
ALTER TABLE RAW_JSON DROP COLUMN key_fingerprint;
ALTER TABLE RAW_JSON DROP COLUMN payload;
ALTER TABLE RAW_JSON DROP COLUMN batch_id;

-- Create a view that TR2000_UTIL can use with column name mapping
CREATE OR REPLACE VIEW V_RAW_JSON_FOR_TR2000_UTIL AS
SELECT 
    raw_json_id,
    endpoint_key as endpoint,           -- Map existing column
    api_url,
    response_hash as key_fingerprint,   -- Map existing column  
    response_json as payload,           -- Map existing column
    correlation_id as batch_id,         -- Map existing column
    plant_id,
    issue_revision,
    api_call_timestamp,
    created_date
FROM RAW_JSON;

-- Grant insert on the view to SYSTEM (TR2000_UTIL will insert through this)
GRANT INSERT ON V_RAW_JSON_FOR_TR2000_UTIL TO SYSTEM;

-- Create an INSTEAD OF trigger to handle inserts through the view
CREATE OR REPLACE TRIGGER TRG_V_RAW_JSON_INSERT
INSTEAD OF INSERT ON V_RAW_JSON_FOR_TR2000_UTIL
FOR EACH ROW
BEGIN
    INSERT INTO RAW_JSON (
        endpoint_key,
        api_url,
        response_json,
        response_hash,
        api_call_timestamp,
        correlation_id,
        plant_id,
        issue_revision
    ) VALUES (
        :NEW.endpoint,
        :NEW.api_url,
        :NEW.payload,
        :NEW.key_fingerprint,
        SYSTIMESTAMP,
        :NEW.batch_id,
        :NEW.plant_id,
        :NEW.issue_revision
    );
END;
/

PROMPT RAW_JSON redundancy fixed - using view for compatibility