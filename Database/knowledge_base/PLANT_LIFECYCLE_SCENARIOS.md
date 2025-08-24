# Plant Lifecycle Scenarios - What Happens When Data Changes?

## The Soft Delete Pattern

The system uses `is_valid = 'Y'/'N'` instead of hard DELETE operations. This means:
- **Active plants**: `is_valid = 'Y'`
- **Deleted/removed plants**: `is_valid = 'N'`
- **History preserved**: Records are NEVER physically deleted

## Scenario 1: Plant Deleted by Source API

### What Happens:
```
API Returns: Plants 1, 2, 4, 5 (Plant 3 is missing)
Database Before: Plants 1, 2, 3, 4, 5 (all with is_valid='Y')
```

### Process:
1. **Step 1**: `UPDATE PLANTS SET is_valid = 'N'` - ALL plants marked invalid
2. **Step 2**: MERGE processes plants from API:
   - Plants 1, 2, 4, 5: Updated with `is_valid = 'Y'`
   - Plant 3: Remains with `is_valid = 'N'` (soft deleted)

### Result:
```sql
-- Plant 3 still exists but marked as deleted
SELECT * FROM PLANTS WHERE plant_id = 3;
-- Returns: plant_id=3, is_valid='N', last_modified_date=TODAY

-- Active plants only
SELECT * FROM PLANTS WHERE is_valid = 'Y';
-- Returns: Plants 1, 2, 4, 5
```

### Cascade Effect:
- Any issues for Plant 3 are also marked `is_valid = 'N'`
- Selection_loader entries for Plant 3 remain (for audit)

---

## Scenario 2: New Plant Added by Source API

### What Happens:
```
API Returns: Plants 1, 2, 3, 4, 5, 99 (Plant 99 is new)
Database Before: Plants 1, 2, 3, 4, 5 (all with is_valid='Y')
```

### Process:
1. **Step 1**: `UPDATE PLANTS SET is_valid = 'N'` - ALL plants marked invalid
2. **Step 2**: MERGE processes:
   - Plants 1-5: MATCHED - Updated with `is_valid = 'Y'`
   - Plant 99: NOT MATCHED - Inserted with `is_valid = 'Y'`, `created_date = TODAY`

### Result:
```sql
SELECT plant_id, created_date, is_valid FROM PLANTS ORDER BY plant_id;
-- Plant 1-5: created_date = ORIGINAL_DATE, is_valid = 'Y'
-- Plant 99: created_date = TODAY, is_valid = 'Y'
```

---

## Scenario 3: Plant Deleted Then Added Back

### Initial State:
```
Database: Plant 10 exists (is_valid='Y', created_date='2024-01-01')
```

### Phase 1: Plant Deleted
```
API Returns: Plants without Plant 10
After ETL: Plant 10 has is_valid='N', last_modified_date='2025-08-01'
```

### Phase 2: Plant Re-Added (Different Day)
```
API Returns: Plant 10 is back
MERGE Operation: Plant 10 MATCHES (it still exists in database)
Result: UPDATE SET is_valid='Y', last_modified_date='2025-08-15'
```

### Critical Point:
```sql
-- The plant retains its original created_date!
SELECT * FROM PLANTS WHERE plant_id = 10;
-- created_date = '2024-01-01' (ORIGINAL)
-- last_modified_date = '2025-08-15' (LATEST)
-- is_valid = 'Y'
```

**The system remembers it saw this plant before!**

---

## Scenario 4: Plant Modified by Source API

### What Happens:
```
API Returns: Plant 5 with new short_description="UPDATED NAME"
Database Before: Plant 5 with short_description="OLD NAME"
```

### Process:
1. **Step 1**: `UPDATE PLANTS SET is_valid = 'N'`
2. **Step 2**: MERGE finds Plant 5:
   - MATCHED: Updates all fields including `short_description`
   - Sets `is_valid = 'Y'`, `last_modified_date = TODAY`

### Result:
```sql
-- Updated data but same created_date
SELECT * FROM PLANTS WHERE plant_id = 5;
-- short_description = 'UPDATED NAME'
-- created_date = ORIGINAL_DATE
-- last_modified_date = TODAY
```

---

## Scenario 5: Complete API Replacement

### What Happens:
```
API Returns: Completely different set of plants (6, 7, 8, 9)
Database Before: Plants 1, 2, 3, 4, 5
```

### Process:
1. **Step 1**: ALL plants (1-5) marked `is_valid = 'N'`
2. **Step 2**: Plants 6-9 inserted as new with `is_valid = 'Y'`

### Result:
```sql
-- Old plants soft deleted
SELECT COUNT(*) FROM PLANTS WHERE is_valid = 'N'; -- Returns: 5

-- New plants active
SELECT COUNT(*) FROM PLANTS WHERE is_valid = 'Y'; -- Returns: 4

-- Total plants in database
SELECT COUNT(*) FROM PLANTS; -- Returns: 9
```

---

## Key Design Benefits

### 1. **Full Audit Trail**
```sql
-- See when a plant was first seen
SELECT plant_id, created_date FROM PLANTS WHERE plant_id = 'X';

-- See when it was last active
SELECT plant_id, last_modified_date, is_valid FROM PLANTS WHERE plant_id = 'X';

-- See deletion history
SELECT plant_id, last_modified_date 
FROM PLANTS 
WHERE is_valid = 'N' 
ORDER BY last_modified_date DESC;
```

### 2. **Recovery Capability**
If a plant is accidentally deleted from source:
- Data still exists with `is_valid = 'N'`
- Can be manually reactivated if needed
- Historical associations preserved

### 3. **Referential Integrity**
- Foreign keys still work (plant_id exists)
- Issues can reference "deleted" plants
- No orphaned records

### 4. **Performance**
- No CASCADE DELETE operations
- Simple UPDATE instead of DELETE+INSERT
- Indexes on is_valid for fast filtering

---

## Important Queries

### Active Plants Only
```sql
SELECT * FROM PLANTS WHERE is_valid = 'Y';
```

### Recently Deleted Plants
```sql
SELECT plant_id, short_description, last_modified_date
FROM PLANTS 
WHERE is_valid = 'N'
AND last_modified_date > SYSDATE - 7;  -- Last 7 days
```

### Plant History
```sql
SELECT 
    plant_id,
    CASE is_valid 
        WHEN 'Y' THEN 'Active' 
        ELSE 'Deleted' 
    END as status,
    created_date as first_seen,
    last_modified_date as last_changed,
    ROUND(last_modified_date - created_date) as days_in_system
FROM PLANTS
WHERE plant_id = :plant_id;
```

### Resurrection Detection
```sql
-- Find plants that were deleted and came back
SELECT plant_id, short_description
FROM PLANTS
WHERE is_valid = 'Y'
AND created_date < last_modified_date - 30  -- Modified 30+ days after creation
AND plant_id IN (
    SELECT plant_id FROM RAW_JSON 
    GROUP BY plant_id 
    HAVING COUNT(DISTINCT response_hash) > 2  -- Appeared in multiple different API responses
);
```

---

## CRITICAL SCENARIO: Plant ID Changes in API

### ⚠️ WARNING: This is a Breaking Change!

If the API changes a plant_id (e.g., from "PLANT_10" to "PLANT_10A"), the system CANNOT detect this is the same plant!

### What Happens:
```
API Before: plant_id="PLANT_10", short_description="Sleipner"
API After:  plant_id="PLANT_10A", short_description="Sleipner"  (same plant, new ID)
```

### System Behavior:
1. **Step 1**: All plants marked `is_valid = 'N'`
2. **Step 2**: MERGE operation:
   - "PLANT_10": NO MATCH in staging → Remains `is_valid = 'N'` (appears deleted)
   - "PLANT_10A": NO MATCH in database → INSERTED as brand new plant

### Result:
```sql
SELECT * FROM PLANTS WHERE short_description = 'Sleipner';
-- Returns 2 records:
-- plant_id="PLANT_10", is_valid='N', created_date='2024-01-01'
-- plant_id="PLANT_10A", is_valid='Y', created_date='2025-08-24' (TODAY)
```

### Cascade Problems:
1. **Issues Orphaned**: All issues linked to "PLANT_10" now reference a "deleted" plant
2. **Selection Lost**: User selections for "PLANT_10" don't apply to "PLANT_10A"
3. **History Broken**: No connection between old and new plant records
4. **Foreign Keys**: Issues cannot automatically move to new plant_id

### How to Detect This:
```sql
-- Find potential renamed plants (same name, one deleted, one new)
SELECT 
    old.plant_id as old_id,
    new.plant_id as new_id,
    old.short_description
FROM PLANTS old
JOIN PLANTS new ON old.short_description = new.short_description
WHERE old.is_valid = 'N'
  AND new.is_valid = 'Y'
  AND old.plant_id != new.plant_id
  AND new.created_date > old.last_modified_date - 1;  -- Changed recently
```

### Manual Fix Required:
```sql
-- If you confirm PLANT_10A is really PLANT_10 renamed:

-- Option 1: Update the old record (RISKY - breaks primary key)
-- DON'T DO THIS - will fail due to PRIMARY KEY constraint

-- Option 2: Migrate issues to new plant_id
UPDATE ISSUES SET plant_id = 'PLANT_10A' WHERE plant_id = 'PLANT_10';
UPDATE SELECTION_LOADER SET plant_id = 'PLANT_10A' WHERE plant_id = 'PLANT_10';

-- Option 3: Keep both, add mapping table (BEST)
CREATE TABLE PLANT_ID_MAPPING (
    old_plant_id VARCHAR2(50),
    new_plant_id VARCHAR2(50),
    mapped_date DATE DEFAULT SYSDATE
);
INSERT INTO PLANT_ID_MAPPING VALUES ('PLANT_10', 'PLANT_10A', SYSDATE);
```

---

## Edge Cases Handled

1. **Empty API Response**: All plants marked `is_valid = 'N'`
2. **API Error**: Transaction rolled back, no changes
3. **Duplicate plant_id with different data**: MERGE updates existing
4. **Plant resurrection**: Maintains original created_date
5. **Cascade deletion**: Issues follow plant status

## What's NOT Handled (System Limitations)

1. **Plant ID Changes**: System cannot detect renamed plants (treated as delete + new)
2. **History Table**: No PLANTS_HISTORY to track all changes
3. **Change Tracking**: Can't see what fields changed when
4. **Deletion Reason**: No record of why something was deleted
5. **Manual Override**: No flag to prevent API from changing certain plants
6. **Merge Detection**: No logic to detect if two plants are actually the same

## Recommendations for Production

1. **Monitor for ID Changes**:
   ```sql
   -- Run daily to detect potential renames
   CREATE OR REPLACE VIEW v_potential_plant_renames AS
   SELECT ... (query from above)
   ```

2. **Add ID Stability Check**:
   - Contact API provider about ID stability guarantees
   - Document their ID change policy

3. **Consider Additional Matching**:
   - Could match on multiple fields (name + operator + area)
   - Add a "canonical_id" field for mapping

4. **Alert on Suspicious Changes**:
   - Email when plants deleted + similar new plants appear
   - Require manual confirmation for cascading deletes