# Session 28 - RAW_JSON Architecture Fix Deployment Instructions

## 🚨 CRITICAL: Manual DDL Deployment Required

**Status**: Phase 1 implementation complete - C# code updated, DDL scripts ready
**Next Step**: User must deploy Oracle DDL changes manually

## What Was Fixed in Phase 1:

### ✅ Oracle DDL Updates Complete:
1. **Enhanced RAW_JSON table structure** - added comprehensive metadata fields
2. **Updated SP_INSERT_RAW_JSON procedure** - now accepts 9 parameters vs previous 4
3. **Performance indexes** - for efficient querying and processing
4. **JSON validation** - CLOB with CHECK (JSON_DATA IS JSON) constraint

### ✅ C# Code Updates Complete:
1. **Fixed InsertRawJson method** - parameter mismatch resolved
2. **Added ExtractPlantIdFromKey helper** - extracts plant context from keyString
3. **Enhanced parameter mapping** - now provides full URL, status, duration metadata

## 🛡️ DEPLOYMENT PROCESS (USER ACTION REQUIRED):

### Step 1: Deploy DDL via SQL Developer
**File**: `/workspace/TR2000/TR2K/Ops/RAW_JSON_Migration_Session28.sql`

**Important**: 
- ⚠️ **Do NOT run this automatically from code**
- ⚠️ **Must be deployed manually via SQL Developer or similar tool**
- ⚠️ **This follows security policy - no automated DDL deployment**

### Step 2: Verify Deployment
After running the migration script, verify:
```sql
-- Check RAW_JSON table structure
SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = 'RAW_JSON';
-- Should return 12 (up from 6)

-- Check procedure exists
SELECT OBJECT_NAME, STATUS FROM USER_OBJECTS 
WHERE OBJECT_NAME = 'SP_INSERT_RAW_JSON' AND OBJECT_TYPE = 'PROCEDURE';
-- Should show 'VALID' status
```

### Step 3: Test RAW_JSON Insertion
1. Navigate to: http://localhost:5005/etl-operations
2. Click "Load Operators" 
3. Check application logs - should see "RAW_JSON inserted for /operators" instead of error
4. Verify RAW_JSON table has data:
```sql
SELECT COUNT(*), ENDPOINT_NAME FROM RAW_JSON GROUP BY ENDPOINT_NAME;
```

## Expected Results After Deployment:

### ✅ Before (Broken):
- RAW_JSON table: Empty (all inserts failed)
- Application logs: "RAW_JSON insert failed (non-critical): ORA-06553: PLS-306: wrong number or types of arguments"
- Architecture: API → STG_TABLES (bypassing RAW_JSON)

### ✅ After (Fixed):
- RAW_JSON table: Populated with API responses and comprehensive metadata
- Application logs: "RAW_JSON inserted for [endpoint]"
- Architecture: API → RAW_JSON → STG_TABLES (industry standard)

## Session 28 Status:

- ✅ **Phase 1 Complete**: Oracle DDL and C# parameter mismatch fixed
- ⏳ **Manual Deployment Required**: User must run migration script
- 🔄 **Ready for Testing**: Once deployed, RAW_JSON insertion should work
- 📋 **Next Session**: Phase 2 - JSON_TABLE parsing procedures

## Architecture Benefits After Deployment:
1. **Complete Audit Trail** - Every API response captured with metadata
2. **Deduplication** - Hash-based duplicate prevention
3. **Replay Capability** - Re-process data without API calls
4. **Industry Compliance** - Proper API → RAW_JSON → STG → CORE flow
5. **Smart Workflow Preserved** - 98.5% API reduction maintained

---
**Ready for User Action**: Deploy migration script and test RAW_JSON insertion