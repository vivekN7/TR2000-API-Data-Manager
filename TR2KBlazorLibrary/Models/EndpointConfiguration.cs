namespace TR2KBlazorLibrary.Models;

public class EndpointConfiguration
{
    public string Key { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Section { get; set; } = string.Empty;
    public string Endpoint { get; set; } = string.Empty;
    public string TableName { get; set; } = string.Empty;
    public List<EndpointParameter> Parameters { get; set; } = new();
    public string Description { get; set; } = string.Empty;
    public string HttpMethod { get; set; } = "GET";
    public List<ResponseField> ResponseFields { get; set; } = new();
}

public class ResponseField
{
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public string? Description { get; set; }
}

public class EndpointParameter
{
    public string Name { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public bool IsRequired { get; set; }
    public string Type { get; set; } = "string"; // string, int, dropdown, etc.
    public string? DefaultValue { get; set; }
    public string? DropdownSource { get; set; } // e.g., "operators", "plants"
    public string? ValueField { get; set; } // e.g., "OperatorID", "PlantID"
    public string? DisplayField { get; set; } // e.g., "OperatorName", "LongDescription"
}

public static class EndpointRegistry
{
    public static readonly List<EndpointConfiguration> AllEndpoints = new()
    {
        // Operators and Plants Section - In exact order from API documentation
        new EndpointConfiguration
        {
            Key = "operators",
            Name = "Get operators",
            Section = "Operators and Plants",
            Endpoint = "operators",
            TableName = "operators",
            HttpMethod = "GET",
            Parameters = new(),
            Description = "Retrieve all operators",
            ResponseFields = new()
            {
                new ResponseField { Name = "OperatorID", Type = "[Int32]" },
                new ResponseField { Name = "OperatorName", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "operator_plants",
            Name = "Get operator plants",
            Section = "Operators and Plants",
            Endpoint = "operators/{operatorId}/plants",
            TableName = "plants",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "operatorId", 
                    DisplayName = "Select Operator", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "operators",
                    ValueField = "OperatorID",
                    DisplayField = "OperatorName"
                }
            },
            Description = "Retrieve plants for a specific operator",
            ResponseFields = new()
            {
                new ResponseField { Name = "OperatorID", Type = "[Int32]" },
                new ResponseField { Name = "OperatorName", Type = "[String]" },
                new ResponseField { Name = "PlantID", Type = "[Int32]" },
                new ResponseField { Name = "ShortDescription", Type = "[String]" },
                new ResponseField { Name = "Project", Type = "[String]" },
                new ResponseField { Name = "LongDescription", Type = "[String]" },
                new ResponseField { Name = "CommonLibPlantCode", Type = "[String]" },
                new ResponseField { Name = "InitialRevision", Type = "[String]" },
                new ResponseField { Name = "AreaID", Type = "[Int32]" },
                new ResponseField { Name = "Area", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "plants",
            Name = "Get plants",
            Section = "Operators and Plants",
            Endpoint = "plants",
            TableName = "plants",
            HttpMethod = "GET",
            Parameters = new(),
            Description = "Retrieve all plants across all operators",
            ResponseFields = new()
            {
                new ResponseField { Name = "OperatorID", Type = "[Int32]" },
                new ResponseField { Name = "OperatorName", Type = "[String]" },
                new ResponseField { Name = "PlantID", Type = "[Int32]" },
                new ResponseField { Name = "ShortDescription", Type = "[String]" },
                new ResponseField { Name = "Project", Type = "[String]" },
                new ResponseField { Name = "LongDescription", Type = "[String]" },
                new ResponseField { Name = "CommonLibPlantCode", Type = "[String]" },
                new ResponseField { Name = "InitialRevision", Type = "[String]" },
                new ResponseField { Name = "AreaID", Type = "[Int32]" },
                new ResponseField { Name = "Area", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "plant",
            Name = "Get plant",
            Section = "Operators and Plants",
            Endpoint = "plants/{plantId}",
            TableName = "plants",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "plantId", 
                    DisplayName = "Plant ID", 
                    IsRequired = true, 
                    Type = "int"
                }
            },
            Description = "Retrieve a specific plant by ID",
            ResponseFields = new()
            {
                new ResponseField { Name = "OperatorID", Type = "[Int32]" },
                new ResponseField { Name = "OperatorName", Type = "[String]" },
                new ResponseField { Name = "PlantID", Type = "[Int32]" },
                new ResponseField { Name = "ShortDescription", Type = "[String]" },
                new ResponseField { Name = "Project", Type = "[String]" },
                new ResponseField { Name = "LongDescription", Type = "[String]" },
                new ResponseField { Name = "CommonLibPlantCode", Type = "[String]" },
                new ResponseField { Name = "InitialRevision", Type = "[String]" },
                new ResponseField { Name = "AreaID", Type = "[Int32]" },
                new ResponseField { Name = "Area", Type = "[String]" }
            }
        },
        
        // Issues - Collection of datasheets Section
        new EndpointConfiguration
        {
            Key = "plant_issues",
            Name = "Get issue revisions",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantId}/issues",
            TableName = "issues",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "plantId", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "ShortDescription"
                }
            },
            Description = "Retrieve issue revisions for a specific plant",
            ResponseFields = new()
            {
                new ResponseField { Name = "IssueRevision", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "ProtectStatus", Type = "[String]" },
                new ResponseField { Name = "GeneralRevision", Type = "[String]" },
                new ResponseField { Name = "GeneralRevDate", Type = "[String]" },
                new ResponseField { Name = "PCSRevision", Type = "[String]" },
                new ResponseField { Name = "PCSRevDate", Type = "[String]" },
                new ResponseField { Name = "EDSRevision", Type = "[String]" },
                new ResponseField { Name = "EDSRevDate", Type = "[String]" },
                new ResponseField { Name = "VDSRevision", Type = "[String]" },
                new ResponseField { Name = "VDSRevDate", Type = "[String]" },
                new ResponseField { Name = "VSKRevision", Type = "[String]" },
                new ResponseField { Name = "VSKRevDate", Type = "[String]" },
                new ResponseField { Name = "MDSRevision", Type = "[String]" },
                new ResponseField { Name = "MDSRevDate", Type = "[String]" },
                new ResponseField { Name = "ESKRevision", Type = "[String]" },
                new ResponseField { Name = "ESKRevDate", Type = "[String]" },
                new ResponseField { Name = "SCRevision", Type = "[String]" },
                new ResponseField { Name = "SCRevDate", Type = "[String]" },
                new ResponseField { Name = "VSMRevision", Type = "[String]" },
                new ResponseField { Name = "VSMRevDate", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "issue",
            Name = "Get issue revision",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantId}/issues/{issueRevision}",
            TableName = "issues",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "plantId", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "ShortDescription"
                },
                new EndpointParameter
                {
                    Name = "issueRevision",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "string"
                }
            },
            Description = "Retrieve a specific issue revision",
            ResponseFields = new()
            {
                new ResponseField { Name = "IssueRevision", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "ProtectStatus", Type = "[String]" },
                new ResponseField { Name = "GeneralRevision", Type = "[String]" },
                new ResponseField { Name = "GeneralRevDate", Type = "[String]" },
                new ResponseField { Name = "PCSRevision", Type = "[String]" },
                new ResponseField { Name = "PCSRevDate", Type = "[String]" },
                new ResponseField { Name = "EDSRevision", Type = "[String]" },
                new ResponseField { Name = "EDSRevDate", Type = "[String]" },
                new ResponseField { Name = "VDSRevision", Type = "[String]" },
                new ResponseField { Name = "VDSRevDate", Type = "[String]" },
                new ResponseField { Name = "VSKRevision", Type = "[String]" },
                new ResponseField { Name = "VSKRevDate", Type = "[String]" },
                new ResponseField { Name = "MDSRevision", Type = "[String]" },
                new ResponseField { Name = "MDSRevDate", Type = "[String]" },
                new ResponseField { Name = "ESKRevision", Type = "[String]" },
                new ResponseField { Name = "ESKRevDate", Type = "[String]" },
                new ResponseField { Name = "SCRevision", Type = "[String]" },
                new ResponseField { Name = "SCRevDate", Type = "[String]" },
                new ResponseField { Name = "VSMRevision", Type = "[String]" },
                new ResponseField { Name = "VSMRevDate", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "general_datasheet",
            Name = "Get general datasheet",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantId}/issues/{issueRevision}/general",
            TableName = "general_datasheet",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "plantId", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "ShortDescription"
                },
                new EndpointParameter
                {
                    Name = "issueRevision",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "string"
                }
            },
            Description = "Retrieve general datasheet for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "PlantID", Type = "[Int32]" },
                new ResponseField { Name = "IssueRevision", Type = "[String]" },
                new ResponseField { Name = "GeneralRevision", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "ProjectTitle", Type = "[String]" },
                new ResponseField { Name = "PlantName", Type = "[String]" },
                new ResponseField { Name = "PlantCode", Type = "[String]" },
                new ResponseField { Name = "Comments", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "general_datasheet_by_revision",
            Name = "Get general datasheet by revision",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantId}/general/{generalRevision}",
            TableName = "general_datasheet",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "plantId", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "ShortDescription"
                },
                new EndpointParameter
                {
                    Name = "generalRevision",
                    DisplayName = "General Revision",
                    IsRequired = true,
                    Type = "string"
                }
            },
            Description = "Retrieve general datasheet by specific revision",
            ResponseFields = new()
            {
                new ResponseField { Name = "PlantID", Type = "[Int32]" },
                new ResponseField { Name = "GeneralRevision", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "ProjectTitle", Type = "[String]" },
                new ResponseField { Name = "PlantName", Type = "[String]" },
                new ResponseField { Name = "PlantCode", Type = "[String]" },
                new ResponseField { Name = "Comments", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pipe_element_references",
            Name = "Get pipe element references",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantId}/issues/{issueRevision}/pipe-element-references",
            TableName = "pipe_element_references",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "plantId", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "ShortDescription"
                },
                new EndpointParameter
                {
                    Name = "issueRevision",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "string"
                }
            },
            Description = "Retrieve pipe element references for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "ElementType", Type = "[String]" },
                new ResponseField { Name = "ElementCode", Type = "[String]" },
                new ResponseField { Name = "Description", Type = "[String]" },
                new ResponseField { Name = "Reference", Type = "[String]" },
                new ResponseField { Name = "Standard", Type = "[String]" },
                new ResponseField { Name = "Material", Type = "[String]" }
            }
        },
        
        // PCS Section  
        new EndpointConfiguration
        {
            Key = "plant_pcs",
            Name = "Get PCS list",
            Section = "PCS",
            Endpoint = "plants/{plantId}/pcs",
            TableName = "pcs",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "plantId", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "ShortDescription"
                }
            },
            Description = "Retrieve PCS list for a specific plant",
            ResponseFields = new()
            {
                new ResponseField { Name = "PCS", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "RatingClass", Type = "[String]" },
                new ResponseField { Name = "TestPressure", Type = "[String]" },
                new ResponseField { Name = "MaterialGroup", Type = "[String]" },
                new ResponseField { Name = "DesignCode", Type = "[String]" },
                new ResponseField { Name = "LastUpdate", Type = "[String]" },
                new ResponseField { Name = "LastUpdateBy", Type = "[String]" },
                new ResponseField { Name = "Approver", Type = "[String]" },
                new ResponseField { Name = "Notepad", Type = "[String]" },
                new ResponseField { Name = "SpecialReqID", Type = "[Int32]" },
                new ResponseField { Name = "TubePCS", Type = "[String]" },
                new ResponseField { Name = "NewVDSSection", Type = "[String]" }
            }
        }
    };
}