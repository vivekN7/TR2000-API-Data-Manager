# TR2000 API Complete Reference

## Overview
The TR2000 API provides access to Equinor's pipe class specifications, plant data, and operational information. This document maps all working endpoints with complete request/response structures.

## Working Endpoints Summary

| Endpoint | Method | Parameters | Records | Description |
|----------|--------|------------|---------|-------------|
| `/operators` | GET | None | 8 | All operators |
| `/plants` | GET | None | 106 | All plants |
| `/plants/{id}` | GET | id (PlantID) | 1 | Single plant details |
| `/operators/{id}/plants` | GET | id (OperatorID) | Varies | Plants by operator |
| `/plants/{id}/pcs` | GET | id (PlantID) | 100+ | Pipe Class Specifications |
| `/plants/{id}/issues` | GET | id (PlantID) | 5-20 | Issue tracking/revisions |
| `/vds` | GET | None | Large (>10MB) | All Valve Data Sheets |
| `/eds` | GET | None | Multiple | All Engineering Data Specifications |
| `/mds` | GET | None | Multiple | All Material Data Sheets |
| `/vsk` | GET | None | Multiple | All Valve Specifications |

## Detailed Endpoint Documentation

### 1. GET /operators
**Purpose**: Retrieve all operators in the system

**Request**:
```http
GET https://tr2000api.equinor.com/operators
```

**Response Structure**:
```json
{
  "success": true,
  "getOperator": [
    {
      "OperatorID": 8,
      "OperatorName": "Equinor Africa"
    }
  ]
}
```

**Data Types**:
- `OperatorID`: Integer (Primary Key)
- `OperatorName`: String

**Available Operators**:
1. Equinor Europe (106 plants)
2. Equinor North America (10 plants)  
3. Equinor Africa (0 plants with data)
4. Equinor Wind Projects (0 plants with data)

---

### 2. GET /plants
**Purpose**: Retrieve all plants across all operators

**Request**:
```http
GET https://tr2000api.equinor.com/plants
```

**Response Structure**:
```json
{
  "success": true,
  "getPlant": [
    {
      "OperatorID": 1,
      "OperatorName": "Equinor Europe", 
      "PlantID": 1,
      "ShortDescription": "KAR",
      "Project": "",
      "LongDescription": "Kårstø Plant",
      "CommonLibPlantCode": "",
      "InitialRevision": "1",
      "AreaID": 1,
      "Area": "Europe"
    }
  ]
}
```

**Data Types**:
- `PlantID`: Integer (Primary Key)
- `OperatorID`: Integer (Foreign Key → operators.OperatorID)
- `AreaID`: Integer (References areas, but /areas endpoint restricted)
- All other fields: String

**Key Plants with Data**:
- Plant 1: "Kårstø Plant" (200+ PCS, 16 issues)
- Plant 2: Major facility (300+ PCS, 13 issues)
- Plant 145: "Sleipner A Platform" (100+ PCS)

---

### 3. GET /plants/{id}
**Purpose**: Get detailed information for a specific plant

**Request**:
```http
GET https://tr2000api.equinor.com/plants/1
```

**Response Structure**:
```json
{
  "success": true,
  "getPlant": [
    {
      "OperatorID": 1,
      "OperatorName": "Equinor Europe",
      "PlantID": 1,
      "ShortDescription": "KAR", 
      "Project": "",
      "LongDescription": "Kårstø Plant",
      "CommonLibPlantCode": "",
      "InitialRevision": "1",
      "AreaID": 1,
      "Area": "Europe"
    }
  ]
}
```

**Usage Notes**:
- Identical structure to /plants but filtered to single plant
- Useful for plant-specific lookups
- Returns same data as found in /plants collection

---

### 4. GET /operators/{id}/plants  
**Purpose**: Get all plants belonging to a specific operator

**Request**:
```http
GET https://tr2000api.equinor.com/operators/1/plants
```

**Response Structure**:
```json
{
  "success": true,
  "getPlant": [
    {
      "OperatorID": 1,
      "OperatorName": "Equinor Europe",
      "PlantID": 1,
      "ShortDescription": "KAR",
      "LongDescription": "Kårstø Plant", 
      "Area": "Europe"
      // ... more plants for this operator
    }
  ]
}
```

**Record Counts by Operator**:
- Operator 1 (Equinor Europe): 89 plants
- Operator 7 (Equinor North America): 8 plants  
- Operator 2 (Equinor South America): 2 plants
- Operator 8 (Equinor Wind Projects): 4 plants
- Others: 3 plants

---

### 5. GET /plants/{id}/pcs
**Purpose**: Get Pipe Class Specifications for a specific plant

**Request**:
```http  
GET https://tr2000api.equinor.com/plants/1/pcs
```

**Response Structure**:
```json
{
  "success": true,
  "getPCS": [
    {
      "PCS": "01-GA101",
      "Revision": "5", 
      "Status": "R",
      "RevDate": "15.01.2019",
      "RatingClass": "CL150",
      "TestPressure": "21.4 bar(g) / 311 psi",
      "MaterialGroup": "CSLT",
      "DesignCode": "ASME B31.3",
      "LastUpdate": "15.01.2019 08:43",
      "LastUpdateBy": "MOKR",
      "Approver": "MOKR", 
      "Notepad": "",
      "SpecialReqID": 0,
      "TubePCS": "",
      "NewVDSSection": ""
    }
  ]
}
```

**Data Types**:
- `PCS`: String (Pipe Class Specification ID - Primary Key)
- `Revision`: String
- `Status`: String (R/O/S/W - Released/Outdated/Superseded/Working)
- `RevDate`: String (Date format: DD.MM.YYYY)
- `RatingClass`: String (CL150, CL300, CL600, CL900)
- `TestPressure`: String (Pressure with units)
- `MaterialGroup`: String (CSLT, 316, TITAN, etc.)
- `DesignCode`: String (ASME B31.3, EN ISO 14692)
- `LastUpdate`: String (DateTime: DD.MM.YYYY HH:MM)
- `LastUpdateBy`: String (User ID)
- `Approver`: String (User ID)
- `SpecialReqID`: Integer
- Other fields: String

**Record Counts**:
- Major plants: 200-300+ specifications
- Smaller plants: 50-100 specifications

---

### 6. GET /plants/{id}/issues
**Purpose**: Get issue tracking and revision history for a plant

**Request**:
```http
GET https://tr2000api.equinor.com/plants/1/issues  
```

**Response Structure**:
```json
{
  "success": true,
  "UserName": "Ian Plaine",
  "UserEntryTime": "02.08.2024 10:23",
  "UserProtected": "",
  "getIssueList": [
    {
      "IssueRevision": "1",
      "Status": "R", 
      "RevDate": "01.01.2019",
      "ProtectStatus": "",
      "GeneralRevision": "A",
      "GeneralRevDate": "01.01.2019",
      "PCSRevision": "1",
      "PCSRevDate": "01.01.2019", 
      "EDSRevision": "A",
      "EDSRevDate": "01.01.2019",
      "VDSRevision": "A", 
      "VDSRevDate": "01.01.2019",
      "VSKRevision": "",
      "VSKRevDate": "",
      "MDSRevision": "",
      "MDSRevDate": "", 
      "ESKRevision": "",
      "ESKRevDate": "",
      "SCRevision": "",
      "SCRevDate": "",
      "VSMRevision": "",
      "VSMRevDate": ""
    }
  ]
}
```

**Data Types**:
- `IssueRevision`: String (Primary revision identifier)
- `Status`: String (R/O/S/W - Released/Outdated/Superseded/Working)
- All revision fields: String (revision numbers/identifiers)  
- All date fields: String (DD.MM.YYYY format)
- Metadata fields: String (user info, protection status)

**Document Types Tracked**:
- **General**: General documentation revisions
- **PCS**: Pipe Class Specification revisions
- **EDS**: Engineering Design Specification 
- **VDS**: Valve Design Specification
- **VSK**: Valve Selection Criteria
- **MDS**: Material Design Specification
- **ESK**: Equipment Selection Criteria  
- **SC**: Safety Case
- **VSM**: Valve Selection Manual

## Entity Relationship Mapping

```
OPERATORS (1:N) PLANTS (1:N) PCS
    |                |
    |                +---(1:N) ISSUES
    |
OperatorID -----> OperatorID (FK)
                     |
                  PlantID -----> PlantID (FK in PCS & Issues)
```

## Non-Working Endpoints

The following endpoints were tested but returned 404, 403, or other errors:

### 404 Not Found:
- `/operators/{id}` - Individual operator details
- `/pcs` - All PCS across plants
- `/issues` - All issues across plants  
- `/plants/{id}/equipment` - Equipment listings

### 403 Forbidden:
- `/areas` - Geographic area definitions

---

### 7. GET /vds
**Purpose**: Retrieve all Valve Data Sheets across the system

**Request**:
```http
GET https://tr2000api.equinor.com/vds
```

**Response Structure**:
```json
{
  "success": true,
  "getVDS": [
    {
      "VDS": "string", 
      "Revision": "string",
      "Status": "string",
      "RevDate": "string",
      "LastUpdate": "string",
      "LastUpdateBy": "string",
      "Notepad": "string",
      "HTMLContent": "string"
    }
  ]
}
```

**Warning**: This endpoint returns a very large dataset (>10MB). Use with caution.

---

### 8. GET /eds
**Purpose**: Retrieve all Engineering Data Specifications

**Request**:
```http
GET https://tr2000api.equinor.com/eds
```

**Response Structure**:
```json
{
  "success": true,
  "getEDS": [
    {
      "EDS": "string",
      "Revision": "string", 
      "Status": "string",
      "RevDate": "string",
      "LastUpdate": "string",
      "LastUpdateBy": "string",
      "Notepad": "string",
      "ArticleContent": "string",
      "ElementGroupID": 0,
      "HTMLContent": "string"
    }
  ]
}
```

---

### 9. GET /mds
**Purpose**: Retrieve all Material Data Sheets

**Request**:
```http
GET https://tr2000api.equinor.com/mds
```

**Response Structure**:
```json
{
  "success": true,
  "getMDS": [
    {
      "MDS": "string",
      "Revision": "string",
      "Status": "string", 
      "RevDate": "string",
      "LastUpdate": "string",
      "LastUpdateBy": "string",
      "Notepad": "string",
      "Area": "string"
    }
  ]
}
```

---

### 10. GET /vsk
**Purpose**: Retrieve all Valve Specifications

**Request**:
```http
GET https://tr2000api.equinor.com/vsk
```

**Response Structure**:
```json
{
  "success": true,
  "getVSK": [
    {
      "VSK": "string",
      "Revision": "string",
      "Status": "string",
      "RevDate": "string", 
      "LastUpdate": "string",
      "LastUpdateBy": "string",
      "Notepad": "string"
    }
  ]
}
```

## Non-Working Endpoints

The following endpoints were tested but returned 404, 403, or 500 errors:

### Individual Document Access (404):
- `/pcs/{id}` - Individual PCS access
- `/vds/{id}` - Individual VDS access  
- `/eds/{id}` - Individual EDS access

### Reference Endpoints (404):
- `/plants/{id}/pcs/references`
- `/plants/{id}/sc/references`
- `/plants/{id}/vsm/references`
- `/plants/{id}/vds/references`
- `/plants/{id}/eds/references`
- `/plants/{id}/mds/references`
- `/plants/{id}/vsk/references`
- `/plants/{id}/esk/references`
- `/plants/{id}/pipe-element/references`

### PCS Sub-Endpoints (404):
- `/plants/{id}/pcs/header`
- `/plants/{id}/pcs/properties`
- `/plants/{id}/pcs/temperature`
- `/plants/{id}/pcs/pressure`
- `/plants/{id}/pcs/pipe-size`
- `/plants/{id}/pcs/pipe-element`
- `/plants/{id}/pcs/valve-element`
- `/plants/{id}/pcs/embedded-note`

### VDS Plant-Specific (404):
- `/plants/{id}/vds`
- `/plants/{id}/vds/subsegments`
- `/plants/{id}/vds/properties`

### BoltTension Endpoints (404):
All BoltTension endpoints return 404:
- `/bolttension/flangetype`
- `/bolttension/gaskettype`
- `/bolttension/boltmaterial`
- `/bolttension/tensionforces`
- `/bolttension/tool`
- `/bolttension/toolpressure`
- `/bolttension/plantinfo`
- `/bolttension/lubricant`

### Error Endpoints (500):
- `/esk` - Internal Server Error

### Root-Level Missing (404):
- `/pcs` - All PCS data
- `/sc` - Safety Case documents
- `/vsm` - Valve Selection Manual

## Query Parameters

### PCS Endpoint Filtering:
The `/plants/{id}/pcs` endpoint supports query parameters:
- `?revision=A` - Filter by specific revision
- `?status=R` - Filter by status (R/O/S/W/E/I)

Example:
```http
GET https://tr2000api.equinor.com/plants/1/pcs?status=R&revision=A
```

## Usage Recommendations

1. **Start with `/operators`** to get the list of available operators
2. **Use `/plants`** to understand plant distribution and relationships
3. **Filter by operator** using `/operators/{id}/plants` for focused analysis
4. **Get technical specs** via `/plants/{id}/pcs` for engineering data
5. **Track revisions** using `/plants/{id}/issues` for change management
6. **Access global documents** via `/vds`, `/eds`, `/mds`, `/vsk` for comprehensive specifications
7. **Use query parameters** on PCS endpoints for filtered results

## Data Quality Notes

- **Equinor Europe** has the most comprehensive data (89 plants)
- **Global Coverage**: 106 plants across 8 operators worldwide
- **Major plants** (IDs 1, 2, 145) have extensive PCS and issue data
- **Status codes** are consistently used across all document types
- **Date formats** are standardized as DD.MM.YYYY
- **User tracking** is available in all document management
- **Large datasets** available via global document endpoints (VDS >10MB)
