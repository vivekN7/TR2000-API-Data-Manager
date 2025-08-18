# TR2000 Enhanced Database Table Structures

## Overview

This document provides complete documentation for the enhanced TR2000 database schema with **complete API field coverage**. The enhancement represents a transformation from basic ETL (20% field coverage) to comprehensive TR2000 engineering data warehouse (100% field coverage).

## Enhancement Summary

| Category | Before | After | Enhancement |
|----------|--------|-------|-------------|
| **OPERATORS** | 2 fields | 2 fields | ✅ Already complete |
| **PLANTS** | 5 fields | 24+ fields | 🚀 **380% increase** |
| **ISSUES** | 5 fields | 25+ fields | 🚀 **400% increase** |
| **Reference Tables** | Basic fields | Complete metadata | 🚀 **Enhanced with RevDate, Status, User audit** |
| **PCS Detail Tables** | 0 tables | 4 tables (100+ fields) | 🚀 **NEW: Complete engineering specifications** |

---

## **CONTROL TABLES**

### ETL_CONTROL
**Purpose**: Tracks all ETL runs and performance metrics

| Field | Type | Description |
|-------|------|-------------|
| ETL_RUN_ID | NUMBER (PK) | Unique run identifier (auto-generated) |
| RUN_TYPE | VARCHAR2(50) | Type of ETL run (OPERATORS, PLANTS, ISSUES, etc.) |
| STATUS | VARCHAR2(20) | 'RUNNING', 'SUCCESS', 'FAILED' |
| START_TIME | DATE | ETL run start timestamp |
| END_TIME | DATE | ETL run completion timestamp |
| PROCESSING_TIME_SEC | NUMBER | Total processing time in seconds |
| RECORDS_LOADED | NUMBER | Count of new records inserted |
| RECORDS_UPDATED | NUMBER | Count of records updated |
| RECORDS_UNCHANGED | NUMBER | Count of records with no changes |
| RECORDS_DELETED | NUMBER | Count of records soft-deleted |
| RECORDS_REACTIVATED | NUMBER | Count of deleted records reactivated |
| ERROR_COUNT | NUMBER | Total errors encountered |
| API_CALL_COUNT | NUMBER | Number of API calls made |
| COMMENTS | VARCHAR2(500) | Additional run information |

### ETL_ENDPOINT_LOG  
**Purpose**: Detailed logging of each API call

| Field | Type | Description |
|-------|------|-------------|
| LOG_ID | NUMBER (PK) | Unique log entry identifier |
| ETL_RUN_ID | NUMBER (FK) | Reference to ETL_CONTROL |
| ENDPOINT_NAME | VARCHAR2(100) | API endpoint called |
| PLANT_ID | VARCHAR2(50) | Plant context (if applicable) |
| API_URL | VARCHAR2(500) | Full API URL called |
| HTTP_STATUS | NUMBER | HTTP response status code |
| RECORDS_RETURNED | NUMBER | Number of records in response |
| LOAD_TIME_SECONDS | NUMBER(10,2) | API call duration |
| ERROR_MESSAGE | VARCHAR2(4000) | Error details (if any) |
| CREATED_DATE | DATE | Log entry timestamp |

### ETL_ERROR_LOG
**Purpose**: Persistent error logging (survives rollbacks via autonomous transactions)

| Field | Type | Description |
|-------|------|-------------|
| ERROR_ID | NUMBER (PK) | Unique error identifier |
| ETL_RUN_ID | NUMBER | ETL run context |
| ERROR_TIME | DATE | When error occurred |
| ERROR_SOURCE | VARCHAR2(100) | Component that generated error |
| ERROR_CODE | VARCHAR2(20) | Error classification code |
| ERROR_MESSAGE | VARCHAR2(4000) | Detailed error message |
| STACK_TRACE | CLOB | Full exception stack trace |
| RECORD_DATA | CLOB | Data being processed when error occurred |

### ETL_PLANT_LOADER
**Purpose**: Scope control - defines which plants to process

| Field | Type | Description |
|-------|------|-------------|
| PLANT_ID | VARCHAR2(50) (PK) | Plant identifier |
| PLANT_NAME | VARCHAR2(200) | Plant display name |
| IS_ACTIVE | CHAR(1) | 'Y'/'N' - active for processing |
| LOAD_PRIORITY | NUMBER | Processing order (default: 100) |
| NOTES | VARCHAR2(500) | User notes about plant |
| CREATED_DATE | DATE | When plant was added to loader |
| CREATED_BY | VARCHAR2(100) | User who added plant |
| MODIFIED_DATE | DATE | Last modification timestamp |
| MODIFIED_BY | VARCHAR2(100) | User who last modified |

### ETL_ISSUE_LOADER
**Purpose**: Scope control for reference tables - defines which issues to load references for

| Field | Type | Description |
|-------|------|-------------|
| PLANT_ID | VARCHAR2(50) (PK) | Plant identifier |
| ISSUE_REVISION | VARCHAR2(20) (PK) | Issue revision identifier |
| PLANT_NAME | VARCHAR2(200) | Plant display name |
| CREATED_DATE | DATE | When issue was added to loader |

**Key**: Presence in this table = load references. Cascades when plant removed from ETL_PLANT_LOADER.

### ETL_RECONCILIATION
**Purpose**: Data quality validation and count verification

| Field | Type | Description |
|-------|------|-------------|
| ETL_RUN_ID | NUMBER (PK) | ETL run reference |
| ENTITY_TYPE | VARCHAR2(50) (PK) | 'OPERATORS', 'PLANTS', 'ISSUES', etc. |
| SOURCE_COUNT | NUMBER | Count from API source |
| TARGET_COUNT | NUMBER | Count in database after ETL |
| DIFF_COUNT | NUMBER | Difference (should be 0) |
| CHECK_TIME | DATE | When reconciliation was performed |

---

## **STAGING TABLES** (Complete Field Coverage)

All staging tables include standard ETL control fields:
- `STG_ID` (NUMBER, IDENTITY) - Deterministic deduplication key
- `ETL_RUN_ID` (NUMBER) - Batch tracking
- `IS_DUPLICATE` (CHAR(1)) - Deduplication flag
- `IS_VALID` (CHAR(1)) - Validation flag  
- `VALIDATION_ERROR` (VARCHAR2(500)) - Error details
- `PROCESSED_FLAG` (CHAR(1)) - Processing status

### STG_OPERATORS
**Purpose**: Staging for operator data (unchanged - already minimal)

| Field | Type | Description |
|-------|------|-------------|
| OPERATOR_ID | NUMBER | Primary operator identifier |
| OPERATOR_NAME | VARCHAR2(200) | Company/operator name |
| *(+ Standard ETL fields)* | | |

### STG_PLANTS (Enhanced: 5 → 24+ Fields)
**Purpose**: Staging for complete plant configuration data

#### Core Plant Fields
| Field | Type | Description |
|-------|------|-------------|
| OPERATOR_ID | NUMBER | Owner operator |
| OPERATOR_NAME | VARCHAR2(200) | Operator company name |
| PLANT_ID | VARCHAR2(50) | Primary plant identifier |
| SHORT_DESCRIPTION | VARCHAR2(200) | Brief plant name |
| PROJECT | VARCHAR2(200) | Associated project |
| LONG_DESCRIPTION | VARCHAR2(500) | Detailed plant description |
| COMMON_LIB_PLANT_CODE | VARCHAR2(50) | Standard library reference |
| INITIAL_REVISION | VARCHAR2(50) | First revision marker |
| AREA_ID | NUMBER | Geographic/operational area ID |
| AREA | VARCHAR2(200) | Area description |

#### **NEW** Extended Plant Configuration Fields
| Field | Type | Description |
|-------|------|-------------|
| ENABLE_EMBEDDED_NOTE | VARCHAR2(10) | Allow embedded documentation |
| CATEGORY_ID | VARCHAR2(50) | Plant classification ID |
| CATEGORY | VARCHAR2(200) | Plant classification |
| DOCUMENT_SPACE_LINK | VARCHAR2(500) | External documentation URL |
| ENABLE_COPY_PCS_FROM_PLANT | VARCHAR2(10) | PCS inheritance permission |
| OVER_LENGTH | VARCHAR2(50) | Over-length pipe specification |
| PCS_QA | VARCHAR2(50) | PCS quality assurance level |
| EDS_MJ | VARCHAR2(50) | Equipment datasheet major joint setting |
| CELSIUS_BAR | VARCHAR2(50) | Temperature/pressure unit system |
| WEB_INFO_TEXT | CLOB | Web portal information |
| BOLT_TENSION_TEXT | CLOB | Bolt tension specifications |
| VISIBLE | VARCHAR2(10) | System visibility flag |
| WINDOWS_REMARK_TEXT | CLOB | Windows application remarks |
| USER_PROTECTED | VARCHAR2(20) | User protection level |

### STG_ISSUES (Enhanced: 5 → 25+ Fields)  
**Purpose**: Staging for complete issue revision tracking

#### Core Issue Fields
| Field | Type | Description |
|-------|------|-------------|
| PLANT_ID | VARCHAR2(50) | Associated plant |
| ISSUE_REVISION | VARCHAR2(20) | Issue revision identifier |
| STATUS | VARCHAR2(50) | Issue status (Active, Withdrawn, etc.) |
| REV_DATE | VARCHAR2(50) | Revision date (API format) |
| PROTECT_STATUS | VARCHAR2(50) | Protection level |

#### **NEW** General Revision Tracking
| Field | Type | Description |
|-------|------|-------------|
| GENERAL_REVISION | VARCHAR2(50) | Overall revision number |
| GENERAL_REV_DATE | VARCHAR2(50) | General revision date |

#### **NEW** Component-Specific Revision Matrix (16 fields)
| Component | Revision Field | Date Field |
|-----------|----------------|------------|
| **PCS** | PCS_REVISION | PCS_REV_DATE |
| **EDS** | EDS_REVISION | EDS_REV_DATE |
| **VDS** | VDS_REVISION | VDS_REV_DATE |
| **VSK** | VSK_REVISION | VSK_REV_DATE |
| **MDS** | MDS_REVISION | MDS_REV_DATE |
| **ESK** | ESK_REVISION | ESK_REV_DATE |
| **SC** | SC_REVISION | SC_REV_DATE |
| **VSM** | VSM_REVISION | VSM_REV_DATE |

#### **NEW** User Audit Fields
| Field | Type | Description |
|-------|------|-------------|
| USER_NAME | VARCHAR2(100) | User who created/modified issue |
| USER_ENTRY_TIME | DATE | Entry timestamp |
| USER_PROTECTED | VARCHAR2(20) | User-level protection |

---

## **REFERENCE TABLES STAGING** (All Enhanced with Complete Metadata)

All reference staging tables now include **enhanced metadata fields**:

### Common Enhanced Pattern
**Before (Basic)**: Name, Revision  
**After (Enhanced)**: Name, Revision, **RevDate, Status, OfficialRevision, Delta, UserName, UserEntryTime, UserProtected**

### STG_PCS_REFERENCES
| Field | Type | Description |
|-------|------|-------------|
| PLANT_ID | VARCHAR2(50) | Associated plant |
| ISSUE_REVISION | VARCHAR2(20) | Issue context |
| PCS_NAME | VARCHAR2(100) | PCS identifier |
| PCS_REVISION | VARCHAR2(20) | PCS revision |
| **REV_DATE** | VARCHAR2(50) | **NEW**: Revision date |
| **STATUS** | VARCHAR2(50) | **NEW**: Document status |
| **OFFICIAL_REVISION** | VARCHAR2(20) | **NEW**: Official revision marker |
| **REVISION_SUFFIX** | VARCHAR2(20) | **NEW**: Revision suffix |
| **RATING_CLASS** | VARCHAR2(50) | **NEW**: Pressure rating |
| **MATERIAL_GROUP** | VARCHAR2(100) | **NEW**: Material classification |
| **HISTORICAL_PCS** | VARCHAR2(100) | **NEW**: Historical reference |
| **DELTA** | VARCHAR2(50) | **NEW**: Change indicator |
| **USER_NAME** | VARCHAR2(100) | **NEW**: User audit |
| **USER_ENTRY_TIME** | DATE | **NEW**: Entry timestamp |
| **USER_PROTECTED** | VARCHAR2(20) | **NEW**: User protection |

### STG_VDS_REFERENCES, STG_EDS_REFERENCES, STG_VSK_REFERENCES, STG_ESK_REFERENCES  
**Pattern**: Same enhanced metadata as PCS but with component-specific names (VDS_NAME, EDS_NAME, etc.)

### STG_SC_REFERENCES, STG_VSM_REFERENCES
**Pattern**: Same enhanced metadata as above

### STG_MDS_REFERENCES (Special Case)
**Additional Field**: `AREA` (VARCHAR2(50)) - Material area specification

### STG_PIPE_ELEMENT_REFERENCES (Different Structure)
| Field | Type | Description |
|-------|------|-------------|
| PLANT_ID | VARCHAR2(50) | Associated plant |
| ISSUE_REVISION | VARCHAR2(20) | Issue context |
| **ELEMENT_GROUP** | VARCHAR2(100) | **NEW**: Element classification |
| **DIMENSION_STANDARD** | VARCHAR2(100) | **NEW**: Dimensional standard |
| **PRODUCT_FORM** | VARCHAR2(100) | **NEW**: Product form |
| **MATERIAL_GRADE** | VARCHAR2(100) | **NEW**: Material specification |
| **MDS** | VARCHAR2(100) | **NEW**: Material datasheet reference |
| **MDS_REVISION** | VARCHAR2(20) | **NEW**: MDS revision |
| **AREA** | VARCHAR2(50) | **NEW**: Area specification |
| **ELEMENT_ID** | NUMBER | **NEW**: Unique element identifier |
| REVISION | VARCHAR2(20) | Element revision |
| REV_DATE | VARCHAR2(50) | Revision date |
| STATUS | VARCHAR2(50) | Element status |
| DELTA | VARCHAR2(50) | Change indicator |
| *(+ User audit fields)* | | |

---

## **NEW PCS DETAIL STAGING TABLES** (100+ Engineering Fields)

### STG_PCS_HEADER (15+ Fields)
**Purpose**: Complete PCS properties and metadata

| Field | Type | Description |
|-------|------|-------------|
| PLANT_ID | VARCHAR2(50) | Associated plant |
| PCS_NAME | VARCHAR2(100) | PCS identifier |
| PCS_REVISION | VARCHAR2(20) | PCS revision |
| STATUS | VARCHAR2(50) | Document status |
| REV_DATE | VARCHAR2(50) | Revision date |
| RATING_CLASS | VARCHAR2(50) | Pressure rating classification |
| TEST_PRESSURE | VARCHAR2(50) | Test pressure specification |
| MATERIAL_GROUP | VARCHAR2(100) | Material group classification |
| DESIGN_CODE | VARCHAR2(100) | Applicable design code |
| LAST_UPDATE | VARCHAR2(50) | Last modification date |
| LAST_UPDATE_BY | VARCHAR2(100) | User who last modified |
| APPROVER | VARCHAR2(100) | Approving engineer |
| NOTEPAD | CLOB | Engineering notes |
| SPECIAL_REQ_ID | NUMBER | Special requirements reference |
| TUBE_PCS | VARCHAR2(100) | Tube PCS reference |
| NEW_VDS_SECTION | VARCHAR2(100) | VDS section reference |

### STG_PCS_TEMP_PRESSURE (70+ Fields)
**Purpose**: Complete temperature/pressure engineering matrix

#### Base Engineering Fields
| Field | Type | Description |
|-------|------|-------------|
| *(Base fields from PCS_HEADER)* | | |
| SC | VARCHAR2(100) | Special component reference |
| VSM | VARCHAR2(100) | Valve specification manual |
| DESIGN_CODE_REV_MARK | VARCHAR2(50) | Design code revision marker |
| CORR_ALLOWANCE | NUMBER | Corrosion allowance value |
| CORR_ALLOWANCE_REV_MARK | VARCHAR2(50) | Corrosion allowance revision |
| LONG_WELD_EFF | VARCHAR2(50) | Longitudinal weld efficiency |
| LONG_WELD_EFF_REV_MARK | VARCHAR2(50) | Weld efficiency revision |
| WALL_THK_TOL | VARCHAR2(50) | Wall thickness tolerance |
| WALL_THK_TOL_REV_MARK | VARCHAR2(50) | Thickness tolerance revision |
| SERVICE_REMARK | CLOB | Service condition remarks |
| SERVICE_REMARK_REV_MARK | VARCHAR2(50) | Service remark revision |

#### **NEW** Design Pressure Matrix (12 pressure points)
| Field | Type | Description |
|-------|------|-------------|
| DESIGN_PRESS_01 through DESIGN_PRESS_12 | VARCHAR2(50) | Design pressure at different temperatures |
| DESIGN_PRESS_REV_MARK | VARCHAR2(50) | Pressure matrix revision marker |

#### **NEW** Design Temperature Matrix (12 temperature points)
| Field | Type | Description |
|-------|------|-------------|
| DESIGN_TEMP_01 through DESIGN_TEMP_12 | VARCHAR2(50) | Design temperature values |
| DESIGN_TEMP_REV_MARK | VARCHAR2(50) | Temperature matrix revision marker |

#### **NEW** Engineering Note IDs (8 references)
| Field | Type | Description |
|-------|------|-------------|
| NOTE_ID_CORR_ALLOWANCE | VARCHAR2(50) | Corrosion allowance note reference |
| NOTE_ID_SERVICE_CODE | VARCHAR2(50) | Service code note reference |
| NOTE_ID_WALL_THK_TOL | VARCHAR2(50) | Wall thickness note reference |
| NOTE_ID_LONG_WELD_EFF | VARCHAR2(50) | Weld efficiency note reference |
| NOTE_ID_GENERAL_PCS | VARCHAR2(50) | General PCS note reference |
| NOTE_ID_DESIGN_CODE | VARCHAR2(50) | Design code note reference |
| NOTE_ID_PRESS_TEMP_TABLE | VARCHAR2(50) | Pressure/temp table note |
| NOTE_ID_PIPE_SIZE_WTH_TABLE | VARCHAR2(50) | Pipe size table note |

#### **NEW** Additional Engineering Parameters
| Field | Type | Description |
|-------|------|-------------|
| PRESS_ELEMENT_CHANGE | VARCHAR2(50) | Pressure element change indicator |
| TEMP_ELEMENT_CHANGE | VARCHAR2(50) | Temperature element change indicator |
| MATERIAL_GROUP_ID | NUMBER | Material group identifier |
| SPECIAL_REQ_ID | NUMBER | Special requirements ID |
| SPECIAL_REQ | VARCHAR2(200) | Special requirements description |
| NEW_VDS_SECTION | VARCHAR2(100) | New VDS section reference |
| TUBE_PCS | VARCHAR2(100) | Tube PCS reference |
| EDS_MJ_MATRIX | VARCHAR2(50) | EDS major joint matrix |
| MJ_REDUCTION_FACTOR | NUMBER | Major joint reduction factor |

### STG_PCS_PIPE_SIZES (11 Fields)
**Purpose**: Pipe sizing specifications

| Field | Type | Description |
|-------|------|-------------|
| PLANT_ID | VARCHAR2(50) | Associated plant |
| PCS_NAME | VARCHAR2(100) | PCS identifier |
| PCS_REVISION | VARCHAR2(20) | PCS revision |
| NOM_SIZE | VARCHAR2(50) | Nominal pipe size |
| OUTER_DIAM | VARCHAR2(50) | Outer diameter specification |
| WALL_THICKNESS | VARCHAR2(50) | Wall thickness specification |
| SCHEDULE | VARCHAR2(50) | Pipe schedule |
| UNDER_TOLERANCE | VARCHAR2(50) | Under-tolerance specification |
| CORROSION_ALLOWANCE | VARCHAR2(50) | Corrosion allowance |
| WELDING_FACTOR | VARCHAR2(50) | Welding factor |
| DIM_ELEMENT_CHANGE | VARCHAR2(50) | Dimensional element change |
| SCHEDULE_IN_MATRIX | VARCHAR2(50) | Schedule matrix inclusion |

### STG_PCS_PIPE_ELEMENTS (25+ Fields)
**Purpose**: Detailed pipe element specifications

| Field | Type | Description |
|-------|------|-------------|
| PLANT_ID | VARCHAR2(50) | Associated plant |
| PCS_NAME | VARCHAR2(100) | PCS identifier |  
| PCS_REVISION | VARCHAR2(20) | PCS revision |
| MATERIAL_GROUP_ID | NUMBER | Material group identifier |
| ELEMENT_GROUP_NO | NUMBER | Element group number |
| LINE_NO | NUMBER | Line number |
| ELEMENT | VARCHAR2(200) | Element description |
| DIM_STANDARD | VARCHAR2(100) | Dimensional standard |
| FROM_SIZE | VARCHAR2(50) | Starting size |
| TO_SIZE | VARCHAR2(50) | Ending size |
| PRODUCT_FORM | VARCHAR2(100) | Product form specification |
| MATERIAL | VARCHAR2(200) | Material specification |
| MDS | VARCHAR2(100) | Material datasheet reference |
| EDS | VARCHAR2(100) | Equipment datasheet reference |
| EDS_REVISION | VARCHAR2(20) | EDS revision |
| ESK | VARCHAR2(100) | Equipment spares kit reference |
| REVMARK | VARCHAR2(50) | Revision marker |
| REMARK | CLOB | Engineering remarks |
| PAGE_BREAK | VARCHAR2(10) | Page break indicator |
| ELEMENT_GROUP | VARCHAR2(100) | Element group classification |
| MATL_IN_MATRIX | VARCHAR2(10) | Material in matrix flag |
| PARENT_ELEMENT | VARCHAR2(200) | Parent element reference |
| ITEM_CODE | VARCHAR2(100) | Item code |
| MDS_REVISION | VARCHAR2(20) | MDS revision |

---

## **DIMENSION TABLES** (Complete SCD2 Implementation)

All dimension tables include **complete SCD2 temporal tracking**:

### Standard SCD2 Fields
| Field | Type | Description |
|-------|------|-------------|
| SRC_HASH | RAW(32) | Oracle STANDARD_HASH for change detection |
| VALID_FROM | DATE | When record became active |
| VALID_TO | DATE | When record became inactive |
| IS_CURRENT | CHAR(1) | 'Y'/'N' - current record flag |
| CHANGE_TYPE | VARCHAR2(20) | 'INSERT', 'UPDATE', 'DELETE', 'REACTIVATE' |
| DELETE_DATE | DATE | When deleted from source |
| ETL_RUN_ID | NUMBER | Audit trail |

### OPERATORS (Unchanged)
**Purpose**: Operator master data (already complete)

| Field | Type | Description |
|-------|------|-------------|
| OPERATOR_ID | NUMBER | Primary identifier |
| OPERATOR_NAME | VARCHAR2(200) | Company name |
| *(+ Standard SCD2 fields)* | | |

### PLANTS (Enhanced: 5 → 24+ Fields)
**Purpose**: Complete plant master data with full configuration

#### Core Plant Fields  
| Field | Type | Description |
|-------|------|-------------|
| OPERATOR_ID | NUMBER | Owner operator |
| OPERATOR_NAME | VARCHAR2(200) | Operator company |
| PLANT_ID | VARCHAR2(50) | Primary identifier |
| SHORT_DESCRIPTION | VARCHAR2(200) | Brief name |
| PROJECT | VARCHAR2(200) | Associated project |
| LONG_DESCRIPTION | VARCHAR2(500) | Detailed description |
| COMMON_LIB_PLANT_CODE | VARCHAR2(50) | Library reference |
| INITIAL_REVISION | VARCHAR2(50) | First revision |
| AREA_ID | NUMBER | Area identifier |
| AREA | VARCHAR2(200) | Area description |

#### **NEW** Extended Plant Configuration (14 additional fields)
| Field | Type | Description |
|-------|------|-------------|
| ENABLE_EMBEDDED_NOTE | VARCHAR2(10) | Embedded notes permission |
| CATEGORY_ID | VARCHAR2(50) | Plant category ID |
| CATEGORY | VARCHAR2(200) | Plant category |
| DOCUMENT_SPACE_LINK | VARCHAR2(500) | Documentation URL |
| ENABLE_COPY_PCS_FROM_PLANT | VARCHAR2(10) | PCS copy permission |
| OVER_LENGTH | VARCHAR2(50) | Over-length specification |
| PCS_QA | VARCHAR2(50) | PCS QA level |
| EDS_MJ | VARCHAR2(50) | EDS major joint setting |
| CELSIUS_BAR | VARCHAR2(50) | Unit system |
| WEB_INFO_TEXT | CLOB | Web information |
| BOLT_TENSION_TEXT | CLOB | Bolt tension specs |
| VISIBLE | VARCHAR2(10) | Visibility flag |
| WINDOWS_REMARK_TEXT | CLOB | Windows remarks |
| USER_PROTECTED | VARCHAR2(20) | Protection level |

### ISSUES (Enhanced: 5 → 25+ Fields)
**Purpose**: Complete issue revision tracking with component-specific revisions

#### Core Issue Fields
| Field | Type | Description |
|-------|------|-------------|
| PLANT_ID | VARCHAR2(50) | Associated plant |
| ISSUE_REVISION | VARCHAR2(20) | Issue identifier |
| STATUS | VARCHAR2(50) | Issue status |
| REV_DATE | DATE | Revision date (converted) |
| PROTECT_STATUS | VARCHAR2(50) | Protection status |

#### **NEW** General Revision Tracking
| Field | Type | Description |
|-------|------|-------------|
| GENERAL_REVISION | VARCHAR2(50) | General revision number |
| GENERAL_REV_DATE | DATE | General revision date |

#### **NEW** Component Revision Matrix (16 fields)
Complete tracking of all component revisions and dates:
- PCS_REVISION, PCS_REV_DATE
- EDS_REVISION, EDS_REV_DATE  
- VDS_REVISION, VDS_REV_DATE
- VSK_REVISION, VSK_REV_DATE
- MDS_REVISION, MDS_REV_DATE
- ESK_REVISION, ESK_REV_DATE
- SC_REVISION, SC_REV_DATE
- VSM_REVISION, VSM_REV_DATE

#### **NEW** User Audit Fields
| Field | Type | Description |
|-------|------|-------------|
| USER_NAME | VARCHAR2(100) | User who created/modified |
| USER_ENTRY_TIME | DATE | Entry timestamp |
| USER_PROTECTED | VARCHAR2(20) | User protection level |

---

## **ENHANCED REFERENCE DIMENSION TABLES**

All reference tables now include **complete metadata and user audit fields**:

### Common Enhanced Pattern
**Before**: Name, Revision  
**After**: Name, Revision, **RevDate, Status, OfficialRevision, Delta, UserName, UserEntryTime, UserProtected**

### PCS_REFERENCES, SC_REFERENCES, VSM_REFERENCES, VDS_REFERENCES, EDS_REFERENCES, VSK_REFERENCES, ESK_REFERENCES
**Pattern**: All follow same enhanced structure with component-specific naming

### MDS_REFERENCES (Special Case)
**Additional Field**: `AREA` (VARCHAR2(50)) - Material area specification

### PIPE_ELEMENT_REFERENCES (Different Structure)
**Enhanced Engineering Fields**:
- ELEMENT_GROUP, DIMENSION_STANDARD, PRODUCT_FORM, MATERIAL_GRADE
- MDS, MDS_REVISION, AREA, ELEMENT_ID
- Complete revision and user audit tracking

---

## **NEW PCS DETAIL DIMENSION TABLES** (100+ Engineering Fields)

### PCS_HEADER
**Purpose**: Complete PCS properties with SCD2 tracking

All fields from STG_PCS_HEADER plus complete SCD2 implementation.

### PCS_TEMP_PRESSURE  
**Purpose**: Complete temperature/pressure engineering matrix with SCD2

#### Enhanced Data Types for Engineering Calculations
| Field | Type | Description |
|-------|------|-------------|
| DESIGN_PRESS_01 through DESIGN_PRESS_12 | NUMBER(10,2) | **Numeric** design pressures |
| DESIGN_TEMP_01 through DESIGN_TEMP_12 | NUMBER(10,2) | **Numeric** design temperatures |
| CORR_ALLOWANCE | NUMBER | **Numeric** corrosion allowance |
| *(+ All other fields from staging)* | | |

### PCS_PIPE_SIZES
**Purpose**: Pipe sizing with engineering precision

#### Enhanced Data Types for Engineering Calculations
| Field | Type | Description |
|-------|------|-------------|
| OUTER_DIAM | NUMBER(10,3) | **Precise** outer diameter |
| WALL_THICKNESS | NUMBER(10,3) | **Precise** wall thickness |
| UNDER_TOLERANCE | NUMBER(10,3) | **Precise** tolerance |
| CORROSION_ALLOWANCE | NUMBER(10,3) | **Precise** corrosion allowance |
| WELDING_FACTOR | NUMBER(5,3) | **Precise** welding factor |
| *(+ Other fields)* | | |

### PCS_PIPE_ELEMENTS
**Purpose**: Complete pipe element specifications with SCD2

All fields from STG_PCS_PIPE_ELEMENTS with complete SCD2 temporal tracking.

---

## **Key Enhancements Summary**

### 1. **Complete API Field Coverage (Session 20 Breakthrough)**
- **PLANTS**: 5 → 24+ fields (380% increase)
- **ISSUES**: 5 → 25+ fields (400% increase) 
- **All Reference Tables**: Enhanced with complete metadata
- **4 New PCS Tables**: 100+ detailed engineering fields

### 2. **Enhanced Data Quality**
- **User Audit Fields**: UserName, UserEntryTime, UserProtected on all entities
- **Complete Revision Tracking**: RevDate, Status, OfficialRevision, Delta
- **Engineering Data Types**: Proper NUMBER types for calculations

### 3. **Complete SCD2 Implementation**
- **Full Temporal Tracking**: VALID_FROM, VALID_TO, IS_CURRENT
- **Change Type Logging**: INSERT, UPDATE, DELETE, REACTIVATE
- **Oracle Native Hashing**: STANDARD_HASH for change detection

### 4. **Engineering Data Warehouse Capabilities**
- **Temperature/Pressure Matrix**: 12-point engineering calculations
- **Pipe Specifications**: Precise dimensional data
- **Material Tracking**: Complete material and datasheet references
- **Note References**: Traceability for all engineering decisions

---

## **Business Impact**

### Before Enhancement
- **Basic ETL**: ~20% field coverage
- **Minimal Engineering Data**: Name/revision only
- **Limited Analysis**: Basic reporting only

### After Enhancement  
- **Complete Data Warehouse**: 100% field coverage
- **Full Engineering Specifications**: Design pressures, temperatures, materials
- **Advanced Analytics**: Complete audit trails, revision matrices, engineering calculations
- **Comprehensive Integration**: All fields available for downstream engineering systems

---

*This enhancement transforms the TR2000 system from a basic ETL tool into a comprehensive engineering data warehouse with complete TR2000 API field coverage and full audit capabilities.*