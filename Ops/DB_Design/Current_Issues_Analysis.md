# Current Issues Analysis - RAW_JSON Parameter Mismatch

## Issue Summary

**Primary Problem**: RAW_JSON table is empty and unused due to parameter mismatch between C# code and Oracle stored procedure.

**Impact**: The entire RAW_JSON audit trail layer is bypassed, violating industry ETL standards and missing critical benefits.

## Root Cause Analysis

### **Oracle Procedure Definition (Current):**
```sql
-- From Master_DDL_Script.sql, lines 285-315
CREATE OR REPLACE PROCEDURE SP_INSERT_RAW_JSON(
    p_etl_run_id NUMBER,           -- Parameter 1
    p_endpoint_name VARCHAR2,      -- Parameter 2  
    p_plant_id VARCHAR2,           -- Parameter 3
    p_json_data CLOB               -- Parameter 4
) AS
```

### **C# Code Calling (Current):**
```csharp
// From OracleETLServiceV2.cs, InsertRawJson method
await connection.ExecuteAsync(@"
    BEGIN
        SP_INSERT_RAW_JSON(
            p_endpoint      => :endpoint,      -- MISMATCH: Oracle expects p_endpoint_name
            p_key_string    => :keyString,     -- ERROR: Oracle doesn't have this parameter
            p_etl_run_id    => :etlRunId,      -- OK: Matches but wrong position
            p_http_status   => :httpStatus,    -- ERROR: Oracle doesn't have this parameter  
            p_duration_ms   => :durationMs,    -- ERROR: Oracle doesn't have this parameter
            p_headers_json  => :headers,       -- ERROR: Oracle doesn't have this parameter
            p_payload       => :payload        -- MISMATCH: Oracle expects p_json_data
        );
    END;",
```

### **Error Analysis:**

| C# Parameter | Oracle Parameter | Status | Issue |
|--------------|------------------|---------|--------|
| p_endpoint | p_endpoint_name | ❌ **NAME MISMATCH** | Different parameter names |
| p_key_string | - | ❌ **MISSING** | Oracle procedure doesn't have this parameter |
| p_etl_run_id | p_etl_run_id | ✅ **OK** | Matches but wrong position in call |
| p_http_status | - | ❌ **MISSING** | Oracle procedure doesn't have this parameter |
| p_duration_ms | - | ❌ **MISSING** | Oracle procedure doesn't have this parameter |
| p_headers_json | - | ❌ **MISSING** | Oracle procedure doesn't have this parameter |
| p_payload | p_json_data | ❌ **NAME MISMATCH** | Different parameter names |
| - | p_plant_id | ❌ **MISSING** | C# doesn't provide this parameter |

**Result**: 
- **C# sends**: 7 parameters
- **Oracle expects**: 4 parameters  
- **Matches**: 1 parameter (etl_run_id)
- **Outcome**: `ORA-06553: PLS-306: wrong number or types of arguments` error

## Evidence from Logs

### **Application Logs Show Failures:**
```
warn: TR2KBlazorLibrary.Logic.Services.OracleETLServiceV2[0]
      RAW_JSON insert failed (non-critical): ORA-06553: PLS-306: wrong number or types of arguments in call to 'SP_INSERT_RAW_JSON'

warn: TR2KBlazorLibrary.Logic.Services.OracleETLServiceV2[0]
      RAW_JSON insert failed (non-critical): Specified argument was out of the range of valid values.
```

### **C# Code Marks as "Non-Critical":**
```csharp
catch (Exception ex)
{
    // Non-critical - log and continue
    _logger.LogWarning($"RAW_JSON insert failed (non-critical): {ex.Message}");
}
```

**This "non-critical" approach masks a fundamental architecture violation!**

## Current Broken Data Flow

### **What Actually Happens:**
```
1. C# fetches data from API ✅
2. C# tries to insert to RAW_JSON ❌ FAILS (parameter mismatch)
3. C# logs warning and continues ⚠️ 
4. C# inserts directly to STG_TABLES ✅ (works)
5. Oracle processes STG → CORE tables ✅ (works)
```

### **Result:**
- **RAW_JSON table**: Empty (all inserts fail)
- **STG_TABLES**: Populated directly from API
- **Core ETL**: Works (but bypassing audit layer)
- **Smart Workflow**: Works (98.5% API reduction maintained)

## Missing Industry Benefits

### **Due to RAW_JSON Layer Being Bypassed:**

1. **No Audit Trail** 
   - Can't see what API actually returned on any given date
   - No forensic capability for data quality issues
   - Compliance/regulatory audit gaps

2. **No Replay Capability**
   - Can't re-process data without hitting API again
   - No ability to fix data issues retrospectively
   - Testing requires live API calls

3. **No Deduplication**
   - Same API response could be processed multiple times
   - No hash-based duplicate detection
   - Potential data quality issues

4. **No Schema Drift Protection**
   - New API fields not captured
   - Changes in API structure not tracked
   - Breaking changes cause silent data loss

5. **No Lineage Tracking**
   - Can't trace dimension records back to source API response
   - Debugging is much harder
   - Data governance requirements not met

## Comparison: Current vs Industry Standard

### **Current (Broken) Architecture:**
```
API Response (JSON)
       ↓
   [RAW_JSON] ← ❌ FAILS (parameter mismatch)
       ↓
   STG_TABLES ← ✅ Works (direct from API)
       ↓  
   DIM_TABLES ← ✅ Works (SCD2 processing)
```

### **Industry Standard Architecture:**
```
API Response (JSON)
       ↓
   RAW_JSON ← ✅ All responses stored with metadata
       ↓
   STG_TABLES ← ✅ Parsed from RAW_JSON via JSON_TABLE
       ↓  
   DIM_TABLES ← ✅ Works (existing SCD2 processing)
```

## Why This Went Unnoticed

### **Factors That Masked the Issue:**

1. **"Non-Critical" Handling**
   - C# code catches the error and continues
   - Logged as warning, not error
   - ETL appears to work because STG → DIM flow works

2. **Working Core Functionality** 
   - Smart Workflow achieves 98.5% API reduction
   - LoadOperators, LoadPlants, LoadIssues all work
   - Date parsing issue was resolved
   - User-visible features work perfectly

3. **Focus on Other Issues**
   - European date parsing consumed attention (Sessions 25-26)
   - Smart Workflow implementation (Sessions 24-25)
   - Performance optimization priorities

4. **Missing Architecture Review**
   - GPT-5 analysis in Session 27 revealed the violation
   - Industry standards comparison wasn't done earlier
   - Focus was on "getting it working" vs "getting it right"

## Fix Complexity Assessment

### **Oracle DDL Changes (Medium Complexity):**
- Update RAW_JSON table structure (add missing columns)
- Update SP_INSERT_RAW_JSON procedure (accept additional parameters)
- Create JSON_TABLE parsing procedures
- Add RAW_JSON_ID columns to staging tables

### **C# Code Changes (Low Complexity):**
- Update InsertRawJson method (fix parameter names/types)
- Update ETL flow to parse from RAW_JSON (vs direct API)
- Add processed flag management

### **Testing Required (Medium Complexity):**
- Validate RAW_JSON insertion works
- Test JSON_TABLE parsing to staging
- Ensure existing SCD2 processing unchanged
- Verify Smart Workflow performance maintained

### **Risk Assessment:**
- **Low Risk**: Core ETL works, only adding missing layer
- **No Breaking Changes**: Existing functionality preserved
- **Incremental**: Can implement and test step by step

## Recommended Approach

### **Session 28 Priority (Phase 1):**
1. Fix Oracle procedure parameter mismatch
2. Update C# InsertRawJson method
3. Test RAW_JSON insertion end-to-end

### **Session 29 Priority (Phase 2):**
1. Implement JSON_TABLE parsing procedures
2. Update ETL flow to parse from RAW_JSON
3. Add processed flag management

### **Session 30 Priority (Phase 3):**
1. Full end-to-end testing
2. Validate audit trail functionality
3. Test replay capability
4. Performance validation

## Success Criteria

### **Phase 1 Success:**
- RAW_JSON table receives all API responses
- No more "RAW_JSON insert failed" warnings
- Comprehensive metadata captured

### **Phase 2 Success:**
- STG_TABLES populated from RAW_JSON (not direct API)
- Processed flags managed correctly
- JSON_TABLE parsing working

### **Phase 3 Success:**
- Complete audit trail operational
- Replay functionality working
- Smart Workflow performance maintained (98.5% API reduction)
- Industry standard architecture achieved

---
**Document Status**: Analysis Complete
**Next Action**: Begin Session 28 implementation
**Priority**: Critical - Fundamental architecture compliance issue