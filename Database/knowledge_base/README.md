# TR2000 ETL Knowledge Base

## Purpose
This knowledge base contains all technical documentation, architectural decisions, and operational guides for the TR2000 ETL system.

## Documents

### 🔧 Setup & Configuration
- **[APEX_WALLET_SETUP_GUIDE.md](./APEX_WALLET_SETUP_GUIDE.md)**
  - Complete guide for fixing APEX HTTPS/wallet issues
  - Network ACL configuration
  - Troubleshooting steps
  - Recovery procedures

### 📊 System Architecture
- **[ETL_FLOW_DOCUMENTATION.md](./ETL_FLOW_DOCUMENTATION.md)**
  - Complete ETL flow from API to database
  - Package responsibilities and interactions
  - Control flow and error handling
  - Who calls what and why

### 🔄 Data Lifecycle
- **[PLANT_LIFECYCLE_SCENARIOS.md](./PLANT_LIFECYCLE_SCENARIOS.md)**
  - What happens when plants are added/deleted/modified
  - Soft delete pattern explanation
  - Edge cases and limitations
  - **Critical: Plant ID change scenario**

### 💬 Team Discussion
- **[DISCUSSION_POINTS_FOR_DB_TEAM.md](./DISCUSSION_POINTS_FOR_DB_TEAM.md)**
  - Issues requiring team decisions
  - Architectural considerations
  - Risk assessments
  - Meeting agenda items

## Quick Reference

### Critical Issues to Monitor
1. **Plant ID Changes** - System cannot detect if API changes a plant_id
2. **Network ACL** - Most common cause of API failures
3. **Wallet Configuration** - Required for HTTPS calls

### Key Design Patterns
- **Soft Delete**: Records marked `is_valid='N'` instead of DELETE
- **SHA256 Deduplication**: Skip processing if API response unchanged
- **Three-Layer Architecture**: RAW_JSON → STG_* → Production tables

### Important Queries
```sql
-- Active plants only
SELECT * FROM PLANTS WHERE is_valid = 'Y';

-- Check ETL history
SELECT * FROM ETL_RUN_LOG ORDER BY start_time DESC;

-- Find potential plant ID changes
SELECT old.plant_id as old_id, new.plant_id as new_id, old.short_description
FROM PLANTS old
JOIN PLANTS new ON old.short_description = new.short_description
WHERE old.is_valid = 'N' AND new.is_valid = 'Y'
  AND old.plant_id != new.plant_id;
```

## Maintenance

### When to Update These Docs
- After any architectural changes
- When new issues are discovered
- After team decisions on discussion points
- When new patterns are implemented

### Document Owners
- Primary: Development Team
- Review: Database Team
- Approval: Project Stakeholders

---

*Last Updated: 2025-08-24*
*Version: 1.0*