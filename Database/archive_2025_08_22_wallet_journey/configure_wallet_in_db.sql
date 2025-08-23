-- Configure Database to Use Wallet for HTTPS
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ========================================
PROMPT Configuring Wallet in Database
PROMPT ========================================

-- Switch to PDB
ALTER SESSION SET CONTAINER = XEPDB1;

-- Update APEX instance settings for wallet
BEGIN
    DBMS_OUTPUT.PUT_LINE('Updating APEX instance settings...');
    
    -- Check if WALLET_PATH exists, if not insert it
    MERGE INTO APEX_240200.WWV_FLOW_PLATFORM_PREFS t
    USING (SELECT 'WALLET_PATH' as name, 
                  'file:/workspace/TR2000/TR2K/Database/instantclient_21_12/network/admin/wallet' as value 
           FROM dual) s
    ON (t.name = s.name)
    WHEN MATCHED THEN
        UPDATE SET t.value = s.value
    WHEN NOT MATCHED THEN
        INSERT (name, value) VALUES (s.name, s.value);
    
    -- Set auto-login wallet flag
    MERGE INTO APEX_240200.WWV_FLOW_PLATFORM_PREFS t
    USING (SELECT 'AUTO_LOGIN_WALLET' as name, 'Y' as value FROM dual) s
    ON (t.name = s.name)
    WHEN MATCHED THEN
        UPDATE SET t.value = s.value
    WHEN NOT MATCHED THEN
        INSERT (name, value) VALUES (s.name, s.value);
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ APEX instance settings updated');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Verify settings
PROMPT
PROMPT Current APEX instance settings:
SELECT name, value 
FROM APEX_240200.WWV_FLOW_PLATFORM_PREFS
WHERE name IN ('WALLET_PATH', 'AUTO_LOGIN_WALLET', 'ALLOW_PUBLIC_WEBSERVICES')
ORDER BY name;

PROMPT
PROMPT ========================================
PROMPT Wallet configuration complete
PROMPT ========================================