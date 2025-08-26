-- ===============================================================================
-- APEX LOV (List of Values) Views - UI Objects
-- ===============================================================================
-- These views support dropdown lists and selection components in APEX
-- These views support dropdown lists and selection components in APEX
-- ===============================================================================

-- Plants LOV for dropdowns
CREATE OR REPLACE VIEW V_ETL_CONTROL_PLANTS_LOV AS
SELECT 
    plant_id as return_value,
    plant_id || ' - ' || short_description as display_value,
    short_description,
    operator_name,
    area
FROM PLANTS
WHERE is_valid = 'Y'
ORDER BY plant_id;

-- Available plants (not yet selected)
CREATE OR REPLACE VIEW V_AVAILABLE_PLANTS_LOV AS
SELECT 
    p.plant_id as return_value,
    p.plant_id || ' - ' || p.short_description as display_value
FROM PLANTS p
WHERE p.is_valid = 'Y'
AND NOT EXISTS (
    SELECT 1 FROM SELECTION_LOADER sl 
    WHERE sl.plant_id = p.plant_id 
    AND sl.is_active = 'Y'
    AND sl.issue_revision IS NULL
)
ORDER BY p.plant_id;

-- Issues LOV for dropdowns
CREATE OR REPLACE VIEW V_APEX_ISSUES_LOV AS
SELECT 
    i.issue_id,
    i.issue_revision as return_value,
    i.issue_revision || ' (Rev: ' || NVL(i.pcs_revision, 'N/A') || ')' as display_value,
    i.plant_id,
    i.status,
    i.rev_date
FROM ISSUES i
WHERE i.is_valid = 'Y'
ORDER BY i.plant_id, i.issue_revision;

-- Issues for selected plants only
CREATE OR REPLACE VIEW V_ETL_CONTROL_ISSUES_LOV AS
SELECT 
    i.issue_revision as return_value,
    i.issue_revision || ' - ' || i.status || ' (' || TO_CHAR(i.rev_date, 'DD-MON-YY') || ')' as display_value,
    i.plant_id
FROM ISSUES i
WHERE i.is_valid = 'Y'
AND EXISTS (
    SELECT 1 FROM SELECTION_LOADER sl
    WHERE sl.plant_id = i.plant_id
    AND sl.is_active = 'Y'
)
ORDER BY i.issue_revision;

-- Simplified plant LOV
CREATE OR REPLACE VIEW V_APEX_PLANT_LOV AS
SELECT 
    plant_id as id,
    plant_id || ' - ' || short_description as name
FROM PLANTS
WHERE is_valid = 'Y'
ORDER BY plant_id;

PROMPT APEX LOV views created successfully