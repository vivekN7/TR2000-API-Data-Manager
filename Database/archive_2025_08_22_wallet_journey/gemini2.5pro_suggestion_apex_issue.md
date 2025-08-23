Of course. Here is the complete solution formatted as a markdown file, which you can share directly.

-----

# Solving the Oracle HTTPS Wallet Issue (`ORA-29024`)

## 1\. Executive Summary

This document outlines the solution to the `ORA-29024: Certificate validation failure` error that is currently blocking the TR2000 ETL project. The root cause is that the Oracle Database, running in a minimal Docker container, requires a proprietary Oracle Wallet to validate SSL certificates for outbound HTTPS calls, but the `orapki` tool needed to create this wallet is not available in the container's Instant Client installation.

The most direct and standard solution is to **create the wallet on an external machine** where the necessary Oracle tools can be installed. The resulting wallet files can then be copied into the Docker container, unblocking all HTTPS calls from `APEX_WEB_SERVICE` and `UTL_HTTP`.

## 2\. The Solution: External Wallet Creation

This approach resolves the issue without altering the project's pure Oracle APEX architecture or requiring additional infrastructure like a reverse proxy.

### Step 1: Download Oracle Tools (on your local machine)

You need the Oracle Instant Client that includes the `orapki` utility.

1.  Navigate to the [Oracle Instant Client Downloads page](https://www.oracle.com/database/technologies/instant-client/downloads.html).
2.  Select your local operating system (e.g., Windows, macOS, or Linux).
3.  Download and unzip the following two packages into a single directory:
      * **Instant Client Package - Basic**
      * **Instant Client Package - Tools** (this contains `orapki`)

### Step 2: Export API SSL Certificates

The database needs the public SSL certificates from the target API to establish trust.

1.  In a web browser, go to the API endpoint: `https://equinor.pipespec-api.presight.com/plants`.
2.  Click the padlock icon in the address bar to view certificate details.
3.  Export the entire certificate chain. You will typically need the **root** and any **intermediate** certificates.
4.  Save each certificate as a separate Base-64 encoded file (e.g., `root.cer`, `intermediate.cer`).

### Step 3: Create the Oracle Wallet with `orapki`

Use the `orapki` command-line tool from the downloaded Instant Client package.

1.  Open a terminal or command prompt and navigate to your Instant Client directory.
2.  Run the following commands to create the wallet and add the certificates you just saved:

<!-- end list -->

```bash
# Create a new, empty wallet directory first
mkdir ./wallet

# Create the wallet with auto-login enabled. This is critical for services.
# It creates the cwallet.sso file which allows access without a password.
orapki wallet create -wallet "./wallet" -auto_login_local -pwd "YourSecurePassword123"

# Add the root certificate to the wallet's trust list.
orapki wallet add -wallet "./wallet" -trusted_cert -cert /path/to/root.cer -pwd "YourSecurePassword123"

# Add the intermediate certificate to the trust list.
orapki wallet add -wallet "./wallet" -trusted_cert -cert /path/to/intermediate.cer -pwd "YourSecurePassword123"
```

After running these commands, your `./wallet` directory will contain `cwallet.sso` and `ewallet.p12`. These are the files the database needs.

### Step 4: Deploy the Wallet to the Docker Container

Copy the generated wallet files into the correct location within the running Docker container.

1.  Use the `docker cp` command:

<!-- end list -->

```bash
# Syntax: docker cp <local_path_to_wallet_dir> <container_name_or_id>:<path_in_container>
docker cp ./wallet your_container_name:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/
```

*Note: The target path is taken from the issue report.*

2.  **(Recommended)** For persistence across container restarts, use a Docker volume mount in your `docker run` command or `docker-compose.yml` file:
      * `--volume /local/path/to/wallet:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet:ro`

### Step 5: Update PL/SQL Code to Use the Wallet

Modify the `pkg_api_client` package to specify the wallet path before making HTTPS calls. This allows you to revert to using the simpler `APEX_WEB_SERVICE` package as intended.

```sql
-- From Master_DDL.sql, update the pkg_api_client body
CREATE OR REPLACE PACKAGE BODY pkg_api_client AS
    
    FUNCTION fetch_plants_json RETURN CLOB IS
        v_response CLOB;
        v_api_base_url VARCHAR2(500);
        v_url VARCHAR2(1000);
    BEGIN
        SELECT setting_value INTO v_api_base_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        v_url := v_api_base_url || 'plants';
        
        -- Set the wallet path. The cwallet.sso file handles authentication.
        apex_web_service.g_wallet_path := 'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet';
        
        -- This call will now succeed
        v_response := apex_web_service.make_rest_request(
            p_url         => v_url,
            p_http_method => 'GET'
        );

        -- It is good practice to reset the global wallet path after use
        apex_web_service.g_wallet_path := NULL;

        RETURN v_response;
    EXCEPTION
        WHEN OTHERS THEN
            apex_web_service.g_wallet_path := NULL; -- Reset on error
            RAISE; -- Re-raise the exception for the caller to handle
    END fetch_plants_json;

    -- Implement the same logic for fetch_issues_json
    FUNCTION fetch_issues_json(p_plant_id VARCHAR2) RETURN CLOB IS
        v_response CLOB;
        v_api_base_url VARCHAR2(500);
        v_url VARCHAR2(1000);
    BEGIN
        SELECT setting_value INTO v_api_base_url
        FROM CONTROL_SETTINGS
        WHERE setting_key = 'API_BASE_URL';
        
        v_url := v_api_base_url || 'plants/' || p_plant_id || '/issues';
        
        apex_web_service.g_wallet_path := 'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet';
        
        v_response := apex_web_service.make_rest_request(
            p_url         => v_url,
            p_http_method => 'GET'
        );
        
        apex_web_service.g_wallet_path := NULL;
        
        RETURN v_response;
    EXCEPTION
        WHEN OTHERS THEN
            apex_web_service.g_wallet_path := NULL;
            RAISE;
    END fetch_issues_json;
    
    -- ... other package functions (calculate_sha256, etc.) ...

END pkg_api_client;
/
```

## 3\. Answering Open Investigation Questions

This solution directly answers the questions posed in the technical report:

  * **Create wallets without `orapki`?** No, the format is proprietary. This external creation method is the standard workaround.
  * **Trust system certificates?** No, Oracle Database maintains its own trust store via the wallet.
  * **Hidden parameter to disable SSL validation?** No, this is not supported in modern, secure database versions.
  * **Use the database's Java VM differently?** This is overly complex and, as observed, often blocked by security policies and network timeouts.
  * **Oracle patches that relax SSL requirements?** No, security requirements are consistently tightened, not relaxed.

## 4\. Next Steps

With the wallet in place, the primary technical blocker is removed. The team can now proceed with **Task 8.0: Build Simplified 2-Page APEX Application**, as all underlying API calls from PL/SQL will now function correctly.