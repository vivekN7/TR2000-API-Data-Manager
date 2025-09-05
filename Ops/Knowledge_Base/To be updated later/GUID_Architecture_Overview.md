# GUID Architecture for TR2000 ETL System

## Executive Summary

This document explains the GUID (Globally Unique Identifier) architecture being implemented in the TR2000 ETL system to support multi-system integration and REST API interactions. GUIDs provide a foundation for reliable data exchange, API idempotency, and cross-system correlation tracking.

---

## Table of Contents
1. [What are GUIDs?](#what-are-guids)
2. [Why TR2000 Needs GUIDs](#why-tr2000-needs-guids)
3. [Current Architecture Problems](#current-architecture-problems)
4. [GUID Solution Architecture](#guid-solution-architecture)
5. [Benefits for TR2000](#benefits-for-tr2000)
6. [Real-World Scenarios](#real-world-scenarios)
7. [Technical Implementation](#technical-implementation)
8. [Performance Considerations](#performance-considerations)

---

## What are GUIDs?

**GUID (Globally Unique Identifier)** is a 128-bit identifier that is guaranteed to be unique across all systems, databases, and time.

### Oracle GUID Format
```sql
-- Oracle SYS_GUID() generates a RAW(16) value
SELECT SYS_GUID() FROM dual;
-- Result: 7F16B4A6B5C94010E053020011AC8B4D

-- Standard UUID format (with hyphens)
-- 7f16b4a6-b5c9-4010-e053-020011ac8b4d
```

### GUID vs Sequential ID Comparison

| Aspect | Sequential ID | GUID |
|--------|--------------|------|
| **Format** | NUMBER (1, 2, 3...) | RAW(16) hexadecimal |
| **Uniqueness** | Within single database | Globally unique |
| **Predictability** | Predictable sequence | Random, unpredictable |
| **Size** | 4-8 bytes | 16 bytes |
| **Collision Risk** | High across systems | Virtually impossible |
| **API Safety** | Risky (ID conflicts) | Safe (guaranteed unique) |

---

## Why TR2000 Needs GUIDs

### 1. Multi-System Integration Reality

TR2000_STAGING will interact with multiple systems:

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Equinor   │────▶│   TR2000     │────▶│    SAP      │
│     API     │     │   STAGING    │     │   System    │
└─────────────┘     └──────────────┘     └─────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │   Internal   │
                    │   REST APIs  │
                    └──────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
  ┌──────────┐      ┌──────────┐      ┌──────────┐
  │  Teams   │      │  Maximo  │      │  Power   │
  │  Apps    │      │  System  │      │    BI    │
  └──────────┘      └──────────┘      └──────────┘
```

### 2. The ID Collision Problem

**Current State - Dangerous:**
```sql
-- TR2000_STAGING Database
INSERT INTO PLANTS VALUES (1, 'JSP2', ...);

-- SAP System
INSERT INTO FACILITIES VALUES (1, 'GRANE', ...);

-- When systems sync: COLLISION!
-- Both have ID = 1 but represent different entities
```

**With GUIDs - Safe:**
```sql
-- TR2000_STAGING Database
INSERT INTO PLANTS VALUES ('7F16B4A6...', 'JSP2', ...);

-- SAP System  
INSERT INTO FACILITIES VALUES ('8A27C5B7...', 'GRANE', ...);

-- No collision possible - GUIDs are globally unique
```

### 3. API Idempotency Requirement

**Problem: Network failures cause duplicate operations**
```sql
-- Without idempotency
Client: POST /api/plants/create {data}
Server: Creates plant, ID=100
[Network timeout - client doesn't get response]
Client: Retry POST /api/plants/create {data}
Server: Creates DUPLICATE plant, ID=101  ❌
```

**Solution: GUID-based idempotency**
```sql
-- With idempotency key (GUID)
Client: POST /api/plants/create 
        Headers: {'Idempotency-Key': 'a4f5b6c7-d8e9-...'}
Server: Creates plant, stores idempotency key
[Network timeout - client doesn't get response]
Client: Retry with SAME idempotency key
Server: Returns existing result, no duplicate ✅
```

---

## Current Architecture Problems

### Problem 1: Business Key Dependencies
```sql
-- Current: Everything depends on business keys
PLANTS.plant_id = '124'  -- What if this changes to 'JSP2_2025'?
ISSUES.plant_id = '124'  -- Foreign key breaks!
SELECTION_LOADER.plant_id = '124'  -- Selection breaks!
External System Reference = '124'  -- Integration breaks!
```

### Problem 2: No Operation Tracking
```sql
-- Current: Can't track if operation was already done
pkg_api_client.refresh_plants_from_api();
-- Network glitch...
pkg_api_client.refresh_plants_from_api();  -- Duplicates everything!
```

### Problem 3: No Cross-System Correlation
```sql
-- Current: Can't trace operations across systems
Oracle Log: "Error in plant update"
API Gateway: "Request failed"
External System: "Data sync issue"
-- Which are related? No way to tell!
```

### Problem 4: REST API Exposure Risk
```sql
-- Future API endpoint (unsafe with sequential IDs)
GET /api/plants/1  -- Easy to guess
GET /api/plants/2  -- Sequential scanning possible
GET /api/plants/3  -- Security risk!

-- With GUIDs (safe)
GET /api/plants/7f16b4a6-b5c9-4010-e053-020011ac8b4d  -- Unguessable
```

---

## GUID Solution Architecture

### 1. Core Entity GUIDs
Every major entity gets a GUID alongside its business key:

```sql
PLANTS
├── plant_guid (RAW(16))        -- Internal GUID (PK)
├── plant_id (VARCHAR2(50))     -- Business key ('124')
├── external_guid (VARCHAR2(36)) -- From external system
└── api_sync_guid (VARCHAR2(36)) -- For sync tracking

ISSUES  
├── issue_guid (RAW(16))        -- Internal GUID (PK)
├── plant_id (VARCHAR2(50))     -- Business FK
├── issue_revision (VARCHAR2(50)) -- Business key
└── external_guid (VARCHAR2(36)) -- From external system
```

### 2. API Transaction Tracking
Every API interaction is tracked with GUIDs:

```sql
API_TRANSACTIONS
├── transaction_guid (RAW(16))   -- Unique transaction ID
├── correlation_id (VARCHAR2(36)) -- Links related operations
├── idempotency_key (VARCHAR2(36)) -- Prevents duplicates
├── operation_type               -- 'FETCH_PLANTS', 'UPDATE_ISSUE'
├── request/response details
└── timing/status information
```

### 3. External System Mapping
Track how our records map to external systems:

```sql
EXTERNAL_SYSTEM_REFS
├── internal_guid (RAW(16))      -- Our GUID
├── external_system (VARCHAR2)   -- 'SAP', 'MAXIMO', etc.
├── external_id (VARCHAR2)       -- Their ID
├── external_guid (VARCHAR2)     -- Their GUID
└── sync_status                  -- Track sync state
```

---

## Benefits for TR2000

### 1. **Reliable Multi-System Integration**
```sql
-- Plant can be referenced by GUID across all systems
TR2000: plant_guid = '7F16B4A6B5C94010E053020011AC8B4D'
SAP: tr2000_plant_ref = '7f16b4a6-b5c9-4010-e053-020011ac8b4d'
Teams: plant_reference = '7f16b4a6-b5c9-4010-e053-020011ac8b4d'
-- All refer to the same plant, no ambiguity
```

### 2. **Safe API Operations**
```sql
-- Idempotent API calls
BEGIN
    IF NOT PKG_GUID_UTILS.is_duplicate_operation(p_idempotency_key) THEN
        -- Do the operation
        refresh_plants_from_api();
    ELSE
        -- Return cached result
        RETURN get_cached_result(p_idempotency_key);
    END IF;
END;
```

### 3. **Complete Audit Trail**
```sql
-- Trace an operation across all systems
SELECT * FROM API_TRANSACTIONS 
WHERE correlation_id = 'a4f5b6c7-d8e9-4321-b098-765432109876'
ORDER BY started_at;

-- Shows complete flow:
-- 1. Teams app initiated request
-- 2. TR2000 fetched from Equinor API  
-- 3. TR2000 processed data
-- 4. TR2000 pushed to SAP
-- 5. SAP confirmed receipt
```

### 4. **Business Key Independence**
```sql
-- Business key can change without breaking references
UPDATE PLANTS 
SET plant_id = 'JSP2_NEW_2025'  -- Business key changes
WHERE plant_guid = hextoraw('7F16B4A6B5C94010E053020011AC8B4D');
-- All GUID-based references still work!
```

---

## Real-World Scenarios

### Scenario 1: Teams App Integration
```sql
-- Teams app requests plant data
Request: GET /api/v1/plants/7f16b4a6-b5c9-4010-e053-020011ac8b4d
Headers: {
    'X-Correlation-Id': 'teams-req-123',
    'X-Source-System': 'TEAMS_APP'
}

-- TR2000 processes request
1. Log in API_TRANSACTIONS with correlation_id
2. Fetch plant by GUID (instant lookup)
3. Record in EXTERNAL_SYSTEM_REFS that Teams accessed this plant
4. Return data with TR2000 correlation ID

Response: {
    "plant_guid": "7f16b4a6-b5c9-4010-e053-020011ac8b4d",
    "plant_id": "124",
    "name": "JSP2",
    "_meta": {
        "correlation_id": "tr2000-resp-456",
        "cached": false,
        "timestamp": "2025-08-25T10:30:00Z"
    }
}
```

### Scenario 2: Preventing Duplicate ETL Runs
```sql
DECLARE
    l_idempotency_key VARCHAR2(36) := PKG_GUID_UTILS.generate_guid();
BEGIN
    -- First run
    pkg_api_client.refresh_plants_from_api(
        p_idempotency_key => l_idempotency_key
    );
    -- Success, data loaded
    
    -- Accidental second run (same key)
    pkg_api_client.refresh_plants_from_api(
        p_idempotency_key => l_idempotency_key
    );
    -- Skipped! Duplicate detected
END;
```

### Scenario 3: Cross-System Debugging
```sql
-- User reports: "Plant JSP2 data is wrong in SAP"

-- Investigate with correlation tracking:
SELECT 
    at.operation_type,
    at.external_system,
    at.started_at,
    at.status,
    at.error_message
FROM API_TRANSACTIONS at
WHERE at.correlation_id IN (
    SELECT DISTINCT correlation_id 
    FROM API_TRANSACTIONS 
    WHERE entity_guid = (
        SELECT plant_guid FROM PLANTS WHERE plant_id = 'JSP2'
    )
)
ORDER BY at.started_at;

-- Results show:
-- 1. ✅ Fetched from Equinor API successfully
-- 2. ✅ Parsed and stored in TR2000
-- 3. ❌ Push to SAP failed - timeout error
-- 4. ✅ Retry succeeded
-- Problem identified: SAP had stale data from failed push
```

---

## Technical Implementation

### 1. GUID Generation in Oracle
```sql
-- Generate RAW(16) GUID
SELECT SYS_GUID() FROM dual;
-- Result: 7F16B4A6B5C94010E053020011AC8B4D

-- Convert to standard UUID format
SELECT LOWER(
    REGEXP_REPLACE(
        SYS_GUID(),
        '(.{8})(.{4})(.{4})(.{4})(.{12})',
        '\1-\2-\3-\4-\5'
    )
) AS uuid FROM dual;
-- Result: 7f16b4a6-b5c9-4010-e053-020011ac8b4d
```

### 2. Storage Considerations

**RAW(16) vs VARCHAR2(36):**
```sql
-- Storage efficient (16 bytes)
plant_guid RAW(16) DEFAULT SYS_GUID()

-- Human readable but larger (36 bytes)
plant_guid_str VARCHAR2(36) DEFAULT LOWER(
    REGEXP_REPLACE(SYS_GUID(), '(.{8})(.{4})(.{4})(.{4})(.{12})', '\1-\2-\3-\4-\5')
)

-- Recommendation: Use RAW(16) internally, convert for APIs
```

### 3. Index Strategy
```sql
-- Primary key on GUID (automatic index)
ALTER TABLE PLANTS ADD CONSTRAINT PK_PLANTS_GUID 
PRIMARY KEY (plant_guid);

-- Keep business key index for queries
CREATE UNIQUE INDEX UK_PLANTS_BUSINESS 
ON PLANTS(plant_id);

-- Composite for foreign keys
CREATE INDEX IDX_ISSUES_PLANT 
ON ISSUES(plant_guid, issue_revision);
```

---

## Performance Considerations

### 1. GUID Index Performance

**Pros:**
- No hotspot in concurrent inserts (unlike sequences)
- Distributed generation (no sequence contention)

**Cons:**
- Larger index size (16 bytes vs 4-8 for NUMBER)
- Random insertion pattern (can cause index fragmentation)

**Mitigation:**
```sql
-- Use reverse key index for high-insert tables
CREATE INDEX IDX_API_TRANS_GUID 
ON API_TRANSACTIONS(transaction_guid) REVERSE;

-- Regular index rebuilds for fragmented indexes
ALTER INDEX IDX_API_TRANS_GUID REBUILD ONLINE;
```

### 2. Query Performance

```sql
-- Fast: Query by GUID (indexed)
SELECT * FROM PLANTS WHERE plant_guid = hextoraw('7F16B4A6...');

-- Fast: Query by business key (still indexed)
SELECT * FROM PLANTS WHERE plant_id = '124';

-- Slower: Join on GUID vs NUMBER
-- But negligible in practice for typical data volumes
```

### 3. Storage Impact

```sql
-- Storage calculation
1 million plants:
- Sequential ID: 1M × 8 bytes = 8 MB
- GUID: 1M × 16 bytes = 16 MB
- Difference: 8 MB (negligible for modern systems)

-- Index size increase: ~2x
-- But provides global uniqueness guarantee
```

---

## Summary

GUIDs provide TR2000 with:

1. **Global Uniqueness**: Safe integration with any system
2. **API Safety**: Idempotency and unpredictable IDs
3. **Correlation Tracking**: Debug across system boundaries
4. **Business Key Independence**: Change business keys without breaking references
5. **Future Proofing**: Ready for distributed architectures

The small storage and performance overhead is negligible compared to the robustness and integration capabilities gained.

---

## Next Steps

See [GUID Implementation Guide](./GUID_Implementation_Guide.md) for:
- Detailed implementation steps
- Table modifications required
- ETL process updates
- Package modifications
- Testing procedures

---

*Document Version: 1.0*  
*Last Updated: 2025-08-25*  
*Author: TR2000 ETL Team*