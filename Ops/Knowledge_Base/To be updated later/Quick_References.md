# Quick References for TR2000 ETL System

## Key Design Patterns
- **Soft Delete**: Records marked `is_valid='N'` instead of DELETE
- **SHA256 Deduplication**: Skip processing if API response unchanged
- **Three-Layer Architecture**: RAW_JSON → STG_* → Production tables

## Important SQL Queries

### Data Monitoring
```sql
-- Active plants only
SELECT * FROM PLANTS WHERE is_valid = 'Y';

-- Check ETL history
SELECT * FROM ETL_RUN_LOG ORDER BY start_time DESC;

-- Current plant selections
SELECT * FROM SELECTED_PLANTS WHERE is_active = 'Y';

-- Current issue selections
SELECT * FROM SELECTED_ISSUES WHERE is_active = 'Y';

-- Find potential plant ID changes
SELECT old.plant_id as old_id, new.plant_id as new_id, old.short_description
FROM PLANTS old
JOIN PLANTS new ON old.short_description = new.short_description
WHERE old.is_valid = 'N' AND new.is_valid = 'Y'
  AND old.plant_id != new.plant_id;

-- Check for recent errors
SELECT * FROM ETL_ERROR_LOG WHERE error_timestamp > SYSDATE - 1;
```

### Testing Queries
```sql
-- Check raw JSON
SELECT raw_json_id, endpoint_key, LENGTH(response_json) as json_length, created_date 
FROM RAW_JSON WHERE endpoint_key = 'plants';

-- Check staging
SELECT COUNT(*) as staging_count FROM STG_PLANTS;

-- Check final data
SELECT COUNT(*) as active_plants FROM PLANTS WHERE is_valid = 'Y';

-- Issues for selected plants  
SELECT i.* 
FROM ISSUES i
JOIN SELECTED_PLANTS sp ON i.plant_id = sp.plant_id
WHERE sp.is_active = 'Y' AND i.is_valid = 'Y';

-- ETL history for selected plants
SELECT * FROM ETL_RUN_LOG 
WHERE plant_id IN (
  SELECT plant_id FROM SELECTED_PLANTS WHERE is_active = 'Y'
)
ORDER BY start_time DESC;
```

## Connection Information

### Database Connection
- **Database**: TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1
- **Schema**: TR2000_STAGING
- **Password**: piping

### APEX Application
- **APEX URL**: http://localhost:8888/ords/
- **APEX Workspace**: TR2000_ETL
- **APEX Username**: ADMIN
- **APEX Password**: Apex!1985
- **Application ID**: 101 (TR2000 ETL Manager)

### Oracle Wallet (for HTTPS)
- **Wallet Path**: `file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet`
- **Wallet Password**: WalletPass123

## SQL*Plus Quick Connect

### Standard Connection
```bash
export LD_LIBRARY_PATH=/workspace/TR2000/TR2K/Database/tools/instantclient:$LD_LIBRARY_PATH
/workspace/TR2000/TR2K/Database/tools/instantclient/sqlplus -S TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1
```

### One-liner Connection
```bash
export LD_LIBRARY_PATH=/workspace/TR2000/TR2K/Database/tools/instantclient:$LD_LIBRARY_PATH && /workspace/TR2000/TR2K/Database/tools/instantclient/sqlplus -S TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1
```

## Key API Endpoints

### Base URL
```
https://equinor.pipespec-api.presight.com/
```

### Main Endpoints
- `/plants` - Get all plants
- `/plants/{plantId}/issues` - Get issues for a specific plant
- `/plants/{plantId}/issues/{issueId}/pcsReferences` - Get PCS references
- `/plants/{plantId}/issues/{issueId}/vdsReferences` - Get VDS references

## Control Settings Reference

### Currently Active
| Setting Key | Value | Purpose |
|------------|-------|---------|
| API_BASE_URL | https://equinor.pipespec-api.presight.com/ | Base URL for all API calls |

### Future Settings (Not Implemented)
| Setting Key | Default | Purpose |
|------------|---------|---------|
| API_TIMEOUT_SECONDS | 60 | Timeout for API calls |
| MAX_PLANTS_PER_RUN | 10 | Batch size limit |
| RAW_JSON_RETENTION_DAYS | 30 | Data retention period |
| ETL_LOG_RETENTION_DAYS | 90 | Log retention period |

## Package Quick Reference

### Master Controllers
- **pkg_api_client** - Main ETL orchestrator and API interface
- **pkg_selection_mgmt** - User selection management

### Data Processing
- **pkg_raw_ingest** - RAW_JSON operations and deduplication
- **pkg_parse_plants** - Plants JSON parsing
- **pkg_parse_issues** - Issues JSON parsing
- **pkg_upsert_plants** - Plants staging to production
- **pkg_upsert_issues** - Issues staging to production

### ETL Operations
- **pkg_etl_operations** - Alternative dynamic ETL (not currently used)

## Common Commands

### Deploy Database Schema
```bash
cd /workspace/TR2000/TR2K/Database
sqlplus TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1 @Master_DDL.sql
```

### Test API Connectivity
```sql
EXEC pkg_api_client.refresh_plants_from_api(:status, :msg);
PRINT status;
PRINT msg;
```

### Refresh Issues for Selected Plants
```sql
EXEC pkg_api_client.refresh_issues_from_api('124', :status, :msg);
SELECT COUNT(*) FROM ISSUES WHERE plant_id = '124';
```

## Test Plant IDs (VERIFIED WORKING)
- **Plant 124**: JSP2 (12 issues loaded ✅)
- **Plant 34**: GRANE (8 issues loaded ✅)

## Working Commands

### Deploy DDL
```bash
@/workspace/TR2000/TR2K/Database/Master_DDL.sql
```

### Test Data Loading
```sql
-- Load all plants
EXEC pkg_api_client.refresh_plants_from_api(:status, :msg);

-- Load issues for test plants
EXEC pkg_api_client.refresh_issues_from_api('124', :status, :msg);
EXEC pkg_api_client.refresh_issues_from_api('34', :status, :msg);

-- Check counts
SELECT COUNT(*) FROM PLANTS WHERE is_valid = 'Y';  -- Should be 130
SELECT COUNT(*) FROM ISSUES WHERE plant_id IN ('124','34');  -- Should be 20
```

## Additional Important Queries

### VDS Data Monitoring
```sql
-- Check VDS reference counts
SELECT COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y';

-- Check VDS details loaded
SELECT COUNT(*) FROM VDS_DETAILS;

-- VDS details for specific reference
SELECT * FROM VDS_DETAILS 
WHERE vds_name = 'your_vds_name' 
AND revision = 'your_revision';
```

### Reference Tables Overview
```sql
-- Count all references by type
SELECT 'PCS' as type, COUNT(*) as count FROM PCS_REFERENCES WHERE is_valid = 'Y'
UNION ALL SELECT 'VDS', COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y'
UNION ALL SELECT 'MDS', COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y'
UNION ALL SELECT 'PIPE_ELEMENT', COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
UNION ALL SELECT 'VSK', COUNT(*) FROM VSK_REFERENCES WHERE is_valid = 'Y'
UNION ALL SELECT 'EDS', COUNT(*) FROM EDS_REFERENCES WHERE is_valid = 'Y'
UNION ALL SELECT 'SC', COUNT(*) FROM SC_REFERENCES WHERE is_valid = 'Y'
UNION ALL SELECT 'VSM', COUNT(*) FROM VSM_REFERENCES WHERE is_valid = 'Y'
UNION ALL SELECT 'ESK', COUNT(*) FROM ESK_REFERENCES WHERE is_valid = 'Y';
```

## Current Database Status
- **Tables**: 30+ (including all reference and detail tables)
- **Views**: 15+ (monitoring and analysis views)  
- **Indexes**: 50+ (optimized with composite indexes)
- **Packages**: 20+ (full ETL pipeline)
- **Test Coverage**: ~85-90% (75 tests across 9 packages)
- **All Objects**: VALID ✅

---

*Last Updated: 2025-12-30 Session 18*
*Version: 2.0 - Updated with current architecture*