# PowerShell script for direct Oracle connection on Windows
# Usage: .\connect_direct.ps1

# Connection parameters
$OracleUser = "TR2000_STAGING"
$OraclePass = "piping"
$OracleHost = "localhost"
$OraclePort = "1521"
$OracleSID = "XEPDB1"

# SQL*Plus path - adjust if your Oracle client is installed elsewhere
$SqlPlusPath = "sqlplus"  # Assumes sqlplus is in PATH

# Connection string
$ConnectionString = "$OracleUser/$OraclePass@$OracleHost`:$OraclePort/$OracleSID"

Write-Host "Connecting to Oracle Database..." -ForegroundColor Green
Write-Host "Connection: $OracleUser@$OracleHost`:$OraclePort/$OracleSID" -ForegroundColor Yellow

# Connect to database
& $SqlPlusPath -S $ConnectionString