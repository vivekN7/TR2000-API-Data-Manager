# TR2000 PipeSpec API - Complete Entity Relationship Diagram

*Comprehensive ERD covering all endpoints and data structures*

## Master Entity Relationship Diagram

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor': '#7b1fa2', 'primaryTextColor': '#000000', 'primaryBorderColor': '#7b1fa2', 'lineColor': '#333333', 'secondaryColor': '#f57c00', 'tertiaryColor': '#2e7d32', 'background': '#ffffff', 'mainBkg': '#ffffff', 'clusterTextColor': '#ffffff', 'titleColor': '#ffffff', 'edgeLabelBackground': '#ffffff', 'attributeFill': '#ffffff', 'attributeColor': '#000000'}}}%%
erDiagram
    %% Core Organizational Structure
    OPERATOR {
        int OperatorID PK "🔑 PRIMARY KEY"
        string OperatorName "Operator company name"
        string Description "Operator description"
        string ContactInfo "Contact details"
    }
    
    PLANT {
        int PlantID PK "🔑 PRIMARY KEY"
        int OperatorID FK "🔗 REFERENCES Operator.OperatorID"
        string LongDescription "Full plant name"
        string ShortDescription "Plant abbreviation"
        string Location "Plant location"
        string Status "Operational status"
    }
    
    %% Issue Management System
    ISSUE {
        string IssueID PK "🔑 PRIMARY KEY"
        int PlantID FK "🔗 REFERENCES Plant.PlantID"
        string IssueType "Type of issue"
        string Status "Current status"
        string Description "Issue description"
        datetime CreatedDate "Creation timestamp"
    }
    
    ISSUE_REVISION {
        string IssueID PK "🔑 PRIMARY KEY"
        string RevisionID PK "🔑 PRIMARY KEY"
        datetime RevisionDate "Revision timestamp"
        string Status "Revision status"
        string Notes "Revision notes"
    }
    
    %% PCS (Pipe Class System) Structure
    PCS {
        string PCS PK "🔑 PRIMARY KEY"
        string Revision PK "🔑 PRIMARY KEY"
        int PlantID FK "🔗 REFERENCES Plant.PlantID"
        string IssueID FK "🔗 REFERENCES Issue.IssueID"
        string Status "Current status"
        string RevDate "Revision date"
        string Description "PCS description"
    }
    
    PCS_HEADER {
        string PCS PK "🔑 PRIMARY KEY"
        string Revision PK "🔑 PRIMARY KEY"
        string HeaderType "Header classification"
        string Properties "Header properties JSON"
        string Standards "Applicable standards"
        string Notes "Additional notes"
    }
    
    PCS_TEMPERATURE_PRESSURE {
        string PCS PK "🔑 PRIMARY KEY"
        string Revision PK "🔑 PRIMARY KEY"
        string ConditionID PK "🔑 PRIMARY KEY"
        decimal Temperature "Operating temperature"
        decimal Pressure "Operating pressure"
        string Units "Temperature/Pressure units"
        string Description "Condition description"
    }
    
    PIPE_SIZE {
        string NomSize PK "🔑 PRIMARY KEY"
        string PCS PK "🔑 PRIMARY KEY"
        string Revision PK "🔑 PRIMARY KEY"
        int PlantID FK "🔗 REFERENCES Plant.PlantID"
        string OuterDiam "Diameter in mm"
        string WallThickness "Thickness in mm"
        string Schedule "Pipe schedule"
        string UnderTolerance "Tolerance percentage"
        string CorrosionAllowance "Corrosion allowance"
        string WeldingFactor "Welding factor"
        string ScheduleInMatrix "Y/N matrix inclusion"
    }
    
    PIPE_ELEMENT {
        string ElementID PK "🔑 PRIMARY KEY"
        string PCS PK "🔑 PRIMARY KEY"
        string Revision PK "🔑 PRIMARY KEY"
        string ElementType "Type of pipe element"
        string Specification "Element specification"
        string Material "Element material"
        string Rating "Pressure rating"
        string Standards "Applicable standards"
    }
    
    VALVE_ELEMENT {
        string ValveID PK "🔑 PRIMARY KEY"
        string PCS PK "🔑 PRIMARY KEY"
        string Revision PK "🔑 PRIMARY KEY"
        string ValveType "Type of valve"
        string Specification "Valve specification"
        string Material "Valve material"
        string Rating "Pressure rating"
        string Actuation "Valve actuation method"
        string Standards "Applicable standards"
    }
    
    EMBEDDED_NOTE {
        string NoteID PK "🔑 PRIMARY KEY"
        string PCS PK "🔑 PRIMARY KEY"
        string Revision PK "🔑 PRIMARY KEY"
        string NoteType "Type of note"
        string Content "Note content"
        string Position "Note position reference"
        datetime CreatedDate "Note creation date"
    }
    
    %% VDS (Valve Data Sheet) Structure
    VDS {
        string VDSID PK "🔑 PRIMARY KEY"
        string Revision PK "🔑 PRIMARY KEY"
        int PlantID FK "🔗 REFERENCES Plant.PlantID"
        string IssueID FK "🔗 REFERENCES Issue.IssueID"
        string Description "VDS description"
        string Status "Current status"
        string RevDate "Revision date"
    }
    
    VDS_SUBSEGMENT {
        string SubsegmentID PK "🔑 PRIMARY KEY"
        string VDSID PK "🔑 PRIMARY KEY"
        string Revision PK "🔑 PRIMARY KEY"
        string SubsegmentType "Type of subsegment"
        string Properties "Subsegment properties JSON"
        string Description "Subsegment description"
        int SortOrder "Display order"
    }
    
    %% Reference Tables for Various Standards
    PCS_REFERENCE {
        string ReferenceID PK "🔑 PRIMARY KEY"
        string PCS FK "🔗 REFERENCES PCS.PCS"
        string ReferenceType "Type of reference"
        string ReferenceCode "Reference code"
        string Description "Reference description"
        string Standard "Applicable standard"
    }
    
    SC_REFERENCE {
        string SCID PK "🔑 PRIMARY KEY"
        string IssueID FK "🔗 REFERENCES Issue.IssueID"
        string Description "SC description"
        string Standard "Applicable standard"
        string Status "Reference status"
    }
    
    VSM_REFERENCE {
        string VSMID PK "🔑 PRIMARY KEY"
        string IssueID FK "🔗 REFERENCES Issue.IssueID"
        string Description "VSM description"
        string Standard "Applicable standard"
        string Status "Reference status"
    }
    
    VSK_REFERENCE {
        string VSKID PK "🔑 PRIMARY KEY"
        string IssueID FK "🔗 REFERENCES Issue.IssueID"
        string Description "VSK description"
        string Standard "Applicable standard"
        string Status "Reference status"
    }
    
    EDS_REFERENCE {
        string EDSID PK "🔑 PRIMARY KEY"
        string IssueID FK "🔗 REFERENCES Issue.IssueID"
        string Description "EDS description"
        string Standard "Applicable standard"
        string Status "Reference status"
    }
    
    MDS_REFERENCE {
        string MDSID PK "🔑 PRIMARY KEY"
        string IssueID FK "🔗 REFERENCES Issue.IssueID"
        string Description "MDS description"
        string Standard "Applicable standard"
        string Status "Reference status"
    }
    
    ESK_REFERENCE {
        string ESKID PK "🔑 PRIMARY KEY"
        string IssueID FK "🔗 REFERENCES Issue.IssueID"
        string Description "ESK description"
        string Standard "Applicable standard"
        string Status "Reference status"
    }
    
    %% Bolt Tension System
    FLANGE_TYPE {
        string FlangeTypeID PK "🔑 PRIMARY KEY"
        int PlantID FK "🔗 REFERENCES Plant.PlantID"
        string FlangeClass "Flange classification"
        string Rating "Pressure rating"
        string Standard "Applicable standard"
        string Material "Flange material"
        string Description "Flange description"
    }
    
    GASKET_TYPE {
        string GasketTypeID PK "🔑 PRIMARY KEY"
        int PlantID FK "🔗 REFERENCES Plant.PlantID"
        string GasketMaterial "Gasket material"
        string GasketType "Type of gasket"
        string Standard "Applicable standard"
        string Description "Gasket description"
        decimal Thickness "Gasket thickness"
    }
    
    BOLT_MATERIAL {
        string BoltMaterialID PK "🔑 PRIMARY KEY"
        int PlantID FK "🔗 REFERENCES Plant.PlantID"
        string Material "Bolt material"
        string Grade "Material grade"
        string Standard "Applicable standard"
        decimal TensileStrength "Tensile strength"
        decimal YieldStrength "Yield strength"
    }
    
    TENSION_FORCES {
        string TensionID PK "🔑 PRIMARY KEY"
        string FlangeTypeID FK "🔗 REFERENCES FlangeType.FlangeTypeID"
        string GasketTypeID FK "🔗 REFERENCES GasketType.GasketTypeID"
        string BoltMaterialID FK "🔗 REFERENCES BoltMaterial.BoltMaterialID"
        decimal RequiredTension "Required tension force"
        decimal MaxTension "Maximum tension force"
        decimal MinTension "Minimum tension force"
        string Units "Force units"
    }
    
    TENSION_TOOL {
        string ToolID PK "🔑 PRIMARY KEY"
        int PlantID FK "🔗 REFERENCES Plant.PlantID"
        string ToolType "Type of tensioning tool"
        string Manufacturer "Tool manufacturer"
        string Model "Tool model"
        decimal MaxCapacity "Maximum tool capacity"
        string Calibration "Calibration status"
    }
    
    TOOL_PRESSURE {
        string PressureID PK "🔑 PRIMARY KEY"
        string ToolID FK "🔗 REFERENCES TensionTool.ToolID"
        string TensionID FK "🔗 REFERENCES TensionForces.TensionID"
        decimal RequiredPressure "Required hydraulic pressure"
        string Units "Pressure units"
        decimal Tolerance "Pressure tolerance"
    }
    
    LUBRICANT {
        string LubricantID PK "🔑 PRIMARY KEY"
        int PlantID FK "🔗 REFERENCES Plant.PlantID"
        string LubricantType "Type of lubricant"
        string Brand "Lubricant brand"
        string Specification "Lubricant specification"
        decimal FrictionCoefficient "Friction coefficient"
        string ApplicationMethod "Application method"
    }
    
    %% Core Relationships
    OPERATOR ||--o{ PLANT : "🔗 OperatorID-to-OperatorID"
    PLANT ||--o{ ISSUE : "🔗 PlantID-to-PlantID"
    ISSUE ||--o{ ISSUE_REVISION : "🔗 IssueID-to-IssueID"
    PLANT ||--o{ PCS : "🔗 PlantID-to-PlantID"
    ISSUE ||--o{ PCS : "🔗 IssueID-to-IssueID"
    PCS ||--o{ PCS_HEADER : "🔗 PCS+Revision-to-PCS+Revision"
    PCS ||--o{ PCS_TEMPERATURE_PRESSURE : "🔗 PCS+Revision-to-PCS+Revision"
    PCS ||--o{ PIPE_SIZE : "🔗 PCS+Revision-to-PCS+Revision"
    PCS ||--o{ PIPE_ELEMENT : "🔗 PCS+Revision-to-PCS+Revision"
    PCS ||--o{ VALVE_ELEMENT : "🔗 PCS+Revision-to-PCS+Revision"
    PCS ||--o{ EMBEDDED_NOTE : "🔗 PCS+Revision-to-PCS+Revision"
    PCS ||--o{ PCS_REFERENCE : "🔗 PCS-to-PCS"
    
    %% VDS Relationships
    PLANT ||--o{ VDS : "🔗 PlantID-to-PlantID"
    ISSUE ||--o{ VDS : "🔗 IssueID-to-IssueID"
    VDS ||--o{ VDS_SUBSEGMENT : "🔗 VDSID+Revision-to-VDSID+Revision"
    
    %% Reference Relationships
    ISSUE ||--o{ SC_REFERENCE : "🔗 IssueID-to-IssueID"
    ISSUE ||--o{ VSM_REFERENCE : "🔗 IssueID-to-IssueID"
    ISSUE ||--o{ VSK_REFERENCE : "🔗 IssueID-to-IssueID"
    ISSUE ||--o{ EDS_REFERENCE : "🔗 IssueID-to-IssueID"
    ISSUE ||--o{ MDS_REFERENCE : "🔗 IssueID-to-IssueID"
    ISSUE ||--o{ ESK_REFERENCE : "🔗 IssueID-to-IssueID"
    
    %% Bolt Tension Relationships
    PLANT ||--o{ FLANGE_TYPE : "🔗 PlantID-to-PlantID"
    PLANT ||--o{ GASKET_TYPE : "🔗 PlantID-to-PlantID"
    PLANT ||--o{ BOLT_MATERIAL : "🔗 PlantID-to-PlantID"
    PLANT ||--o{ TENSION_TOOL : "🔗 PlantID-to-PlantID"
    PLANT ||--o{ LUBRICANT : "🔗 PlantID-to-PlantID"
    FLANGE_TYPE ||--o{ TENSION_FORCES : "🔗 FlangeTypeID-to-FlangeTypeID"
    GASKET_TYPE ||--o{ TENSION_FORCES : "🔗 GasketTypeID-to-GasketTypeID"
    BOLT_MATERIAL ||--o{ TENSION_FORCES : "🔗 BoltMaterialID-to-BoltMaterialID"
    TENSION_TOOL ||--o{ TOOL_PRESSURE : "🔗 ToolID-to-ToolID"
    TENSION_FORCES ||--o{ TOOL_PRESSURE : "🔗 TensionID-to-TensionID"
```

## Complete API Endpoint Structure

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor': '#7b1fa2', 'primaryTextColor': '#000000', 'primaryBorderColor': '#7b1fa2', 'lineColor': '#333333', 'secondaryColor': '#f57c00', 'tertiaryColor': '#2e7d32', 'background': '#ffffff', 'mainBkg': '#ffffff', 'clusterTextColor': '#ffffff', 'titleColor': '#ffffff', 'edgeLabelBackground': '#ffffff', 'attributeFill': '#ffffff', 'attributeColor': '#000000'}}}%%
graph TB
    subgraph "Operators and Plants"
        A1["/operators"]
        A2["/operators/{operatorId}/plants"]
        A3["/plants"]
        A4["/plants/{plantId}"]
    end
    
    subgraph "Issue Management"
        B1["/issues/{issueId}/revisions"]
        B2["/issues/{issueId}/pcs-references"]
        B3["/issues/{issueId}/sc-references"]
        B4["/issues/{issueId}/vsm-references"]
        B5["/issues/{issueId}/vds-references"]
        B6["/issues/{issueId}/eds-references"]
        B7["/issues/{issueId}/mds-references"]
        B8["/issues/{issueId}/vsk-references"]
        B9["/issues/{issueId}/esk-references"]
        B10["/issues/{issueId}/pipe-element-references"]
    end
    
    subgraph "PCS Endpoints"
        C1["/plants/{plantId}/pcs"]
        C2["/plants/{plantId}/pcs/{pcsId}/header"]
        C3["/plants/{plantId}/pcs/{pcsId}/temp-pressure"]
        C4["/plants/{plantId}/pcs/{pcsId}/rev/{revision}/pipe-sizes"]
        C5["/plants/{plantId}/pcs/{pcsId}/pipe-elements"]
        C6["/plants/{plantId}/pcs/{pcsId}/valve-elements"]
        C7["/plants/{plantId}/pcs/{pcsId}/embedded-notes"]
    end
    
    subgraph "VDS Endpoints"
        D1["/plants/{plantId}/vds"]
        D2["/plants/{plantId}/vds/{vdsId}/subsegments"]
    end
    
    subgraph "Bolt Tension Endpoints"
        E1["/plants/{plantId}/flange-types"]
        E2["/plants/{plantId}/gasket-types"]
        E3["/plants/{plantId}/bolt-materials"]
        E4["/plants/{plantId}/tension-forces"]
        E5["/plants/{plantId}/tension-tools"]
        E6["/plants/{plantId}/tool-pressures"]
        E7["/plants/{plantId}/plant-info"]
        E8["/plants/{plantId}/lubricants"]
    end
    
    classDef operators fill:#e3f2fd,stroke:#1976d2,stroke-width:3px,color:#000000
    classDef issues fill:#fff3e0,stroke:#f57c00,stroke-width:3px,color:#000000
    classDef pcs fill:#e8f5e8,stroke:#2e7d32,stroke-width:3px,color:#000000
    classDef vds fill:#fce4ec,stroke:#c2185b,stroke-width:3px,color:#000000
    classDef bolts fill:#f3e5f5,stroke:#7b1fa2,stroke-width:3px,color:#000000
    
    class A1,A2,A3,A4 operators
    class B1,B2,B3,B4,B5,B6,B7,B8,B9,B10 issues
    class C1,C2,C3,C4,C5,C6,C7 pcs
    class D1,D2 vds
    class E1,E2,E3,E4,E5,E6,E7,E8 bolts
```

## Data Domain Architecture

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor': '#7b1fa2', 'primaryTextColor': '#000000', 'primaryBorderColor': '#7b1fa2', 'lineColor': '#333333', 'secondaryColor': '#f57c00', 'tertiaryColor': '#2e7d32', 'background': '#ffffff', 'mainBkg': '#ffffff', 'clusterTextColor': '#ffffff', 'titleColor': '#ffffff', 'edgeLabelBackground': '#ffffff', 'attributeFill': '#ffffff', 'attributeColor': '#000000'}}}%%
flowchart TD
    subgraph "Organizational Hierarchy"
        OP[Operator Companies] --> PL[Plants/Facilities]
        PL --> IS[Issues/Projects]
        IS --> REV[Issue Revisions]
    end
    
    subgraph "Engineering Specifications"
        IS --> PCS[Pipe Class Systems]
        IS --> VDS[Valve Data Sheets]
        PCS --> PSIZ[Pipe Sizes]
        PCS --> PELEM[Pipe Elements]
        PCS --> VELEM[Valve Elements]
        VDS --> VSUB[VDS Subsegments]
    end
    
    subgraph "Reference Standards"
        IS --> SCR[SC References]
        IS --> VSMR[VSM References]
        IS --> VSKR[VSK References]
        IS --> EDSR[EDS References]
        IS --> MDSR[MDS References]
        IS --> ESKR[ESK References]
        PCS --> PCSR[PCS References]
    end
    
    subgraph "Bolt Tensioning System"
        PL --> FT[Flange Types]
        PL --> GT[Gasket Types]
        PL --> BM[Bolt Materials]
        PL --> TT[Tension Tools]
        PL --> LUB[Lubricants]
        FT --> TF[Tension Forces]
        GT --> TF
        BM --> TF
        TT --> TP[Tool Pressures]
        TF --> TP
    end
    
    classDef org fill:#e3f2fd,stroke:#1976d2,stroke-width:3px,color:#000000
    classDef eng fill:#e8f5e8,stroke:#2e7d32,stroke-width:3px,color:#000000
    classDef ref fill:#fff3e0,stroke:#f57c00,stroke-width:3px,color:#000000
    classDef bolt fill:#f3e5f5,stroke:#7b1fa2,stroke-width:3px,color:#000000
    
    class OP,PL,IS,REV org
    class PCS,VDS,PSIZ,PELEM,VELEM,VSUB eng
    class SCR,VSMR,VSKR,EDSR,MDSR,ESKR,PCSR ref
    class FT,GT,BM,TT,LUB,TF,TP bolt
```

## Key System Insights

### 1. **Hierarchical Organization Structure**
```
Operator → Plants → Issues → Revisions
                 ↓
         Engineering Specifications
                 ↓
         (PCS, VDS, References, Bolt Tension)
```

### 2. **Primary Data Domains**

#### **PCS (Pipe Class System)**: Core piping specifications
- Header and properties configuration
- Temperature and pressure conditions  
- Pipe sizes and elements
- Valve elements and embedded notes

#### **VDS (Valve Data Sheet)**: Valve specifications
- VDS list management
- Subsegments with detailed properties

#### **Issue References**: Standards and documentation
- Multiple reference types (SC, VSM, VDS, EDS, MDS, VSK, ESK)
- Pipe element references
- Centralized reference management

#### **Bolt Tension System**: Mechanical integrity
- Flange and gasket specifications
- Bolt materials and tension calculations
- Tool requirements and pressure settings
- Lubrication specifications

### 3. **API Design Patterns**

#### **Hierarchical Endpoints**: Follow organizational structure
- `/operators/{operatorId}/plants`
- `/plants/{plantId}/pcs/{pcsId}/rev/{revision}`

#### **Domain-Specific Groupings**: Related functionality grouped
- All bolt tension endpoints under `/plants/{plantId}/`
- All issue references under `/issues/{issueId}/`

#### **Revision Control**: Built-in versioning
- Issue revisions for change management
- PCS revisions for specification updates
- VDS revisions for valve specifications

### 4. **Data Relationships Summary**

- **One-to-Many**: Operator→Plants, Plant→Issues, Issue→References
- **Composite Keys**: PCS+Revision, VDS+Revision combinations
- **Cross-Domain**: Plants connect all domains (PCS, VDS, BoltTension)
- **Reference Integrity**: Issues link to multiple reference types

This comprehensive ERD represents the complete TR2000 PipeSpec API ecosystem, showing how all the different endpoints and data domains interconnect to support industrial piping and valve specification management.