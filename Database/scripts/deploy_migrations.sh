#!/bin/bash
# ===============================================================================
# Deploy Database Migrations
# Usage: ./deploy_migrations.sh [environment] [from_version] [to_version]
# ===============================================================================

# Configuration
DB_USER="${DB_USER:-TR2000_STAGING}"
DB_PASS="${DB_PASS:-justkeepswimming}"
DB_HOST="${DB_HOST:-host.docker.internal}"
DB_PORT="${DB_PORT:-1521}"
DB_SID="${DB_SID:-XEPDB1}"
ENVIRONMENT="${1:-development}"
FROM_VERSION="${2:-V000}"
TO_VERSION="${3:-V999}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "TR2000 Database Migration Deployment"
echo "=========================================="
echo "Environment: $ENVIRONMENT"
echo "Database: $DB_USER@$DB_HOST:$DB_PORT/$DB_SID"
echo "Migration Range: $FROM_VERSION to $TO_VERSION"
echo ""

# Function to execute SQL file
execute_sql() {
    local sql_file=$1
    local migration_name=$(basename "$sql_file")
    
    echo -n "Deploying $migration_name... "
    
    # Create temp SQL with error handling
    cat > /tmp/deploy_temp.sql <<EOF
SET SERVEROUTPUT ON
SET ECHO OFF
SET FEEDBACK OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- Start timing
TIMING START migration

-- Run the migration
@$sql_file

-- Record success
BEGIN
    UPDATE schema_version 
    SET success = 'Y'
    WHERE script_name = '$migration_name'
    AND success IS NULL;
    COMMIT;
END;
/

TIMING STOP
EXIT SUCCESS
EOF
    
    # Execute with SQLPlus
    if sqlplus -s "$DB_USER/$DB_PASS@$DB_HOST:$DB_PORT/$DB_SID" @/tmp/deploy_temp.sql > /tmp/migration_output.log 2>&1; then
        echo -e "${GREEN}✓${NC}"
        
        # Extract timing if available
        if grep -q "Elapsed:" /tmp/migration_output.log; then
            timing=$(grep "Elapsed:" /tmp/migration_output.log | tail -1)
            echo "  $timing"
        fi
    else
        echo -e "${RED}✗${NC}"
        echo -e "${RED}Error deploying $migration_name:${NC}"
        cat /tmp/migration_output.log
        
        # Record failure in database
        sqlplus -s "$DB_USER/$DB_PASS@$DB_HOST:$DB_PORT/$DB_SID" <<EOF
BEGIN
    pr_record_migration(
        p_version => SUBSTR('$migration_name', 1, INSTR('$migration_name', '__') - 1),
        p_description => 'Failed migration',
        p_script_name => '$migration_name',
        p_success => 'N',
        p_error_message => 'See deployment logs'
    );
END;
/
EXIT
EOF
        exit 1
    fi
}

# Check current version
echo "Checking current schema version..."
current_version=$(sqlplus -s "$DB_USER/$DB_PASS@$DB_HOST:$DB_PORT/$DB_SID" <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT version FROM v_schema_current_version;
EXIT
EOF
)

if [ -z "$current_version" ]; then
    echo -e "${YELLOW}No version found. Starting from V000${NC}"
    current_version="V000"
else
    echo "Current version: $current_version"
fi

# Find migrations to apply
echo ""
echo "Scanning for migrations..."
migrations_to_apply=()

for migration in migrations/V*.sql; do
    if [ -f "$migration" ]; then
        migration_name=$(basename "$migration")
        migration_version="${migration_name%%__*}"
        
        # Check if migration is in range and not already applied
        if [[ "$migration_version" > "$current_version" ]] && \
           [[ "$migration_version" <= "$TO_VERSION" ]] && \
           [[ "$migration_version" >= "$FROM_VERSION" ]]; then
            migrations_to_apply+=("$migration")
        fi
    fi
done

# Display migrations to apply
if [ ${#migrations_to_apply[@]} -eq 0 ]; then
    echo -e "${GREEN}Database is up to date!${NC}"
    exit 0
fi

echo "Found ${#migrations_to_apply[@]} migration(s) to apply:"
for migration in "${migrations_to_apply[@]}"; do
    echo "  - $(basename "$migration")"
done
echo ""

# Confirm deployment
if [ "$ENVIRONMENT" = "production" ]; then
    read -p "Deploy to PRODUCTION? Type 'yes' to continue: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

# Create backup point
echo "Creating restore point..."
sqlplus -s "$DB_USER/$DB_PASS@$DB_HOST:$DB_PORT/$DB_SID" <<EOF
-- Create a savepoint for this deployment
SAVEPOINT before_deployment;
EXIT
EOF

# Apply migrations
echo ""
echo "Applying migrations..."
for migration in "${migrations_to_apply[@]}"; do
    execute_sql "$migration"
done

echo ""
echo -e "${GREEN}=========================================="
echo "Deployment Complete!"
echo "==========================================${NC}"

# Show final version
final_version=$(sqlplus -s "$DB_USER/$DB_PASS@$DB_HOST:$DB_PORT/$DB_SID" <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT version FROM v_schema_current_version;
EXIT
EOF
)

echo "Final version: $final_version"
echo ""

# Show deployment summary
sqlplus -s "$DB_USER/$DB_PASS@$DB_HOST:$DB_PORT/$DB_SID" <<EOF
SET LINESIZE 200
SET PAGESIZE 50
COLUMN version FORMAT A10
COLUMN description FORMAT A50
COLUMN applied_date FORMAT A20

SELECT version, description, TO_CHAR(applied_date, 'YYYY-MM-DD HH24:MI:SS') as applied_date
FROM schema_version
WHERE success = 'Y'
AND applied_date >= SYSDATE - 1
ORDER BY version_id DESC;
EXIT
EOF

# Cleanup
rm -f /tmp/deploy_temp.sql /tmp/migration_output.log

exit 0