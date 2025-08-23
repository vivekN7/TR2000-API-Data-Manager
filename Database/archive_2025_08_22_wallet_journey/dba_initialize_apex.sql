-- ===============================================================================
-- DBA Script: Initialize APEX Instance for Web Services
-- Run as SYS
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

-- Connect as SYSDBA and run APEX provisioning
PROMPT ========================================
PROMPT Initializing APEX Instance
PROMPT ========================================

-- First, let's check if APEX runtime is properly initialized
BEGIN
    -- Set the internal APEX schema
    EXECUTE IMMEDIATE 'ALTER SESSION SET CURRENT_SCHEMA = APEX_240200';
    DBMS_OUTPUT.PUT_LINE('Switched to APEX_240200 schema');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error switching schema: ' || SQLERRM);
END;
/

-- Run the APEX provisioning script
BEGIN
    -- Call the APEX_ADMIN procedure to initialize
    APEX_240200.APEX_ADMIN;
    DBMS_OUTPUT.PUT_LINE('APEX_ADMIN executed');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error calling APEX_ADMIN: ' || SQLERRM);
END;
/

-- Try the legacy HTMLDB_ADMIN
BEGIN
    APEX_240200.HTMLDB_ADMIN;
    DBMS_OUTPUT.PUT_LINE('HTMLDB_ADMIN executed');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error calling HTMLDB_ADMIN: ' || SQLERRM);
END;
/

-- Now let's manually enable web services by inserting into the internal tables
PROMPT
PROMPT ========================================
PROMPT Manually Enabling Web Services
PROMPT ========================================

-- Find and update the internal configuration
DECLARE
    v_count NUMBER;
BEGIN
    -- Check if WWV_FLOW_PLATFORM_PREFS exists and its structure
    SELECT COUNT(*)
    INTO v_count
    FROM all_tables
    WHERE owner = 'APEX_240200'
    AND table_name = 'WWV_FLOW_PLATFORM_PREFS';
    
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Found WWV_FLOW_PLATFORM_PREFS table');
        
        -- Get column names
        FOR rec IN (
            SELECT column_name
            FROM all_tab_columns
            WHERE owner = 'APEX_240200'
            AND table_name = 'WWV_FLOW_PLATFORM_PREFS'
            ORDER BY column_id
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('  Column: ' || rec.column_name);
        END LOOP;
    END IF;
    
    -- Check for other configuration tables
    FOR rec IN (
        SELECT table_name
        FROM all_tables
        WHERE owner = 'APEX_240200'
        AND table_name LIKE 'WWV_FLOW%'
        AND (table_name LIKE '%PREF%' OR table_name LIKE '%PARAM%' OR table_name LIKE '%CONFIG%')
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('Config table: ' || rec.table_name);
    END LOOP;
END;
/

-- Alternative: Set a database parameter to allow APEX web services
PROMPT
PROMPT ========================================
PROMPT Setting Database Parameters
PROMPT ========================================

-- Enable HTTP access at database level
BEGIN
    -- Enable XDB HTTP
    DBMS_XDB.SETHTTPPORT(8080);
    DBMS_OUTPUT.PUT_LINE('HTTP port set to 8080');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error setting HTTP port: ' || SQLERRM);
END;
/

-- Grant network privileges directly to APEX schema
BEGIN
    -- Grant to APEX internal schema
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => 'APEX_240200',
            principal_type => xs_acl.ptype_db
        )
    );
    DBMS_OUTPUT.PUT_LINE('Network ACE granted to APEX_240200 for all hosts');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error granting ACE: ' || SQLERRM);
END;
/

-- Also grant to PUBLIC for APEX operations
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host => '*',
        ace => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => 'PUBLIC',
            principal_type => xs_acl.ptype_db
        )
    );
    DBMS_OUTPUT.PUT_LINE('Network ACE granted to PUBLIC for all hosts');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error granting ACE to PUBLIC: ' || SQLERRM);
END;
/

COMMIT;

PROMPT
PROMPT ========================================
PROMPT Testing After Configuration
PROMPT ========================================

-- Test as TR2000_STAGING user
CONNECT TR2000_STAGING/piping

DECLARE
    v_response CLOB;
BEGIN
    apex_web_service.g_request_headers.DELETE;
    v_response := apex_web_service.make_rest_request(
        p_url => 'http://httpbin.org/get',
        p_http_method => 'GET'
    );
    
    DBMS_OUTPUT.PUT_LINE('✓ SUCCESS! Web services are working!');
    DBMS_OUTPUT.PUT_LINE('Status: ' || apex_web_service.g_status_code);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Still not working: ' || SQLERRM);
END;
/