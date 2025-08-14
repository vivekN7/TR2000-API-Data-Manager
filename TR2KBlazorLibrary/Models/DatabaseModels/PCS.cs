using System.ComponentModel.DataAnnotations.Schema;

namespace TR2KBlazorLibrary.Models.DatabaseModels;

public class PCS : BaseEntity
{
    public string? PCSName { get; set; }
    public string? PlantID { get; set; }
    public string? Revision { get; set; }
    public string? Status { get; set; }
    public string? RevDate { get; set; }
    public string? RatingClass { get; set; }
    public string? TestPressure { get; set; }
    public string? MaterialGroup { get; set; }
    public string? DesignCode { get; set; }
    public string? LastUpdate { get; set; }
    public string? LastUpdateBy { get; set; }
    public string? Approver { get; set; }
    public string? Notepad { get; set; }
    public int? SpecialReqID { get; set; }
    public string? TubePCS { get; set; }
    public string? NewVDSSection { get; set; }
}