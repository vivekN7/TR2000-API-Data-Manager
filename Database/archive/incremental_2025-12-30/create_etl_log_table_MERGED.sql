-- ===============================================================================
-- Create ETL_LOG Table for TR2000_UTIL Package
-- Date: 2025-08-27
-- Purpose: Create logging table required by DBA's tr2000_util package
-- ===============================================================================

-- Create the ETL_LOG table in TR2000_STAGING schema
CREATE TABLE ETL_LOG (
    log_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    endpoint       VARCHAR2(500),
    query_params   VARCHAR2(2000),
    http_status    NUMBER,
    rows_ingested  NUMBER,
    batch_id       VARCHAR2(100),
    error_msg      VARCHAR2(4000),
    created_at     TIMESTAMP DEFAULT SYSTIMESTAMP
);

COMMENT ON TABLE ETL_LOG IS 'API call logging for TR2000_UTIL package';
COMMENT ON COLUMN ETL_LOG.log_id IS 'Unique identifier for each log entry';
COMMENT ON COLUMN ETL_LOG.endpoint IS 'API endpoint called';
COMMENT ON COLUMN ETL_LOG.query_params IS 'Query parameters used';
COMMENT ON COLUMN ETL_LOG.http_status IS 'HTTP response status code';
COMMENT ON COLUMN ETL_LOG.rows_ingested IS 'Number of rows processed';
COMMENT ON COLUMN ETL_LOG.batch_id IS 'Batch identifier for grouping calls';
COMMENT ON COLUMN ETL_LOG.error_msg IS 'Error message if any';
COMMENT ON COLUMN ETL_LOG.created_at IS 'Timestamp of the log entry';

-- Create index for performance
CREATE INDEX IDX_ETL_LOG_BATCH ON ETL_LOG(batch_id);
CREATE INDEX IDX_ETL_LOG_CREATED ON ETL_LOG(created_at);

PROMPT ETL_LOG table created successfully