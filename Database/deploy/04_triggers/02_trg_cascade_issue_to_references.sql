-- ===============================================================================
-- TRG_CASCADE_ISSUE_TO_REFERENCES - Cascade Issue Changes to References
-- Date: 2025-08-26
-- Purpose: When an issue is marked invalid, cascade to all reference tables
-- ===============================================================================

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