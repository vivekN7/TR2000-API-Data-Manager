using System.ComponentModel.DataAnnotations.Schema;

namespace TR2KBlazorLibrary.Models.DatabaseModels;

public class Issue : BaseEntity
{
    public string? IssueRevision { get; set; }
    public string? PlantID { get; set; }
    public string? Status { get; set; }
    public string? RevDate { get; set; }
    public string? ProtectStatus { get; set; }
    public string? GeneralRevision { get; set; }
    public string? GeneralRevDate { get; set; }
    public string? PCSRevision { get; set; }
    public string? PCSRevDate { get; set; }
    public string? EDSRevision { get; set; }
    public string? EDSRevDate { get; set; }
    public string? VDSRevision { get; set; }
    public string? VDSRevDate { get; set; }
    public string? VSKRevision { get; set; }
    public string? VSKRevDate { get; set; }
    public string? MDSRevision { get; set; }
    public string? MDSRevDate { get; set; }
    public string? ESKRevision { get; set; }
    public string? ESKRevDate { get; set; }
    public string? SCRevision { get; set; }
    public string? SCRevDate { get; set; }
    public string? VSMRevision { get; set; }
    public string? VSMRevDate { get; set; }
}