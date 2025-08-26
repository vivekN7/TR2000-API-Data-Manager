-- ===============================================================================
-- Cascade Triggers - Chain Reaction System
-- ===============================================================================
-- Purpose: Create chain reaction where changes flow through SELECTION_LOADER
-- PLANTS → SELECTION_LOADER → Everything else
-- ISSUES → SELECTION_LOADER → Everything else
-- SELECTION_LOADER is the "big brain" that orchestrates all cascades
-- ===============================================================================

-- ===============================================================================
-- Trigger 1: PLANTS → SELECTION_LOADER
-- When a plant is deactivated/reactivated, update SELECTION_LOADER
-- ===============================================================================
CREATE OR REPLACE TRIGGER TRG_PLANTS_TO_SELECTION
AFTER UPDATE OF is_valid ON PLANTS
FOR EACH ROW
WHEN (OLD.is_valid != NEW.is_valid)
BEGIN
    -- Don't trigger if we're already cascading
    IF NOT PKG_CASCADE_MANAGER.is_cascading THEN
        -- Update SELECTION_LOADER plant-level entry to match plant status
        UPDATE SELECTION_LOADER
        SET is_active = :NEW.is_valid,
            etl_status = CASE 
                WHEN :NEW.is_valid = 'N' THEN 'PLANT_DEACTIVATED'
                ELSE 'PLANT_REACTIVATED'
            END,
            last_etl_run = SYSTIMESTAMP
        WHERE plant_id = :NEW.plant_id
        AND issue_revision IS NULL;  -- Only update plant-level entry
        
        -- Log this trigger action
        INSERT INTO CASCADE_LOG (
            cascade_type, source_table, source_id, target_table,
            trigger_name, action_taken
        ) VALUES (
            CASE WHEN :NEW.is_valid = 'N' THEN 'PLANT_STATUS_CHANGE' ELSE 'PLANT_REACTIVATION' END,
            'PLANTS', :NEW.plant_id, 'SELECTION_LOADER',
            'TRG_PLANTS_TO_SELECTION',
            'Updated SELECTION_LOADER plant-level entry to is_active=' || :NEW.is_valid
        );
    END IF;
END;
/

-- ===============================================================================
-- Trigger 2: SELECTION_LOADER → Everything (The "Big Brain")
-- This is the main cascade trigger that updates all downstream tables
-- ===============================================================================
CREATE OR REPLACE TRIGGER TRG_SELECTION_CASCADE
AFTER UPDATE OF is_active ON SELECTION_LOADER
FOR EACH ROW
WHEN (OLD.is_active != NEW.is_active)
BEGIN
    -- Call the package to handle all cascading
    PKG_CASCADE_MANAGER.cascade_selection_change(
        p_plant_id => :NEW.plant_id,
        p_issue_revision => :NEW.issue_revision,
        p_old_active => :OLD.is_active,
        p_new_active => :NEW.is_active,
        p_trigger_name => 'TRG_SELECTION_CASCADE'
    );
END;
/

-- ===============================================================================
-- Trigger 3: ISSUES → SELECTION_LOADER
-- When an issue is deactivated/reactivated, update SELECTION_LOADER
-- ===============================================================================
CREATE OR REPLACE TRIGGER TRG_ISSUES_TO_SELECTION
AFTER UPDATE OF is_valid ON ISSUES
FOR EACH ROW
WHEN (OLD.is_valid != NEW.is_valid)
BEGIN
    -- Don't trigger if we're already cascading
    IF NOT PKG_CASCADE_MANAGER.is_cascading THEN
        -- First check if this issue exists in SELECTION_LOADER
        DECLARE
            v_exists NUMBER;
        BEGIN
            SELECT COUNT(*)
            INTO v_exists
            FROM SELECTION_LOADER
            WHERE plant_id = :NEW.plant_id
            AND issue_revision = :NEW.issue_revision;
            
            IF v_exists > 0 THEN
                -- Update SELECTION_LOADER to match issue status
                UPDATE SELECTION_LOADER
                SET is_active = :NEW.is_valid,
                    etl_status = CASE 
                        WHEN :NEW.is_valid = 'N' THEN 'ISSUE_DEACTIVATED'
                        ELSE 'ISSUE_REACTIVATED'
                    END,
                    last_etl_run = SYSTIMESTAMP
                WHERE plant_id = :NEW.plant_id
                AND issue_revision = :NEW.issue_revision;
                
                -- Log this trigger action
                INSERT INTO CASCADE_LOG (
                    cascade_type, source_table, source_id, target_table,
                    trigger_name, action_taken
                ) VALUES (
                    CASE WHEN :NEW.is_valid = 'N' THEN 'ISSUE_STATUS_CHANGE' ELSE 'ISSUE_REACTIVATION' END,
                    'ISSUES', :NEW.plant_id || '|' || :NEW.issue_revision, 'SELECTION_LOADER',
                    'TRG_ISSUES_TO_SELECTION',
                    'Updated SELECTION_LOADER issue entry to is_active=' || :NEW.is_valid
                );
            END IF;
        END;
    END IF;
END;
/

PROMPT
PROMPT Cascade triggers created:
PROMPT 1. TRG_PLANTS_TO_SELECTION - PLANTS changes update SELECTION_LOADER
PROMPT 2. TRG_SELECTION_CASCADE - SELECTION_LOADER cascades to everything (big brain)
PROMPT 3. TRG_ISSUES_TO_SELECTION - ISSUES changes update SELECTION_LOADER
PROMPT
PROMPT Chain reaction pattern: Any change → SELECTION_LOADER → All downstream tables
PROMPT