using System.ComponentModel.DataAnnotations.Schema;

namespace TR2KBlazorLibrary.Models.DatabaseModels;

public class Plant : BaseEntity
{
    public string? PlantID { get; set; } // Can be numeric (e.g., "105") or alphanumeric (e.g., "JSV")
    public string? ShortDescription { get; set; }
    public string? LongDescription { get; set; }
    public int? OperatorID { get; set; }
    public string? OperatorName { get; set; }
    public int? AreaID { get; set; }
    public string? Area { get; set; }
    public string? CommonLibPlantCode { get; set; }
    public string? Project { get; set; }
    public string? InitialRevision { get; set; }
}