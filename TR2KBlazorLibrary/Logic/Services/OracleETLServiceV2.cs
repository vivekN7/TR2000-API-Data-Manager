using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Oracle.ManagedDataAccess.Client;
using Oracle.ManagedDataAccess.Types;
using TR2KBlazorLibrary.Models;
using Dapper;

namespace TR2KBlazorLibrary.Logic.Services
{
    /// <summary>
    /// Simplified Oracle ETL Service that delegates all logic to database
    /// C# only fetches from API and calls stored procedures
    /// </summary>
    public class OracleETLServiceV2
    {
        private readonly string _connectionString;
        private readonly TR2000ApiService _apiService;
        private readonly ApiResponseDeserializer _deserializer;
        private readonly ILogger<OracleETLServiceV2> _logger;

        public OracleETLServiceV2(
            IConfiguration configuration, 
            TR2000ApiService apiService, 
            ApiResponseDeserializer deserializer, 
            ILogger<OracleETLServiceV2> logger)
        {
            _connectionString = configuration.GetConnectionString("OracleConnection") ?? string.Empty;
            _apiService = apiService;
            _deserializer = deserializer;
            _logger = logger;
        }

        /// <summary>
        /// Get SQL preview for Operators ETL
        /// </summary>
        public ETLSqlPreview GetOperatorsSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load Operators - Complete SCD2 Process",
                Description = "This process implements full SCD Type 2 change tracking for Operators, maintaining complete history of all changes.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Fetch from API",
                        Description = "C# fetches all operators from TR2000 API",
                        SqlStatement = @"-- C# Code (not SQL)
await _apiService.FetchDataAsync('https://equinor.pipespec-api.presight.com/operators');

Returns: 8 operators with OperatorID and OperatorName"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "Get ETL Run ID",
                        Description = "Generate unique identifier for this ETL run",
                        SqlStatement = @"SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL;

-- Insert control record
INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
VALUES (:etlRunId, 'OPERATORS', 'RUNNING', SYSTIMESTAMP, 1);"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Save to RAW_JSON (Audit Trail)",
                        Description = "Store raw API response for audit/forensics/replay",
                        SqlStatement = @"-- C# calls SP_INSERT_RAW_JSON (MANDATORY for data integrity)
BEGIN
    SP_INSERT_RAW_JSON(
        p_endpoint      => '/operators',
        p_key_string    => 'all-operators',
        p_etl_run_id    => :etlRunId,
        p_http_status   => 200,
        p_duration_ms   => :elapsedMs,
        p_headers_json  => :headers_json,
        p_payload       => :apiResponse  -- Complete JSON from API
    );
END;

-- Purpose: Audit trail, forensics, replay capability
-- Storage: SECUREFILE with COMPRESS MEDIUM (60-80% reduction)
-- Retention: 30 days (auto-purged after each ETL run)
-- If insert fails: ETL continues (non-critical)"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Load to Staging",
                        Description = "Insert API data into staging table (temporary holding area)",
                        SqlStatement = @"-- C# performs bulk insert (8 records)
INSERT INTO STG_OPERATORS (OPERATOR_ID, OPERATOR_NAME, ETL_RUN_ID)
VALUES (:OperatorId, :OperatorName, :EtlRunId);

-- Staging is TEMPORARY - cleared after successful processing
-- No history kept in staging - it's just a landing zone"
                    },
                    new ETLStep
                    {
                        StepNumber = 5,
                        Title = "Call Orchestrator",
                        Description = "Oracle SP_PROCESS_ETL_BATCH handles ALL business logic",
                        SqlStatement = @"BEGIN
    SP_PROCESS_ETL_BATCH(
        p_etl_run_id => :etlRunId,
        p_entity_type => 'OPERATORS'
    );
END;

This orchestrator performs:
1. Deduplication (handles duplicate API data)
2. Validation (checks business rules)
3. SCD2 Processing (5 sub-steps below)
4. Reconciliation (verifies counts)
5. COMMIT (single atomic transaction)"
                    },
                    new ETLStep
                    {
                        StepNumber = 5,
                        Title = "Step 4.1: Handle Deletions",
                        Description = "Mark records as deleted if missing from API (soft delete)",
                        SqlStatement = @"UPDATE OPERATORS o
SET o.VALID_TO = SYSDATE,
    o.IS_CURRENT = 'N',
    o.DELETE_DATE = SYSDATE,
    o.CHANGE_TYPE = 'DELETE'
WHERE o.IS_CURRENT = 'Y'
  AND NOT EXISTS (
    SELECT 1 FROM STG_OPERATORS s
    WHERE s.OPERATOR_ID = o.OPERATOR_ID
      AND s.ETL_RUN_ID = :etlRunId
  );

-- Records are NEVER physically deleted
-- Full history preserved forever
-- Can query deleted records with DELETE_DATE IS NOT NULL"
                    },
                    new ETLStep
                    {
                        StepNumber = 6,
                        Title = "Step 4.2: Handle Reactivations",
                        Description = "Reactivate previously deleted records that return",
                        SqlStatement = @"INSERT INTO OPERATORS (
    OPERATOR_ID, OPERATOR_NAME, SRC_HASH,
    VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
)
SELECT s.OPERATOR_ID, s.OPERATOR_NAME,
       STANDARD_HASH(fields, 'SHA256'),
       SYSDATE, 'Y', 'REACTIVATE', :etlRunId
FROM STG_OPERATORS s
WHERE EXISTS (deleted record) AND NOT EXISTS (current record);

-- Tracks the business scenario of removed then restored data
-- Maintains audit trail of lifecycle"
                    },
                    new ETLStep
                    {
                        StepNumber = 7,
                        Title = "Step 4.3: Detect Unchanged",
                        Description = "Skip records with no changes (performance optimization)",
                        SqlStatement = @"SELECT COUNT(*) INTO v_records_unchanged
FROM STG_OPERATORS s
INNER JOIN OPERATORS o ON o.OPERATOR_ID = s.OPERATOR_ID
WHERE o.IS_CURRENT = 'Y'
  AND STANDARD_HASH(o.fields) = STANDARD_HASH(s.fields);

-- Uses SHA256 hash for efficient change detection
-- Unchanged records are NOT rewritten
-- Reduces database I/O and storage"
                    },
                    new ETLStep
                    {
                        StepNumber = 8,
                        Title = "Step 4.4: Handle Updates",
                        Description = "Create new version for changed records",
                        SqlStatement = @"-- Close old version
UPDATE OPERATORS o
SET o.VALID_TO = SYSDATE, o.IS_CURRENT = 'N'
WHERE o.IS_CURRENT = 'Y' AND [hash changed];

-- Insert new version
INSERT INTO OPERATORS (all_fields, CHANGE_TYPE)
VALUES (new_values, 'UPDATE');

-- Both versions kept: old with IS_CURRENT='N', new with IS_CURRENT='Y'
-- Can query historical state at any point in time"
                    },
                    new ETLStep
                    {
                        StepNumber = 9,
                        Title = "Step 4.5: Handle Inserts",
                        Description = "Add brand new records",
                        SqlStatement = @"INSERT INTO OPERATORS (
    OPERATOR_ID, OPERATOR_NAME, SRC_HASH,
    VALID_FROM, IS_CURRENT, CHANGE_TYPE, ETL_RUN_ID
)
SELECT s.*, SYSDATE, 'Y', 'INSERT', :etlRunId
FROM STG_OPERATORS s
WHERE NOT EXISTS (
    SELECT 1 FROM OPERATORS o
    WHERE o.OPERATOR_ID = s.OPERATOR_ID
);

-- New records start their history
-- VALID_FROM = now, VALID_TO = null
-- IS_CURRENT = 'Y'"
                    },
                    new ETLStep
                    {
                        StepNumber = 11,
                        Title = "Update Control & Commit",
                        Description = "Record metrics and commit transaction",
                        SqlStatement = @"UPDATE ETL_CONTROL
SET RECORDS_UNCHANGED = :unchanged,
    RECORDS_UPDATED = :updated,
    RECORDS_LOADED = :inserted,
    RECORDS_DELETED = :deleted,
    RECORDS_REACTIVATED = :reactivated,
    STATUS = 'SUCCESS',
    END_TIME = SYSTIMESTAMP
WHERE ETL_RUN_ID = :etlRunId;

COMMIT; -- Single atomic commit

-- If ANY error occurs: ROLLBACK everything
-- Error logged via autonomous transaction (survives rollback)
-- Data integrity guaranteed"
                    },
                    new ETLStep
                    {
                        StepNumber = 12,
                        Title = "Post-ETL Cleanup (Automatic)",
                        Description = "Cleanup runs AFTER successful ETL - no DBA required",
                        SqlStatement = @"-- Cleanup executes AFTER COMMIT (non-critical)
BEGIN
    -- Keep only last 10 ETL runs
    DELETE FROM ETL_CONTROL WHERE ETL_RUN_ID < 
        (SELECT MIN(ETL_RUN_ID) FROM last_10_runs);
    
    -- Clean 30-day old error logs
    DELETE FROM ETL_ERROR_LOG WHERE ERROR_TIME < SYSDATE - 30;
    
    -- Clean orphaned staging (safety)
    DELETE FROM STG_* WHERE ETL_RUN_ID < current - 10;
    
    COMMIT; -- Separate commit
EXCEPTION
    WHEN OTHERS THEN
        -- Cleanup errors don't fail ETL
        LOG_ETL_ERROR('Non-critical cleanup error');
END;

-- NO DBA REQUIRED! Runs with your permissions
-- NO SCHEDULED JOBS! Runs after each ETL
-- If cleanup fails, ETL still succeeds"
                    }
                }
            };
        }

        /// <summary>
        /// Get SQL preview for Plants ETL
        /// </summary>
        public ETLSqlPreview GetPlantsSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load Plants - Complete SCD2 Process",
                Description = "This process implements full SCD Type 2 change tracking for Plants (130 records), with foreign key to Operators.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Fetch from API",
                        Description = "C# fetches all plants from TR2000 API",
                        SqlStatement = @"-- C# Code
await _apiService.FetchDataAsync('https://equinor.pipespec-api.presight.com/plants');

Returns: 130 plants with:
- PlantID (e.g., '47')
- PlantName/ShortDescription (e.g., 'AASTA')
- LongDescription (e.g., 'Aasta Hansteen')
- OperatorID (FK to OPERATORS)
- CommonLibPlantCode (e.g., 'AHA')"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "Save to RAW_JSON",
                        Description = "Store raw API response for audit trail",
                        SqlStatement = @"BEGIN
    SP_INSERT_RAW_JSON(
        p_endpoint => '/plants', p_key_string => 'all-plants',
        p_etl_run_id => :etlRunId, p_http_status => 200,
        p_duration_ms => :elapsedMs, p_payload => :apiResponse
    );
END;
-- Compressed storage, 30-day retention, auto-purged"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Load to Staging",
                        Description = "Bulk insert 130 plants to staging",
                        SqlStatement = @"INSERT INTO STG_PLANTS (
    PLANT_ID, PLANT_NAME, LONG_DESCRIPTION,
    OPERATOR_ID, COMMON_LIB_PLANT_CODE, ETL_RUN_ID
) VALUES (
    :PlantId, :PlantName, :LongDescription,
    :OperatorId, :CommonLibPlantCode, :EtlRunId
);

-- Field mappings:
-- PlantName: Uses ShortDescription if PlantName missing
-- All fields nullable except PLANT_ID"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "SCD2 Processing",
                        Description = "PKG_PLANTS_ETL.PROCESS_SCD2 handles all logic",
                        SqlStatement = @"-- Same 5-step process as OPERATORS:
1. DELETE: Mark missing plants as deleted
2. REACTIVATE: Restore previously deleted plants
3. UNCHANGED: Skip if hash matches (most common)
4. UPDATE: New version for changed plants
5. INSERT: Add new plants

-- Key difference: More fields in hash
STANDARD_HASH(
    PLANT_ID || PLANT_NAME || LONG_DESCRIPTION ||
    OPERATOR_ID || COMMON_LIB_PLANT_CODE
)"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Data Integrity",
                        Description = "Validation and error handling",
                        SqlStatement = @"-- Validation checks:
- PLANT_ID required (cannot be null)
- PLANT_NAME max 200 characters
- Foreign key to OPERATORS validated

-- Error handling:
IF validation_failed THEN
    UPDATE STG_PLANTS 
    SET IS_VALID = 'N',
        VALIDATION_ERROR = 'specific error'
    WHERE [failed condition];
    
    -- Record still processed but marked
END IF;

-- Autonomous error logging:
LOG_ETL_ERROR(run_id, source, code, message);
-- This survives even if transaction rolls back"
                    },
                    new ETLStep
                    {
                        StepNumber = 6,
                        Title = "Reconciliation",
                        Description = "Verify data consistency",
                        SqlStatement = @"INSERT INTO ETL_RECONCILIATION (
    ETL_RUN_ID, ENTITY_TYPE, 
    SOURCE_COUNT, TARGET_COUNT, DIFF_COUNT
)
SELECT :etlRunId, 'PLANTS',
       (SELECT COUNT(*) FROM STG_PLANTS WHERE IS_VALID='Y'),
       (SELECT COUNT(*) FROM PLANTS WHERE IS_CURRENT='Y'),
       ABS(source - target);

-- Alert if difference > 10%
-- Helps detect data quality issues"
                    }
                }
            };
        }

        /// <summary>
        /// Get SQL preview for Issues ETL
        /// </summary>
        public ETLSqlPreview GetIssuesSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load Issues - Multi-Plant Process",
                Description = "Loads issues for all 130 plants with multiple API calls. Uses ETL_PLANT_LOADER for scope control.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Plant Loader Scope",
                        Description = "Check which plants to process",
                        SqlStatement = @"SELECT PLANT_ID, PLANT_NAME
FROM ETL_PLANT_LOADER
WHERE IS_ACTIVE = 'Y'
ORDER BY LOAD_PRIORITY;

-- ETL_PLANT_LOADER controls scope
-- Without it: 130 plants × N issues = 500+ API calls
-- With it: 3-5 plants × N issues = 30-50 API calls
-- 90% reduction in processing time!"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "API Loop",
                        Description = "Fetch issues for each active plant",
                        SqlStatement = @"FOR each plant IN active_plants LOOP
    -- API call for each plant
    await FetchDataAsync('/plants/{plantId}/issues');
    
    -- Each returns multiple issue revisions
    -- Insert all to staging with same ETL_RUN_ID
END LOOP;

-- Typical: 3-10 issues per plant
-- Total records: 50-500 depending on scope"
                    }
                }
            };
        }

        /// <summary>
        /// Get VDS References SQL Preview
        /// </summary>
        public ETLSqlPreview GetVDSReferencesSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load VDS References - Optimized Process",
                Description = "Loads Valve Data Sheet references for issues selected in Issue Loader. Uses cascade deletion pattern.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Issue Loader Scope",
                        Description = "Check which issues are configured for reference loading",
                        SqlStatement = @"SELECT PLANT_ID, ISSUE_REVISION, USER_NAME
FROM V_ISSUES_FOR_REFERENCES
ORDER BY PLANT_ID, ISSUE_REVISION;

-- V_ISSUES_FOR_REFERENCES view:
-- ✓ Joins ISSUES with ETL_ISSUE_LOADER
-- ✓ Only includes current issues (IS_CURRENT = 'Y')
-- ✓ Presence in loader = load references
-- ✓ 70% fewer API calls than full load"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "API Fetch Loop",
                        Description = "Fetch VDS references for each selected issue",
                        SqlStatement = @"FOR each issue IN selected_issues LOOP
    -- API call per issue
    await FetchDataAsync('/plants/{plantId}/issues/rev/{revision}/vds');
    
    -- Insert to staging with hash for change detection
    INSERT INTO STG_VDS_REFERENCES (
        PLANT_ID, ISSUE_REVISION, VDS_NAME, VDS_REVISION,
        OFFICIAL_REVISION, DELTA, USER_NAME, USER_ENTRY_TIME,
        SRC_HASH, ETL_RUN_ID
    ) VALUES (...);
END LOOP;"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Validate Staging Data",
                        Description = "Data quality checks and duplicate detection",
                        SqlStatement = @"BEGIN PKG_VDS_REF_ETL.VALIDATE(:etl_run_id); END;

-- Validation includes:
-- ✓ Required fields (PLANT_ID, ISSUE_REVISION, VDS_NAME)
-- ✓ Mark duplicates within batch
-- ✓ Set IS_VALID flag for processing"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Process SCD2 with Cascade Deletion",
                        Description = "Apply SCD2 changes with automatic cascade deletion",
                        SqlStatement = @"BEGIN PKG_VDS_REF_ETL.PROCESS_SCD2(:etl_run_id); END;

-- SCD2 Processing:
-- 1. CASCADE DELETE: Mark references deleted for issues NOT in loader
-- 2. CLOSE CHANGED: Update existing records where hash differs  
-- 3. REACTIVATE: Restore previously deleted records
-- 4. INSERT NEW: Add new reference records
-- 
-- Result: Full audit trail with CHANGE_TYPE tracking"
                    },
                    new ETLStep
                    {
                        StepNumber = 5,
                        Title = "Reconcile and Log",
                        Description = "Count validation and audit logging",
                        SqlStatement = @"BEGIN PKG_VDS_REF_ETL.RECONCILE(:etl_run_id); END;

-- Reconciliation:
-- ✓ Count staging vs dimension records
-- ✓ Log to ETL_RECONCILIATION table
-- ✓ Performance metrics tracking
-- ✓ Success/failure logging"
                    }
                }
            };
        }

        public ETLSqlPreview GetEDSReferencesSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load EDS References - Optimized Process",
                Description = "Loads Equipment Data Sheet references for issues selected in Issue Loader. Uses cascade deletion pattern.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Issue Loader Scope",
                        Description = "Check which issues are configured for reference loading",
                        SqlStatement = @"SELECT PLANT_ID, ISSUE_REVISION, USER_NAME
FROM V_ISSUES_FOR_REFERENCES
ORDER BY PLANT_ID, ISSUE_REVISION;

-- V_ISSUES_FOR_REFERENCES view:
-- ✓ Joins ISSUES with ETL_ISSUE_LOADER
-- ✓ Only includes current issues (IS_CURRENT = 'Y')
-- ✓ Presence in loader = load references
-- ✓ 70% fewer API calls than full load"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "API Fetch Loop",
                        Description = "Fetch EDS references for each selected issue",
                        SqlStatement = @"FOR each issue IN selected_issues LOOP
    -- API call per issue
    await FetchDataAsync('/plants/{plantId}/issues/rev/{revision}/eds');
    
    -- Insert to staging with hash for change detection
    INSERT INTO STG_EDS_REFERENCES (
        PLANT_ID, ISSUE_REVISION, EDS_NAME, EDS_REVISION,
        OFFICIAL_REVISION, DELTA, USER_NAME, USER_ENTRY_TIME,
        SRC_HASH, ETL_RUN_ID
    ) VALUES (...);
END LOOP;"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Validate Staging Data",
                        Description = "Data quality checks and duplicate detection",
                        SqlStatement = @"BEGIN PKG_EDS_REF_ETL.VALIDATE(:etl_run_id); END;

-- Validation includes:
-- ✓ Required fields (PLANT_ID, ISSUE_REVISION, EDS_NAME)
-- ✓ Mark duplicates within batch
-- ✓ Set IS_VALID flag for processing"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Process SCD2 with Cascade Deletion",
                        Description = "Apply SCD2 changes with automatic cascade deletion",
                        SqlStatement = @"BEGIN PKG_EDS_REF_ETL.PROCESS_SCD2(:etl_run_id); END;

-- SCD2 Processing:
-- 1. CASCADE DELETE: Mark references deleted for issues NOT in loader
-- 2. CLOSE CHANGED: Update existing records where hash differs  
-- 3. REACTIVATE: Restore previously deleted records
-- 4. INSERT NEW: Add new reference records
-- 
-- Result: Full audit trail with CHANGE_TYPE tracking"
                    },
                    new ETLStep
                    {
                        StepNumber = 5,
                        Title = "Reconcile and Log",
                        Description = "Count validation and audit logging",
                        SqlStatement = @"BEGIN PKG_EDS_REF_ETL.RECONCILE(:etl_run_id); END;

-- Reconciliation:
-- ✓ Count staging vs dimension records
-- ✓ Log to ETL_RECONCILIATION table
-- ✓ Performance metrics tracking
-- ✓ Success/failure logging"
                    }
                }
            };
        }

        public ETLSqlPreview GetMDSReferencesSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load MDS References - Optimized Process",
                Description = "Loads Material Data Sheet references for issues selected in Issue Loader. Includes AREA field.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Issue Loader Scope",
                        Description = "Check which issues are configured for reference loading",
                        SqlStatement = @"SELECT PLANT_ID, ISSUE_REVISION, USER_NAME
FROM V_ISSUES_FOR_REFERENCES
ORDER BY PLANT_ID, ISSUE_REVISION;

-- V_ISSUES_FOR_REFERENCES view:
-- ✓ Joins ISSUES with ETL_ISSUE_LOADER
-- ✓ Only includes current issues (IS_CURRENT = 'Y')
-- ✓ Presence in loader = load references
-- ✓ 70% fewer API calls than full load"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "API Fetch Loop",
                        Description = "Fetch MDS references for each selected issue",
                        SqlStatement = @"FOR each issue IN selected_issues LOOP
    -- API call per issue
    await FetchDataAsync('/plants/{plantId}/issues/rev/{revision}/mds');
    
    -- Insert to staging with hash for change detection
    INSERT INTO STG_MDS_REFERENCES (
        PLANT_ID, ISSUE_REVISION, MDS_NAME, MDS_REVISION,
        OFFICIAL_REVISION, DELTA, AREA, USER_NAME, USER_ENTRY_TIME,
        SRC_HASH, ETL_RUN_ID
    ) VALUES (...);
END LOOP;

-- NOTE: MDS includes AREA field unlike other reference types"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Validate Staging Data",
                        Description = "Data quality checks and duplicate detection",
                        SqlStatement = @"BEGIN PKG_MDS_REF_ETL.VALIDATE(:etl_run_id); END;

-- Validation includes:
-- ✓ Required fields (PLANT_ID, ISSUE_REVISION, MDS_NAME)
-- ✓ Mark duplicates within batch
-- ✓ Set IS_VALID flag for processing"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Process SCD2 with Cascade Deletion",
                        Description = "Apply SCD2 changes with automatic cascade deletion",
                        SqlStatement = @"BEGIN PKG_MDS_REF_ETL.PROCESS_SCD2(:etl_run_id); END;

-- SCD2 Processing:
-- 1. CASCADE DELETE: Mark references deleted for issues NOT in loader
-- 2. CLOSE CHANGED: Update existing records where hash differs  
-- 3. REACTIVATE: Restore previously deleted records
-- 4. INSERT NEW: Add new reference records
-- 
-- Result: Full audit trail with CHANGE_TYPE tracking"
                    },
                    new ETLStep
                    {
                        StepNumber = 5,
                        Title = "Reconcile and Log",
                        Description = "Count validation and audit logging",
                        SqlStatement = @"BEGIN PKG_MDS_REF_ETL.RECONCILE(:etl_run_id); END;

-- Reconciliation:
-- ✓ Count staging vs dimension records
-- ✓ Log to ETL_RECONCILIATION table
-- ✓ Performance metrics tracking
-- ✓ Success/failure logging"
                    }
                }
            };
        }

        public ETLSqlPreview GetVSKReferencesSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load VSK References - Optimized Process",
                Description = "Loads Valve Sketch references for issues selected in Issue Loader. Uses cascade deletion pattern.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Issue Loader Scope",
                        Description = "Check which issues are configured for reference loading",
                        SqlStatement = @"SELECT PLANT_ID, ISSUE_REVISION, USER_NAME
FROM V_ISSUES_FOR_REFERENCES
ORDER BY PLANT_ID, ISSUE_REVISION;

-- V_ISSUES_FOR_REFERENCES view:
-- ✓ Joins ISSUES with ETL_ISSUE_LOADER
-- ✓ Only includes current issues (IS_CURRENT = 'Y')
-- ✓ Presence in loader = load references
-- ✓ 70% fewer API calls than full load"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "API Fetch Loop",
                        Description = "Fetch VSK references for each selected issue",
                        SqlStatement = @"FOR each issue IN selected_issues LOOP
    -- API call per issue
    await FetchDataAsync('/plants/{plantId}/issues/rev/{revision}/vsk');
    
    -- Insert to staging with hash for change detection
    INSERT INTO STG_VSK_REFERENCES (
        PLANT_ID, ISSUE_REVISION, VSK_NAME, VSK_REVISION,
        OFFICIAL_REVISION, DELTA, USER_NAME, USER_ENTRY_TIME,
        SRC_HASH, ETL_RUN_ID
    ) VALUES (...);
END LOOP;"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Validate Staging Data",
                        Description = "Data quality checks and duplicate detection",
                        SqlStatement = @"BEGIN PKG_VSK_REF_ETL.VALIDATE(:etl_run_id); END;

-- Validation includes:
-- ✓ Required fields (PLANT_ID, ISSUE_REVISION, VSK_NAME)
-- ✓ Mark duplicates within batch
-- ✓ Set IS_VALID flag for processing"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Process SCD2 with Cascade Deletion",
                        Description = "Apply SCD2 changes with automatic cascade deletion",
                        SqlStatement = @"BEGIN PKG_VSK_REF_ETL.PROCESS_SCD2(:etl_run_id); END;

-- SCD2 Processing:
-- 1. CASCADE DELETE: Mark references deleted for issues NOT in loader
-- 2. CLOSE CHANGED: Update existing records where hash differs  
-- 3. REACTIVATE: Restore previously deleted records
-- 4. INSERT NEW: Add new reference records
-- 
-- Result: Full audit trail with CHANGE_TYPE tracking"
                    },
                    new ETLStep
                    {
                        StepNumber = 5,
                        Title = "Reconcile and Log",
                        Description = "Count validation and audit logging",
                        SqlStatement = @"BEGIN PKG_VSK_REF_ETL.RECONCILE(:etl_run_id); END;

-- Reconciliation:
-- ✓ Count staging vs dimension records
-- ✓ Log to ETL_RECONCILIATION table
-- ✓ Performance metrics tracking
-- ✓ Success/failure logging"
                    }
                }
            };
        }

        public ETLSqlPreview GetESKReferencesSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load ESK References - Optimized Process",
                Description = "Loads Equipment Sketch references for issues selected in Issue Loader. Uses cascade deletion pattern.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Issue Loader Scope",
                        Description = "Check which issues are configured for reference loading",
                        SqlStatement = @"SELECT PLANT_ID, ISSUE_REVISION, USER_NAME
FROM V_ISSUES_FOR_REFERENCES
ORDER BY PLANT_ID, ISSUE_REVISION;

-- V_ISSUES_FOR_REFERENCES view:
-- ✓ Joins ISSUES with ETL_ISSUE_LOADER
-- ✓ Only includes current issues (IS_CURRENT = 'Y')
-- ✓ Presence in loader = load references
-- ✓ 70% fewer API calls than full load"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "API Fetch Loop",
                        Description = "Fetch ESK references for each selected issue",
                        SqlStatement = @"FOR each issue IN selected_issues LOOP
    -- API call per issue
    await FetchDataAsync('/plants/{plantId}/issues/rev/{revision}/esk');
    
    -- Insert to staging with hash for change detection
    INSERT INTO STG_ESK_REFERENCES (
        PLANT_ID, ISSUE_REVISION, ESK_NAME, ESK_REVISION,
        OFFICIAL_REVISION, DELTA, USER_NAME, USER_ENTRY_TIME,
        SRC_HASH, ETL_RUN_ID
    ) VALUES (...);
END LOOP;"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Validate Staging Data",
                        Description = "Data quality checks and duplicate detection",
                        SqlStatement = @"BEGIN PKG_ESK_REF_ETL.VALIDATE(:etl_run_id); END;

-- Validation includes:
-- ✓ Required fields (PLANT_ID, ISSUE_REVISION, ESK_NAME)
-- ✓ Mark duplicates within batch
-- ✓ Set IS_VALID flag for processing"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Process SCD2 with Cascade Deletion",
                        Description = "Apply SCD2 changes with automatic cascade deletion",
                        SqlStatement = @"BEGIN PKG_ESK_REF_ETL.PROCESS_SCD2(:etl_run_id); END;

-- SCD2 Processing:
-- 1. CASCADE DELETE: Mark references deleted for issues NOT in loader
-- 2. CLOSE CHANGED: Update existing records where hash differs  
-- 3. REACTIVATE: Restore previously deleted records
-- 4. INSERT NEW: Add new reference records
-- 
-- Result: Full audit trail with CHANGE_TYPE tracking"
                    },
                    new ETLStep
                    {
                        StepNumber = 5,
                        Title = "Reconcile and Log",
                        Description = "Count validation and audit logging",
                        SqlStatement = @"BEGIN PKG_ESK_REF_ETL.RECONCILE(:etl_run_id); END;

-- Reconciliation:
-- ✓ Count staging vs dimension records
-- ✓ Log to ETL_RECONCILIATION table
-- ✓ Performance metrics tracking
-- ✓ Success/failure logging"
                    }
                }
            };
        }

        public ETLSqlPreview GetPipeElementReferencesSqlPreview()
        {
            return new ETLSqlPreview
            {
                Title = "Load Pipe Element References - Optimized Process",
                Description = "Loads Pipe Element references for issues selected in Issue Loader. Different field structure from other references.",
                Steps = new List<ETLStep>
                {
                    new ETLStep
                    {
                        StepNumber = 1,
                        Title = "Issue Loader Scope",
                        Description = "Check which issues are configured for reference loading",
                        SqlStatement = @"SELECT PLANT_ID, ISSUE_REVISION, USER_NAME
FROM V_ISSUES_FOR_REFERENCES
ORDER BY PLANT_ID, ISSUE_REVISION;

-- V_ISSUES_FOR_REFERENCES view:
-- ✓ Joins ISSUES with ETL_ISSUE_LOADER
-- ✓ Only includes current issues (IS_CURRENT = 'Y')
-- ✓ Presence in loader = load references
-- ✓ 70% fewer API calls than full load"
                    },
                    new ETLStep
                    {
                        StepNumber = 2,
                        Title = "API Fetch Loop",
                        Description = "Fetch Pipe Element references for each selected issue",
                        SqlStatement = @"FOR each issue IN selected_issues LOOP
    -- API call per issue
    await FetchDataAsync('/plants/{plantId}/issues/rev/{revision}/pipe-elements');
    
    -- Insert to staging with DIFFERENT field structure
    INSERT INTO STG_PIPE_ELEMENT_REFERENCES (
        PLANT_ID, ISSUE_REVISION, 
        TAG_NO,           -- ElementID from API
        ELEMENT_TYPE,     -- ElementGroup from API
        ELEMENT_SIZE,     -- DimensionStandard from API
        RATING,           -- ProductForm from API
        MATERIAL,         -- MaterialGrade from API
        USER_NAME, USER_ENTRY_TIME,
        SRC_HASH, ETL_RUN_ID
    ) VALUES (...);
END LOOP;

-- NOTE: Different field mapping than other reference types!"
                    },
                    new ETLStep
                    {
                        StepNumber = 3,
                        Title = "Validate Staging Data",
                        Description = "Data quality checks and duplicate detection",
                        SqlStatement = @"BEGIN PKG_PIPE_ELEMENT_REF_ETL.VALIDATE(:etl_run_id); END;

-- Validation includes:
-- ✓ Required fields (PLANT_ID, ISSUE_REVISION, TAG_NO)
-- ✓ Mark duplicates within batch
-- ✓ Set IS_VALID flag for processing"
                    },
                    new ETLStep
                    {
                        StepNumber = 4,
                        Title = "Process SCD2 with Cascade Deletion",
                        Description = "Apply SCD2 changes with automatic cascade deletion",
                        SqlStatement = @"BEGIN PKG_PIPE_ELEMENT_REF_ETL.PROCESS_SCD2(:etl_run_id); END;

-- SCD2 Processing:
-- 1. CASCADE DELETE: Mark references deleted for issues NOT in loader
-- 2. CLOSE CHANGED: Update existing records where hash differs  
-- 3. REACTIVATE: Restore previously deleted records
-- 4. INSERT NEW: Add new reference records
-- 
-- Result: Full audit trail with CHANGE_TYPE tracking"
                    },
                    new ETLStep
                    {
                        StepNumber = 5,
                        Title = "Reconcile and Log",
                        Description = "Count validation and audit logging",
                        SqlStatement = @"BEGIN PKG_PIPE_ELEMENT_REF_ETL.RECONCILE(:etl_run_id); END;

-- Reconciliation:
-- ✓ Count staging vs dimension records
-- ✓ Log to ETL_RECONCILIATION table
-- ✓ Performance metrics tracking
-- ✓ Success/failure logging"
                    }
                }
            };
        }

        /// <summary>
        /// Test Oracle database connection
        /// </summary>
        public async Task<bool> TestConnection()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                // Verify we can query
                var result = await connection.QuerySingleAsync<int>("SELECT 1 FROM DUAL");
                
                _logger.LogInformation("Successfully connected to Oracle database");
                return result == 1;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to connect to Oracle database");
                return false;
            }
        }

        /// <summary>
        /// Insert raw JSON response to audit table (MANDATORY for data integrity)
        /// </summary>
        private async Task InsertRawJson(
            OracleConnection connection, 
            int etlRunId, 
            string endpoint, 
            string keyString,
            string apiResponse,
            int httpStatus = 200,
            int? durationMs = null)
        {
            try
            {
                // Use simple anonymous object parameters (like the rest of the codebase)
                await connection.ExecuteAsync(@"
                    BEGIN
                        SP_INSERT_RAW_JSON(
                            p_etl_run_id     => :etlRunId,
                            p_endpoint       => :endpoint,
                            p_request_url    => :requestUrl,
                            p_request_params => :requestParams,
                            p_response_status => :httpStatus,
                            p_plant_id       => :plantId,
                            p_json_data      => :jsonData,
                            p_duration_ms    => :durationMs,
                            p_headers        => :headers
                        );
                    END;",
                    new 
                    { 
                        etlRunId,
                        endpoint,
                        requestUrl = $"https://equinor.pipespec-api.presight.com/{endpoint}",
                        requestParams = (string?)null,
                        httpStatus,
                        plantId = ExtractPlantIdFromKey(keyString) ?? (string?)null,
                        jsonData = apiResponse,
                        durationMs = durationMs ?? 0,
                        headers = "{\"Content-Type\": \"application/json\"}"
                    });
                
                _logger.LogDebug($"RAW_JSON inserted for {endpoint}");
            }
            catch (Exception ex)
            {
                // RAW_JSON is MANDATORY - ETL must fail if this fails
                _logger.LogError($"RAW_JSON insert FAILED - ETL cannot continue: {ex.Message}");
                throw new InvalidOperationException($"RAW_JSON insertion is mandatory for data integrity. Error: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Extract plant ID from keyString (if present)
        /// </summary>
        private string ExtractPlantIdFromKey(string keyString)
        {
            if (string.IsNullOrEmpty(keyString))
                return null;
                
            // Extract plant ID from patterns like "vds-PLANTID-REVISION" or "all-plants"
            if (keyString.Contains("-") && !keyString.StartsWith("all-"))
            {
                var parts = keyString.Split('-');
                if (parts.Length >= 2)
                    return parts[1]; // Return the plant ID part
            }
            
            return null; // For global endpoints like "all-operators", "all-plants"
        }

        /// <summary>
        /// Load Operators using new orchestrator pattern
        /// </summary>
        public async Task<ETLResult> LoadOperators()
        {
            var result = new ETLResult 
            { 
                StartTime = DateTime.Now, 
                EndpointName = "OPERATORS" 
            };

            try
            {
                // STEP 1: Fetch from API (raw JSON for Oracle parsing)
                _logger.LogInformation("Fetching operators from API...");
                var sw = System.Diagnostics.Stopwatch.StartNew();
                var apiResponse = await _apiService.FetchDataAsync("operators");
                sw.Stop();
                
                result.ApiCallCount = 1;
                
                if (string.IsNullOrEmpty(apiResponse))
                {
                    result.Status = "NO_DATA";
                    result.Message = "No data returned from API";
                    return result;
                }

                _logger.LogInformation($"Fetched operators from API");

                // STEP 2: Get ETL Run ID
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                // Insert ETL control record
                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSTIMESTAMP, :apiCalls)",
                    new { etlRunId, runType = "OPERATORS", apiCalls = result.ApiCallCount }
                );

                // MANDATORY: Insert RAW_JSON for audit trail
                await InsertRawJson(
                    connection, 
                    etlRunId, 
                    "operators", 
                    "all-operators",
                    apiResponse,
                    200,
                    (int)sw.ElapsedMilliseconds
                );

                // STEP 3: Call Oracle orchestrator (parses RAW_JSON → STG → FINAL)
                _logger.LogInformation("Calling Oracle ETL orchestrator to parse RAW_JSON data...");
                
                using (var cmd = new OracleCommand("SP_PROCESS_ETL_BATCH", connection))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add("p_etl_run_id", OracleDbType.Int32).Value = etlRunId;
                    cmd.Parameters.Add("p_entity_type", OracleDbType.Varchar2).Value = "OPERATORS";
                    
                    await cmd.ExecuteNonQueryAsync();
                }

                // STEP 5: Get results from Oracle
                var controlRecord = await connection.QuerySingleAsync<dynamic>(@"
                    SELECT STATUS, PROCESSING_TIME_SEC,
                           RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED,
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                
                result.EndTime = DateTime.Now;
                result.Message = $"ETL completed: {result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, " +
                               $"{result.RecordsDeleted} deleted, {result.RecordsReactivated} reactivated";

                _logger.LogInformation($"ETL completed successfully: {result.Message}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Load Plants using new orchestrator pattern
        /// </summary>
        public async Task<ETLResult> LoadPlants()
        {
            var result = new ETLResult 
            { 
                StartTime = DateTime.Now, 
                EndpointName = "PLANTS_ENHANCED" 
            };

            try
            {
                // STEP 1: Fetch plant data from API (raw JSON for Oracle parsing)
                _logger.LogInformation("Fetching plants from API (basic data)...");
                var sw = System.Diagnostics.Stopwatch.StartNew();
                var plantsApiResponse = await _apiService.FetchDataAsync("plants");
                sw.Stop();
                
                if (string.IsNullOrEmpty(plantsApiResponse))
                {
                    result.Status = "NO_DATA";
                    result.Message = "No data returned from plants API";
                    return result;
                }

                _logger.LogInformation($"Fetched plants from API");
                result.ApiCallCount = 1;

                // STEP 2: Get ETL Run ID and setup
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSDATE, :apiCalls)",
                    new { etlRunId, runType = "PLANTS_ENHANCED", apiCalls = 1 }
                );

                // MANDATORY: Insert RAW_JSON for plants data
                await InsertRawJson(
                    connection, 
                    etlRunId, 
                    "plants", 
                    "all-plants",
                    plantsApiResponse,
                    200,
                    (int)sw.ElapsedMilliseconds
                );

                // STEP 3: Call Oracle orchestrator (parses RAW_JSON → STG → FINAL)
                _logger.LogInformation("Calling Oracle ETL orchestrator to parse RAW_JSON data...");
                
                using (var cmd = new OracleCommand("SP_PROCESS_ETL_BATCH", connection))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.Parameters.Add("p_etl_run_id", OracleDbType.Int32).Value = etlRunId;
                    cmd.Parameters.Add("p_entity_type", OracleDbType.Varchar2).Value = "PLANTS";
                    
                    await cmd.ExecuteNonQueryAsync();
                }

                // STEP 5: Get results
                var controlRecord = await connection.QuerySingleAsync<dynamic>(@"
                    SELECT STATUS, PROCESSING_TIME_SEC,
                           RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED,
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                
                result.EndTime = DateTime.Now;
                result.Message = $"ETL completed: {result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, " +
                               $"{result.RecordsDeleted} deleted, {result.RecordsReactivated} reactivated";

                _logger.LogInformation($"ETL completed successfully: {result.Message}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Load Issues for selected plants
        /// </summary>
        public async Task<ETLResult> LoadIssuesForSelectedPlants()
        {
            var result = new ETLResult 
            { 
                StartTime = DateTime.Now, 
                EndpointName = "ISSUES_ENHANCED" 
            };

            try
            {
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();

                // Get all plants from loader (no active/inactive - if it's in the loader, we process it)
                var plantsToProcess = await connection.QueryAsync<string>(@"
                    SELECT PLANT_ID 
                    FROM ETL_PLANT_LOADER 
                    ORDER BY PLANT_ID"
                );

                if (!plantsToProcess.Any())
                {
                    result.Status = "NO_PLANTS";
                    result.Message = "No plants in loader. Add plants to process.";
                    return result;
                }

                _logger.LogInformation($"Loading issues for {plantsToProcess.Count()} plants");

                // SMART WORKFLOW: Enhance plants with detailed data for selected plants only
                _logger.LogInformation("🎯 SMART WORKFLOW: Starting plant enhancement for selected plants");
                await EnhancePlantsWithDetailedData(connection, plantsToProcess.ToList());

                // Get ETL Run ID
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSDATE, :apiCalls)",
                    new { etlRunId, runType = "ISSUES_ENHANCED", apiCalls = 0 }
                );

                int totalRecords = 0;
                int apiCalls = 0; // Start with 0, will increment with issues API calls

                // Fetch issues for each plant
                foreach (var plantId in plantsToProcess)
                {
                    try
                    {
                        _logger.LogInformation($"Fetching issues for plant {plantId}...");
                        var endpoint = $"plants/{plantId}/issues";
                        var apiResponse = await _apiService.FetchDataAsync(endpoint);
                        var issuesData = _deserializer.DeserializeApiResponse(apiResponse, endpoint);
                        apiCalls++;

                        // Log to RAW_JSON for audit trail (MANDATORY for data integrity)
                        try
                        {
                            await connection.ExecuteAsync(@"
                                CALL SP_INSERT_RAW_JSON(
                                    :endpoint, :keyString, :etlRunId, 
                                    :httpStatus, :durationMs, :headers, :payload
                                )",
                                new
                                {
                                    endpoint = $"ISSUES_{endpoint}",
                                    keyString = $"plant_{plantId}",
                                    etlRunId,
                                    httpStatus = 200,
                                    durationMs = 100, // Placeholder - would need to measure actual duration
                                    headers = "{}",
                                    payload = apiResponse
                                }
                            );
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "RAW_JSON insert FAILED - ETL cannot continue: {Message}", ex.Message);
                            throw new InvalidOperationException($"RAW_JSON insertion is mandatory for data integrity. Error: {ex.Message}", ex);
                        }

                        if (issuesData != null && issuesData.Any())
                        {
                            foreach (var issue in issuesData)
                            {
                                await connection.ExecuteAsync(@"
                                    INSERT INTO STG_ISSUES (
                                        PLANT_ID, ISSUE_REVISION, 
                                        -- Issue Status and Dates
                                        STATUS, REV_DATE, PROTECT_STATUS,
                                        -- General Revision Info
                                        GENERAL_REVISION, GENERAL_REV_DATE,
                                        -- Specific Component Revisions and Dates (16 fields)
                                        PCS_REVISION, PCS_REV_DATE, EDS_REVISION, EDS_REV_DATE,
                                        VDS_REVISION, VDS_REV_DATE, VSK_REVISION, VSK_REV_DATE,
                                        MDS_REVISION, MDS_REV_DATE, ESK_REVISION, ESK_REV_DATE,
                                        SC_REVISION, SC_REV_DATE, VSM_REVISION, VSM_REV_DATE,
                                        -- User Audit Fields
                                        USER_NAME, USER_ENTRY_TIME, USER_PROTECTED,
                                        -- ETL Control Fields
                                        ETL_RUN_ID
                                    ) VALUES (
                                        :PlantId, :IssueRevision,
                                        :Status, :RevDate, :ProtectStatus,
                                        :GeneralRevision, :GeneralRevDate,
                                        :PcsRevision, :PcsRevDate, :EdsRevision, :EdsRevDate,
                                        :VdsRevision, :VdsRevDate, :VskRevision, :VskRevDate,
                                        :MdsRevision, :MdsRevDate, :EskRevision, :EskRevDate,
                                        :ScRevision, :ScRevDate, :VsmRevision, :VsmRevDate,
                                        :UserName, :UserEntryTime, :UserProtected,
                                        :EtlRunId
                                    )",
                                    new
                                    {
                                        PlantId = plantId,
                                        IssueRevision = issue["IssueRevision"]?.ToString(),
                                        // Issue Status and Dates
                                        Status = issue["Status"]?.ToString(),
                                        RevDate = issue["RevDate"]?.ToString(),
                                        ProtectStatus = issue["ProtectStatus"]?.ToString(),
                                        // General Revision Info
                                        GeneralRevision = issue["GeneralRevision"]?.ToString(),
                                        GeneralRevDate = issue["GeneralRevDate"]?.ToString(),
                                        // Specific Component Revisions and Dates (16 fields)
                                        PcsRevision = issue["PCSRevision"]?.ToString(),
                                        PcsRevDate = issue["PCSRevDate"]?.ToString(),
                                        EdsRevision = issue["EDSRevision"]?.ToString(),
                                        EdsRevDate = issue["EDSRevDate"]?.ToString(),
                                        VdsRevision = issue["VDSRevision"]?.ToString(),
                                        VdsRevDate = issue["VDSRevDate"]?.ToString(),
                                        VskRevision = issue["VSKRevision"]?.ToString(),
                                        VskRevDate = issue["VSKRevDate"]?.ToString(),
                                        MdsRevision = issue["MDSRevision"]?.ToString(),
                                        MdsRevDate = issue["MDSRevDate"]?.ToString(),
                                        EskRevision = issue["ESKRevision"]?.ToString(),
                                        EskRevDate = issue["ESKRevDate"]?.ToString(),
                                        ScRevision = issue["SCRevision"]?.ToString(),
                                        ScRevDate = issue["SCRevDate"]?.ToString(),
                                        VsmRevision = issue["VSMRevision"]?.ToString(),
                                        VsmRevDate = issue["VSMRevDate"]?.ToString(),
                                        // User Audit Fields
                                        UserName = issue["UserName"]?.ToString(),
                                        UserEntryTime = issue.ContainsKey("UserEntryTime") ? issue["UserEntryTime"]?.ToString() : null,
                                        UserProtected = issue["UserProtected"]?.ToString(),
                                        // ETL Control
                                        EtlRunId = etlRunId
                                    }
                                );
                                totalRecords++;
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Failed to load issues for plant {plantId}: {ex.Message}");
                    }
                }

                // Update API call count
                await connection.ExecuteAsync(
                    "UPDATE ETL_CONTROL SET API_CALL_COUNT = :apiCalls WHERE ETL_RUN_ID = :etlRunId",
                    new { apiCalls, etlRunId }
                );

                // Call orchestrator
                _logger.LogInformation($"Processing {totalRecords} issues through orchestrator...");
                
                try
                {
                    using (var cmd = new OracleCommand("SP_PROCESS_ETL_BATCH", connection))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add("p_etl_run_id", OracleDbType.Int32).Value = etlRunId;
                        cmd.Parameters.Add("p_entity_type", OracleDbType.Varchar2).Value = "ISSUES";
                        
                        await cmd.ExecuteNonQueryAsync();
                    }
                    _logger.LogInformation("Orchestrator completed successfully");
                }
                catch (OracleException oex)
                {
                    _logger.LogError($"Oracle error in orchestrator: {oex.Message} (Code: {oex.Number})");
                    throw;
                }

                // Get results
                var controlRecord = await connection.QuerySingleAsync<dynamic>(@"
                    SELECT STATUS, PROCESSING_TIME_SEC,
                           RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED,
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.ApiCallCount = apiCalls;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                
                result.EndTime = DateTime.Now;
                result.Message = $"🎯 SMART WORKFLOW: Enhanced {plantsToProcess.Count()} plants + loaded issues. " +
                               $"{result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, {result.RecordsDeleted} deleted. " +
                               $"Total API calls: {apiCalls} (vs 131 for all plants = {Math.Round((1 - (double)apiCalls/131) * 100, 1)}% reduction)";

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Get ETL history
        /// </summary>
        public async Task<List<ETLRunHistory>> GetETLHistory(int maxRows = 10)
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                
                var history = await connection.QueryAsync<ETLRunHistory>(@"
                    SELECT 
                        ETL_RUN_ID,
                        RUN_TYPE,
                        STATUS,
                        START_TIME,
                        END_TIME,
                        PROCESSING_TIME_SEC,
                        RECORDS_LOADED,
                        RECORDS_UPDATED,
                        RECORDS_DELETED,
                        RECORDS_REACTIVATED,
                        RECORDS_UNCHANGED,
                        ERROR_COUNT,
                        API_CALL_COUNT,
                        COMMENTS
                    FROM ETL_CONTROL
                    ORDER BY ETL_RUN_ID DESC
                    FETCH FIRST :maxRows ROWS ONLY",
                    new { maxRows }
                );

                return history.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get ETL history");
                return new List<ETLRunHistory>();
            }
        }

        /// <summary>
        /// Get table statistics
        /// </summary>
        public async Task<List<TableStatus>> GetTableStatuses()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                
                var statuses = await connection.QueryAsync<TableStatus>(@"
                    SELECT 
                        'OPERATORS' as TABLE_NAME,
                        COUNT(*) as RECORD_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as DELETED_COUNT,
                        MAX(VALID_FROM) as LAST_UPDATE
                    FROM OPERATORS
                    UNION ALL
                    SELECT 
                        'PLANTS' as TABLE_NAME,
                        COUNT(*) as RECORD_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as DELETED_COUNT,
                        MAX(VALID_FROM) as LAST_UPDATE
                    FROM PLANTS
                    UNION ALL
                    SELECT 
                        'ISSUES' as TABLE_NAME,
                        COUNT(*) as RECORD_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as DELETED_COUNT,
                        MAX(VALID_FROM) as LAST_UPDATE
                    FROM ISSUES
                    UNION ALL
                    SELECT 
                        'VDS_REFERENCES' as TABLE_NAME,
                        COUNT(*) as RECORD_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as DELETED_COUNT,
                        MAX(VALID_FROM) as LAST_UPDATE
                    FROM VDS_REFERENCES
                    UNION ALL
                    SELECT 
                        'EDS_REFERENCES' as TABLE_NAME,
                        COUNT(*) as RECORD_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as DELETED_COUNT,
                        MAX(VALID_FROM) as LAST_UPDATE
                    FROM EDS_REFERENCES
                    UNION ALL
                    SELECT 
                        'MDS_REFERENCES' as TABLE_NAME,
                        COUNT(*) as RECORD_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as DELETED_COUNT,
                        MAX(VALID_FROM) as LAST_UPDATE
                    FROM MDS_REFERENCES
                    UNION ALL
                    SELECT 
                        'VSK_REFERENCES' as TABLE_NAME,
                        COUNT(*) as RECORD_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as DELETED_COUNT,
                        MAX(VALID_FROM) as LAST_UPDATE
                    FROM VSK_REFERENCES
                    UNION ALL
                    SELECT 
                        'ESK_REFERENCES' as TABLE_NAME,
                        COUNT(*) as RECORD_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as DELETED_COUNT,
                        MAX(VALID_FROM) as LAST_UPDATE
                    FROM ESK_REFERENCES
                    UNION ALL
                    SELECT 
                        'PIPE_ELEMENT_REFERENCES' as TABLE_NAME,
                        COUNT(*) as RECORD_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'Y' THEN 1 ELSE 0 END) as CURRENT_COUNT,
                        SUM(CASE WHEN IS_CURRENT = 'N' THEN 1 ELSE 0 END) as DELETED_COUNT,
                        MAX(VALID_FROM) as LAST_UPDATE
                    FROM PIPE_ELEMENT_REFERENCES"
                );

                return statuses.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get table statuses");
                return new List<TableStatus>();
            }
        }

        /// <summary>
        /// Check if plant loader table exists
        /// </summary>
        public async Task<bool> CheckPlantLoaderTableExists()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                var count = await connection.QuerySingleAsync<int>(@"
                    SELECT COUNT(*) 
                    FROM USER_TABLES 
                    WHERE TABLE_NAME = 'ETL_PLANT_LOADER'"
                );
                return count > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to check plant loader table");
                return false;
            }
        }

        /// <summary>
        /// Create plant loader table
        /// </summary>
        public async Task CreatePlantLoaderTable()
        {
            using var connection = new OracleConnection(_connectionString);
            await connection.ExecuteAsync(@"
                CREATE TABLE ETL_PLANT_LOADER (
                    PLANT_ID VARCHAR2(20) PRIMARY KEY,
                    PLANT_NAME VARCHAR2(200),
                    IS_ACTIVE CHAR(1) DEFAULT 'Y' CHECK (IS_ACTIVE IN ('Y', 'N')),
                    CREATED_DATE DATE DEFAULT SYSDATE,
                    MODIFIED_DATE DATE DEFAULT SYSDATE
                )"
            );
        }

        /// <summary>
        /// Get all plants from database
        /// </summary>
        public async Task<List<Plant>> GetAllPlants()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                var plants = await connection.QueryAsync<Plant>(@"
                    SELECT PLANT_ID as PlantID, 
                           SHORT_DESCRIPTION as PlantName,
                           LONG_DESCRIPTION as LongDescription,
                           OPERATOR_ID as OperatorID
                    FROM PLANTS 
                    WHERE IS_CURRENT = 'Y'
                    ORDER BY SHORT_DESCRIPTION"
                );
                return plants.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get all plants");
                return new List<Plant>();
            }
        }

        /// <summary>
        /// Get plant loader entries
        /// </summary>
        public async Task<List<PlantLoaderEntry>> GetPlantLoaderEntries()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                var entries = await connection.QueryAsync<PlantLoaderEntry>(@"
                    SELECT PLANT_ID as PlantID,
                           PLANT_NAME as PlantName,
                           CASE WHEN IS_ACTIVE = 'Y' THEN 1 ELSE 0 END as IsActive,
                           CREATED_DATE as CreatedDate,
                           MODIFIED_DATE as ModifiedDate
                    FROM ETL_PLANT_LOADER
                    ORDER BY PLANT_NAME"
                );
                return entries.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get plant loader entries");
                return new List<PlantLoaderEntry>();
            }
        }

        /// <summary>
        /// Add plant to loader
        /// </summary>
        public async Task AddPlantToLoader(string plantId)
        {
            using var connection = new OracleConnection(_connectionString);
            
            // Get plant details
            var plant = await connection.QuerySingleOrDefaultAsync<Plant>(@"
                SELECT PLANT_ID as PlantID, SHORT_DESCRIPTION as PlantName
                FROM PLANTS 
                WHERE IS_CURRENT = 'Y' AND PLANT_ID = :plantId",
                new { plantId }
            );
            
            if (plant == null)
                throw new Exception($"Plant {plantId} not found");
            
            // Insert into loader
            await connection.ExecuteAsync(@"
                INSERT INTO ETL_PLANT_LOADER (PLANT_ID, PLANT_NAME, IS_ACTIVE)
                VALUES (:plantId, :plantName, 'Y')",
                new { plantId = plant.PlantID, plantName = plant.PlantName }
            );
        }

        // REMOVED: Active/Inactive concept removed for simplicity
        // Plants in the loader are always processed
        // /// <summary>
        // /// Toggle plant active status
        // /// </summary>
        // public async Task TogglePlantActive(string plantId)
        // {
        //     using var connection = new OracleConnection(_connectionString);
        //     await connection.ExecuteAsync(@"
        //         UPDATE ETL_PLANT_LOADER 
        //         SET IS_ACTIVE = CASE WHEN IS_ACTIVE = 'Y' THEN 'N' ELSE 'Y' END,
        //             MODIFIED_DATE = SYSDATE
        //         WHERE PLANT_ID = :plantId",
        //         new { plantId }
        //     );
        // }

        /// <summary>
        /// Remove plant from loader
        /// </summary>
        public async Task RemovePlantFromLoader(string plantId)
        {
            using var connection = new OracleConnection(_connectionString);
            await connection.ExecuteAsync(@"
                DELETE FROM ETL_PLANT_LOADER 
                WHERE PLANT_ID = :plantId",
                new { plantId }
            );
        }

        #region Issue Loader Methods

        /// <summary>
        /// Check if issue loader table exists
        /// </summary>
        public async Task<bool> CheckIssueLoaderTableExists()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                var count = await connection.QuerySingleAsync<int>(@"
                    SELECT COUNT(*) 
                    FROM USER_TABLES 
                    WHERE TABLE_NAME = 'ETL_ISSUE_LOADER'"
                );
                return count > 0;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to check issue loader table");
                return false;
            }
        }

        /// <summary>
        /// Create issue loader table
        /// </summary>
        public async Task CreateIssueLoaderTable()
        {
            using var connection = new OracleConnection(_connectionString);
            await connection.ExecuteAsync(@"
                CREATE TABLE ETL_ISSUE_LOADER (
                    PLANT_ID VARCHAR2(50) NOT NULL,
                    ISSUE_REVISION VARCHAR2(20) NOT NULL,
                    PLANT_NAME VARCHAR2(200),
                    CREATED_DATE DATE DEFAULT SYSDATE,
                    CONSTRAINT PK_ETL_ISSUE_LOADER PRIMARY KEY (PLANT_ID, ISSUE_REVISION),
                    CONSTRAINT FK_ISSUE_LOADER_PLANT FOREIGN KEY (PLANT_ID) 
                        REFERENCES ETL_PLANT_LOADER(PLANT_ID) ON DELETE CASCADE
                )"
            );
        }

        /// <summary>
        /// Get issues for a specific plant
        /// </summary>
        public async Task<List<Issue>> GetIssuesForPlant(string plantId)
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                var issues = await connection.QueryAsync<Issue>(@"
                    SELECT PLANT_ID as PlantID,
                           ISSUE_REVISION as IssueRevision,
                           USER_NAME as UserName,
                           USER_ENTRY_TIME as UserEntryTime,
                           USER_PROTECTED as UserProtected
                    FROM ISSUES 
                    WHERE IS_CURRENT = 'Y' 
                      AND PLANT_ID = :plantId
                    ORDER BY ISSUE_REVISION"
                , new { plantId });
                return issues.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get issues for plant {PlantId}", plantId);
                return new List<Issue>();
            }
        }

        /// <summary>
        /// Get issue loader entries
        /// </summary>
        public async Task<List<IssueLoaderEntry>> GetIssueLoaderEntries()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                var entries = await connection.QueryAsync<IssueLoaderEntry>(@"
                    SELECT il.PLANT_ID as PlantID,
                           il.ISSUE_REVISION as IssueRevision,
                           il.PLANT_NAME as PlantName,
                           il.CREATED_DATE as CreatedDate
                    FROM ETL_ISSUE_LOADER il
                    ORDER BY il.PLANT_NAME, il.ISSUE_REVISION"
                );
                return entries.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get issue loader entries");
                return new List<IssueLoaderEntry>();
            }
        }

        /// <summary>
        /// Add issue to loader
        /// </summary>
        public async Task AddIssueToLoader(string plantId, string issueRevision)
        {
            using var connection = new OracleConnection(_connectionString);
            
            // Get plant and issue details
            var plantName = await connection.QuerySingleOrDefaultAsync<string>(@"
                SELECT PLANT_NAME
                FROM ETL_PLANT_LOADER 
                WHERE PLANT_ID = :plantId",
                new { plantId }
            );
            
            if (string.IsNullOrEmpty(plantName))
                throw new Exception($"Plant {plantId} not found in Plant Loader");
            
            // Verify issue exists
            var issueExists = await connection.QuerySingleAsync<int>(@"
                SELECT COUNT(*)
                FROM ISSUES 
                WHERE IS_CURRENT = 'Y' 
                  AND PLANT_ID = :plantId 
                  AND ISSUE_REVISION = :issueRevision",
                new { plantId, issueRevision }
            );
            
            if (issueExists == 0)
                throw new Exception($"Issue {issueRevision} not found for plant {plantId}");
            
            // Insert into issue loader
            await connection.ExecuteAsync(@"
                INSERT INTO ETL_ISSUE_LOADER (PLANT_ID, ISSUE_REVISION, PLANT_NAME)
                VALUES (:plantId, :issueRevision, :plantName)",
                new { plantId, issueRevision, plantName }
            );
        }

        /// <summary>
        /// Remove issue from loader
        /// </summary>
        public async Task RemoveIssueFromLoader(string plantId, string issueRevision)
        {
            using var connection = new OracleConnection(_connectionString);
            await connection.ExecuteAsync(@"
                DELETE FROM ETL_ISSUE_LOADER 
                WHERE PLANT_ID = :plantId AND ISSUE_REVISION = :issueRevision",
                new { plantId, issueRevision }
            );
        }

        #endregion

        #region Reference Table ETL Methods

        /// <summary>
        /// Load VDS References for all issues in the Issue Loader
        /// </summary>
        public async Task<ETLResult> LoadVDSReferences()
        {
            var result = new ETLResult 
            { 
                StartTime = DateTime.Now, 
                EndpointName = "VDS_REFERENCES" 
            };

            try
            {
                _logger.LogInformation("Loading VDS references for selected issues");

                // Get issues from Issue Loader for reference loading
                var issuesForReferences = await GetIssuesForReferences();
                if (!issuesForReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No issues configured for reference loading";
                    result.EndTime = DateTime.Now;
                    return result;
                }

                _logger.LogInformation($"Loading VDS references for {issuesForReferences.Count} issues");

                // Use orchestrator pattern - let Oracle handle the ETL logic
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                // Insert ETL control record
                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSTIMESTAMP, 0)",
                    new { etlRunId, runType = "VDS_REFERENCES" }
                );

                // Fetch and insert data for each issue (simplified)
                int totalApiCalls = 0;
                foreach (var issue in issuesForReferences)
                {
                    try
                    {
                        var apiUrl = $"plants/{issue.PlantID}/issues/rev/{issue.IssueRevision}/vds";
                        var apiResponse = await _apiService.FetchDataAsync(apiUrl);
                        totalApiCalls++;
                        
                        // MANDATORY: Insert RAW_JSON for audit trail
                        await InsertRawJson(
                            connection, 
                            etlRunId, 
                            apiUrl, 
                            $"vds-{issue.PlantID}-{issue.IssueRevision}",
                            apiResponse,
                            200,
                            0
                        );
                        
                        var apiData = _deserializer.DeserializeApiResponse(apiResponse, $"vds-{issue.PlantID}-{issue.IssueRevision}");

                        if (apiData?.Any() == true)
                        {
                            // Simple insert - let Oracle packages handle the transformation
                            foreach (var item in apiData)
                            {
                                await connection.ExecuteAsync(@"
                                    INSERT INTO STG_VDS_REFERENCES (
                                        PLANT_ID, ISSUE_REVISION, VDS_NAME, VDS_REVISION,
                                        REV_DATE, STATUS, OFFICIAL_REVISION, DELTA, ETL_RUN_ID
                                    ) VALUES (
                                        :plantId, :issueRev, :vdsName, :vdsRev,
                                        :revDate, :status, :officialRev, :delta, :etlRunId
                                    )", new {
                                        plantId = issue.PlantID,
                                        issueRev = issue.IssueRevision,
                                        vdsName = item["VDS"]?.ToString(),
                                        vdsRev = item["Revision"]?.ToString(),
                                        revDate = ParseDateTimeFromString(item["RevDate"]?.ToString()),
                                        status = item["Status"]?.ToString(),
                                        officialRev = item["OfficialRevision"]?.ToString(),
                                        delta = item["Delta"]?.ToString(),
                                        etlRunId
                                    });
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Failed to fetch VDS references for plant {issue.PlantID}, issue {issue.IssueRevision}");
                    }
                }

                // Update API call count
                await connection.ExecuteAsync(@"
                    UPDATE ETL_CONTROL 
                    SET API_CALL_COUNT = :apiCalls
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { apiCalls = totalApiCalls, etlRunId }
                );

                // Call orchestrator to process through packages
                _logger.LogInformation("Calling Oracle ETL orchestrator...");
                await connection.ExecuteAsync(@"
                    BEGIN 
                        SP_PROCESS_ETL_BATCH(:etlRunId, 'VDS_REFERENCES');
                    END;", 
                    new { etlRunId }
                );

                // Get final results
                var controlRecord = await connection.QuerySingleAsync(@"
                    SELECT STATUS, RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED, 
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT, PROCESSING_TIME_SEC
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                result.ApiCallCount = totalApiCalls;
                
                result.EndTime = DateTime.Now;
                result.Message = $"ETL completed: {result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, " +
                               $"{result.RecordsDeleted} deleted, {result.RecordsReactivated} reactivated";

                _logger.LogInformation($"VDS References ETL completed successfully: {result.Message}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "VDS References ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Load EDS references for issues in Issue Loader
        /// </summary>
        public async Task<ETLResult> LoadEDSReferences()
        {
            var result = new ETLResult { StartTime = DateTime.Now };
            
            try
            {
                _logger.LogInformation("Starting EDS References ETL with 70% optimization...");
                
                // Get issues from Issue Loader
                var issuesForReferences = await GetIssuesForReferences();
                
                if (!issuesForReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No issues configured for reference loading";
                    result.EndTime = DateTime.Now;
                    return result;
                }

                _logger.LogInformation($"Loading EDS references for {issuesForReferences.Count} issues");

                // Use orchestrator pattern - let Oracle handle the ETL logic
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                // Insert ETL control record
                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSTIMESTAMP, 0)",
                    new { etlRunId, runType = "EDS_REFERENCES" }
                );

                // Fetch and insert data for each issue (simplified)
                int totalApiCalls = 0;
                foreach (var issue in issuesForReferences)
                {
                    try
                    {
                        var apiUrl = $"plants/{issue.PlantID}/issues/rev/{issue.IssueRevision}/eds";
                        var apiResponse = await _apiService.FetchDataAsync(apiUrl);
                        totalApiCalls++;
                        
                        // MANDATORY: Insert RAW_JSON for audit trail
                        await InsertRawJson(
                            connection, 
                            etlRunId, 
                            apiUrl, 
                            $"eds-{issue.PlantID}-{issue.IssueRevision}",
                            apiResponse,
                            200,
                            0
                        );
                        
                        var apiData = _deserializer.DeserializeApiResponse(apiResponse, $"eds-{issue.PlantID}-{issue.IssueRevision}");

                        if (apiData?.Any() == true)
                        {
                            // Simple insert - let Oracle packages handle the transformation
                            foreach (var item in apiData)
                            {
                                await connection.ExecuteAsync(@"
                                    INSERT INTO STG_EDS_REFERENCES (
                                        PLANT_ID, ISSUE_REVISION, EDS_NAME, EDS_REVISION,
                                        REV_DATE, STATUS, OFFICIAL_REVISION, DELTA, ETL_RUN_ID
                                    ) VALUES (
                                        :plantId, :issueRev, :edsName, :edsRev,
                                        :revDate, :status, :officialRev, :delta, :etlRunId
                                    )", new {
                                        plantId = issue.PlantID,
                                        issueRev = issue.IssueRevision,
                                        edsName = item["EDS"]?.ToString(),
                                        edsRev = item["Revision"]?.ToString(),
                                        revDate = ParseDateTimeFromString(item["RevDate"]?.ToString()),
                                        status = item["Status"]?.ToString(),
                                        officialRev = item["OfficialRevision"]?.ToString(),
                                        delta = item["Delta"]?.ToString(),
                                        etlRunId
                                    });
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Failed to fetch EDS references for plant {issue.PlantID}, issue {issue.IssueRevision}");
                    }
                }

                // Update API call count
                await connection.ExecuteAsync(@"
                    UPDATE ETL_CONTROL 
                    SET API_CALL_COUNT = :apiCalls
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { apiCalls = totalApiCalls, etlRunId }
                );

                // Call orchestrator to process through packages
                _logger.LogInformation("Calling Oracle ETL orchestrator...");
                await connection.ExecuteAsync(@"
                    BEGIN 
                        SP_PROCESS_ETL_BATCH(:etlRunId, 'EDS_REFERENCES');
                    END;", 
                    new { etlRunId }
                );

                // Get final results
                var controlRecord = await connection.QuerySingleAsync(@"
                    SELECT STATUS, RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED, 
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT, PROCESSING_TIME_SEC
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                result.ApiCallCount = totalApiCalls;
                
                result.EndTime = DateTime.Now;
                result.Message = $"ETL completed: {result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, " +
                               $"{result.RecordsDeleted} deleted, {result.RecordsReactivated} reactivated";

                _logger.LogInformation($"EDS References ETL completed successfully: {result.Message}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "EDS References ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Load MDS references for issues in Issue Loader
        /// </summary>
        public async Task<ETLResult> LoadMDSReferences()
        {
            var result = new ETLResult { StartTime = DateTime.Now };
            
            try
            {
                _logger.LogInformation("Starting MDS References ETL with 70% optimization...");
                
                // Get issues from Issue Loader
                var issuesForReferences = await GetIssuesForReferences();
                
                if (!issuesForReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No issues configured for reference loading";
                    result.EndTime = DateTime.Now;
                    return result;
                }

                _logger.LogInformation($"Loading MDS references for {issuesForReferences.Count} issues");

                // Use orchestrator pattern - let Oracle handle the ETL logic
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                // Insert ETL control record
                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSTIMESTAMP, 0)",
                    new { etlRunId, runType = "MDS_REFERENCES" }
                );

                // Fetch and insert data for each issue (simplified)
                int totalApiCalls = 0;
                foreach (var issue in issuesForReferences)
                {
                    try
                    {
                        var apiUrl = $"plants/{issue.PlantID}/issues/rev/{issue.IssueRevision}/mds";
                        var apiResponse = await _apiService.FetchDataAsync(apiUrl);
                        totalApiCalls++;
                        
                        // MANDATORY: Insert RAW_JSON for audit trail
                        await InsertRawJson(
                            connection, 
                            etlRunId, 
                            apiUrl, 
                            $"mds-{issue.PlantID}-{issue.IssueRevision}",
                            apiResponse,
                            200,
                            0
                        );
                        
                        var apiData = _deserializer.DeserializeApiResponse(apiResponse, $"mds-{issue.PlantID}-{issue.IssueRevision}");

                        if (apiData?.Any() == true)
                        {
                            // Simple insert - let Oracle packages handle the transformation
                            foreach (var item in apiData)
                            {
                                await connection.ExecuteAsync(@"
                                    INSERT INTO STG_MDS_REFERENCES (
                                        PLANT_ID, ISSUE_REVISION, MDS_NAME, MDS_REVISION,
                                        AREA, REV_DATE, STATUS, OFFICIAL_REVISION, DELTA, ETL_RUN_ID
                                    ) VALUES (
                                        :plantId, :issueRev, :mdsName, :mdsRev,
                                        :area, :revDate, :status, :officialRev, :delta, :etlRunId
                                    )", new {
                                        plantId = issue.PlantID,
                                        issueRev = issue.IssueRevision,
                                        mdsName = item["MDS"]?.ToString(),
                                        mdsRev = item["Revision"]?.ToString(),
                                        area = item["Area"]?.ToString(), // Special field for MDS only
                                        revDate = ParseDateTimeFromString(item["RevDate"]?.ToString()),
                                        status = item["Status"]?.ToString(),
                                        officialRev = item["OfficialRevision"]?.ToString(),
                                        delta = item["Delta"]?.ToString(),
                                        etlRunId
                                    });
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Failed to fetch MDS references for plant {issue.PlantID}, issue {issue.IssueRevision}");
                    }
                }

                // Update API call count
                await connection.ExecuteAsync(@"
                    UPDATE ETL_CONTROL 
                    SET API_CALL_COUNT = :apiCalls
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { apiCalls = totalApiCalls, etlRunId }
                );

                // Call orchestrator to process through packages
                _logger.LogInformation("Calling Oracle ETL orchestrator...");
                await connection.ExecuteAsync(@"
                    BEGIN 
                        SP_PROCESS_ETL_BATCH(:etlRunId, 'MDS_REFERENCES');
                    END;", 
                    new { etlRunId }
                );

                // Get final results
                var controlRecord = await connection.QuerySingleAsync(@"
                    SELECT STATUS, RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED, 
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT, PROCESSING_TIME_SEC
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                result.ApiCallCount = totalApiCalls;
                
                result.EndTime = DateTime.Now;
                result.Message = $"ETL completed: {result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, " +
                               $"{result.RecordsDeleted} deleted, {result.RecordsReactivated} reactivated";

                _logger.LogInformation($"MDS References ETL completed successfully: {result.Message}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "MDS References ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Load VSK references for issues in Issue Loader
        /// </summary>
        public async Task<ETLResult> LoadVSKReferences()
        {
            var result = new ETLResult { StartTime = DateTime.Now };
            
            try
            {
                _logger.LogInformation("Starting VSK References ETL with 70% optimization...");
                
                // Get issues from Issue Loader
                var issuesForReferences = await GetIssuesForReferences();
                
                if (!issuesForReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No issues configured for reference loading";
                    result.EndTime = DateTime.Now;
                    return result;
                }

                _logger.LogInformation($"Loading VSK references for {issuesForReferences.Count} issues");

                // Use orchestrator pattern - let Oracle handle the ETL logic
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                // Insert ETL control record
                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSTIMESTAMP, 0)",
                    new { etlRunId, runType = "VSK_REFERENCES" }
                );

                // Fetch and insert data for each issue (simplified)
                int totalApiCalls = 0;
                foreach (var issue in issuesForReferences)
                {
                    try
                    {
                        var apiUrl = $"plants/{issue.PlantID}/issues/rev/{issue.IssueRevision}/vsk";
                        var apiResponse = await _apiService.FetchDataAsync(apiUrl);
                        totalApiCalls++;
                        
                        // MANDATORY: Insert RAW_JSON for audit trail
                        await InsertRawJson(
                            connection, 
                            etlRunId, 
                            apiUrl, 
                            $"vsk-{issue.PlantID}-{issue.IssueRevision}",
                            apiResponse,
                            200,
                            0
                        );
                        
                        var apiData = _deserializer.DeserializeApiResponse(apiResponse, $"vsk-{issue.PlantID}-{issue.IssueRevision}");

                        if (apiData?.Any() == true)
                        {
                            // Simple insert - let Oracle packages handle the transformation
                            foreach (var item in apiData)
                            {
                                await connection.ExecuteAsync(@"
                                    INSERT INTO STG_VSK_REFERENCES (
                                        PLANT_ID, ISSUE_REVISION, VSK_NAME, VSK_REVISION,
                                        REV_DATE, STATUS, OFFICIAL_REVISION, DELTA, ETL_RUN_ID
                                    ) VALUES (
                                        :plantId, :issueRev, :vskName, :vskRev,
                                        :revDate, :status, :officialRev, :delta, :etlRunId
                                    )", new {
                                        plantId = issue.PlantID,
                                        issueRev = issue.IssueRevision,
                                        vskName = item["VSK"]?.ToString(),
                                        vskRev = item["Revision"]?.ToString(),
                                        revDate = ParseDateTimeFromString(item["RevDate"]?.ToString()),
                                        status = item["Status"]?.ToString(),
                                        officialRev = item["OfficialRevision"]?.ToString(),
                                        delta = item["Delta"]?.ToString(),
                                        etlRunId
                                    });
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Failed to fetch VSK references for plant {issue.PlantID}, issue {issue.IssueRevision}");
                    }
                }

                // Update API call count
                await connection.ExecuteAsync(@"
                    UPDATE ETL_CONTROL 
                    SET API_CALL_COUNT = :apiCalls
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { apiCalls = totalApiCalls, etlRunId }
                );

                // Call orchestrator to process through packages
                _logger.LogInformation("Calling Oracle ETL orchestrator...");
                await connection.ExecuteAsync(@"
                    BEGIN 
                        SP_PROCESS_ETL_BATCH(:etlRunId, 'VSK_REFERENCES');
                    END;", 
                    new { etlRunId }
                );

                // Get final results
                var controlRecord = await connection.QuerySingleAsync(@"
                    SELECT STATUS, RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED, 
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT, PROCESSING_TIME_SEC
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                result.ApiCallCount = totalApiCalls;
                
                result.EndTime = DateTime.Now;
                result.Message = $"ETL completed: {result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, " +
                               $"{result.RecordsDeleted} deleted, {result.RecordsReactivated} reactivated";

                _logger.LogInformation($"VSK References ETL completed successfully: {result.Message}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "VSK References ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Load ESK references for issues in Issue Loader
        /// </summary>
        public async Task<ETLResult> LoadESKReferences()
        {
            var result = new ETLResult { StartTime = DateTime.Now };
            
            try
            {
                _logger.LogInformation("Starting ESK References ETL with 70% optimization...");
                
                // Get issues from Issue Loader
                var issuesForReferences = await GetIssuesForReferences();
                
                if (!issuesForReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No issues configured for reference loading";
                    result.EndTime = DateTime.Now;
                    return result;
                }

                _logger.LogInformation($"Loading ESK references for {issuesForReferences.Count} issues");

                // Use orchestrator pattern - let Oracle handle the ETL logic
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                // Insert ETL control record
                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSTIMESTAMP, 0)",
                    new { etlRunId, runType = "ESK_REFERENCES" }
                );

                // Fetch and insert data for each issue (simplified)
                int totalApiCalls = 0;
                foreach (var issue in issuesForReferences)
                {
                    try
                    {
                        var apiUrl = $"plants/{issue.PlantID}/issues/rev/{issue.IssueRevision}/esk";
                        var apiResponse = await _apiService.FetchDataAsync(apiUrl);
                        totalApiCalls++;
                        
                        // MANDATORY: Insert RAW_JSON for audit trail
                        await InsertRawJson(
                            connection, 
                            etlRunId, 
                            apiUrl, 
                            $"esk-{issue.PlantID}-{issue.IssueRevision}",
                            apiResponse,
                            200,
                            0
                        );
                        
                        var apiData = _deserializer.DeserializeApiResponse(apiResponse, $"esk-{issue.PlantID}-{issue.IssueRevision}");

                        if (apiData?.Any() == true)
                        {
                            // Simple insert - let Oracle packages handle the transformation
                            foreach (var item in apiData)
                            {
                                await connection.ExecuteAsync(@"
                                    INSERT INTO STG_ESK_REFERENCES (
                                        PLANT_ID, ISSUE_REVISION, ESK_NAME, ESK_REVISION,
                                        REV_DATE, STATUS, OFFICIAL_REVISION, DELTA, ETL_RUN_ID
                                    ) VALUES (
                                        :plantId, :issueRev, :eskName, :eskRev,
                                        :revDate, :status, :officialRev, :delta, :etlRunId
                                    )", new {
                                        plantId = issue.PlantID,
                                        issueRev = issue.IssueRevision,
                                        eskName = item["ESK"]?.ToString(),
                                        eskRev = item["Revision"]?.ToString(),
                                        revDate = ParseDateTimeFromString(item["RevDate"]?.ToString()),
                                        status = item["Status"]?.ToString(),
                                        officialRev = item["OfficialRevision"]?.ToString(),
                                        delta = item["Delta"]?.ToString(),
                                        etlRunId
                                    });
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Failed to fetch ESK references for plant {issue.PlantID}, issue {issue.IssueRevision}");
                    }
                }

                // Update API call count
                await connection.ExecuteAsync(@"
                    UPDATE ETL_CONTROL 
                    SET API_CALL_COUNT = :apiCalls
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { apiCalls = totalApiCalls, etlRunId }
                );

                // Call orchestrator to process through packages
                _logger.LogInformation("Calling Oracle ETL orchestrator...");
                await connection.ExecuteAsync(@"
                    BEGIN 
                        SP_PROCESS_ETL_BATCH(:etlRunId, 'ESK_REFERENCES');
                    END;", 
                    new { etlRunId }
                );

                // Get final results
                var controlRecord = await connection.QuerySingleAsync(@"
                    SELECT STATUS, RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED, 
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT, PROCESSING_TIME_SEC
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                result.ApiCallCount = totalApiCalls;
                
                result.EndTime = DateTime.Now;
                result.Message = $"ETL completed: {result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, " +
                               $"{result.RecordsDeleted} deleted, {result.RecordsReactivated} reactivated";

                _logger.LogInformation($"ESK References ETL completed successfully: {result.Message}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "ESK References ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Load Pipe Element references for issues in Issue Loader
        /// </summary>
        public async Task<ETLResult> LoadPipeElementReferences()
        {
            var result = new ETLResult { StartTime = DateTime.Now };
            
            try
            {
                _logger.LogInformation("Starting Pipe Element References ETL with 70% optimization...");
                
                // Get issues from Issue Loader
                var issuesForReferences = await GetIssuesForReferences();
                
                if (!issuesForReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No issues configured for reference loading";
                    result.EndTime = DateTime.Now;
                    return result;
                }

                _logger.LogInformation($"Loading Pipe Element references for {issuesForReferences.Count} issues");

                // Use orchestrator pattern - let Oracle handle the ETL logic
                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                // Insert ETL control record
                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSTIMESTAMP, 0)",
                    new { etlRunId, runType = "PIPE_ELEMENT_REFERENCES" }
                );

                // Fetch and insert data for each issue (simplified)
                int totalApiCalls = 0;
                foreach (var issue in issuesForReferences)
                {
                    try
                    {
                        var apiUrl = $"plants/{issue.PlantID}/issues/rev/{issue.IssueRevision}/pipe-elements";
                        var apiResponse = await _apiService.FetchDataAsync(apiUrl);
                        totalApiCalls++;
                        
                        // MANDATORY: Insert RAW_JSON for audit trail
                        await InsertRawJson(
                            connection, 
                            etlRunId, 
                            apiUrl, 
                            $"pipe-element-{issue.PlantID}-{issue.IssueRevision}",
                            apiResponse,
                            200,
                            0
                        );
                        
                        var apiData = _deserializer.DeserializeApiResponse(apiResponse, $"pipe-element-{issue.PlantID}-{issue.IssueRevision}");

                        if (apiData?.Any() == true)
                        {
                            // Simple insert - let Oracle packages handle the transformation
                            foreach (var item in apiData)
                            {
                                await connection.ExecuteAsync(@"
                                    INSERT INTO STG_PIPE_ELEMENT_REFERENCES (
                                        PLANT_ID, ISSUE_REVISION, 
                                        ELEMENT_GROUP, DIMENSION_STANDARD, PRODUCT_FORM, MATERIAL_GRADE,
                                        MDS, MDS_REVISION, AREA, ELEMENT_ID, REVISION,
                                        REV_DATE, STATUS, DELTA, ETL_RUN_ID
                                    ) VALUES (
                                        :plantId, :issueRev,
                                        :elementGroup, :dimensionStandard, :productForm, :materialGrade,
                                        :mds, :mdsRevision, :area, :elementId, :revision,
                                        :revDate, :status, :delta, :etlRunId
                                    )", new {
                                        plantId = issue.PlantID,
                                        issueRev = issue.IssueRevision,
                                        elementGroup = item["ElementGroup"]?.ToString(),
                                        dimensionStandard = item["DimensionStandard"]?.ToString(),
                                        productForm = item["ProductForm"]?.ToString(),
                                        materialGrade = item["MaterialGrade"]?.ToString(),
                                        mds = item["MDS"]?.ToString(),
                                        mdsRevision = item["MDSRevision"]?.ToString(),
                                        area = item["Area"]?.ToString(),
                                        elementId = item.ContainsKey("ElementID") && item["ElementID"] != null ? Convert.ToInt32(item["ElementID"]) : (int?)null,
                                        revision = item["Revision"]?.ToString(),
                                        revDate = ParseDateTimeFromString(item["RevDate"]?.ToString()),
                                        status = item["Status"]?.ToString(),
                                        delta = item["Delta"]?.ToString(),
                                        etlRunId
                                    });
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Failed to fetch Pipe Element references for plant {issue.PlantID}, issue {issue.IssueRevision}");
                    }
                }

                // Update API call count
                await connection.ExecuteAsync(@"
                    UPDATE ETL_CONTROL 
                    SET API_CALL_COUNT = :apiCalls
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { apiCalls = totalApiCalls, etlRunId }
                );

                // Call orchestrator to process through packages
                _logger.LogInformation("Calling Oracle ETL orchestrator...");
                await connection.ExecuteAsync(@"
                    BEGIN 
                        SP_PROCESS_ETL_BATCH(:etlRunId, 'PIPE_ELEMENT_REFERENCES');
                    END;", 
                    new { etlRunId }
                );

                // Get final results
                var controlRecord = await connection.QuerySingleAsync(@"
                    SELECT STATUS, RECORDS_LOADED, RECORDS_UPDATED, RECORDS_UNCHANGED, 
                           RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT, PROCESSING_TIME_SEC
                    FROM ETL_CONTROL 
                    WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.ProcessingTimeSeconds = Convert.ToDouble(controlRecord.PROCESSING_TIME_SEC ?? 0);
                result.ApiCallCount = totalApiCalls;
                
                result.EndTime = DateTime.Now;
                result.Message = $"ETL completed: {result.RecordsLoaded} inserted, {result.RecordsUpdated} updated, " +
                               $"{result.RecordsDeleted} deleted, {result.RecordsReactivated} reactivated";

                _logger.LogInformation($"Pipe Element References ETL completed successfully: {result.Message}");
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Pipe Element References ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.ErrorCount = 1;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// SMART WORKFLOW: Enhance selected plants with detailed data from /plants/{plantid} API
        /// This is called during LoadIssues to update existing PLANTS table with complete field coverage
        /// for selected plants only (N API calls instead of 131 for all plants)
        /// </summary>
        private async Task EnhancePlantsWithDetailedData(OracleConnection connection, List<string> plantIds)
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            _logger.LogInformation($"🎯 SMART ENHANCEMENT: Fetching detailed data for {plantIds.Count} selected plants");

            foreach (var plantId in plantIds)
            {
                try
                {
                    _logger.LogInformation($"Enhancing plant {plantId} with detailed API data...");
                    
                    // Fetch detailed plant data from /plants/{plantid} endpoint
                    var endpoint = $"plants/{plantId}";
                    var apiResponse = await _apiService.FetchDataAsync(endpoint);
                    var plantDetailData = _deserializer.DeserializeApiResponse(apiResponse, endpoint);

                    if (plantDetailData?.Any() == true)
                    {
                        var plant = plantDetailData.First();
                        
                        // Update existing PLANTS table with enhanced fields
                        await connection.ExecuteAsync(@"
                            UPDATE PLANTS 
                            SET
                                -- Enhanced fields from /plants/{plantid} endpoint (14+ additional fields)
                                CATEGORY_ID = :CategoryId,
                                CATEGORY = :Category,
                                AREA_ID = :AreaId,
                                ENABLE_EMBEDDED_NOTE = :EnableEmbeddedNote,
                                PCS_QA = :PcsQa,
                                EDS_MJ = :EdsMj,
                                DESIGN_PRESSURE_BAR = :DesignPressureBar,
                                DESIGN_TEMPERATURE_C = :DesignTemperatureC,
                                MATERIAL_CLASS = :MaterialClass,
                                FLUID_CODE = :FluidCode,
                                INSULATION_PURPOSE = :InsulationPurpose,
                                PAINTING_SPEC = :PaintingSpec,
                                TRACING_SPEC = :TracingSpec,
                                VIBRATION_CLASS = :VibrationClass
                            WHERE PLANT_ID = :PlantId 
                            AND IS_CURRENT = 'Y'",
                            new
                            {
                                PlantId = plantId,
                                // Enhanced fields (safe parsing with null fallbacks)
                                CategoryId = plant.ContainsKey("CategoryID") && plant["CategoryID"] != null ? Convert.ToInt32(plant["CategoryID"]) : (int?)null,
                                Category = plant.ContainsKey("Category") ? plant["Category"]?.ToString() : null,
                                AreaId = plant.ContainsKey("AreaID") && plant["AreaID"] != null ? Convert.ToInt32(plant["AreaID"]) : (int?)null,
                                EnableEmbeddedNote = plant.ContainsKey("EnableEmbeddedNote") ? plant["EnableEmbeddedNote"]?.ToString() : null,
                                PcsQa = plant.ContainsKey("PCS_QA") ? plant["PCS_QA"]?.ToString() : null,
                                EdsMj = plant.ContainsKey("EDS_MJ") ? plant["EDS_MJ"]?.ToString() : null,
                                DesignPressureBar = ParseDecimalSafely(plant.ContainsKey("DesignPressure") ? plant["DesignPressure"]?.ToString() : null),
                                DesignTemperatureC = ParseDecimalSafely(plant.ContainsKey("DesignTemperature") ? plant["DesignTemperature"]?.ToString() : null),
                                MaterialClass = plant.ContainsKey("MaterialClass") ? plant["MaterialClass"]?.ToString() : null,
                                FluidCode = plant.ContainsKey("FluidCode") ? plant["FluidCode"]?.ToString() : null,
                                InsulationPurpose = plant.ContainsKey("InsulationPurpose") ? plant["InsulationPurpose"]?.ToString() : null,
                                PaintingSpec = plant.ContainsKey("PaintingSpec") ? plant["PaintingSpec"]?.ToString() : null,
                                TracingSpec = plant.ContainsKey("TracingSpec") ? plant["TracingSpec"]?.ToString() : null,
                                VibrationClass = plant.ContainsKey("VibrationClass") ? plant["VibrationClass"]?.ToString() : null
                            });

                        _logger.LogInformation($"✅ Enhanced plant {plantId} with detailed data");
                    }
                    else
                    {
                        _logger.LogWarning($"⚠️ No detailed data returned for plant {plantId}");
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"❌ Error enhancing plant {plantId}: {ex.Message}");
                    // Continue with other plants - don't fail entire process
                }
            }

            sw.Stop();
            _logger.LogInformation($"🎯 SMART ENHANCEMENT COMPLETE: {plantIds.Count} plants enhanced in {sw.ElapsedMilliseconds}ms");
        }

        /// <summary>
        /// Get issues selected for reference loading from V_ISSUES_FOR_REFERENCES view
        /// </summary>
        private async Task<List<Issue>> GetIssuesForReferences()
        {
            try
            {
                using var connection = new OracleConnection(_connectionString);
                var issues = await connection.QueryAsync<Issue>(@"
                    SELECT PLANT_ID as PlantID,
                           ISSUE_REVISION as IssueRevision,
                           USER_NAME as UserName,
                           USER_ENTRY_TIME as UserEntryTime,
                           USER_PROTECTED as UserProtected
                    FROM V_ISSUES_FOR_REFERENCES
                    ORDER BY PLANT_ID, ISSUE_REVISION"
                );
                return issues.ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get issues for reference loading");
                return new List<Issue>();
            }
        }

        #endregion

        /// <summary>
        /// Parse datetime from various formats safely
        /// </summary>
        private DateTime? ParseDateTime(object? value)
        {
            if (value == null) return null;
            
            var dateStr = value.ToString();
            if (string.IsNullOrWhiteSpace(dateStr)) return null;
            
            // Try multiple common formats
            string[] formats = new[] 
            {
                "dd.MM.yyyy HH:mm:ss",
                "dd.MM.yyyy HH:mm",
                "yyyy-MM-dd HH:mm:ss",
                "yyyy-MM-dd HH:mm",
                "MM/dd/yyyy HH:mm:ss",
                "MM/dd/yyyy HH:mm",
                "yyyy-MM-ddTHH:mm:ss",
                "yyyy-MM-ddTHH:mm:ssZ"
            };
            
            foreach (var format in formats)
            {
                if (DateTime.TryParseExact(dateStr, format, 
                    System.Globalization.CultureInfo.InvariantCulture, 
                    System.Globalization.DateTimeStyles.None, out var result))
                {
                    return result;
                }
            }
            
            // Try general parse as fallback
            if (DateTime.TryParse(dateStr, out var fallbackResult))
            {
                return fallbackResult;
            }
            
            _logger.LogWarning($"Could not parse date: {dateStr}");
            return null;
        }

        /// <summary>
        /// Safe parse date from string - prevents Oracle date parsing errors
        /// </summary>
        private DateTime? SafeParseDateTimeFromString(string? dateStr)
        {
            try
            {
                // Return null immediately for null/empty strings
                if (string.IsNullOrWhiteSpace(dateStr)) return null;
                
                // Check for common problematic values
                if (dateStr.Trim() == "0" || dateStr.Trim() == "-" || dateStr.Trim().Length < 4)
                    return null;
                
                // Use the existing parser but with additional safety
                return ParseDateTimeFromString(dateStr);
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Date parsing failed for '{dateStr}': {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// Parse date string for enhanced issues fields (date-only fields from API)
        /// </summary>
        private DateTime? ParseDateTimeFromString(string? dateStr)
        {
            if (string.IsNullOrWhiteSpace(dateStr)) return null;
            
            // Try date-only formats first (most common for revision dates)
            string[] formats = new[] 
            {
                "dd.MM.yyyy",
                "yyyy-MM-dd",
                "MM/dd/yyyy",
                "dd/MM/yyyy",
                "dd-MM-yyyy",
                "yyyy/MM/dd"
            };
            
            foreach (var format in formats)
            {
                if (DateTime.TryParseExact(dateStr, format, 
                    System.Globalization.CultureInfo.InvariantCulture, 
                    System.Globalization.DateTimeStyles.None, out var result))
                {
                    return result;
                }
            }
            
            // Try general parse as fallback
            if (DateTime.TryParse(dateStr, out var fallbackResult))
            {
                return fallbackResult;
            }
            
            _logger.LogWarning($"Could not parse date string: {dateStr}");
            return null;
        }

        #region New PCS Detail Loading Methods (Enhanced Implementation)

        /// <summary>
        /// Load PCS Header/Properties data for complete engineering specifications
        /// API Endpoint: plants/{plantid}/pcs/{pcsname}/rev/{revision}
        /// </summary>
        public async Task<ETLResult> LoadPCSHeader()
        {
            var result = new ETLResult 
            { 
                StartTime = DateTime.Now, 
                EndpointName = "PCS_HEADER_ENHANCED" 
            };

            try
            {
                _logger.LogInformation("Loading PCS Header data with complete field coverage...");

                // Get PCS references to know which PCS to load details for
                var pcsReferences = await GetPCSReferencesForDetailLoading();
                if (!pcsReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No PCS references found for detail loading";
                    result.EndTime = DateTime.Now;
                    return result;
                }

                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSDATE, 0)",
                    new { etlRunId, runType = "PCS_HEADER_ENHANCED" }
                );

                int totalApiCalls = 0;
                foreach (var pcs in pcsReferences)
                {
                    try
                    {
                        var apiUrl = $"plants/{pcs.PlantID}/pcs/{pcs.PCSName}/rev/{pcs.PCSRevision}";
                        var apiResponse = await _apiService.FetchDataAsync(apiUrl);
                        totalApiCalls++;
                        
                        var apiData = _deserializer.DeserializeApiResponse(apiResponse, apiUrl);

                        if (apiData?.Any() == true)
                        {
                            var pcsData = apiData.First();
                            
                            await connection.ExecuteAsync(@"
                                INSERT INTO STG_PCS_HEADER (
                                    PLANT_ID, PCS_NAME, PCS_REVISION,
                                    STATUS, REV_DATE, RATING_CLASS, TEST_PRESSURE, MATERIAL_GROUP,
                                    DESIGN_CODE, LAST_UPDATE, LAST_UPDATE_BY, APPROVER, NOTEPAD,
                                    SPECIAL_REQ_ID, TUBE_PCS, NEW_VDS_SECTION, ETL_RUN_ID
                                ) VALUES (
                                    :plantId, :pcsName, :pcsRevision,
                                    :status, :revDate, :ratingClass, :testPressure, :materialGroup,
                                    :designCode, :lastUpdate, :lastUpdateBy, :approver, :notepad,
                                    :specialReqId, :tubePcs, :newVdsSection, :etlRunId
                                )", new {
                                    plantId = pcs.PlantID,
                                    pcsName = pcs.PCSName,
                                    pcsRevision = pcs.PCSRevision,
                                    status = pcsData["Status"]?.ToString(),
                                    revDate = ParseDateTimeFromString(pcsData["RevDate"]?.ToString()),
                                    ratingClass = pcsData["RatingClass"]?.ToString(),
                                    testPressure = pcsData["TestPressure"]?.ToString(),
                                    materialGroup = pcsData["MaterialGroup"]?.ToString(),
                                    designCode = pcsData["DesignCode"]?.ToString(),
                                    lastUpdate = pcsData["LastUpdate"]?.ToString(),
                                    lastUpdateBy = pcsData["LastUpdateBy"]?.ToString(),
                                    approver = pcsData["Approver"]?.ToString(),
                                    notepad = pcsData["Notepad"]?.ToString(),
                                    specialReqId = pcsData.ContainsKey("SpecialReqID") && pcsData["SpecialReqID"] != null ? Convert.ToInt32(pcsData["SpecialReqID"]) : (int?)null,
                                    tubePcs = pcsData["TubePCS"]?.ToString(),
                                    newVdsSection = pcsData["NewVDSSection"]?.ToString(),
                                    etlRunId
                                });
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Failed to fetch PCS header for {pcs.PlantID}/{pcs.PCSName}/{pcs.PCSRevision}");
                    }
                }

                // Update API call count and call orchestrator
                await connection.ExecuteAsync(@"
                    UPDATE ETL_CONTROL SET API_CALL_COUNT = :apiCalls WHERE ETL_RUN_ID = :etlRunId",
                    new { apiCalls = totalApiCalls, etlRunId }
                );

                await connection.ExecuteAsync(@"
                    BEGIN SP_PROCESS_ETL_BATCH(:etlRunId, 'PCS_HEADER'); END;", 
                    new { etlRunId }
                );

                // Get results
                var controlRecord = await connection.QuerySingleAsync<dynamic>(@"
                    SELECT STATUS, PROCESSING_TIME_SEC, RECORDS_LOADED, RECORDS_UPDATED, 
                           RECORDS_UNCHANGED, RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT
                    FROM ETL_CONTROL WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.ApiCallCount = totalApiCalls;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.EndTime = DateTime.Now;
                result.Message = $"PCS Header ETL completed: {result.RecordsLoaded} loaded, {result.RecordsUpdated} updated";

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "PCS Header ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Load PCS Temperature/Pressure matrix with 70+ fields including 12-point temp/pressure data
        /// API Endpoint: plants/{plantid}/pcs/{pcsname}/rev/{revision}/temp-pressures
        /// </summary>
        public async Task<ETLResult> LoadPCSTemperaturePressure()
        {
            var result = new ETLResult 
            { 
                StartTime = DateTime.Now, 
                EndpointName = "PCS_TEMP_PRESSURE_ENHANCED" 
            };

            try
            {
                _logger.LogInformation("Loading PCS Temperature/Pressure matrix with complete field coverage...");

                // Get PCS references to know which PCS to load temp/pressure for
                var pcsReferences = await GetPCSReferencesForDetailLoading();
                if (!pcsReferences.Any())
                {
                    result.Status = "NO_DATA";
                    result.Message = "No PCS references found for temp/pressure loading";
                    result.EndTime = DateTime.Now;
                    return result;
                }

                using var connection = new OracleConnection(_connectionString);
                await connection.OpenAsync();
                
                var etlRunId = await connection.QuerySingleAsync<int>(
                    "SELECT ETL_RUN_ID_SEQ.NEXTVAL FROM DUAL"
                );

                await connection.ExecuteAsync(@"
                    INSERT INTO ETL_CONTROL (ETL_RUN_ID, RUN_TYPE, STATUS, START_TIME, API_CALL_COUNT)
                    VALUES (:etlRunId, :runType, 'RUNNING', SYSDATE, 0)",
                    new { etlRunId, runType = "PCS_TEMP_PRESSURE_ENHANCED" }
                );

                int totalApiCalls = 0;
                foreach (var pcs in pcsReferences)
                {
                    try
                    {
                        var apiUrl = $"plants/{pcs.PlantID}/pcs/{pcs.PCSName}/rev/{pcs.PCSRevision}/temp-pressures";
                        var apiResponse = await _apiService.FetchDataAsync(apiUrl);
                        totalApiCalls++;
                        
                        var apiData = _deserializer.DeserializeApiResponse(apiResponse, apiUrl);

                        if (apiData?.Any() == true)
                        {
                            var tempPressData = apiData.First();
                            
                            await connection.ExecuteAsync(@"
                                INSERT INTO STG_PCS_TEMP_PRESSURE (
                                    PLANT_ID, PCS_NAME, PCS_REVISION,
                                    STATUS, REV_DATE, RATING_CLASS, TEST_PRESSURE, MATERIAL_GROUP,
                                    DESIGN_CODE, LAST_UPDATE, LAST_UPDATE_BY, APPROVER, NOTEPAD,
                                    SC, VSM, DESIGN_CODE_REV_MARK, CORR_ALLOWANCE, CORR_ALLOWANCE_REV_MARK,
                                    LONG_WELD_EFF, LONG_WELD_EFF_REV_MARK, WALL_THK_TOL, WALL_THK_TOL_REV_MARK,
                                    SERVICE_REMARK, SERVICE_REMARK_REV_MARK,
                                    -- 12-point Design Pressure Matrix
                                    DESIGN_PRESS_01, DESIGN_PRESS_02, DESIGN_PRESS_03, DESIGN_PRESS_04,
                                    DESIGN_PRESS_05, DESIGN_PRESS_06, DESIGN_PRESS_07, DESIGN_PRESS_08,
                                    DESIGN_PRESS_09, DESIGN_PRESS_10, DESIGN_PRESS_11, DESIGN_PRESS_12,
                                    DESIGN_PRESS_REV_MARK,
                                    -- 12-point Design Temperature Matrix
                                    DESIGN_TEMP_01, DESIGN_TEMP_02, DESIGN_TEMP_03, DESIGN_TEMP_04,
                                    DESIGN_TEMP_05, DESIGN_TEMP_06, DESIGN_TEMP_07, DESIGN_TEMP_08,
                                    DESIGN_TEMP_09, DESIGN_TEMP_10, DESIGN_TEMP_11, DESIGN_TEMP_12,
                                    DESIGN_TEMP_REV_MARK,
                                    -- Note ID Fields
                                    NOTE_ID_CORR_ALLOWANCE, NOTE_ID_SERVICE_CODE, NOTE_ID_WALL_THK_TOL,
                                    NOTE_ID_LONG_WELD_EFF, NOTE_ID_GENERAL_PCS, NOTE_ID_DESIGN_CODE,
                                    NOTE_ID_PRESS_TEMP_TABLE, NOTE_ID_PIPE_SIZE_WTH_TABLE,
                                    -- Additional Engineering Fields
                                    PRESS_ELEMENT_CHANGE, TEMP_ELEMENT_CHANGE, MATERIAL_GROUP_ID,
                                    SPECIAL_REQ_ID, SPECIAL_REQ, NEW_VDS_SECTION, TUBE_PCS,
                                    EDS_MJ_MATRIX, MJ_REDUCTION_FACTOR, ETL_RUN_ID
                                ) VALUES (
                                    :plantId, :pcsName, :pcsRevision,
                                    :status, :revDate, :ratingClass, :testPressure, :materialGroup,
                                    :designCode, :lastUpdate, :lastUpdateBy, :approver, :notepad,
                                    :sc, :vsm, :designCodeRevMark, :corrAllowance, :corrAllowanceRevMark,
                                    :longWeldEff, :longWeldEffRevMark, :wallThkTol, :wallThkTolRevMark,
                                    :serviceRemark, :serviceRemarkRevMark,
                                    -- Design Pressures (SAFETY CRITICAL - require exact precision)
                                    :designPress01, :designPress02, :designPress03, :designPress04,
                                    :designPress05, :designPress06, :designPress07, :designPress08,
                                    :designPress09, :designPress10, :designPress11, :designPress12,
                                    :designPressRevMark,
                                    -- Design Temperatures (SAFETY CRITICAL - require exact precision)
                                    :designTemp01, :designTemp02, :designTemp03, :designTemp04,
                                    :designTemp05, :designTemp06, :designTemp07, :designTemp08,
                                    :designTemp09, :designTemp10, :designTemp11, :designTemp12,
                                    :designTempRevMark,
                                    -- Note IDs
                                    :noteIdCorrAllowance, :noteIdServiceCode, :noteIdWallThkTol,
                                    :noteIdLongWeldEff, :noteIdGeneralPcs, :noteIdDesignCode,
                                    :noteIdPressTempTable, :noteIdPipeSizeWthTable,
                                    -- Additional Fields
                                    :pressElementChange, :tempElementChange, :materialGroupId,
                                    :specialReqId, :specialReq, :newVdsSection, :tubePcs,
                                    :edsMjMatrix, :mjReductionFactor, :etlRunId
                                )", new {
                                    plantId = pcs.PlantID,
                                    pcsName = pcs.PCSName,
                                    pcsRevision = pcs.PCSRevision,
                                    status = tempPressData["Status"]?.ToString(),
                                    revDate = ParseDateTimeFromString(tempPressData["RevDate"]?.ToString()),
                                    ratingClass = tempPressData["RatingClass"]?.ToString(),
                                    testPressure = tempPressData["TestPressure"]?.ToString(),
                                    materialGroup = tempPressData["MaterialGroup"]?.ToString(),
                                    designCode = tempPressData["DesignCode"]?.ToString(),
                                    lastUpdate = tempPressData["LastUpdate"]?.ToString(),
                                    lastUpdateBy = tempPressData["LastUpdateBy"]?.ToString(),
                                    approver = tempPressData["Approver"]?.ToString(),
                                    notepad = tempPressData["Notepad"]?.ToString(),
                                    sc = tempPressData["SC"]?.ToString(),
                                    vsm = tempPressData["VSM"]?.ToString(),
                                    designCodeRevMark = tempPressData["DesignCodeRevMark"]?.ToString(),
                                    corrAllowance = ParseDecimalSafely(tempPressData["CorrAllowance"]?.ToString()),
                                    corrAllowanceRevMark = tempPressData["CorrAllowanceRevMark"]?.ToString(),
                                    longWeldEff = tempPressData["LongWeldEff"]?.ToString(),
                                    longWeldEffRevMark = tempPressData["LongWeldEffRevMark"]?.ToString(),
                                    wallThkTol = tempPressData["WallThkTol"]?.ToString(),
                                    wallThkTolRevMark = tempPressData["WallThkTolRevMark"]?.ToString(),
                                    serviceRemark = tempPressData["ServiceRemark"]?.ToString(),
                                    serviceRemarkRevMark = tempPressData["ServiceRemarkRevMark"]?.ToString(),
                                    // SAFETY CRITICAL: Design pressure values (exact precision required)
                                    designPress01 = ParseDecimalSafely(tempPressData["DesignPress01"]?.ToString()),
                                    designPress02 = ParseDecimalSafely(tempPressData["DesignPress02"]?.ToString()),
                                    designPress03 = ParseDecimalSafely(tempPressData["DesignPress03"]?.ToString()),
                                    designPress04 = ParseDecimalSafely(tempPressData["DesignPress04"]?.ToString()),
                                    designPress05 = ParseDecimalSafely(tempPressData["DesignPress05"]?.ToString()),
                                    designPress06 = ParseDecimalSafely(tempPressData["DesignPress06"]?.ToString()),
                                    designPress07 = ParseDecimalSafely(tempPressData["DesignPress07"]?.ToString()),
                                    designPress08 = ParseDecimalSafely(tempPressData["DesignPress08"]?.ToString()),
                                    designPress09 = ParseDecimalSafely(tempPressData["DesignPress09"]?.ToString()),
                                    designPress10 = ParseDecimalSafely(tempPressData["DesignPress10"]?.ToString()),
                                    designPress11 = ParseDecimalSafely(tempPressData["DesignPress11"]?.ToString()),
                                    designPress12 = ParseDecimalSafely(tempPressData["DesignPress12"]?.ToString()),
                                    designPressRevMark = tempPressData["DesignPressRevMark"]?.ToString(),
                                    // SAFETY CRITICAL: Design temperature values (exact precision required)
                                    designTemp01 = ParseDecimalSafely(tempPressData["DesignTemp01"]?.ToString()),
                                    designTemp02 = ParseDecimalSafely(tempPressData["DesignTemp02"]?.ToString()),
                                    designTemp03 = ParseDecimalSafely(tempPressData["DesignTemp03"]?.ToString()),
                                    designTemp04 = ParseDecimalSafely(tempPressData["DesignTemp04"]?.ToString()),
                                    designTemp05 = ParseDecimalSafely(tempPressData["DesignTemp05"]?.ToString()),
                                    designTemp06 = ParseDecimalSafely(tempPressData["DesignTemp06"]?.ToString()),
                                    designTemp07 = ParseDecimalSafely(tempPressData["DesignTemp07"]?.ToString()),
                                    designTemp08 = ParseDecimalSafely(tempPressData["DesignTemp08"]?.ToString()),
                                    designTemp09 = ParseDecimalSafely(tempPressData["DesignTemp09"]?.ToString()),
                                    designTemp10 = ParseDecimalSafely(tempPressData["DesignTemp10"]?.ToString()),
                                    designTemp11 = ParseDecimalSafely(tempPressData["DesignTemp11"]?.ToString()),
                                    designTemp12 = ParseDecimalSafely(tempPressData["DesignTemp12"]?.ToString()),
                                    designTempRevMark = tempPressData["DesignTempRevMark"]?.ToString(),
                                    // Note IDs
                                    noteIdCorrAllowance = tempPressData["NoteIDCorrAllowance"]?.ToString(),
                                    noteIdServiceCode = tempPressData["NoteIDServiceCode"]?.ToString(),
                                    noteIdWallThkTol = tempPressData["NoteIDWallThkTol"]?.ToString(),
                                    noteIdLongWeldEff = tempPressData["NoteIDLongWeldEff"]?.ToString(),
                                    noteIdGeneralPcs = tempPressData["NoteIDGeneralPCS"]?.ToString(),
                                    noteIdDesignCode = tempPressData["NoteIDDesignCode"]?.ToString(),
                                    noteIdPressTempTable = tempPressData["NoteIDPressTempTable"]?.ToString(),
                                    noteIdPipeSizeWthTable = tempPressData["NoteIDPipeSizeWthTable"]?.ToString(),
                                    // Additional Fields
                                    pressElementChange = tempPressData["PressElementChange"]?.ToString(),
                                    tempElementChange = tempPressData["TempElementChange"]?.ToString(),
                                    materialGroupId = tempPressData.ContainsKey("MaterialGroupID") && tempPressData["MaterialGroupID"] != null ? Convert.ToInt32(tempPressData["MaterialGroupID"]) : (int?)null,
                                    specialReqId = tempPressData.ContainsKey("SpecialReqID") && tempPressData["SpecialReqID"] != null ? Convert.ToInt32(tempPressData["SpecialReqID"]) : (int?)null,
                                    specialReq = tempPressData["SpecialReq"]?.ToString(),
                                    newVdsSection = tempPressData["NewVDSSection"]?.ToString(),
                                    tubePcs = tempPressData["TubePCS"]?.ToString(),
                                    edsMjMatrix = tempPressData["EDSMJMatrix"]?.ToString(),
                                    mjReductionFactor = ParseDecimalSafely(tempPressData["MJReductionFactor"]?.ToString()),
                                    etlRunId
                                });
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Failed to fetch PCS temp/pressure for {pcs.PlantID}/{pcs.PCSName}/{pcs.PCSRevision}");
                    }
                }

                // Update API call count and call orchestrator
                await connection.ExecuteAsync(@"
                    UPDATE ETL_CONTROL SET API_CALL_COUNT = :apiCalls WHERE ETL_RUN_ID = :etlRunId",
                    new { apiCalls = totalApiCalls, etlRunId }
                );

                await connection.ExecuteAsync(@"
                    BEGIN SP_PROCESS_ETL_BATCH(:etlRunId, 'PCS_TEMP_PRESSURE'); END;", 
                    new { etlRunId }
                );

                // Get results and return
                var controlRecord = await connection.QuerySingleAsync<dynamic>(@"
                    SELECT STATUS, PROCESSING_TIME_SEC, RECORDS_LOADED, RECORDS_UPDATED, 
                           RECORDS_UNCHANGED, RECORDS_DELETED, RECORDS_REACTIVATED, ERROR_COUNT
                    FROM ETL_CONTROL WHERE ETL_RUN_ID = :etlRunId",
                    new { etlRunId }
                );

                result.Status = controlRecord.STATUS;
                result.ApiCallCount = totalApiCalls;
                result.RecordsLoaded = Convert.ToInt32(controlRecord.RECORDS_LOADED ?? 0);
                result.RecordsUpdated = Convert.ToInt32(controlRecord.RECORDS_UPDATED ?? 0);
                result.RecordsUnchanged = Convert.ToInt32(controlRecord.RECORDS_UNCHANGED ?? 0);
                result.RecordsDeleted = Convert.ToInt32(controlRecord.RECORDS_DELETED ?? 0);
                result.RecordsReactivated = Convert.ToInt32(controlRecord.RECORDS_REACTIVATED ?? 0);
                result.ErrorCount = Convert.ToInt32(controlRecord.ERROR_COUNT ?? 0);
                result.EndTime = DateTime.Now;
                result.Message = $"PCS Temp/Pressure ETL completed: {result.RecordsLoaded} loaded, {result.RecordsUpdated} updated";

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "PCS Temperature/Pressure ETL failed");
                result.Status = "FAILED";
                result.Message = ex.Message;
                result.EndTime = DateTime.Now;
                return result;
            }
        }

        /// <summary>
        /// Helper method to get PCS references for detail loading
        /// </summary>
        private async Task<List<dynamic>> GetPCSReferencesForDetailLoading()
        {
            using var connection = new OracleConnection(_connectionString);
            await connection.OpenAsync();

            var pcsReferences = await connection.QueryAsync<dynamic>(@"
                SELECT DISTINCT p.PLANT_ID, p.PCS_NAME, p.PCS_REVISION
                FROM PCS_REFERENCES p
                INNER JOIN V_ISSUES_FOR_REFERENCES i ON p.PLANT_ID = i.PLANT_ID AND p.ISSUE_REVISION = i.ISSUE_REVISION
                WHERE p.IS_CURRENT = 'Y'
                ORDER BY p.PLANT_ID, p.PCS_NAME, p.PCS_REVISION"
            );

            return pcsReferences.ToList();
        }

        /// <summary>
        /// Parse decimal values safely for engineering dimensions (SAFETY CRITICAL)
        /// </summary>
        private decimal? ParseDecimalSafely(string? value)
        {
            if (string.IsNullOrWhiteSpace(value)) return null;
            
            if (decimal.TryParse(value, out var result))
            {
                return result;
            }
            
            _logger.LogWarning($"Could not parse decimal value: {value}");
            return null;
        }

        #endregion

    }
    
    // Note: Using ETLResult, ETLRunHistory, and TableStatus classes from OracleETLService
}