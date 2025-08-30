# ETL Operations Guide - Simplified System

## Quick Start

### What is this system?
A simplified ETL (Extract, Transform, Load) system that fetches data from Equinor's API and loads it into Oracle tables for use by other applications.

### Key Concept
**Clear Everything → Load Everything** - No partial updates, no complex merges, just fresh data every time.

## Daily Operations

### 1. Managing What Gets Loaded

#### View Current Filters
```sql
-- See what will be loaded
SELECT plant_id, plant_name, issue_revision, added_date, added_by_user_id
FROM ETL_FILTER
ORDER BY plant_id, issue_revision;
```

#### Add New Plant/Issue to Load
```sql
-- Add GRANE issue 4.2
INSERT INTO ETL_FILTER (plant_id, plant_name, issue_revision, added_by_user_id)
VALUES ('34', 'GRANE', '4.2', 'john.doe');

-- Add multiple issues
INSERT INTO ETL_FILTER (plant_id, plant_name, issue_revision, added_by_user_id)
SELECT '124', 'JSP2', '3.3', 'john.doe' FROM DUAL UNION ALL
SELECT '124', 'JSP2', '1.0', 'john.doe' FROM DUAL;
```

#### Remove Plant/Issue
```sql
-- Remove specific issue
DELETE FROM ETL_FILTER 
WHERE plant_id = '34' AND issue_revision = '4.2';

-- Remove all issues for a plant
DELETE FROM ETL_FILTER 
WHERE plant_id = '124';
```

### 2. Running the ETL - Three Separate Processes

#### Process 1: Reference Data ETL
**Command**: Execute the main reference ETL procedure

**What it does:**
1. Clear all reference tables
2. Process each entry in ETL_FILTER
3. Load 9 reference types per issue
4. Log the results

#### Process 2: PCS Details ETL
**Command**: Execute the PCS details ETL procedure (run AFTER references)

**What it does:**
1. Clear all PCS detail tables
2. Extract unique PCS from PCS_REFERENCES
3. Fetch 6 detail endpoints per PCS
4. Load temperature/pressure, pipe sizes, elements, etc.

#### Process 3: VDS Catalog ETL (Independent)
**Command**: Execute the VDS catalog ETL procedure

**What it does:**
1. Clear VDS_LIST table
2. Fetch entire VDS catalog from API
3. Load all VDS items
4. Takes 30+ seconds due to volume

#### Complete ETL Sequence
To run all three processes in the correct order:
1. **Load references first** - Establishes base data
2. **Then load PCS details** - Depends on references
3. **Load VDS catalog** - Independent, can run anytime

#### Check Progress
```sql
-- Monitor current ETL run
SELECT status, message, run_timestamp 
FROM ETL_RUN_LOG 
ORDER BY run_timestamp DESC
FETCH FIRST 10 ROWS ONLY;
```

### 3. Monitoring

#### Quick Status Check
```sql
-- Overall system status
SELECT 
    'ETL Filters' as component, COUNT(*) as count FROM ETL_FILTER
UNION ALL
SELECT 'PCS References', COUNT(*) FROM PCS_REFERENCES
UNION ALL
SELECT 'PCS Details', COUNT(*) FROM PCS_HEADER_PROPERTIES
UNION ALL
SELECT 'VDS Catalog', COUNT(*) FROM VDS_LIST;
```

#### Check What PCS Details Are Loaded
```sql
-- See PCS details coverage
SELECT 
    r.plant_id,
    COUNT(DISTINCT r.pcs_name) as unique_pcs_in_references,
    COUNT(DISTINCT h.pcs_name) as pcs_with_details
FROM PCS_REFERENCES r
LEFT JOIN PCS_HEADER_PROPERTIES h 
    ON r.plant_id = h.plant_id 
    AND r.pcs_name = h.pcs_name
GROUP BY r.plant_id
ORDER BY r.plant_id;
```

#### VDS Catalog Status
```sql
-- Check VDS catalog load
SELECT 
    COUNT(*) as total_vds_items,
    COUNT(DISTINCT vds_name) as unique_vds,
    MIN(created_date) as first_loaded,
    MAX(created_date) as last_loaded
FROM VDS_LIST;
```

#### Check Raw API Responses
```sql
-- View recent API calls (for debugging)
SELECT endpoint, plant_id, issue_revision, 
       LENGTH(payload) as payload_size, created_date
FROM RAW_JSON
ORDER BY created_date DESC
FETCH FIRST 20 ROWS ONLY;
```

## Common Tasks

### Task: Load a New Plant/Issue with Details

**Steps:**
1. **Add to filter** - Insert new plant/issue into ETL_FILTER table
2. **Run reference ETL** - Load all reference data
3. **Load PCS details** - Fetch detailed PCS information
4. **Verify** - Check counts in reference and detail tables

### Task: Refresh All Data

**Process:**
Run all three ETL processes in sequence:
1. Reference ETL for all configured plant/issues
2. PCS Details ETL for all loaded references
3. VDS Catalog ETL for complete valve data

### Task: Update VDS Catalog Only

Since VDS catalog is independent, it can be updated anytime without affecting other data. Simply run the VDS catalog ETL procedure.

### Task: Remove Old Plant Data

**Steps:**
1. **Remove from filter** - Delete the plant/issue from ETL_FILTER
2. **Run ETL processes** - Both reference and PCS details ETL will clear out the old data

### Task: Check What's Loaded

```sql
-- Summary by plant/issue
SELECT plant_id, issue_revision, 
       COUNT(*) as total_refs,
       MIN(created_date) as first_loaded,
       MAX(last_modified_date) as last_updated
FROM (
    SELECT plant_id, issue_revision, created_date, last_modified_date FROM PCS_REFERENCES
    UNION ALL
    SELECT plant_id, issue_revision, created_date, last_modified_date FROM VDS_REFERENCES
    UNION ALL
    SELECT plant_id, issue_revision, created_date, last_modified_date FROM MDS_REFERENCES
)
GROUP BY plant_id, issue_revision
ORDER BY plant_id, issue_revision;
```

## Troubleshooting

### Problem: ETL Failed

**Solution**: Identify which process failed and rerun that specific ETL procedure:
- **Reference ETL failures**: Run the reference ETL procedure
- **PCS details failures**: Run the PCS details ETL procedure
- **VDS catalog failures**: Run the VDS catalog ETL procedure

The system clears everything first, so running again is always safe.

### Problem: Missing Data

**Check 1**: Is it in the filter?
```sql
SELECT * FROM ETL_FILTER 
WHERE plant_id = 'YOUR_PLANT' AND issue_revision = 'YOUR_ISSUE';
```

**Check 2**: Did the API return data?
```sql
SELECT endpoint, LENGTH(payload) as size, created_date
FROM RAW_JSON
WHERE plant_id = 'YOUR_PLANT' AND issue_revision = 'YOUR_ISSUE'
ORDER BY created_date DESC;
```

**Check 3**: Any errors logged?
```sql
SELECT * FROM ETL_ERROR_LOG
WHERE error_timestamp > SYSDATE - 1
ORDER BY error_timestamp DESC;
```

### Problem: Partial Data

**This shouldn't happen** in the new system because we clear everything first. If you see partial data:

1. **Run the affected ETL process again** - It will clear and reload
2. **If still issues**: Check ETL_ERROR_LOG for specific errors

### Problem: API Timeout

**Symptom**: ETL takes very long or fails with timeout errors

**For VDS Catalog** (44,000+ items):
- Expected to take 30+ seconds
- If it times out, simply retry the VDS catalog ETL

**For PCS Details** (many API calls):
- Process in smaller batches by temporarily disabling some ETL_FILTER entries
- Use negative filter_id as a disable flag
- Run ETL for active filters only
- Re-enable and process the rest

## Performance Tips

### 1. Load Only What You Need
Don't add every plant/issue to ETL_FILTER. Only add what you actually need.

### 2. Run ETL During Off-Hours
The API might be faster when fewer users are accessing it.

### 3. Monitor API Response Times
```sql
-- Check how long API calls are taking
SELECT 
    endpoint,
    AVG(EXTRACT(SECOND FROM (created_date - LAG(created_date) 
        OVER (ORDER BY created_date)))) as avg_seconds
FROM RAW_JSON
WHERE created_date > SYSDATE - 1
GROUP BY endpoint;
```

## Understanding the Data Flow

### Simplified Flow
1. **ETL_FILTER** defines what to load
2. **Clear phase** removes old data
3. **API calls** fetch fresh data
4. **RAW_JSON** stores API responses
5. **STG_* tables** temporarily hold parsed data
6. **Final tables** receive clean data

### No More Complexity
- ❌ No soft-deletes (is_valid columns ignored)
- ❌ No cascade triggers
- ❌ No duplicate detection
- ❌ No merge operations
- ❌ No partial updates

## Maintenance Tasks

### Weekly: Clean Old API Logs
```sql
-- Remove RAW_JSON older than 30 days (optional)
DELETE FROM RAW_JSON 
WHERE created_date < SYSDATE - 30;
COMMIT;
```

### Monthly: Review Filters
```sql
-- Check for unused filters
SELECT f.*, 
       (SELECT MAX(created_date) FROM RAW_JSON r 
        WHERE r.plant_id = f.plant_id 
        AND r.issue_revision = f.issue_revision) as last_loaded
FROM ETL_FILTER f
ORDER BY last_loaded NULLS FIRST;
```

### Quarterly: Analyze Performance
```sql
-- Table sizes
SELECT segment_name as table_name, 
       ROUND(bytes/1024/1024, 2) as size_mb
FROM user_segments
WHERE segment_type = 'TABLE'
AND segment_name IN ('PCS_REFERENCES', 'VDS_REFERENCES', 'RAW_JSON')
ORDER BY bytes DESC;
```

## Best Practices

### DO:
✅ Run full ETL when in doubt
✅ Check ETL_FILTER before running
✅ Monitor ETL_RUN_LOG for issues
✅ Keep RAW_JSON for debugging
✅ Add filters gradually if loading many issues

### DON'T:
❌ Try to update single records manually
❌ Modify data tables directly
❌ Clear control tables (ETL_FILTER, CONTROL_SETTINGS)
❌ Skip the clear step
❌ Run multiple ETLs simultaneously

## Comparison with Old System

| Old System | New System |
|------------|------------|
| Soft-deletes with is_valid | Hard delete everything first |
| Complex cascade triggers | No cascades |
| Hash duplicate detection | Always fetch fresh |
| MERGE operations | Simple INSERT |
| 15+ packages | 3 packages |
| 5000+ lines of code | ~500 lines |
| Multiple failure modes | One recovery method |
| Partial updates possible | Always complete refresh |

## Emergency Procedures

### Complete Reset
**Nuclear option - clears everything:**
1. Clear all data tables
2. Optionally clear all logs (ETL_RUN_LOG, ETL_ERROR_LOG, RAW_JSON)
3. Keep ETL_FILTER intact
4. Commit changes

### Disable All Processing
**To stop all ETL processing:**
- Remove all entries from ETL_FILTER
- Or create a backup table first, then clear ETL_FILTER

### Check System Health
```sql
-- Quick health check
SELECT 
    'ETL_FILTER' as component,
    CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'EMPTY' END as status,
    COUNT(*) as count
FROM ETL_FILTER
UNION ALL
SELECT 
    'Data Tables',
    CASE WHEN COUNT(*) > 0 THEN 'HAS DATA' ELSE 'EMPTY' END,
    COUNT(*)
FROM PCS_REFERENCES
UNION ALL
SELECT 
    'Last ETL Run',
    CASE 
        WHEN MAX(run_timestamp) > SYSDATE - 1 THEN 'RECENT' 
        WHEN MAX(run_timestamp) > SYSDATE - 7 THEN 'THIS WEEK'
        ELSE 'OLD' 
    END,
    COUNT(*)
FROM ETL_RUN_LOG
WHERE status = 'SUCCESS';
```

## Getting Help

### Check Documentation
1. `ETL_SIMPLIFIED_ARCHITECTURE.md` - Technical details
2. `ETL_MIGRATION_PLAN.md` - How we got here
3. `ETL_OPERATIONS_GUIDE.md` - This file

### Common Questions

**Q: Why does ETL clear everything?**
A: Simplicity and reliability. No partial states, no complex logic.

**Q: What happened to soft-deletes?**
A: Removed. They caused bugs and added complexity.

**Q: Can I update just one issue?**
A: No. System always processes everything in ETL_FILTER.

**Q: Is this slower than before?**
A: Similar speed, but more predictable and reliable.

**Q: What if API is down?**
A: Old data remains. Try again when API is available.

## Summary

The new ETL system follows one simple pattern:
1. Define what you want in ETL_FILTER
2. Run PKG_ETL_CONTROL.run_full_etl()
3. Get fresh, clean data

No complexity, no cascades, no soft-deletes. Just reliable data loading.