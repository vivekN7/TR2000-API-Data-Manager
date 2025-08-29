# Task List: TR2000 ETL System Implementation

## Session 20 Complete (2025-12-30)
**Status**: Tasks 1-9 COMPLETE ✅ | ETL_STATS fully functional | Workflow scripts fixed | Ready for Task 10.3+

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

- [x] 9.0 Build ETL Backend for VDS Details (Section 4 of API) ✅ COMPLETE
  - [x] 9.1 Review Section 4: Large dataset (44,000+ records)
  - [x] 9.2 Create VDS_DETAILS table with proper indexes
  - [x] 9.3 Build pkg_parse_vds for bulk JSON processing
  - [x] 9.4 Build pkg_upsert_vds with batch processing
  - [x] 9.5 Add VDS endpoint to CONTROL_ENDPOINTS
  - [x] 9.6 Extend pkg_api_client with fetch_vds_details
  - [x] 9.7 Implement pagination/chunking for large dataset (done in pkg_upsert_vds)
  - [x] 9.8 Add to ETL workflow with performance monitoring
  - [x] 9.9 Create analysis views for VDS data
  - [x] 9.10 Performance test with test data (JSP2, GRANE)
  - [x] 9.11 Run PKG_SIMPLE_TESTS with performance metrics

- [ ] 10.0 Database Optimization & Cleanup (Session 19-20 Partial)
  - [x] 10.1 Audit all tables - identify unused/redundant tables (Session 19: Completed)
  - [x] 10.2 Remove unused tables that were identified, optimize and update other tables (Session 19: CONTROL_ENDPOINT_STATE→ETL_STATS, removed 2 tables)
  - [x] 10.2a ETL_STATS fully implemented with logging for all operations (Session 20: Complete)
  - [x] 10.2b Workflow scripts fixed - created _no_exit versions, archived originals (Session 20: Complete)
  - [x] 10.2c VDS_LIST loading optimized for OFFICIAL_ONLY mode (Session 20: Complete)
  - [ ] 10.3 Audit all views - remove unused/redundant, identify and add useful new views (with approval)
  - [ ] 10.4 Cleanup unused packages/procedures, optimize others where possible
  - [ ] 10.5 Optimize indexes based on actual query patterns
  - [ ] 10.6 Review and streamline ETL control tables
  - [ ] 10.7 Document each remaining object's purpose
  - [ ] 10.8 Create database object dependency map
  - [ ] 10.9 Archive old incremental scripts (50+ files)
  - [ ] 10.10 Validate all remaining objects compile successfully

- [ ] 11.0 Documentation & Blazor Website Enhancement
        **NOTE**: Plan the documentation pages first - keep website clean with minimal pages
  - [ ] 11.1 Remove legacy pages from Blazor site (API Data Manager pages)
  - [ ] 11.2 Create ETL Flow documentation page with interactive diagrams
  - [ ] 11.3 Create ERD visualization page showing all table relationships
  - [ ] 11.4 Create API Endpoint documentation page with call sequences
  - [ ] 11.5 Create Data Flow diagram page (API → RAW → STG → CORE)
  - [ ] 11.6 Add Process Flow documentation (Selection → ETL → References)
  - [ ] 11.7 Create Testing Dashboard page showing test results
  - [ ] 11.8 Add ETL Monitoring Dashboard with real-time statistics
  - [ ] 11.9 Create Data Quality Dashboard page
  - [ ] 11.10 Add System Health monitoring page
  - [ ] 11.11 Document cascade operations and triggers
  - [ ] 11.12 Create troubleshooting guide page

- [ ] 12.0 Blazor UI Development & Scheduling
        **NOTE**: Plan the UI development and scheduling pages first - keep website clean with minimal pages
  - [ ] 12.1 Create interactive Plant Selection page
  - [ ] 12.2 Create Issue Selection and Management page
  - [ ] 12.3 Build Reference Data Explorer with drill-down
  - [ ] 12.4 Create PCS Details viewer with search
  - [ ] 12.5 Build VDS Details browser with pagination
  - [ ] 12.6 Add Test Results Dashboard with history
  - [ ] 12.7 Create ETL Run History page with logs
  - [ ] 12.8 Implement weekly export scheduler (CSV/Excel)
  - [ ] 12.9 Add scheduled report generation
  - [ ] 12.10 Create data export APIs for Blazor
  - [ ] 12.11 Add user preference management
  - [ ] 12.12 Implement role-based access control

- [ ] 13.0 BoltTension Analysis & Implementation
  - [ ] 13.1 Analyze BoltTension API endpoints (Section 5)
  - [ ] 13.2 Map BoltTension data to existing table structures
  - [ ] 13.3 Identify if new tables are needed or existing can be reused
  - [ ] 13.4 Document BoltTension data relationships
  - [ ] 13.5 Create proof-of-concept using existing infrastructure
  - [ ] 13.6 Test BoltTension data retrieval with minimal changes
  - [ ] 13.7 Implement only necessary new components
  - [ ] 13.8 Add BoltTension to ETL workflow if needed
  - [ ] 13.9 Create BoltTension viewer in Blazor (can be queries making direct endpoint calls in the correct webpages)
  - [ ] 13.10 Validate BoltTension data quality

- [ ] 14.0 Peer Review & Quality Assurance
  - [ ] 14.1 Prepare comprehensive system documentation for review
  - [ ] 14.2 Create code review package with key components
  - [ ] 14.3 Submit ETL architecture for LLM peer review
  - [ ] 14.4 Submit database design for review
  - [ ] 14.5 Review test coverage and quality
  - [ ] 14.6 Implement recommended security improvements
  - [ ] 14.7 Apply performance optimization suggestions
  - [ ] 14.8 Address code quality recommendations
  - [ ] 14.9 Update documentation based on feedback
  - [ ] 14.10 Create final review report

- [ ] 15.0 Final Optimization & Knowledge Base Update
  - [ ] 15.1 Apply all optimization recommendations from peer review
  - [ ] 15.2 Update all Knowledge Base documents to current state
  - [ ] 15.3 Archive outdated documentation
  - [ ] 15.4 Create comprehensive deployment guide
  - [ ] 15.5 Update Quick References with final commands
  - [ ] 15.6 Document all lessons learned
  - [ ] 15.7 Create performance benchmarks
  - [ ] 15.8 Finalize error handling procedures
  - [ ] 15.9 Update troubleshooting guides
  - [ ] 15.10 Create system maintenance checklist

- [ ] 16.0 Environment Migration & Deployment Strategy
  - [ ] 16.1 Document current local environment configuration
  - [ ] 16.2 Create migration scripts for network Oracle database
  - [ ] 16.3 Design synchronization strategy (Dev → Network → Prod)
  - [ ] 16.4 Create environment-specific configuration files
  - [ ] 16.5 Build automated deployment pipeline
  - [ ] 16.6 Test migration to network database
  - [ ] 16.7 Document rollback procedures
  - [ ] 16.8 Create production deployment checklist
  - [ ] 16.9 Design continuous deployment workflow
  - [ ] 16.10 Create environment sync utilities
  - [ ] 16.11 Document change management process
  - [ ] 16.12 Final production readiness review