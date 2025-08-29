-- ===============================================================================
-- Create Consolidated Views
-- Date: 2025-12-30
-- Purpose: Create simplified, user-friendly consolidated views
-- ===============================================================================

-- VDS Dashboard - simplified
CREATE OR REPLACE VIEW V_VDS_DASHBOARD AS
SELECT 
    'Summary' as metric_type,
    'Total VDS Records' as metric_name,
    TO_CHAR(COUNT(*)) as metric_value
FROM VDS_LIST
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'Summary' as metric_type,
    'Total VDS Details' as metric_name,
    TO_CHAR(COUNT(*)) as metric_value
FROM VDS_DETAILS
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'Summary' as metric_type,
    'Unique VDS Names' as metric_name,
    TO_CHAR(COUNT(DISTINCT vds_name)) as metric_value
FROM VDS_LIST
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'Status' as metric_type,
    'Valid Records' as metric_name,
    TO_CHAR(COUNT(*)) as metric_value
FROM VDS_LIST
WHERE is_valid = 'Y'
UNION ALL
SELECT 
    'Status' as metric_type,
    'Invalid Records' as metric_name,
    TO_CHAR(COUNT(*)) as metric_value
FROM VDS_LIST
WHERE is_valid = 'N';

-- Check view count
SELECT COUNT(*) as total_views FROM user_views;