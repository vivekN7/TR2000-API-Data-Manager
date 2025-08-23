#!/bin/bash
# ===============================================================================
# Setup Oracle Instant Client in Docker Environment
# ===============================================================================

echo "========================================="
echo "Installing Oracle Instant Client"
echo "========================================="

# Update package list
apt-get update

# Install required dependencies
apt-get install -y wget unzip libaio1 libaio-dev

# Create Oracle directory
mkdir -p /opt/oracle

# Download Oracle Instant Client (Basic + SQLPlus)
cd /opt/oracle

# Oracle Instant Client 21.x for Linux x86-64
# Basic Package (required)
wget https://download.oracle.com/otn_software/linux/instantclient/2112000/instantclient-basic-linux.x64-21.12.0.0.0dbru.zip

# SQL*Plus Package
wget https://download.oracle.com/otn_software/linux/instantclient/2112000/instantclient-sqlplus-linux.x64-21.12.0.0.0dbru.zip

# Unzip packages
unzip -o instantclient-basic-linux.x64-21.12.0.0.0dbru.zip
unzip -o instantclient-sqlplus-linux.x64-21.12.0.0.0dbru.zip

# Set up environment variables
export ORACLE_HOME=/opt/oracle/instantclient_21_12
export LD_LIBRARY_PATH=$ORACLE_HOME:$LD_LIBRARY_PATH
export PATH=$ORACLE_HOME:$PATH

# Create symbolic links for compatibility
cd $ORACLE_HOME
ln -sf libclntsh.so.21.1 libclntsh.so
ln -sf libocci.so.21.1 libocci.so

# Update library cache
ldconfig

# Add environment variables to bashrc for persistence
echo "" >> ~/.bashrc
echo "# Oracle Instant Client" >> ~/.bashrc
echo "export ORACLE_HOME=/opt/oracle/instantclient_21_12" >> ~/.bashrc
echo "export LD_LIBRARY_PATH=\$ORACLE_HOME:\$LD_LIBRARY_PATH" >> ~/.bashrc
echo "export PATH=\$ORACLE_HOME:\$PATH" >> ~/.bashrc

echo "========================================="
echo "Oracle Instant Client installed!"
echo "Testing sqlplus..."
echo "========================================="

# Test sqlplus
sqlplus -V

echo ""
echo "To connect to your database, use:"
echo "sqlplus TR2000_STAGING/oracle@//localhost:1521/FREEPDB1"
echo ""
echo "Or for easier use, create a tnsnames.ora file"