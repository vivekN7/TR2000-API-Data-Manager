# Discussion Points for Database Team

## Document Purpose
This document tracks important architectural decisions and potential issues that need to be discussed with the database team or stakeholders.

---

## 1. Plant ID Stability (CRITICAL)

### Issue
The ETL system assumes `plant_id` values from the API are immutable (never change). If the API changes a plant_id, our system cannot detect it's the same plant.

### Example Scenario
- API changes plant_id from "47" to "47A" for the same plant
- System treats this as: Plant 47 deleted, Plant 47A added (new)
- All historical data and foreign key relationships are broken

### Current Assumption
**We assume plant_id values will NEVER change in the API**

### Questions for Discussion
1. Can we get a guarantee from the API provider that plant_ids are immutable?
2. If not, what business rules determine when two plants are "the same"?
3. Should we implement a mapping table for ID changes?
4. Do we need additional matching logic (e.g., match on name + operator)?

### Risk Level
**HIGH** - Would break referential integrity and historical tracking

### Recommended Actions
1. Get written confirmation from API team about ID stability
2. Implement monitoring query to detect potential ID changes
3. Consider adding a "canonical_id" field for future flexibility

---

## 2. Soft Delete Pattern

### Current Implementation
- Records are never physically deleted
- Use `is_valid = 'Y'/'N'` flag for active/inactive status
- Preserves full audit trail

### Points to Confirm
1. Is soft delete acceptable for all tables?
2. Any regulatory requirements for data retention/purging?
3. Performance implications as tables grow?

### Status
**Implemented and Working**

---

## 3. SHA256 Deduplication Strategy

### Current Implementation
- Hash API responses to avoid reprocessing identical data
- Skip ETL if hash matches previous response

### Discussion Points
1. Is skipping processing acceptable if hash matches?
2. Should we still update last_checked timestamp even if data unchanged?
3. Any scenarios where we'd want to force reprocessing?

### Status
**Implemented and Working**

---

## 4. Control Settings Not Yet Implemented

### Placeholder Settings
These exist in CONTROL_SETTINGS but aren't used:
- `MAX_PLANTS_PER_RUN` (set to 10)
- `RAW_JSON_RETENTION_DAYS` (set to 30)
- `ETL_LOG_RETENTION_DAYS` (set to 90)
- `ENABLE_PARALLEL_PROCESSING` (set to 'N')
- `BATCH_SIZE` (set to 1000)

### Questions
1. Should we implement these constraints?
2. Priority order for implementation?
3. Are the default values appropriate?

### Status
**Not Implemented - Future Enhancement**

---

## 5. History Tracking

### Current Limitation
- Only track current state and last modification
- Cannot see what specific fields changed
- No PLANTS_HISTORY or audit tables

### Discussion Points
1. Do we need field-level change tracking?
2. Implement triggers for history tables?
3. Use Oracle Flashback instead?

### Status
**Not Implemented - Assess Need**

---

## 6. Manual Override Capability

### Current Limitation
- No way to "lock" a record from API updates
- All data can be overwritten by next API refresh

### Questions
1. Need for manual data corrections that persist?
2. "Protected" flag to prevent API overwrites?
3. Manual override table for exceptions?

### Status
**Not Implemented - Assess Need**

---

## Meeting Agenda Items

### Priority 1 (Must Discuss)
- [ ] Plant ID stability guarantee
- [ ] Data retention requirements

### Priority 2 (Should Discuss)
- [ ] History tracking requirements
- [ ] Manual override needs

### Priority 3 (Nice to Discuss)
- [ ] Performance optimization strategies
- [ ] Future scaling considerations

---

## Decision Log

| Date | Topic | Decision | Responsible |
|------|-------|----------|-------------|
| TBD | Plant ID Stability | Pending | - |
| TBD | Data Retention | Pending | - |

---

## Notes Section
(Add meeting notes and decisions here)

---

*Last Updated: 2025-08-24*
*Next Review: [Schedule with DB Team]*