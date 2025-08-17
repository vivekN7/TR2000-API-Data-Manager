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
}