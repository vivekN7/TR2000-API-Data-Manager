# Task List: TR2000 ETL System Implementation

## Relevant Files

### Critical Reference Documentation
- `/workspace/TR2000/TR2K/Ops/Setup/TR2000_API_Endpoints_Documentation.md` - **CRITICAL**: Contains all endpoints and data fields to be transferred to database tables via ETL operations. Must be referenced when implementing any table structure.
  - **Section 1**: Operators and Plants (✅ COMPLETE in Tasks 1-5)
  - **Section 2**: Issue References - 9 types (📋 NEW Task 6)
  - **Section 3**: PCS Details - 7 table types (📋 NEW Task 7)
  - **Section 4**: VDS Details - 44,000+ records (📋 NEW Task 8)
  - **Section 5**: BoltTension - 8 endpoints (📋 NEW Task 9)

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
  - **MISSING - MUST ADD**: pkg_selection_mgmt (currently in separate file)
  - **MISSING - MUST ADD**: apex_etl_control_action procedure
  - **MISSING - MUST ADD**: Views for APEX (v_etl_control_plants_lov, etc.)

### APEX Application Components (ITERATIVE DEVELOPMENT)
- **Application**: TR2000 ETL Manager
- **Initial Setup**: Basic app with placeholder regions
- **Progressive Enhancement**: UI components added with each feature:
  - Selection Management → Plant/Issue selection page
  - ETL Operations → Control and monitoring pages
  - API Integration → Test and refresh buttons
- **Future Enhancements**: Dashboard, statistics, themes
- **NO EXTERNAL HOSTING**: Runs entirely inside Oracle Database
- **Access**: Via browser at `http://localhost:8888/ords/` (ORDS on port 8888)
- **Workspace**: TR2000_ETL | **Username**: ADMIN | **Password**: Apex!1985


### Implementation Notes

- **Architecture**: Pure Oracle APEX solution (no external applications)
- **Database**: Master_DDL.sql is the SINGLE source of truth
- **Deployment**: Run Master_DDL.sql to drop and recreate everything
- **Version Control**: Git tracks all changes (no manual backups)
- **API Calls**: Using APEX_WEB_SERVICE from PL/SQL
- **🔴 CRITICAL**: NEVER use UTL_HTTP - only use APEX_WEB_SERVICE for all HTTP/HTTPS calls
- **Connection**: TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1
- **Focus**: Plants and Issues first, then reference tables
- **Tools**: SQL*Plus client in /Database/tools/instantclient/
- **SQL*Plus Command**: `export LD_LIBRARY_PATH=/workspace/TR2000/TR2K/Database/tools/instantclient:$LD_LIBRARY_PATH && /workspace/TR2000/TR2K/Database/tools/instantclient/sqlplus -S TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1`

### CURRENT STATUS (2025-08-24 - Session 2)
- **COMPLETED**: Database schema (Task 1), Basic APEX App (Task 2), Selection Management (Task 3), ETL Pipeline (Task 4), API Integration (Task 5)
- **IN PROGRESS**: Tasks 4.9-4.10 (APEX ETL pages), Task 5.10 (APEX API test page)
- **NEW TASKS ADDED**: 
  - Task 6: Issue Reference Tables (9 reference types from Section 2 of API)
  - Task 7: PCS Detail Tables (7 table types from Section 3 of API)
  - Task 8: VDS Detail Tables (Section 4 - includes 44,000+ records!)
  - Task 9: BoltTension Tables (8 endpoints from Section 5 of API)
- **ARCHITECTURE**: All new tables follow API → RAW_JSON → STG_* → CORE pattern
- **BLOCKER**: Oracle wallet for HTTPS not being recognized (see WALLET_ISSUE_STATUS_2025_08_24.md)
- **NEXT PRIORITY**: Fix wallet issue, then populate plants from API
- **POST-PROJECT**: Automation (Task 10), Testing (Task 11)

### 🔴 CRITICAL: ETL Data Flow & Selection Management Architecture

#### **1. Initial Data Population**
- **One-time load**: Fetch ALL plants from API to populate PLANTS table
- This provides the master list for user selection
- No issues are loaded initially (API optimization)

#### **2. User Selection Workflow**
1. **Plant Selection**:
   - User selects plants from PLANTS table via APEX UI
   - Selected plants saved to SELECTION_LOADER (is_active='Y')
   - Triggers automatic fetch of issues for ONLY selected plants
   
2. **Issue Selection**:
   - Issues dropdown populates with data for selected plants only
   - User selects specific issue revisions
   - Selected issues saved to SELECTION_LOADER with plant_id + issue_revision

#### **3. Full ETL Execution Order** (Processes ONLY selected data)
When user clicks "Run Full ETL", the system processes in this sequence:
1. **Issues** - Already fetched during selection
2. **Issue References** (Task 6) - For selected issues only:
   - PCS_REFERENCES, SC_REFERENCES, VSM_REFERENCES
   - VDS_REFERENCES, EDS_REFERENCES, MDS_REFERENCES  
   - VSK_REFERENCES, ESK_REFERENCES, PIPE_ELEMENT_REFERENCES
3. **PCS Details** (Task 7) - ONLY for PCS referenced in step 2
4. **VDS Details** (Task 8) - ONLY for VDS referenced in step 2
5. **BoltTension** (Task 9) - DEFERRED until all above complete successfully

#### **4. Change Management & Cascade Logic**
- **Plant change**: 
  - Deactivate old plant → cascade deactivate its issues → cascade deactivate all downstream
  - Activate new plant → fetch its issues → user selects issues → fetch downstream
- **Issue change**:
  - Deactivate old issue → cascade deactivate its references and downstream data
  - Activate new issue → fetch its references → fetch downstream details
- **Soft delete**: All tables use is_valid='N' instead of DELETE

#### **5. API Call Optimization Strategy**
- **Selection scoping**: Only fetch data for selected plants/issues (70% reduction)
- **SHA256 deduplication**: Skip unchanged API responses
- **Cascade fetching**: Only fetch downstream data that's actually referenced
- **Example**: 3 plants × 2 issues = 6 API calls for issues + their references
  (vs 100+ plants × all issues = 1000s of calls without selection)

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
- [x] 1.12 Ensure all schema changes are reflected in Master_DDL.sql only

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

- [x] 4.0 Build ETL Pipeline for Plants and Issues ✅
  - [x] 4.1 Create pkg_raw_ingest package for SHA256 deduplication and RAW_JSON insertion
  - [x] 4.2 Implement pkg_parse_plants to extract data from JSON using JSON_TABLE
  - [x] 4.3 Build pkg_upsert_plants with MERGE logic for current-state management
  - [x] 4.4 Create pkg_parse_issues to extract data from JSON using JSON_TABLE
  - [x] 4.5 Build pkg_upsert_issues with MERGE logic for current-state management
  - [x] 4.6 Develop pkg_etl_operations for orchestrating the full pipeline
  - [x] 4.7 Implement transaction safety with explicit COMMIT/ROLLBACK
  - [x] 4.8 Modify pkg_etl_operations to dynamically read CONTROL_ENDPOINTS
  - [ ] 4.9 Create APEX page for ETL control and monitoring (placeholder)
  - [ ] 4.10 Add ETL run buttons and status display to APEX

- [x] 5.0 Create pkg_api_client Package for API Integration ✅
  - [x] 5.1 Create package specification with APEX_WEB_SERVICE functions
  - [x] 5.2 Implement fetch_plants_json function using APEX_WEB_SERVICE
  - [x] 5.3 Implement fetch_issues_json function for specific plants
  - [x] 5.4 Add calculate_sha256 function using DBMS_CRYPTO
  - [x] 5.5 Create refresh_plants_from_api procedure (fetch + insert + process)
  - [x] 5.6 Create refresh_issues_from_api procedure
  - [x] 5.7 Add error handling and logging
  - [x] 5.8 Configure Oracle wallet with SSL certificates for HTTPS
  - [x] 5.9 Test API connectivity with APEX_WEB_SERVICE - WORKING!
  - [ ] 5.10 Create APEX page with API test buttons (placeholder for now)

- [ ] 6.0 Setup Automation [POST-PROJECT]
  - [ ] 6.1 Create DBMS_SCHEDULER job for daily plant refresh
  - [ ] 6.2 Create job for processing selected issues
  - [ ] 6.3 Add job monitoring page in APEX
  - [ ] 6.4 Implement email notifications on failure (optional)

- [ ] 6.0 Build ETL for Issue Reference Tables (Section 2 of API)
  - [ ] 6.1 Create database schema for PCS_REFERENCES table (STG_PCS_REFERENCES → PCS_REFERENCES)
  - [ ] 6.2 Create schemas for SC_REFERENCES, VSM_REFERENCES, VDS_REFERENCES tables
  - [ ] 6.3 Create schemas for EDS_REFERENCES, MDS_REFERENCES tables
  - [ ] 6.4 Create schemas for VSK_REFERENCES, ESK_REFERENCES tables
  - [ ] 6.5 Create schema for PIPE_ELEMENT_REFERENCES table (most complex with 11 fields)
  - [ ] 6.6 Build pkg_parse_references for JSON parsing of all 9 reference types
  - [ ] 6.7 Build pkg_upsert_references with MERGE logic for current-state management
  - [ ] 6.8 Add fetch functions to pkg_api_client for all reference endpoints
  - [ ] 6.9 Integrate with issue selection (auto-load references when issue selected)
  - [ ] 6.10 Create APEX pages to display reference data with drill-down capability
  - [ ] 6.11 Add reference counts to issue selection display
  - [ ] 6.12 Test cascade deletion when issues are deselected

- [ ] 7.0 Build ETL for PCS Detail Tables (Section 3 of API)
  - [ ] 7.1 Create schema for PCS list (PCS_LIST table with 14 fields)
  - [ ] 7.2 Create schema for PCS header and properties (PCS_HEADER table with 53 fields!)
  - [ ] 7.3 Create schema for temperature/pressure tables (PCS_TEMP_PRESSURE)
  - [ ] 7.4 Create schema for pipe sizes (PCS_PIPE_SIZES with 9 fields)
  - [ ] 7.5 Create schema for pipe elements (PCS_PIPE_ELEMENTS with 20 fields)
  - [ ] 7.6 Create schema for valve elements (PCS_VALVE_ELEMENTS with 17 fields)
  - [ ] 7.7 Create schema for embedded notes (PCS_EMBEDDED_NOTES)
  - [ ] 7.8 Build pkg_parse_pcs for all PCS-related JSON parsing
  - [ ] 7.9 Build pkg_upsert_pcs with MERGE logic
  - [ ] 7.10 Add PCS API functions to pkg_api_client
  - [ ] 7.11 Add to CONTROL_ENDPOINTS for dynamic processing
  - [ ] 7.12 Create APEX reports and detail pages for PCS data
  - [ ] 7.13 Implement PCS selection interface linked to plants

- [ ] 8.0 Build ETL for VDS Detail Tables (Section 4 of API)
  - [ ] 8.1 Create schema for VDS list (VDS_LIST - WARNING: 44,000+ records!)
  - [ ] 8.2 Create schema for VDS subsegments and properties (VDS_SUBSEGMENTS)
  - [ ] 8.3 Implement pagination handling for large VDS dataset
  - [ ] 8.4 Build pkg_parse_vds with performance optimization for large data
  - [ ] 8.5 Build pkg_upsert_vds with batch processing capability
  - [ ] 8.6 Add VDS API functions with timeout handling (30+ seconds)
  - [ ] 8.7 Create filtered VDS loading (only for referenced VDS from issues)
  - [ ] 8.8 Add VDS caching strategy to minimize API calls
  - [ ] 8.9 Create APEX interface with pagination for VDS display
  - [ ] 8.10 Add VDS search and filter capabilities
  - [ ] 8.11 Performance test with full 44,000 record load

- [ ] 9.0 Build ETL for BoltTension Tables (Section 5 of API)
  - [ ] 9.1 Create schema for Flange Type (BOLT_FLANGE_TYPE)
  - [ ] 9.2 Create schema for Gasket Type (BOLT_GASKET_TYPE)
  - [ ] 9.3 Create schema for Bolt Material (BOLT_MATERIAL)
  - [ ] 9.4 Create schema for Tension Forces (BOLT_TENSION_FORCES)
  - [ ] 9.5 Create schema for Tool (BOLT_TOOL)
  - [ ] 9.6 Create schema for Tool Pressure (BOLT_TOOL_PRESSURE)
  - [ ] 9.7 Create schema for Plant Info and Lubricant tables
  - [ ] 9.8 Build pkg_parse_bolttension for all 8 endpoints
  - [ ] 9.9 Build pkg_upsert_bolttension
  - [ ] 9.10 Add BoltTension API functions to pkg_api_client
  - [ ] 9.11 Create APEX calculator interface for bolt tension
  - [ ] 9.12 Link BoltTension data to PCS selections

- [ ] 10.0 Setup Automation [POST-PROJECT - Renumbered from 6.0]
  - [ ] 10.1 Create DBMS_SCHEDULER job for daily plant refresh
  - [ ] 10.2 Create job for processing selected issues
  - [ ] 10.3 Add job monitoring page in APEX
  - [ ] 10.4 Implement email notifications on failure (optional)

- [ ] 11.0 Testing and Validation [FUTURE - Renumbered from 7.0]
  - [ ] 11.1 Create PL/SQL unit tests for parsing and ETL procedures
  - [ ] 11.2 Build integration test for Plants → Issues pipeline
  - [ ] 11.3 Verify execution performance and optimization
  - [ ] 11.4 Test data retention and purge procedures
  - [ ] 11.5 Validate ETL_ERROR_LOG captures proper context
