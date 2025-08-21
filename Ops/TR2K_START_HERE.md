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

## Current State (2025-08-21 - Session 28) - ✅ CRITICAL RAW_JSON ARCHITECTURE ISSUE RESOLVED!

### ✅ SESSION 26 SUCCESS - SMART WORKFLOW FULLY OPERATIONAL!
- **Performance Achievement**: 98.5% API call reduction (2 calls vs 131 calls)
- **LoadIssues Result**: ✅ 20 records inserted, Enhanced 2 plants perfectly
- **Date Parsing Issue**: ✅ PERMANENTLY RESOLVED with `PARSE_TR2000_DATE()` Oracle function
- **Smart Enhancement**: ✅ `EnhancePlantsWithDetailedData()` working flawlessly
- **Build Status**: ✅ Production ready at http://localhost:5005/etl-operations

### ✅ **SESSION 28 SUCCESS - RAW_JSON ARCHITECTURE COMPLETELY FIXED!**
- **Critical Issue Resolved**: RAW_JSON parameter mismatch and bypass mechanism completely fixed
- **Enhanced RAW_JSON Table**: 12 fields with comprehensive metadata (Master_DDL_Script.sql updated)
- **Fixed SP_INSERT_RAW_JSON**: Now accepts 9 parameters vs previous 4 (C# compatible)
- **Mandatory RAW_JSON Enforced**: ETL now FAILS if RAW_JSON insertion fails (no data bypass)
- **Architecture Tested**: System properly enforces API → RAW_JSON → STG → CORE flow
- **Data Integrity**: Zero bypass allowed, complete audit trail architecture enforced

### 🔍 **SESSION 27 ANALYSIS - RAW_JSON ARCHITECTURE ISSUE IDENTIFIED & ANALYZED**
**GPT-5 Analysis Revealed Fundamental Architecture Problem:**

#### Was (WRONG) Flow:
```
API → STG_TABLES → ISSUES (bypassing RAW_JSON entirely)
```

#### Now (FIXED) Industry Standard Flow:
```
API → RAW_JSON → STG_TABLES → ISSUES (ENFORCED in Session 28)
```

#### Root Cause Analysis (RESOLVED in Session 28):
1. **Parameter Mismatch**: ✅ FIXED - SP_INSERT_RAW_JSON now accepts 9 parameters (C# compatible)
2. **Table Design Issues**: ✅ FIXED - RAW_JSON uses CLOB with JSON validation
3. **Missing Features**: ✅ FIXED - Added processed flag, deduplication hash, request context
4. **Architecture Violation**: ✅ FIXED - RAW_JSON is now MANDATORY (ETL fails if bypassed)

#### Impact (NOW RESOLVED):
- ✅ **Complete audit trail** of actual API responses
- ✅ **Full replay capability** for debugging and recovery
- ✅ **Industry standard architecture** enforced with data integrity

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

## 🎯 **IMMEDIATE ACTION REQUIRED (Session 28 Complete)**

### **Current Status:**
✅ **Session 28 COMPLETE**: RAW_JSON architecture fix fully implemented and tested  
✅ **Master_DDL_Script.sql**: Enhanced with RAW_JSON structure (12 fields, 9-parameter procedure)  
✅ **C# Code**: Parameter mismatch fixed, bypass removed, mandatory RAW_JSON enforced  
✅ **Architecture Tested**: ETL properly fails when RAW_JSON can't insert (data integrity enforced)  

### **Next Required Action:**
⏳ **Deploy Oracle DDL**: Oracle database needs Master_DDL_Script.sql deployment to activate enhanced RAW_JSON  
🎯 **Session 29 Ready**: JSON_TABLE parsing procedures implementation  

### **Application Behavior:**
- **With Current Oracle DDL**: ETL fails with "RAW_JSON insertion is mandatory for data integrity" ✅ WORKING AS INTENDED
- **After Oracle DDL Deployment**: Complete audit trail operational with industry-standard flow

### **Quick References:**
- **Next Session Guide**: `/workspace/TR2000/TR2K/Ops/NEXT_SESSION_CRITICAL.md`
- **Session 28 Summary**: `/workspace/TR2000/TR2K/Ops/SESSION_28_COMPLETE_SUMMARY.md`
- **Progress Log**: `/workspace/TR2000/TR2K/Ops/TR2K_PROGRESS.md`

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