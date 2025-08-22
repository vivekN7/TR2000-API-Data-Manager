# Data Architecture Decision Record (DADR) — TR2000 ETL

### Context
The TR2000 ETL project must ingest Equinor TR2000 API data into Oracle (`TR2000_STAGING` schema) in a manner that is **auditable, simple, efficient, and free of DBA-only dependencies**. This record documents major data architecture decisions for clarity and governance.

---

### Decision 1: RAW_JSON as First Landing Zone
- **Decision**: All API responses are first stored in `RAW_JSON` with metadata (hash, source, processed flag).  
- **Alternatives considered**:
  - Load API → STG directly (faster, but no audit/replay).  
  - Store API dumps as files outside DB (adds ops complexity).  
- **Consequences**:
  - ✅ Full audit trail and replay capability.  
  - ✅ Schema drift protection.  
  - ❌ Requires purge strategy to avoid unbounded growth.  

---

### Decision 2: Soft Validity Model in CORE
- **Decision**: Maintain **one row per business key** in CORE tables with `is_valid` flag. No full SCD2 history.  
- **Alternatives considered**:
  - SCD2 with duplicate rows for every change (adds complexity and bloat).  
  - Hard deletes for removals (loses history).  
- **Consequences**:
  - ✅ Current-state tables remain simple and performant.  
  - ✅ History retained through `is_valid` transitions and timestamps.  
  - ❌ Limited ability to analyze historical “as-was” states.  

---

### Decision 3: Metadata-Driven ETL
- **Decision**: Use `CONTROL_ENDPOINTS`, `CONTROL_SETTINGS`, and `CONTROL_ENDPOINT_STATE` to drive ETL dynamically.  
- **Alternatives considered**:
  - Hardcode endpoints and table mappings in procedures.  
- **Consequences**:
  - ✅ Flexible, new endpoints can be added without code changes.  
  - ✅ Easier testing of multiple endpoints.  
  - ❌ Slight upfront overhead to maintain metadata.  

---

### Decision 4: Purge & Retention
- **Decision**: RAW_JSON retention managed by **user-owned procedure** `pr_purge_raw_json`, callable only by `TR2000_STAGING`. No DBA policies.  
- **Alternatives considered**:
  - DBA-managed ILM/partitioning (not acceptable due to scope).  
  - Never purge (risk of uncontrolled growth).  
- **Consequences**:
  - ✅ Fully within schema-owner control.  
  - ✅ Transparent and auditable purge process.  
  - ❌ Requires manual/triggered invocation to enforce retention.  

---

### Decision 5: Error Handling & Monitoring
- **Decision**: Use `ETL_RUN_LOG` and `ETL_ERROR_LOG` (plus optional KPI table) for monitoring. Dashboards via APEX or C#.  
- **Alternatives considered**:
  - Reject tables per endpoint (too complex).  
  - Silent failures with only console logs (not auditable).  
- **Consequences**:
  - ✅ Unified error tracking and visibility.  
  - ✅ Lightweight, schema-only solution (no external monitoring system needed).  

---

### Decision 6: Governance of DDL
- **Decision**: Maintain a single `Master_DDL.sql`. Only Vivek executes it. All changes versioned in Git.  
- **Alternatives considered**:
  - Allow auto-DDL generation/deployment by AI/tools (security risk).  
  - Use DBA-managed migrations (out of scope).  
- **Consequences**:
  - ✅ Controlled and secure schema changes.  
  - ❌ Requires manual execution step for every schema update.  

---

### Decision 7: C# ORM
- **Decision**: Use Dapper ORM for all database access in C#.  
- **Alternatives considered**:
  - Entity Framework (too heavy, not needed).  
  - Raw ADO.NET (verbose, error-prone).  
- **Consequences**:
  - ✅ Lightweight and efficient.  
  - ✅ Easy mapping to views with `is_valid='Y'`.  
  - ❌ Less built-in tooling than EF.  

---

## Future Decisions to Revisit
- Authentication/security strategy (currently internal network).  
- Backup/archiving strategy if retention requirements change.  
- Integration points with downstream pipe class sheet DB.  
- Whether APEX or C# will own orchestration long-term.  

---

*Document Version: 1.0*  
*Created: 2025-08-22*  
*Audience: Development team, System administrators, Data engineers*  
