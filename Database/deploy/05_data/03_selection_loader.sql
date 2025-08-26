-- ===============================================================================
-- Initial Data: Selection Loader - Test Plant Selections for Development
-- ===============================================================================
-- Uses MERGE to preserve test selections during development
-- This data is temporary for ETL backend testing until APEX UI is ready
-- ===============================================================================

PROMPT Loading test plant selections for development...

-- Test plant selections (JSP2 and GRANE for consistent testing)
MERGE INTO SELECTION_LOADER tgt
USING (
    SELECT 
        'JSP2' as plant_id,
        NULL as issue_revision,
        'Y' as is_active,
        SYSDATE as selection_date,
        'TEST_DATA' as selected_by,
        NULL as last_etl_run,
        'READY' as etl_status,
        'Test plant for development' as notes
    FROM DUAL
    UNION ALL
    SELECT 
        'GRANE' as plant_id,
        NULL as issue_revision,
        'Y' as is_active,
        SYSDATE as selection_date,
        'TEST_DATA' as selected_by,
        NULL as last_etl_run,
        'READY' as etl_status,
        'Test plant for development' as notes
    FROM DUAL
) src
ON (tgt.plant_id = src.plant_id AND tgt.issue_revision IS NULL)
WHEN NOT MATCHED THEN
    INSERT (plant_id, issue_revision, is_active, selection_date, selected_by, 
            last_etl_run, etl_status, notes)
    VALUES (src.plant_id, src.issue_revision, src.is_active, src.selection_date, 
            src.selected_by, src.last_etl_run, src.etl_status, src.notes)
WHEN MATCHED THEN
    -- Keep existing data, just update notes to indicate it's test data
    UPDATE SET notes = 'Test plant for development (preserved)';

-- Test issue selections for JSP2 (a few sample issues)
MERGE INTO SELECTION_LOADER tgt
USING (
    SELECT 
        'JSP2' as plant_id,
        '2KJE-124-01' as issue_revision,
        'Y' as is_active,
        SYSDATE as selection_date,
        'TEST_DATA' as selected_by,
        NULL as last_etl_run,
        'READY' as etl_status,
        'Test issue for development' as notes
    FROM DUAL
    UNION ALL
    SELECT 
        'JSP2' as plant_id,
        '2KJE-124-02' as issue_revision,
        'Y' as is_active,
        SYSDATE as selection_date,
        'TEST_DATA' as selected_by,
        NULL as last_etl_run,
        'READY' as etl_status,
        'Test issue for development' as notes
    FROM DUAL
) src
ON (tgt.plant_id = src.plant_id AND NVL(tgt.issue_revision, 'NULL') = NVL(src.issue_revision, 'NULL'))
WHEN NOT MATCHED THEN
    INSERT (plant_id, issue_revision, is_active, selection_date, selected_by, 
            last_etl_run, etl_status, notes)
    VALUES (src.plant_id, src.issue_revision, src.is_active, src.selection_date, 
            src.selected_by, src.last_etl_run, src.etl_status, src.notes)
WHEN MATCHED THEN
    -- Keep existing data
    UPDATE SET notes = 'Test issue for development (preserved)';

-- Test issue selections for GRANE
MERGE INTO SELECTION_LOADER tgt
USING (
    SELECT 
        'GRANE' as plant_id,
        'GRA-34-01' as issue_revision,
        'Y' as is_active,
        SYSDATE as selection_date,
        'TEST_DATA' as selected_by,
        NULL as last_etl_run,
        'READY' as etl_status,
        'Test issue for development' as notes
    FROM DUAL
) src
ON (tgt.plant_id = src.plant_id AND NVL(tgt.issue_revision, 'NULL') = NVL(src.issue_revision, 'NULL'))
WHEN NOT MATCHED THEN
    INSERT (plant_id, issue_revision, is_active, selection_date, selected_by, 
            last_etl_run, etl_status, notes)
    VALUES (src.plant_id, src.issue_revision, src.is_active, src.selection_date, 
            src.selected_by, src.last_etl_run, src.etl_status, src.notes)
WHEN MATCHED THEN
    -- Keep existing data
    UPDATE SET notes = 'Test issue for development (preserved)';

COMMIT;

PROMPT Test selections loaded/preserved for JSP2 and GRANE

-- Show what's selected
PROMPT
PROMPT Current test selections:
SELECT plant_id, issue_revision, is_active, selected_by 
FROM SELECTION_LOADER 
WHERE is_active = 'Y'
ORDER BY plant_id, issue_revision;