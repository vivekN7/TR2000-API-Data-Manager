#!/bin/bash
# Create Oracle wallet using openssl

WALLET_DIR="/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet"
mkdir -p $WALLET_DIR
cd $WALLET_DIR

echo "Creating Oracle wallet with openssl..."

# Download the certificate chain
echo "Downloading certificates..."
openssl s_client -showcerts -connect equinor.pipespec-api.presight.com:443 </dev/null 2>/dev/null | \
  sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > cert_chain.pem

# Split the chain into individual certificates
csplit -z -f cert_ cert_chain.pem '/-----END CERTIFICATE-----/+1' '{*}' 2>/dev/null

# Create PKCS#12 file (ewallet.p12) without password
# Oracle expects this format
openssl pkcs12 -export -nokeys -in cert_chain.pem -out ewallet.p12 -passout pass:

# Create the auto-login wallet (cwallet.sso)
# This is trickier - Oracle uses a proprietary format
# We'll create a base64 encoded version as placeholder
echo -n "SSO\001\002\003\004" > cwallet.sso
cat ewallet.p12 >> cwallet.sso

echo "Wallet files created:"
ls -la

echo ""
echo "Testing wallet with openssl..."
openssl pkcs12 -info -in ewallet.p12 -passin pass: -noout && echo "ewallet.p12 is valid PKCS#12"