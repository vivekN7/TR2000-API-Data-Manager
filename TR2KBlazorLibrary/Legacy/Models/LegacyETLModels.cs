namespace TR2KBlazorLibrary.Legacy.Models
{
    /// <summary>
    /// Result of an ETL operation
    /// </summary>
    public class ETLResult
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public int RecordsProcessed { get; set; }
        public int RecordsInserted { get; set; }
        public int RecordsUpdated { get; set; }
        public int RecordsDeleted { get; set; }
        public int RecordsUnchanged { get; set; }
        public int RecordsReactivated { get; set; }
        public int RecordsLoaded { get; set; }  // Added for compatibility
        public int ApiCallCount { get; set; }
        public int PlantIterations { get; set; }
        public int IssueIterations { get; set; }
        public double DurationSeconds { get; set; }
        public double ProcessingTimeSeconds { get; set; }  // Added for compatibility
        public string? ErrorMessage { get; set; }
        public string? Details { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime EndTime { get; set; }
        public string EndpointName { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public int ErrorCount { get; set; }
        
        // Calculated properties
        public double RecordsPerSecond => DurationSeconds > 0 ? RecordsProcessed / DurationSeconds : 0;
        public double RecordsPerApiCall => ApiCallCount > 0 ? (double)RecordsProcessed / ApiCallCount : 0;
        public string FormattedDuration => DurationSeconds < 60 
            ? $"{DurationSeconds:F1} seconds" 
            : $"{DurationSeconds / 60:F1} minutes";
        public string Efficiency => ApiCallCount > 0 
            ? $"{RecordsPerApiCall:F1} records/API call" 
            : "N/A";
    }

    /// <summary>
    /// SQL preview for ETL operations
    /// </summary>
    public class ETLSqlPreview
    {
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public List<ETLStep> Steps { get; set; } = new List<ETLStep>();
    }

    /// <summary>
    /// Individual step in an ETL operation
    /// </summary>
    public class ETLStep
    {
        public int StepNumber { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string SqlStatement { get; set; } = string.Empty;
    }

    /// <summary>
    /// ETL run history record
    /// </summary>
    public class ETLRunHistory
    {
        public int ETL_RUN_ID { get; set; }
        public string? RUN_TYPE { get; set; }
        public string? STATUS { get; set; }
        public DateTime? START_TIME { get; set; }
        public DateTime? END_TIME { get; set; }
        public decimal? PROCESSING_TIME_SEC { get; set; }
        public int? RECORDS_LOADED { get; set; }
        public int? RECORDS_UPDATED { get; set; }
        public int? RECORDS_UNCHANGED { get; set; }
        public int? RECORDS_DELETED { get; set; }
        public int? RECORDS_REACTIVATED { get; set; }
        public int? ERROR_COUNT { get; set; }
        public int? API_CALL_COUNT { get; set; }
        public string? COMMENTS { get; set; }
        
        // Alias properties for compatibility
        public int RunId => ETL_RUN_ID;
        public string? RunType => RUN_TYPE;
        public string? Status => STATUS;
        public DateTime? StartTime => START_TIME;
        public decimal? ProcessingTimeSeconds => PROCESSING_TIME_SEC;
        public int? RecordsLoaded => RECORDS_LOADED;
        public int? RecordsUpdated => RECORDS_UPDATED;
        public int? RecordsUnchanged => RECORDS_UNCHANGED;
        public int? RecordsDeleted => RECORDS_DELETED;
        public int? RecordsReactivated => RECORDS_REACTIVATED;
        public int? ApiCallCount => API_CALL_COUNT;
    }

    /// <summary>
    /// Oracle table status information
    /// </summary>
    public class TableStatus
    {
        public string TABLE_NAME { get; set; } = string.Empty;
        public int RECORD_COUNT { get; set; }
        public int CURRENT_COUNT { get; set; }
        public int DELETED_COUNT { get; set; }
        public DateTime? LAST_UPDATE { get; set; }
        public string? TABLE_TYPE { get; set; }
        
        // Alias properties for compatibility
        public string TableName => TABLE_NAME;
        public int TotalRows => RECORD_COUNT;
        public int CurrentRows => CURRENT_COUNT;
        public int HistoricalRows => RECORD_COUNT - CURRENT_COUNT;
        public DateTime? LastModified => LAST_UPDATE;
    }
}