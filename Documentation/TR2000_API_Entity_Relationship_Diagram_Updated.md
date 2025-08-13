# TR2000 Pipe Size Specifications Demo Architecture

*Vivek P - 6th August 2025*

## Database Entity Relationship Diagram

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor': '#7b1fa2', 'primaryTextColor': '#000000', 'primaryBorderColor': '#7b1fa2', 'lineColor': '#666666', 'secondaryColor': '#f57c00', 'tertiaryColor': '#2e7d32', 'background': '#ffffff', 'mainBkg': '#ffffff', 'secondBkg': '#f7f7f7', 'tertiaryBkg': '#efefef'}}}%%
erDiagram
    PLANT {
        int PlantID PK "🔑 PRIMARY KEY"
        string LongDescription "Full plant name"
        string ShortDescription "Plant abbreviation"
    }
    
    PCS {
        string PCS PK "🔑 PRIMARY KEY"
        string Revision PK "🔑 PRIMARY KEY"
        int PlantID FK "🔗 REFERENCES Plant.PlantID"
        string Status "Current status"
        string RevDate "Revision date"
        string DimElementChange "Change indicator"
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
        string DimElementChange "Change indicator"
        string ScheduleInMatrix "Y/N matrix inclusion"
    }
    
    %% Relationships with clear reference descriptions
    PLANT ||--o{ PCS : "🔗 PlantID-to-PlantID"
    PCS ||--o{ PIPE_SIZE : "🔗 PCS-and-Revision-to-PCS-and-Revision"
    PLANT ||--o{ PIPE_SIZE : "🔗 PlantID-to-PlantID"
```

## API Endpoint Structure Diagram

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor': '#7b1fa2', 'primaryTextColor': '#ffffff', 'primaryBorderColor': '#7b1fa2', 'lineColor': '#333333', 'secondaryColor': '#f57c00', 'tertiaryColor': '#2e7d32', 'background': '#ffffff', 'mainBkg': '#ffffff', 'clusterTextColor': '#ffffff', 'titleColor': '#ffffff', 'edgeLabelBackground': '#ffffff', 'nodeTextColor': '#000000'}}}%%
graph TB
    subgraph "TR2000 PipeSpec API Structure"
        A["API Base URL<br/>equinor.pipespec-api.presight.com"]
        B["/plants"]
        C["/plants/{plantId}/pcs"]
        D["/plants/{plantId}/pcs/{pcsId}/rev/{revision}/pipe-sizes"]
        
        E["Plant List Response<br/>PlantID, LongDescription, ShortDescription"]
        F["PCS List Response<br/>PCS, Revision, Status, RevDate"]
        G["Pipe Size List Response<br/>NomSize, OuterDiam, WallThickness<br/>Schedule, Tolerances, etc."]
        
        A --> B
        A --> C  
        A --> D
        B --> E
        C --> F
        D --> G
    end
    
    classDef endpoint fill:#fff3e0,stroke:#f57c00,stroke-width:3px,color:#000000
    classDef response fill:#e8f5e8,stroke:#2e7d32,stroke-width:3px,color:#000000
    
    class A,B,C,D endpoint
    class E,F,G response
```

## Data Flow and Relationships

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor': '#7b1fa2', 'primaryTextColor': '#ffffff', 'primaryBorderColor': '#7b1fa2', 'lineColor': '#333333', 'secondaryColor': '#f57c00', 'tertiaryColor': '#2e7d32', 'background': '#ffffff', 'mainBkg': '#ffffff', 'clusterTextColor': '#ffffff', 'titleColor': '#ffffff', 'edgeLabelBackground': '#ffffff', 'nodeTextColor': '#000000'}}}%%
flowchart TD
    subgraph "Hierarchical Data Structure"
        A[Plant Selection] --> B[PCS Selection]
        B --> C[Revision Selection] 
        C --> D[Pipe Size Data]
        
        A1["Plant: Johan Sverdrup<br/>PlantID: 7940"] --> B1["PCS: 13CR-A-001"]
        B1 --> C1["Revision: C2, C3, etc."]
        C1 --> D1["Pipe Sizes:<br/>Half-inch, Three-quarter, One-inch, Two-inch, etc."]
    end
    
    subgraph "Comparison Feature"
        D --> E[Base Revision Data]
        D --> F[Compare Revision Data]
        E --> G[Side-by-side Comparison]
        F --> G
        G --> H["Visual Differences<br/>Old → New Format"]
    end
    
    classDef selection fill:#fff3e0,stroke:#f57c00,stroke-width:3px,color:#000000
    classDef data fill:#e8f5e8,stroke:#2e7d32,stroke-width:3px,color:#000000
    classDef comparison fill:#fce4ec,stroke:#c2185b,stroke-width:3px,color:#000000
    
    class A,B,C,A1,B1,C1 selection
    class D,D1 data
    class E,F,G,H comparison
```

## Detailed Pipe Size Entity Structure

```mermaid
erDiagram
    PIPE_SIZE_DETAILED {
        string NomSize "Nominal pipe size (e.g., '1/2', '3/4', '1')"
        string OuterDiam "Outer diameter in mm"
        string WallThickness "Wall thickness in mm" 
        string Schedule "Pipe schedule (e.g., 'STD', 'XS', '40')"
        string UnderTolerance "Under tolerance percentage"
        string CorrosionAllowance "Corrosion allowance value"
        string WeldingFactor "Welding factor coefficient"
        string DimElementChange "Dimensional element change indicator"
        string ScheduleInMatrix "Y/N - Whether schedule exists in matrix"
        string PCS "Parent PCS identifier"
        string Revision "Parent revision identifier"
        int PlantID "Parent plant identifier"
    }
    
    PCS_REVISION {
        string PCS "PCS identifier (e.g., '13CR-A-001')"
        string Revision "Revision code (e.g., 'C2', 'C3')"
        string Status "Current status"
        string RevDate "Revision date"
        int PlantID "Parent plant ID"
    }
    
    PLANT_MASTER {
        int PlantID "Unique plant identifier"
        string LongDescription "Full plant name"
        string ShortDescription "Plant abbreviation"
    }
    
    PLANT_MASTER ||--o{ PCS_REVISION : "contains"
    PCS_REVISION ||--o{ PIPE_SIZE_DETAILED : "defines"
```

## API Response Structure

```mermaid
classDiagram
    class ApiResponse~T~ {
        +boolean Success
        +List~T~ GetPlant
        +List~T~ GetPCS  
        +List~T~ GetPipeSize
        +string ErrorMessage
    }
    
    class Plant {
        +int PlantID
        +string LongDescription
        +string ShortDescription
    }
    
    class PCSData {
        +string PCS
        +string Revision
        +string Status
        +string RevDate
    }
    
    class PipeSize {
        +string NomSize
        +string OuterDiam
        +string WallThickness
        +string Schedule
        +string UnderTolerance
        +string CorrosionAllowance
        +string WeldingFactor
        +string DimElementChange
        +string ScheduleInMatrix
    }
    
    ApiResponse~T~ --> Plant : contains
    ApiResponse~T~ --> PCSData : contains
    ApiResponse~T~ --> PipeSize : contains
```

## Application Architecture Flow

```mermaid
%%{init: {'theme':'base', 'themeVariables': { 'primaryColor': '#7b1fa2', 'primaryTextColor': '#ffffff', 'primaryBorderColor': '#7b1fa2', 'lineColor': '#333333', 'secondaryColor': '#f57c00', 'tertiaryColor': '#2e7d32', 'background': '#ffffff', 'mainBkg': '#ffffff', 'clusterTextColor': '#ffffff', 'titleColor': '#ffffff', 'edgeLabelBackground': '#ffffff', 'nodeTextColor': '#000000'}}}%%
graph LR
    subgraph "User Interface"
        A[Plant Dropdown] --> B[PCS Dropdown]
        B --> C[Revision Dropdown]
        C --> D[Load Button]
    end
    
    subgraph "API Calls"
        D --> E["GET pipe-sizes endpoint"]
        E --> F[Process Response]
    end
    
    subgraph "Data Display"
        F --> G[Filter Controls]
        F --> H[Comparison Toggle]
        F --> I[Data Grid]
        G --> I
        H --> J[Load Comparison Data]
        J --> I
        I --> K[Export to Excel]
    end
    
    classDef ui fill:#f3e5f5,stroke:#7b1fa2,stroke-width:3px,color:#000000
    classDef api fill:#fff3e0,stroke:#f57c00,stroke-width:3px,color:#000000
    classDef display fill:#e8f5e8,stroke:#2e7d32,stroke-width:3px,color:#000000
    
    class A,B,C,D ui
    class E,F api
    class G,H,I,J,K display
```

## Key Insights from Implementation

### 1. **Hierarchical Structure**: 
- Plant → PCS → Revision → Pipe Sizes
- Each level depends on the previous selection

### 2. **Data Relationships**:
- Plants have multiple PCS systems
- Each PCS can have multiple revisions
- Each revision contains specific pipe size specifications
- Pipe sizes are uniquely identified by Plant+PCS+Revision+NomSize

### 3. **Comparison Logic**:
- Two different revisions of the same PCS can be compared
- Comparison shows: Base Revision → Current Revision
- Null values are properly handled and displayed as "Null"

### 4. **API Response Pattern**:
- All endpoints return similar response structure with Success flag
- Data is contained in specific properties (GetPlant, GetPCS, GetPipeSize)
- Error handling is consistent across all endpoints

This ERD reflects the actual working implementation and API structure discovered during the proof-of-concept development.