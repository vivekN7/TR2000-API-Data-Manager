# TR2000 API Visual Charts (Fixed)

## How to View These Charts

### Online Mermaid Editor (Recommended)
1. Go to **https://mermaid.live/**
2. Copy any chart code below (without the ```mermaid wrapper)
3. Paste directly into the editor
4. Charts will render immediately

### VS Code with Extension
1. Install **"Mermaid Markdown Syntax Highlighting"** extension
2. Open this file
3. Press `Ctrl+Shift+V` for preview

---

## Chart 1: API Coverage Overview

```mermaid
pie title TR2000 API Endpoint Coverage
    "Working (10)" : 10
    "Missing (46)" : 46
    "Errors (1)" : 1
```

---

## Chart 2: Endpoint Status Map

```mermaid
graph TD
    API[TR2000 API]
    
    API --> WE[Working Endpoints - 10]
    API --> ME[Missing Endpoints - 46+]
    API --> EE[Error Endpoints - 1]
    
    WE --> OP[Operators & Plants - 4]
    WE --> DOC[Global Documents - 4]
    WE --> SPEC[Plant Specifications - 2]
    
    OP --> OP1["/operators<br/>8 records"]
    OP --> OP2["/plants<br/>106 records"]
    OP --> OP3["/plants/{id}<br/>Single plant"]
    OP --> OP4["/operators/{id}/plants<br/>By operator"]
    
    DOC --> DOC1["/vds<br/>WARNING: >10MB"]
    DOC --> DOC2["/eds<br/>Engineering specs"]
    DOC --> DOC3["/mds<br/>Material data"]
    DOC --> DOC4["/vsk<br/>Valve specs"]
    
    SPEC --> SPEC1["/plants/{id}/pcs<br/>100+ per plant"]
    SPEC --> SPEC2["/plants/{id}/issues<br/>Revision tracking"]
    
    ME --> BT[BoltTension - 8 endpoints]
    ME --> REF[References - 9 endpoints]
    ME --> PCS_DET[PCS Details - 8 endpoints]
    ME --> VDS_PLANT[VDS Plant - 3 endpoints]
    
    EE --> ESK["/esk - 500 Error"]
    
    classDef working fill:#4CAF50,stroke:#2E7D32,stroke-width:2px,color:#fff
    classDef missing fill:#F44336,stroke:#C62828,stroke-width:2px,color:#fff
    classDef error fill:#FF9800,stroke:#EF6C00,stroke-width:2px,color:#fff
    classDef warning fill:#FFEB3B,stroke:#F57F17,stroke-width:2px,color:#000
    
    class WE,OP,DOC,SPEC,OP1,OP2,OP3,OP4,DOC2,DOC3,DOC4,SPEC1,SPEC2 working
    class ME,BT,REF,PCS_DET,VDS_PLANT missing
    class EE,ESK error
    class DOC1 warning
```

---

## Chart 3: Entity Relationships

```mermaid
erDiagram
    OPERATORS {
        int OperatorID PK
        string OperatorName
    }
    
    PLANTS {
        int PlantID PK
        int OperatorID FK
        string ShortDescription
        string LongDescription
        string Area
    }
    
    PCS {
        string PCS PK
        int PlantID FK
        string Status
        string RatingClass
        string MaterialGroup
    }
    
    ISSUES {
        string IssueRevision PK
        int PlantID FK
        string Status
        string PCSRevision
        string VDSRevision
    }
    
    VDS_GLOBAL {
        string VDS PK
        string HTMLContent
        string Status
    }
    
    EDS_GLOBAL {
        string EDS PK
        string ArticleContent
        int ElementGroupID
    }
    
    OPERATORS ||--o{ PLANTS : "manages"
    PLANTS ||--o{ PCS : "contains"
    PLANTS ||--o{ ISSUES : "tracks"
    PLANTS }o--|| VDS_GLOBAL : "references"
    PLANTS }o--|| EDS_GLOBAL : "references"
```

---

## Chart 4: Regional Distribution

```mermaid
pie title Plant Distribution by Region
    "Europe (89)" : 89
    "North America (8)" : 8
    "Wind Projects (4)" : 4
    "South America (2)" : 2
    "Others (3)" : 3
```

---

## Chart 5: Document Access Matrix

```mermaid
graph LR
    subgraph PLANT [Plant-Specific Access]
        PP[Plants]
        PP --> PCS_P[PCS Basic Only]
        PP --> ISS_P[Issues Full]
        PP --> VDS_P[VDS Missing]
        PP --> EDS_P[EDS Missing]
    end
    
    subgraph GLOBAL [Global Access]
        PCS_G[PCS Missing]
        VDS_G[VDS Available >10MB]
        EDS_G[EDS Available]
        MDS_G[MDS Available]
        VSK_G[VSK Available]
        ESK_G[ESK Error 500]
    end
    
    subgraph INDIVIDUAL [Individual Access]
        ALL_I[All Individual Missing]
    end
    
    classDef available fill:#4CAF50,stroke:#2E7D32,color:#fff
    classDef missing fill:#F44336,stroke:#C62828,color:#fff
    classDef warning fill:#FFEB3B,stroke:#F57F17,color:#000
    classDef error fill:#FF9800,stroke:#EF6C00,color:#fff
    
    class PCS_P,ISS_P,VDS_G,EDS_G,MDS_G,VSK_G available
    class VDS_P,EDS_P,PCS_G,ALL_I missing
    class VDS_G warning
    class ESK_G error
```

---

## Chart 6: API Implementation Flow

```mermaid
flowchart TD
    START([Start API Integration])
    
    START --> OP[Get Operators<br/>GET /operators]
    OP --> PLANTS[Get Plants<br/>GET /plants]
    PLANTS --> CHOOSE{Choose Data Type}
    
    CHOOSE -->|PCS| PCS[Get PCS<br/>GET /plants/id/pcs<br/>Available]
    CHOOSE -->|Issues| ISSUES[Get Issues<br/>GET /plants/id/issues<br/>Available]
    CHOOSE -->|VDS| VDS_CHOICE{VDS Access}
    CHOOSE -->|EDS| EDS[Get EDS<br/>GET /eds<br/>Global Only]
    
    VDS_CHOICE -->|Plant Specific| VDS_PLANT[Missing<br/>NOT AVAILABLE]
    VDS_CHOICE -->|Global| VDS_GLOBAL[GET /vds<br/>WARNING >10MB]
    
    PCS --> PCS_DETAIL{Need Details?}
    PCS_DETAIL -->|Basic| PCS_OK[Use Available Data]
    PCS_DETAIL -->|Detailed| PCS_MISSING[Missing Endpoints<br/>Temperature, Pressure, etc]
    
    ISSUES --> REF_CHOICE{Need References?}
    REF_CHOICE -->|Basic| ISSUES_OK[Use Available Data]
    REF_CHOICE -->|References| REF_MISSING[Missing Reference Endpoints]
    
    VDS_PLANT --> WORKAROUND[Filter Global VDS Data]
    
    PCS_OK --> SUCCESS[Data Retrieved]
    ISSUES_OK --> SUCCESS
    EDS --> SUCCESS
    VDS_GLOBAL --> SUCCESS
    WORKAROUND --> SUCCESS
    
    classDef available fill:#4CAF50,stroke:#2E7D32,color:#fff
    classDef missing fill:#F44336,stroke:#C62828,color:#fff
    classDef warning fill:#FFEB3B,stroke:#F57F17,color:#000
    classDef decision fill:#2196F3,stroke:#1565C0,color:#fff
    classDef success fill:#4CAF50,stroke:#2E7D32,color:#fff
    
    class OP,PLANTS,PCS,ISSUES,EDS,PCS_OK,ISSUES_OK,SUCCESS available
    class VDS_PLANT,PCS_MISSING,REF_MISSING missing
    class VDS_GLOBAL,WORKAROUND warning
    class CHOOSE,VDS_CHOICE,PCS_DETAIL,REF_CHOICE decision
```

---

## Chart 7: Missing Functionality Impact

```mermaid
graph TD
    MISSING[Missing Endpoints<br/>46+ unavailable]
    
    MISSING --> HIGH[HIGH IMPACT<br/>Critical Missing]
    MISSING --> MED[MEDIUM IMPACT<br/>Workarounds Exist]
    MISSING --> LOW[LOW IMPACT<br/>Minor Issues]
    
    HIGH --> BT[BoltTension<br/>8 endpoints<br/>No calculations]
    HIGH --> PCS_DET[PCS Details<br/>8 endpoints<br/>No temperature/pressure]
    HIGH --> PLANT_VDS[Plant VDS<br/>3 endpoints<br/>Must use 10MB+ global]
    
    MED --> REFS[References<br/>9 endpoints<br/>No cross-references]
    MED --> IND_DOC[Individual Docs<br/>5+ endpoints<br/>No direct access]
    
    LOW --> ALT_URLS[Alternative URLs<br/>10+ endpoints<br/>Plural forms work]
    
    classDef high fill:#F44336,stroke:#C62828,color:#fff
    classDef medium fill:#FF9800,stroke:#EF6C00,color:#fff
    classDef low fill:#4CAF50,stroke:#2E7D32,color:#fff
    
    class HIGH,BT,PCS_DET,PLANT_VDS high
    class MED,REFS,IND_DOC medium
    class LOW,ALT_URLS low
```

---

## Chart 8: Priority Matrix

```mermaid
quadrantChart
    title Implementation Priority Matrix
    x-axis Low Complexity --> High Complexity
    y-axis Low Value --> High Value
    
    quadrant-1 Quick Wins
    quadrant-2 Major Projects
    quadrant-3 Fill-ins
    quadrant-4 Questionable
    
    Operators: [0.2, 0.9]
    PCS Basic: [0.3, 0.8]
    Issues: [0.3, 0.7]
    Global Docs: [0.6, 0.6]
    VDS Filtering: [0.8, 0.8]
    PCS Details: [0.9, 0.9]
    References: [0.7, 0.5]
    BoltTension: [0.9, 0.6]
```

---

## Quick Test Instructions

### For Mermaid.live:
1. Copy this code (without the triple backticks):

```
pie title TR2000 API Coverage
    "Working (10)" : 10
    "Missing (46)" : 46
    "Errors (1)" : 1
```

2. Paste into https://mermaid.live/
3. Should render immediately

### For VS Code:
1. Install Mermaid extension
2. Open this file  
3. Use preview mode (Ctrl+Shift+V)

## Color Legend

- 🟢 **Green**: Working endpoints
- 🔴 **Red**: Missing endpoints
- 🟡 **Yellow**: Warnings/limitations
- 🟠 **Orange**: Errors
- 🔵 **Blue**: Informational/decisions

## Summary Stats

- **Total Endpoints Tested**: 57+
- **Working**: 10 (18%)
- **Missing**: 46 (80%)
- **Errors**: 1 (2%)
- **Major Plants**: 3 (Kårstø, Plant 2, Sleipner)
- **Global Coverage**: 106 plants across 8 operators