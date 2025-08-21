# TR2000 ETL Fresh Start Implementation Plan

## 🎯 **CONTEXT: Why Starting Fresh**

After Session 29 architectural analysis, we identified the core issue: the current ETL implementation violates industry standards by bypassing the RAW_JSON audit layer and double-calling APIs. Starting fresh will implement proper architecture from day one without the complexity of untangling existing technical debt.

## 📋 **WHAT TO KEEP vs START FRESH**

### ✅ **KEEP (Proven Working Components):**
1. **TR2000 API Data Page** - UI works perfectly
2. **Oracle Database Schema** - Tables, SCD2 procedures, PARSE_TR2000_DATE function
3. **RAW_JSON Table Structure** - Enhanced 12-field design with audit trail
4. **SP_INSERT_RAW_JSON Procedure** - Fixed hash function, 9-parameter design
5. **Oracle SCD2 ETL Packages** - PKG_OPERATORS_ETL, PKG_PLANTS_ETL, PKG_ISSUES_ETL
6. **API Service Classes** - TR2000ApiService, ApiResponseDeserializer

### 🔥 **START FRESH:**
1. **OracleETLServiceV2** - Replace with clean OracleETLServiceV3
2. **Complex Enhancement Logic** - Eliminate unnecessary complexity
3. **Mixed Dapper Approaches** - Standardize parameter handling
4. **Inconsistent RAW_JSON Patterns** - Implement uniform approach

## 🏗️ **INDUSTRY-STANDARD ARCHITECTURE TO IMPLEMENT**

### **Correct ETL Flow:**
```
1. C# → TR2000 API → RAW_JSON (audit trail + deduplication)
2. Oracle → RAW_JSON → STG_TABLES (JSON_TABLE parsing)
3. Oracle → STG_TABLES → FINAL_TABLES (existing SCD2 logic)
```

### **Key Principles:**
- **Single API call per endpoint** (no redundant calls)
- **Complete audit trail** in RAW_JSON with replay capability
- **Oracle handles all data transformation** (no C# parsing/mapping)
- **Consistent error handling** with ETL_ERROR_LOG
- **Transactional integrity** throughout the pipeline

## 📂 **IMPLEMENTATION PHASES**

### **PHASE 1: Oracle Foundation (1 hour)**

#### **1.1 Deploy Enhanced RAW_JSON Architecture**
**File to deploy**: `/workspace/TR2000/TR2K/Ops/Master_DDL_Script.sql`

**Critical components:**
- Enhanced RAW_JSON table (12 fields with metadata)
- SP_INSERT_RAW_JSON procedure (9 parameters, fixed hash function)
- Performance indexes (IX_RAWJSON_PICK, IX_RAWJSON_HASH)

**Verification:**
```sql
-- Test the procedure works
EXEC SP_INSERT_RAW_JSON(999, 'test', 'https://test.com', NULL, 200, NULL, '{"test":"data"}', 100, '{}');
SELECT COUNT(*) FROM RAW_JSON WHERE ENDPOINT_NAME = 'test';
```

#### **1.2 Deploy JSON_TABLE Parsing Procedures**
**File to deploy**: `/workspace/TR2000/TR2K/Ops/JSON_TABLE_Parsing_Procedures.sql`

**Procedures to create:**
- `SP_PARSE_OPERATORS_FROM_RAW_JSON`
- `SP_PARSE_PLANTS_FROM_RAW_JSON` 
- `SP_PARSE_ISSUES_FROM_RAW_JSON`

**Verification:**
```sql
-- Test with existing RAW_JSON data
EXEC SP_PARSE_OPERATORS_FROM_RAW_JSON();
SELECT COUNT(*) FROM STG_OPERATORS WHERE RAW_JSON_ID IS NOT NULL;
```

#### **1.3 Update Master Orchestrator**
**Enhanced SP_PROCESS_ETL_BATCH** with RAW_JSON parsing as Step 0:
```sql
-- Step 0: Parse RAW_JSON to STG_TABLES (NEW)
CASE p_entity_type
    WHEN 'OPERATORS' THEN SP_PARSE_OPERATORS_FROM_RAW_JSON(p_etl_run_id);
    WHEN 'PLANTS' THEN SP_PARSE_PLANTS_FROM_RAW_JSON(p_etl_run_id);
    WHEN 'ISSUES' THEN SP_PARSE_ISSUES_FROM_RAW_JSON(p_etl_run_id);
END CASE;

-- Step 1-4: Existing SCD2 processing (unchanged)
```

### **PHASE 2: Clean C# Implementation (1.5 hours)**

#### **2.1 Create OracleETLServiceV3**
**Location**: `/TR2KBlazorLibrary/Logic/Services/OracleETLServiceV3.cs`

**Design Pattern** (consistent for ALL endpoints):
```csharp
public async Task<ETLResult> LoadOperators()
{
    try 
    {
        // Step 1: API → RAW_JSON (audit trail)
        var apiResponse = await _apiService.FetchDataAsync("operators");
        await InsertRawJson(connection, etlRunId, "operators", "all-operators", apiResponse);
        
        // Step 2: Oracle processes everything (RAW_JSON → STG → FINAL)
        await connection.ExecuteAsync("SP_PROCESS_ETL_BATCH", 
            new { etlRunId, entityType = "OPERATORS" });
            
        return GetETLResults(etlRunId);
    }
    catch (Exception ex) 
    {
        await LogError(etlRunId, "LoadOperators", ex);
        throw;
    }
}
```

#### **2.2 Implement Core Methods**
**Methods to implement:**
1. **LoadOperators()** - Single API call, Oracle parsing
2. **LoadPlants()** - No enhancement complexity, clean flow  
3. **LoadIssues()** - Per-plant iteration but clean pattern
4. **InsertRawJson()** - Consistent Dapper approach
5. **GetETLResults()** - Query final results from Oracle

#### **2.3 Standardize Error Handling**
```csharp
private async Task LogError(int etlRunId, string source, Exception ex)
{
    await connection.ExecuteAsync("LOG_ETL_ERROR", new {
        etlRunId, source, errorCode = ex.GetType().Name, 
        errorMessage = ex.Message, stackTrace = ex.StackTrace
    });
}
```

### **PHASE 3: Integration & Testing (1 hour)**

#### **3.1 Update Dependency Injection**
**File**: `/TR2KApp/Program.cs`
```csharp
// Replace V2 with V3
services.AddScoped<IOracleETLService, OracleETLServiceV3>();
```

#### **3.2 Test Each Endpoint Incrementally**
**Test sequence:**
1. **LoadOperators**: Verify RAW_JSON → STG_OPERATORS → OPERATORS
2. **LoadPlants**: Verify RAW_JSON → STG_PLANTS → PLANTS  
3. **LoadIssues**: Verify RAW_JSON → STG_ISSUES → ISSUES

**Validation queries:**
```sql
-- Verify complete flow
SELECT 'RAW_JSON' as TABLE_NAME, COUNT(*) FROM RAW_JSON WHERE ENDPOINT_NAME = 'operators'
UNION ALL
SELECT 'STG_OPERATORS', COUNT(*) FROM STG_OPERATORS WHERE RAW_JSON_ID IS NOT NULL
UNION ALL  
SELECT 'OPERATORS', COUNT(*) FROM OPERATORS WHERE IS_CURRENT = 'Y';
```

#### **3.3 Validate Audit Trail**
**Verify replay capability:**
```sql
-- Reset processed flag to replay from RAW_JSON
UPDATE RAW_JSON SET PROCESSED_FLAG = 'N' WHERE ENDPOINT_NAME = 'operators';

-- Re-run ETL (should work from existing RAW_JSON data)
EXEC SP_PROCESS_ETL_BATCH(999, 'OPERATORS');
```

### **PHASE 4: Cleanup & Documentation (30 minutes)**

#### **4.1 Remove Legacy Code**
- Delete OracleETLServiceV2.cs
- Remove unused enhancement logic
- Clean up old RAW_JSON procedure calls

#### **4.2 Update Documentation**
- Update TR2K_START_HERE.md with new architecture
- Document the clean C# patterns
- Add troubleshooting guide for new flow

## 🎯 **SUCCESS CRITERIA**

### **Architecture Compliance:**
- ✅ Single API call per endpoint type
- ✅ Complete audit trail in RAW_JSON  
- ✅ Oracle handles all data transformation
- ✅ No C# manual STG inserts
- ✅ Consistent error handling

### **Performance Targets:**
- **LoadOperators**: 1 API call (vs previous 1) ✅
- **LoadPlants**: 1 API call (vs previous 1) ✅  
- **LoadIssues**: N API calls for N plants (vs previous 2N calls) 📈

### **Data Quality:**
- ✅ All data flows through RAW_JSON audit layer
- ✅ Replay capability from RAW_JSON works
- ✅ SCD2 temporal tracking maintained
- ✅ Error logging and transaction integrity

## 📋 **QUICK START CHECKLIST**

### **Before Starting:**
- [ ] Archive current implementation (commit to GitHub)
- [ ] Backup Oracle database
- [ ] Test Oracle connection and permissions

### **Implementation Order:**
1. [ ] Deploy Oracle DDL scripts (Master_DDL_Script.sql)
2. [ ] Deploy JSON_TABLE procedures  
3. [ ] Test Oracle procedures independently
4. [ ] Create OracleETLServiceV3 class
5. [ ] Implement LoadOperators (test end-to-end)
6. [ ] Implement LoadPlants (test end-to-end)
7. [ ] Implement LoadIssues (test end-to-end)
8. [ ] Update dependency injection
9. [ ] Remove legacy OracleETLServiceV2
10. [ ] Test complete application

### **Critical Files:**
- **Oracle**: `/Ops/Master_DDL_Script.sql`, `/Ops/JSON_TABLE_Parsing_Procedures.sql`
- **C#**: New `/Logic/Services/OracleETLServiceV3.cs`
- **Config**: `/TR2KApp/Program.cs` (DI update)

## 🚀 **EXPECTED TIMELINE**

**Total Estimated Time**: ~4 hours

- **Phase 1 (Oracle)**: 1 hour
- **Phase 2 (C#)**: 1.5 hours  
- **Phase 3 (Testing)**: 1 hour
- **Phase 4 (Cleanup)**: 30 minutes

## 💡 **KEY INSIGHTS FROM SESSION 29**

1. **The Problem**: Double API calls + bypassing RAW_JSON audit layer
2. **The Solution**: Oracle JSON_TABLE parsing from RAW_JSON
3. **The Benefit**: Industry-standard architecture with complete audit trail
4. **The Simplicity**: Clean, consistent patterns across all endpoints

---
**Created**: Session 29 (2025-08-21)  
**Purpose**: Complete fresh implementation guide for industry-standard TR2000 ETL architecture  
**Status**: Ready for implementation