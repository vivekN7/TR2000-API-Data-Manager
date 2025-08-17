-- =====================================================
-- ETL PLANT LOADER CONFIGURATION TABLE
-- Purpose: Control which plants to load data for in ETL processes
-- This dramatically reduces API calls by only loading selected plants
-- =====================================================

-- Drop existing table if needed
-- DROP TABLE ETL_PLANT_LOADER;

CREATE TABLE ETL_PLANT_LOADER (
    PLANT_ID           VARCHAR2(50) NOT NULL,
    PLANT_NAME         VARCHAR2(200),
    IS_ACTIVE          CHAR(1) DEFAULT 'Y' CHECK (IS_ACTIVE IN ('Y', 'N')),
    LOAD_PRIORITY      NUMBER DEFAULT 100,  -- Lower number = higher priority
    NOTES              VARCHAR2(500),
    CREATED_DATE       DATE DEFAULT SYSDATE,
    CREATED_BY         VARCHAR2(100) DEFAULT USER,
    MODIFIED_DATE      DATE DEFAULT SYSDATE,
    MODIFIED_BY        VARCHAR2(100) DEFAULT USER,
    CONSTRAINT PK_ETL_PLANT_LOADER PRIMARY KEY (PLANT_ID)
);

-- Create index for active plants
CREATE INDEX IDX_ETL_PLANT_ACTIVE ON ETL_PLANT_LOADER(IS_ACTIVE, LOAD_PRIORITY);

-- Add some sample plants for testing (adjust as needed)
-- These are commonly used plants based on the API calls I saw
INSERT INTO ETL_PLANT_LOADER (PLANT_ID, PLANT_NAME, LOAD_PRIORITY, NOTES) VALUES 
    ('34', 'Gullfaks A', 10, 'High priority - active project'),
    ('47', 'Oseberg Øst', 20, 'Active development'),
    ('92', 'Åsgard B', 30, 'Regular updates needed');

COMMIT;

-- View to show active plants with their details
CREATE OR REPLACE VIEW V_ACTIVE_ETL_PLANTS AS
SELECT 
    L.PLANT_ID,
    L.PLANT_NAME,
    L.LOAD_PRIORITY,
    L.NOTES,
    P.LONG_DESCRIPTION,
    P.OPERATOR_ID,
    (SELECT COUNT(*) FROM ISSUES I WHERE I.PLANT_ID = L.PLANT_ID AND I.IS_CURRENT = 'Y') AS ISSUE_COUNT
FROM ETL_PLANT_LOADER L
LEFT JOIN PLANTS P ON L.PLANT_ID = P.PLANT_ID AND P.IS_CURRENT = 'Y'
WHERE L.IS_ACTIVE = 'Y'
ORDER BY L.LOAD_PRIORITY, L.PLANT_ID;