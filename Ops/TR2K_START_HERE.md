# TR2000 API Data Manager - Project Status

## 🔴 CRITICAL REMINDERS
1. **NEVER push to GitHub without explicit permission from the user**
2. **Commit locally as often as needed, but DO NOT use 'git push' unless specifically asked**
3. **Always ask before pushing: "Would you like me to push these changes to GitHub?"**

## Current State (2025-08-15)
The TR2000 API Data Manager is a Blazor Server application (.NET 9.0) that interfaces with the TR2000 API to manage piping specification data. The project is approximately 98% complete with all major functionality working correctly.

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

## Latest Updates (2025-08-15 - Session 5)

### NEW: Section 4 - VDS (Valve Datasheet) Implemented ✅
1. **Added VDS List Endpoint**
   - Endpoint: `/vds`
   - Returns complete list of all VDS items (44,070+ items)
   - Includes all VDS properties and subsegment lists
   - No parameters required (table filtering handles search)

2. **Added VDS Subsegments and Properties Endpoint**
   - Endpoint: `/vds/{vdsname}/rev/{revision}`
   - Returns VDS content details and subsegment information
   - Parameters: VDSNAME (text), REVISION (text)
   - Provides comprehensive valve specification details

3. **Database Layer Completely Removed**
   - All SQLite components removed for faster development
   - Application now fetches and displays API data directly
   - No intermediate storage - pure API-to-UI flow
   - DatabaseCreator and SchemaComparator projects deleted

## Previous Updates (2025-08-15 - Session 3)

### Major Improvements Completed Today:
1. **✅ Fixed pipe_element_references table schema**
   - Corrected column mismatch issue
   - Table now matches API response structure exactly
   - All pipe element imports working correctly

2. **✅ Enhanced Loading Experience**
   - Added loading spinner with informative messages
   - Table clears immediately when loading starts
   - All controls (buttons, inputs, dropdowns) disabled during loading
   - Clear visual feedback for long-running operations
   - Users can see exactly what's happening during imports

3. **✅ Added Complete PCS Section (Section 3)**
   - Implemented all 7 PCS endpoints:
     - Get PCS list (already existed)
     - Get header and properties
     - Get temperature and pressure  
     - Get pipe size
     - Get pipe element
     - Get valve element
     - Get embedded note
   - Created corresponding database tables for each endpoint
   - All PCS endpoints use dropdown parameters:
     - Plant selection (auto-populated from plants table)
     - PCS ID selection (filtered by selected plant)
     - Revision selection (filtered by selected PCS)

### Latest Fixes (2025-08-15 - Session 3):
1. **✅ Fixed All PCS Detail Endpoints**:
   - Corrected endpoint URLs to match actual API patterns
   - Properties: `/properties`
   - Pipe sizes: `/pipe-sizes`
   - Pipe elements: `/pipe-elements`
   - Valve elements: `/valve-elements`
   - Embedded notes: `/embedded-notes`
   - Temperature/pressure: `/temp-pressures` (not `/temperature-pressure`)
   - Removed all "NOT AVAILABLE" and "404 not implemented" labels

2. **✅ Fixed Properties Endpoint Deserialization**:
   - Properties endpoint returns nested arrays (getPCSMapping, getPCSManufacturers)
   - Updated deserializer to flatten multiple nested arrays into separate table rows
   - Each nested array item now shows as individual row with parent context
   - Test Connection button now correctly counts all nested items

3. **✅ Fixed Test Connection Button**:
   - Now properly counts records for endpoints with nested arrays
   - Uses same logic as deserializer for consistency
   - Shows accurate record count for all endpoint types

## Latest Fixes (2025-08-14 - Earlier Sessions)
1. **✅ Reference Table Columns**: Fixed to match API response structure
2. **✅ PlantID Support**: Now supports alphanumeric IDs (e.g., "JSV", "110")
3. **✅ Parameter Display**: Shows correct names (PLANTID, ISSUEREV) and types [String]
4. **✅ Data Import Behavior**: Tables now clear completely to mirror API responses exactly

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
1. **Fixed Data Import to Mirror API Responses**:
   - ALL tables now clear completely before importing new data
   - SQLite database mirrors exactly what the API returns
   - No accumulation of data from multiple API calls
   - Each import completely replaces the table contents
   - Database acts as a true mirror of the last API endpoint response

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

### ALL MAJOR ISSUES FIXED (2025-08-14)

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

### COMPLETED: Section 4 - VDS ✅
- VDS list endpoint implemented (`/vds`)
- VDS subsegments and properties endpoint implemented (`/vds/{vdsname}/rev/{revision}`)
- Both endpoints working and tested successfully

### Future Work:
1. **Add Remaining API Sections**:
   - Continue adding other sections from API documentation

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
1. **REMEMBER**: Never push to GitHub without explicit permission!
2. Open this `/workspace/TR2000/TR2K/Ops/TR2K_START_HERE.md` file first
3. Check git status: `cd /workspace/TR2000/TR2K && git status`
4. Pull latest changes: `git pull origin master`
5. Start the application: `cd /workspace/TR2000/TR2K/TR2KApp && /home/node/.dotnet/dotnet run --urls "http://0.0.0.0:5003"`
6. Access at: http://localhost:5003/api-data
7. Review "Next Steps / Remaining Work" section below for tasks

## Quick Test Commands
```bash
# Test SC references (should fail with column error)
curl -s "https://equinor.pipespec-api.presight.com/plants/34/issues/rev/1/sc" | python3 -m json.tool | head -20

# Test VSM references (should fail with column error)  
curl -s "https://equinor.pipespec-api.presight.com/plants/34/issues/rev/1/vsm" | python3 -m json.tool | head -20

# Compare with PCS which works
curl -s "https://equinor.pipespec-api.presight.com/plants/34/issues/rev/1/pcs" | python3 -m json.tool | head -20
```

## Technical Notes for Next Session:

### PCS Dropdown Issue Investigation Points:
1. **Check ApiData.razor LoadDropdownData method**:
   - Look at line ~500-600 where dropdown data is loaded
   - See how it handles the "pcs" dropdown source
   - Compare with how "issues" dropdown works (which is functioning)

2. **Possible Issues**:
   - PCS table might need PlantID column for filtering
   - LoadDropdownData might not be fetching PCS data correctly when PLANTID changes
   - Revision dropdown might need special handling since multiple PCS can have same revision

3. **Debug Steps**:
   - Add console logging to see what data is being fetched
   - Check browser F12 console for any JavaScript errors
   - Verify PCS data exists in database after importing "Get PCS list"

---
Last Updated: 2025-08-15 (Session 3)
## Summary of Recent Major Fixes:
- ✅ FIXED: All PCS detail endpoint URLs corrected to match actual API patterns
- ✅ FIXED: Properties endpoint deserializer now handles multiple nested arrays
- ✅ FIXED: Test Connection button correctly counts records in nested arrays
- ✅ FIXED: Temperature/pressure endpoint uses correct URL (/temp-pressures)
- ✅ FIXED: PCS dropdown population issue - dropdowns now work correctly
- ✅ FIXED: All reference table column mismatches resolved  
- ✅ FIXED: PlantID now supports alphanumeric values (e.g., "JSV")
- ✅ FIXED: Endpoint parameter types corrected in UI display (PLANTID=[String], ISSUEREV=[String])
- ✅ FIXED: Data import now clears tables to mirror API responses exactly
- ✅ All reference endpoints (PCS, SC, VSM, VDS, EDS, MDS, VSK, ESK) working perfectly
- ✅ All PCS detail endpoints (properties, pipe-sizes, pipe-elements, valve-elements, embedded-notes, temp-pressures) working perfectly
- ✅ Database schema updated to support TEXT for PlantID
- ✅ Latest changes committed and pushed to GitHub (commit 9ab06bd)

## Application Status:
- **Functionality**: ~99% complete
- **All major features working**
- **PCS Section**: Fully operational with all 7 endpoints
- **VDS Section**: Fully operational with 2 endpoints
- **Database**: Completely removed - direct API display only

## Important Notes for Next Session:
1. **DO NOT push to GitHub without permission**
2. **NO DATABASE** - Application fetches and displays API data directly
3. All endpoint parameters use uppercase names (PLANTID, ISSUEREV, OPERATORID, VDSNAME)