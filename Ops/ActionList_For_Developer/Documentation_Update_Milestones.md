# Documentation Update Milestones

## Purpose
This file tracks when to update various documentation as we complete TR2000 ETL tasks.
Claude should be asked to update these docs at the specified milestones.

## Knowledge Base Documents to Update

### 1. `Apex_UI_Specifications.md`
**Update After:** Task 11 (Build APEX UI for ETL System)
**What to Update:**
- Final UI design decisions
- Page layouts and navigation
- Interactive components implemented
- User workflow documentation

### 2. `ETL_and_Selection_Flow_Documentation.md`
**Update After:** Task 7 (Issue Reference Tables) and Task 10 (BoltTension)
**What to Update:**
- After Task 7: Document reference table cascade logic
- After Task 10: Complete ETL flow with all table types
- Performance metrics from actual runs
- Optimization strategies implemented

### 3. `Quick_References.md`
**Update After:** Each major task completion (7, 8, 9, 10)
**What to Update:**
- New SQL commands for testing
- New package procedures added
- Common troubleshooting scenarios
- Performance tuning parameters

## Lessons Learnt Documents to Update

### 1. `Apex_Wallet_Setup_Guide.md`
**Update After:** Any SSL/HTTPS issues encountered
**What to Update:**
- New certificate issues and solutions
- Additional endpoints requiring special handling
- Timeout configurations for large datasets (VDS)

## Testing Documents to Update

### 1. `Lifecycle_Scenarios_to_Test.md`
**Update After:** Task 6 completion
**What to Update:**
- Add cascade deletion scenarios for reference tables
- Add performance test scenarios for VDS (44,000+ records)
- Add BoltTension calculation verification tests

### 2. `Testing_Procedures.md`
**Update After:** Each ETL backend task (6-9)
**What to Update:**
- Specific test queries for each new table type
- Expected record counts for test plants (JSP2, GRANE)
- API response validation checks

## How to Use This File

When completing a task, check this file for documentation that needs updating.

Example Claude prompt:
```
"We just completed Task 6 (Issue Reference Tables). 
Please update the ETL_and_Selection_Flow_Documentation.md 
to include the reference table cascade logic we implemented."
```

## Current Status (Session 7)
- Tasks 1-5: ✅ Complete
- Task 6: Ready to start
- Documentation: All Knowledge_Base docs retained for future updates
- Session handoffs: Removed (not needed with consolidated process file)