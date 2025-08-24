#!/bin/bash
# ===============================================================================
# SQLPlus Wrapper - Easy access to Oracle SQL*Plus
# Usage: ./sqlplus_wrapper.sh [connection_string]
# Default: Connects to TR2000_STAGING if no parameters provided
# ===============================================================================

# Set up Oracle instant client environment
export LD_LIBRARY_PATH="/workspace/TR2000/TR2K/Database/tools/instantclient:$LD_LIBRARY_PATH"
SQLPLUS="/workspace/TR2000/TR2K/Database/tools/instantclient/sqlplus"

# Default connection parameters
DEFAULT_USER="TR2000_STAGING"
DEFAULT_PASS="piping"
DEFAULT_HOST="host.docker.internal"
DEFAULT_PORT="1521"
DEFAULT_SID="XEPDB1"

# If no arguments provided, use default connection
if [ $# -eq 0 ]; then
    echo "Connecting to default database: $DEFAULT_USER@$DEFAULT_HOST:$DEFAULT_PORT/$DEFAULT_SID"
    $SQLPLUS "$DEFAULT_USER/$DEFAULT_PASS@$DEFAULT_HOST:$DEFAULT_PORT/$DEFAULT_SID"
else
    # Use provided connection string
    $SQLPLUS "$@"
fi