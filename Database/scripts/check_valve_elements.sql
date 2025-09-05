-- Check what's in STG_PCS_VALVE_ELEMENTS
SELECT COUNT(*) as count FROM STG_PCS_VALVE_ELEMENTS;

-- Check for non-numeric values in numeric columns
SELECT 
    'ValveGroupNo' as column_name,
    COUNT(*) as total,
    SUM(CASE WHEN "ValveGroupNo" IS NULL THEN 1 ELSE 0 END) as nulls,
    SUM(CASE WHEN "ValveGroupNo" IS NOT NULL 
             AND NOT REGEXP_LIKE("ValveGroupNo", '^-?[0-9]+(\.[0-9]+)?$') 
             THEN 1 ELSE 0 END) as non_numeric
FROM STG_PCS_VALVE_ELEMENTS
UNION ALL
SELECT 
    'LineNo',
    COUNT(*),
    SUM(CASE WHEN "LineNo" IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN "LineNo" IS NOT NULL 
             AND NOT REGEXP_LIKE("LineNo", '^-?[0-9]+(\.[0-9]+)?$') 
             THEN 1 ELSE 0 END)
FROM STG_PCS_VALVE_ELEMENTS
UNION ALL
SELECT 
    'NoteID',
    COUNT(*),
    SUM(CASE WHEN "NoteID" IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN "NoteID" IS NOT NULL 
             AND NOT REGEXP_LIKE("NoteID", '^-?[0-9]+(\.[0-9]+)?$') 
             THEN 1 ELSE 0 END)
FROM STG_PCS_VALVE_ELEMENTS;

-- Show a sample of the problematic data
SELECT "ValveGroupNo", "LineNo", "NoteID"
FROM STG_PCS_VALVE_ELEMENTS
WHERE ROWNUM <= 5;

EXIT;
