-- ===============================================================================
-- Deploy All Tables - TR2000 ETL System
-- ===============================================================================
-- WARNING: This script DROPS and RECREATES all tables
-- All data will be lost! Use with caution.
-- ===============================================================================

SET ECHO ON
SET SERVEROUTPUT ON

PROMPT ===============================================================================
PROMPT WARNING: This will DROP and RECREATE all tables!
PROMPT Press Ctrl+C to cancel, or Enter to continue...
PROMPT ===============================================================================
PAUSE

-- Drop all tables first (in reverse dependency order)
PROMPT Dropping existing tables...

BEGIN
    -- Drop in reverse dependency order
    FOR t IN (
        SELECT table_name FROM user_tables 
        WHERE table_name IN (
            'ETL_ERROR_LOG', 'ETL_RUN_LOG', 'CONTROL_ENDPOINT_STATE', 
            'CONTROL_ENDPOINTS', 'CONTROL_SETTINGS', 'SELECTION_LOADER',
            'ISSUES', 'PLANTS', 'STG_ISSUES', 'STG_PLANTS', 
            'RAW_JSON'
        )
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Dropped table: ' || t.table_name);
        EXCEPTION WHEN OTHERS THEN 
            NULL; -- Table doesn't exist
        END;
    END LOOP;
END;
/

PROMPT
PROMPT Creating tables...

-- Raw data storage
@01_raw_json.sql

-- Staging tables
@02_staging_tables.sql

-- Core business tables
@03_core_tables.sql

-- Control and configuration tables
@04_control_tables.sql

-- Logging and documentation tables
@05_log_tables.sql

-- CASCADE management table
@07_cascade_log.sql

-- GUID tracking tables for API and external systems
@08_guid_tracking_tables.sql

-- Reference tables for issue references
@06_reference_tables.sql

PROMPT
PROMPT ===============================================================================
PROMPT Table deployment complete
PROMPT ===============================================================================

-- Show all tables
SELECT table_name, num_rows FROM user_tables ORDER BY table_name;

EXIT;