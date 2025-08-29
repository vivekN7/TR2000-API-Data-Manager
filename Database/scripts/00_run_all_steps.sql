-- ===============================================================================
-- Master Script: Run All Steps for GRANE/4.2 Load
-- Date: 2025-12-30
-- Purpose: Clean data and run all 5 steps in sequence
-- ===============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

-- First clean all data (using no-exit version)
@scripts/clean_all_data_no_exit.sql

-- Now run the 5 logical steps
PROMPT
PROMPT ===============================================
PROMPT Starting 5-Step ETL Process for GRANE/4.2
PROMPT ===============================================

-- Step 1: Load all plants
@scripts/01_load_plants_no_exit.sql

-- Step 2: User selects GRANE
@scripts/02_select_grane_no_exit.sql

-- Step 3: Load issues for selected plant
@scripts/03_load_issues_for_selected_no_exit.sql

-- Step 4: User selects issue 4.2
@scripts/04_select_issue_42_no_exit.sql

-- Step 5: Load references and details (broken into sub-steps)
PROMPT
PROMPT Step 5a: Loading references for issue 4.2...
@scripts/05a_load_references_no_exit.sql

PROMPT
PROMPT Step 5b: Loading PCS list for plant 34...
@scripts/05b_load_pcs_list_no_exit.sql

PROMPT
PROMPT Step 5c: Loading PCS details...
@scripts/05c_load_pcs_details_no_exit.sql

PROMPT
PROMPT Step 5d: Loading global VDS list...
@scripts/05d_load_vds_list_no_exit.sql

PROMPT
PROMPT ===============================================
PROMPT All Steps Complete!
PROMPT ===============================================

EXIT;