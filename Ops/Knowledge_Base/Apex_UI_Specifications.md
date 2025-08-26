# APEX UI Requirements for Plant Selection

## Required APEX Components

### Page: Plant Selection Manager

#### 1. Plant Selection Region
**Type**: Interactive Grid or Checkbox Group
**Source**: 
```sql
SELECT plant_id, 
       short_description || ' (' || plant_id || ')' as display_value,
       CASE 
         WHEN plant_id IN (SELECT plant_id FROM SELECTION_LOADER WHERE is_active = 'Y')
         THEN 'Y' 
         ELSE 'N' 
       END as selected
FROM PLANTS 
WHERE is_valid = 'Y'
ORDER BY short_description;
```

#### 2. Required Buttons

##### Button: "Add Selected Plants"
**Action**: PL/SQL Process
```sql
BEGIN
  -- Add selected plants to SELECTION_LOADER
  FOR i IN 1..APEX_APPLICATION.G_F01.COUNT LOOP
    MERGE INTO SELECTION_LOADER tgt
    USING (SELECT APEX_APPLICATION.G_F01(i) as plant_id FROM DUAL) src
    ON (tgt.plant_id = src.plant_id AND tgt.issue_revision IS NULL)
    WHEN NOT MATCHED THEN
      INSERT (plant_id, is_active, selection_type, created_by, created_date)
      VALUES (src.plant_id, 'Y', 'MANUAL', :APP_USER, SYSDATE)
    WHEN MATCHED THEN
      UPDATE SET is_active = 'Y', last_modified_date = SYSDATE;
  END LOOP;
  COMMIT;
END;
```

##### Button: "Remove Selected Plants"
**Action**: PL/SQL Process
```sql
BEGIN
  -- Deactivate selected plants
  FOR i IN 1..APEX_APPLICATION.G_F01.COUNT LOOP
    UPDATE SELECTION_LOADER 
    SET is_active = 'N', 
        last_modified_date = SYSDATE
    WHERE plant_id = APEX_APPLICATION.G_F01(i);
  END LOOP;
  COMMIT;
END;
```

##### Button: "Clear All Selections"
**Action**: PL/SQL Process
```sql
BEGIN
  UPDATE SELECTION_LOADER 
  SET is_active = 'N', 
      last_modified_date = SYSDATE
  WHERE is_active = 'Y';
  COMMIT;
END;
```

##### Button: "Fetch Issues for Selected Plants"
**Action**: PL/SQL Process
```sql
DECLARE
  v_status VARCHAR2(50);
  v_message VARCHAR2(4000);
  v_count NUMBER := 0;
BEGIN
  FOR plant_rec IN (
    SELECT DISTINCT plant_id 
    FROM SELECTION_LOADER 
    WHERE is_active = 'Y'
  ) LOOP
    pkg_api_client.refresh_issues_from_api(
      p_plant_id => plant_rec.plant_id,
      p_status => v_status,
      p_message => v_message
    );
    
    IF v_status = 'SUCCESS' THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;
  
  :P_SUCCESS_MESSAGE := 'Issues fetched for ' || v_count || ' plants';
END;
```

#### 3. Display Regions

##### Region: "Currently Selected Plants"
**Type**: Classic Report
**Source**:
```sql
SELECT plant_id,
       (SELECT short_description FROM PLANTS WHERE PLANTS.plant_id = s.plant_id) as plant_name,
       created_date as selected_date,
       NVL(last_etl_run, 'Never') as last_processed
FROM SELECTION_LOADER s
WHERE is_active = 'Y'
ORDER BY plant_id;
```

##### Region: "Selection Statistics"
**Type**: Static Content with Substitution Strings
**Items to Create**:
- P_TOTAL_PLANTS (from PLANTS where is_valid='Y')
- P_SELECTED_PLANTS (from SELECTION_LOADER where is_active='Y')  
- P_ISSUES_COUNT (from ISSUES where plant_id in selected and is_valid='Y')

---

## Alternative: Direct SQL Commands (For Testing)

### To Select Plants (Backend Only):
```sql
-- Clear previous selections
UPDATE SELECTION_LOADER SET is_active = 'N';

-- Add JSP2 and GRANE
INSERT INTO SELECTION_LOADER (plant_id, issue_revision, is_active, selection_type, created_by)
VALUES ('JSP2', NULL, 'Y', 'MANUAL', USER);

INSERT INTO SELECTION_LOADER (plant_id, issue_revision, is_active, selection_type, created_by)
VALUES ('GRANE', NULL, 'Y', 'MANUAL', USER);

COMMIT;
```

### To Fetch Issues:
```sql
-- For each selected plant
EXEC pkg_api_client.refresh_issues_from_api('JSP2', :status, :message);
EXEC pkg_api_client.refresh_issues_from_api('GRANE', :status, :message);
```

---

## Navigation Flow

1. User sees list of all active plants
2. Selects checkboxes for desired plants
3. Clicks "Add Selected Plants" → Updates SELECTION_LOADER
4. Clicks "Fetch Issues" → Calls API for each plant
5. Views issues in separate region/page
6. Selects specific issue revisions if needed
7. Runs full ETL for selected data

---

## Future Enhancements

1. **Bulk Operations**: Select all/Deselect all buttons
2. **Filter Options**: By operator, area, category
3. **Search**: Quick search by plant name/ID
4. **Issue Preview**: Show issue count before fetching
5. **Progress Bar**: For long-running API calls
6. **Export**: Selected plants to CSV