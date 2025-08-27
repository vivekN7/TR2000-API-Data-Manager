-- ===============================================================================
-- Fix Reference Validity
-- Date: 2025-08-27
-- Purpose: Ensure all references for selected issues are marked valid
-- Issue: References were loaded but not marked as valid through upsert
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT
PROMPT ===============================================================================
PROMPT Fixing Reference Validity for Selected Issues
PROMPT ===============================================================================
PROMPT

-- Show current state
PROMPT Current Reference State:
SELECT 
    reference_type,
    plant_id || '/' || issue_revision as issue,
    COUNT(*) as total,
    is_valid
FROM (
    SELECT 'VDS' as reference_type, plant_id, issue_revision, is_valid 
    FROM VDS_REFERENCES
    WHERE plant_id IN ('124', '34')
    UNION ALL
    SELECT 'MDS', plant_id, issue_revision, is_valid 
    FROM MDS_REFERENCES
    WHERE plant_id IN ('124', '34')
    UNION ALL
    SELECT 'PIPE', plant_id, issue_revision, is_valid 
    FROM PIPE_ELEMENT_REFERENCES
    WHERE plant_id IN ('124', '34')
    UNION ALL
    SELECT 'VSK', plant_id, issue_revision, is_valid 
    FROM VSK_REFERENCES
    WHERE plant_id IN ('124', '34')
    UNION ALL
    SELECT 'EDS', plant_id, issue_revision, is_valid 
    FROM EDS_REFERENCES
    WHERE plant_id IN ('124', '34')
)
GROUP BY reference_type, plant_id, issue_revision, is_valid
ORDER BY reference_type, plant_id, issue_revision;

PROMPT
PROMPT Running upsert procedures for all reference types...

DECLARE
    v_count NUMBER;
    v_total_fixed NUMBER := 0;
BEGIN
    -- Process each selected issue
    FOR rec IN (
        SELECT plant_id, issue_revision 
        FROM SELECTED_ISSUES 
        WHERE is_active = 'Y'
        ORDER BY plant_id, issue_revision
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('Processing ' || rec.plant_id || '/' || rec.issue_revision || '...');
        
        -- VDS References
        PKG_UPSERT_REFERENCES.upsert_vds_references(rec.plant_id, rec.issue_revision);
        SELECT COUNT(*) INTO v_count FROM VDS_REFERENCES 
        WHERE plant_id = rec.plant_id AND issue_revision = rec.issue_revision AND is_valid = 'Y';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  VDS: ' || v_count || ' references validated');
            v_total_fixed := v_total_fixed + v_count;
        END IF;
        
        -- MDS References
        PKG_UPSERT_REFERENCES.upsert_mds_references(rec.plant_id, rec.issue_revision);
        SELECT COUNT(*) INTO v_count FROM MDS_REFERENCES 
        WHERE plant_id = rec.plant_id AND issue_revision = rec.issue_revision AND is_valid = 'Y';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  MDS: ' || v_count || ' references validated');
            v_total_fixed := v_total_fixed + v_count;
        END IF;
        
        -- PIPE_ELEMENT References
        PKG_UPSERT_REFERENCES.upsert_pipe_element_references(rec.plant_id, rec.issue_revision);
        SELECT COUNT(*) INTO v_count FROM PIPE_ELEMENT_REFERENCES 
        WHERE plant_id = rec.plant_id AND issue_revision = rec.issue_revision AND is_valid = 'Y';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  PIPE: ' || v_count || ' references validated');
            v_total_fixed := v_total_fixed + v_count;
        END IF;
        
        -- VSK References
        PKG_UPSERT_REFERENCES.upsert_vsk_references(rec.plant_id, rec.issue_revision);
        SELECT COUNT(*) INTO v_count FROM VSK_REFERENCES 
        WHERE plant_id = rec.plant_id AND issue_revision = rec.issue_revision AND is_valid = 'Y';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  VSK: ' || v_count || ' references validated');
            v_total_fixed := v_total_fixed + v_count;
        END IF;
        
        -- EDS References
        PKG_UPSERT_REFERENCES.upsert_eds_references(rec.plant_id, rec.issue_revision);
        SELECT COUNT(*) INTO v_count FROM EDS_REFERENCES 
        WHERE plant_id = rec.plant_id AND issue_revision = rec.issue_revision AND is_valid = 'Y';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  EDS: ' || v_count || ' references validated');
            v_total_fixed := v_total_fixed + v_count;
        END IF;
        
        -- SC References
        PKG_UPSERT_REFERENCES.upsert_sc_references(rec.plant_id, rec.issue_revision);
        SELECT COUNT(*) INTO v_count FROM SC_REFERENCES 
        WHERE plant_id = rec.plant_id AND issue_revision = rec.issue_revision AND is_valid = 'Y';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  SC: ' || v_count || ' references validated');
            v_total_fixed := v_total_fixed + v_count;
        END IF;
        
        -- VSM References
        PKG_UPSERT_REFERENCES.upsert_vsm_references(rec.plant_id, rec.issue_revision);
        SELECT COUNT(*) INTO v_count FROM VSM_REFERENCES 
        WHERE plant_id = rec.plant_id AND issue_revision = rec.issue_revision AND is_valid = 'Y';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  VSM: ' || v_count || ' references validated');
            v_total_fixed := v_total_fixed + v_count;
        END IF;
        
        -- ESK References
        PKG_UPSERT_REFERENCES.upsert_esk_references(rec.plant_id, rec.issue_revision);
        SELECT COUNT(*) INTO v_count FROM ESK_REFERENCES 
        WHERE plant_id = rec.plant_id AND issue_revision = rec.issue_revision AND is_valid = 'Y';
        IF v_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  ESK: ' || v_count || ' references validated');
            v_total_fixed := v_total_fixed + v_count;
        END IF;
        
    END LOOP;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '========================================');
    DBMS_OUTPUT.PUT_LINE('Total references validated: ' || v_total_fixed);
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

-- Show updated counts
PROMPT
PROMPT Updated Reference Counts (Valid Only):
SELECT 
    table_name,
    valid_count
FROM (
    SELECT 'PCS_REFERENCES' as table_name,
           COUNT(*) as valid_count
    FROM PCS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL
    SELECT 'VDS_REFERENCES',
           COUNT(*)
    FROM VDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL
    SELECT 'MDS_REFERENCES',
           COUNT(*)
    FROM MDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL
    SELECT 'PIPE_ELEMENT_REF',
           COUNT(*)
    FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
    UNION ALL
    SELECT 'VSK_REFERENCES',
           COUNT(*)
    FROM VSK_REFERENCES WHERE is_valid = 'Y'
    UNION ALL
    SELECT 'EDS_REFERENCES',
           COUNT(*)
    FROM EDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL
    SELECT 'SC_REFERENCES',
           COUNT(*)
    FROM SC_REFERENCES WHERE is_valid = 'Y'
    UNION ALL
    SELECT 'VSM_REFERENCES',
           COUNT(*)
    FROM VSM_REFERENCES WHERE is_valid = 'Y'
    UNION ALL
    SELECT 'ESK_REFERENCES',
           COUNT(*)
    FROM ESK_REFERENCES WHERE is_valid = 'Y'
)
ORDER BY table_name;

-- Show total
SELECT 'TOTAL VALID REFERENCES' as metric, SUM(cnt) as count FROM (
    SELECT COUNT(*) cnt FROM PCS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM VDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM MDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM PIPE_ELEMENT_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM VSK_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM EDS_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM SC_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM VSM_REFERENCES WHERE is_valid = 'Y'
    UNION ALL SELECT COUNT(*) FROM ESK_REFERENCES WHERE is_valid = 'Y'
);

PROMPT
PROMPT ===============================================================================
PROMPT Reference Validity Fix Complete
PROMPT ===============================================================================
PROMPT