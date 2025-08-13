# Product Requirements Document: TR2000 API Data Manager

## Introduction/Overview

The TR2000 API Data Manager is a data exploration and testing tool designed to import pipe class sheet data from the TR2000 API endpoints into a local SQLite database for analysis and testing purposes. Currently, piping engineers must manually extract data from PDF pipe class sheets and recreate it in databases for use in other applications. This tool will automate the data extraction process using the newly available TR2000 API. The eventual goal is to export all of this data to a database in oracle allowing engineers and other applications to use this data directly. Currently the scope is to export to a local sqllite database only to test data structure and quality before implementing a full-scale Oracle database solution.

The primary goal is to create a proof-of-concept system that demonstrates API data import capabilities while providing a structured foundation for future enterprise database migration.

## Goals

1. **Automate Data Import**: Replace manual PDF data extraction with automated API imports
2. **Database Structure Discovery**: Create SQLite tables that mirror API endpoint structures to inform Oracle database design
3. **Data Quality Assessment**: Enable engineers to review and validate API data completeness and accuracy
4. **Foundation for Scaling**: Establish architecture patterns for future enterprise-grade implementation
5. **User-Friendly Interface**: Provide intuitive web interface for data exploration and analysis

## User Stories

1. **As a piping engineer**, I want to import pipe class data from specific API endpoints so that I can analyze the data structure without manual PDF processing.

2. **As a database architect**, I want to see the exact table schemas generated from API data so that I can design corresponding Oracle database tables.

3. **As a project engineer**, I want to view pipe class data in a filterable grid so that I can quickly find relevant information for my current project.

4. **As a data analyst**, I want to export pipe class data to Excel so that I can perform offline analysis and reporting.

5. **As a system administrator**, I want clear error messages when API imports fail so that I can troubleshoot connectivity or data issues.

## Functional Requirements

### Data Import Requirements
1. The system must connect to TR2000 API endpoints at https://tr2000api.equinor.com/
2. The system must create SQLite database tables with column headers exactly matching API response structures
3. The system must use Dapper ORM for all database operations
4. The system must completely overwrite existing data on each import operation
5. The system must support manual import triggers per API endpoint
6. The system must log all import operations with timestamps and status

### Web Interface Requirements
7. The system must provide a dropdown selector for different API endpoints
8. The system must display imported data in DevExpress data grids
9. The system must load only data relevant to the selected API endpoint
10. The system must provide read-only data display (no editing capabilities)
11. The system must integrate with existing TR2K Blazor project structure
12. The system must maintain Blazor Auto rendering mode (client and server)

### Architecture Requirements
13. The system must create a separate "TR2KBlazorLibrary" project for business logic separation
14. The system must organize models in "TR2KBlazorLibrary/Models" folder
15. The system must organize business logic in "TR2KBlazorLibrary/Logic" folder
16. The system must keep sensitive operations in the server-side project only
17. The system must use dependency injection for service registration

### Error Handling Requirements
18. The system must log detailed error messages for failed API calls
19. The system must display user-friendly warning messages on import failures
20. The system must not display cached data when current import fails
21. The system must continue operation after individual endpoint failures

## Non-Goals (Out of Scope)

1. **Real-time Data Synchronization**: No automatic or scheduled imports (future Oracle implementation will handle nightly exports)
2. **Data Editing Capabilities**: No create, update, or delete operations on imported data
3. **User Authentication**: No user management or access control (using existing project setup)
4. **Advanced Grid Features**: No conditional formatting, complex reporting, or custom export features (to be handled by user with DevExpress components)
5. **Multi-database Support**: Only SQLite support, no PostgreSQL, SQL Server, or other database engines
6. **API Modification**: No changes to existing TR2000 API endpoints or data structures

## Design Considerations

- Leverage existing DevExpress components in TR2K project for consistent UI/UX
- Follow established Blazor Auto architecture patterns
- Maintain separation of concerns between presentation and business logic layers
- Use standard Bootstrap styling consistent with existing project theme
- Implement responsive design principles for various screen sizes

## Technical Considerations

### Dependencies
- **Dapper**: Required ORM for SQLite operations
- **Microsoft.Data.Sqlite**: SQLite database provider
- **System.Net.Http**: For API communication
- **DevExpress Blazor Components**: Already configured in existing project

### Database Design
- SQLite database file location: `Data/tr2000_api_data.db`
- Table naming convention: `[EndpointName]` (e.g., `PipeClassSheets`)
- Column names must exactly match API response property names.
- No foreign key relationships initially (flat table structure for testing)

### Project Structure
```
TR2K/
├── TR2KBlazorUI/ (existing)
└── TR2KBlazorLibrary/ (new)
    ├── Models/
    │   ├── ApiModels/
    │   └── DatabaseModels/
    └── Logic/
        ├── Services/
        └── Repositories/
```

## Success Metrics

1. **Import Success Rate**: >95% successful API data imports without errors
2. **Data Completeness**: 100% of API response fields mapped to SQLite columns
3. **User Adoption**: Piping engineers actively use tool instead of manual PDF processing
4. **Development Velocity**: Reduces database schema design time by 80% for Oracle implementation
5. **Error Recovery**: All API failures properly logged with actionable error messages

## Open Questions

1. **API Rate Limiting**: What are the rate limits for TR2000 API endpoints, and should we implement throttling?
2. **Data Volume**: What is the expected size of data per endpoint to optimize SQLite performance?
3. **Endpoint Discovery**: Should the system automatically discover available endpoints or use a predefined list?
4. **Data Retention**: How long should historical import data be retained in SQLite?
5. **Performance Monitoring**: Should we track import duration and data processing metrics?
6. **Deployment Strategy**: Will this run locally on engineer workstations or on a shared development server?