# Oracle HTTPS Wallet Fix Guide for TR2000 ETL (Oracle APEX)

This document summarizes the HTTPS wallet issue described in `ORACLE_HTTPS_WALLET_ISSUE_REPORT.md` and provides a step‑by‑step resolution path that integrates with the TR2000 ETL APEX application and PL/SQL packages.

---

## Problem Recap
- Oracle Database XE + Instant Client cannot validate HTTPS certs without an Oracle Wallet.
- `orapki` (wallet creation tool) is missing in the Instant Client Docker container.
- Result: ORA‑29273 / ORA‑29024 errors when using `APEX_WEB_SERVICE` or `UTL_HTTP`.
- API (`equinor.pipespec-api.presight.com`) uses Let’s Encrypt, so we must load the trust chain into an Oracle Wallet.

---

## 10‑Step Fix

### A) Build the Wallet outside Docker
1. Install **Oracle Administrator Client** on your Windows host (includes `orapki`).
2. Create a wallet directory, e.g. `C:\wallets\tr2000`.
3. Create auto‑login wallet:  
   ```bat
   orapki wallet create -wallet C:\wallets\tr2000 -auto_login
   ```
4. Import Let’s Encrypt root and intermediate certs:  
   ```bat
   orapki wallet add -wallet C:\wallets\tr2000 -trusted_cert -cert ISRG-Root-X1.pem
   orapki wallet add -wallet C:\wallets\tr2000 -trusted_cert -cert LE-Intermediate.pem
   ```
5. Verify contents:  
   ```bat
   orapki wallet display -wallet C:\wallets\tr2000 -complete
   ```

### B) Deploy Wallet to Container
6. Copy wallet folder into bind‑mounted path:  
   `/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet/tr2000`

### C) Wire Up Oracle
7. In **UTL_HTTP** sessions:  
   ```sql
   BEGIN
     UTL_HTTP.set_wallet('file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet/tr2000', NULL);
   END;
   /
   ```
8. In **APEX_WEB_SERVICE** calls:  
   ```sql
   v_resp := apex_web_service.make_rest_request(
       p_url         => 'https://equinor.pipespec-api.presight.com/plants',
       p_http_method => 'GET',
       p_wallet_path => 'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet/tr2000',
       p_wallet_pwd  => NULL
   );
   ```
9. (Optional) Configure `sqlnet.ora` with:
   ```
   WALLET_LOCATION = (SOURCE=(METHOD=FILE)(METHOD_DATA=(DIRECTORY=/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet/tr2000)))
   SSL_SERVER_DN_MATCH = TRUE
   ```
10. Smoke test:  
   ```sql
   SET SERVEROUTPUT ON
   BEGIN
     UTL_HTTP.set_wallet('file:/workspace/.../wallet/tr2000', NULL);
     DBMS_OUTPUT.put_line(utl_http.request('https://equinor.pipespec-api.presight.com/plants'));
   END;
   /
   ```

---

## Integration with TR2000 Codebase
- **APEX App** (`APEX_APPLICATION_DESIGN.md`): Buttons and processes calling `pkg_api_client.refresh_*` will work once wallet path is valid.
- **PL/SQL Packages** (`Master_DDL.sql`): `pkg_api_client.fetch_*` functions must either set the wallet explicitly or rely on `sqlnet.ora`.

---

## Pitfalls
- Wallet path must use `file:/...` prefix (Linux style).
- Import both root and intermediate certs.
- Ensure Oracle user can read wallet files.
- DN matching must succeed (`equinor.pipespec-api.presight.com`).

---

## Alternatives if Wallet Is Impossible
1. Reverse proxy HTTPS→HTTP internally (nginx).  
2. Move API calls to app layer (C#/Python) and insert JSON to `RAW_JSON`.  

---

## Next Steps
- Run the smoke test with the new wallet.  
- Update `pkg_api_client` comments (“UTL_HTTP proven to work”) once verified.  
- Proceed with APEX 2‑page application build (`tasks-tr2000-etl.md`).

---

*Prepared for TR2000 ETL Project – August 2025*
