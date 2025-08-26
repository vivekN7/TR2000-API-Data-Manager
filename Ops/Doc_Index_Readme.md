# TR2000 ETL Documentation Index

## Purpose
This is the master index for all TR2000 ETL system documentation, including technical specifications, operational guides, and testing procedures.

## Documentation Structure

### 📁 Setup Documentation
**Location:** `/workspace/TR2000/TR2K/Ops/Setup/`
- **[process-task-list-tr2k-etl.md](./Setup/process-task-list-tr2k-etl.md)**
  - Task list management guidelines
  - Implementation protocols
  - Completion procedures
  
- **[tasks-tr2k-etl.md](./Setup/tasks-tr2k-etl.md)**
  - Master task list for ETL implementation
  - Current status and progress tracking
  - Detailed task breakdowns
  
- **[prd-tr2k-etl.md](./Setup/prd-tr2k-etl.md)**
  - Product Requirements Document
  - Business requirements and specifications
  
- **[TR2000_API_Endpoints_Documentation.md](./Setup/TR2000_API_Endpoints_Documentation.md)**
  - Complete API endpoint reference
  - Data field mappings
  - Request/response formats

### 📁 Knowledge Base
**Location:** `/workspace/TR2000/TR2K/Ops/Knowledge_Base/`

#### 🎨 User Interface
- **[Apex_UI_Specifications.md](./Knowledge_Base/Apex_UI_Specifications.md)**
  - APEX application specifications
  - Page layouts and components
  - User interaction flows
  - Design requirements

#### 📊 System Architecture
- **[ETL_and_Selection_Flow_Documentation.md](./Knowledge_Base/ETL_and_Selection_Flow_Documentation.md)**
  - Complete ETL flow from API to database
  - Selection management process
  - Package responsibilities and interactions
  - Control flow and error handling
  - Data flow tables and monitoring

#### 🔍 Quick References
- **[Quick_References.md](./Knowledge_Base/Quick_References.md)**
  - Connection information and credentials
  - Common SQL queries and commands
  - Package quick reference
  - Key design patterns
  - API endpoints reference
  - Test data and working commands
  - Current database status

### 📁 Lessons Learnt
**Location:** `/workspace/TR2000/TR2K/Ops/Lessons_Learnt/`

- **[Apex_Wallet_Setup_Guide.md](./Lessons_Learnt/Apex_Wallet_Setup_Guide.md)**
  - Complete guide for fixing APEX HTTPS/wallet issues
  - Network ACL configuration
  - Troubleshooting steps
  - Recovery procedures

### 📁 Action List for Developer
**Location:** `/workspace/TR2000/TR2K/Ops/ActionList_For_Developer/`

- **[Discussion_Points_for_DB_Team.md](./ActionList_For_Developer/Discussion_Points_for_DB_Team.md)**
  - Issues requiring team decisions
  - Architectural considerations
  - Risk assessments
  - Meeting agenda items

### 📁 Testing Documentation
**Location:** `/workspace/TR2000/TR2K/Ops/Testing/`

- **[Testing_Procedures.md](./Testing/Testing_Procedures.md)**
  - Test procedures for all components
  - Error scenario testing
  - Performance testing guidelines
  
- **[Lifecycle_Scenarios_to_Test.md](./Testing/Lifecycle_Scenarios_to_Test.md)**
  - Plant lifecycle test scenarios
  - Data state transitions
  - Edge cases and limitations
  - **Critical: Plant ID change scenario**

### 📁 Database Scripts
**Location:** `/workspace/TR2000/TR2K/Database/`
- **Master_DDL.sql** - Single source of truth for all database objects (includes COMMENT ON statements)

## Document Maintenance Guidelines

### When to Update Each Document

#### Setup Documentation
- **process-task-list-tr2k-etl.md**: Update when task management protocols change
- **tasks-tr2k-etl.md**: Update after completing each task, mark tasks as [x] when done
- **prd-tr2k-etl.md**: Update when business requirements change
- **TR2000_API_Endpoints_Documentation.md**: Update when new API endpoints are discovered or changed

#### Knowledge Base
- **Apex_UI_Specifications.md**: Update when APEX pages or UI requirements change
- **ETL_and_Selection_Flow_Documentation.md**: Update when ETL flow or selection logic changes
- **Quick_References.md**: Update when connection info, common queries, or commands change

#### Lessons Learnt
- **Apex_Wallet_Setup_Guide.md**: Update when wallet/HTTPS issues are resolved or new solutions found

#### Action List for Developer
- **Discussion_Points_for_DB_Team.md**: Update before team meetings with new discussion items

#### Testing Documentation
- **Testing_Procedures.md**: Update when new test scenarios are identified or procedures change
- **Lifecycle_Scenarios_to_Test.md**: Update when new edge cases or critical issues are discovered

### Update Priorities
1. **IMMEDIATE**: Update tasks-tr2k-etl.md after completing tasks
2. **HIGH**: Update Quick_References.md when credentials/connections change
3. **MEDIUM**: Update ETL documentation when flow changes
4. **LOW**: Update discussion points before scheduled meetings

### Linking to Tasks
**IMPORTANT**: When working on tasks in `/workspace/TR2000/TR2K/Ops/Setup/tasks-tr2k-etl.md`:
- Check this Doc_Index_Readme.md for which docs need updating
- No need to read all docs - just update relevant ones based on task
- This saves context and improves efficiency

### Document Owners
- Primary: Development Team
- Review: Database Team
- Approval: Project Stakeholders

---

*Last Updated: 2025-08-24*
*Version: 2.2 - Consolidated documentation and removed session handoffs*