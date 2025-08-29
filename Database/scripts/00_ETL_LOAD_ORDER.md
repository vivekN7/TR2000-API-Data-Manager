# ETL Load Order - GRANE/4.2

## Complete Load Sequence

### Phase 1: Initial Setup
1. **01_load_plants.sql** - Load all plants from API (~130 plants)
2. **02_select_grane.sql** - User selects GRANE (plant_id=34)

### Phase 2: Issues
3. **03_load_issues_for_selected.sql** - Load issues for GRANE (8 issues)
4. **04_select_issue_42.sql** - User selects issue 4.2

### Phase 3: References (Issue-specific)
5. **05a_load_references.sql** - Load all 9 reference types for issue 4.2
   - PCS References (~66)
   - VDS References (~753)
   - MDS References (~259)
   - EDS References (~9)
   - VSK References (~80)
   - ESK References (0)
   - PIPE_ELEMENT References (~480)
   - SC References (~1)
   - VSM References (~2)

### Phase 4: PCS Processing (Plant-specific)
6. **05b_load_pcs_list.sql** - Load ALL PCS revisions for plant 34
   - Gets all PCS revisions (official and unofficial)
   - Expected: ~362 PCS revisions

7. **05c_load_pcs_details.sql** - Load PCS details (OFFICIAL_ONLY mode)
   - Only loads details for official PCS revisions
   - 6 detail types: Header, Temp/Pressure, Pipe Sizes, Pipe Elements, Valve Elements, Embedded Notes

### Phase 5: VDS Processing (Global)
8. **05d_load_vds_list.sql** - Load global VDS list
   - Loads ALL VDS from API (~53,319 records)
   - Not plant-specific

9. **05e_load_vds_details.sql** - Load VDS details (official only)
   - Only loads details for official VDS revisions
   - Limited to 10 API calls max

## Key Dependencies
- Steps 1-2: Plants must exist before selection
- Steps 3-4: Issues must exist before selection  
- Step 5a: Must have selected issue
- Steps 5b-5c: Require PCS references from 5a
- Steps 5d-5e: VDS list is global, details depend on references from 5a

## Current Issue
- Step 5a (references) appears to not be loading when called from run_full_etl
- But works when called directly

## Note
- 05_run_remaining_etl.sql has been archived to avoid confusion
- Use 00_run_all_steps.sql which now calls each individual step directly