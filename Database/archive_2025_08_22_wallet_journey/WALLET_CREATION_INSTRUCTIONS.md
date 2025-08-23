# Oracle Wallet Creation Instructions for TR2000 ETL

## Prerequisites
You need Oracle Instant Client with Tools package installed on your local machine (Windows/Mac/Linux).

### Download Links:
- [Oracle Instant Client Downloads](https://www.oracle.com/database/technologies/instant-client/downloads.html)
- Download both:
  1. **Instant Client Package - Basic**
  2. **Instant Client Package - Tools** (contains orapki)

## Step 1: Create Wallet Directory
```bash
mkdir tr2000_wallet
cd tr2000_wallet
```

## Step 2: Create the Oracle Wallet
```bash
# Create auto-login wallet (no password needed at runtime)
orapki wallet create -wallet . -auto_login_local -pwd WalletPass123

# Verify wallet was created
ls -la
# Should see: cwallet.sso and ewallet.p12
```

## Step 3: Add Certificates to Wallet

The certificates are already prepared in this directory:
- `isrgrootx1.pem` - Let's Encrypt ISRG Root X1
- `cert_00` - Server certificate
- `cert_01` - Intermediate certificate (R10 or R3)

```bash
# Add root certificate
orapki wallet add -wallet . -trusted_cert -cert isrgrootx1.pem -pwd WalletPass123

# Add intermediate certificate
orapki wallet add -wallet . -trusted_cert -cert cert_01 -pwd WalletPass123

# Display wallet contents to verify
orapki wallet display -wallet . -pwd WalletPass123
```

## Step 4: Test Wallet (Optional)
```bash
# List certificates in wallet
orapki wallet display -wallet . -summary -pwd WalletPass123
```

## Step 5: Copy Wallet Files to Container

After creating the wallet, you'll have these files:
- `cwallet.sso` (auto-login wallet)
- `ewallet.p12` (password-protected wallet)

Copy these to the container's wallet directory:
```bash
# From your host machine:
docker cp cwallet.sso <container_id>:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet/
docker cp ewallet.p12 <container_id>:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet/
```

Or if you're using WSL/mounted volumes, simply copy to:
`/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet/`

## Expected Output
After successful wallet creation and certificate import:
```
Oracle PKI Tool Release 21.0.0.0.0 - Production
Copyright (c) 2004, 2021, Oracle and/or its affiliates. All rights reserved.

Requested Certificates:
User Certificates:
Trusted Certificates:
Subject:        CN=ISRG Root X1,O=Internet Security Research Group,C=US
Subject:        CN=R10,O=Let's Encrypt,C=US
```

## Verification
Once the wallet files are in place, test with:
```sql
DECLARE
    v_response VARCHAR2(4000);
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',
        p_http_method => 'GET',
        p_wallet_path => 'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet',
        p_wallet_pwd => NULL  -- Auto-login wallet doesn't need password
    );
    DBMS_OUTPUT.PUT_LINE('Success! Length: ' || LENGTH(v_response));
END;
/
```

## Notes
- The wallet password is only needed during creation/modification
- At runtime, the auto-login wallet (cwallet.sso) allows passwordless access
- Both files (cwallet.sso and ewallet.p12) should be copied together