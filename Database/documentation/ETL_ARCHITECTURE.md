# ETL Architecture & Operations Guide - TR2000 Staging System

## System Philosophy

### Core Principles
1. **Staging/Transformation Only** - This is NOT a master data management system
2. **API is Truth** - The Equinor API is always the source of truth
3. **No Soft-Deletes** - No is_valid columns, no complex cascade logic
4. **Clear-Then-Load** - Always start fresh, no partial updates
5. **Simple Recovery** - If anything fails, just clear and restart

### Why This Approach?
- The API maintains all history and revisions
- We're building a separate master PCS system later
- Complexity was causing bugs (11+ critical issues found)
- Maintenance overhead exceeded benefits
- Simple is reliable

## ETL Processes

### Initial Clear Phase
Before any ETL process starts, clear all data tables except:
- Control tables (ETL_FILTER, CONTROL_SETTINGS)
- Logging tables (ETL_LOG, ETL_RUN_LOG, ETL_ERROR_LOG, ETL_STATS)
- RAW_JSON (audit trail)
- VDS_LIST (not cleared since it's a separate ETL process)

Tables to clear:
- All reference tables (PCS_REFERENCES, VDS_REFERENCES, MDS_REFERENCES, etc.)
- All PCS detail tables (PCS_HEADER_PROPERTIES, PCS_TEMP_PRESSURES, etc.)
- PCS_LIST
- All staging tables (STG_*)

Main flow for all processes: API Call → RAW_JSON → STG_* → Core tables

### Process 1: Reference Data ETL (Issue-based)
**Flow:** ETL_FILTER → For each plant_id and issue_revision → API Calls → Parse → Load

**API Endpoints:**
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/issues/rev/{issuerev}/pcs`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/issues/rev/{issuerev}/vds`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/issues/rev/{issuerev}/mds`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/issues/rev/{issuerev}/eds`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/issues/rev/{issuerev}/vsk`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/issues/rev/{issuerev}/esk`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/issues/rev/{issuerev}/pipe-elements`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/issues/rev/{issuerev}/sc`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/issues/rev/{issuerev}/vsm`

### Process 2: PCS_LIST Load
**Flow:** ETL_FILTER → For each unique plant_id → API Call → Parse → Load

**API Endpoint:**
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/pcs`

### Process 3: PCS Details ETL (Reference-dependent)
**Flow:** ETL_FILTER → For each plant_id and issue_revision → Get PCS_NAME and official_revision from PCS_REFERENCES → API Calls → Parse → Load

**API Endpoints (6 per PCS):**
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/pcs/{pcsname}/rev/{official_revision}`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/pcs/{pcsname}/rev/{official_revision}/temp-pressures`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/pcs/{pcsname}/rev/{official_revision}/pipe-sizes`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/pcs/{pcsname}/rev/{official_revision}/pipe-elements`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/pcs/{pcsname}/rev/{official_revision}/valve-elements`
- `https://equinor.pipespec-api.presight.com/plants/{plantid}/pcs/{pcsname}/rev/{official_revision}/embedded-notes`

### VDS Catalog ETL (Independent - Separate Process)
**Flow:** Manual Trigger → Clear VDS_LIST → API Call → Parse → Load

**API Endpoint:**
- `https://equinor.pipespec-api.presight.com/vds` (No parameters, returns 50,000+ items)

Note: This is a completely separate ETL process, not part of the main ETL flow.

## Core Tables

### 1. Control Tables
```sql
ETL_FILTER
├── filter_id (PK, auto-generated)
├── plant_id (NOT NULL)
├── plant_name (for reference)
├── issue_revision (NOT NULL)
├── added_date (DEFAULT SYSDATE)
├── added_by_user_id
└── UNIQUE(plant_id, issue_revision)

CONTROL_SETTINGS
├── setting_name (PK)
├── setting_value
├── description
└── last_modified
```

### 2. RAW_JSON Table (Raw data dump for parsing)
```sql
RAW_JSON
├── raw_json_id (PK)
├── endpoint
├── plant_id (nullable for VDS)
├── issue_revision (nullable for VDS)
├── pcs_name (nullable, for PCS details)
├── pcs_revision (nullable, for PCS details)
├── payload (CLOB)
├── created_date
└── batch_id
```

### 3. Reference Tables (9 types - Issue-dependent)
- PCS_REFERENCES (links to PCS details)
- VDS_REFERENCES
- MDS_REFERENCES
- EDS_REFERENCES
- VSK_REFERENCES
- ESK_REFERENCES
- PIPE_ELEMENT_REFERENCES
- SC_REFERENCES
- VSM_REFERENCES

### 4. PCS Tables
- PCS_LIST (All PCS for a plant)
- PCS_HEADER_PROPERTIES (Detail table)
- PCS_TEMP_PRESSURES (Detail table)
- PCS_PIPE_SIZES (Detail table)
- PCS_PIPE_ELEMENTS (Detail table)
- PCS_VALVE_ELEMENTS (Detail table)
- PCS_EMBEDDED_NOTES (Detail table)

### 5. VDS Catalog Table (Independent)
```sql
VDS_LIST
├── vds_guid (PK)
├── vds_name
├── revision
├── status
├── rev_date
├── description
├── valve_type_id
├── rating_class_id
├── material_group_id
├── end_connection_id
├── bore_id
├── size_range
├── custom_name
├── subsegment_list
├── created_date
└── last_modified_date
```

### 6. Staging Tables (Temporary)
All staging tables use VARCHAR2 for all columns (no strong typing) to allow direct JSON transfer:
- STG_PCS_REFERENCES
- STG_VDS_REFERENCES
- STG_MDS_REFERENCES
- STG_EDS_REFERENCES
- STG_VSK_REFERENCES
- STG_ESK_REFERENCES
- STG_PIPE_ELEMENT_REFERENCES
- STG_SC_REFERENCES
- STG_VSM_REFERENCES
- STG_PCS_LIST
- STG_VDS_LIST
- STG_PCS_HEADER_PROPERTIES
- STG_PCS_TEMP_PRESSURES
- STG_PCS_PIPE_SIZES
- STG_PCS_PIPE_ELEMENTS
- STG_PCS_VALVE_ELEMENTS
- STG_PCS_EMBEDDED_NOTES

Note: Data is properly typed (NUMBER, DATE, etc.) when moving from STG_* to final tables.

### 7. Control/Logging Tables
- ETL_LOG - Main ETL execution log
- ETL_RUN_LOG - Individual run details
- ETL_ERROR_LOG - Error tracking
- ETL_STATS - Performance statistics

## Package Structure

### 1. PKG_ETL_CONTROL
**Purpose**: Orchestrate ETL processes

**Key Procedures:**
- **Reference Data ETL**: Main entry point, clear tables, process issues
- **PCS Details ETL**: Load details for all PCS references  
- **VDS Catalog ETL**: Load entire VDS catalog
- **Utilities**: Logging and error handling

### 2. PKG_API_CLIENT
**Purpose**: Handle all API communications

**Key Functions:**
- **Reference endpoints**: Fetch data for 9 reference types
- **PCS endpoints**: 6 detail endpoints (header, temp/pressure, sizes, elements, valves, notes)
- **VDS endpoint**: Single endpoint for entire catalog
- **RAW_JSON storage**: Store all API responses for audit

### 3. PKG_ETL_PROCESSOR
**Purpose**: Parse JSON and load data

**Key Procedure Groups:**
- **Reference parsing**: JSON to staging for 9 reference types
- **Reference loading**: Staging to final tables
- **PCS Details parsing**: JSON to staging for 6 detail types
- **PCS Details loading**: Staging to final detail tables
- **VDS Catalog**: Parse and load VDS items
- **Utilities**: Extract unique PCS combinations

## User Operations

### Managing ETL_FILTER

```sql
-- View current filters
SELECT plant_id, plant_name, issue_revision, added_date, added_by_user_id
FROM ETL_FILTER
ORDER BY plant_id, issue_revision;

-- Add new plant/issue
INSERT INTO ETL_FILTER (plant_id, plant_name, issue_revision, added_by_user_id)
VALUES ('34', 'GRANE', '4.2', 'john.doe');

-- Remove plant/issue
DELETE FROM ETL_FILTER 
WHERE plant_id = '34' AND issue_revision = '4.2';
```

### Running ETL Processes

1. **Reference Data ETL** - Processes all entries in ETL_FILTER
2. **PCS_LIST Load** - Loads all PCS for configured plants
3. **PCS Details ETL** - Loads details for PCS references (run after references)
4. **VDS Catalog ETL** - Independent, can run anytime

### Monitoring

```sql
-- Check overall status
SELECT 
    'ETL Filters' as component, COUNT(*) as count FROM ETL_FILTER
UNION ALL
SELECT 'PCS References', COUNT(*) FROM PCS_REFERENCES
UNION ALL
SELECT 'PCS Details', COUNT(*) FROM PCS_HEADER_PROPERTIES
UNION ALL
SELECT 'VDS Catalog', COUNT(*) FROM VDS_LIST;

-- Check recent ETL runs
SELECT status, message, run_timestamp 
FROM ETL_RUN_LOG 
ORDER BY run_timestamp DESC
FETCH FIRST 10 ROWS ONLY;

-- Check for errors
SELECT * FROM ETL_ERROR_LOG
WHERE error_timestamp > SYSDATE - 1
ORDER BY error_timestamp DESC;
```

## Error Recovery

### Simple Recovery Pattern
If any ETL process fails, just run it again. The system clears tables first, so rerunning is always safe.

- **Reference Data issues**: Run reference ETL again
- **PCS Details issues**: Run PCS details ETL again  
- **VDS Catalog issues**: Run VDS catalog ETL again

For VDS Catalog (50,000+ items), timeouts are expected - simply retry.

## What We Eliminated

### Removed Complexity
- ❌ Soft-delete logic (is_valid columns)
- ❌ Cascade triggers
- ❌ Hash duplicate detection  
- ❌ MERGE statements
- ❌ Complex DELETE WHERE conditions
- ❌ PLANTS/ISSUES tables
- ❌ SELECTED_PLANTS/SELECTED_ISSUES tables
- ❌ SELECTION_LOADER table
- ❌ 15+ complex packages
- ❌ 28+ views with is_valid filters
- ❌ 75+ test procedures

### Removed Bugs
- ❌ Soft-delete bug (11 tables affected)
- ❌ Cascade trigger issues
- ❌ Hash detection causing empty staging
- ❌ Plants "mark all invalid" pattern
- ❌ Inconsistent upsert patterns

## Benefits of Simplified Architecture

### Reliability
- **Predictable**: Always matches API exactly
- **Atomic**: All or nothing, no partial states
- **Recoverable**: One recovery pattern for all failures

### Maintainability  
- **Simple**: ~500 lines vs ~5000 lines
- **Consistent**: Same pattern everywhere
- **Understandable**: New developer can learn in 30 minutes

### Performance
- **Fast Clears**: Simple DELETE statements
- **Fast Loads**: Simple INSERT statements
- **No Complex Logic**: No triggers firing, no cascades

## API Call Volumes

For a typical issue with 100 PCS references:
- **Reference ETL**: 9 API calls (one per reference type)
- **PCS_LIST**: 1 API call per plant
- **PCS Details ETL**: ~600 API calls (6 endpoints × 100 unique PCS)
- **VDS Catalog ETL**: 1 API call (entire catalog)

Total: ~610 API calls per issue

## Summary

**Old System**: API → Plants → Issues → Selected → Cascades → Soft-deletes → Complex Data

**New System**: ETL_FILTER → Clear All → API → Parse → Load

This simplified approach is ideal for a staging system where:
- The API is the source of truth
- Simplicity and reliability are priorities
- Recovery is straightforward (just run again)
- No partial updates or complex merges needed