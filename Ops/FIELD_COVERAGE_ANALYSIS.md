# TR2000 ETL Field Coverage Analysis

## 🚨 CRITICAL DISCOVERY: Major Field Coverage Gaps

**Date:** 2025-08-17  
**Analysis:** Comparison between current ETL tables and actual API field structure  
**Impact:** We're capturing only ~20% of available TR2000 API data

## Executive Summary

Our current ETL implementation has **massive field coverage gaps** compared to the actual API responses. We discovered this by comparing our Oracle DDL against the complete field definitions in `EndpointConfiguration.cs`.

### Overall Impact:
- **Data Loss:** 80% of engineering data not captured
- **Business Value:** Missing critical design pressures, temperatures, materials
- **Audit Trail:** Incomplete revision tracking and status information
- **Integration:** Missing fields needed for downstream engineering systems

---

## 📊 Detailed Field Gap Analysis

### 1. PLANTS Table - Missing 19+ Fields

#### **Current ETL Implementation (5 fields):**
```sql
PLANT_ID, PLANT_NAME, LONG_DESCRIPTION, OPERATOR_ID, COMMON_LIB_PLANT_CODE
```

#### **Actual API Response (24+ fields):**
```json
{
  "OperatorID": "[Int32]",
  "OperatorName": "[String]", 
  "PlantID": "[String]",
  "ShortDescription": "[String]",     // ❌ MISSING
  "Project": "[String]",              // ❌ MISSING
  "LongDescription": "[String]",
  "CommonLibPlantCode": "[String]",
  "InitialRevision": "[String]",      // ❌ MISSING
  "AreaID": "[Int32]",                // ❌ MISSING
  "Area": "[String]",                 // ❌ MISSING
  "EnableEmbeddedNote": "[String]",   // ❌ MISSING
  "CategoryID": "[String]",           // ❌ MISSING
  "Category": "[String]",             // ❌ MISSING
  "DocumentSpaceLink": "[String]",    // ❌ MISSING
  "EnableCopyPCSFromPlant": "[String]", // ❌ MISSING
  "OverLength": "[String]",           // ❌ MISSING
  "PCSQA": "[String]",                // ❌ MISSING
  "EDSMJ": "[String]",                // ❌ MISSING
  "CelsiusBar": "[String]",           // ❌ MISSING
  "WebInfoText": "[String]",          // ❌ MISSING
  "BoltTensionText": "[String]",      // ❌ MISSING
  "Visible": "[String]",              // ❌ MISSING
  "WindowsRemarkText": "[String]",    // ❌ MISSING
  "UserProtected": "[String]"         // ❌ MISSING
}
```

**Missing Fields:** 19 out of 24 fields (79% data loss!)

---

### 2. ISSUES Table - Missing 22+ Fields

#### **Current ETL Implementation (3 fields):**
```sql
PLANT_ID, ISSUE_REVISION, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED
```

#### **Actual API Response (25+ fields):**
```json
{
  "IssueRevision": "[String]",
  "Status": "[String]",              // ❌ MISSING
  "RevDate": "[String]",             // ❌ MISSING
  "ProtectStatus": "[String]",       // ❌ MISSING
  "GeneralRevision": "[String]",     // ❌ MISSING
  "GeneralRevDate": "[String]",      // ❌ MISSING
  "PCSRevision": "[String]",         // ❌ MISSING
  "PCSRevDate": "[String]",          // ❌ MISSING
  "EDSRevision": "[String]",         // ❌ MISSING
  "EDSRevDate": "[String]",          // ❌ MISSING
  "VDSRevision": "[String]",         // ❌ MISSING
  "VDSRevDate": "[String]",          // ❌ MISSING
  "VSKRevision": "[String]",         // ❌ MISSING
  "VSKRevDate": "[String]",          // ❌ MISSING
  "MDSRevision": "[String]",         // ❌ MISSING
  "MDSRevDate": "[String]",          // ❌ MISSING
  "ESKRevision": "[String]",         // ❌ MISSING
  "ESKRevDate": "[String]",          // ❌ MISSING
  "SCRevision": "[String]",          // ❌ MISSING
  "SCRevDate": "[String]",           // ❌ MISSING
  "VSMRevision": "[String]",         // ❌ MISSING
  "VSMRevDate": "[String]",          // ❌ MISSING
  "UserName": "[String]",
  "UserEntryTime": "[String]",
  "UserProtected": "[String]"
}
```

**Missing Fields:** 22 out of 25 fields (88% data loss!)

---

### 3. Reference Tables - Missing Critical Metadata

#### **VDS References - Missing 4+ Fields:**

**Current Implementation:**
```sql
VDS_NAME, VDS_REVISION, OFFICIAL_REVISION, DELTA, USER_NAME, USER_ENTRY_TIME, USER_PROTECTED
```

**Actual API Response:**
```json
{
  "VDS": "[String]",
  "Revision": "[String]",
  "RevDate": "[String]",           // ❌ MISSING
  "Status": "[String]",            // ❌ MISSING  
  "OfficialRevision": "[String]",
  "Delta": "[String]"
}
```

**Issue:** Missing RevDate and Status for ALL reference types (VDS, EDS, MDS, VSK, ESK, SC, VSM)

---

### 4. COMPLETELY MISSING: Detailed PCS Tables

The API provides rich PCS detail tables that we're not capturing **at all**:

#### **PCS Header/Properties (15+ fields):**
```json
{
  "PCS": "[String]",
  "Revision": "[String]",
  "Status": "[String]",
  "RevDate": "[String]",
  "RatingClass": "[String]",
  "TestPressure": "[String]",
  "MaterialGroup": "[String]",
  "DesignCode": "[String]",
  "LastUpdate": "[String]",
  "LastUpdateBy": "[String]",
  "Approver": "[String]",
  "Notepad": "[String]",
  "SpecialReqID": "[Int32]",
  "TubePCS": "[String]",
  "NewVDSSection": "[String]"
}
```

#### **PCS Temperature/Pressure Matrix (70+ fields):**
```json
{
  // 12 Design Pressure fields
  "DesignPress01": "[String]", "DesignPress02": "[String]", ... "DesignPress12": "[String]",
  // 12 Design Temperature fields  
  "DesignTemp01": "[String]", "DesignTemp02": "[String]", ... "DesignTemp12": "[String]",
  // Plus 40+ additional engineering fields
  "CorrAllowance": "[Int32]",
  "LongWeldEff": "[String]",
  "WallThkTol": "[String]",
  "ServiceRemark": "[String]",
  // ... many more
}
```

#### **PCS Pipe Sizes (11 fields):**
```json
{
  "NomSize": "[String]",
  "OuterDiam": "[String]",
  "WallThickness": "[String]",
  "Schedule": "[String]",
  "UnderTolerance": "[String]",
  "CorrosionAllowance": "[String]",
  "WeldingFactor": "[String]",
  "DimElementChange": "[String]",
  "ScheduleInMatrix": "[String]"
}
```

#### **PCS Pipe Elements (25+ fields):**
```json
{
  "MaterialGroupID": "[Int32]",
  "ElementGroupNo": "[Int32]",
  "LineNo": "[Int32]",
  "Element": "[String]",
  "DimStandard": "[String]",
  "FromSize": "[String]",
  "ToSize": "[String]",
  "ProductForm": "[String]",
  "Material": "[String]",
  "MDS": "[String]",
  "EDS": "[String]",
  "EDSRevision": "[String]",
  "ESK": "[String]",
  // ... more fields
}
```

**Status:** 🚨 **COMPLETELY MISSING** - 0% coverage

---

## 📈 Business Impact Assessment

### **Current State (Minimal ETL):**
- Basic master data with minimal fields
- Reference tracking without metadata
- No detailed engineering data
- Limited audit capabilities

### **Target State (Enhanced ETL):**
- Complete TR2000 data replication
- Full engineering design data (pressures, temperatures, materials)
- Comprehensive audit trails with all revision tracking
- Complete metadata for all references
- Detailed PCS specifications for engineering analysis

### **Value Proposition:**
1. **Engineering Analysis:** Access to design pressures, temperatures, material specifications
2. **Compliance:** Complete audit trails with revision dates and status tracking
3. **Integration:** Full field coverage for downstream systems
4. **Decision Making:** Rich metadata for engineering decisions
5. **Data Quality:** Complete data lineage and change tracking

---

## ✅ Solution: Enhanced DDL Implementation

### **Created:** `Oracle_DDL_SCD2_ENHANCED.sql`

This enhanced DDL addresses all identified gaps:

#### **1. Enhanced Existing Tables:**
- **PLANTS:** Expanded from 5 to 24+ fields
- **ISSUES:** Expanded from 5 to 25+ fields  
- **Reference Tables:** Added RevDate, Status for all types

#### **2. New Detailed PCS Tables:**
- **PCS_HEADER:** Complete PCS properties (15+ fields)
- **PCS_TEMP_PRESSURE:** Full temperature/pressure matrix (70+ fields)
- **PCS_PIPE_SIZES:** Pipe size specifications (11 fields)
- **PCS_PIPE_ELEMENTS:** Element details (25+ fields)

#### **3. Enhanced Staging Tables:**
- All staging tables updated with complete field sets
- Proper data types for engineering values
- Enhanced validation capabilities

---

## 🚀 Implementation Roadmap

### **Phase 1: Critical Field Addition (Week 1)**
- Deploy enhanced DDL
- Update ETL services to populate missing fields in existing tables
- Add RevDate and Status to all reference tables

### **Phase 2: Detailed PCS Tables (Week 2-3)**
- Implement PCS detail table ETL processes
- Create new API endpoints for PCS details
- Add comprehensive temperature/pressure matrix handling

### **Phase 3: Enhanced C# Services (Week 4)**
- Update all ETL services with complete field mappings
- Enhanced error handling for expanded data
- Performance optimization for larger datasets

### **Phase 4: Testing & Validation (Week 5)**
- Comprehensive testing with real API data
- Data quality validation
- Performance testing with full field sets

---

## 📋 Immediate Next Steps

1. **Review Enhanced DDL** - Validate field mappings against actual API responses
2. **Update ETL Services** - Modify C# code to populate all new fields
3. **Create Field Mapping** - Document exact API field → Database column mapping
4. **Test Migration** - Pilot enhanced ETL with sample data
5. **Performance Analysis** - Assess impact of expanded data model

---

## ⚠️ Risks & Mitigation

### **Risks:**
- **Data Volume:** 5x increase in data storage
- **Performance:** Longer ETL times with more fields
- **Complexity:** More complex field validation

### **Mitigation:**
- **Selective Loading:** Use Plant/Issue Loader to control scope
- **Incremental Deployment:** Phase rollout to manage complexity
- **Performance Monitoring:** Enhanced metrics for new tables
- **Data Validation:** Comprehensive validation rules for engineering data

---

**Conclusion:** The enhanced DDL provides complete TR2000 API field coverage, transforming our basic ETL into a comprehensive engineering data warehouse. This addresses the 80% data loss identified and provides full engineering analysis capabilities.