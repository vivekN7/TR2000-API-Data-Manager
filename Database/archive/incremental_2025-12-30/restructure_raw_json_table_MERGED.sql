-- ===============================================================================
-- Restructure RAW_JSON Table to Match TR2000_UTIL Requirements
-- Date: 2025-08-27
-- Purpose: Align table with DBA's expectations, remove redundancy
-- ===============================================================================

-- First drop the view and trigger we just created
DROP TRIGGER TRG_V_RAW_JSON_INSERT;
DROP VIEW V_RAW_JSON_FOR_TR2000_UTIL;

-- Now restructure RAW_JSON to use TR2000_UTIL's naming conventions
-- Keep the essential columns but rename them to match what TR2000_UTIL expects

-- Step 1: Rename columns to match TR2000_UTIL expectations
ALTER TABLE RAW_JSON RENAME COLUMN endpoint_key TO endpoint;
ALTER TABLE RAW_JSON RENAME COLUMN response_json TO payload;
ALTER TABLE RAW_JSON RENAME COLUMN response_hash TO key_fingerprint;
ALTER TABLE RAW_JSON RENAME COLUMN correlation_id TO batch_id;

-- Step 2: Drop truly redundant columns (API_URL is redundant with endpoint)
ALTER TABLE RAW_JSON DROP COLUMN api_url;

-- Step 3: Keep these columns as they are unique to our needs:
-- plant_id, issue_revision, transaction_guid, request_id, api_call_timestamp, created_date

-- Show final structure
DESCRIBE RAW_JSON;

PROMPT RAW_JSON table restructured to match TR2000_UTIL requirements