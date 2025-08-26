-- ===============================================================================
-- PKG_CASCADE_MANAGER - Central Cascade Management System
-- ===============================================================================
-- Purpose: Handle all cascade operations from SELECTION_LOADER changes
-- This is the "big brain" that orchestrates all data deactivation/reactivation
-- Prevents infinite loops using session tracking
-- ===============================================================================

CREATE OR REPLACE PACKAGE PKG_CASCADE_MANAGER AS
    
    -- Main cascade procedure called by SELECTION_LOADER trigger
    PROCEDURE cascade_selection_change(
        p_plant_id VARCHAR2,
        p_issue_revision VARCHAR2,
        p_old_active CHAR,
        p_new_active CHAR,
        p_trigger_name VARCHAR2
    );
    
    -- Check if we're already in a cascade (prevent loops)
    FUNCTION is_cascading RETURN BOOLEAN;
    
    -- Clear cascade session (for error recovery)
    PROCEDURE clear_cascade_session;
    
END PKG_CASCADE_MANAGER;
/

CREATE OR REPLACE PACKAGE BODY PKG_CASCADE_MANAGER AS
    
    -- Package variable to track cascade session
    g_cascade_session_id VARCHAR2(100) := NULL;
    
    -- Check if we're already cascading
    FUNCTION is_cascading RETURN BOOLEAN IS
    BEGIN
        RETURN (g_cascade_session_id IS NOT NULL);
    END is_cascading;
    
    -- Clear cascade session
    PROCEDURE clear_cascade_session IS
    BEGIN
        g_cascade_session_id := NULL;
    END clear_cascade_session;
    
    -- Main cascade procedure
    PROCEDURE cascade_selection_change(
        p_plant_id VARCHAR2,
        p_issue_revision VARCHAR2,
        p_old_active CHAR,
        p_new_active CHAR,
        p_trigger_name VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;  -- Allow independent transaction in trigger
        v_affected_count NUMBER := 0;
        v_action_taken VARCHAR2(4000);
    BEGIN
        -- Skip if already cascading (prevent infinite loop)
        IF is_cascading THEN
            -- Log that we prevented a loop
            INSERT INTO CASCADE_LOG (
                CASCADE_TYPE, SOURCE_TABLE, SOURCE_ID, 
                TRIGGER_NAME, ACTION_TAKEN
            ) VALUES (
                'LOOP_PREVENTED', 'SELECTION_LOADER', 
                p_plant_id || '|' || NVL(p_issue_revision, 'NULL'),
                p_trigger_name, 'Cascade already in progress - skipped to prevent loop'
            );
            COMMIT;
            RETURN;
        END IF;
        
        -- Set cascade session
        g_cascade_session_id := SYS_GUID() || '_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF');
        
        BEGIN
            -- Handle DEACTIVATION (is_active changed from Y to N)
            IF p_old_active = 'Y' AND p_new_active = 'N' THEN
                
                IF p_issue_revision IS NULL THEN
                    -- PLANT-LEVEL DEACTIVATION
                    v_action_taken := 'Plant-level deactivation cascade';
                    
                    -- 1. Deactivate all issues for this plant
                    UPDATE ISSUES 
                    SET is_valid = 'N',
                        last_modified_date = SYSDATE
                    WHERE plant_id = p_plant_id 
                    AND is_valid = 'Y';
                    
                    v_affected_count := SQL%ROWCOUNT;
                    
                    -- Log this cascade
                    INSERT INTO CASCADE_LOG (
                        CASCADE_TYPE, SOURCE_TABLE, SOURCE_ID, TARGET_TABLE,
                        AFFECTED_COUNT, CASCADE_SESSION_ID, TRIGGER_NAME, ACTION_TAKEN
                    ) VALUES (
                        'PLANT_DEACTIVATION', 'SELECTION_LOADER', p_plant_id,
                        'ISSUES', v_affected_count, g_cascade_session_id,
                        p_trigger_name, v_action_taken || ' - ' || v_affected_count || ' issues deactivated'
                    );
                    
                    -- 2. Deactivate all issue-specific selections for this plant
                    UPDATE SELECTION_LOADER 
                    SET is_active = 'N',
                        etl_status = 'CASCADE_DEACTIVATED',
                        last_etl_run = SYSTIMESTAMP
                    WHERE plant_id = p_plant_id 
                    AND issue_revision IS NOT NULL 
                    AND is_active = 'Y';
                    
                    v_affected_count := SQL%ROWCOUNT;
                    
                    -- Log this cascade
                    INSERT INTO CASCADE_LOG (
                        CASCADE_TYPE, SOURCE_TABLE, SOURCE_ID, TARGET_TABLE,
                        AFFECTED_COUNT, CASCADE_SESSION_ID, TRIGGER_NAME, ACTION_TAKEN
                    ) VALUES (
                        'PLANT_DEACTIVATION', 'SELECTION_LOADER', p_plant_id,
                        'SELECTION_LOADER', v_affected_count, g_cascade_session_id,
                        p_trigger_name, 'Deactivated ' || v_affected_count || ' issue-specific selections'
                    );
                    
                ELSE
                    -- ISSUE-LEVEL DEACTIVATION
                    v_action_taken := 'Issue-level deactivation cascade';
                    
                    -- Deactivate the specific issue
                    UPDATE ISSUES 
                    SET is_valid = 'N',
                        last_modified_date = SYSDATE
                    WHERE plant_id = p_plant_id 
                    AND issue_revision = p_issue_revision
                    AND is_valid = 'Y';
                    
                    v_affected_count := SQL%ROWCOUNT;
                    
                    -- Log this cascade
                    INSERT INTO CASCADE_LOG (
                        CASCADE_TYPE, SOURCE_TABLE, SOURCE_ID, TARGET_TABLE,
                        AFFECTED_COUNT, CASCADE_SESSION_ID, TRIGGER_NAME, ACTION_TAKEN
                    ) VALUES (
                        'ISSUE_DEACTIVATION', 'SELECTION_LOADER', 
                        p_plant_id || '|' || p_issue_revision,
                        'ISSUES', v_affected_count, g_cascade_session_id,
                        p_trigger_name, v_action_taken || ' - issue ' || p_issue_revision || ' deactivated'
                    );
                    
                    -- Future: Deactivate reference tables for this issue
                    -- UPDATE PCS_REFERENCES SET is_valid = 'N' WHERE ...
                END IF;
                
            -- Handle REACTIVATION (is_active changed from N to Y)
            ELSIF p_old_active = 'N' AND p_new_active = 'Y' THEN
                
                IF p_issue_revision IS NULL THEN
                    -- PLANT-LEVEL REACTIVATION
                    v_action_taken := 'Plant-level reactivation';
                    
                    -- Note: We DON'T automatically reactivate all issues
                    -- This needs to be done selectively based on business rules
                    
                    -- Log the reactivation
                    INSERT INTO CASCADE_LOG (
                        CASCADE_TYPE, SOURCE_TABLE, SOURCE_ID, TARGET_TABLE,
                        AFFECTED_COUNT, CASCADE_SESSION_ID, TRIGGER_NAME, ACTION_TAKEN
                    ) VALUES (
                        'PLANT_REACTIVATION', 'SELECTION_LOADER', p_plant_id,
                        'NONE', 0, g_cascade_session_id,
                        p_trigger_name, v_action_taken || ' - manual issue reactivation required'
                    );
                    
                ELSE
                    -- ISSUE-LEVEL REACTIVATION
                    v_action_taken := 'Issue-level reactivation';
                    
                    -- Reactivate the specific issue (if plant is active)
                    UPDATE ISSUES 
                    SET is_valid = 'Y',
                        last_modified_date = SYSDATE
                    WHERE plant_id = p_plant_id 
                    AND issue_revision = p_issue_revision
                    AND is_valid = 'N'
                    AND EXISTS (
                        SELECT 1 FROM PLANTS p 
                        WHERE p.plant_id = ISSUES.plant_id 
                        AND p.is_valid = 'Y'
                    );
                    
                    v_affected_count := SQL%ROWCOUNT;
                    
                    -- Log this cascade
                    INSERT INTO CASCADE_LOG (
                        CASCADE_TYPE, SOURCE_TABLE, SOURCE_ID, TARGET_TABLE,
                        AFFECTED_COUNT, CASCADE_SESSION_ID, TRIGGER_NAME, ACTION_TAKEN
                    ) VALUES (
                        'ISSUE_REACTIVATION', 'SELECTION_LOADER', 
                        p_plant_id || '|' || p_issue_revision,
                        'ISSUES', v_affected_count, g_cascade_session_id,
                        p_trigger_name, v_action_taken || ' - issue ' || p_issue_revision || ' reactivated'
                    );
                END IF;
            END IF;
            
            -- Clear cascade session
            g_cascade_session_id := NULL;
            COMMIT;
            
        EXCEPTION
            WHEN OTHERS THEN
                DECLARE
                    v_error_msg VARCHAR2(4000);
                BEGIN
                    -- Clear cascade session on error
                    g_cascade_session_id := NULL;
                    
                    -- Capture error message
                    v_error_msg := SUBSTR(SQLERRM, 1, 3900);
                    
                    -- Log the error
                    INSERT INTO CASCADE_LOG (
                        CASCADE_TYPE, SOURCE_TABLE, SOURCE_ID,
                        TRIGGER_NAME, ACTION_TAKEN
                    ) VALUES (
                        'ERROR', 'SELECTION_LOADER', 
                        p_plant_id || '|' || NVL(p_issue_revision, 'NULL'),
                        p_trigger_name, 'Error: ' || v_error_msg
                    );
                    COMMIT;
                END;
                
                -- Re-raise the error
                RAISE;
        END;
        
    END cascade_selection_change;
    
END PKG_CASCADE_MANAGER;
/

SHOW ERRORS

PROMPT PKG_CASCADE_MANAGER package created for cascade management