# Task List: TR2000 ETL System Implementation

## Relevant Files

### Critical Reference Documentation
- `/workspace/TR2000/TR2K/Ops/Setup/TR2000_API_Endpoints_Documentation.md` - **CRITICAL**: Contains all endpoints and data fields to be transferred to database tables via ETL operations. Must be referenced when implementing any table structure.

### Database Schema & Procedures (ORACLE APEX SOLUTION)
- `/workspace/TR2000/TR2K/Database/Master_DDL.sql` - **SINGLE SOURCE OF TRUTH** - Contains ALL database objects including:
  - Schema definitions (RAW_JSON, STG_*, CORE tables)
  - pkg_raw_ingest - RAW_JSON deduplication and insertion
  - pkg_parse_plants - JSON parsing for Plants endpoint
  - pkg_upsert_plants - MERGE procedures for PLANTS table
  - pkg_parse_issues - JSON parsing for Issues endpoint
  - pkg_upsert_issues - MERGE procedures for ISSUES table
  - pkg_etl_operations - ETL orchestration and logging
  - **pkg_api_client** - NEW: APEX_WEB_SERVICE API calls

### APEX Application Components (SIMPLIFIED - 2 PAGES ONLY)
- **Application**: TR2000 ETL Manager
- **Page 1**: Dashboard - Quick statistics and recent runs
- **Page 2**: ETL Operations - Everything in one page:
  - Plant selection (multi-select, max 10)
  - Issue selection (cascading from plants)
  - Action buttons (Refresh, Save, Run)
  - Execution log at bottom
- **NO EXTERNAL HOSTING**: Runs entirely inside Oracle Database
- **Access**: Via browser at `http://oracle-server:8080/apex`

### Legacy Files (NO LONGER USED - Kept for reference)
- ~~C# Application Files - Replaced by APEX~~
- ~~Blazor Components - Replaced by APEX pages~~
- ~~.NET Services - Replaced by PL/SQL packages~~

### Notes

- **ARCHITECTURE CHANGE**: Pivoted to pure Oracle APEX solution (2025-08-22)
- **CRITICAL**: Master_DDL.sql is the SINGLE source of truth for all database objects
- The Master_DDL.sql includes DROP statements for clean redeployment
- All API calls now made from Oracle using APEX_WEB_SERVICE
- UI provided by APEX pages (no external frontend needed)
- All logic remains in Oracle stored procedures
- Focus on Plants and Issues FIRST before moving to references
- PL/SQL tests should be executed directly in Oracle
- APEX application can be exported/imported for deployment

### CURRENT STATUS (2025-08-23) - ARCHITECTURE SIMPLIFIED! 🎉
- **COMPLETED**: Task 7.0-7.9 - pkg_api_client now using APEX_WEB_SERVICE!
- **COMPLETED**: Task 3.8 & 3.10 - Added pr_purge_raw_json and dynamic endpoint processing
- **HTTPS WORKING**: Oracle wallet configured at C:\Oracle\wallet with Let's Encrypt certificates
- **APEX STATUS**: Fully functional with HTTPS! APEX_WEB_SERVICE working perfectly
- **CODE REDUCTION**: 70% less code compared to UTL_HTTP implementation
- **DATABASE CLEANUP**: Archived 90% of files, Master_DDL.sql is single source of truth
- **NEW FEATURES**: Added APEX helper procedures, views, and DBMS_SCHEDULER jobs
- **NEXT**: Task 8.0 - Build 2-page APEX application with full API integration

## Tasks

- [x] 1.0 Setup Core Database Schema for Plants and Issues ONLY
  - [x] 1.1 Review TR2000_API_Endpoints_Documentation.md to understand Plants and Issues data fields
  - [x] 1.2 Create Master_DDL.sql with RAW_JSON table (including sha256 hash, endpoint_key, plant, issue_rev columns)
        **IMPORTANT**: Master_DDL.sql is the ONLY SQL script to be updated during development. It includes DROP statements for clean redeployment.
  - [x] 1.3 Define STG_PLANTS staging table with all VARCHAR2 columns matching API response
  - [x] 1.4 Define STG_ISSUES staging table with all VARCHAR2 columns matching API response
  - [x] 1.5 Create PLANTS table with proper data types and is_valid soft delete flag
  - [x] 1.6 Create ISSUES table with proper data types and is_valid soft delete flag
  - [x] 1.7 Setup SELECTION_LOADER table for storing user-selected plants and issues
  - [x] 1.8 Create ETL control tables (CONTROL_ENDPOINTS, CONTROL_SETTINGS, CONTROL_ENDPOINT_STATE)
  - [x] 1.9 Define ETL_RUN_LOG and ETL_ERROR_LOG tables for monitoring and error tracking
  - [x] 1.10 Create indexes for performance optimization on key columns
- [x] 1.11 Populate CONTROL_ENDPOINTS with initial Plants + Issues configs
- [x] 1.12 Ensure all schema changes are reflected in Master_DDL.sql only. No other DDL scripts should exist outside this file
        **DEPLOYMENT NOTE**: Run Master_DDL.sql to drop and recreate all database objects cleanly. This is the ONLY script to maintain.

- [x] 2.0 ~~Build Unified ETL Operations Page~~ [REPLACED BY APEX]
  - [x] 2.1 ~~Create single ETLOperations.razor page~~ [N/A - Using APEX]
  - [x] 2.2 ~~Add Plant Selection section~~ [N/A - Using APEX]
  - [x] 2.3 ~~Add Issue Selection section~~ [N/A - Using APEX]
  - [x] 2.4 ~~Implement SelectionService.cs~~ [N/A - Using PL/SQL]
  - [x] 2.5 Add cascade logic in Oracle procedures to update dependent data when plants are removed
  - [x] 2.6 Implement validation to limit selection to maximum 10 plants
  - [x] 2.7 Create stored procedures for selection management (insert, update, cascade deletes)
  - [x] 2.8 Add selection persistence across application restarts

- [x] 3.0 Build ETL Pipeline for Plants and Issues ONLY  
  - [x] 3.1 Create pkg_raw_ingest package for SHA256 deduplication and RAW_JSON insertion
  - [x] 3.2 Implement pkg_parse_plants to extract data from JSON using JSON_TABLE (reference API documentation)
  - [x] 3.3 Build pkg_upsert_plants with MERGE logic for current-state management
  - [x] 3.4 Create pkg_parse_issues to extract data from JSON using JSON_TABLE (reference API documentation)
  - [x] 3.5 Build pkg_upsert_issues with MERGE logic for current-state management
  - [x] 3.6 Develop pkg_etl_operations for orchestrating the full pipeline per endpoint
  - [x] 3.7 Implement transaction safety with explicit COMMIT/ROLLBACK in all procedures
  - [x] 3.8 Add pr_purge_raw_json procedure for manual data retention management
  - [x] 3.9 Create minimal ETLService.cs to orchestrate API calls and procedure execution via Dapper
  - [x] 3.10 Modify pkg_etl_operations to dynamically read CONTROL_ENDPOINTS instead of hardcoding endpoints

## NEW: Oracle APEX Implementation Tasks

- [x] 7.0 Create pkg_api_client Package for API Integration ✅ USING APEX_WEB_SERVICE!
  - [x] 7.1 Create package specification with APEX_WEB_SERVICE functions
  - [x] 7.2 Implement fetch_plants_json function using APEX_WEB_SERVICE
  - [x] 7.3 Implement fetch_issues_json function for specific plants
  - [x] 7.4 Add calculate_sha256 function using DBMS_CRYPTO
  - [x] 7.5 Create refresh_plants_from_api procedure (fetch + insert + process)
  - [x] 7.6 Create refresh_issues_from_api procedure
  - [x] 7.7 Add error handling and logging
  - [x] 7.8 Configure Oracle wallet with SSL certificates for HTTPS
  - [x] 7.9 Test API connectivity with APEX_WEB_SERVICE - WORKING!

- [ ] 8.0 Build Simplified 2-Page APEX Application
  - [ ] 8.1 Create APEX workspace for TR2000_STAGING
  - [ ] 8.2 Create application "TR2000 ETL Manager" 
  - [ ] 8.3 Create Page 1: Dashboard (statistics cards + recent runs)
  - [ ] 8.4 Create Page 2: ETL Operations (all-in-one page)
  - [ ] 8.5 Add plant multi-select (max 10) on Page 2
  - [ ] 8.6 Add cascading issue selection on Page 2
  - [ ] 8.7 Add action buttons (Refresh, Save, Run ETL) on Page 2
  - [ ] 8.8 Add execution log region at bottom of Page 2
  - [ ] 8.9 Apply Universal Theme
  - [ ] 8.10 Test complete flow end-to-end

- [ ] 9.0 Setup Automation
  - [ ] 9.1 Create DBMS_SCHEDULER job for daily plant refresh
  - [ ] 9.2 Create job for processing selected issues
  - [ ] 9.3 Add job monitoring page in APEX
  - [ ] 9.4 Implement email notifications on failure (optional)

- [ ] 4.0 ~~Add Monitoring and Testing to ETL Operations Page~~ [REPLACED BY APEX]
  - [ ] 4.1 ~~Add monitoring section to ETLOperations.razor~~ [N/A - Using APEX Interactive Reports]
  - [ ] 4.2 ~~Create error log viewer~~ [N/A - Built-in with APEX]
  - [ ] 4.3 ~~Implement real-time progress indicators~~ [N/A - APEX has this]
  - [ ] 4.4 ~~Add tabbed interface~~ [N/A - APEX pages handle this]
  - [ ] 4.5 ~~Create manual trigger buttons~~ [N/A - APEX buttons]
  - [ ] 4.6 ~~Build statistics cards~~ [N/A - APEX regions]
  - [ ] 4.7 ~~Implement data preview~~ [N/A - APEX Interactive Reports]
  - [ ] 4.8 ~~Add test execution section~~ [N/A - APEX processes]

- [ ] 5.0 Develop Testing and Validation for Plants and Issues
  - [ ] 5.1 Create PL/SQL unit tests for pkg_parse_plants using test fixtures
  - [ ] 5.2 Create PL/SQL unit tests for pkg_parse_issues using test fixtures
  - [ ] 5.3 Write tests for deduplication logic in pkg_raw_ingest
  - [ ] 5.4 Develop tests for MERGE/upsert operations with is_valid flag handling
  - [ ] 5.5 Create minimal C# unit tests for ETLService using mock API responses
  - [ ] 5.6 Build integration test for Plants → Issues pipeline with test data
  - [ ] 5.7 Implement data validation checks ensuring all API fields are captured
  - [ ] 5.8 Create performance test to verify 1-minute execution target for 10 plants
  - [ ] 5.9 Add smoke test for API connectivity and basic database operations
- [ ] 5.10 Create test cases for pr_purge_raw_json with dry-run (count only) and actual delete scenarios
- [ ] 5.11 Simulate API and parsing errors and validate that ETL_ERROR_LOG entries contain correct endpoint/plant/issue context
- [ ] 5.12 Create test to ensure disappearing records are flagged invalid, and returning records are correctly reactivated (Plants/Issues)

- [ ] 6.0 ~~Setup CI jobs~~ [SIMPLIFIED FOR APEX]
  - [ ] 6.1 Run PL/SQL syntax check + utPLSQL tests in containerized Oracle XE
  - [ ] 6.2 ~~Run dotnet test~~ [N/A - No C# code]
