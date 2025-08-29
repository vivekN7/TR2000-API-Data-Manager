-- ===============================================================================
-- Add upsert_pcs_list to PKG_UPSERT_PCS_DETAILS
-- Date: 2025-08-29
-- Purpose: Add upsert for plant-level PCS list
-- ===============================================================================

CREATE OR REPLACE PACKAGE pkg_upsert_pcs_details AS
    -- Safe date parsing helper function
    FUNCTION safe_date_parse(p_date_string IN VARCHAR2) RETURN DATE;
    
    -- Safe number parsing helper function
    FUNCTION safe_number_parse(p_number_string IN VARCHAR2) RETURN NUMBER;
    
    -- NEW: Upsert plant PCS list
    PROCEDURE upsert_pcs_list(
        p_plant_id     IN VARCHAR2
    );
    
    -- Existing procedures
    PROCEDURE upsert_header_properties(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_temp_pressures(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_pipe_sizes(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_pipe_elements(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_valve_elements(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_embedded_notes(
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
    PROCEDURE upsert_pcs_details(
        p_detail_type  IN VARCHAR2,
        p_plant_id     IN VARCHAR2,
        p_issue_rev    IN VARCHAR2,
        p_pcs_name     IN VARCHAR2,
        p_pcs_revision IN VARCHAR2
    );
    
END pkg_upsert_pcs_details;
/