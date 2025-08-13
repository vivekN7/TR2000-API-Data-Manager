# TR2000 API Missing Endpoints Analysis

## Overview
This document provides a comprehensive analysis of TR2000 API endpoints that were expected but found to be non-functional during systematic testing.

## Expected vs. Actual Endpoint Coverage

### ✅ **Working Endpoints (10 total)**
1. `/operators` - All operators
2. `/plants` - All plants  
3. `/plants/{id}` - Single plant details
4. `/operators/{id}/plants` - Plants by operator
5. `/plants/{id}/pcs` - Pipe Class Specifications
6. `/plants/{id}/issues` - Issue tracking/revisions
7. `/vds` - All Valve Data Sheets (global)
8. `/eds` - All Engineering Data Specifications (global)
9. `/mds` - All Material Data Sheets (global)
10. `/vsk` - All Valve Specifications (global)

### ❌ **Missing/Non-Working Endpoints**

## 1. Issue Collection & References (9 endpoints missing)

**Expected but Non-Functional:**
- `/plants/{id}/pcs/references` ❌ 404
- `/plants/{id}/sc/references` ❌ 404  
- `/plants/{id}/vsm/references` ❌ 404
- `/plants/{id}/vds/references` ❌ 404
- `/plants/{id}/eds/references` ❌ 404
- `/plants/{id}/mds/references` ❌ 404
- `/plants/{id}/vsk/references` ❌ 404
- `/plants/{id}/esk/references` ❌ 404
- `/plants/{id}/pipe-element/references` ❌ 404

**Impact**: Cannot access plant-specific document references or cross-references between document types.

## 2. PCS Detailed Endpoints (8 endpoints missing)

**Expected but Non-Functional:**
- `/plants/{id}/pcs/header` ❌ 404
- `/plants/{id}/pcs/properties` ❌ 404
- `/plants/{id}/pcs/temperature` ❌ 404
- `/plants/{id}/pcs/pressure` ❌ 404
- `/plants/{id}/pcs/pipe-size` ❌ 404
- `/plants/{id}/pcs/pipe-element` ❌ 404
- `/plants/{id}/pcs/valve-element` ❌ 404
- `/plants/{id}/pcs/embedded-note` ❌ 404

**Impact**: Cannot access detailed PCS specifications beyond basic metadata. All detailed engineering data is missing.

## 3. VDS Plant-Specific Endpoints (3 endpoints missing)

**Expected but Non-Functional:**
- `/plants/{id}/vds` ❌ 404
- `/plants/{id}/vds/subsegments` ❌ 404
- `/plants/{id}/vds/properties` ❌ 404

**Impact**: Cannot access plant-specific valve data sheets. Only global VDS data available.

**Note**: Global `/vds` endpoint works but returns >10MB dataset without plant filtering.

## 4. BoltTension Endpoints (8 endpoints missing)

**Expected but Non-Functional:**
- `/bolttension/flangetype` ❌ 404
- `/bolttension/gaskettype` ❌ 404
- `/bolttension/boltmaterial` ❌ 404
- `/bolttension/tensionforces` ❌ 404
- `/bolttension/tool` ❌ 404
- `/bolttension/toolpressure` ❌ 404
- `/bolttension/plantinfo` ❌ 404
- `/bolttension/lubricant` ❌ 404

**Alternative patterns tested:**
- `/bolt-tension/*` variants ❌ 404

**Impact**: No access to bolt tension calculation data, flange specifications, or tool information.

## 5. Individual Document Access (3+ endpoints missing)

**Expected but Non-Functional:**
- `/pcs/{id}` ❌ 404
- `/vds/{id}` ❌ 404
- `/eds/{id}` ❌ 404
- `/mds/{id}` ❌ 404
- `/vsk/{id}` ❌ 404

**Impact**: Cannot access individual documents by their unique IDs.

## 6. Root-Level Document Collections (3 endpoints missing)

**Expected but Non-Functional:**
- `/pcs` ❌ 404 (global PCS collection)
- `/sc` ❌ 404 (Safety Case documents)
- `/vsm` ❌ 404 (Valve Selection Manual)

**Working Root-Level:**
- `/vds` ✅ (but very large dataset)
- `/eds` ✅
- `/mds` ✅
- `/vsk` ✅

**Impact**: Inconsistent availability of global document collections.

## 7. Error-Prone Endpoints

**Server Error:**
- `/esk` ⚠️ 500 Internal Server Error

**Impact**: ESK (Equipment Selection Criteria) data completely unavailable.

## 8. Alternative URL Patterns (Multiple missing)

**Non-Working Singular Forms:**
- `/operator/{id}/plants` ❌ 404 (vs. working `/operators/{id}/plants`)
- `/plant/{id}` ❌ 404 (vs. working `/plants/{id}`)
- `/plant/{id}/pcs` ❌ 404 (vs. working `/plants/{id}/pcs`)

**Impact**: API strictly requires plural forms in URLs.

## Missing Functionality Summary

### Document Type Coverage
| Document Type | Plant-Specific | Global Collection | Individual Access |
|---------------|----------------|-------------------|-------------------|
| **PCS** | ✅ Basic only | ❌ | ❌ |
| **VDS** | ❌ | ✅ | ❌ |
| **EDS** | ❌ | ✅ | ❌ |
| **MDS** | ❌ | ✅ | ❌ |
| **VSK** | ❌ | ✅ | ❌ |
| **SC** | ❌ | ❌ | ❌ |
| **VSM** | ❌ | ❌ | ❌ |
| **ESK** | ❌ | ⚠️ Error | ❌ |

### Technical Data Access
| Data Category | Available | Missing |
|---------------|-----------|---------|
| **Plant Management** | ✅ Full | - |
| **Issue Tracking** | ✅ Basic | References, Cross-refs |
| **PCS Basic** | ✅ Metadata | Detailed specs, Elements |
| **VDS** | ✅ Global only | Plant-specific |
| **BoltTension** | ❌ None | All calculations |
| **Engineering Specs** | ✅ Global only | Plant-specific |

## Recommendations

### 1. **Workarounds for Missing Data**
- **PCS Details**: Extract from available metadata fields
- **Plant-specific VDS**: Filter global `/vds` response by plant references
- **References**: Build relationships from available issue tracking data
- **BoltTension**: May need external calculation tools

### 2. **API Enhancement Requests**
- Enable plant-specific filtering on global endpoints
- Restore individual document access endpoints
- Fix ESK endpoint (500 error)
- Add query parameter support to more endpoints

### 3. **Application Design Implications**
- Design around available metadata rather than detailed specifications
- Implement client-side filtering for large global datasets
- Build reference relationships from existing data
- Plan for future endpoint additions

## Total Missing Endpoint Count
- **Reference Endpoints**: 9 missing
- **PCS Detail Endpoints**: 8 missing  
- **BoltTension Endpoints**: 8 missing
- **VDS Plant Endpoints**: 3 missing
- **Individual Document Access**: 5+ missing
- **Root Collections**: 3 missing
- **Alternative Patterns**: 10+ missing

**Total Identified Missing**: 46+ endpoints

**Working vs. Expected Ratio**: 10 working out of 56+ expected ≈ **18% API coverage**