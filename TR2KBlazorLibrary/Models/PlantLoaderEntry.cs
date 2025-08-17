namespace TR2KBlazorLibrary.Models
{
    public class PlantLoaderEntry
    {
        public string PlantID { get; set; } = "";
        public string PlantName { get; set; } = "";
        public bool IsActive { get; set; }
        public DateTime? CreatedDate { get; set; }
        public DateTime? ModifiedDate { get; set; }
    }
    
    public class Plant
    {
        public string PlantID { get; set; } = "";
        public string PlantName { get; set; } = "";
        public string? LongDescription { get; set; }
        public int? OperatorID { get; set; }
    }
    
    public class IssueLoaderEntry
    {
        public string PlantID { get; set; } = "";
        public string IssueRevision { get; set; } = "";
        public string PlantName { get; set; } = "";
        public bool LoadReferences { get; set; }
        public string? Notes { get; set; }
        public DateTime? CreatedDate { get; set; }
        public DateTime? ModifiedDate { get; set; }
    }
    
    public class Issue
    {
        public string PlantID { get; set; } = "";
        public string IssueRevision { get; set; } = "";
        public string? UserName { get; set; }
        public DateTime? UserEntryTime { get; set; }
        public string? UserProtected { get; set; }
    }
}