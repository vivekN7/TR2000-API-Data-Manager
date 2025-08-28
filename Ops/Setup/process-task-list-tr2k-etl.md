# Task List Management & Processing Guidelines

Guidelines for managing task lists in markdown files to track progress on completing the TR2000 ETL System PRD.

## 🔴 CRITICAL RULES

### 1. SQL Code Execution
**NEVER write SQL code directly in command line unless it's a one-off temporary query!**
- **ALWAYS use the modular deploy system** in `/Database/deploy/`
- **CREATE proper .sql files** for any code that needs to be implemented
- **Only exceptions**: Quick SELECT queries for checking data, one-time fixes
- **If creating procedures, views, packages, tables**: MUST go in proper deploy folder
- **If running tests**: Use the scripts in `/Database/scripts/`

### 2. After Running Tests - MANDATORY FIX
**ALWAYS run reference validity fix after test suites!**
```sql
@Database/scripts/fix_reference_validity.sql
```
**Why**: The conductor tests call `run_full_etl()` which processes ALL selected plants (including real ones: 124, 34), causing reference cascades to mark them invalid. This is a known test isolation issue.

**Test sequence should be:**
1. Run tests: `@Database/scripts/run_comprehensive_tests.sql`
2. Fix references: `@Database/scripts/fix_reference_validity.sql` 
3. Verify: `@Database/scripts/final_system_test.sql`

## 📊 CURRENT STATUS (Session 17 Complete - 2025-12-29)

### Quick Status
- **Completed**: Tasks 1-8 ✅ FULLY TESTED AND OPTIMIZED
- **System State**: 130 plants, 20 issues, 4,572 references, 362 PCS revisions
- **Test Coverage**: ~40-45% (32 tests, 29 passing)
- **Next Priority**: Task 9 - VDS Details (44k+ records)
- **Documentation**: Fully updated to Version 4.0

### Session 17 Achievements (2025-12-29)
- ✅ Task 8 (PCS Details) COMPLETE with 82% API optimization
- ✅ Added PCS_LOADING_MODE setting (OFFICIAL_ONLY default)
- ✅ Fixed PCS JSON parsing paths for all 6 endpoints
- ✅ Removed issue_revision dependency from PCS details
- ✅ Added 5 new critical tests (all passing)
- ✅ Merged all incremental scripts and archived

### Session 13 Achievements (2025-08-27)
- ✅ TR2000_UTIL proxy migration COMPLETE
- ✅ Fixed ALL invalid objects (0 remaining)
- ✅ Updated all packages to new column names
- ✅ Merged all incremental scripts to masters
- ✅ Archived all temporary scripts
- ✅ Created deployment readiness check script
- ✅ API connectivity verified and working
- ✅ Documentation updated and organized

### ✅ Ready for Testing - All Prerequisites Complete:
1. TR2000_UTIL implemented and working ✅
2. All invalid objects fixed (0 remaining) ✅
3. TR2000_CRED documented (optional for now) ✅

### Tables Needing Discussion
- **CONTROL_ENDPOINT_STATE**: Not used (0 records) - keep for retry logic?
- **EXTERNAL_SYSTEM_REFS**: Not used (0 records) - keep for future integrations?
- **TEMP_TEST_DATA**: Not used (0 records) - useful for mock testing?

### Previous Session Highlights
- Session 15: Comprehensive testing, reference validity fixes
- Session 13: TR2000_UTIL proxy migration
- Session 11: Task 7 Complete - Reference Tables Implementation
- Session 10: GUID Architecture implementation
- Session 9: CASCADE MANAGEMENT SYSTEM deployed

### Session 10 Achievements
- ✅ Transitioned from Docker to PowerShell direct access (connection strings updated)
- ✅ GUID Architecture implemented and merged (correlation tracking ready)
- ✅ Cleaned up 16 unnecessary APEX views (0 invalid objects remaining)
- ✅ Documentation consolidated to 3 clean files (40% reduction in process-task-list)
- ✅ Incremental scripts properly merged and archived

### Session 9 Achievements
- ✅ CASCADE MANAGEMENT SYSTEM DEPLOYED (Plant→Issues cascade working)
- ✅ PKG_SIMPLE_TESTS fixed (all 5 critical tests passing)
- ✅ GUID design documented (implementation was in Session 10)

### System Statistics
- 130 plants loaded from API
- 12 issues for JSP2, 8 for GRANE
- 11 tables with full documentation
- 11 views with COMMENT descriptions
- 44 indexes optimized
- 94+ columns documented
- All objects VALID

## 🔴 CRITICAL PROJECT RULES

### Git Workflow
- **Commit locally frequently** - Track all changes
- **NEVER push to GitHub without explicit permission** - Ask first!
- **Use conventional commits**: feat:, fix:, refactor:, docs:, test:

### Database Safety
- **ALWAYS use transactions** for UPDATE/DELETE operations
- **Test in development first** before production changes
- **Run tests before committing**: `EXEC PKG_SIMPLE_TESTS.run_critical_tests;`
- **Zero tolerance for data loss** - Use soft deletes (is_valid='N')
- **NEVER use UTL_HTTP** - Only use APEX_WEB_SERVICE for all HTTP/HTTPS calls

### Test Data Isolation Rules
- **ALL test data MUST use 'TEST_' prefix** for plant_id or issue_revision
- **NEVER mix test data with real data** - causes cascade contamination
- **Clean test data regularly**: `EXEC PKG_TEST_ISOLATION.clean_all_test_data;`
- **When in doubt, refresh from API**: `EXEC refresh_all_data_from_api;`
- **Check for contamination**: `EXEC PKG_TEST_ISOLATION.validate_no_test_contamination;`

### Temporary Objects
- **Prefix with TEMP_**: Any temporary tables/views (e.g., TEMP_DEBUG_LOG)
- **Clean up before commit**: Remove all TEMP_ objects
- **Document if needed temporarily**: Explain why it exists

## 📋 TASK IMPLEMENTATION PROTOCOL

### Sub-task Execution
- **One sub-task at a time:** Do **NOT** start the next sub‑task until user permission ("yes" or "y")
- **API Call Limits:**
  - Can run test scripts directly without user permission for up to 5 API calls
  - MUST get user permission before running scripts that make more than 5 API calls
  - Always aim for minimal API calls to avoid hammering endpoints

### Completion Protocol
1. When you finish a **sub‑task**, immediately mark it as completed `[x]`
2. If **all** subtasks underneath a parent task are now `[x]`:
   - **First**: Run the ETL test suite: `EXEC PKG_SIMPLE_TESTS.run_critical_tests;`
   - **Only if all tests pass**: Check for any TEMP_* objects to clean up
   - **Clean up**: Remove any temporary files and temporary code
   - **Commit**: Use descriptive commit message:
     ```bash
     git commit -m "feat: add payment validation logic" -m "- Validates card type and expiry" -m "- Adds unit tests for edge cases" -m "Related to T123 in PRD"
     ```
3. Mark the **parent task** as completed
4. Stop after each sub‑task and wait for user's go‑ahead

### 🔴 CRITICAL: Incremental Script Management
**NEVER leave fixes in incremental scripts for next session!**

When you create an incremental fix script:
1. **Test it thoroughly** - Ensure the fix works correctly
2. **IMMEDIATELY merge into master** deployment files:
   - If fixing a table → Update `01_tables/[appropriate_file].sql`
   - If fixing a package → Update `03_packages/[appropriate_file].sql`
   - If fixing a view → Update `02_views/[appropriate_file].sql`
3. **Archive the incremental** script:
   - Move to `incremental/archived_merged/`
   - Rename with `_MERGED` suffix and date
   - Example: `fix_pipe_element_2025-08-27_MERGED.sql`
4. **Test the master deployment** to ensure it works
5. **Document what was merged** in commit message

**Why this matters:** Incremental scripts get forgotten between sessions, causing the same bugs to reappear when deploying from master files. This wastes hours of debugging time!

### Task List Maintenance
- **Update tasks-tr2k-etl.md** - Mark tasks [x] when complete
- Add newly discovered tasks as they emerge
- **DO NOT create** session handoff files, status updates, or additional documentation

## 🚀 QUICK COMMANDS (Copy & Paste Ready)

### Database Connection
```bash
# Windows PowerShell (Direct):
sqlplus TR2000_STAGING/piping@localhost:1521/XEPDB1

# Docker/WSL:
export LD_LIBRARY_PATH=/workspace/TR2000/TR2K/Database/tools/instantclient:$LD_LIBRARY_PATH && /workspace/TR2000/TR2K/Database/tools/instantclient/sqlplus -S TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1
```

### Test API Connectivity
```sql
VAR status VARCHAR2(50);
VAR msg VARCHAR2(4000);
EXEC pkg_api_client.refresh_plants_from_api(:status, :msg);
PRINT status;
PRINT msg;
```

### Run Test Suite
```sql
EXEC PKG_SIMPLE_TESTS.run_critical_tests;
SELECT * FROM V_TEST_BY_FLOW_STEP;
SELECT * FROM V_TEST_FAILURE_ANALYSIS;
EXEC PKG_SIMPLE_TESTS.cleanup_test_data;
```

## 💾 DATABASE DEPLOYMENT SYSTEM

### Directory Structure
```
Database/
├── deploy/                # PRODUCTION DEPLOYMENT
│   ├── 01_tables/        # Core table definitions ONLY
│   ├── 02_views/         # View definitions ONLY
│   ├── 03_packages/      # Package specs and bodies ONLY
│   ├── 04_procedures/    # Standalone procedures ONLY
│   ├── 05_data/          # Initial/seed data ONLY
│   ├── 06_testing/       # Test framework ONLY
│   ├── incremental/      # Schema CHANGES go here (and ONLY here!)
│   │   ├── [active]      # Scripts not yet merged or one-time ops
│   │   └── archived_merged/  # Scripts that have been merged
│   └── deploy_full.sql   # Master script that runs everything
│
├── scripts/              # UTILITY SCRIPTS (not for deployment)
│   ├── test_*.sql       # Testing utilities
│   ├── fix_*.sql        # Troubleshooting tools
│   └── check_*.sql      # Analysis queries
│
└── tools/               # External tools (sqlplus, instant client)
```

### Script Types & Usage

#### 1. Main Deployment Scripts (`/Database/deploy/[01_tables, 03_packages, etc]`)
- **Purpose**: Core schema definitions
- **When to modify**: Only when merging permanent changes from incremental
- **Examples**: CREATE TABLE, CREATE PACKAGE

#### 2. Incremental Scripts (`/Database/deploy/incremental/`)
- **Purpose**: One-time schema changes and migrations
- **Current Active Scripts**:
  - `cleanup_unnecessary_objects.sql` (one-time, don't merge)
  - `task7_reference_tables_FUTURE.sql` (for Task 7)
- **Archived Scripts**:
  - `add_guid_support_MERGED_2025-08-26.sql`
  - `enhance_pkg_api_client_guid_MERGED_2025-08-26.sql`

**Merge Process**:
1. Create incremental script with date (e.g., `add_feature_2025-08-26.sql`)
2. Test and deploy
3. If permanent → Merge into main scripts → Archive with _MERGED suffix
4. If one-time → Keep in incremental folder

#### 3. Utility Scripts (`/Database/scripts/`)
- **Purpose**: Testing and troubleshooting tools (NOT for deployment)
- **Examples**: 
  - `test_https_connectivity.sql` - Test APEX_WEB_SERVICE
  - `fix_wallet_certificates.sql` - Fix Oracle wallet
  - `rename_views_to_new_convention.sql` - One-time cleanup

### Deployment Commands

#### Safe Deployments (No Data Loss)
```sql
-- Deploy all views:
@deploy/02_views/deploy_all_views.sql

-- Deploy all packages:
@deploy/03_packages/deploy_all_packages.sql

-- Deploy specific package:
@deploy/03_packages/06_pkg_api_client.sql
```

#### Full Deployment (WARNING: Drops Everything!)
```sql
-- Only use when starting fresh:
@deploy/deploy_full.sql
```

### Important Rules
1. **ONE incremental folder ONLY**: `/Database/deploy/incremental/`
2. **NEVER create incremental folders inside object folders**
3. **NEVER create incremental folders outside deploy**
4. **NEVER run table scripts in production without backup** (they DROP data)

## 🧪 TESTING FRAMEWORK

### Location & Structure
- **Location**: `/Database/deploy/06_testing/`
- **Core Package**: PKG_SIMPLE_TESTS with 5 critical tests
- **Test Matrix**: `/Ops/Testing/ETL_Test_Matrix.md` - MANDATORY reference
- **Enhanced Tracking**: TEST_RESULTS table with detailed columns:
  - data_flow_step (API_TO_RAW, RAW_TO_STG, STG_TO_CORE)
  - test_category (CONNECTIVITY, PARSING, VALIDATION)
  - failure_mode (TIMEOUT, PARSE_ERROR, FK_VIOLATION)
  - test_parameters (JSON for reproducibility)

### Testing Requirements
- **MANDATORY**: Before implementing ANY new data flow step (Tasks 7-12):
  1. Review ETL_Test_Matrix.md for that step
  2. Implement ALL missing test procedures
  3. Run tests BEFORE and AFTER implementation
  4. Update test matrix with new scenarios
- **Coverage**: Each data flow step needs 80%+ coverage before proceeding
- **Test Data**: All test records MUST use 'TEST_' prefix

### Current Test Coverage
- API → RAW_JSON: 2/14 scenarios (14%)
- RAW_JSON → STG: 2/8 scenarios (25%)
- STG → CORE: 1/11 scenarios (9%)
- Selection Management: 1/6 scenarios (17%)
- Error Logging: 1/5 scenarios (20%)

### Task 7 Required Tests
```sql
-- MUST implement before coding:
FUNCTION test_invalid_fk RETURN VARCHAR2;      -- Foreign key violations
FUNCTION test_reference_cascade RETURN VARCHAR2; -- Cascade deletion
FUNCTION test_reference_parsing RETURN VARCHAR2; -- JSON structure
```

## 🔧 SYSTEM ARCHITECTURE

### Database Configuration
- **Host**: localhost (or host.docker.internal in Docker)
- **Port**: 1521
- **SID**: XEPDB1
- **User**: TR2000_STAGING
- **Password**: piping

### API Configuration
- **Base URL**: https://equinor.pipespec-api.presight.com
- **Method**: APEX_WEB_SERVICE (NEVER use UTL_HTTP)
- **Wallet Path**: C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet
- **Wallet Password**: WalletPass123

### APEX Application
- **Application**: TR2000 ETL Manager (App 101)
- **Access**: http://localhost:8888/ords/
- **Workspace**: TR2000_ETL
- **Username**: ADMIN
- **Password**: Apex!1985
- **Key Page**: Page 5 (ETL Control Center)

### Object Naming Conventions
- **Views**: `V_*` - General reporting views
- **Procedures**: `UI_*` - UI-only procedures (distinguish from core ETL)
- **Functions**: `UI_*` - UI-only functions
- **Temporary Objects**: `TEMP_*` - Must be cleaned before commit

### Data Persistence Strategy
Control tables use MERGE pattern to preserve user settings:
- CONTROL_SETTINGS - preserves custom API URLs, timeouts
- CONTROL_ENDPOINTS - preserves endpoint configurations
- SELECTION_LOADER - preserves test plant selections
- No data loss during structure updates

## 🌊 ETL DATA FLOW & SELECTION MANAGEMENT

### 1. Initial Data Population
- **One-time load**: Fetch ALL plants from API to populate PLANTS table
- Provides master list for user selection
- No issues loaded initially (API optimization)

### 2. User Selection Workflow
1. **Plant Selection**:
   - User selects plants from PLANTS table via APEX UI
   - Selected plants saved to SELECTION_LOADER (is_active='Y')
   - Triggers automatic fetch of issues for ONLY selected plants
   
2. **Issue Selection**:
   - Issues dropdown populates with data for selected plants only
   - User selects specific issue revisions
   - Selected issues saved to SELECTION_LOADER

### 3. Full ETL Execution Order
When user clicks "Run Full ETL":
1. **Issues** - Already fetched during selection
2. **Issue References** (Task 7) - For selected issues only:
   - PCS, SC, VSM, VDS, EDS, MDS, VSK, ESK, PIPE_ELEMENT
3. **PCS Details** (Task 8) - ONLY for PCS referenced
4. **VDS Details** (Task 9) - ONLY for VDS referenced
5. **BoltTension** (Task 10) - DEFERRED until above complete

### 4. Change Management & Cascade Logic
- **Plant change**: Deactivate old → cascade deactivate downstream
- **Issue change**: Deactivate old → cascade deactivate references
- **Soft delete**: All tables use is_valid='N' instead of DELETE

### 5. API Call Optimization
- **Selection scoping**: Only fetch for selected items (70% reduction)
- **SHA256 deduplication**: Skip unchanged API responses
- **Cascade fetching**: Only fetch actually referenced data
- **Example**: 3 plants × 2 issues = 6 API calls (vs 1000s without selection)

## 🎯 DEPLOYED COMPONENTS

### CASCADE MANAGEMENT SYSTEM (Session 9)
- **CASCADE_LOG table**: Audit trail for cascade operations
- **PKG_CASCADE_MANAGER**: Central logic with AUTONOMOUS_TRANSACTION
- **Three triggers**: Plant→Selection, Selection→All, Issues→Selection
- **Testing**: Cascade deactivation working (Plant 34 → 8 issues marked invalid)
- **Known Issue**: Deadlock when manually updating issues (can be addressed if needed)

### GUID ARCHITECTURE (Session 10)
- **Status**: ✅ IMPLEMENTED AND MERGED
- **Documentation**: 
  - `/Ops/Knowledge_Base/GUID_Architecture_Overview.md`
  - `/Ops/Knowledge_Base/GUID_Implementation_Guide.md`
- **Implementation**: GUIDs added to PLANTS, ISSUES, SELECTION_LOADER, RAW_JSON
- **API Tracking**: Correlation IDs for idempotency and tracking

### Database Packages
- **pkg_raw_ingest**: RAW_JSON deduplication and insertion
- **pkg_parse_plants/issues**: JSON parsing for endpoints
- **pkg_upsert_plants/issues**: MERGE procedures
- **pkg_etl_operations**: ETL orchestration and logging
- **pkg_api_client**: APEX_WEB_SERVICE API calls with GUID support
- **pkg_selection_mgmt**: Selection management
- **pkg_cascade_manager**: Cascade logic management
- **pkg_guid_utils**: GUID utilities and conversions

## 📚 DOCUMENTATION REFERENCES

### Critical Reference Documents
- **API Documentation**: `/Ops/Setup/TR2000_API_Endpoints_Documentation.md`
  - Section 1: Operators and Plants (✅ COMPLETE in Tasks 1-5)
  - Section 2: Issue References - 9 types (✅ COMPLETE in Task 7)
  - Section 3: PCS Details - 6 detail types (✅ COMPLETE in Task 8)
  - Section 4: VDS Details - 44,000+ records (📋 NEXT - Task 9)
  - Section 5: BoltTension - 8 endpoints (📋 Task 10)

### Other Documentation
- **Master Index**: `/Ops/Doc_Index_Readme.md` - Documentation guidelines
- **Test Matrix**: `/Ops/Testing/ETL_Test_Matrix.md` - Test scenarios
- **Knowledge Base**: `/Ops/Knowledge_Base/` - Architecture guides
- **Task List**: `/Ops/Setup/tasks-tr2k-etl.md` - Task tracking

## AI INSTRUCTIONS

When working with task lists, the AI must:
1. Regularly update the task list file after finishing any significant work
2. Follow the completion protocol (mark sub-tasks → run tests → commit → mark parent)
3. Add newly discovered tasks as they emerge
4. Before starting work, check which sub‑task is next
5. After implementing a sub‑task, update the file and pause for user approval
6. **ONLY update tasks-tr2k-etl.md** - no other documentation updates needed