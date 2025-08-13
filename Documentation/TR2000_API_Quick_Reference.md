# TR2000 API Quick Reference

## Base URL
```
https://tr2000api.equinor.com
```

## Working Endpoints

| Endpoint | Method | Params | Records | Purpose |
|----------|--------|---------|---------|---------|
| `/operators` | GET | - | 8 | List all operators |
| `/plants` | GET | - | 106 | List all plants |
| `/plants/{id}` | GET | PlantID | 1 | Single plant details |
| `/operators/{id}/plants` | GET | OperatorID | Varies | Plants by operator |
| `/plants/{id}/pcs` | GET | PlantID | 100+ | Pipe specifications |
| `/plants/{id}/issues` | GET | PlantID | 5-20 | Revision tracking |
| `/vds` | GET | - | Large | All valve data sheets |
| `/eds` | GET | - | Multiple | Engineering specifications |
| `/mds` | GET | - | Multiple | Material data sheets |
| `/vsk` | GET | - | Multiple | Valve specifications |

## Sample Requests

### Get All Operators
```bash
curl https://tr2000api.equinor.com/operators
```

### Get Plants for Equinor Europe  
```bash
curl https://tr2000api.equinor.com/operators/1/plants
```

### Get PCS for Kårstø Plant
```bash  
curl https://tr2000api.equinor.com/plants/1/pcs
```

### Get Issue History for Plant
```bash
curl https://tr2000api.equinor.com/plants/1/issues
```

### Get All Valve Data Sheets (Large Dataset)
```bash
curl https://tr2000api.equinor.com/vds
```

### Get Engineering Specifications
```bash
curl https://tr2000api.equinor.com/eds
```

### Get Material Data Sheets
```bash  
curl https://tr2000api.equinor.com/mds
```

### Get Valve Specifications
```bash
curl https://tr2000api.equinor.com/vsk
```

### PCS with Query Parameters
```bash
curl "https://tr2000api.equinor.com/plants/1/pcs?status=R&revision=A"
```

## Key Data Points

### Active Operators
- **ID 1**: Equinor Europe (89 plants)
- **ID 7**: Equinor North America (8 plants)
- **ID 2**: Equinor South America (2 plants)
- **ID 8**: Equinor Wind Projects (4 plants)

### Major Plants with Data
- **Plant 1**: Kårstø Plant (200+ PCS, 16 issues)
- **Plant 2**: Major facility (300+ PCS, 13 issues)  
- **Plant 145**: Sleipner A Platform (100+ PCS)

### Response Format
All endpoints return:
```json
{
  "success": true,
  "get{EntityName}": [ /* data array */ ]
}
```

## Status Codes
- **R**: Released (active)
- **O**: Outdated  
- **S**: Superseded
- **W**: Working (draft)
- **E**: Expired
- **I**: Inactive

## Query Parameters
- **PCS Filtering**: `?status=R&revision=A`
- **Supported on**: `/plants/{id}/pcs`

## Quick Data Stats
- **Total Plants**: 106 (across all operators)
- **Working Endpoints**: 10 confirmed
- **Global Document Types**: VDS, EDS, MDS, VSK
- **PCS per Major Plant**: 100+ specifications
- **Geographic Coverage**: Europe, North/South America, Wind Projects

## Non-Working Endpoints
❌ **BoltTension**: All 8 endpoints (404)
❌ **References**: All plant reference endpoints (404)
❌ **PCS Sub-endpoints**: header, properties, temperature, etc. (404)
❌ **VDS Plant-Specific**: `/plants/{id}/vds` (404)
❌ **Individual Documents**: `/pcs/{id}`, `/vds/{id}` (404)
❌ **ESK**: `/esk` (500 Internal Server Error)

## Warnings
⚠️ **Large Dataset**: `/vds` endpoint returns >10MB of data