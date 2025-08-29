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

-- PCS Loading Mode (OFFICIAL_ONLY reduces API calls from 2,172 to 396)
MERGE INTO CONTROL_SETTINGS tgt
USING (SELECT 'PCS_LOADING_MODE' as key FROM dual) src
ON (tgt.setting_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (setting_key, setting_value, setting_type, description)
    VALUES ('PCS_LOADING_MODE', 'OFFICIAL_ONLY', 'STRING', 
            'Controls PCS detail loading: OFFICIAL_ONLY (default - only revisions in PCS_REFERENCES) or ALL_REVISIONS (all from PCS_LIST)');

-- Reference Loading Mode
MERGE INTO CONTROL_SETTINGS tgt
USING (SELECT 'REFERENCE_LOADING_MODE' as key FROM dual) src
ON (tgt.setting_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (setting_key, setting_value, setting_type, description)
    VALUES ('REFERENCE_LOADING_MODE', 'OFFICIAL_ONLY', 'STRING',
            'Controls reference detail loading: OFFICIAL_ONLY (default - only official revisions) or ALL_REVISIONS');

-- VDS Loading Mode (Session 18)
MERGE INTO CONTROL_SETTINGS tgt
USING (SELECT 'VDS_LOADING_MODE' as key FROM dual) src
ON (tgt.setting_key = src.key)
WHEN NOT MATCHED THEN
    INSERT (setting_key, setting_value, setting_type, description)
    VALUES ('VDS_LOADING_MODE', 'OFFICIAL_ONLY', 'STRING',
            'Controls VDS detail loading: OFFICIAL_ONLY (default - only official revisions) or ALL_REVISIONS');

COMMIT;

PROMPT Control settings loaded successfully