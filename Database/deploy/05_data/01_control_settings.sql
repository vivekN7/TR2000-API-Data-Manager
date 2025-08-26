-- ===============================================================================
-- Initial Data: Control Settings
-- ===============================================================================
-- Uses MERGE to preserve custom settings while ensuring defaults exist
-- ===============================================================================

-- API Base URL
MERGE INTO CONTROL_SETTINGS tgt
USING (SELECT 'API_BASE_URL' as key FROM dual) src
ON (tgt.setting_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (setting_key, setting_value, setting_type, description)
    VALUES ('API_BASE_URL', 'https://equinor.pipespec-api.presight.com/', 'URL', 'Base URL for TR2000 API');

-- API Timeout
MERGE INTO CONTROL_SETTINGS tgt
USING (SELECT 'API_TIMEOUT_SECONDS' as key FROM dual) src
ON (tgt.setting_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (setting_key, setting_value, setting_type, description)
    VALUES ('API_TIMEOUT_SECONDS', '60', 'NUMBER', 'Timeout for API calls in seconds');

-- Max Plants Per Run
MERGE INTO CONTROL_SETTINGS tgt
USING (SELECT 'MAX_PLANTS_PER_RUN' as key FROM dual) src
ON (tgt.setting_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (setting_key, setting_value, setting_type, description)
    VALUES ('MAX_PLANTS_PER_RUN', '10', 'NUMBER', 'Maximum plants to process per ETL run');

-- Raw JSON Retention
MERGE INTO CONTROL_SETTINGS tgt
USING (SELECT 'RAW_JSON_RETENTION_DAYS' as key FROM dual) src
ON (tgt.setting_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (setting_key, setting_value, setting_type, description)
    VALUES ('RAW_JSON_RETENTION_DAYS', '30', 'NUMBER', 'Days to retain raw JSON responses');

-- ETL Log Retention
MERGE INTO CONTROL_SETTINGS tgt
USING (SELECT 'ETL_LOG_RETENTION_DAYS' as key FROM dual) src
ON (tgt.setting_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (setting_key, setting_value, setting_type, description)
    VALUES ('ETL_LOG_RETENTION_DAYS', '90', 'NUMBER', 'Days to retain ETL logs');

COMMIT;

PROMPT Control settings loaded successfully