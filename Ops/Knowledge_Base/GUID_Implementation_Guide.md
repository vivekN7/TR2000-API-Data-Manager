# GUID Implementation Guide for TR2000 ETL System

## Overview

This guide provides step-by-step instructions for implementing GUID support in the existing TR2000 ETL system. The implementation is designed to be non-disruptive, maintaining backward compatibility while adding new capabilities.

---

## Table of Contents
1. [Implementation Phases](#implementation-phases)
2. [Phase 1: Database Schema Updates](#phase-1-database-schema-updates)
3. [Phase 2: Package Modifications](#phase-2-package-modifications)
4. [Phase 3: ETL Process Updates](#phase-3-etl-process-updates)
5. [Phase 4: View Updates](#phase-4-view-updates)
6. [Phase 5: APEX UI Updates](#phase-5-apex-ui-updates)
7. [Testing Plan](#testing-plan)
8. [Rollback Plan](#rollback-plan)
9. [Migration Checklist](#migration-checklist)

---

## Implementation Phases

### Phase Overview
```
Phase 1: Database Schema (Day 1)
  ├── Add GUID columns to existing tables
  ├── Create new tracking tables
  └── Deploy PKG_GUID_UTILS

Phase 2: Package Updates (Day 2)
  ├── Update pkg_api_client
  ├── Update ETL packages
  └── Add correlation tracking

Phase 3: ETL Process (Day 3)
  ├── Modify RAW_JSON ingestion
  ├── Update parsing procedures
  └── Enhance error handling

Phase 4: Views (Day 4)
  ├── Add GUID columns to views
  └── Create new monitoring views

Phase 5: APEX UI (Day 5)
  ├── Update pages to display GUIDs
  └── Add correlation tracking UI
```

---

## Phase 1: Database Schema Updates

### Step 1.1: Deploy GUID Support Script

```bash
# Connect to database
export LD_LIBRARY_PATH=/workspace/TR2000/TR2K/Database/tools/instantclient:$LD_LIBRARY_PATH
/workspace/TR2000/TR2K/Database/tools/instantclient/sqlplus -S TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1

# Run the GUID enhancement script
@/workspace/TR2000/TR2K/Database/deploy/incremental/add_guid_support.sql
```

### Step 1.2: Verify GUID Columns Added

```sql
-- Check PLANTS table
DESC PLANTS;
-- Should show new columns:
-- PLANT_GUID     RAW(16)
-- EXTERNAL_GUID  VARCHAR2(36)
-- API_SYNC_GUID  VARCHAR2(36)

-- Check ISSUES table
DESC ISSUES;
-- Should show new columns:
-- ISSUE_GUID     RAW(16)
-- EXTERNAL_GUID  VARCHAR2(36)
-- API_SYNC_GUID  VARCHAR2(36)

-- Verify new tables
SELECT table_name FROM user_tables 
WHERE table_name IN ('API_TRANSACTIONS', 'EXTERNAL_SYSTEM_REFS');
```

### Step 1.3: Backfill GUIDs for Existing Records

```sql
-- GUIDs are auto-generated for new records via DEFAULT
-- For existing records, they'll be NULL - let's populate them

-- Update existing PLANTS records
UPDATE PLANTS 
SET plant_guid = SYS_GUID() 
WHERE plant_guid IS NULL;

-- Update existing ISSUES records
UPDATE ISSUES 
SET issue_guid = SYS_GUID() 
WHERE issue_guid IS NULL;

-- Update existing RAW_JSON records
UPDATE RAW_JSON 
SET transaction_guid = SYS_GUID() 
WHERE transaction_guid IS NULL;

COMMIT;

-- Verify
SELECT COUNT(*) AS plants_without_guid FROM PLANTS WHERE plant_guid IS NULL;
SELECT COUNT(*) AS issues_without_guid FROM ISSUES WHERE issue_guid IS NULL;
```

### Step 1.4: Add GUID Columns to Reference Tables (Future)

```sql
-- For Task 7 tables (when created):
ALTER TABLE PCS_REFERENCES ADD (
    pcs_ref_guid    RAW(16) DEFAULT SYS_GUID(),
    external_guid   VARCHAR2(36)
);

ALTER TABLE VDS_REFERENCES ADD (
    vds_ref_guid    RAW(16) DEFAULT SYS_GUID(),
    external_guid   VARCHAR2(36)
);

-- Continue for other reference tables...
```

---

## Phase 2: Package Modifications

### Step 2.1: Enhance pkg_api_client with Correlation Tracking

Create new version with GUID support:

```sql
CREATE OR REPLACE PACKAGE pkg_api_client AS
    -- Existing functions remain unchanged for compatibility
    FUNCTION fetch_plants_json RETURN CLOB;
    
    -- New functions with GUID support
    FUNCTION fetch_plants_json_v2(
        p_correlation_id  VARCHAR2 DEFAULT NULL,
        p_idempotency_key VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;
    
    -- Enhanced procedures with optional GUID parameters
    PROCEDURE refresh_plants_from_api(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL,
        p_idempotency_key IN VARCHAR2 DEFAULT NULL
    );
END pkg_api_client;
/

CREATE OR REPLACE PACKAGE BODY pkg_api_client AS
    
    -- Enhanced fetch with correlation tracking
    FUNCTION fetch_plants_json_v2(
        p_correlation_id  VARCHAR2 DEFAULT NULL,
        p_idempotency_key VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_response CLOB;
        l_url VARCHAR2(500);
        l_correlation_id VARCHAR2(36);
    BEGIN
        -- Use provided correlation ID or generate new
        l_correlation_id := NVL(p_correlation_id, PKG_GUID_UTILS.create_correlation_id());
        
        -- Check for duplicate operation
        IF p_idempotency_key IS NOT NULL THEN
            IF PKG_GUID_UTILS.is_duplicate_operation(p_idempotency_key) THEN
                -- Return cached result
                SELECT response_body INTO l_response
                FROM API_TRANSACTIONS
                WHERE idempotency_key = p_idempotency_key
                AND status = 'SUCCESS';
                RETURN l_response;
            END IF;
        END IF;
        
        -- Log API call start
        PKG_GUID_UTILS.log_api_transaction(
            p_correlation_id => l_correlation_id,
            p_operation_type => 'FETCH_PLANTS',
            p_request_url => get_base_url() || '/plants',
            p_request_method => 'GET',
            p_idempotency_key => p_idempotency_key
        );
        
        BEGIN
            -- Make the actual API call
            l_url := get_base_url() || '/plants';
            l_response := APEX_WEB_SERVICE.make_rest_request(
                p_url => l_url,
                p_http_method => 'GET',
                p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
                p_wallet_pwd => 'WalletPass123'
            );
            
            -- Log success
            PKG_GUID_UTILS.update_api_response(
                p_correlation_id => l_correlation_id,
                p_response_code => 200,
                p_response_body => l_response,
                p_status => 'SUCCESS'
            );
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Log failure
                PKG_GUID_UTILS.update_api_response(
                    p_correlation_id => l_correlation_id,
                    p_response_code => 500,
                    p_response_body => NULL,
                    p_status => 'FAILED',
                    p_error_message => SQLERRM
                );
                RAISE;
        END;
        
        RETURN l_response;
    END fetch_plants_json_v2;
    
    -- Keep existing function for compatibility
    FUNCTION fetch_plants_json RETURN CLOB IS
    BEGIN
        RETURN fetch_plants_json_v2(NULL, NULL);
    END fetch_plants_json;
    
    -- Enhanced refresh procedure
    PROCEDURE refresh_plants_from_api(
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2,
        p_correlation_id  IN VARCHAR2 DEFAULT NULL,
        p_idempotency_key IN VARCHAR2 DEFAULT NULL
    ) IS
        l_json CLOB;
        l_hash VARCHAR2(64);
        l_raw_json_id NUMBER;
        l_correlation_id VARCHAR2(36);
        l_run_id NUMBER;
    BEGIN
        -- Generate or use correlation ID
        l_correlation_id := NVL(p_correlation_id, PKG_GUID_UTILS.create_correlation_id());
        
        -- Start ETL run logging
        INSERT INTO ETL_RUN_LOG (
            run_type, 
            endpoint_key, 
            start_time, 
            status,
            correlation_id  -- New column
        )
        VALUES (
            'PLANTS_API_REFRESH', 
            'plants', 
            SYSTIMESTAMP, 
            'RUNNING',
            l_correlation_id
        )
        RETURNING run_id INTO l_run_id;
        
        -- Fetch with correlation tracking
        l_json := fetch_plants_json_v2(l_correlation_id, p_idempotency_key);
        l_hash := calculate_sha256(l_json);
        
        -- Store in RAW_JSON with correlation
        IF NOT pkg_raw_ingest.is_duplicate_hash(l_hash) THEN
            INSERT INTO RAW_JSON (
                endpoint_key,
                api_url,
                response_json,
                sha256_hash,
                correlation_id,    -- New column
                transaction_guid   -- Auto-generated
            ) VALUES (
                'plants',
                get_base_url() || '/plants',
                l_json,
                l_hash,
                l_correlation_id,
                DEFAULT
            )
            RETURNING raw_json_id INTO l_raw_json_id;
            
            -- Continue with parsing...
            pkg_parse_plants.parse_plants_json(l_raw_json_id);
            pkg_upsert_plants.merge_plants_current_state();
            
            p_status := 'SUCCESS';
            p_message := 'Plants refreshed successfully. Correlation: ' || l_correlation_id;
        ELSE
            p_status := 'SKIPPED';
            p_message := 'No changes detected (duplicate hash). Correlation: ' || l_correlation_id;
        END IF;
        
        -- Update ETL run log
        UPDATE ETL_RUN_LOG
        SET end_time = SYSTIMESTAMP,
            status = p_status,
            error_message = p_message
        WHERE run_id = l_run_id;
        
        COMMIT;
    END refresh_plants_from_api;
    
END pkg_api_client;
/
```

### Step 2.2: Update ETL Packages to Preserve GUIDs

```sql
-- Modify pkg_upsert_plants to preserve GUIDs during MERGE
CREATE OR REPLACE PACKAGE BODY pkg_upsert_plants AS
    
    PROCEDURE merge_plants_current_state IS
    BEGIN
        MERGE INTO PLANTS tgt
        USING (
            SELECT DISTINCT
                plant_id,
                short_description,
                long_description,
                operator,
                country,
                update_date
            FROM STG_PLANTS
            WHERE processing_status = 'PENDING'
        ) src
        ON (tgt.plant_id = src.plant_id)
        WHEN MATCHED THEN
            UPDATE SET
                short_description = src.short_description,
                long_description = src.long_description,
                operator = src.operator,
                country = src.country,
                update_date = src.update_date,
                last_modified_date = SYSDATE,
                is_valid = 'Y'
                -- Note: plant_guid is NOT updated (preserves GUID)
        WHEN NOT MATCHED THEN
            INSERT (
                plant_guid,  -- Auto-generated by DEFAULT
                plant_id,
                short_description,
                long_description,
                operator,
                country,
                update_date,
                created_date,
                last_modified_date,
                is_valid
            ) VALUES (
                SYS_GUID(),  -- Or DEFAULT
                src.plant_id,
                src.short_description,
                src.long_description,
                src.operator,
                src.country,
                src.update_date,
                SYSDATE,
                SYSDATE,
                'Y'
            );
            
        -- Mark as processed
        UPDATE STG_PLANTS 
        SET processing_status = 'PROCESSED'
        WHERE processing_status = 'PENDING';
        
        COMMIT;
    END merge_plants_current_state;
    
END pkg_upsert_plants;
/
```

---

## Phase 3: ETL Process Updates

### Step 3.1: Update RAW_JSON Ingestion

```sql
-- Already handled by schema changes
-- transaction_guid auto-generates
-- correlation_id and request_id can be added during insert
```

### Step 3.2: Create GUID-Based ETL Views

```sql
CREATE OR REPLACE VIEW V_ETL_PLANT_GUIDS AS
SELECT 
    p.plant_guid,
    PKG_GUID_UTILS.raw_to_guid(p.plant_guid) AS plant_uuid,
    p.plant_id,
    p.short_description,
    COUNT(i.issue_guid) AS issue_count,
    p.created_date,
    p.last_modified_date
FROM PLANTS p
LEFT JOIN ISSUES i ON p.plant_id = i.plant_id AND i.is_valid = 'Y'
WHERE p.is_valid = 'Y'
GROUP BY p.plant_guid, p.plant_id, p.short_description, 
         p.created_date, p.last_modified_date;

-- Create view for API transaction monitoring
CREATE OR REPLACE VIEW V_API_TRANSACTION_MONITOR AS
SELECT 
    correlation_id,
    operation_type,
    request_method,
    request_url,
    response_code,
    status,
    started_at,
    completed_at,
    duration_ms,
    error_message
FROM API_TRANSACTIONS
WHERE started_at >= SYSDATE - 1  -- Last 24 hours
ORDER BY started_at DESC;
```

### Step 3.3: Add GUID Support to Selection Management

```sql
-- Update SELECTION_LOADER to support GUIDs
ALTER TABLE SELECTION_LOADER ADD (
    selection_guid  RAW(16) DEFAULT SYS_GUID(),
    plant_guid      RAW(16),
    issue_guid      RAW(16)
);

-- Add foreign key constraints
ALTER TABLE SELECTION_LOADER 
ADD CONSTRAINT FK_SEL_PLANT_GUID 
FOREIGN KEY (plant_guid) REFERENCES PLANTS(plant_guid);

ALTER TABLE SELECTION_LOADER 
ADD CONSTRAINT FK_SEL_ISSUE_GUID 
FOREIGN KEY (issue_guid) REFERENCES ISSUES(issue_guid);

-- Update existing records to populate GUIDs
UPDATE SELECTION_LOADER sl
SET plant_guid = (
    SELECT plant_guid 
    FROM PLANTS p 
    WHERE p.plant_id = sl.plant_id
)
WHERE plant_guid IS NULL;

UPDATE SELECTION_LOADER sl
SET issue_guid = (
    SELECT i.issue_guid 
    FROM ISSUES i 
    WHERE i.plant_id = sl.plant_id 
    AND i.issue_revision = sl.issue_revision
)
WHERE issue_revision IS NOT NULL 
AND issue_guid IS NULL;

COMMIT;
```

---

## Phase 4: View Updates

### Step 4.1: Update Existing Views to Include GUIDs

```sql
-- Update V_PLANT_ISSUE_SUMMARY
CREATE OR REPLACE VIEW V_PLANT_ISSUE_SUMMARY AS
SELECT 
    p.plant_guid,
    PKG_GUID_UTILS.raw_to_guid(p.plant_guid) AS plant_uuid,
    p.plant_id,
    p.short_description AS plant_name,
    p.operator,
    p.country,
    COUNT(DISTINCT i.issue_revision) AS total_issues,
    COUNT(DISTINCT CASE WHEN i.is_valid = 'Y' THEN i.issue_revision END) AS active_issues,
    MAX(i.update_date) AS latest_issue_date
FROM PLANTS p
LEFT JOIN ISSUES i ON p.plant_id = i.plant_id
WHERE p.is_valid = 'Y'
GROUP BY p.plant_guid, p.plant_id, p.short_description, p.operator, p.country;

-- Update V_SELECTION_STATUS
CREATE OR REPLACE VIEW V_SELECTION_STATUS AS
SELECT 
    sl.selection_guid,
    PKG_GUID_UTILS.raw_to_guid(sl.selection_guid) AS selection_uuid,
    sl.plant_guid,
    sl.issue_guid,
    sl.plant_id,
    sl.issue_revision,
    p.short_description AS plant_name,
    i.short_description AS issue_description,
    sl.is_active,
    sl.selection_date,
    sl.selection_type,
    CASE 
        WHEN sl.issue_revision IS NOT NULL THEN 'ISSUE_SPECIFIC'
        ELSE 'PLANT_LEVEL'
    END AS selection_level
FROM SELECTION_LOADER sl
LEFT JOIN PLANTS p ON sl.plant_id = p.plant_id
LEFT JOIN ISSUES i ON sl.plant_id = i.plant_id 
                   AND sl.issue_revision = i.issue_revision
WHERE sl.is_active = 'Y';
```

### Step 4.2: Create New GUID-Specific Views

```sql
-- View for External System Mapping
CREATE OR REPLACE VIEW V_EXTERNAL_SYSTEM_MAPPING AS
SELECT 
    es.external_system,
    es.entity_type,
    CASE es.entity_type
        WHEN 'PLANT' THEN p.plant_id
        WHEN 'ISSUE' THEN i.plant_id || '|' || i.issue_revision
    END AS business_key,
    PKG_GUID_UTILS.raw_to_guid(es.internal_guid) AS internal_uuid,
    es.external_id,
    es.external_guid,
    es.sync_status,
    es.last_pushed_at,
    es.last_pulled_at
FROM EXTERNAL_SYSTEM_REFS es
LEFT JOIN PLANTS p ON es.internal_guid = p.plant_guid 
                   AND es.entity_type = 'PLANT'
LEFT JOIN ISSUES i ON es.internal_guid = i.issue_guid 
                   AND es.entity_type = 'ISSUE';

-- View for Correlation Tracking
CREATE OR REPLACE VIEW V_CORRELATION_TRACKING AS
SELECT 
    correlation_id,
    MIN(started_at) AS first_operation,
    MAX(completed_at) AS last_operation,
    COUNT(*) AS operation_count,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failure_count,
    LISTAGG(operation_type, ' -> ') WITHIN GROUP (ORDER BY started_at) AS operation_flow
FROM API_TRANSACTIONS
GROUP BY correlation_id;
```

---

## Phase 5: APEX UI Updates

### Step 5.1: Update APEX Pages to Display GUIDs

```sql
-- Add GUID column to plant selection page
-- Page 5: ETL Control Center

-- Update the Plants report query:
SELECT 
    plant_id,
    short_description,
    operator,
    PKG_GUID_UTILS.raw_to_guid(plant_guid) AS plant_uuid,
    CASE 
        WHEN plant_id IN (SELECT plant_id FROM SELECTION_LOADER WHERE is_active = 'Y')
        THEN 'Selected'
        ELSE 'Not Selected'
    END AS selection_status
FROM PLANTS
WHERE is_valid = 'Y'
ORDER BY plant_id;
```

### Step 5.2: Create API Transaction Monitor Page

```sql
-- New Page: API Transaction Monitor
-- Interactive Report showing:
SELECT 
    correlation_id,
    operation_type,
    request_url,
    response_code,
    status,
    TO_CHAR(started_at, 'DD-MON-YYYY HH24:MI:SS') AS started,
    duration_ms,
    SUBSTR(error_message, 1, 50) AS error_summary
FROM API_TRANSACTIONS
WHERE started_at >= :P10_START_DATE
ORDER BY started_at DESC;
```

### Step 5.3: Add Correlation ID to ETL Run Display

```sql
-- Update ETL_RUN_LOG display
ALTER TABLE ETL_RUN_LOG ADD (
    correlation_id VARCHAR2(36)
);

-- Update ETL monitoring query:
SELECT 
    run_id,
    run_type,
    endpoint_key,
    correlation_id,  -- New column
    TO_CHAR(start_time, 'DD-MON HH24:MI:SS') AS started,
    TO_CHAR(end_time, 'DD-MON HH24:MI:SS') AS completed,
    status,
    record_count,
    error_message
FROM ETL_RUN_LOG
ORDER BY run_id DESC
FETCH FIRST 20 ROWS ONLY;
```

---

## Testing Plan

### Test 1: Verify GUID Generation
```sql
-- Insert test plant
INSERT INTO PLANTS (plant_id, short_description) 
VALUES ('TEST_GUID_001', 'GUID Test Plant');

-- Verify GUID was generated
SELECT 
    plant_id,
    plant_guid,
    PKG_GUID_UTILS.raw_to_guid(plant_guid) AS plant_uuid
FROM PLANTS 
WHERE plant_id = 'TEST_GUID_001';

-- Clean up
DELETE FROM PLANTS WHERE plant_id = 'TEST_GUID_001';
COMMIT;
```

### Test 2: Test Idempotency
```sql
DECLARE
    v_status VARCHAR2(50);
    v_message VARCHAR2(4000);
    v_idempotency_key VARCHAR2(36) := PKG_GUID_UTILS.generate_guid();
BEGIN
    -- First call
    pkg_api_client.refresh_plants_from_api(
        p_status => v_status,
        p_message => v_message,
        p_idempotency_key => v_idempotency_key
    );
    DBMS_OUTPUT.PUT_LINE('First call: ' || v_status);
    
    -- Second call with same key
    pkg_api_client.refresh_plants_from_api(
        p_status => v_status,
        p_message => v_message,
        p_idempotency_key => v_idempotency_key
    );
    DBMS_OUTPUT.PUT_LINE('Second call: ' || v_status);  -- Should be SKIPPED
END;
/
```

### Test 3: Test Correlation Tracking
```sql
-- Check correlation across operations
SELECT * FROM V_CORRELATION_TRACKING
WHERE correlation_id IN (
    SELECT DISTINCT correlation_id 
    FROM API_TRANSACTIONS 
    WHERE started_at >= SYSDATE - 1/24
);
```

### Test 4: Verify Foreign Key Relationships
```sql
-- Test GUID-based foreign keys
INSERT INTO PLANTS (plant_id, short_description) 
VALUES ('TEST_FK_001', 'FK Test Plant');

INSERT INTO ISSUES (plant_id, issue_revision, short_description)
VALUES ('TEST_FK_001', '1.0', 'FK Test Issue');

-- Verify GUIDs are linked
SELECT 
    p.plant_guid,
    i.issue_guid,
    i.plant_id,
    i.issue_revision
FROM PLANTS p
JOIN ISSUES i ON p.plant_id = i.plant_id
WHERE p.plant_id = 'TEST_FK_001';

-- Clean up
DELETE FROM ISSUES WHERE plant_id = 'TEST_FK_001';
DELETE FROM PLANTS WHERE plant_id = 'TEST_FK_001';
COMMIT;
```

---

## Rollback Plan

### If Issues Arise, Rollback Steps:

```sql
-- 1. Remove new columns (preserves data)
ALTER TABLE PLANTS DROP COLUMN plant_guid;
ALTER TABLE PLANTS DROP COLUMN external_guid;
ALTER TABLE PLANTS DROP COLUMN api_sync_guid;

ALTER TABLE ISSUES DROP COLUMN issue_guid;
ALTER TABLE ISSUES DROP COLUMN external_guid;
ALTER TABLE ISSUES DROP COLUMN api_sync_guid;

-- 2. Drop new tables
DROP TABLE API_TRANSACTIONS;
DROP TABLE EXTERNAL_SYSTEM_REFS;

-- 3. Drop new package
DROP PACKAGE PKG_GUID_UTILS;

-- 4. Restore original packages
@/workspace/TR2000/TR2K/Database/deploy/03_packages/06_pkg_api_client_backup.sql

-- 5. Drop new views
DROP VIEW V_ETL_PLANT_GUIDS;
DROP VIEW V_API_TRANSACTION_MONITOR;
DROP VIEW V_EXTERNAL_SYSTEM_MAPPING;
DROP VIEW V_CORRELATION_TRACKING;
```

---

## Migration Checklist

### Pre-Implementation
- [ ] Backup database
- [ ] Document current state
- [ ] Review with team
- [ ] Schedule maintenance window

### Phase 1: Schema
- [ ] Run add_guid_support.sql
- [ ] Verify new columns added
- [ ] Backfill GUIDs for existing records
- [ ] Test GUID generation

### Phase 2: Packages
- [ ] Deploy PKG_GUID_UTILS
- [ ] Update pkg_api_client
- [ ] Test correlation tracking
- [ ] Verify idempotency

### Phase 3: ETL
- [ ] Update RAW_JSON processing
- [ ] Modify parsing procedures
- [ ] Test end-to-end ETL with GUIDs

### Phase 4: Views
- [ ] Update existing views
- [ ] Create new monitoring views
- [ ] Verify view performance

### Phase 5: APEX
- [ ] Update selection pages
- [ ] Add transaction monitor
- [ ] Test UI functionality

### Post-Implementation
- [ ] Run full test suite
- [ ] Monitor performance
- [ ] Document lessons learned
- [ ] Train team on new features

---

## Performance Monitoring

### Monitor After Implementation:

```sql
-- Check index usage
SELECT 
    index_name,
    table_name,
    num_rows,
    leaf_blocks,
    clustering_factor
FROM user_indexes
WHERE table_name IN ('PLANTS', 'ISSUES', 'API_TRANSACTIONS');

-- Check for fragmentation
SELECT 
    segment_name,
    bytes/1024/1024 AS size_mb,
    blocks,
    extents
FROM user_segments
WHERE segment_name IN ('PLANTS', 'ISSUES', 'API_TRANSACTIONS');

-- Monitor API transaction performance
SELECT 
    operation_type,
    COUNT(*) AS call_count,
    AVG(duration_ms) AS avg_duration,
    MIN(duration_ms) AS min_duration,
    MAX(duration_ms) AS max_duration
FROM API_TRANSACTIONS
WHERE started_at >= SYSDATE - 7
GROUP BY operation_type;
```

---

## Support Resources

### Common Issues and Solutions:

**Issue 1: GUID generation fails**
```sql
-- Solution: Grant execute on DBMS_CRYPTO
GRANT EXECUTE ON DBMS_CRYPTO TO TR2000_STAGING;
```

**Issue 2: Performance degradation**
```sql
-- Solution: Rebuild indexes
ALTER INDEX UK_PLANTS_GUID REBUILD ONLINE;
ALTER INDEX UK_ISSUES_GUID REBUILD ONLINE;
```

**Issue 3: Correlation ID not propagating**
```sql
-- Check if correlation_id column exists
SELECT column_name 
FROM user_tab_columns 
WHERE table_name = 'RAW_JSON' 
AND column_name = 'CORRELATION_ID';

-- Add if missing
ALTER TABLE RAW_JSON ADD correlation_id VARCHAR2(36);
```

---

## Conclusion

This implementation guide provides a structured approach to adding GUID support to the TR2000 ETL system. The phased approach ensures minimal disruption while adding powerful new capabilities for multi-system integration and API interactions.

Key benefits after implementation:
- ✅ Global uniqueness for all entities
- ✅ API idempotency support
- ✅ Cross-system correlation tracking
- ✅ External system reference mapping
- ✅ Future-proof architecture for REST APIs

---

*Document Version: 1.0*  
*Last Updated: 2025-08-25*  
*Author: TR2000 ETL Team*  
*Next Review: After Phase 1 completion*