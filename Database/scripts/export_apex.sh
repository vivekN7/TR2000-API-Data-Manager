#!/bin/bash
# ===============================================================================
# Export APEX Application for Version Control
# Usage: ./export_apex.sh [app_id] [workspace]
# ===============================================================================

# Configuration
APP_ID="${1:-100}"
WORKSPACE="${2:-TR2000_ETL}"
DB_USER="${DB_USER:-TR2000_STAGING}"
DB_PASS="${DB_PASS:-justkeepswimming}"
DB_HOST="${DB_HOST:-host.docker.internal}"
DB_PORT="${DB_PORT:-1521}"
DB_SID="${DB_SID:-XEPDB1}"
EXPORT_DIR="apex_exports/f${APP_ID}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=========================================="
echo "APEX Application Export"
echo "=========================================="
echo "Application ID: $APP_ID"
echo "Workspace: $WORKSPACE"
echo "Export Directory: $EXPORT_DIR"
echo ""

# Create export directory if it doesn't exist
mkdir -p "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR/backups"

# Backup existing export if it exists
if [ -d "$EXPORT_DIR/application" ]; then
    echo "Backing up existing export..."
    tar -czf "$EXPORT_DIR/backups/backup_${TIMESTAMP}.tar.gz" \
        -C "$EXPORT_DIR" application install.sql 2>/dev/null
    rm -rf "$EXPORT_DIR/application" "$EXPORT_DIR/install.sql"
fi

# Create export script
cat > /tmp/apex_export.sql <<EOF
SET SERVEROUTPUT ON
SET FEEDBACK OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 1000

-- Set APEX environment
BEGIN
    apex_application_install.set_workspace('$WORKSPACE');
    apex_application_install.set_application_id($APP_ID);
END;
/

-- Export application in split mode
DECLARE
    l_files apex_t_export_files;
    l_clob CLOB;
    l_file_name VARCHAR2(255);
    l_file UTL_FILE.FILE_TYPE;
    l_buffer VARCHAR2(32767);
    l_amount NUMBER;
    l_pos NUMBER := 1;
BEGIN
    -- Export the application
    l_files := apex_export.get_application(
        p_application_id => $APP_ID,
        p_split => TRUE,  -- Split into multiple files
        p_with_date => FALSE,
        p_with_ir_public_reports => TRUE,
        p_with_ir_private_reports => FALSE,
        p_with_ir_notifications => TRUE,
        p_with_translations => TRUE,
        p_with_pkg_app_mapping => FALSE,
        p_with_original_ids => TRUE,
        p_with_no_subscriptions => FALSE,
        p_with_comments => TRUE,
        p_with_supporting_objects => 'Y',
        p_with_acl_assignments => TRUE
    );
    
    DBMS_OUTPUT.PUT_LINE('Export complete. Files: ' || l_files.COUNT);
    
    -- Process each file
    FOR i IN 1 .. l_files.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('File ' || i || ': ' || l_files(i).name);
        -- Note: Actual file writing would need directory object in Oracle
    END LOOP;
END;
/

-- Alternative: Simple export to single file
SPOOL $EXPORT_DIR/f${APP_ID}.sql

SELECT 'prompt --application/set_environment' FROM dual;
SELECT text FROM (
    SELECT line, text
    FROM apex_application_export
    WHERE application_id = $APP_ID
    ORDER BY line
);

SPOOL OFF

EXIT
EOF

echo "Exporting APEX application..."

# Execute export
sqlplus -s "$DB_USER/$DB_PASS@$DB_HOST:$DB_PORT/$DB_SID" @/tmp/apex_export.sql > /tmp/apex_export.log 2>&1

# Check if export was successful
if [ -f "$EXPORT_DIR/f${APP_ID}.sql" ]; then
    echo "✓ Export successful!"
    
    # Split the export file into components (basic split)
    echo "Splitting export into components..."
    
    mkdir -p "$EXPORT_DIR/application/pages"
    mkdir -p "$EXPORT_DIR/application/shared_components"
    mkdir -p "$EXPORT_DIR/application/user_interfaces"
    
    # Extract pages (basic pattern matching)
    grep -n "^prompt --application/pages/page_" "$EXPORT_DIR/f${APP_ID}.sql" | while read -r line; do
        line_num=$(echo "$line" | cut -d: -f1)
        page_num=$(echo "$line" | grep -o "page_[0-9]*" | sed 's/page_//')
        
        if [ -n "$page_num" ]; then
            echo "  Extracting page $page_num..."
            # Extract from this line to next page or end
            sed -n "${line_num},/^prompt --application\/pages\/page_/p" "$EXPORT_DIR/f${APP_ID}.sql" \
                > "$EXPORT_DIR/application/pages/page_${page_num}.sql"
        fi
    done
    
    # Create install script
    cat > "$EXPORT_DIR/install.sql" <<EOF
-- Install script for application $APP_ID
-- Generated: $(date)

@application/set_environment.sql
@application/delete_application.sql
@application/create_application.sql
@application/user_interfaces.sql
@application/shared_components/navigation/lists.sql
@application/shared_components/logic/application_items.sql
@application/shared_components/logic/application_processes.sql
@application/shared_components/logic/application_computations.sql

-- Install pages
EOF
    
    for page_file in "$EXPORT_DIR/application/pages/"*.sql; do
        if [ -f "$page_file" ]; then
            echo "@application/pages/$(basename "$page_file")" >> "$EXPORT_DIR/install.sql"
        fi
    done
    
    echo "@application/end_environment.sql" >> "$EXPORT_DIR/install.sql"
    
    echo ""
    echo "Export structure created:"
    echo "  $EXPORT_DIR/"
    echo "  ├── f${APP_ID}.sql (complete export)"
    echo "  ├── install.sql (installation script)"
    echo "  └── application/"
    echo "      ├── pages/"
    echo "      ├── shared_components/"
    echo "      └── user_interfaces/"
    
else
    echo "✗ Export failed. Check /tmp/apex_export.log for details"
    cat /tmp/apex_export.log
    exit 1
fi

# Git operations
echo ""
echo "Checking for changes..."
cd "$EXPORT_DIR" || exit 1

# Initialize git if needed
if [ ! -d .git ]; then
    git init
fi

# Check for changes
if git diff --quiet && git diff --cached --quiet; then
    echo "No changes detected in APEX application"
else
    echo "Changes detected! Showing diff..."
    git diff --stat
    
    read -p "Commit changes? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter commit message: " commit_msg
        git add -A
        git commit -m "APEX: $commit_msg"
        echo "✓ Changes committed"
    fi
fi

# Cleanup
rm -f /tmp/apex_export.sql /tmp/apex_export.log

echo ""
echo "=========================================="
echo "Export Complete!"
echo "=========================================="

exit 0