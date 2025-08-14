# TR2000 API Data Manager - Project Status

## Current State (2025-08-14)
The TR2000 API Data Manager is a Blazor Server application (.NET 9.0) that interfaces with the TR2000 API to manage piping specification data. The project is approximately 95% complete with all reference endpoints now working correctly.

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

## Recent Work

### 2025-08-14 Session (Part 4)
1. **Fixed Data Import Behavior**:
   - Reference data now clears existing records for PlantID/IssueRevision before import
   - Issues clear existing records for PlantID before import
   - PCS clears existing records for PlantID before import
   - Importing different revisions now replaces data instead of appending

### 2025-08-14 Session (Part 3)
1. **Fixed Parameter Names and Display**:
   - Changed parameter names to uppercase (PLANTID, ISSUEREV, OPERATORID)
   - Fixed parameter type display to show actual types not hardcoded [Int32]
   - Updated URL building to convert uppercase params to lowercase
   - Parameter display now correctly shows: PLANTID=[String] ISSUEREV=[String]

### 2025-08-14 Session (Part 2)
1. **Fixed PlantID Type and Alphanumeric Support**:
   - Changed PlantID from INTEGER to TEXT in database
   - Updated all models (Plant, PCS, Issue) to use string for PlantID
   - Fixed regex to accept alphanumeric plant IDs (e.g., "JSV")
   - Corrected endpoint parameter types in UI display
   - Application now supports both numeric (105) and alphanumeric (JSV) plant IDs

### 2025-08-14 Session (Part 1)
1. **Fixed Reference Table Column Mismatch**:
   - Analyzed API responses for all reference endpoints
   - Corrected column definitions in DatabaseCreator
   - SC, VSM, VDS, EDS, VSK, ESK: Now have OfficialRevision and Delta
   - MDS: Now has OfficialRevision, Delta, and Area
   - All reference endpoints now import successfully!

### 2025-08-13 Session
1. **Fixed Issues Section Endpoints**:
   - Corrected URL format from `/issues/{issueRevision}/pcs-references` to `/issues/rev/{issueRevision}/pcs`
   - Fixed all 9 reference endpoints (PCS, SC, VSM, VDS, EDS, MDS, VSK, ESK, Pipe Elements)

2. **Database Updates**:
   - Added 9 new tables for reference endpoints
   - Fixed database permissions (chmod 666)
   - Updated connection string with proper settings

3. **UI Improvements**:
   - Added clickable hyperlink showing full API URL in endpoint details
   - All endpoints now visible and accessible

4. **Repository Updates**:
   - Updated DataImportService to handle reference tables
   - Added dynamic data import/export functionality

### Known Issues & Solutions

### RECENTLY FIXED ISSUES (2025-08-14)

### 1. ✅ Reference Table Column Mismatch - FIXED
- **Issue**: All reference tables except PCS had column mismatch errors
- **Solution Applied**: 
  - Tested each reference endpoint to get actual response structure
  - Updated database tables with correct columns:
    - SC, VSM, VDS, EDS, VSK, ESK: Added OfficialRevision and Delta columns
    - MDS: Added OfficialRevision, Delta, and Area columns
  - Recreated database with correct schema
  - All reference endpoints now work correctly!

### 2. Hot Reload Not Working
- **Issue**: Changes don't reflect without restart
- **Solution**: Kill process and restart after code changes

### 3. Server Binding in WSL/Docker
- **Issue**: Site stuck on loading
- **Solution**: Always use `--host 0.0.0.0` when starting server

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
   - PCS detailed endpoints (if any)
   - Other sections from API documentation

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

## Session Recovery for Next Time
When starting fresh Claude Code session:
1. Open this `/workspace/TR2000/TR2K/Ops/TR2K_START_HERE.md` file first
2. Check git status: `cd /workspace/TR2000/TR2K && git status`
3. Pull latest changes: `git pull origin master`
4. Start the application: `cd /workspace/TR2000/TR2K/TR2KApp && /home/node/.dotnet/dotnet run --urls "http://0.0.0.0:5003"`
5. Focus on fixing reference table columns (see CURRENT ISSUES above)

## Quick Test Commands
```bash
# Test SC references (should fail with column error)
curl -s "https://equinor.pipespec-api.presight.com/plants/34/issues/rev/1/sc" | python3 -m json.tool | head -20

# Test VSM references (should fail with column error)  
curl -s "https://equinor.pipespec-api.presight.com/plants/34/issues/rev/1/vsm" | python3 -m json.tool | head -20

# Compare with PCS which works
curl -s "https://equinor.pipespec-api.presight.com/plants/34/issues/rev/1/pcs" | python3 -m json.tool | head -20
```

---
Last Updated: 2025-08-14 (End of Day)
- ✅ FIXED: All reference table column mismatches resolved
- ✅ FIXED: PlantID now supports alphanumeric values (e.g., "JSV")
- ✅ FIXED: Endpoint parameter types corrected in UI display
- All reference endpoints (PCS, SC, VSM, VDS, EDS, MDS, VSK, ESK) now working
- Database schema updated to support TEXT for PlantID
- All changes committed locally (NOT pushed to GitHub)