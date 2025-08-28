# TR2000 API Investigation: PCS Revision Discrepancy

## Issue Found
When calling the Issues endpoint for Grane (Plant ID: 34), Issue Revision 4.2 shows:
- **PCSRevision: "5"** (according to the actual API)
- This revision doesn't appear to exist in the PCS list

## Investigation Steps

### Step 1: Check Issues Endpoint
**API Call:** `GET https://equinor.pipespec-api.presight.com/plants/34/issues`

Filter for Issue 4.2 and check the PCSRevision field.

**Expected Field:**
```json
{
  "IssueRevision": "4.2",
  "PCSRevision": "5",  // ← This seems wrong!
  ...
}
```

### Step 2: Check PCS List Endpoint
**API Call:** `GET https://equinor.pipespec-api.presight.com/plants/34/pcs`

Look for ANY PCS with revision "5" - likely none exist.

### Step 3: Check PCS References for Issue 4.2
**API Call:** `GET https://equinor.pipespec-api.presight.com/plants/34/issues/rev/4.2/pcs`

This should return the ACTUAL PCS items referenced by Issue 4.2.

**Key Question:** What revisions do these PCS items actually have?
- Probably NOT revision "5"
- Likely revision "4.1", "4.2", or something else

## Possible Explanations

### Theory 1: API Data Inconsistency
The Issues endpoint might have incorrect/outdated PCSRevision field values.

### Theory 2: Reference vs. Version Mismatch
- The `PCSRevision` field in Issues might be a different concept
- The actual PCS references might use different revision numbers
- The field might be for documentation purposes only

### Theory 3: Data Quality Issue
The source system might have data integrity problems where:
- Issues reference non-existent PCS revisions
- PCS revisions were deleted but Issues still reference them
- Manual data entry errors

## What This Means for Your ETL

### Current Problem
If your ETL relies on the `PCSRevision` field from Issues to determine what to load, it will fail because:
```
Issues says: Load PCS revision "5"
PCS endpoint: No revision "5" exists!
```

### Recommended Solution
**Don't rely on the revision fields in the Issues table!**

Instead, use the reference endpoints directly:
1. Call `/plants/{id}/issues/rev/{rev}/pcs` to get actual PCS references
2. These will have the CORRECT revision numbers that actually exist
3. Load those specific PCS items regardless of what Issues.PCSRevision says

### Code Change Needed
```csharp
// OLD APPROACH (broken):
var issueData = await GetIssue(plantId, "4.2");
var pcsRevision = issueData.PCSRevision; // "5" - doesn't exist!
var pcsList = await GetPCSByRevision(plantId, pcsRevision); // FAILS

// NEW APPROACH (working):
var pcsReferences = await GetAPI($"/plants/{plantId}/issues/rev/4.2/pcs");
foreach (var pcsRef in pcsReferences)
{
    // Use the revision from the actual reference
    var pcsData = await GetPCS(plantId, pcsRef.PCS, pcsRef.Revision);
}
```

## Action Items

1. **Verify with actual API calls** to confirm the discrepancy
2. **Update ETL logic** to use reference endpoints instead of Issue revision fields
3. **Document this quirk** for future developers
4. **Consider adding validation** to detect when Issue revision fields don't match actual references

## SQL to Detect This Issue
```sql
-- Find Issues where PCSRevision doesn't match any actual PCS
SELECT i.plant_id, i.issue_revision, i.pcs_revision
FROM ISSUES i
WHERE NOT EXISTS (
    SELECT 1 FROM PCS_LIST p 
    WHERE p.plant_id = i.plant_id 
    AND p.revision = i.pcs_revision
)
AND i.pcs_revision IS NOT NULL;
```

## Conclusion
The Issue's `PCSRevision` field appears to be unreliable. Always use the reference endpoints (`/issues/rev/{rev}/pcs`) to get the actual PCS items and their correct revisions.