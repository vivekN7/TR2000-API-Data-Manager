# Product Requirements Document: TR2000 ETL System

## Introduction/Overview

The TR2000 ETL System is a data integration solution designed to digitize and automate the current manual process of extracting data from PDFs. This system will establish an automated Extract, Transform, Load (ETL) pipeline from the Equinor TR2000 API to an Oracle database, replacing manual PDF reading with automated data synchronization. The solution will serve as a foundation for future integration with the company's pipe class sheet database.

## Goals

1. **Digitize Manual Processes**: Replace manual PDF reading with automated API-based data extraction
2. **Establish Reliable Data Pipeline**: Create a robust ETL process from TR2000 API to Oracle TR2000_STAGING schema
3. **Minimize API Calls**: Implement intelligent selection and caching to reduce API usage by 70%
4. **Enable Weekly Automation**: Support automated weekly data exports with full audit trails
5. **Provide Foundation for Integration**: Prepare data in a format suitable for merging with company pipe class sheet database

## User Stories

1. **As a data engineer**, I want to select specific plants and issue revisions through a UI so that I can control which data gets loaded without manual API calls.

2. **As a system administrator**, I want to view ETL run status and errors on a dashboard so that I can monitor system health and troubleshoot issues quickly.

3. **As a data analyst**, I want the system to automatically fetch only changed data so that API calls are minimized and data stays current.

4. **As an operations manager**, I want weekly automated exports so that our pipe class sheet database stays synchronized without manual intervention.

5. **As a developer**, I want comprehensive logging and error handling so that I can debug issues and maintain data integrity.

## Functional Requirements

### Core ETL Functionality
1. The system must load plant data from the "Get Plants" TR2000 API endpoint
2. The system must provide a dropdown interface to select up to 10 plants for processing
3. The system must store selected plants in a SELECTION_LOADER table
4. The system must load issue revisions for selected plants only
5. The system must allow selection of specific issue revisions per plant
6. The system must cascade selection changes throughout all dependent data
7. The system must maintain metadata tables (`CONTROL_ENDPOINTS`, `CONTROL_SETTINGS`, `CONTROL_ENDPOINT_STATE`) to drive ETL dynamically rather than hardcoding endpoints

### Data Processing Pipeline
8. The system must implement a three-stage data flow: RAW_JSON → STG_* → CORE
9. The system must store raw API responses with SHA256 deduplication
10. The system must parse JSON data into staging tables using set-based operations
11. The system must maintain current-state in CORE tables with soft validity (is_valid flag)
12. The system must track data lineage from raw JSON through to final tables

### Monitoring & Administration
13. The system must provide a dashboard showing ETL run status
14. The system must display error logs with context (endpoint, plant, issue revision)
15. The system must show loading progress with visual feedback
16. The system must display ETL statistics (records loaded, updated, invalidated)
17. The system must support manual triggering of ETL runs
18. The system must persist all run metadata into ETL_RUN_LOG
19. The system must log detailed errors in ETL_ERROR_LOG with endpoint/plant/issue context

### Database Operations
20. The system must use Oracle stored procedures for all data transformations
21. The system must implement transaction safety with explicit COMMIT/ROLLBACK
22. The system must log all errors to ETL_ERROR_LOG table
23. The system must support incremental loading to minimize API calls
24. The system must maintain metadata about last successful runs per endpoint

### Development Features
25. The system must provide advanced filtering and search capabilities during development
26. The system must support on-demand data refresh for testing
27. The system must provide detailed logging for debugging
28. The system must include test data fixtures for repeatable testing
29. The system must include PL/SQL unit tests for parsing, deduplication, and upserts
30. The system must include API mock fixtures to allow repeatable test runs

## Non-Goals (Out of Scope)

1. **Real-time data synchronization** - System will support weekly batch processing only
2. **Full production UI** - Final production UI design will be determined in a later phase
3. **Encryption implementation** - Security will be handled through network isolation initially
4. **Automated production deployment** - Initial deployment is for development environment only
5. **Complex data transformations** - Business logic beyond basic ETL will be minimal
6. **Historical data migration** - System focuses on current-state data, not full history
7. **Multi-tenant support** - System is designed for single organization use
8. **Mobile interface** - All interfaces will be web-based desktop applications

## Governance Rules
- Only Vivek may run `Master_DDL.sql` in target environments
- All schema and procedure changes must be reflected in Git before deployment
- Releases must be tagged after DDL/DML updates

## Design Considerations

### User Interface (Oracle APEX)
- Interactive Grid for plant selection with multi-select capability
- Dependent select lists for issue selection based on chosen plants
- Dashboard page with regions showing ETL statistics, recent runs, and errors
- Interactive Reports for viewing PLANTS, ISSUES, and reference data
- Process buttons to trigger ETL operations (calls PL/SQL procedures)
- Built-in Excel/CSV export functionality on all reports
- Automatic session state management and form validation
- Responsive design included by default in APEX Universal Theme

### Database Architecture
- Follow the established RAW_JSON → STG_* → CORE pattern
- Use VARCHAR2 for all staging table columns for schema-drift tolerance
- Implement soft deletion with is_valid flags rather than hard deletes
- Maintain single source of truth in CORE tables with current-state model (one row per business key, updated in place; disappearing records flagged is_valid='N')

## Technical Considerations

### Technology Stack
- **Complete Platform**: Oracle Database with APEX (Application Express)
- **API Integration**: APEX_WEB_SERVICE package for REST API calls
- **User Interface**: APEX Interactive Reports, Forms, and Dashboards
- **Backend Logic**: PL/SQL packages and procedures
- **Scheduling**: DBMS_SCHEDULER for automated ETL runs
- **Security**: APEX authentication and authorization schemes
- **Development**: APEX Builder + SQL Developer

### Architecture Constraints
- All DDL must be maintained in a single Master_DDL.sql file
- Complete solution implemented in Oracle/APEX (no external applications)
- API calls made directly from PL/SQL using APEX_WEB_SERVICE
- UI provided by Oracle APEX pages (no external frontend)
- Set-based operations only - no row-by-row processing

### API Integration
- Implement intelligent caching to achieve 70% reduction in API calls
- Use continuation tokens for paginated endpoints
- Store response SHA256 for deduplication
- Maintain CONTROL_ENDPOINTS metadata for configuration

### Performance Requirements
- Database operations must use set-based processing
- API calls must be minimized through selection scoping
- System must support concurrent reads during ETL operations

## Success Metrics

1. **Proof of Concept Delivery**: Functional system demonstrated within 5 days
2. **API Call Reduction**: Achieve 70% reduction in API calls through intelligent selection
3. **Data Integrity**: Zero data loss or corruption incidents during ETL operations
4. **Automation Success**: Successfully execute weekly automated ETL exports without manual intervention
5. **Processing Efficiency**: Complete ETL cycle for up to 10 plants within 1 minute
6. **Error Visibility**: 100% of errors logged with sufficient context for debugging
7. **Selection Accuracy**: Load data only for explicitly selected plants and issues

## Open Questions

1. **Authentication**: What authentication method will be used for the TR2000 API access? - A) No authentication. The API is publically available.
2. **Network Configuration**: Are there any firewall rules or proxy settings needed for API access? A) None
3. **Data Retention**: How long should RAW_JSON data be retained before purging (default 30 days)? A) Will be manually purged by user when needed. RAW_JSON retention must be managed by a purge procedure callable by TR2000_STAGING only. No DBA-level ILM or automatic jobs are allowed.
4. **Error Thresholds**: At what error rate should the ETL process automatically halt? A) Try to complete the full run once unless critical information missing in which case stop.
5. **Notification Requirements**: Should the system send alerts on failures? If so, through what channel? A) Will be indicated on dashboard
6. **Backup Strategy**: What is the recovery plan if ETL fails mid-process? A) no need for backups. The API is always available anyway and we can run it anytime after solving issue.
7. **Performance Baselines**: What are the current manual processing times for comparison? A) This is expected to finish within a minute since only few plants are required.
8. **Data Validation Rules**: Are there specific business rules for data quality that need to be enforced? A) Final core tables must be strongly typed
9. **Future Integration Points**: What specific fields are critical for pipe class sheet database integration? A) Not important right now. We need to ensure all data from the TR2000 API endpoints are available for the selected plants/issues regardless of whether they will be used further
10. **User Access Control**: Will different users have different levels of access to the selection interface? A) No need to worry about any access related issues at this stage.

---

*Document Version: 2.0*  
*Created: 2025-08-22*  
*Updated: 2025-08-22 - Pivoted to Oracle APEX-only architecture*  
*Target Delivery: Simplified with APEX - 2-3 days*  
*Audience: Oracle DBAs, APEX Developers, Data Engineers*

## Architecture Decision Record

**Decision Date**: 2025-08-22  
**Decision**: Pivot from Blazor/C# to pure Oracle APEX solution  
**Rationale**: 
- APEX is installed and configured
- Eliminates external dependencies
- Simplifies deployment and maintenance
- Provides all required functionality natively
- Reduces technology stack from 2 platforms to 1
- DBA team already familiar with APEX