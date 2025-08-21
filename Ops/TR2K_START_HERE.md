# TR2000 API Data Manager - Project Status

## 🔴 CRITICAL REMINDERS
1. **NEVER push to GitHub without explicit permission from the user**
2. **Commit locally as often as needed, but DO NOT use 'git push' unless specifically asked**
3. **Always ask before pushing: "Would you like me to push these changes to GitHub?"**
4. **ALWAYS use https://tr2000api.equinor.com/Home/Help for API endpoint documentation**
5. **DATABASE SECURITY POLICY - CRITICAL**:
   - **NEVER deploy DDL scripts from code or automation - EXTREMELY DANGEROUS!**
   - **NEVER add buttons that execute DDL or database scripts directly from the UI**
   - **DDL deployment must ALWAYS be done manually by the user via SQL Developer or similar tools**
   - **Claude must NEVER attempt to run sqlplus, deploy scripts, or execute DDL commands**

## 🛡️ DATA INTEGRITY & TRANSACTION SAFETY REQUIREMENTS
**ALL database operations MUST use transactions to ensure data integrity:**
1. **NEVER update/delete data without a transaction wrapper**
2. **ALWAYS fetch API data BEFORE starting any database transaction**
3. **Use try-catch-finally with explicit ROLLBACK on errors**
4. **Log all errors to ETL_ERROR_LOG table for audit trail**

## 📅 CRITICAL: MULTI-FORMAT DATE PARSING LESSON LEARNED
**NEVER FORGET: TR2000 API returns European timezone dates that require multi-format parsing!**

### The Recurring Problem:
- **TR2000 API** returns dates like: `"30.04.2025 09:50"` (DD.MM.YYYY HH24:MI format)
- **Default Oracle TO_DATE** expects: `'YYYY-MM-DD'` format
- **Result**: ORA-01858 and ORA-01830 errors that cause hours of debugging circles

### The Solution (IMPLEMENTED):
**Always use `PARSE_TR2000_DATE()` function in Oracle ETL transformations:**
```sql
-- DON'T DO THIS (will fail with European dates):
TO_DATE(s.REV_DATE, 'YYYY-MM-DD')

-- DO THIS (handles multiple formats):
PARSE_TR2000_DATE(s.REV_DATE)
```

### Critical Architecture Principle:
1. **Staging Tables**: Store raw API strings (VARCHAR2) - no parsing!
2. **Transformation Layer**: Use multi-format parsing during ETL (Oracle PARSE_TR2000_DATE function)
3. **Dimension Tables**: Clean DATE columns

**This pattern prevents date parsing circles and follows proper ETL architecture principles.**

## Current State (2025-08-21 - Session 27) - 🚨 CRITICAL RAW_JSON ARCHITECTURE ISSUE IDENTIFIED!

### ✅ SESSION 26 SUCCESS - SMART WORKFLOW FULLY OPERATIONAL!
- **Performance Achievement**: 98.5% API call reduction (2 calls vs 131 calls)
- **LoadIssues Result**: ✅ 20 records inserted, Enhanced 2 plants perfectly
- **Date Parsing Issue**: ✅ PERMANENTLY RESOLVED with `PARSE_TR2000_DATE()` Oracle function
- **Smart Enhancement**: ✅ `EnhancePlantsWithDetailedData()` working flawlessly
- **Build Status**: ✅ Production ready at http://localhost:5005/etl-operations

### 🚨 **CRITICAL ISSUE DISCOVERED - RAW_JSON ARCHITECTURE BROKEN**
**GPT-5 Analysis Revealed Fundamental Architecture Problem:**

#### Current (WRONG) Flow:
```
API → STG_TABLES → ISSUES (bypassing RAW_JSON entirely)
```

#### Should Be (INDUSTRY STANDARD):
```
API → RAW_JSON → STG_TABLES → ISSUES
```

#### Root Cause Analysis:
1. **Parameter Mismatch**: C# calls SP_INSERT_RAW_JSON with 7 parameters, Oracle procedure expects 4
2. **Table Design Issues**: RAW_JSON uses BLOB storage without JSON capabilities
3. **Missing Features**: No processed flag, no deduplication hash, no request context
4. **Architecture Violation**: STG tables reading directly from API instead of RAW_JSON

#### Impact:
- **No audit trail** of actual API responses
- **No ability to replay** or debug data issues  
- **Missing the core benefit** of the three-layer architecture

## Project Structure
```
/workspace/TR2000/TR2K/
├── TR2KApp/              # Main Blazor Server application
├── TR2KBlazorLibrary/    # Shared library with business logic
└── Ops/                  # Documentation and DDL scripts
    ├── Master_DDL_Script.sql    # Current production DDL
    ├── backup_session26/        # OLD documentation (archived)
    └── DB_Design/               # NEW architecture analysis
```

## Key Technologies
- **Framework**: Blazor Server with .NET 9.0
- **Database**: Oracle 21c XE with SCD2 temporal tracking
- **API**: TR2000 API (https://equinor.pipespec-api.presight.com)
- **UI**: Bootstrap 5
- **Git Repo**: https://github.com/vivekN7/TR2000-API-Data-Manager.git

## Running the Application
```bash
# Kill any existing processes
pkill -f "dotnet.*run" || true

# Run the application (MUST use --host 0.0.0.0 in WSL/Docker)
cd /workspace/TR2000/TR2K/TR2KApp
/home/node/.dotnet/dotnet run --urls "http://0.0.0.0:5005"

# Access at: http://localhost:5005/etl-operations
```

## Session Recovery for Next Time (IMPORTANT - START HERE!)
When starting fresh Claude Code session:
1. **REMEMBER**: Never push to GitHub without explicit permission!
2. **CRITICAL**: Read these files in order:
   - `/workspace/TR2000/TR2K/Ops/TR2K_START_HERE.md` (this file)
   - `/workspace/TR2000/TR2K/Ops/NEXT_SESSION_CRITICAL.md` (immediate next steps)
   - `/workspace/TR2000/TR2K/Ops/TR2K_PROGRESS.md` (detailed history)
3. Check git status: `cd /workspace/TR2000/TR2K && git status`
4. Start the application: 
   ```bash
   cd /workspace/TR2000/TR2K/TR2KApp 
   /home/node/.dotnet/dotnet run --urls "http://0.0.0.0:5005"
   ```
5. Access the ETL Operations page: http://localhost:5005/etl-operations

## Current Working Features (Session 26)
- ✅ **LoadOperators**: Working (8 records)
- ✅ **LoadPlants**: Working (130 records basic + smart enhancement)
- ✅ **LoadIssues**: Working (98.5% API reduction with smart workflow)
- ✅ **Date Parsing**: All European formats handled with PARSE_TR2000_DATE()
- ✅ **Smart Enhancement**: EnhancePlantsWithDetailedData() operational
- ❌ **RAW_JSON**: Broken architecture - needs complete refactor

## Next Priority: RAW_JSON Architecture Fix
**See `/workspace/TR2000/TR2K/Ops/NEXT_SESSION_CRITICAL.md` for detailed implementation plan**

---
**Last Updated**: 2025-08-21 (Session 27)
**Current Status**: Smart Workflow operational, RAW_JSON architecture needs refactor
**Next Session Priority**: Implement proper API → RAW_JSON → STG → CORE flow per GPT-5 recommendations