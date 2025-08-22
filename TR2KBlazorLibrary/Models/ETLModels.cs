using System;

namespace TR2KBlazorLibrary.Models
{
    /// <summary>
    /// Model for SELECTION_LOADER table
    /// </summary>
    public class SelectionModel
    {
        public int SelectionId { get; set; }
        public string PlantId { get; set; } = string.Empty;
        public string? IssueRevision { get; set; }
        public bool IsActive { get; set; }
        public string IsActiveChar { get; set; } = "Y"; // For Dapper mapping
        public string? SelectedBy { get; set; }
        public DateTime SelectionDate { get; set; }
        public DateTime? LastEtlRun { get; set; }
        public string? EtlStatus { get; set; }
    }

    /// <summary>
    /// Model for ETL_RUN_LOG table
    /// </summary>
    public class EtlRunModel
    {
        public int RunId { get; set; }
        public string RunType { get; set; } = string.Empty;
        public string? EndpointKey { get; set; }
        public string? PlantId { get; set; }
        public string? IssueRevision { get; set; }
        public DateTime StartTime { get; set; }
        public DateTime? EndTime { get; set; }
        public string Status { get; set; } = string.Empty;
        public int RecordsProcessed { get; set; }
        public int RecordsInserted { get; set; }
        public int RecordsUpdated { get; set; }
        public int RecordsInvalidated { get; set; }
        public int ErrorCount { get; set; }
        public int? DurationSeconds { get; set; }
        public string? InitiatedBy { get; set; }
        public string? Notes { get; set; }
    }

    /// <summary>
    /// Model for ETL_ERROR_LOG table
    /// </summary>
    public class EtlErrorModel
    {
        public int ErrorId { get; set; }
        public int? RunId { get; set; }
        public string? EndpointKey { get; set; }
        public string? PlantId { get; set; }
        public string? IssueRevision { get; set; }
        public DateTime ErrorTimestamp { get; set; }
        public string? ErrorType { get; set; }
        public string? ErrorCode { get; set; }
        public string? ErrorMessage { get; set; }
        public string? ErrorStack { get; set; }
        public string? RawData { get; set; }
        public string ResolutionStatus { get; set; } = "OPEN";
        public string? ResolvedBy { get; set; }
        public string? ResolutionNotes { get; set; }
    }

    /// <summary>
    /// Model for CONTROL_ENDPOINTS table
    /// </summary>
    public class ControlEndpointModel
    {
        public int EndpointId { get; set; }
        public string EndpointKey { get; set; } = string.Empty;
        public string EndpointUrlPattern { get; set; } = string.Empty;
        public string? EndpointDescription { get; set; }
        public int ProcessingOrder { get; set; }
        public bool IsActive { get; set; }
        public string IsActiveChar { get; set; } = "Y";
        public bool RequiresPlant { get; set; }
        public string RequiresPlantChar { get; set; } = "N";
        public bool RequiresIssue { get; set; }
        public string RequiresIssueChar { get; set; } = "N";
        public string? ParseProcedure { get; set; }
        public string? UpsertProcedure { get; set; }
        public DateTime CreatedDate { get; set; }
    }

    /// <summary>
    /// Model for ETL statistics dashboard
    /// </summary>
    public class EtlStatistics
    {
        public int TotalRuns { get; set; }
        public int SuccessfulRuns { get; set; }
        public int FailedRuns { get; set; }
        public int TotalRecordsProcessed { get; set; }
        public int TotalRecordsInserted { get; set; }
        public int TotalRecordsUpdated { get; set; }
        public int TotalRecordsInvalidated { get; set; }
        public double AverageRunDuration { get; set; }
        public DateTime? LastRunTime { get; set; }
        public string? LastRunStatus { get; set; }
        public int ActiveSelections { get; set; }
        public int PendingErrors { get; set; }
    }

    /// <summary>
    /// Model for RAW_JSON table
    /// </summary>
    public class RawJsonModel
    {
        public int RawJsonId { get; set; }
        public string EndpointKey { get; set; } = string.Empty;
        public string? PlantId { get; set; }
        public string? IssueRevision { get; set; }
        public string ApiUrl { get; set; } = string.Empty;
        public string ResponseJson { get; set; } = string.Empty;
        public string ResponseHash { get; set; } = string.Empty;
        public DateTime ApiCallTimestamp { get; set; }
        public DateTime CreatedDate { get; set; }
    }
}