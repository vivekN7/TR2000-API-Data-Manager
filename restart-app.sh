#!/bin/bash

# Kill any existing dotnet run processes
echo "🔄 Stopping existing dotnet processes..."
pkill -f "dotnet run" 2>/dev/null || true
sleep 2

# Export PATH for dotnet
export PATH="$PATH:$HOME/.dotnet"

# Change to app directory
cd /workspace/TR2000/TR2K/TR2KApp

# Start the application with hot reload enabled
echo "🚀 Starting TR2K application on port 5002..."
echo "📌 Access at: http://localhost:5002"
echo "🔥 Hot reload is enabled - changes will auto-refresh"
echo ""

# Run with hot reload support
DOTNET_WATCH_SUPPRESS_LAUNCH_BROWSER=1 dotnet watch run --urls "http://0.0.0.0:5002"