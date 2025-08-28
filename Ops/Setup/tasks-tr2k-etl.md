# Task List: TR2000 ETL System Implementation

## Session 17 In Progress (2025-12-29)
**Status**: Tasks 1-8 COMPLETE ✅ | System optimized with loading modes | Ready for Task 9

## Tasks

- [x] 1.0 Setup Core Database Schema for Plants and Issues ONLY ✅ COMPLETE
  - [x] 1.1 Review TR2000_API_Endpoints_Documentation.md to understand Plants and Issues data fields
  - [x] 1.2 Create database schema with RAW_JSON table (including sha256 hash, endpoint_key, plant, issue_rev columns)
        **IMPORTANT**: Using modular deployment system in `/Database/deploy/` for all database objects.
  - [x] 1.3 Define STG_PLANTS staging table with all VARCHAR2 columns matching API response
  - [x] 1.4 Define STG_ISSUES staging table with all VARCHAR2 columns matching API response
  - [x] 1.5 Create PLANTS table with proper data types and is_valid soft delete flag
  - [x] 1.6 Create ISSUES table with proper data types and is_valid soft delete flag
  - [x] 1.7 Setup SELECTION_LOADER table for storing user-selected plants and issues
  - [x] 1.8 Create ETL control tables (CONTROL_ENDPOINTS, CONTROL_SETTINGS, CONTROL_ENDPOINT_STATE)
  - [x] 1.9 Define ETL_RUN_LOG and ETL_ERROR_LOG tables for monitoring and error tracking
  - [x] 1.10 Create indexes for performance optimization on key columns
- [x] 1.11 Populate CONTROL_ENDPOINTS with initial Plants + Issues configs
- [x] 1.12 Ensure all schema changes are reflected in modular deployment scripts

- [x] 2.0 Create Basic APEX Application ✅ COMPLETE
  - [x] 2.1 Create APEX workspace for TR2000_STAGING (Workspace created)
  - [x] 2.2 Create application "TR2000 ETL Manager" with basic structure (App 101 created)
  - [x] 2.3 Create simple home page with placeholder regions for future features (3 regions added)
  - [x] 2.4 Add basic navigation menu structure (Default menu in place)
  - [x] 2.5 Test APEX application is accessible and running (Working on http://localhost:8888/ords/)

- [x] 3.0 Build Selection Management in Oracle ✅ COMPLETE
  - [x] 3.1 Create stored procedures for selection management (pkg_selection_mgmt created)
  - [x] 3.2 Add cascade logic to update dependent data when plants are removed
  - [x] 3.3 Add selection persistence across application restarts
  - [x] 3.4 Create APEX page for plant/issue selection UI (Page 5: ETL Control Center)
  - [x] 3.5 Wire up APEX selection page to call Oracle procedures (All buttons working)
  - [x] 3.6 Test selection functionality end-to-end (Verified working)

- [x] 4.0 Build ETL Pipeline for Plants and Issues ✅ COMPLETE
  - [x] 4.1 Create pkg_raw_ingest package for raw JSON storage (SHA256 deduplication) (Package created)
  - [x] 4.2 Create pkg_parse_plants package to parse JSON into staging (Package created)
  - [x] 4.3 Create pkg_parse_issues package for issue parsing (Package created)
  - [x] 4.4 Create pkg_upsert_plants package for staging->core with soft delete (Package created)
  - [x] 4.5 Create pkg_upsert_issues package with foreign key validation (Package created)
  - [x] 4.6 Create pkg_etl_operations orchestration package (Package created)
  - [x] 4.7 Add error handling and transaction management (SAVEPOINT/ROLLBACK)
  - [x] 4.8 Add run logging and row count tracking (ETL_RUN_LOG tracking)
  - [x] 4.9 Test full pipeline with JSP2 and GRANE plants (Working: 130 plants, 12/8 issues)
  - [x] 4.10 Add views for ETL monitoring and status (All 11 views created)

- [x] 5.0 Build API Client in Oracle (APEX_WEB_SERVICE) ✅ COMPLETE
  - [x] 5.1 Configure Oracle wallet for HTTPS certificates (Wallet configured)
  - [x] 5.2 Create pkg_api_client with dynamic endpoint calling (Package created)
  - [x] 5.3 Implement error handling and retry logic (Error handling in place)
  - [x] 5.4 Add refresh_plants_from_api procedure (Procedure working)
  - [x] 5.5 Add refresh_issues_for_plant procedure (Procedure working)
  - [x] 5.6 Add API authentication support (if needed) (Using APEX_WEB_SERVICE, no auth needed)
  - [x] 5.7 Test API connectivity end-to-end (Confirmed working)
  - [x] 5.8 Update CONTROL_SETTINGS with production URLs (Updated for new API)
  - [x] 5.9 Wire APEX refresh buttons to API procedures (Page 5 refresh buttons working)

- [x] 6.0 Testing Framework Implementation ✅ COMPLETE (Session 8)
  - [x] 6.1 Create TEST_RESULTS table with enhanced tracking columns (Session 8)
  - [x] 6.2 Define PKG_SIMPLE_TESTS package specification (Session 6)
  - [x] 6.3 Implement test_api_connectivity function (Session 6)
  - [x] 6.4 Implement test_selection_process function (Session 6)
  - [x] 6.5 Implement test_etl_pipeline function (Session 6)
  - [x] 6.6 Create run_critical_tests main procedure (Session 6)
  - [x] 6.7 Add log_test_result procedure for tracking (Session 6)
  - [x] 6.8 Create ETL_Test_Matrix.md documentation (Session 8)
  - [x] 6.9 Add test data cleanup procedures (Session 6)
  - [x] 6.10 Deploy test framework to database (Session 6)
  - [x] 6.11 Run initial test suite and verify (Session 6)
  - [x] 6.12 Create analysis views for test results (Session 8)

- [x] 7.0 Build ETL Backend for Issue Reference Tables (Section 2 of API doc) ✅ COMPLETE (Session 15)
  - [x] 7.1 Create tables for 9 reference types (PCS, SC, VSM, VDS, EDS, MDS, VSK, ESK, PIPE_ELEMENT)
        **IMPORTANT**: Each reference type has both STG_ and final tables with proper data types
  - [x] 7.2 Build pkg_parse_references to parse JSON into staging
  - [x] 7.3 Build pkg_upsert_references for staging->core with FK validation
  - [x] 7.4 Add reference API endpoints to CONTROL_ENDPOINTS
  - [x] 7.5 Extend pkg_api_client with fetch_issue_references procedure
  - [x] 7.6 Add reference_type parameter to support all 9 types dynamically
  - [x] 7.7 Extend pkg_etl_operations to include reference processing
  - [x] 7.8 Add cascade logic: when issue changes, mark old references invalid
  - [x] 7.9 Create views for reference data monitoring
  - [x] 7.10 Test with JSP2 and GRANE selected issues
  - [x] 7.11 Extend PKG_SIMPLE_TESTS with reference tests

- [x] 8.0 Build ETL Backend for PCS Details (Section 3 of API) ✅ COMPLETE & OPTIMIZED
  - [x] 8.1 Review API doc Section 3: 7 PCS detail endpoints (6 detail types identified)
  - [x] 8.2 Create tables for Header, Temp/Pressure, Pipe Sizes, Pipe Elements, Valve Elements, Embedded Notes
  - [x] 8.3 Build pkg_parse_pcs_details for JSON parsing
  - [x] 8.4 Build pkg_upsert_pcs_details with FK to PCS_REFERENCES
  - [x] 8.5 Add PCS detail endpoints to CONTROL_ENDPOINTS  
  - [x] 8.6 Extend pkg_api_client with fetch_pcs_details (pkg_api_client_pcs_details created)
  - [x] 8.7 Add parameter support for different PCS detail types (6 types supported)
  - [x] 8.8 Add to pkg_etl_operations workflow (Step 4 in run_full_etl)
  - [x] 8.9 Create monitoring views for PCS data (7 views created)
  - [x] 8.10 Test cascade: PCS reference removal should invalidate details (trigger created)
  - [x] 8.11 Add PCS tests to PKG_SIMPLE_TESTS (test script created)
  - [x] 8.12 FIX: Implemented correct 3-step flow (Issue refs → ALL plant PCS → Details for ALL)
  - [x] 8.13 Created PCS_LIST table for ALL plant PCS revisions (362 for GRANE)
  - [x] 8.14 Fixed to use REAL issue_revision (4.2), no dummy values
  - [x] 8.15 Created pkg_api_client_pcs_details_v2 with correct implementation
  - [x] 8.16 OPTIMIZED: Added PCS_LOADING_MODE setting (82% API call reduction)
  - [x] 8.17 Fixed JSON parsing paths for all PCS detail endpoints
  - [x] 8.18 Removed issue_revision dependency from PCS detail tables

- [ ] 9.0 Build ETL Backend for VDS Details (Section 4 of API)
  - [ ] 9.1 Review Section 4: Large dataset (44,000+ records)
  - [ ] 9.2 Create VDS_DETAILS table with proper indexes
  - [ ] 9.3 Build pkg_parse_vds for bulk JSON processing
  - [ ] 9.4 Build pkg_upsert_vds with batch processing
  - [ ] 9.5 Add VDS endpoint to CONTROL_ENDPOINTS
  - [ ] 9.6 Extend pkg_api_client with fetch_vds_details
  - [ ] 9.7 Implement pagination/chunking for large dataset
  - [ ] 9.8 Add to ETL workflow with performance monitoring
  - [ ] 9.9 Create analysis views for VDS data
  - [ ] 9.10 Performance test with test data (JSP2, GRANE)
  - [ ] 9.11 Run PKG_SIMPLE_TESTS with performance metrics

- [ ] 10.0 Build ETL Backend for BoltTension Tables (Section 5 of API)
  - [ ] 10.1 Create schema for Flange Type (BOLT_FLANGE_TYPE)
  - [ ] 10.2 Create schema for Gasket Type (BOLT_GASKET_TYPE)
  - [ ] 10.3 Create schema for Bolt Material (BOLT_MATERIAL)
  - [ ] 10.4 Create schema for Tension Forces (BOLT_TENSION_FORCES)
  - [ ] 10.5 Create schema for Tool (BOLT_TOOL)
  - [ ] 10.6 Create schema for Tool Pressure (BOLT_TOOL_PRESSURE)
  - [ ] 10.7 Create schema for Plant Info and Lubricant tables
  - [ ] 10.8 Build pkg_parse_bolttension for all 8 endpoints
  - [ ] 10.9 Build pkg_upsert_bolttension
  - [ ] 10.10 Add BoltTension API functions to pkg_api_client
  - [ ] 10.11 Add to CONTROL_ENDPOINTS for dynamic processing
  - [ ] 10.12 Validate with PKG_SIMPLE_TESTS framework

- [ ] 11.0 Build APEX UI for ETL System [AFTER ETL BACKEND COMPLETE]
  - [ ] 11.1 Create APEX page for Issue Reference data display with drill-down
  - [ ] 11.2 Add reference counts to issue selection display
  - [ ] 11.3 Create APEX reports and detail pages for PCS data
  - [ ] 11.4 Implement PCS selection interface linked to plants
  - [ ] 11.5 Create APEX interface with pagination for VDS display
  - [ ] 11.6 Add VDS search and filter capabilities
  - [ ] 11.7 Create APEX calculator interface for bolt tension
  - [ ] 11.8 Link BoltTension data to PCS selections
  - [ ] 11.9 Create dashboard with ETL statistics and status
  - [ ] 11.10 Add data export capabilities (CSV, Excel)
  - [ ] 11.11 Implement user preferences and saved filters
  - [ ] 11.12 Final UI testing and refinement

- [ ] 12.0 Setup Automation [POST-PROJECT]
  - [ ] 12.1 Create DBMS_SCHEDULER job for daily plant refresh
  - [ ] 12.2 Create job for processing selected issues
  - [ ] 12.3 Add job monitoring page in APEX
  - [ ] 12.4 Implement email notifications on failure (optional)
  - [ ] 12.5 Schedule PKG_SIMPLE_TESTS.run_critical_tests before each ETL run

- [ ] 13.0 Performance Optimization Phase [AFTER CORE COMPLETE]
  - [ ] 13.1 Implement full CONTROL_ENDPOINT_STATE tracking
  - [ ] 13.2 Add HTTP HEAD request support for change detection
  - [ ] 13.3 Implement exponential backoff for failed endpoints
  - [ ] 13.4 Track "unchanged count" for adaptive checking frequency
  - [ ] 13.5 Add time-of-day logic (business hours vs off-hours)
  - [ ] 13.6 Implement batch processing for multiple plants
  - [ ] 13.7 Add parallel processing for reference types
  - [ ] 13.8 Optimize hash comparisons with checksums
  - [ ] 13.9 Add API call metrics and reporting
  - [ ] 13.10 Performance testing with large datasets

- [ ] 14.0 Cleanup & Documentation Phase
  - [ ] 14.1 Review and remove unused tables (or document future use)
    - CONTROL_ENDPOINT_STATE (decide: implement or remove)
    - EXTERNAL_SYSTEM_REFS (keep for future integrations?)
    - TEMP_TEST_DATA (remove or use for mock testing?)
  - [ ] 14.2 Complete API documentation
  - [ ] 14.3 Create operations runbook
  - [ ] 14.4 Document troubleshooting procedures
  - [ ] 14.5 Create data dictionary for all tables
  - [ ] 14.6 Archive all incremental scripts
  - [ ] 14.7 Final code review and cleanup