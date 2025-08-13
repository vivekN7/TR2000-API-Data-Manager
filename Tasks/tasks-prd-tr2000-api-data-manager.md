# Task List: TR2000 API Data Manager Implementation

## Relevant Files

- `TR2KBlazorLibrary/TR2KBlazorLibrary.csproj` - New class library project for business logic separation (CREATED/UPDATED - Added logging and configuration packages)
- `TR2KBlazorLibrary/Models/ApiModels/TR2000ApiResponse.cs` - Models for TR2000 API response structures (CREATED)
- `TR2KBlazorLibrary/Models/ApiModels/PipeClassSheetData.cs` - Specific model for pipe class sheet data (CREATED)
- `TR2KBlazorLibrary/Models/DatabaseModels/BaseEntity.cs` - Base entity for database models (CREATED)
- `TR2KBlazorLibrary/Models/DatabaseModels/ImportLog.cs` - Model for tracking import operations (CREATED)
- `TR2KBlazorLibrary/Logic/Services/ITR2000ApiService.cs` - Interface for API service (CREATED)
- `TR2KBlazorLibrary/Logic/Services/TR2000ApiService.cs` - Implementation of TR2000 API integration (CREATED)
- `TR2KBlazorLibrary/Logic/Services/ApiResponseDeserializer.cs` - Advanced JSON deserialization with dynamic mapping (CREATED)
- `TR2KBlazorLibrary/Logic/Services/IDataImportService.cs` - Interface for data import service (CREATED)
- `TR2KBlazorLibrary/Logic/Services/DataImportService.cs` - Service for managing data imports (CREATED)
- `TR2KBlazorLibrary/Logic/Services/DynamicTableCreator.cs` - Advanced table creation with schema analysis (CREATED)
- `TR2KBlazorLibrary/Logic/Services/DataManagementService.cs` - Comprehensive data management operations (CREATED)
- `TR2KBlazorLibrary/Logic/Services/ErrorHandlingService.cs` - Centralized error handling and logging (CREATED)
- `TR2KBlazorLibrary/Logic/Services/ImportProgressTracker.cs` - Advanced progress tracking and notifications (CREATED)
- `TR2KBlazorLibrary/Logic/Repositories/IGenericRepository.cs` - Generic repository interface (CREATED)
- `TR2KBlazorLibrary/Logic/Repositories/GenericRepository.cs` - Dapper-based generic repository implementation (CREATED)
- `TR2KBlazorLibrary/Logic/Repositories/ISqliteConnectionFactory.cs` - Interface for SQLite connection factory (CREATED)
- `TR2KBlazorLibrary/Logic/Repositories/SqliteConnectionFactory.cs` - SQLite connection factory implementation (CREATED)
- `TR2KBlazorUI/Components/Pages/ApiDataViewer.razor` - Main page for viewing API data
- `TR2KBlazorUI/Components/Pages/ApiDataViewer.razor.cs` - Code-behind for API data viewer
- `TR2KBlazorUI/Components/Shared/ApiEndpointSelector.razor` - Component for selecting API endpoints
- `TR2KBlazorUI/Components/Shared/DataImportProgress.razor` - Component for showing import progress
- `TR2KBlazorUI/Data/tr2000_api_data.db` - SQLite database file (created at runtime)
- `TR2KBlazorUI/appsettings.json` - Configuration file with database connection strings (UPDATED)
- `TR2KBlazorUI/appsettings.Development.json` - Development configuration with separate database (UPDATED)
- `TR2KBlazorUI/Program.cs` - Dependency injection registration for all services (UPDATED)

### Notes

- Use Dapper ORM for all database operations as specified in PRD
- SQLite database will be created automatically on first run
- Follow existing DevExpress component patterns for consistent UI
- Keep sensitive API operations on server-side only
- Unit tests should be added in future iterations but are not required for initial implementation

## Tasks

- [x] 1.0 **Setup TR2KBlazorLibrary Project and Infrastructure**
  - [x] 1.1 Create new class library project `TR2KBlazorLibrary` with .NET 9.0 target framework
  - [x] 1.2 Add required NuGet packages: Dapper, Microsoft.Data.Sqlite, Microsoft.Extensions.DependencyInjection
  - [x] 1.3 Create folder structure: Models/ApiModels, Models/DatabaseModels, Logic/Services, Logic/Repositories
  - [x] 1.4 Add project reference from TR2KBlazorUI to TR2KBlazorLibrary
  - [x] 1.5 Update TR2KBlazorUI _Imports.razor to include TR2KBlazorLibrary namespaces

- [x] 2.0 **Implement Data Access Layer with SQLite and Dapper**
  - [x] 2.1 Create ISqliteConnectionFactory interface with GetConnection() method
  - [x] 2.2 Implement SqliteConnectionFactory with connection string management and database initialization
  - [x] 2.3 Create IGenericRepository<T> interface with basic CRUD operations for dynamic table operations
  - [x] 2.4 Implement GenericRepository<T> using Dapper with methods for dynamic table creation and data operations
  - [x] 2.5 Create BaseEntity abstract class with common properties (Id, CreatedDate, ModifiedDate)
  - [x] 2.6 Create ImportLog model for tracking import operations with timestamp, endpoint, status, and error details
  - [x] 2.7 Add database connection string to appsettings.json with SQLite file path

- [x] 3.0 **Create TR2000 API Integration Services**
  - [x] 3.1 Create TR2000ApiResponse<T> generic model for API response structure
  - [x] 3.2 Create PipeClassSheetData model based on expected API response structure (initially generic, to be refined)
  - [x] 3.3 Create ITR2000ApiService interface with methods for GetEndpoints(), GetDataFromEndpoint(endpoint), TestConnection()
  - [x] 3.4 Implement TR2000ApiService using HttpClient with proper error handling and logging
  - [x] 3.5 Add API base URL configuration to appsettings.json
  - [x] 3.6 Implement API response deserialization with dynamic property mapping for unknown structures

- [x] 4.0 **Build Data Import and Management Logic**
  - [x] 4.1 Create IDataImportService interface with ImportFromEndpoint(endpoint), GetImportHistory(), ClearData(endpoint)
  - [x] 4.2 Implement DataImportService with logic to call API, dynamically create tables, and insert data
  - [x] 4.3 Add dynamic table creation logic that analyzes API response structure and creates matching SQLite tables
  - [x] 4.4 Implement data overwrite functionality that truncates existing data before inserting new data
  - [x] 4.5 Add comprehensive error handling with detailed logging for API failures and database errors
  - [x] 4.6 Create import progress tracking with status updates and completion notifications
  - [x] 4.7 Register all services in TR2KBlazorUI Program.cs with proper dependency injection

- [ ] 5.0 **Develop Web Interface for Data Display**
  - [ ] 5.1 Create ApiEndpointSelector component with dropdown for available endpoints and import trigger button
  - [ ] 5.2 Create DataImportProgress component to show import status, progress, and error messages
  - [ ] 5.3 Create ApiDataViewer.razor main page with endpoint selector and data grid display
  - [ ] 5.4 Implement ApiDataViewer.razor.cs code-behind with data loading, import triggering, and error handling
  - [ ] 5.5 Configure DxDataGrid component with dynamic column generation based on imported data structure
  - [ ] 5.6 Add navigation menu item for API Data Viewer in NavMenu.razor
  - [ ] 5.7 Implement proper loading states and error messaging for user feedback
  - [ ] 5.8 Add basic styling consistent with existing DevExpress theme and layout