# Database & APEX Version Control Guide

## The Challenge

Unlike traditional web apps where code = files, database development has:
- **State in the database** (tables, data, compiled procedures)
- **APEX apps as metadata** (stored in Oracle tables, not files)
- **DDL is destructive** (DROP TABLE loses data)
- **Order matters** (can't create view before table exists)

## Best Practices for Database Version Control

### 1. Migration-Based Approach (Recommended)

Instead of one huge Master_DDL.sql, use numbered migration scripts:

```
Database/
├── migrations/
│   ├── V001__initial_schema.sql
│   ├── V002__add_plants_table.sql
│   ├── V003__add_etl_procedures.sql
│   ├── V004__fix_issue_columns.sql
│   └── V005__add_apex_views.sql
├── rollback/
│   ├── R001__drop_initial_schema.sql
│   ├── R002__drop_plants_table.sql
│   └── R003__drop_etl_procedures.sql
└── current_state/
    └── full_schema.sql  # Generated from DB
```

**Benefits:**
- ✅ Can track exactly what changed when
- ✅ Can rollback specific changes
- ✅ Clear history in git
- ✅ Multiple developers can work without conflicts

### 2. Version Table in Database

```sql
CREATE TABLE schema_version (
    version_id NUMBER PRIMARY KEY,
    version VARCHAR2(50),
    description VARCHAR2(500),
    script_name VARCHAR2(200),
    applied_date TIMESTAMP DEFAULT SYSTIMESTAMP,
    applied_by VARCHAR2(50) DEFAULT USER,
    checksum VARCHAR2(100),
    execution_time NUMBER
);
```

Track what's been applied:
```sql
-- Before applying migration
INSERT INTO schema_version (version_id, version, description, script_name)
VALUES (4, 'V004', 'Fix issue columns', 'V004__fix_issue_columns.sql');
```

### 3. Flyway or Liquibase Integration

Professional tools that handle this automatically:

**Flyway Example:**
```bash
flyway.url=jdbc:oracle:thin:@localhost:1521:XEPDB1
flyway.user=TR2000_STAGING
flyway.password=xxx
flyway.locations=filesystem:./Database/migrations

# Apply migrations
flyway migrate

# See status
flyway info

# Undo last migration
flyway undo
```

### 4. Separate Code from Schema

```
Database/
├── schema/           # Tables, indexes (rarely change)
│   ├── tables/
│   └── indexes/
├── code/            # Procedures, packages (change often)
│   ├── packages/
│   ├── procedures/
│   └── functions/
└── data/            # Reference data
    └── lookups/
```

**Why?** Code can be replaced safely (CREATE OR REPLACE), schema cannot.

## APEX Version Control Best Practices

### 1. Export APEX App Regularly

```sql
-- Export from command line
BEGIN
    apex_application_install.get_application(
        p_application_id => 100,
        p_split => true,  -- Split into multiple files!
        p_with_date => false
    );
END;
/
```

This creates:
```
f100/
├── application/
│   ├── pages/
│   │   ├── page_00001.sql
│   │   └── page_00002.sql
│   ├── shared_components/
│   └── user_interfaces/
└── install.sql
```

**Now each page is a separate file - much better for git!**

### 2. APEX Development Workflow

```bash
# 1. Export current version before changes
apex export -applicationid 100 -instance localhost

# 2. Make changes in APEX Builder

# 3. Export new version
apex export -applicationid 100 -instance localhost

# 4. Compare and commit
git diff f100/
git add f100/
git commit -m "feat: Added validation to plant selection"
```

### 3. APEX with CI/CD

```yaml
# .github/workflows/apex-deploy.yml
name: Deploy APEX App
on:
  push:
    branches: [main]
    paths:
      - 'f100/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install SQLcl
        run: |
          wget https://download.oracle.com/otn/java/sqldeveloper/sqlcl.zip
          unzip sqlcl.zip
          
      - name: Deploy APEX App
        run: |
          sql sys/${{ secrets.DB_PASSWORD }}@${{ secrets.DB_CONNECTION }} as sysdba <<EOF
          ALTER SESSION SET CURRENT_SCHEMA = TR2000_STAGING;
          @f100/install.sql
          EOF
```

## Practical Example: Our TR2000 Project

### Current Structure (Monolithic - Hard to Track)
```sql
-- Master_DDL.sql (60KB - everything mixed)
DROP TABLE plants CASCADE CONSTRAINTS;
CREATE TABLE plants (...);
DROP PACKAGE pkg_etl_operations;
CREATE PACKAGE pkg_etl_operations AS ...
```

### Better Structure (Migration-Based)
```sql
-- migrations/V001__initial_setup.sql
CREATE TABLE plants (...);

-- migrations/V002__add_etl_package.sql  
CREATE OR REPLACE PACKAGE pkg_etl_operations AS ...

-- migrations/V003__add_apex_views.sql
CREATE OR REPLACE VIEW v_apex_dashboard_stats AS ...

-- rollback/R003__remove_apex_views.sql
DROP VIEW v_apex_dashboard_stats;
```

### Git Workflow with Migrations

```bash
# Developer A adds new feature
git checkout -b feature/add-references
echo "CREATE TABLE references (...);" > migrations/V006__add_references.sql
git add migrations/V006__add_references.sql
git commit -m "feat: Add references table"
git push origin feature/add-references

# Developer B adds different feature  
git checkout -b feature/add-logging
echo "ALTER TABLE etl_log ADD (user_id NUMBER);" > migrations/V007__enhance_logging.sql
git add migrations/V007__enhance_logging.sql
git commit -m "feat: Enhance ETL logging"
git push origin feature/add-logging

# Both can merge without conflicts!
```

## Tools Comparison

| Tool | Pros | Cons | Best For |
|------|------|------|----------|
| **Manual Scripts** | Simple, no dependencies | Error-prone, no rollback | Small projects |
| **Flyway** | Popular, simple, Java-based | Limited rollback | Most projects |
| **Liquibase** | Powerful, multiple formats | Complex | Enterprise |
| **Oracle SQLcl** | Native Oracle, free | Oracle-only | APEX projects |
| **RedGate** | GUI, comprehensive | Expensive | Large teams |

## Recommended Setup for TR2000

### 1. Immediate Improvements
```bash
# Split Master_DDL.sql into migrations
mkdir -p Database/migrations Database/rollback

# Create migration from current state
echo "-- V001: Initial schema from Master_DDL" > Database/migrations/V001__initial_schema.sql
# Copy CREATE statements only (no DROPs)

# Future changes as new files
echo "ALTER TABLE plants ADD (last_sync DATE);" > Database/migrations/V002__add_sync_column.sql
```

### 2. APEX Version Control
```bash
# Create APEX export directory
mkdir -p apex_app/f100

# Export with SQLcl (split mode)
sql TR2000_STAGING/password@localhost:1521/XEPDB1 <<EOF
apex export -applicationid 100 -split
EOF

# Now you can track individual page changes!
git add apex_app/f100/application/pages/page_00001.sql
git commit -m "fix: Correct validation on plant selector"
```

### 3. Development Workflow
```bash
# Starting new feature
git checkout -b feature/new-report

# Database changes
echo "CREATE VIEW v_new_report AS ..." > Database/migrations/V008__add_report_view.sql

# APEX changes (after making in Builder)
./scripts/export_apex.sh  # Your export script

# Commit both together
git add Database/migrations/V008* apex_app/f100/
git commit -m "feat: Add new ETL status report"

# Deploy to test
./scripts/deploy_to_test.sh

# Merge to main
git checkout main
git merge feature/new-report
```

## Recovery Scenarios

### Scenario 1: Revert Database Change
```bash
# Bad migration applied
sqlplus @migrations/V009__broken_change.sql  # Oh no!

# Revert using rollback script
sqlplus @rollback/R009__undo_broken_change.sql

# Fix and reapply
vim migrations/V009__broken_change.sql
sqlplus @migrations/V009__broken_change.sql
```

### Scenario 2: Restore APEX Page
```bash
# Broke page 2 in APEX Builder

# Restore from git
git checkout HEAD -- apex_app/f100/application/pages/page_00002.sql

# Reimport just that page
sqlplus <<EOF
@apex_app/f100/application/pages/page_00002.sql
EOF
```

### Scenario 3: Full Environment Reset
```bash
# Complete rebuild from git
git pull origin main

# Reset database
sqlplus sys/password as sysdba <<EOF
DROP USER TR2000_STAGING CASCADE;
CREATE USER TR2000_STAGING ...;
GRANT ...;
EOF

# Apply all migrations in order
for f in Database/migrations/V*.sql; do
    echo "Applying $f"
    sqlplus TR2000_STAGING/password @$f
done

# Import APEX app
sqlplus TR2000_STAGING/password @apex_app/f100/install.sql
```

## Summary

### DO:
✅ Use migrations for incremental changes
✅ Export APEX apps in split mode
✅ Keep rollback scripts
✅ Version control everything
✅ Test migrations on a copy first
✅ Use CREATE OR REPLACE for code
✅ Document dependencies

### DON'T:
❌ Edit Master_DDL.sql for changes (append migrations)
❌ Use DROP in production without backup
❌ Forget to export APEX after changes
❌ Mix schema and code changes
❌ Apply migrations out of order

## Next Steps for TR2000

1. **Split Master_DDL.sql** into versioned migrations
2. **Add schema_version** table
3. **Create export script** for APEX
4. **Setup Flyway** (optional but recommended)
5. **Document process** for team

This approach gives you the same version control benefits as web apps!