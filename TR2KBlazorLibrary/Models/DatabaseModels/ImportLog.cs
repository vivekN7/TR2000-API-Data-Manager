using System.ComponentModel.DataAnnotations.Schema;

namespace TR2KBlazorLibrary.Models.DatabaseModels;

public class ImportLog : BaseEntity
{
    public string Endpoint { get; set; } = string.Empty;
    public ImportStatus Status { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public int RecordsImported { get; set; } = 0;
    public string? ErrorMessage { get; set; }
    
    // Calculated properties - exclude from database mapping
    [NotMapped]
    public TimeSpan? Duration => EndTime.HasValue ? EndTime.Value - StartTime : null;
    [NotMapped]
    public bool IsCompleted => Status == ImportStatus.Completed || Status == ImportStatus.Failed;
    [NotMapped]
    public bool IsInProgress => Status == ImportStatus.InProgress;
}

public enum ImportStatus
{
    Started = 0,
    InProgress = 1,
    Completed = 2,
    Failed = 3,
    Cancelled = 4
}

public class ImportLogSummary
{
    public string Endpoint { get; set; } = string.Empty;
    public int TotalImports { get; set; }
    public int SuccessfulImports { get; set; }
    public int FailedImports { get; set; }
    public DateTime? LastImportDate { get; set; }
    public ImportStatus? LastImportStatus { get; set; }
    public int TotalRecordsImported { get; set; }
    public double SuccessRate => TotalImports > 0 ? (double)SuccessfulImports / TotalImports * 100 : 0;
}