# TR2000 API Data Manager - Project Status

## Current State (2025-08-13)
The TR2000 API Data Manager is a Blazor Server application (.NET 9.0) that interfaces with the TR2000 API to manage piping specification data. The project is approximately 95% complete with all major functionality working.

## Project Structure
```
/workspace/TR2000/TR2K/
├── TR2KApp/              # Main Blazor Server application
├── TR2KBlazorLibrary/    # Shared library with business logic
├── DatabaseCreator/      # SQLite database initialization
├── SchemaComparator/     # Database schema comparison tool
└── Ops/                  # Documentation and screenshots
```

## Key Technologies
- **Framework**: Blazor Server with .NET 9.0 (latest)
- **Database**: SQLite with Dapper ORM
- **API**: TR2000 API (https://equinor.pipespec-api.presight.com)
- **UI**: Bootstrap 5
- **Git Repo**: https://github.com/vivekN7/TR2000-API-Data-Manager.git
- **PAT Token**: [REDACTED - Ask user for new token if needed]

## Running the Application
```bash
# Kill any existing processes
pkill -f "dotnet.*run" || true

# Run the application (MUST use --host 0.0.0.0 in WSL/Docker)
cd /workspace/TR2000/TR2K/TR2KApp
/home/node/.dotnet/dotnet run --urls "http://0.0.0.0:5003"

# Access at: http://localhost:5003/api-data
```

## Completed Features

### 1. API Endpoint Management
- **Dynamic Endpoint Configuration**: All endpoints defined in `EndpointConfiguration.cs`
- **Sections Implemented**:
  - ✅ Operators and Plants (4 endpoints)
  - ✅ Issues - Collection of datasheets (13 endpoints)
  - ✅ PCS (1 endpoint)

### 2. Data Import Features
- **Test Connection**: Verify API connectivity before import
- **Import Data**: Fetch from API and store in SQLite
- **CSV Export**: Export filtered data to CSV
- **Dynamic Dropdowns**: Load related data (operators, plants, issues)
- **Dependent Dropdowns**: Revision fields populate based on plant selection

### 3. Table Features
- **Pagination**: Navigate through large datasets (100 records per page)
- **Search/Filter**: Real-time filtering across all columns
- **Sorting**: Click headers to sort (numeric and alphabetic)
- **Responsive Design**: Works on different screen sizes

### 4. Issues Section Special Features
- **Dynamic Revision Loading**: When plant selected, loads all issue revisions
- **Correct Revision Mapping**:
  - PCS references → PCSRevision
  - SC references → SCRevision
  - VSM references → VSMRevision
  - VDS references → VDSRevision
  - EDS references → EDSRevision
  - MDS references → MDSRevision
  - VSK references → VSKRevision
  - ESK references → ESKRevision
- **Revision Sorting**: Numbers first (1,2,10), then alphanumeric (1A, 2B)
- **Duplicate Removal**: Each revision appears only once
- **URL Encoding**: Handles special characters in revisions

## Known Issues & Solutions

### 1. Hot Reload Not Working
- **Issue**: Changes don't reflect without restart
- **Solution**: Kill process and restart after code changes

### 2. Server Binding in WSL/Docker
- **Issue**: Site stuck on loading
- **Solution**: Always use `--host 0.0.0.0` when starting server

### 3. Single Plant Endpoint
- **Issue**: Returns all plants instead of one
- **Solution**: Implemented - clears table and inserts only requested plant

### 4. Operator Plants Selection
- **Issue**: Always showed Equinor Europe plants
- **Solution**: Fixed parameter binding in dropdowns

## Database Structure
- **Pre-defined schema** in `CreateDatabase.sql`
- **No dynamic table creation** - all tables must exist
- **Tables**: operators, plants, issues, pcs, general_datasheet, etc.
- **Each endpoint maps to specific table** defined in EndpointConfiguration

## Important Code Locations

### Main UI Component
`/workspace/TR2000/TR2K/TR2KApp/Components/Pages/ApiData.razor`
- Handles all UI interactions
- Dynamic dropdown loading
- Filtering, sorting, pagination

### Endpoint Definitions
`/workspace/TR2000/TR2K/TR2KBlazorLibrary/Models/EndpointConfiguration.cs`
- All API endpoints configured here
- Parameter definitions
- Response field mappings

### Data Import Service
`/workspace/TR2000/TR2K/TR2KBlazorLibrary/Logic/Services/DataImportService.cs`
- Handles API data fetching
- Database operations
- Data transformation

## Next Steps / Remaining Work

1. **Add Remaining API Sections**:
   - PCS detailed endpoints
   - VDS (Valve Datasheets) section
   - EDS (Equipment Datasheets) section
   - MDS (Material Datasheets) section
   - Any other sections from API documentation

2. **Oracle Database Migration**:
   - Current SQLite is for testing
   - Need to transition to production Oracle database
   - Connection string changes
   - Potential stored procedure integration

3. **Authentication & Security**:
   - Add user authentication
   - Role-based access control
   - API key management

4. **Performance Optimization**:
   - Implement caching for frequently accessed data
   - Optimize large dataset handling
   - Add progress indicators for long operations

5. **Error Handling**:
   - Better error messages for users
   - Retry logic for failed API calls
   - Validation of input parameters

## Git Commands
```bash
# Commit changes
git add -A && git commit -m "Your message"

# Push to GitHub (token already configured in remote)
git push origin master

# Check status
git status
git log --oneline -10
```

## Development Tips
1. **Always rebuild after changes**: Hot reload doesn't work properly
2. **Check console output**: F12 in browser for debugging
3. **Use proper port binding**: `--host 0.0.0.0` is mandatory in WSL
4. **Test with small datasets first**: Some plants have many records
5. **Verify API endpoints**: Use browser to test API URLs directly

## Testing Checklist
- [ ] Select "Get operators" → Import → Should show all operators
- [ ] Select "Get plants" → Import → Should show all plants
- [ ] Select "Get plant" → Enter ID 3 → Should show only Sleipner Vest
- [ ] Select "Get operator plants" → Choose operator → Should show correct plants
- [ ] Select any Issues endpoint → Choose plant → Revisions should populate
- [ ] Test filtering → Type in search box → Results should filter
- [ ] Test sorting → Click column headers → Should sort correctly
- [ ] Test pagination → Navigate pages → Should show different records
- [ ] Test CSV export → Should download filtered results

## Contact & Resources
- **API Documentation**: https://equinor.pipespec-api.presight.com
- **GitHub Repo**: https://github.com/vivekN7/TR2000-API-Data-Manager
- **Current Port**: 5003 (can be changed if needed)

## Session Recovery
If starting fresh Claude Code session:
1. Open this START_HERE.md file first
2. Check git status for any uncommitted changes
3. Start the application with proper host binding
4. Continue from "Next Steps" section above

---
Last Updated: 2025-08-13
Session ended due to context limit approaching
All changes pushed to GitHub