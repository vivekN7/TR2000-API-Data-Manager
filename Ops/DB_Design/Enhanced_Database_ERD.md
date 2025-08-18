# TR2000 Enhanced Database ERD & Visual Diagrams

## Overview

This document provides visual representations of the enhanced TR2000 database schema with complete field coverage. The diagrams show the transformation from basic ETL to comprehensive engineering data warehouse.

---

## **Complete Enhanced Database Schema**

```mermaid
erDiagram
    %% Control Tables
    ETL_CONTROL ||--o{ ETL_ENDPOINT_LOG : "tracks"
    ETL_CONTROL ||--o{ ETL_RECONCILIATION : "validates"
    ETL_PLANT_LOADER ||--o{ ETL_ISSUE_LOADER : "cascades"
    
    %% Master Data Flow
    STG_OPERATORS ||--|| OPERATORS : "processes_to"
    STG_PLANTS ||--|| PLANTS : "processes_to" 
    STG_ISSUES ||--|| ISSUES : "processes_to"
    
    %% Reference Data Flow
    STG_PCS_REFERENCES ||--|| PCS_REFERENCES : "processes_to"
    STG_SC_REFERENCES ||--|| SC_REFERENCES : "processes_to"
    STG_VSM_REFERENCES ||--|| VSM_REFERENCES : "processes_to"
    STG_VDS_REFERENCES ||--|| VDS_REFERENCES : "processes_to"
    STG_EDS_REFERENCES ||--|| EDS_REFERENCES : "processes_to"
    STG_MDS_REFERENCES ||--|| MDS_REFERENCES : "processes_to"
    STG_VSK_REFERENCES ||--|| VSK_REFERENCES : "processes_to"
    STG_ESK_REFERENCES ||--|| ESK_REFERENCES : "processes_to"
    STG_PIPE_ELEMENT_REFERENCES ||--|| PIPE_ELEMENT_REFERENCES : "processes_to"
    
    %% NEW PCS Detail Tables
    STG_PCS_HEADER ||--|| PCS_HEADER : "processes_to"
    STG_PCS_TEMP_PRESSURE ||--|| PCS_TEMP_PRESSURE : "processes_to"
    STG_PCS_PIPE_SIZES ||--|| PCS_PIPE_SIZES : "processes_to"
    STG_PCS_PIPE_ELEMENTS ||--|| PCS_PIPE_ELEMENTS : "processes_to"
    
    %% Core Relationships
    OPERATORS ||--o{ PLANTS : "owns"
    PLANTS ||--o{ ISSUES : "has"
    ISSUES ||--o{ PCS_REFERENCES : "references"
    ISSUES ||--o{ VDS_REFERENCES : "references"
    ISSUES ||--o{ EDS_REFERENCES : "references"
    ISSUES ||--o{ MDS_REFERENCES : "references"
    ISSUES ||--o{ VSK_REFERENCES : "references"
    ISSUES ||--o{ ESK_REFERENCES : "references"
    ISSUES ||--o{ SC_REFERENCES : "references"
    ISSUES ||--o{ VSM_REFERENCES : "references"
    ISSUES ||--o{ PIPE_ELEMENT_REFERENCES : "references"
    
    %% Control Table Definitions
    ETL_CONTROL {
        NUMBER ETL_RUN_ID PK
        VARCHAR2-50 RUN_TYPE
        VARCHAR2-20 STATUS
        DATE START_TIME
        DATE END_TIME
        NUMBER PROCESSING_TIME_SEC
        NUMBER RECORDS_LOADED
        NUMBER RECORDS_UPDATED
        NUMBER RECORDS_UNCHANGED
        NUMBER RECORDS_DELETED
        NUMBER RECORDS_REACTIVATED
        NUMBER ERROR_COUNT
        NUMBER API_CALL_COUNT
        VARCHAR2-500 COMMENTS
    }
    
    ETL_PLANT_LOADER {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-200 PLANT_NAME
        CHAR-1 IS_ACTIVE
        NUMBER LOAD_PRIORITY
        VARCHAR2-500 NOTES
        DATE CREATED_DATE
        VARCHAR2-100 CREATED_BY
        DATE MODIFIED_DATE  
        VARCHAR2-100 MODIFIED_BY
    }
    
    ETL_ISSUE_LOADER {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-20 ISSUE_REVISION PK
        VARCHAR2-200 PLANT_NAME
        DATE CREATED_DATE
    }
    
    %% Enhanced Master Tables
    OPERATORS {
        NUMBER OPERATOR_ID PK
        VARCHAR2-200 OPERATOR_NAME
        RAW-32 SRC_HASH
        DATE VALID_FROM PK
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
    
    PLANTS {
        VARCHAR2-50 PLANT_ID PK
        DATE VALID_FROM PK
        NUMBER OPERATOR_ID
        VARCHAR2-200 OPERATOR_NAME
        VARCHAR2-200 SHORT_DESCRIPTION
        VARCHAR2-200 PROJECT
        VARCHAR2-500 LONG_DESCRIPTION
        VARCHAR2-50 COMMON_LIB_PLANT_CODE
        VARCHAR2-50 INITIAL_REVISION
        NUMBER AREA_ID
        VARCHAR2-200 AREA
        VARCHAR2-10 ENABLE_EMBEDDED_NOTE "NEW"
        VARCHAR2-50 CATEGORY_ID "NEW"
        VARCHAR2-200 CATEGORY "NEW"
        VARCHAR2-500 DOCUMENT_SPACE_LINK "NEW"
        VARCHAR2-10 ENABLE_COPY_PCS_FROM_PLANT "NEW"
        VARCHAR2-50 OVER_LENGTH "NEW"
        VARCHAR2-50 PCS_QA "NEW"
        VARCHAR2-50 EDS_MJ "NEW"
        VARCHAR2-50 CELSIUS_BAR "NEW"
        CLOB WEB_INFO_TEXT "NEW"
        CLOB BOLT_TENSION_TEXT "NEW"
        VARCHAR2-10 VISIBLE "NEW"
        CLOB WINDOWS_REMARK_TEXT "NEW"
        VARCHAR2-20 USER_PROTECTED "NEW"
        RAW-32 SRC_HASH
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
    
    ISSUES {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-20 ISSUE_REVISION PK
        DATE VALID_FROM PK
        VARCHAR2-50 STATUS
        DATE REV_DATE
        VARCHAR2-50 PROTECT_STATUS
        VARCHAR2-50 GENERAL_REVISION "NEW"
        DATE GENERAL_REV_DATE "NEW"
        VARCHAR2-50 PCS_REVISION "NEW"
        DATE PCS_REV_DATE "NEW"
        VARCHAR2-50 EDS_REVISION "NEW"
        DATE EDS_REV_DATE "NEW"
        VARCHAR2-50 VDS_REVISION "NEW"
        DATE VDS_REV_DATE "NEW"
        VARCHAR2-50 VSK_REVISION "NEW"
        DATE VSK_REV_DATE "NEW"
        VARCHAR2-50 MDS_REVISION "NEW"
        DATE MDS_REV_DATE "NEW"
        VARCHAR2-50 ESK_REVISION "NEW"
        DATE ESK_REV_DATE "NEW"
        VARCHAR2-50 SC_REVISION "NEW"
        DATE SC_REV_DATE "NEW"
        VARCHAR2-50 VSM_REVISION "NEW"
        DATE VSM_REV_DATE "NEW"
        VARCHAR2-100 USER_NAME "NEW"
        DATE USER_ENTRY_TIME "NEW"
        VARCHAR2-20 USER_PROTECTED "NEW"
        RAW-32 SRC_HASH
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
```

---

## **SCD2 Temporal Structure Visualization**

```mermaid
graph TD
    A[API Source Data] --> B[Staging Table]
    B --> C{Data Changed?}
    C -->|Yes| D[Create New Version]
    C -->|No| E[Mark Unchanged]
    D --> F[Set Old Version VALID_TO]
    D --> G[Set New Version IS_CURRENT='Y']
    F --> H[Complete SCD2 Record]
    G --> H
    E --> H
    
    subgraph "SCD2 Record Structure"
        H --> I[VALID_FROM: Record start date]
        H --> J[VALID_TO: Record end date or NULL]
        H --> K[IS_CURRENT: Y/N flag]
        H --> L[CHANGE_TYPE: INSERT/UPDATE/DELETE/REACTIVATE]
        H --> M[SRC_HASH: Change detection]
        H --> N[ETL_RUN_ID: Audit trail]
    end
    
    style D fill:#90EE90
    style F fill:#FFB6C1
    style G fill:#87CEEB
```

---

## **Enhanced Reference Tables Structure**

```mermaid
erDiagram
    %% Core Reference Pattern
    ISSUES ||--o{ PCS_REFERENCES : "references"
    ISSUES ||--o{ VDS_REFERENCES : "references"
    ISSUES ||--o{ EDS_REFERENCES : "references"
    ISSUES ||--o{ MDS_REFERENCES : "references"
    ISSUES ||--o{ VSK_REFERENCES : "references"
    ISSUES ||--o{ ESK_REFERENCES : "references"
    ISSUES ||--o{ SC_REFERENCES : "references"
    ISSUES ||--o{ VSM_REFERENCES : "references"
    ISSUES ||--o{ PIPE_ELEMENT_REFERENCES : "references"
    
    %% Enhanced Reference Table Pattern
    PCS_REFERENCES {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-20 ISSUE_REVISION PK
        VARCHAR2-100 PCS_NAME PK
        VARCHAR2-20 PCS_REVISION PK
        DATE VALID_FROM PK
        DATE REV_DATE "ENHANCED"
        VARCHAR2-50 STATUS "ENHANCED"
        VARCHAR2-20 OFFICIAL_REVISION "ENHANCED"
        VARCHAR2-20 REVISION_SUFFIX "ENHANCED"
        VARCHAR2-50 RATING_CLASS "ENHANCED"
        VARCHAR2-100 MATERIAL_GROUP "ENHANCED"
        VARCHAR2-100 HISTORICAL_PCS "ENHANCED"
        VARCHAR2-50 DELTA "ENHANCED"
        VARCHAR2-100 USER_NAME "ENHANCED"
        DATE USER_ENTRY_TIME "ENHANCED"
        VARCHAR2-20 USER_PROTECTED "ENHANCED"
        RAW-32 SRC_HASH
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
    
    VDS_REFERENCES {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-20 ISSUE_REVISION PK  
        VARCHAR2-100 VDS_NAME PK
        VARCHAR2-20 VDS_REVISION PK
        DATE VALID_FROM PK
        DATE REV_DATE "ENHANCED"
        VARCHAR2-50 STATUS "ENHANCED"
        VARCHAR2-20 OFFICIAL_REVISION "ENHANCED"
        VARCHAR2-50 DELTA "ENHANCED"
        VARCHAR2-100 USER_NAME "ENHANCED"
        DATE USER_ENTRY_TIME "ENHANCED"
        VARCHAR2-20 USER_PROTECTED "ENHANCED"
        RAW-32 SRC_HASH
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
    
    MDS_REFERENCES {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-20 ISSUE_REVISION PK
        VARCHAR2-100 MDS_NAME PK
        VARCHAR2-20 MDS_REVISION PK
        DATE VALID_FROM PK
        VARCHAR2-50 AREA "SPECIAL_FIELD"
        DATE REV_DATE "ENHANCED"
        VARCHAR2-50 STATUS "ENHANCED"
        VARCHAR2-20 OFFICIAL_REVISION "ENHANCED"
        VARCHAR2-50 DELTA "ENHANCED"
        VARCHAR2-100 USER_NAME "ENHANCED"
        DATE USER_ENTRY_TIME "ENHANCED"
        VARCHAR2-20 USER_PROTECTED "ENHANCED"
        RAW-32 SRC_HASH
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
    
    PIPE_ELEMENT_REFERENCES {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-20 ISSUE_REVISION PK
        NUMBER ELEMENT_ID PK
        DATE VALID_FROM PK
        VARCHAR2-100 ELEMENT_GROUP "ENHANCED"
        VARCHAR2-100 DIMENSION_STANDARD "ENHANCED"
        VARCHAR2-100 PRODUCT_FORM "ENHANCED"
        VARCHAR2-100 MATERIAL_GRADE "ENHANCED"
        VARCHAR2-100 MDS "ENHANCED"
        VARCHAR2-20 MDS_REVISION "ENHANCED"
        VARCHAR2-50 AREA "ENHANCED"
        VARCHAR2-20 REVISION
        DATE REV_DATE
        VARCHAR2-50 STATUS
        VARCHAR2-50 DELTA
        VARCHAR2-100 USER_NAME "ENHANCED"
        DATE USER_ENTRY_TIME "ENHANCED"
        VARCHAR2-20 USER_PROTECTED "ENHANCED"
        RAW-32 SRC_HASH
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
```

---

## **NEW PCS Detail Tables Architecture**

```mermaid
erDiagram
    %% PCS Detail Tables Relationships
    PLANTS ||--o{ PCS_HEADER : "has_pcs"
    PCS_HEADER ||--|| PCS_TEMP_PRESSURE : "detailed_specs"
    PCS_HEADER ||--o{ PCS_PIPE_SIZES : "pipe_specifications"  
    PCS_HEADER ||--o{ PCS_PIPE_ELEMENTS : "pipe_elements"
    
    PCS_HEADER {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-100 PCS_NAME PK
        VARCHAR2-20 PCS_REVISION PK
        DATE VALID_FROM PK
        VARCHAR2-50 STATUS "NEW"
        DATE REV_DATE "NEW"
        VARCHAR2-50 RATING_CLASS "NEW"
        VARCHAR2-50 TEST_PRESSURE "NEW"
        VARCHAR2-100 MATERIAL_GROUP "NEW"
        VARCHAR2-100 DESIGN_CODE "NEW"
        DATE LAST_UPDATE "NEW"
        VARCHAR2-100 LAST_UPDATE_BY "NEW"
        VARCHAR2-100 APPROVER "NEW"
        CLOB NOTEPAD "NEW"
        NUMBER SPECIAL_REQ_ID "NEW"
        VARCHAR2-100 TUBE_PCS "NEW"
        VARCHAR2-100 NEW_VDS_SECTION "NEW"
        RAW-32 SRC_HASH
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
    
    PCS_TEMP_PRESSURE {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-100 PCS_NAME PK
        VARCHAR2-20 PCS_REVISION PK
        DATE VALID_FROM PK
        VARCHAR2-100 SC "NEW"
        VARCHAR2-100 VSM "NEW"
        NUMBER CORR_ALLOWANCE "NEW"
        VARCHAR2-50 LONG_WELD_EFF "NEW"
        VARCHAR2-50 WALL_THK_TOL "NEW"
        CLOB SERVICE_REMARK "NEW"
        NUMBER DESIGN_PRESS_01 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_02 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_03 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_04 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_05 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_06 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_07 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_08 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_09 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_10 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_11 "NEW_MATRIX"
        NUMBER DESIGN_PRESS_12 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_01 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_02 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_03 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_04 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_05 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_06 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_07 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_08 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_09 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_10 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_11 "NEW_MATRIX"
        NUMBER DESIGN_TEMP_12 "NEW_MATRIX"
        VARCHAR2-50 NOTE_ID_CORR_ALLOWANCE "NEW"
        VARCHAR2-50 NOTE_ID_SERVICE_CODE "NEW"
        VARCHAR2-50 NOTE_ID_WALL_THK_TOL "NEW"
        VARCHAR2-50 NOTE_ID_LONG_WELD_EFF "NEW"
        VARCHAR2-50 NOTE_ID_GENERAL_PCS "NEW"
        VARCHAR2-50 NOTE_ID_DESIGN_CODE "NEW"
        VARCHAR2-50 NOTE_ID_PRESS_TEMP_TABLE "NEW"
        VARCHAR2-50 NOTE_ID_PIPE_SIZE_WTH_TABLE "NEW"
        NUMBER MATERIAL_GROUP_ID "NEW"
        NUMBER SPECIAL_REQ_ID "NEW"
        VARCHAR2-200 SPECIAL_REQ "NEW"
        VARCHAR2-100 NEW_VDS_SECTION "NEW"
        VARCHAR2-100 TUBE_PCS "NEW"
        VARCHAR2-50 EDS_MJ_MATRIX "NEW"
        NUMBER MJ_REDUCTION_FACTOR "NEW"
        RAW-32 SRC_HASH
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
    
    PCS_PIPE_SIZES {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-100 PCS_NAME PK
        VARCHAR2-20 PCS_REVISION PK
        VARCHAR2-50 NOM_SIZE PK
        DATE VALID_FROM PK
        NUMBER OUTER_DIAM "PRECISE_NEW"
        NUMBER WALL_THICKNESS "PRECISE_NEW"
        VARCHAR2-50 SCHEDULE "NEW"
        NUMBER UNDER_TOLERANCE "PRECISE_NEW"
        NUMBER CORROSION_ALLOWANCE "PRECISE_NEW"  
        NUMBER WELDING_FACTOR "PRECISE_NEW"
        VARCHAR2-50 DIM_ELEMENT_CHANGE "NEW"
        VARCHAR2-50 SCHEDULE_IN_MATRIX "NEW"
        RAW-32 SRC_HASH
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
    
    PCS_PIPE_ELEMENTS {
        VARCHAR2-50 PLANT_ID PK
        VARCHAR2-100 PCS_NAME PK
        VARCHAR2-20 PCS_REVISION PK
        NUMBER MATERIAL_GROUP_ID PK
        NUMBER ELEMENT_GROUP_NO PK
        NUMBER LINE_NO PK
        DATE VALID_FROM PK
        VARCHAR2-200 ELEMENT "NEW"
        VARCHAR2-100 DIM_STANDARD "NEW"
        VARCHAR2-50 FROM_SIZE "NEW"
        VARCHAR2-50 TO_SIZE "NEW"
        VARCHAR2-100 PRODUCT_FORM "NEW"
        VARCHAR2-200 MATERIAL "NEW"
        VARCHAR2-100 MDS "NEW"
        VARCHAR2-100 EDS "NEW"
        VARCHAR2-20 EDS_REVISION "NEW"
        VARCHAR2-100 ESK "NEW"
        VARCHAR2-50 REVMARK "NEW"
        CLOB REMARK "NEW"
        VARCHAR2-10 PAGE_BREAK "NEW"
        VARCHAR2-100 ELEMENT_GROUP "NEW"
        VARCHAR2-10 MATL_IN_MATRIX "NEW"
        VARCHAR2-200 PARENT_ELEMENT "NEW"
        VARCHAR2-100 ITEM_CODE "NEW"
        VARCHAR2-20 MDS_REVISION "NEW"
        RAW-32 SRC_HASH
        DATE VALID_TO
        CHAR-1 IS_CURRENT
        VARCHAR2-20 CHANGE_TYPE
        DATE DELETE_DATE
        NUMBER ETL_RUN_ID
    }
```

---

## **ETL Data Flow Visualization**

```mermaid
graph TD
    subgraph "TR2000 API"
        A1[Operators API]
        A2[Plants API]
        A3[Plant Issues API]
        A4[Reference APIs<br/>PCS, VDS, EDS, MDS, etc.]
        A5[PCS Detail APIs<br/>Header, Temp/Press, Sizes, Elements]
    end
    
    subgraph "Staging Layer"
        B1[STG_OPERATORS]
        B2[STG_PLANTS<br/>24+ fields]
        B3[STG_ISSUES<br/>25+ fields]
        B4[STG_*_REFERENCES<br/>Enhanced metadata]
        B5[STG_PCS_* Tables<br/>100+ engineering fields]
    end
    
    subgraph "ETL Processing"
        C1[Deduplication<br/>ROW_NUMBER by STG_ID]
        C2[Validation<br/>Business rules]
        C3[SCD2 Processing<br/>INSERT/UPDATE/DELETE/REACTIVATE]
        C4[Change Detection<br/>Oracle STANDARD_HASH]
    end
    
    subgraph "Dimension Layer"
        D1[OPERATORS<br/>SCD2]
        D2[PLANTS<br/>24+ fields + SCD2]
        D3[ISSUES<br/>25+ fields + SCD2]
        D4[*_REFERENCES<br/>Enhanced + SCD2]
        D5[PCS_* Tables<br/>Engineering + SCD2]
    end
    
    subgraph "Control & Audit"
        E1[ETL_CONTROL<br/>Run tracking]
        E2[ETL_ERROR_LOG<br/>Error persistence]
        E3[ETL_RECONCILIATION<br/>Count validation]
    end
    
    A1 --> B1
    A2 --> B2
    A3 --> B3
    A4 --> B4
    A5 --> B5
    
    B1 --> C1
    B2 --> C1
    B3 --> C1
    B4 --> C1
    B5 --> C1
    
    C1 --> C2
    C2 --> C3
    C3 --> C4
    
    C4 --> D1
    C4 --> D2
    C4 --> D3
    C4 --> D4
    C4 --> D5
    
    C1 --> E1
    C2 --> E2
    C3 --> E3
    
    style B2 fill:#90EE90
    style B3 fill:#90EE90  
    style B4 fill:#87CEEB
    style B5 fill:#FFD700
    style D2 fill:#90EE90
    style D3 fill:#90EE90
    style D4 fill:#87CEEB
    style D5 fill:#FFD700
```

---

## **Field Coverage Enhancement Visualization**

```mermaid
graph LR
    subgraph "BEFORE: Basic ETL (20% Coverage)"
        A1[PLANTS<br/>5 basic fields]
        A2[ISSUES<br/>5 basic fields]
        A3[References<br/>Name + Revision only]
        A4[No PCS Detail Tables]
    end
    
    subgraph "AFTER: Complete Data Warehouse (100% Coverage)"
        B1[PLANTS<br/>24+ fields<br/>Complete configuration]
        B2[ISSUES<br/>25+ fields<br/>Full revision matrix]
        B3[References<br/>Complete metadata<br/>User audit fields]
        B4[PCS Detail Tables<br/>4 tables<br/>100+ engineering fields]
    end
    
    A1 -->|380% increase| B1
    A2 -->|400% increase| B2
    A3 -->|Enhanced metadata| B3
    A4 -->|NEW capability| B4
    
    style A1 fill:#FFB6C1
    style A2 fill:#FFB6C1
    style A3 fill:#FFB6C1
    style A4 fill:#FFB6C1
    style B1 fill:#90EE90
    style B2 fill:#90EE90
    style B3 fill:#87CEEB
    style B4 fill:#FFD700
```

---

## **Table Categories & Color Coding**

```mermaid
graph TD
    subgraph "🎛️ Control Tables (Gray)"
        CT1[ETL_CONTROL]
        CT2[ETL_ENDPOINT_LOG]
        CT3[ETL_ERROR_LOG]
        CT4[ETL_PLANT_LOADER]
        CT5[ETL_ISSUE_LOADER]
        CT6[ETL_RECONCILIATION]
    end
    
    subgraph "📊 Master Data (Green)" 
        MD1[OPERATORS<br/>2 fields]
        MD2[PLANTS<br/>24+ fields - ENHANCED]
        MD3[ISSUES<br/>25+ fields - ENHANCED]
    end
    
    subgraph "🔗 Reference Tables (Blue)"
        RT1[PCS_REFERENCES - ENHANCED]
        RT2[VDS_REFERENCES - ENHANCED]
        RT3[EDS_REFERENCES - ENHANCED]
        RT4[MDS_REFERENCES - ENHANCED]
        RT5[VSK_REFERENCES - ENHANCED]
        RT6[ESK_REFERENCES - ENHANCED]
        RT7[SC_REFERENCES - ENHANCED]
        RT8[VSM_REFERENCES - ENHANCED]
        RT9[PIPE_ELEMENT_REFERENCES - ENHANCED]
    end
    
    subgraph "🔧 PCS Engineering Tables (Gold)"
        ET1[PCS_HEADER<br/>15+ fields - NEW]
        ET2[PCS_TEMP_PRESSURE<br/>70+ fields - NEW]
        ET3[PCS_PIPE_SIZES<br/>11 fields - NEW]
        ET4[PCS_PIPE_ELEMENTS<br/>25+ fields - NEW]
    end
    
    style CT1 fill:#D3D3D3
    style CT2 fill:#D3D3D3
    style CT3 fill:#D3D3D3
    style CT4 fill:#D3D3D3
    style CT5 fill:#D3D3D3
    style CT6 fill:#D3D3D3
    
    style MD1 fill:#90EE90
    style MD2 fill:#90EE90
    style MD3 fill:#90EE90
    
    style RT1 fill:#87CEEB
    style RT2 fill:#87CEEB
    style RT3 fill:#87CEEB
    style RT4 fill:#87CEEB
    style RT5 fill:#87CEEB
    style RT6 fill:#87CEEB
    style RT7 fill:#87CEEB
    style RT8 fill:#87CEEB
    style RT9 fill:#87CEEB
    
    style ET1 fill:#FFD700
    style ET2 fill:#FFD700
    style ET3 fill:#FFD700
    style ET4 fill:#FFD700
```

---

## **Engineering Data Capabilities Matrix**

| Data Category | Before Enhancement | After Enhancement | Business Impact |
|---------------|-------------------|-------------------|-----------------|
| **Plant Configuration** | 5 basic fields | 24+ complete fields | ✅ Full plant setup data |
| **Issue Tracking** | 5 basic fields | 25+ revision matrix | ✅ Complete audit trail |
| **Reference Metadata** | Name/revision only | Complete metadata + user audit | ✅ Full traceability |
| **Engineering Specifications** | ❌ None | ✅ 4 detailed PCS tables | ✅ Design calculations |
| **Temperature/Pressure** | ❌ None | ✅ 12-point matrix | ✅ Engineering analysis |
| **Material Tracking** | ❌ Basic | ✅ Complete specifications | ✅ Material management |
| **User Audit** | ❌ None | ✅ Full user/time tracking | ✅ Compliance ready |

---

## **Key Architectural Benefits**

### 🎯 **Complete API Coverage**
- **100% Field Capture**: All TR2000 API fields now stored
- **No Data Loss**: Complete engineering specifications preserved
- **Future-Proof**: Ready for new API enhancements

### 🔍 **Enhanced Traceability**
- **User Audit**: Who created/modified every record
- **Change Tracking**: Complete SCD2 temporal history
- **Revision Matrix**: Component-level revision tracking

### ⚡ **Engineering Analytics** 
- **Design Calculations**: Pressure/temperature matrices
- **Material Analysis**: Complete material specifications  
- **Performance Monitoring**: Full audit trail for optimization

### 🛡️ **Data Quality & Governance**
- **Validation Framework**: Business rule enforcement
- **Error Persistence**: Autonomous transaction error logging
- **Reconciliation**: Automated count validation

---

*This enhanced database architecture transforms TR2000 from a basic ETL system into a comprehensive engineering data warehouse with complete audit capabilities and full API field coverage.*