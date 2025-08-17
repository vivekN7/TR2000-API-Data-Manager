# SCD Type 2 Implementation Guide for TR2000 ETL

## Overview
This guide explains how to implement SCD Type 2 (Slowly Changing Dimensions) with hash-based change detection for the TR2000 ETL process.

## Why SCD Type 2?

### Benefits:
1. **Complete History**: Track all changes over time
2. **Point-in-Time Queries**: Answer "What was the value on date X?"
3. **Audit Trail**: Full traceability of when/what changed
4. **Efficient Storage**: Only store changes, not duplicates
5. **Fast Lookups**: Current data easily accessible via IS_CURRENT flag

### Key Concepts:
- **Business Key**: Natural identifier (e.g., PLANT_ID)
- **Surrogate Key**: System-generated ID (e.g., PLANT_KEY)
- **SRC_HASH**: SHA256 hash of business columns for change detection
- **VALID_FROM/VALID_TO**: Temporal validity period
- **IS_CURRENT**: Quick flag for current records

## Architecture

```
API → Staging Tables → Change Detection → Dimension Tables
         (STG_*)           (Hash Compare)      (DIM_*)
```

## ETL Process Flow

### 1. Extract & Stage
```sql
-- Load API data into staging with computed hash
INSERT INTO STG_PLANTS (
    PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, 
    OPERATOR_ID, COMMON_LIB_PLANT_CODE, SRC_HASH, ETL_RUN_ID
)
VALUES (
    :plantId, :plantName, :longDesc, 
    :operatorId, :commonLib,
    COMPUTE_PLANT_HASH(:plantId, :plantName, :longDesc, :operatorId, :commonLib),
    :etlRunId
);
```

### 2. Detect Changes
```sql
-- Find records that have changed
SELECT s.PLANT_ID, 
       CASE 
         WHEN d.PLANT_ID IS NULL THEN 'NEW'
         WHEN s.SRC_HASH != d.SRC_HASH THEN 'CHANGED'
         ELSE 'UNCHANGED'
       END AS CHANGE_TYPE
FROM STG_PLANTS s
LEFT JOIN DIM_PLANTS d ON d.PLANT_ID = s.PLANT_ID AND d.IS_CURRENT = 'Y';
```

### 3. Process Changes

#### For NEW Records:
```sql
INSERT INTO DIM_PLANTS (
    PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID,
    COMMON_LIB_PLANT_CODE, SRC_HASH, VALID_FROM, VALID_TO, 
    IS_CURRENT, ETL_RUN_ID
)
SELECT 
    s.PLANT_ID, s.PLANT_NAME, s.LONG_DESCRIPTION, s.OPERATOR_ID,
    s.COMMON_LIB_PLANT_CODE, s.SRC_HASH, SYSDATE, NULL, 
    'Y', :etlRunId
FROM STG_PLANTS s
WHERE NOT EXISTS (
    SELECT 1 FROM DIM_PLANTS d WHERE d.PLANT_ID = s.PLANT_ID
);
```

#### For CHANGED Records:
```sql
-- Step 1: Expire the old record
UPDATE DIM_PLANTS
SET VALID_TO = SYSDATE, IS_CURRENT = 'N'
WHERE PLANT_ID = :plantId AND IS_CURRENT = 'Y';

-- Step 2: Insert new version
INSERT INTO DIM_PLANTS (
    PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID,
    COMMON_LIB_PLANT_CODE, SRC_HASH, VALID_FROM, VALID_TO, 
    IS_CURRENT, ETL_RUN_ID
)
SELECT 
    s.PLANT_ID, s.PLANT_NAME, s.LONG_DESCRIPTION, s.OPERATOR_ID,
    s.COMMON_LIB_PLANT_CODE, s.SRC_HASH, SYSDATE, NULL, 
    'Y', :etlRunId
FROM STG_PLANTS s
WHERE s.PLANT_ID = :plantId;
```

#### For UNCHANGED Records:
```sql
-- No action needed - skip these records
-- Just update statistics for reporting
```

## C# Implementation Example

```csharp
public async Task<ETLResult> LoadPlantsWithSCD2()
{
    var result = new ETLResult();
    
    // 1. Fetch from API
    var apiData = await _apiService.GetPlants();
    
    // 2. Start transaction
    using var connection = new OracleConnection(_connectionString);
    using var transaction = connection.BeginTransaction();
    
    try
    {
        // 3. Stage data with hashes
        foreach (var plant in apiData)
        {
            var hash = ComputePlantHash(plant);
            await StageRecord(plant, hash, etlRunId, connection, transaction);
        }
        
        // 4. Process SCD2 logic
        var changes = await DetectChanges(connection, transaction);
        
        result.RecordsUnchanged = changes.Unchanged.Count;
        result.RecordsUpdated = 0;
        result.RecordsLoaded = 0;
        
        // 5. Process changed records
        foreach (var change in changes.Changed)
        {
            await ExpireOldRecord(change.PlantId, connection, transaction);
            await InsertNewVersion(change, etlRunId, connection, transaction);
            result.RecordsUpdated++;
        }
        
        // 6. Process new records
        foreach (var newRecord in changes.New)
        {
            await InsertNewRecord(newRecord, etlRunId, connection, transaction);
            result.RecordsLoaded++;
        }
        
        // 7. Commit
        await transaction.CommitAsync();
        
        // 8. Clean up staging
        await ClearStagingTables(connection);
    }
    catch (Exception ex)
    {
        await transaction.RollbackAsync();
        throw;
    }
    
    return result;
}

private string ComputePlantHash(PlantData plant)
{
    var input = $"{plant.PlantId}|{plant.PlantName}|{plant.LongDescription}|" +
                $"{plant.OperatorId}|{plant.CommonLibPlantCode}";
    
    using (var sha256 = SHA256.Create())
    {
        var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(input.ToLower()));
        return BitConverter.ToString(bytes).Replace("-", "");
    }
}
```

## Performance Optimizations

### 1. Indexes
```sql
-- Current record lookup (most common)
CREATE INDEX IDX_DIM_PLANTS_CURRENT ON DIM_PLANTS(PLANT_ID, IS_CURRENT);

-- Hash comparison for change detection
CREATE INDEX IDX_DIM_PLANTS_HASH ON DIM_PLANTS(PLANT_ID, SRC_HASH) 
WHERE IS_CURRENT = 'Y';

-- Temporal queries
CREATE INDEX IDX_DIM_PLANTS_TEMPORAL ON DIM_PLANTS(PLANT_ID, VALID_FROM, VALID_TO);
```

### 2. Batch Processing
- Process multiple records in single SQL operations
- Use array binding for better performance
- Stage all data first, then process changes in batch

### 3. Statistics Collection
```sql
-- Track performance metrics
UPDATE ETL_CONTROL
SET RECORDS_LOADED = :new_count,
    RECORDS_UPDATED = :changed_count,
    RECORDS_UNCHANGED = :unchanged_count,
    END_TIME = SYSDATE
WHERE ETL_RUN_ID = :etl_run_id;
```

## Common Queries

### Get Current Data
```sql
-- Simple: use the view
SELECT * FROM V_CURRENT_PLANTS;

-- Or direct query
SELECT * FROM DIM_PLANTS WHERE IS_CURRENT = 'Y';
```

### Point-in-Time Query
```sql
-- What were the plants on 2024-12-31?
SELECT * FROM DIM_PLANTS
WHERE VALID_FROM <= DATE '2024-12-31'
  AND (VALID_TO > DATE '2024-12-31' OR VALID_TO IS NULL);
```

### Change History
```sql
-- Show all changes for a specific plant
SELECT PLANT_ID, PLANT_NAME, VALID_FROM, VALID_TO
FROM DIM_PLANTS
WHERE PLANT_ID = '34'
ORDER BY VALID_FROM DESC;
```

### Change Frequency Analysis
```sql
-- How often do plants change?
SELECT PLANT_ID, COUNT(*) as VERSION_COUNT,
       MIN(VALID_FROM) as FIRST_SEEN,
       MAX(VALID_FROM) as LAST_CHANGED
FROM DIM_PLANTS
GROUP BY PLANT_ID
HAVING COUNT(*) > 1
ORDER BY VERSION_COUNT DESC;
```

## Implementation Phases

### Phase 1: Basic SCD2 (Week 1-2)
- Implement for master tables (OPERATORS, PLANTS, ISSUES)
- Basic hash computation
- Simple change detection
- Manual testing

### Phase 2: Reference Tables (Week 3-4)
- Extend to reference tables (PCS, SC, VSM, etc.)
- Optimize batch processing
- Add performance metrics

### Phase 3: Advanced Features (Week 5-6)
- Implement stored procedures
- Add data quality checks
- Create audit reports
- Performance tuning

### Phase 4: Production Ready (Week 7-8)
- Full testing suite
- Documentation
- Monitoring dashboards
- Deployment procedures

## Benefits vs Current Approach

| Current Approach | SCD2 Approach |
|-----------------|---------------|
| Marks all as not current, inserts all | Only processes changes |
| No history beyond last load | Complete history maintained |
| Can't track what changed | Full change tracking |
| Grows linearly with each load | Grows only with changes |
| No point-in-time queries | Full temporal support |

## Estimated Performance Impact

For typical daily load:
- **Current**: 130 plants × 365 days = 47,450 rows/year
- **SCD2**: ~10% change rate = 4,745 rows/year
- **Storage Savings**: 90% reduction
- **Query Performance**: 10x faster for current data
- **ETL Performance**: 5x faster (only processing changes)

## Migration Strategy

1. **Keep existing tables** temporarily (renamed to LEGACY_*)
2. **Run both systems** in parallel for validation
3. **Compare results** to ensure accuracy
4. **Gradual cutover** once confidence established
5. **Archive legacy** tables after successful migration

## Monitoring & Maintenance

### Key Metrics to Track:
- Change rate per table
- Hash collision detection
- Storage growth rate
- Query performance
- ETL duration trends

### Regular Maintenance:
- Monthly: Review change patterns
- Quarterly: Optimize indexes
- Yearly: Archive old versions (if needed)

## Summary

SCD Type 2 with hash-based change detection provides:
1. **Efficiency**: Only process/store actual changes
2. **History**: Complete audit trail
3. **Performance**: Fast current data access
4. **Flexibility**: Point-in-time queries
5. **Scalability**: Grows with changes, not time

This approach is industry standard for data warehousing and will significantly improve the TR2000 ETL process.