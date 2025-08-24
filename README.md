# TR2000 ETL System

## Overview
Pure Oracle APEX-based ETL system for TR2000 API data management with automated plant and issue processing.

## Key Features
- ✅ **APEX_WEB_SERVICE** integration with HTTPS (70% code reduction)
- ✅ **Oracle Database 21c** with complete ETL logic in PL/SQL
- ✅ **Automated ETL pipeline** with SHA256 deduplication
- ✅ **Real-time API integration** with TR2000 endpoints
- ✅ **Single source of truth** - Master_DDL.sql for all database objects
- ✅ **Pure Oracle solution** - No external dependencies

## Current Architecture
- **Database**: Oracle 21c XE with TR2000_STAGING schema
- **API Client**: APEX_WEB_SERVICE with Oracle wallet for HTTPS
- **ETL Logic**: PL/SQL packages (pkg_api_client, pkg_etl_operations, etc.)
- **UI**: Oracle APEX application (to be created)
- **Deployment**: Simple - just run Master_DDL.sql

## Prerequisites

- Oracle Database 21c XE
- Oracle APEX 24.2 (or compatible version)
- Oracle wallet configured for HTTPS
- Network access to `equinor.pipespec-api.presight.com`

## Quick Start

### 1. Database Setup
```sql
-- Connect as TR2000_STAGING user
sqlplus TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1

-- Run the master DDL script
@Database/Master_DDL.sql
```

### 2. APEX Application Setup
Follow `Database/APEX_QUICK_START.md`:
1. Create workspace TR2000_ETL
2. Create app from PLANTS table
3. Add ETL operations page
4. Configure buttons to call PL/SQL procedures

### 3. Access Application
```
URL: http://localhost:8080/apex
Workspace: TR2000_ETL
Username: TR2000_STAGING
Password: piping
```

## Project Structure

```
TR2K/
├── Database/
│   ├── Master_DDL.sql          # Complete database schema and procedures
│   ├── APEX_QUICK_START.md     # Guide for APEX setup
│   ├── scripts/
│   │   └── export_apex.sh      # Export APEX app for version control
│   ├── tools/
│   │   └── instantclient/      # Oracle SQL*Plus client
│   └── apex_exports/           # APEX application exports (when created)
└── Ops/
    └── Setup/
        ├── prd-tr2000-etl.md   # Product Requirements Document
        ├── tasks-tr2000-etl.md # Task tracking
        └── TR2000_API_Endpoints_Documentation.md # API reference
```

## Database Objects

### Core Tables
- `PLANTS` - Plant master data
- `ISSUES` - Issue revisions per plant  
- `SELECTION_LOADER` - User selections for ETL processing
- `RAW_JSON` - Raw API responses with SHA256 deduplication
- `ETL_RUN_LOG` - ETL execution history
- `ETL_ERROR_LOG` - Error tracking with context

### Key Packages
- `pkg_api_client` - APEX_WEB_SERVICE API calls
- `pkg_raw_ingest` - SHA256 deduplication and RAW_JSON management
- `pkg_parse_plants` - JSON parsing for plants endpoint
- `pkg_parse_issues` - JSON parsing for issues endpoint
- `pkg_etl_operations` - ETL orchestration

## Usage

### Manual ETL Operations (via SQL*Plus)
```sql
-- Refresh all plants
EXEC pkg_api_client.refresh_plants_from_api(:status, :message);

-- Refresh issues for a specific plant
EXEC pkg_api_client.refresh_issues_from_api('AAS', :status, :message);

-- Run full ETL
EXEC pkg_etl_operations.run_full_etl(:status, :message);
```

### Via APEX Application (when created)
1. Navigate to ETL Operations page
2. Select plants (max 10)
3. Select issue revisions
4. Click "Run ETL"
5. Monitor progress in execution log

## Version Control

- **Master_DDL.sql** is the single source of truth
- Git tracks all changes (no manual backups needed)
- Deployment is simple: just run Master_DDL.sql
- APEX exports tracked via export_apex.sh script

## Git Workflow

### Making Changes
```bash
# Edit Master_DDL.sql or other files
git add .
git commit -m "feat: Add new ETL procedure"

# Push when ready (not required for every commit)
git push origin master
```

### Database Deployment
```bash
# Connect to database
cd /workspace/TR2000/TR2K/Database
./tools/sqlplus_wrapper.sh

# Run the DDL
SQL> @Master_DDL.sql
```

## Status

- ✅ **Database Schema**: Complete
- ✅ **ETL Procedures**: Complete  
- ✅ **API Integration**: Working with HTTPS
- 🔄 **APEX UI**: To be created
- 📋 **Automation**: Post-project activity

## Next Steps

1. Create APEX application following APEX_QUICK_START.md
2. Test ETL operations through APEX UI
3. Export APEX app for version control
4. Schedule automation jobs (post-project)

---

Last Updated: August 23, 2025