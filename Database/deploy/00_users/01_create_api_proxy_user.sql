-- ===============================================================================
-- Create API Proxy User for Network Access
-- Date: 2025-08-27
-- Purpose: Centralized user with ACL rights for all API calls
-- ===============================================================================

-- Run as SYSTEM or user with CREATE USER privilege

PROMPT ===============================================================================
PROMPT Creating API_PROXY User
PROMPT ===============================================================================

-- Create the proxy user
CREATE USER API_PROXY IDENTIFIED BY "ProxyApi#2025";

-- Grant minimal required privileges
GRANT CREATE SESSION TO API_PROXY;
GRANT CREATE PROCEDURE TO API_PROXY;

-- Grant unlimited quota on default tablespace (for logging if needed)
ALTER USER API_PROXY QUOTA UNLIMITED ON USERS;

PROMPT User API_PROXY created successfully

-- ===============================================================================
-- Grant Network ACL Rights (Run as SYSTEM)
-- ===============================================================================

PROMPT Granting network ACL privileges to API_PROXY...

BEGIN
    -- Create ACL if it doesn't exist
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.create_acl(
            acl         => 'api_proxy_acl.xml',
            description => 'ACL for API Proxy User to access external APIs',
            principal   => 'API_PROXY',
            is_grant    => TRUE,
            privilege   => 'connect'
        );
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE != -31003 THEN -- ACL already exists
                RAISE;
            END IF;
    END;
    
    -- Add resolve privilege
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.add_privilege(
            acl       => 'api_proxy_acl.xml',
            principal => 'API_PROXY',
            is_grant  => TRUE,
            privilege => 'resolve'
        );
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Privilege might already exist
    END;
    
    -- Assign ACL to Equinor API
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.assign_acl(
            acl  => 'api_proxy_acl.xml',
            host => 'equinor.pipespec-api.presight.com',
            lower_port => 443,
            upper_port => 443
        );
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Assignment might already exist
    END;
    
    -- Also allow any HTTPS for flexibility (can be restricted in production)
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.assign_acl(
            acl  => 'api_proxy_acl.xml',
            host => '*',
            lower_port => 443,
            upper_port => 443
        );
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Assignment might already exist
    END;
    
    COMMIT;
END;
/

PROMPT Network ACL privileges granted to API_PROXY

-- Grant execute on APEX_WEB_SERVICE to API_PROXY
GRANT EXECUTE ON APEX_220200.APEX_WEB_SERVICE TO API_PROXY;

-- Create synonym for easier access
CREATE SYNONYM API_PROXY.APEX_WEB_SERVICE FOR APEX_220200.APEX_WEB_SERVICE;

PROMPT 
PROMPT ===============================================================================
PROMPT API_PROXY user created successfully!
PROMPT ===============================================================================
PROMPT Next: Run 02_api_proxy_package.sql to create the service package
PROMPT ===============================================================================