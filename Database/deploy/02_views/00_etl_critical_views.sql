-- ===============================================================================
-- ETL CRITICAL VIEWS - REQUIRED FOR SYSTEM OPERATION
-- ===============================================================================
-- WARNING: These views are used by ETL packages. Dropping or modifying
-- without impact analysis will break the ETL pipeline!
-- 
-- Naming Convention: VETL_* = View ETL (Critical for ETL processes)
-- 
-- These views encapsulate complex business logic that multiple ETL packages
-- depend on. They ensure consistent interpretation of control tables across
-- the entire ETL pipeline.
-- ===============================================================================

-- ===============================================================================
-- VETL_EFFECTIVE_SELECTIONS
-- ===============================================================================
-- Purpose: Determines which plant/issue combinations should be processed by ETL
-- Logic: When specific issue revisions are selected for a plant, they override
--        the plant-level (NULL issue_revision) selection
-- Used By: All ETL packages that need to know what data to load
-- ===============================================================================

CREATE OR REPLACE VIEW VETL_EFFECTIVE_SELECTIONS AS
SELECT 
    -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    -- CRITICAL ETL VIEW - DO NOT DROP WITHOUT IMPACT ANALYSIS
    -- This view is used by ETL packages to determine which issues
    -- to load. Dropping or modifying this view will break:
    -- - Reference data loading processes
    -- - Issue selection logic
    -- - API call optimization
    -- Logic: Specific issue selections override plant-level selections
    -- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    sl.plant_id,
    sl.issue_revision,
    sl.is_active,
    CASE 
        -- If this row is a plant-level selection (NULL issue_revision)
        -- but specific issues exist for this plant, then this row is overridden
        WHEN sl.issue_revision IS NULL 
             AND EXISTS (SELECT 1 FROM SELECTION_LOADER sl2 
                        WHERE sl2.plant_id = sl.plant_id 
                        AND sl2.issue_revision IS NOT NULL 
                        AND sl2.is_active = 'Y')
        THEN 'OVERRIDDEN'
        -- Active specific issue selection
        WHEN sl.issue_revision IS NOT NULL AND sl.is_active = 'Y'
        THEN 'ACTIVE'
        -- Active plant-level selection (no specific issues exist)
        WHEN sl.issue_revision IS NULL AND sl.is_active = 'Y'
        THEN 'ACTIVE'
        -- Inactive selection
        ELSE 'INACTIVE'
    END as effective_status,
    CASE 
        WHEN sl.issue_revision IS NULL THEN 'ALL ISSUES'
        ELSE 'ISSUE ' || sl.issue_revision
    END as selection_scope,
    sl.selected_by,
    sl.selection_date,
    sl.last_etl_run,
    sl.etl_status
FROM SELECTION_LOADER sl;

-- Add database comment for additional documentation
COMMENT ON TABLE VETL_EFFECTIVE_SELECTIONS IS 
'CRITICAL ETL VIEW: Determines which plant/issue combinations to process. Used by all ETL packages. DO NOT DROP! Logic: Specific issue selections override plant-level selections.';

-- Grant necessary permissions (if needed in future)
-- GRANT SELECT ON VETL_EFFECTIVE_SELECTIONS TO etl_reader_role;

PROMPT
PROMPT VETL_EFFECTIVE_SELECTIONS view created
PROMPT WARNING: This is a critical ETL view - do not drop without impact analysis
PROMPT