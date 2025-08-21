-- =====================================================
-- CLEANUP STRATEGY WITHOUT DBA PERMISSIONS
-- All cleanup handled within ETL process
-- =====================================================

-- OPTION 1: Add to SP_PROCESS_ETL_BATCH (At the END - BETTER!)
-- This runs AFTER successful processing
CREATE OR REPLACE PROCEDURE SP_PROCESS_ETL_BATCH(
    p_etl_run_id IN NUMBER,
    p_entity_type IN VARCHAR2
) AS
    v_step VARCHAR2(100);
BEGIN
    -- PROCESS DATA FIRST (priority)
    v_step := 'PROCESSING';
    
    -- ... all normal ETL processing ...
    -- ... deduplication, validation, SCD2, etc ...
    
    -- Update control with success
    UPDATE ETL_CONTROL
    SET STATUS = 'SUCCESS',
        END_TIME = SYSTIMESTAMP
    WHERE ETL_RUN_ID = p_etl_run_id;
    
    -- COMMIT the ETL work
    COMMIT;
    
    -- CLEANUP OLD DATA LAST (after success)
    -- This is OUTSIDE the main transaction (already committed)
    v_step := 'CLEANUP';
    BEGIN
        -- Keep only last 10 ETL runs
        DELETE FROM ETL_CONTROL
        WHERE ETL_RUN_ID < (
            SELECT MIN(ETL_RUN_ID) 
            FROM (
                SELECT ETL_RUN_ID 
                FROM ETL_CONTROL 
                ORDER BY ETL_RUN_ID DESC
            ) 
            WHERE ROWNUM <= 10
        );
        
        -- Clean old error logs (30 days)
        DELETE FROM ETL_ERROR_LOG 
        WHERE ERROR_TIME < SYSDATE - 30;
        
        -- Clean orphaned staging data (safety - should be empty)
        DELETE FROM STG_OPERATORS WHERE ETL_RUN_ID < p_etl_run_id - 10;
        DELETE FROM STG_PLANTS WHERE ETL_RUN_ID < p_etl_run_id - 10;
        DELETE FROM STG_ISSUES WHERE ETL_RUN_ID < p_etl_run_id - 10;
        
        COMMIT; -- Separate commit for cleanup
    EXCEPTION
        WHEN OTHERS THEN
            -- Cleanup failure is NOT critical
            -- Log it but don't fail the ETL
            LOG_ETL_ERROR(
                p_etl_run_id,
                'CLEANUP',
                SQLCODE,
                'Non-critical cleanup error: ' || SQLERRM,
                NULL
            );
    END;
    
    -- ETL is complete regardless of cleanup
END;
/

-- OPTION 2: Manual Cleanup Procedure (Run when needed)
CREATE OR REPLACE PROCEDURE SP_MANUAL_CLEANUP AS
BEGIN
    -- Can be called from C# or manually
    -- Keep last 10 ETL runs
    DELETE FROM ETL_CONTROL
    WHERE ETL_RUN_ID NOT IN (
        SELECT ETL_RUN_ID 
        FROM (
            SELECT ETL_RUN_ID 
            FROM ETL_CONTROL 
            ORDER BY ETL_RUN_ID DESC
        ) 
        WHERE ROWNUM <= 10
    );
    
    -- Clean error logs older than 30 days
    DELETE FROM ETL_ERROR_LOG 
    WHERE ERROR_TIME < SYSDATE - 30;
    
    -- Clean orphaned staging records
    DELETE FROM STG_OPERATORS 
    WHERE ETL_RUN_ID NOT IN (SELECT ETL_RUN_ID FROM ETL_CONTROL);
    
    DELETE FROM STG_PLANTS 
    WHERE ETL_RUN_ID NOT IN (SELECT ETL_RUN_ID FROM ETL_CONTROL);
    
    DELETE FROM STG_ISSUES 
    WHERE ETL_RUN_ID NOT IN (SELECT ETL_RUN_ID FROM ETL_CONTROL);
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Cleanup complete: ' || SQL%ROWCOUNT || ' records removed');
END;
/

-- OPTION 3: Cleanup in C# Service
-- Add this method to OracleETLServiceV2.cs:
/*
public async Task<bool> PerformCleanup()
{
    try
    {
        using var connection = new OracleConnection(_connectionString);
        await connection.OpenAsync();
        
        // Keep last 10 runs
        await connection.ExecuteAsync(@"
            DELETE FROM ETL_CONTROL
            WHERE ETL_RUN_ID < (
                SELECT MIN(ETL_RUN_ID) FROM (
                    SELECT ETL_RUN_ID FROM ETL_CONTROL 
                    ORDER BY ETL_RUN_ID DESC
                    FETCH FIRST 10 ROWS ONLY
                )
            )");
        
        // Clean 30-day old errors
        await connection.ExecuteAsync(
            "DELETE FROM ETL_ERROR_LOG WHERE ERROR_TIME < :cutoff",
            new { cutoff = DateTime.Now.AddDays(-30) });
        
        return true;
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Cleanup failed");
        return false;
    }
}
*/

-- =====================================================
-- WHY THIS IS BETTER THAN SCHEDULED JOBS
-- =====================================================
/*
1. NO DBA REQUIRED
   - Everything runs with your user permissions
   - No DBMS_SCHEDULER privileges needed
   - No coordination with DBA team

2. PREDICTABLE TIMING
   - Cleanup happens when YOU run ETL
   - No surprise cleanups during processing
   - No race conditions

3. SIMPLER ARCHITECTURE
   - One less moving part to monitor
   - No scheduled job failures to debug
   - Everything in your control

4. BETTER PERFORMANCE
   - Cleanup happens when system is already active
   - Not competing with overnight batch jobs
   - Can be optimized with your ETL

5. EASIER TROUBLESHOOTING
   - If cleanup fails, you know immediately
   - Part of your ETL logs
   - No separate job logs to check
*/

-- =====================================================
-- RECOMMENDED APPROACH
-- =====================================================
/*
1. Add cleanup to beginning of SP_PROCESS_ETL_BATCH
2. This ensures cleanup runs BEFORE each ETL
3. Benefits:
   - Automatic (no manual intervention)
   - Guaranteed to run (part of ETL)
   - Fails safely (before data processing)
   - No DBA involvement needed
   
4. For RAW_JSON table (if you use it):
   - Don't even create it if not needed
   - Or add cleanup: DELETE FROM RAW_JSON WHERE LOAD_TS < SYSDATE - 30
*/