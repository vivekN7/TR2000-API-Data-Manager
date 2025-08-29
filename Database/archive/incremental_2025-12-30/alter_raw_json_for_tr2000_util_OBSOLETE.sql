-- ===============================================================================
-- Alter RAW_JSON Table to Support TR2000_UTIL Package
-- Date: 2025-08-27
-- Purpose: Add columns expected by DBA's tr2000_util package
-- ===============================================================================

-- Add missing columns that tr2000_util expects
ALTER TABLE RAW_JSON ADD (
    endpoint        VARCHAR2(500),
    key_fingerprint VARCHAR2(64),
    payload         CLOB,
    batch_id        VARCHAR2(100)
);

COMMENT ON COLUMN RAW_JSON.endpoint IS 'API endpoint for tr2000_util compatibility';
COMMENT ON COLUMN RAW_JSON.key_fingerprint IS 'Hash key for tr2000_util compatibility';
COMMENT ON COLUMN RAW_JSON.payload IS 'Response payload for tr2000_util compatibility';
COMMENT ON COLUMN RAW_JSON.batch_id IS 'Batch identifier for tr2000_util compatibility';

PROMPT RAW_JSON table updated for TR2000_UTIL compatibility