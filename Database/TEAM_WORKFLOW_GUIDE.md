# Team Database Development Workflow Guide

## Overview
This guide explains how team members should work with the TR2000 database using the migration-based version control system.

## Quick Reference

### Making Database Changes
```bash
# 1. Create feature branch
git checkout -b feature/add-new-table

# 2. Create migration
echo "CREATE TABLE new_table (...);" > Database/migrations/V004__add_new_table.sql

# 3. Test locally
./Database/scripts/deploy_migrations.sh development

# 4. Commit and push
git add Database/migrations/V004__add_new_table.sql
git commit -m "feat: Add new_table for storing X"
git push origin feature/add-new-table

# 5. Create Pull Request
```

### Making APEX Changes
```bash
# 1. Make changes in APEX Builder

# 2. Export application
./Database/scripts/export_apex.sh 100

# 3. Commit changes
git add Database/apex_exports/
git commit -m "fix: Correct validation on plant selector"
git push
```

## Detailed Workflows

### 1. Adding a New Table

**Never modify existing migrations!** Always create a new migration.

```sql
-- Database/migrations/V004__add_reference_data.sql
-- Author: Your Name
-- Date: 2025-08-23
-- Description: Add reference data table for lookups
-- Dependencies: V001

EXEC pr_record_migration('V004', 'Add reference data table', 'V004__add_reference_data.sql');

CREATE TABLE reference_data (
    ref_id NUMBER PRIMARY KEY,
    ref_type VARCHAR2(50),
    ref_value VARCHAR2(100),
    description VARCHAR2(500)
);

COMMIT;
```

**Also create rollback:**
```sql
-- Database/rollback/R004__remove_reference_data.sql
DROP TABLE reference_data CASCADE CONSTRAINTS;
DELETE FROM schema_version WHERE version = 'V004';
COMMIT;
```

### 2. Modifying a Table

```sql
-- Database/migrations/V005__add_column_to_plants.sql
EXEC pr_record_migration('V005', 'Add last_sync to plants', 'V005__add_column_to_plants.sql');

ALTER TABLE plants ADD (
    last_sync_date TIMESTAMP,
    sync_status VARCHAR2(50)
);

COMMIT;
```

### 3. Updating a Package/Procedure

For code objects, use CREATE OR REPLACE (safe to re-run):

```sql
-- Database/migrations/V006__update_etl_package.sql
EXEC pr_record_migration('V006', 'Update ETL package', 'V006__update_etl_package.sql');

CREATE OR REPLACE PACKAGE BODY pkg_etl_operations AS
    -- Updated implementation
END;
/

COMMIT;
```

### 4. Data Migrations

```sql
-- Database/migrations/V007__migrate_plant_data.sql
EXEC pr_record_migration('V007', 'Migrate plant data', 'V007__migrate_plant_data.sql');

-- Update existing data
UPDATE plants 
SET sync_status = 'PENDING'
WHERE sync_status IS NULL;

-- Insert reference data
INSERT INTO reference_data (ref_type, ref_value)
SELECT DISTINCT 'PLANT_STATUS', status
FROM plants
WHERE status IS NOT NULL;

COMMIT;
```

## Development Process

### Local Development

1. **Check current version:**
```sql
SELECT * FROM v_schema_current_version;
```

2. **Apply new migrations:**
```bash
./Database/scripts/deploy_migrations.sh development
```

3. **Test your changes:**
```sql
-- Run your tests
SELECT * FROM your_new_table;
EXEC your_new_procedure;
```

4. **If something goes wrong, rollback:**
```sql
@Database/rollback/R004__remove_reference_data.sql
```

### Team Collaboration

1. **Before starting work:**
```bash
git pull origin main
./Database/scripts/deploy_migrations.sh development
```

2. **Check what migrations exist:**
```bash
ls Database/migrations/
```

3. **Your migration number should be next in sequence:**
   - Current highest: V003
   - Your migration: V004

4. **Naming convention:**
   - V{number}__{description}.sql
   - Use underscores, not spaces
   - Be descriptive but concise

### Code Review Checklist

When reviewing database PRs, check:

- [ ] Migration number is correct (next in sequence)
- [ ] Rollback script exists
- [ ] Migration has proper header (Author, Date, Description)
- [ ] Uses pr_record_migration at start
- [ ] Has COMMIT at end
- [ ] Rollback actually reverses the migration
- [ ] No modifications to existing migrations
- [ ] APEX export included if UI changed

### Deployment Process

#### To Development:
```bash
./Database/scripts/deploy_migrations.sh development
```

#### To Test:
```bash
export DB_HOST=test-server
./Database/scripts/deploy_migrations.sh test
```

#### To Production:
```bash
# Must be done by DBA
export DB_HOST=prod-server
./Database/scripts/deploy_migrations.sh production
# Will prompt for confirmation
```

## Common Scenarios

### Scenario 1: Conflict Resolution

If two developers create V004 simultaneously:

1. One PR gets merged first
2. Second developer:
```bash
git pull origin main
mv Database/migrations/V004__my_feature.sql Database/migrations/V005__my_feature.sql
mv Database/rollback/R004__my_feature.sql Database/rollback/R005__my_feature.sql
# Update version number inside files too
git add -A
git commit -m "fix: Renumber migration to V005"
git push
```

### Scenario 2: Failed Migration

If a migration fails in production:

1. **Check error:**
```sql
SELECT * FROM schema_version 
WHERE success = 'N' 
ORDER BY applied_date DESC;
```

2. **Run rollback:**
```sql
@Database/rollback/R004__rollback_broken.sql
```

3. **Fix and reapply:**
```sql
-- Fix the issue in V004
@Database/migrations/V004__fixed_version.sql
```

### Scenario 3: APEX Sync Issues

If APEX gets out of sync:

1. **Export current state:**
```bash
./Database/scripts/export_apex.sh 100
```

2. **Compare with git:**
```bash
cd Database/apex_exports/f100
git diff
```

3. **Decide direction:**
   - Keep APEX version: `git add -A && git commit`
   - Keep git version: Reimport from git

## Best Practices

### DO:
✅ One logical change per migration
✅ Test on local database first
✅ Include rollback for every migration
✅ Use descriptive migration names
✅ Export APEX after UI changes
✅ Review schema_version table regularly
✅ Document complex migrations

### DON'T:
❌ Modify existing migrations
❌ Skip version numbers
❌ Mix schema and data in same migration
❌ Use DROP without backup
❌ Deploy untested migrations
❌ Bypass the deployment script
❌ Commit directly to main branch

## Troubleshooting

### Check Migration Status:
```sql
SELECT version, description, applied_date, success
FROM schema_version
ORDER BY version_id DESC
FETCH FIRST 10 ROWS ONLY;
```

### Find Failed Migrations:
```sql
SELECT * FROM schema_version
WHERE success = 'N';
```

### Verify Current State:
```sql
-- Check if your changes were applied
SELECT object_name, object_type, last_ddl_time
FROM user_objects
WHERE last_ddl_time > SYSDATE - 1
ORDER BY last_ddl_time DESC;
```

### Force Recompile:
```sql
BEGIN
    DBMS_UTILITY.compile_schema(schema => USER);
END;
/
```

## Emergency Procedures

### Full Reset (Development Only):
```bash
# WARNING: Destroys all data!
sqlplus sys/password as sysdba <<EOF
DROP USER TR2000_STAGING CASCADE;
CREATE USER TR2000_STAGING...
GRANT...
EXIT
EOF

# Reapply all migrations
for f in Database/migrations/V*.sql; do
    sqlplus TR2000_STAGING/password @$f
done
```

### Production Rollback:
```bash
# Must be approved by team lead
# 1. Take backup
expdp TR2000_STAGING/password schemas=TR2000_STAGING

# 2. Run specific rollback
sqlplus TR2000_STAGING/password @Database/rollback/R004__specific.sql

# 3. Verify
sqlplus TR2000_STAGING/password @Database/scripts/verify_state.sql
```

## Questions?

- Check `DATABASE_VERSION_CONTROL_GUIDE.md` for concepts
- Review existing migrations for examples
- Ask team lead before production changes
- Use development environment for experiments

---
*Last Updated: 2025-08-23*
*Version: 1.0*