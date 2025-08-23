-- ===============================================================================
-- DBA Script: Enable APEX Web Services Directly
-- Run this as SYS or any DBA user
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ========================================
PROMPT Enabling APEX Web Services as DBA
PROMPT ========================================

-- Grant necessary role to current user to manage APEX
DECLARE
    v_current_user VARCHAR2(100);
BEGIN
    SELECT USER INTO v_current_user FROM dual;
    DBMS_OUTPUT.PUT_LINE('Current user: ' || v_current_user);
    
    -- Try to grant APEX_ADMINISTRATOR_ROLE to current user
    IF v_current_user != 'SYS' THEN
        BEGIN
            EXECUTE IMMEDIATE 'GRANT APEX_ADMINISTRATOR_ROLE TO ' || v_current_user;
            DBMS_OUTPUT.PUT_LINE('Granted APEX_ADMINISTRATOR_ROLE to ' || v_current_user);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Could not grant role: ' || SQLERRM);
        END;
    END IF;
END;
/

-- Method 1: Direct update to APEX internal tables (if SET_PARAMETER doesn't work)
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Method 1: Using APEX_INSTANCE_ADMIN API...');
    
    -- Set the APEX security group ID to access admin functions
    APEX_UTIL.SET_SECURITY_GROUP_ID(p_security_group_id => 10);
    
    -- Enable public web services
    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'ALLOW_PUBLIC_WEBSERVICES',
        p_value => 'Y'
    );
    
    -- Also enable logging for debugging
    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'WEBSERVICE_LOGGING',
        p_value => 'Y'
    );
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✓ SUCCESS: Web services enabled via API!');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Method 1 failed: ' || SQLERRM);
        
        -- Method 2: Direct table update (last resort)
        BEGIN
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Method 2: Direct configuration...');
            
            -- Update the internal configuration
            UPDATE APEX_240200.WWV_FLOW_PLATFORM_PREFS
            SET PREF_VALUE = 'Y'
            WHERE PREF_NAME = 'ALLOW_PUBLIC_WEBSERVICES';
            
            IF SQL%ROWCOUNT = 0 THEN
                -- Insert if it doesn't exist
                INSERT INTO APEX_240200.WWV_FLOW_PLATFORM_PREFS (PREF_NAME, PREF_VALUE)
                VALUES ('ALLOW_PUBLIC_WEBSERVICES', 'Y');
            END IF;
            
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('✓ SUCCESS: Direct update completed!');
            
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Method 2 failed: ' || SQLERRM);
        END;
END;
/

-- Verify the setting
PROMPT
PROMPT ========================================
PROMPT Verifying Configuration
PROMPT ========================================

-- Check if it's enabled now
DECLARE
    v_value VARCHAR2(100);
BEGIN
    -- Try to read from the view
    BEGIN
        SELECT value INTO v_value
        FROM apex_instance_parameters
        WHERE name = 'ALLOW_PUBLIC_WEBSERVICES';
        
        DBMS_OUTPUT.PUT_LINE('ALLOW_PUBLIC_WEBSERVICES = ' || v_value);
        
        IF v_value = 'Y' THEN
            DBMS_OUTPUT.PUT_LINE('✓ Web services are ENABLED!');
        ELSE
            DBMS_OUTPUT.PUT_LINE('⚠ Still disabled, may need APEX restart');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Try the internal table
            BEGIN
                SELECT PREF_VALUE INTO v_value
                FROM APEX_240200.WWV_FLOW_PLATFORM_PREFS
                WHERE PREF_NAME = 'ALLOW_PUBLIC_WEBSERVICES';
                
                DBMS_OUTPUT.PUT_LINE('Internal setting: ALLOW_PUBLIC_WEBSERVICES = ' || v_value);
                
                IF v_value = 'Y' THEN
                    DBMS_OUTPUT.PUT_LINE('✓ Web services are ENABLED in configuration!');
                    DBMS_OUTPUT.PUT_LINE('Note: May need to flush shared pool or restart for changes to take effect');
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Could not verify: ' || SQLERRM);
            END;
    END;
END;
/

-- Flush shared pool to apply changes immediately
BEGIN
    EXECUTE IMMEDIATE 'ALTER SYSTEM FLUSH SHARED_POOL';
    DBMS_OUTPUT.PUT_LINE('Shared pool flushed to apply changes');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Could not flush shared pool: ' || SQLERRM);
END;
/

-- Final test
PROMPT
PROMPT ========================================
PROMPT Testing Web Service
PROMPT ========================================

DECLARE
    v_response CLOB;
BEGIN
    apex_web_service.g_request_headers.DELETE;
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    
    DBMS_OUTPUT.PUT_LINE('✓ SUCCESS! Web services are WORKING!');
    DBMS_OUTPUT.PUT_LINE('HTTP Status: ' || apex_web_service.g_status_code);
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Still not working: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('You may need to:');
        DBMS_OUTPUT.PUT_LINE('1. Restart the database');
        DBMS_OUTPUT.PUT_LINE('2. Or use UTL_HTTP instead of APEX_WEB_SERVICE');
END;
/

PROMPT
PROMPT ========================================
PROMPT Script Complete
PROMPT ========================================