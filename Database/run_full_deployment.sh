#!/bin/bash
# Full deployment script with auto-confirmation

echo "🚀 Starting full modular deployment..."
echo "⚠️  This will DROP and RECREATE everything!"
echo ""

# Set Oracle environment
export LD_LIBRARY_PATH=/workspace/TR2000/TR2K/Database/tools/instantclient:$LD_LIBRARY_PATH

# Run deployment with auto-confirm (pipe empty lines for PAUSE commands)
cd /workspace/TR2000/TR2K/Database
echo -e "\n\n\n\n\n" | /workspace/TR2000/TR2K/Database/tools/instantclient/sqlplus TR2000_STAGING/piping@host.docker.internal:1521/XEPDB1 @deploy/deploy_full.sql

echo "✅ Deployment complete!"