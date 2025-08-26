-- ===============================================================================
-- Fix Oracle Wallet Certificates for TR2000 API
-- ===============================================================================
-- Run this on your Windows host machine to add the required certificates
-- ===============================================================================

-- STEP 1: Export Certificate from Browser (Manual)
-- ------------------------------------------------
-- 1. Open Chrome or Edge browser
-- 2. Navigate to: https://equinor.pipespec-api.presight.com (WORKING API)
-- 3. Click the padlock icon in the address bar
-- 4. Click "Connection is secure" or similar
-- 5. Click "Certificate is valid" or the certificate icon
-- 6. In the certificate dialog:
--    - Go to "Details" tab
--    - Click "Copy to File..." or "Export..."
--    - Save as: C:\temp\equinor-api.cer (Base-64 encoded X.509)
-- 7. Also export the intermediate certificates if shown (usually 2-3 total)

-- STEP 2: Add Certificate to Oracle Wallet (Run as Admin in CMD)
-- ---------------------------------------------------------------
/*
cd C:\app\vivek\product\21c\dbhomeXE\bin

rem View current wallet contents
orapki wallet display -wallet C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet -pwd WalletPass123

rem Add the API certificate
orapki wallet add -wallet C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet -trusted_cert -cert C:\temp\equinor-api.cer -pwd WalletPass123

rem If you have intermediate certificates, add them too
orapki wallet add -wallet C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet -trusted_cert -cert C:\temp\intermediate1.cer -pwd WalletPass123
orapki wallet add -wallet C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet -trusted_cert -cert C:\temp\intermediate2.cer -pwd WalletPass123

rem Verify the certificates were added
orapki wallet display -wallet C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet -pwd WalletPass123
*/

-- STEP 3: Test the Connection (Run in SQL*Plus)
-- ----------------------------------------------
SET SERVEROUTPUT ON

DECLARE
    v_response CLOB;
BEGIN
    v_response := apex_web_service.make_rest_request(
        p_url => 'https://equinor.pipespec-api.presight.com/plants',  -- WORKING URL (no /v1!)
        p_http_method => 'GET',
        p_wallet_path => 'file:C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet',
        p_wallet_pwd => 'WalletPass123'
    );
    
    DBMS_OUTPUT.PUT_LINE('SUCCESS! API is working!');
    DBMS_OUTPUT.PUT_LINE('Response length: ' || LENGTH(v_response) || ' bytes');
    DBMS_OUTPUT.PUT_LINE('First 500 chars: ' || SUBSTR(v_response, 1, 500));
    
    -- Parse to see how many plants
    SELECT COUNT(*) INTO v_count
    FROM JSON_TABLE(v_response, '$.getPlant[*]'
        COLUMNS (PlantID NUMBER PATH '$.PlantID')
    );
    DBMS_OUTPUT.PUT_LINE('Total plants in API: ' || v_count);
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FAILED: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('If certificate error, repeat Step 1-2');
        DBMS_OUTPUT.PUT_LINE('If still failing, try restarting Oracle service');
END;
/

-- STEP 4: Alternative - Use PowerShell to Download Certificates
-- -------------------------------------------------------------
/*
# Run this in PowerShell as Administrator
$url = "https://tr2000api.equinor.com"
$port = 443

# Get certificate chain
$tcpClient = New-Object System.Net.Sockets.TcpClient($url.Replace("https://",""), $port)
$sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, {$true})
$sslStream.AuthenticateAsClient($url.Replace("https://",""))
$cert = $sslStream.RemoteCertificate

# Export main certificate
$certBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
[System.IO.File]::WriteAllBytes("C:\temp\tr2000api.cer", $certBytes)

Write-Host "Certificate exported to C:\temp\tr2000api.cer"
Write-Host "Now run the orapki commands from Step 2"
*/

-- STEP 5: If All Else Fails - Download Common Root CAs
-- -----------------------------------------------------
/*
rem Download common root certificates that APIs often use
curl -o C:\temp\letsencrypt-root.pem https://letsencrypt.org/certs/isrgrootx1.pem
curl -o C:\temp\digicert-root.pem https://cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem
curl -o C:\temp\globalsign-root.pem https://secure.globalsign.com/cacert/root-r3.crt

rem Add them to wallet
orapki wallet add -wallet C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet -trusted_cert -cert C:\temp\letsencrypt-root.pem -pwd WalletPass123
orapki wallet add -wallet C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet -trusted_cert -cert C:\temp\digicert-root.pem -pwd WalletPass123
orapki wallet add -wallet C:\app\vivek\product\21c\dbhomeXE\network\admin\wallet -trusted_cert -cert C:\temp\globalsign-root.pem -pwd WalletPass123
*/

-- ===============================================================================
-- Quick Test After Certificate Installation
-- ===============================================================================
DECLARE
    v_status VARCHAR2(50);
    v_msg VARCHAR2(4000);
BEGIN
    pkg_api_client.refresh_plants_from_api(v_status, v_msg);
    DBMS_OUTPUT.PUT_LINE('Status: ' || v_status);
    DBMS_OUTPUT.PUT_LINE('Message: ' || v_msg);
    
    IF v_status = 'SUCCESS' THEN
        SELECT COUNT(*) INTO v_count FROM PLANTS WHERE is_valid = 'Y';
        DBMS_OUTPUT.PUT_LINE('Plants loaded: ' || v_count);
    END IF;
END;
/