-- ===============================================================================
-- Fix PKG_CASCADE_MANAGER Body
-- Date: 2025-08-26
-- ===============================================================================
-- Fixes compilation errors in PKG_CASCADE_MANAGER package body
-- ===============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_CASCADE_MANAGER AS
    
    -- Session variable to track cascade state
    g_is_cascading BOOLEAN := FALSE;
    
    -- Main cascade procedure
    PROCEDURE cascade_selection_change(
        p_plant_id VARCHAR2,
        p_issue_revision VARCHAR2,
        p_old_active CHAR,
        p_new_active CHAR,
        p_trigger_name VARCHAR2
    ) IS
        v_affected_count NUMBER := 0;
        v_log_message VARCHAR2(4000);
    BEGIN
        -- Prevent cascade loops
        IF g_is_cascading THEN
            RETURN;
        END IF;
        
        g_is_cascading := TRUE;
        
        BEGIN
            -- If issue is being deactivated, cascade to references
            IF p_old_active = 'Y' AND p_new_active = 'N' THEN
                
                -- Update all reference tables
                UPDATE PCS_REFERENCES
                SET is_valid = 'N', last_modified_date = SYSDATE
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_revision
                  AND is_valid = 'Y';
                v_affected_count := v_affected_count + SQL%ROWCOUNT;
                
                UPDATE SC_REFERENCES
                SET is_valid = 'N', last_modified_date = SYSDATE
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_revision
                  AND is_valid = 'Y';
                v_affected_count := v_affected_count + SQL%ROWCOUNT;
                
                UPDATE VSM_REFERENCES
                SET is_valid = 'N', last_modified_date = SYSDATE
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_revision
                  AND is_valid = 'Y';
                v_affected_count := v_affected_count + SQL%ROWCOUNT;
                
                UPDATE VDS_REFERENCES
                SET is_valid = 'N', last_modified_date = SYSDATE
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_revision
                  AND is_valid = 'Y';
                v_affected_count := v_affected_count + SQL%ROWCOUNT;
                
                UPDATE EDS_REFERENCES
                SET is_valid = 'N', last_modified_date = SYSDATE
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_revision
                  AND is_valid = 'Y';
                v_affected_count := v_affected_count + SQL%ROWCOUNT;
                
                UPDATE MDS_REFERENCES
                SET is_valid = 'N', last_modified_date = SYSDATE
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_revision
                  AND is_valid = 'Y';
                v_affected_count := v_affected_count + SQL%ROWCOUNT;
                
                UPDATE VSK_REFERENCES
                SET is_valid = 'N', last_modified_date = SYSDATE
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_revision
                  AND is_valid = 'Y';
                v_affected_count := v_affected_count + SQL%ROWCOUNT;
                
                UPDATE ESK_REFERENCES
                SET is_valid = 'N', last_modified_date = SYSDATE
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_revision
                  AND is_valid = 'Y';
                v_affected_count := v_affected_count + SQL%ROWCOUNT;
                
                UPDATE PIPE_ELEMENT_REFERENCES
                SET is_valid = 'N', last_modified_date = SYSDATE
                WHERE plant_id = p_plant_id
                  AND issue_revision = p_issue_revision
                  AND is_valid = 'Y';
                v_affected_count := v_affected_count + SQL%ROWCOUNT;
                
                -- Log the cascade
                IF v_affected_count > 0 THEN
                    v_log_message := 'Issue deactivated: ' || p_plant_id || '/' || p_issue_revision || 
                                   ', cascaded to ' || v_affected_count || ' reference records';
                    
                    INSERT INTO CASCADE_LOG (
                        cascade_type, 
                        source_table, 
                        source_id,
                        target_table, 
                        affected_count, 
                        cascade_timestamp,
                        cascade_session_id,
                        trigger_name,
                        action_taken
                    ) VALUES (
                        'ISSUE_REFERENCE',
                        'SELECTION_LOADER',
                        p_plant_id || '/' || p_issue_revision,
                        'REFERENCE_TABLES',
                        v_affected_count,
                        SYSTIMESTAMP,
                        SYS_CONTEXT('USERENV', 'SESSIONID'),
                        p_trigger_name,
                        v_log_message
                    );
                END IF;
            END IF;
            
            g_is_cascading := FALSE;
            
        EXCEPTION
            WHEN OTHERS THEN
                g_is_cascading := FALSE;
                RAISE;
        END;
    END cascade_selection_change;
    
    -- Check cascade state
    FUNCTION is_cascading RETURN BOOLEAN IS
    BEGIN
        RETURN g_is_cascading;
    END is_cascading;
    
    -- Clear cascade session
    PROCEDURE clear_cascade_session IS
    BEGIN
        g_is_cascading := FALSE;
    END clear_cascade_session;
    
END PKG_CASCADE_MANAGER;
/

-- Test compilation
DECLARE
    v_status VARCHAR2(20);
BEGIN
    SELECT status INTO v_status
    FROM user_objects
    WHERE object_name = 'PKG_CASCADE_MANAGER'
    AND object_type = 'PACKAGE BODY';
    
    IF v_status = 'VALID' THEN
        DBMS_OUTPUT.PUT_LINE('SUCCESS: PKG_CASCADE_MANAGER compiled successfully');
    ELSE
        DBMS_OUTPUT.PUT_LINE('ERROR: PKG_CASCADE_MANAGER compilation failed');
    END IF;
END;
/

PROMPT
PROMPT ===============================================================================
PROMPT PKG_CASCADE_MANAGER body fixed
PROMPT ===============================================================================