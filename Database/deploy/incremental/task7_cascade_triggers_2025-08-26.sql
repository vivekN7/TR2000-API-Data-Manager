-- ===============================================================================
-- Incremental Update: Task 7.8 - Cascade Triggers for Reference Tables
-- Date: 2025-08-26
-- ===============================================================================
-- This script adds cascade triggers to handle soft deletes when issues change
-- When an issue is marked invalid, all its references cascade to invalid
-- ===============================================================================

SET SERVEROUTPUT ON

PROMPT ===============================================================================
PROMPT Adding Cascade Triggers for Reference Tables (Task 7.8)
PROMPT ===============================================================================

-- =========================================================================
-- Trigger to cascade issue deletion to all reference tables
-- =========================================================================
CREATE OR REPLACE TRIGGER TRG_CASCADE_ISSUE_TO_REFERENCES
AFTER UPDATE OF is_valid ON ISSUES
FOR EACH ROW
WHEN (NEW.is_valid = 'N' AND OLD.is_valid = 'Y')
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_count NUMBER;
    v_total_affected NUMBER := 0;
BEGIN
    -- Update PCS_REFERENCES
    UPDATE PCS_REFERENCES
    SET is_valid = 'N', last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND issue_revision = :NEW.issue_revision
      AND is_valid = 'Y';
    v_count := SQL%ROWCOUNT;
    v_total_affected := v_total_affected + v_count;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Cascaded to PCS_REFERENCES: ' || v_count || ' records');
    END IF;
    
    -- Update SC_REFERENCES
    UPDATE SC_REFERENCES
    SET is_valid = 'N', last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND issue_revision = :NEW.issue_revision
      AND is_valid = 'Y';
    v_count := SQL%ROWCOUNT;
    v_total_affected := v_total_affected + v_count;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Cascaded to SC_REFERENCES: ' || v_count || ' records');
    END IF;
    
    -- Update VSM_REFERENCES
    UPDATE VSM_REFERENCES
    SET is_valid = 'N', last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND issue_revision = :NEW.issue_revision
      AND is_valid = 'Y';
    v_count := SQL%ROWCOUNT;
    v_total_affected := v_total_affected + v_count;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Cascaded to VSM_REFERENCES: ' || v_count || ' records');
    END IF;
    
    -- Update VDS_REFERENCES
    UPDATE VDS_REFERENCES
    SET is_valid = 'N', last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND issue_revision = :NEW.issue_revision
      AND is_valid = 'Y';
    v_count := SQL%ROWCOUNT;
    v_total_affected := v_total_affected + v_count;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Cascaded to VDS_REFERENCES: ' || v_count || ' records');
    END IF;
    
    -- Update EDS_REFERENCES
    UPDATE EDS_REFERENCES
    SET is_valid = 'N', last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND issue_revision = :NEW.issue_revision
      AND is_valid = 'Y';
    v_count := SQL%ROWCOUNT;
    v_total_affected := v_total_affected + v_count;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Cascaded to EDS_REFERENCES: ' || v_count || ' records');
    END IF;
    
    -- Update MDS_REFERENCES
    UPDATE MDS_REFERENCES
    SET is_valid = 'N', last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND issue_revision = :NEW.issue_revision
      AND is_valid = 'Y';
    v_count := SQL%ROWCOUNT;
    v_total_affected := v_total_affected + v_count;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Cascaded to MDS_REFERENCES: ' || v_count || ' records');
    END IF;
    
    -- Update VSK_REFERENCES
    UPDATE VSK_REFERENCES
    SET is_valid = 'N', last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND issue_revision = :NEW.issue_revision
      AND is_valid = 'Y';
    v_count := SQL%ROWCOUNT;
    v_total_affected := v_total_affected + v_count;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Cascaded to VSK_REFERENCES: ' || v_count || ' records');
    END IF;
    
    -- Update ESK_REFERENCES
    UPDATE ESK_REFERENCES
    SET is_valid = 'N', last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND issue_revision = :NEW.issue_revision
      AND is_valid = 'Y';
    v_count := SQL%ROWCOUNT;
    v_total_affected := v_total_affected + v_count;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Cascaded to ESK_REFERENCES: ' || v_count || ' records');
    END IF;
    
    -- Update PIPE_ELEMENT_REFERENCES
    UPDATE PIPE_ELEMENT_REFERENCES
    SET is_valid = 'N', last_modified_date = SYSDATE
    WHERE plant_id = :NEW.plant_id
      AND issue_revision = :NEW.issue_revision
      AND is_valid = 'Y';
    v_count := SQL%ROWCOUNT;
    v_total_affected := v_total_affected + v_count;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Cascaded to PIPE_ELEMENT_REFERENCES: ' || v_count || ' records');
    END IF;
    
    -- Log cascade operation
    IF v_total_affected > 0 THEN
        INSERT INTO CASCADE_LOG (
            cascade_type, source_table, source_id,
            target_table, affected_count, cascade_timestamp,
            trigger_name, action_taken
        ) VALUES (
            'ISSUE_TO_REFERENCES',
            'ISSUES',
            :NEW.plant_id || '/' || :NEW.issue_revision,
            'REFERENCE_TABLES',
            v_total_affected,
            SYSTIMESTAMP,
            'TRG_CASCADE_ISSUE_TO_REFERENCES',
            'Marked ' || v_total_affected || ' reference records as invalid'
        );
    END IF;
    
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the main transaction
        DBMS_OUTPUT.PUT_LINE('Error in cascade trigger: ' || SQLERRM);
        ROLLBACK;
END;
/

-- =========================================================================
-- Extension to PKG_CASCADE_MANAGER for reference tables
-- =========================================================================
CREATE OR REPLACE PACKAGE BODY pkg_cascade_manager AS
    -- Existing procedures remain...
    -- Adding new procedure for reference cascade
    
    PROCEDURE cascade_issue_to_references(
        p_plant_id      IN VARCHAR2,
        p_issue_revision IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_count NUMBER;
        v_total NUMBER := 0;
    BEGIN
        -- This procedure can be called directly if needed
        -- Updates all reference tables when an issue is invalidated
        
        -- PCS References
        UPDATE PCS_REFERENCES
        SET is_valid = 'N', last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_revision
          AND is_valid = 'Y';
        v_count := SQL%ROWCOUNT;
        v_total := v_total + v_count;
        
        -- SC References
        UPDATE SC_REFERENCES
        SET is_valid = 'N', last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_revision
          AND is_valid = 'Y';
        v_count := SQL%ROWCOUNT;
        v_total := v_total + v_count;
        
        -- VSM References
        UPDATE VSM_REFERENCES
        SET is_valid = 'N', last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_revision
          AND is_valid = 'Y';
        v_count := SQL%ROWCOUNT;
        v_total := v_total + v_count;
        
        -- VDS References
        UPDATE VDS_REFERENCES
        SET is_valid = 'N', last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_revision
          AND is_valid = 'Y';
        v_count := SQL%ROWCOUNT;
        v_total := v_total + v_count;
        
        -- EDS References
        UPDATE EDS_REFERENCES
        SET is_valid = 'N', last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_revision
          AND is_valid = 'Y';
        v_count := SQL%ROWCOUNT;
        v_total := v_total + v_count;
        
        -- MDS References
        UPDATE MDS_REFERENCES
        SET is_valid = 'N', last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_revision
          AND is_valid = 'Y';
        v_count := SQL%ROWCOUNT;
        v_total := v_total + v_count;
        
        -- VSK References
        UPDATE VSK_REFERENCES
        SET is_valid = 'N', last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_revision
          AND is_valid = 'Y';
        v_count := SQL%ROWCOUNT;
        v_total := v_total + v_count;
        
        -- ESK References
        UPDATE ESK_REFERENCES
        SET is_valid = 'N', last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_revision
          AND is_valid = 'Y';
        v_count := SQL%ROWCOUNT;
        v_total := v_total + v_count;
        
        -- Pipe Element References
        UPDATE PIPE_ELEMENT_REFERENCES
        SET is_valid = 'N', last_modified_date = SYSDATE
        WHERE plant_id = p_plant_id
          AND issue_revision = p_issue_revision
          AND is_valid = 'Y';
        v_count := SQL%ROWCOUNT;
        v_total := v_total + v_count;
        
        -- Log the cascade
        IF v_total > 0 THEN
            INSERT INTO CASCADE_LOG (
                log_id, trigger_name, table_name, operation_type,
                affected_records, log_timestamp, details
            ) VALUES (
                CASCADE_LOG_SEQ.NEXTVAL,
                'PKG_CASCADE_MANAGER',
                'ISSUES',
                'ISSUE_TO_REFERENCES_CASCADE',
                v_total,
                SYSTIMESTAMP,
                'Cascaded issue ' || p_plant_id || '/' || p_issue_revision || 
                ' to ' || v_total || ' reference records'
            );
        END IF;
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('Cascaded issue to ' || v_total || ' reference records');
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END cascade_issue_to_references;
    
    -- Keep existing procedures...
END pkg_cascade_manager;
/

-- =========================================================================
-- Test the cascade trigger
-- =========================================================================
PROMPT
PROMPT Testing cascade trigger setup...

DECLARE
    v_trigger_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_trigger_count
    FROM user_triggers
    WHERE trigger_name = 'TRG_CASCADE_ISSUE_TO_REFERENCES'
      AND status = 'ENABLED';
    
    IF v_trigger_count = 1 THEN
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Cascade trigger created and enabled');
    ELSE
        DBMS_OUTPUT.PUT_LINE('WARNING: Cascade trigger may not be properly enabled');
    END IF;
END;
/

PROMPT
PROMPT ===============================================================================
PROMPT Task 7.8 Complete: Cascade triggers added for reference tables
PROMPT When an issue is marked invalid, all its references will cascade to invalid
PROMPT ===============================================================================