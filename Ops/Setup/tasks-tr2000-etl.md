# Task List: TR2000 ETL System Implementation

## Relevant Files

### Critical Reference Documentation
- `/workspace/TR2000/TR2K/Ops/Setup/TR2000_API_Endpoints_Documentation.md` - **CRITICAL**: Contains all endpoints and data fields to be transferred to database tables via ETL operations. Must be referenced when implementing any table structure.

### Database Schema & Procedures
- `/workspace/TR2000/TR2K/Database/Master_DDL.sql` - Main DDL file containing all schema definitions (RAW_JSON, STG_*, CORE, control tables)
- `/workspace/TR2000/TR2K/Database/Procedures/pkg_raw_ingest.sql` - Package for RAW_JSON deduplication and insertion
- `/workspace/TR2000/TR2K/Database/Procedures/pkg_parse_plants.sql` - JSON parsing procedures for Plants endpoint
- `/workspace/TR2000/TR2K/Database/Procedures/pkg_upsert_plants.sql` - MERGE procedures for CORE.PLANTS table
- `/workspace/TR2000/TR2K/Database/Procedures/pkg_parse_issues.sql` - JSON parsing procedures for Issues endpoint
- `/workspace/TR2000/TR2K/Database/Procedures/pkg_upsert_issues.sql` - MERGE procedures for CORE.ISSUES table
- `/workspace/TR2000/TR2K/Database/Procedures/pkg_etl_operations.sql` - ETL orchestration and logging procedures
- `/workspace/TR2000/TR2K/Database/Tests/test_etl_pipeline.sql` - PL/SQL unit tests for ETL operations

### C# Application Files
- `/workspace/TR2000/TR2K/TR2KApp/Pages/ETLOperations.razor` - **SINGLE UNIFIED PAGE** for all ETL operations (selection, monitoring, testing, dashboard)
- `/workspace/TR2000/TR2K/TR2KBlazorLibrary/Services/ETLService.cs` - Core ETL orchestration service using Dapper
- `/workspace/TR2000/TR2K/TR2KBlazorLibrary/Services/SelectionService.cs` - Manages SELECTION_LOADER table operations
- `/workspace/TR2000/TR2K/TR2KBlazorLibrary/Models/ETLModels.cs` - Data models for ETL entities
- `/workspace/TR2000/TR2K/TR2KApp/appsettings.json` - Configuration including Oracle connection strings

### Test Files
- `/workspace/TR2000/TR2K/Tests/ETLService.Tests.cs` - Unit tests for ETL service
- `/workspace/TR2000/TR2K/Tests/SelectionService.Tests.cs` - Unit tests for selection service
- `/workspace/TR2000/TR2K/Tests/Fixtures/plants_response.json` - Mock API response for Plants endpoint
- `/workspace/TR2000/TR2K/Tests/Fixtures/issues_response.json` - Mock API response for Issues endpoint

### Notes

- The existing TR2000ApiService and ApiResponseDeserializer can be leveraged for API calls
- Database operations must use Dapper exclusively as per PRD requirements
- All transformations must be in Oracle stored procedures, not C# code
- **DO NOT** reuse legacy patterns without explicit permission - the previous attempt became too messy
- Focus on Plants and Issues FIRST - get these fully working before moving to references
- Keep most logic in Oracle as final orchestrator may be Oracle APEX (not C#)
- Use `dotnet test` to run C# unit tests
- PL/SQL tests should be executed directly in Oracle using the test scripts

## Tasks

- [ ] 1.0 Setup Core Database Schema for Plants and Issues ONLY
  - [ ] 1.1 Review TR2000_API_Endpoints_Documentation.md to understand Plants and Issues data fields
  - [ ] 1.2 Create Master_DDL.sql with RAW_JSON table (including sha256 hash, endpoint_key, plant, issue_rev columns)
  - [ ] 1.3 Define STG_PLANTS staging table with all VARCHAR2 columns matching API response
  - [ ] 1.4 Define STG_ISSUES staging table with all VARCHAR2 columns matching API response
  - [ ] 1.5 Create CORE.PLANTS table with proper data types and is_valid soft delete flag
  - [ ] 1.6 Create CORE.ISSUES table with proper data types and is_valid soft delete flag
  - [ ] 1.7 Setup SELECTION_LOADER table for storing user-selected plants and issues
  - [ ] 1.8 Create ETL control tables (CONTROL_ENDPOINTS, CONTROL_SETTINGS, CONTROL_ENDPOINT_STATE)
  - [ ] 1.9 Define ETL_RUN_LOG and ETL_ERROR_LOG tables for monitoring and error tracking
  - [ ] 1.10 Create indexes for performance optimization on key columns
- [ ] 1.11 Populate CONTROL_ENDPOINTS with initial Plants + Issues configs
- [ ] 1.12 Ensure all schema changes are reflected in Master_DDL.sql only. No other DDL scripts should exist outside this file

- [ ] 2.0 Build Unified ETL Operations Page
  - [ ] 2.1 Create single ETLOperations.razor page with multiple sections
  - [ ] 2.2 Add Plant Selection section with dropdown populated from API
  - [ ] 2.3 Add Issue Selection section that loads issues only for selected plants
  - [ ] 2.4 Implement SelectionService.cs to manage SELECTION_LOADER table operations using Dapper
  - [ ] 2.5 Add cascade logic in Oracle procedures to update dependent data when plants are removed
  - [ ] 2.6 Implement validation to limit selection to maximum 10 plants
  - [ ] 2.7 Create stored procedures for selection management (insert, update, cascade deletes)
  - [ ] 2.8 Add selection persistence across application restarts

- [ ] 3.0 Build ETL Pipeline for Plants and Issues ONLY
  - [ ] 3.1 Create pkg_raw_ingest package for SHA256 deduplication and RAW_JSON insertion
  - [ ] 3.2 Implement pkg_parse_plants to extract data from JSON using JSON_TABLE (reference API documentation)
  - [ ] 3.3 Build pkg_upsert_plants with MERGE logic for current-state management
  - [ ] 3.4 Create pkg_parse_issues to extract data from JSON using JSON_TABLE (reference API documentation)
  - [ ] 3.5 Build pkg_upsert_issues with MERGE logic for current-state management
  - [ ] 3.6 Develop pkg_etl_operations for orchestrating the full pipeline per endpoint
  - [ ] 3.7 Implement transaction safety with explicit COMMIT/ROLLBACK in all procedures
  - [ ] 3.8 Add pr_purge_raw_json procedure for manual data retention management
  - [ ] 3.9 Create minimal ETLService.cs to orchestrate API calls and procedure execution via Dapper
- [ ] 3.10 Modify pkg_etl_operations to dynamically read CONTROL_ENDPOINTS instead of hardcoding endpoints

- [ ] 4.0 Add Monitoring and Testing to ETL Operations Page
  - [ ] 4.1 Add monitoring section to ETLOperations.razor with card-based layout for run status
  - [ ] 4.2 Create error log viewer section showing ETL_ERROR_LOG entries with context
  - [ ] 4.3 Implement real-time progress indicators during ETL operations
  - [ ] 4.4 Add tabbed interface within the page for different views (Active Runs, History, Errors, Statistics)
  - [ ] 4.5 Create manual trigger buttons for Plants and Issues ETL runs
  - [ ] 4.6 Build statistics cards showing records loaded, updated, and invalidated
  - [ ] 4.7 Implement data preview functionality for CORE.PLANTS and CORE.ISSUES tables
  - [ ] 4.8 Add test execution section for running validation checks

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

- [ ] 6.0 Setup CI jobs for lint + unit tests
  - [ ] 6.1 Run PL/SQL syntax check + utPLSQL tests in containerized Oracle XE
  - [ ] 6.2 Run dotnet test for C# unit/integration tests
