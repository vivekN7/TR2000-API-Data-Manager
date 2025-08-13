using System.ComponentModel.DataAnnotations.Schema;

namespace TR2KBlazorLibrary.Models.DatabaseModels;

public class Operator : BaseEntity
{
    public int OperatorID { get; set; }
    public string OperatorName { get; set; } = string.Empty;
}