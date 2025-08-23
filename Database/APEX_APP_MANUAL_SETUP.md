# TR2000 ETL Manager - APEX Application Setup Guide

## Overview
This guide provides step-by-step instructions to create the TR2000 ETL Manager application in Oracle APEX.

## Prerequisites
✅ Oracle Database 21c with APEX 24.2 installed
✅ TR2000_STAGING schema with all database objects created
✅ Oracle wallet configured at C:\Oracle\wallet
✅ APEX_WEB_SERVICE working with HTTPS

## Database Objects Already Created
- **Tables**: APEX_ETL_LOG, PLANTS, ISSUES, SELECTION_LOADER, RAW_JSON
- **Views**: v_apex_dashboard_stats, v_apex_recent_activity, v_apex_plant_lov, v_apex_issues_lov, v_apex_etl_history
- **Procedures**: apex_process_refresh_plants, apex_process_save_selection, apex_process_run_etl, apex_process_clear_selection
- **Packages**: pkg_api_client, pkg_etl_operations

## Step 1: Access APEX and Create Workspace

1. **Access APEX Admin Console**
   - URL: `http://localhost:8080/apex/apex_admin`
   - Username: ADMIN
   - Password: [Your APEX admin password]

2. **Create Workspace**
   - Click "Create Workspace"
   - Workspace Name: `TR2000_ETL`
   - Database User: `TR2000_STAGING`
   - Password: `justkeepswimming` (or set new)
   - Space Quota: 100MB
   - Click "Create Workspace"

3. **Sign Out and Login to New Workspace**
   - Workspace: TR2000_ETL
   - Username: TR2000_STAGING
   - Password: [as set above]

## Step 2: Create Application

1. **App Builder → Create**
   - Choose: New Application
   - Name: `TR2000 ETL Manager`
   - Appearance:
     - Theme Style: Universal Theme
     - Theme: Vita
     - Navigation: Side Menu
   - Features: Check all default features
   - Click "Create Application"

## Step 3: Create Page 1 - Dashboard

1. **Create Page**
   - Click "Create Page"
   - Page Type: Dashboard
   - Page Name: `Dashboard`
   - Page Number: 1 (default)
   - Navigation: Yes
   - Click "Create Page"

2. **Add Statistics Cards Region**
   - Right Panel → Regions → Create Region
   - Title: `ETL Statistics`
   - Type: Cards
   - Source:
     - Type: SQL Query
     - SQL Query:
     ```sql
     SELECT 
         metric_name as card_title,
         metric_value as card_value,
         metric_type as card_color,
         'fa-database' as card_icon
     FROM v_apex_dashboard_stats
     ```
   - Template Options:
     - Style: Featured
     - Icons: Display

3. **Add Recent Activity Region**
   - Create Region
   - Title: `Recent ETL Activity`
   - Type: Classic Report
   - Source:
     - Type: SQL Query
     - SQL Query:
     ```sql
     SELECT 
         run_type,
         endpoint_key,
         plant_id,
         TO_CHAR(start_time, 'DD-MON HH24:MI') as start_time,
         duration_seconds || 's' as duration,
         status,
         '<span class="' || status_icon || '"></span>' as icon
     FROM v_apex_recent_activity
     ```
   - Attributes:
     - Enable Search: Yes
     - Rows Per Page: 10

4. **Add Navigation Buttons**
   - Create Region
   - Title: `Quick Actions`
   - Type: Static Content
   - Add Button: `Refresh Plants`
     - Action: Submit Page
     - Database Action: apex_process_refresh_plants
   - Add Button: `Go to ETL Operations`
     - Action: Redirect to Page 2

## Step 4: Create Page 2 - ETL Operations

1. **Create Page**
   - Page Type: Blank Page
   - Page Name: `ETL Operations`
   - Page Number: 2
   - Navigation: Yes

2. **Add Plant Selection Region**
   - Create Region
   - Title: `Select Plants (Max 10)`
   - Type: Static Content
   - Create Page Item:
     - Name: `P2_PLANTS`
     - Type: Checkbox Group
     - List of Values:
       - Type: SQL Query
       ```sql
       SELECT display_value, return_value
       FROM v_apex_plant_lov
       ORDER BY return_value
       ```
     - Display: 3 columns
     - Default (SQL Query):
       ```sql
       SELECT plant_id 
       FROM SELECTION_LOADER 
       WHERE is_active = 'Y'
       ```

3. **Add Control Buttons Region**
   - Create Region
   - Title: `Actions`
   - Type: Static Content
   - Position: Region Body 2
   - Add Buttons:
     
   **Button: Save Selection**
   - Name: `B_SAVE`
   - Action: Submit Page
   - Process:
     ```sql
     BEGIN
       apex_process_save_selection(:P2_PLANTS, :APP_SESSION);
       apex_application.g_print_success_message := 'Selection saved successfully';
     END;
     ```
   
   **Button: Refresh Plants**
   - Name: `B_REFRESH`
   - Action: Submit Page
   - Process:
     ```sql
     BEGIN
       apex_process_refresh_plants(:APP_SESSION);
       apex_application.g_print_success_message := 'Plants refreshed from API';
     END;
     ```
   
   **Button: Run ETL**
   - Name: `B_RUN_ETL`
   - Action: Submit Page
   - Confirm Message: "Run ETL for selected plants?"
   - Process:
     ```sql
     BEGIN
       apex_process_run_etl(:APP_SESSION);
       apex_application.g_print_success_message := 'ETL completed successfully';
     END;
     ```
   
   **Button: Clear Selection**
   - Name: `B_CLEAR`
   - Action: Submit Page
   - Process:
     ```sql
     BEGIN
       apex_process_clear_selection(:APP_SESSION);
       apex_application.g_print_success_message := 'Selection cleared';
     END;
     ```

4. **Add Execution Log Region**
   - Create Region
   - Title: `ETL Execution Log`
   - Type: Interactive Report
   - Source:
     ```sql
     SELECT 
         run_id,
         run_type,
         endpoint_key,
         plant_id,
         TO_CHAR(start_time, 'DD-MON HH24:MI:SS') as start_time,
         TO_CHAR(end_time, 'DD-MON HH24:MI:SS') as end_time,
         duration_seconds,
         status,
         records_processed,
         records_inserted,
         initiated_by
     FROM v_apex_etl_history
     ```
   - Features:
     - Download: CSV, Excel
     - Search: Yes
     - Actions Menu: Yes

5. **Add JavaScript Validation**
   - Page Properties → JavaScript → Function and Global Variable Declaration:
   ```javascript
   function validatePlantCount() {
       var checkedCount = $('input[name="P2_PLANTS"]:checked').length;
       if (checkedCount > 10) {
           apex.message.showErrors({
               type: "error",
               location: "page",
               message: "Maximum 10 plants can be selected",
               unsafe: false
           });
           return false;
       }
       return true;
   }
   ```

   - Add Validation to Save Button:
     - Condition Type: JavaScript Expression
     - JavaScript Expression: `validatePlantCount()`

## Step 5: Configure Processes

1. **Page 1 Process - Refresh Plants**
   - Processing → Processes → Create Process
   - Name: `Refresh Plants from API`
   - Type: PL/SQL Code
   - PL/SQL Code:
   ```sql
   DECLARE
       v_status VARCHAR2(50);
       v_message VARCHAR2(4000);
   BEGIN
       pkg_api_client.refresh_plants_from_api(v_status, v_message);
       IF v_status = 'SUCCESS' THEN
           apex_application.g_print_success_message := v_message;
       ELSE
           raise_application_error(-20001, v_message);
       END IF;
   END;
   ```
   - When Button Pressed: REFRESH_PLANTS

2. **Page 2 Processes** - Add similar processes for each button

## Step 6: Add Auto-Refresh

1. **Dashboard Page**
   - Page Properties → JavaScript → Execute when Page Loads:
   ```javascript
   // Auto-refresh every 60 seconds
   setInterval(function() {
       apex.region("recent_activity").refresh();
       apex.region("statistics").refresh();
   }, 60000);
   ```

2. **ETL Operations Page**
   - Similar auto-refresh for execution log:
   ```javascript
   setInterval(function() {
       apex.region("execution_log").refresh();
   }, 30000);
   ```

## Step 7: Testing

1. **Test Plant Refresh**
   - Click "Refresh Plants" button
   - Verify plants are loaded from API

2. **Test Selection**
   - Select 3-5 plants
   - Click "Save Selection"
   - Verify selection is saved

3. **Test ETL Run**
   - With plants selected, click "Run ETL"
   - Monitor execution log
   - Verify ETL completes

4. **Test Clear**
   - Click "Clear Selection"
   - Verify all selections removed

## Step 8: Enable Scheduler Jobs

Once application is working, enable the automated jobs:

```sql
-- Enable daily plant refresh
BEGIN
    DBMS_SCHEDULER.ENABLE('TR2000_DAILY_PLANT_REFRESH');
END;
/

-- Enable hourly issues refresh
BEGIN
    DBMS_SCHEDULER.ENABLE('TR2000_HOURLY_ISSUES_REFRESH');
END;
/

-- Enable weekly cleanup
BEGIN
    DBMS_SCHEDULER.ENABLE('TR2000_WEEKLY_CLEANUP');
END;
/
```

## Troubleshooting

### Common Issues:

1. **"ORA-20001: No response from API"**
   - Check wallet configuration
   - Verify network ACLs
   - Test with: `SELECT pkg_api_client.fetch_plants_json FROM dual;`

2. **Plants not showing in checkbox**
   - Run: `SELECT * FROM v_apex_plant_lov;`
   - Ensure PLANTS table has data

3. **Processes failing**
   - Check APEX_ETL_LOG table for errors
   - Verify procedures are compiled: 
   ```sql
   SELECT object_name, status 
   FROM user_objects 
   WHERE object_name LIKE 'APEX_%';
   ```

## Summary

The TR2000 ETL Manager application provides:
- ✅ Simple 2-page interface
- ✅ Plant selection with 10-plant limit
- ✅ API refresh capabilities
- ✅ ETL execution and monitoring
- ✅ Automatic scheduling options
- ✅ Full audit trail in APEX_ETL_LOG

Total implementation time: ~30 minutes

## Next Steps
1. Customize theme colors/logo
2. Add email notifications
3. Implement issue selection (Page 2 enhancement)
4. Add data export features
5. Create user access controls