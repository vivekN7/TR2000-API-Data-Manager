# TR2000 Data Flow Example: Grane Plant (ID: 34) - Issue Revision 4.2

## Starting Point: User Selection
```sql
-- User has selected in the UI:
SELECTED_PLANTS: plant_id = '34' (Grane)
SELECTED_ISSUES: plant_id = '34', issue_revision = '4.2'
```

---

## Step 1: Get Plant Information
**API Call:** `GET /plants/34`

**Returns:**
```json
{
  "OperatorID": 1,
  "OperatorName": "Equinor",
  "PlantID": "34",
  "ShortDescription": "Grane",
  "Project": "GRA",
  "LongDescription": "Grane Field Development",
  "CommonLibPlantCode": "GRA",
  "InitialRevision": "1.0",
  "AreaID": 2,
  "Area": "North Sea",
  "EnableEmbeddedNote": "Y",
  "CategoryID": "1",
  "Category": "Production",
  "PCSQA": "Y",
  "Visible": "Y"
}
```

---

## Step 2: Get Issue Revision Details
**API Call:** `GET /plants/34/issues` (then filter for revision 4.2)

**Returns Issue 4.2 Details:**
```json
{
  "IssueRevision": "4.2",
  "Status": "APPROVED",
  "RevDate": "2024-03-15",
  "ProtectStatus": "N",
  "GeneralRevision": "4.2",
  "GeneralRevDate": "2024-03-15",
  "PCSRevision": "4.1",        // ← PCS documents are at revision 4.1
  "PCSRevDate": "2024-03-10",
  "EDSRevision": "3.8",        // ← EDS documents are at revision 3.8
  "EDSRevDate": "2024-03-08",
  "VDSRevision": "4.0",        // ← VDS documents are at revision 4.0
  "VDSRevDate": "2024-03-12",
  "VSKRevision": "2.5",
  "VSKRevDate": "2024-02-20",
  "MDSRevision": "4.2",
  "MDSRevDate": "2024-03-15",
  "ESKRevision": "3.1",
  "ESKRevDate": "2024-03-01",
  "SCRevision": "4.2",
  "SCRevDate": "2024-03-15",
  "VSMRevision": "4.1",
  "VSMRevDate": "2024-03-10",
  "UserName": "SYSTEM",
  "UserEntryTime": "2024-03-15 10:30:00"
}
```

**🔴 KEY INSIGHT: Issue 4.2 tells us WHICH versions of each document type to load!**

---

## Step 3: Get PCS References for This Issue
**API Call:** `GET /plants/34/issues/rev/4.2/pcs`

**Returns PCS List (Based on PCSRevision 4.1 from Issue):**
```json
[
  {
    "PCS": "1CS12",
    "Revision": "4.1",          // ← Matches issue's PCSRevision
    "RevDate": "2024-03-10",
    "Status": "APPROVED",
    "OfficialRevision": "4.1",
    "RatingClass": "600#",
    "MaterialGroup": "CS",
    "HistoricalPCS": "N",
    "Delta": "N"
  },
  {
    "PCS": "1CS16",
    "Revision": "4.1",
    "RevDate": "2024-03-10",
    "Status": "APPROVED",
    "OfficialRevision": "4.1",
    "RatingClass": "900#",
    "MaterialGroup": "CS",
    "HistoricalPCS": "N",
    "Delta": "Y"              // ← Has changes
  },
  {
    "PCS": "6SS31",
    "Revision": "4.1",
    "RevDate": "2024-03-10",
    "Status": "APPROVED",
    "OfficialRevision": "4.1",
    "RatingClass": "1500#",
    "MaterialGroup": "SS316",
    "HistoricalPCS": "N",
    "Delta": "N"
  }
]
```

---

## Step 4: Get Detailed PCS Data (Example: 1CS16)
### 4A: PCS Header and Properties
**API Call:** `GET /plants/34/pcs/1CS16/rev/4.1`

**Returns:**
```json
{
  "PCS": "1CS16",
  "Revision": "4.1",
  "Status": "APPROVED",
  "RevDate": "2024-03-10",
  "RatingClass": "900#",
  "TestPressure": "225 bar",
  "MaterialGroup": "CS",
  "DesignCode": "ASME B31.3",
  "CorrAllowance": 3,
  "ServiceRemark": "Hydrocarbon Service",
  "DesignPress01": "150",
  "DesignTemp01": "-29",
  "DesignPress02": "150",
  "DesignTemp02": "100",
  "SC": "SC-CS-900",
  "VSM": "VSM-GRA-01"
}
```

### 4B: Temperature and Pressure Table
**API Call:** `GET /plants/34/pcs/1CS16/rev/4.1/temp-pressures`

**Returns:**
```json
[
  { "Temperature": "-29", "Pressure": "150" },
  { "Temperature": "50", "Pressure": "150" },
  { "Temperature": "100", "Pressure": "145" },
  { "Temperature": "150", "Pressure": "140" },
  { "Temperature": "200", "Pressure": "130" },
  { "Temperature": "250", "Pressure": "115" },
  { "Temperature": "300", "Pressure": "95" },
  { "Temperature": "350", "Pressure": "75" }
]
```

### 4C: Pipe Sizes
**API Call:** `GET /plants/34/pcs/1CS16/rev/4.1/pipe-sizes`

**Returns:**
```json
[
  {
    "PCS": "1CS16",
    "Revision": "4.1",
    "NomSize": "2\"",
    "OuterDiam": "60.3",
    "WallThickness": "5.54",
    "Schedule": "SCH 80",
    "UnderTolerance": "12.5%",
    "CorrosionAllowance": "3.0",
    "WeldingFactor": "1.0"
  },
  {
    "NomSize": "3\"",
    "OuterDiam": "88.9",
    "WallThickness": "7.62",
    "Schedule": "SCH 80",
    "UnderTolerance": "12.5%",
    "CorrosionAllowance": "3.0",
    "WeldingFactor": "1.0"
  },
  {
    "NomSize": "4\"",
    "OuterDiam": "114.3",
    "WallThickness": "8.56",
    "Schedule": "SCH 80",
    "UnderTolerance": "12.5%",
    "CorrosionAllowance": "3.0",
    "WeldingFactor": "1.0"
  }
]
```

### 4D: Pipe Elements
**API Call:** `GET /plants/34/pcs/1CS16/rev/4.1/pipe-elements`

**Returns (Sample):**
```json
[
  {
    "PCS": "1CS16",
    "Revision": "4.1",
    "ElementGroupNo": 1,
    "LineNo": 1,
    "Element": "PIPE",
    "DimStandard": "ASME B36.10M",
    "FromSize": "1/2\"",
    "ToSize": "24\"",
    "ProductForm": "SMLS",
    "Material": "A106 Gr.B",
    "MDS": "M11",
    "MDSRevision": "4.2",
    "EDS": "E11",
    "EDSRevision": "3.8",
    "ElementID": 1001
  },
  {
    "ElementGroupNo": 2,
    "LineNo": 1,
    "Element": "ELBOW 90 LR",
    "DimStandard": "ASME B16.9",
    "FromSize": "2\"",
    "ToSize": "24\"",
    "ProductForm": "BUTT WELD",
    "Material": "A234 WPB",
    "MDS": "M12",
    "MDSRevision": "4.2",
    "ElementID": 1002
  }
]
```

### 4E: Valve Elements
**API Call:** `GET /plants/34/pcs/1CS16/rev/4.1/valve-elements`

**Returns:**
```json
[
  {
    "ValveGroupNo": 1,
    "LineNo": 1,
    "ValveType": "GATE",
    "VDS": "VG-900-CS-01",
    "ValveDescription": "Gate Valve, 900#, CS Body",
    "FromSize": "2\"",
    "ToSize": "24\"",
    "Status": "APPROVED",
    "Revision": "4.0"        // ← Matches VDSRevision from Issue
  },
  {
    "ValveGroupNo": 2,
    "LineNo": 1,
    "ValveType": "GLOBE",
    "VDS": "VGL-900-CS-01",
    "ValveDescription": "Globe Valve, 900#, CS Body",
    "FromSize": "1/2\"",
    "ToSize": "4\"",
    "Status": "APPROVED",
    "Revision": "4.0"
  }
]
```

---

## Step 5: Get VDS References for This Issue
**API Call:** `GET /plants/34/issues/rev/4.2/vds`

**Returns VDS List (Based on VDSRevision 4.0):**
```json
[
  {
    "VDS": "VG-900-CS-01",
    "Revision": "4.0",        // ← Matches issue's VDSRevision
    "RevDate": "2024-03-12",
    "Status": "APPROVED",
    "OfficialRevision": "4.0",
    "Delta": "N"
  },
  {
    "VDS": "VGL-900-CS-01",
    "Revision": "4.0",
    "RevDate": "2024-03-12",
    "Status": "APPROVED",
    "OfficialRevision": "4.0",
    "Delta": "Y"
  }
]
```

---

## Step 6: Get Other References (EDS, MDS, VSK, ESK)
### EDS References
**API Call:** `GET /plants/34/issues/rev/4.2/eds`

**Returns (Based on EDSRevision 3.8):**
```json
[
  {
    "EDS": "E11",
    "Revision": "3.8",
    "RevDate": "2024-03-08",
    "Status": "APPROVED"
  },
  {
    "EDS": "E12",
    "Revision": "3.8",
    "RevDate": "2024-03-08",
    "Status": "APPROVED"
  }
]
```

### MDS References
**API Call:** `GET /plants/34/issues/rev/4.2/mds`

**Returns (Based on MDSRevision 4.2):**
```json
[
  {
    "MDS": "M11",
    "Revision": "4.2",
    "Area": "General",
    "RevDate": "2024-03-15",
    "Status": "APPROVED"
  },
  {
    "MDS": "M12",
    "Revision": "4.2",
    "Area": "General",
    "RevDate": "2024-03-15",
    "Status": "APPROVED"
  }
]
```

---

## Database Storage Flow

### 1. ETL Process Sequence:
```sql
-- Step 1: Plant data stored
INSERT INTO PLANTS (plant_id, short_description, operator_id...)
VALUES ('34', 'Grane', 1...);

-- Step 2: Issue data stored
INSERT INTO ISSUES (plant_id, issue_revision, status, pcs_revision, vds_revision...)
VALUES ('34', '4.2', 'APPROVED', '4.1', '4.0'...);

-- Step 3: PCS List loaded (only revision 4.1 items)
INSERT INTO PCS_LIST (plant_id, pcs_name, revision, rating_class...)
VALUES ('34', '1CS16', '4.1', '900#'...);

-- Step 4: PCS Details loaded
INSERT INTO PCS_TEMP_PRESSURES (plant_id, pcs_name, revision, temperature, pressure)
VALUES ('34', '1CS16', '4.1', '-29', '150');

INSERT INTO PCS_PIPE_SIZES (plant_id, pcs_name, revision, nom_size, wall_thickness...)
VALUES ('34', '1CS16', '4.1', '2"', '5.54'...);

-- Step 5: References loaded
INSERT INTO PCS_REFERENCES (plant_id, issue_revision, pcs_name, revision...)
VALUES ('34', '4.2', '1CS16', '4.1'...);

INSERT INTO VDS_REFERENCES (plant_id, issue_revision, vds, revision...)
VALUES ('34', '4.2', 'VG-900-CS-01', '4.0'...);
```

### 2. What You Can Query:
```sql
-- All PCS for this issue
SELECT * FROM PCS_REFERENCES 
WHERE plant_id = '34' AND issue_revision = '4.2';

-- Temperature/Pressure for specific PCS
SELECT * FROM PCS_TEMP_PRESSURES
WHERE plant_id = '34' AND pcs_name = '1CS16' AND revision = '4.1';

-- All valve specs referenced by this issue
SELECT vr.*, vd.*
FROM VDS_REFERENCES vr
LEFT JOIN VDS_LIST vd ON vr.plant_id = vd.plant_id 
  AND vr.vds = vd.vds AND vr.revision = vd.revision
WHERE vr.plant_id = '34' AND vr.issue_revision = '4.2';
```

---

## Summary: What Issue 4.2 Gives You

1. **Configuration Snapshot**: Issue 4.2 defines EXACT versions of all documents
2. **PCS Documents**: Only loads revision 4.1 PCS specs (not older/newer)
3. **VDS Documents**: Only loads revision 4.0 valve specs
4. **Coordinated Set**: All these versions are guaranteed to work together
5. **Delta Tracking**: Shows which documents changed (Delta = 'Y')

## Key Takeaway

**Without Issue Selection**: You'd have to guess which PCS/VDS revisions to load
**With Issue 4.2 Selected**: System knows exactly:
- Load PCS revision 4.1 (not 3.9 or 4.2)
- Load VDS revision 4.0 (not 3.8 or 4.1)
- Load EDS revision 3.8
- These all work together as a tested configuration!

The issue revision acts as a **manifest** ensuring version compatibility across all document types.