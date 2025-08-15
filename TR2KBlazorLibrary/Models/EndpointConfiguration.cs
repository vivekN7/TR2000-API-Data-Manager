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
    public string? DropdownSource { get; set; } // e.g., "operators", "plants", "issues"
    public string? ValueField { get; set; } // e.g., "OperatorID", "PlantID", "IssueRevision"
    public string? DisplayField { get; set; } // e.g., "OperatorName", "LongDescription"
    public string? DependsOn { get; set; } // e.g., "plantId" - another parameter this depends on
    public string ParameterLocation { get; set; } = "path"; // "path" or "query" - defaults to path for backward compatibility
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
            Endpoint = "operators/{operatorid}/plants",
            TableName = "plants",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "OPERATORID", 
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
                new ResponseField { Name = "PlantID", Type = "[String]" },
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
                new ResponseField { Name = "PlantID", Type = "[String]" },
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
            Endpoint = "plants/{plantid}",
            TableName = "plants",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                }
            },
            Description = "Retrieve a specific plant by ID",
            ResponseFields = new()
            {
                new ResponseField { Name = "OperatorID", Type = "[Int32]" },
                new ResponseField { Name = "OperatorName", Type = "[String]" },
                new ResponseField { Name = "PlantID", Type = "[String]" },
                new ResponseField { Name = "ShortDescription", Type = "[String]" },
                new ResponseField { Name = "Project", Type = "[String]" },
                new ResponseField { Name = "LongDescription", Type = "[String]" },
                new ResponseField { Name = "CommonLibPlantCode", Type = "[String]" },
                new ResponseField { Name = "InitialRevision", Type = "[String]" },
                new ResponseField { Name = "AreaID", Type = "[Int32]" },
                new ResponseField { Name = "Area", Type = "[String]" },
                new ResponseField { Name = "EnableEmbeddedNote", Type = "[String]" },
                new ResponseField { Name = "CategoryID", Type = "[String]" },
                new ResponseField { Name = "Category", Type = "[String]" },
                new ResponseField { Name = "DocumentSpaceLink", Type = "[String]" },
                new ResponseField { Name = "EnableCopyPCSFromPlant", Type = "[String]" },
                new ResponseField { Name = "OverLength", Type = "[String]" },
                new ResponseField { Name = "PCSQA", Type = "[String]" },
                new ResponseField { Name = "EDSMJ", Type = "[String]" },
                new ResponseField { Name = "CelsiusBar", Type = "[String]" },
                new ResponseField { Name = "WebInfoText", Type = "[String]" },
                new ResponseField { Name = "BoltTensionText", Type = "[String]" },
                new ResponseField { Name = "Visible", Type = "[String]" },
                new ResponseField { Name = "WindowsRemarkText", Type = "[String]" },
                new ResponseField { Name = "UserProtected", Type = "[String]" }
            }
        },
        
        // Issues - Collection of datasheets Section
        new EndpointConfiguration
        {
            Key = "plant_issues",
            Name = "Get issue revisions",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantid}/issues",
            TableName = "issues",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
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
                new ResponseField { Name = "VSMRevDate", Type = "[String]" },
                new ResponseField { Name = "UserName", Type = "[String]" },
                new ResponseField { Name = "UserEntryTime", Type = "[String]" },
                new ResponseField { Name = "UserProtected", Type = "[String]" }
            }
        },
        
        // NOTE: The following endpoints don't exist in the API but are kept for future implementation
        new EndpointConfiguration
        {
            Key = "pcs_references",
            Name = "Get PCS references",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantid}/issues/rev/{issuerev}/pcs",
            TableName = "pcs_references",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter
                {
                    Name = "ISSUEREV",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "issues",
                    ValueField = "IssueRevision",
                    DisplayField = "IssueRevision",
                    DependsOn = "PLANTID"
                }
            },
            Description = "Retrieve PCS references for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "PCS", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "OfficialRevision", Type = "[String]" },
                new ResponseField { Name = "RevisionSuffix", Type = "[String]" },
                new ResponseField { Name = "RatingClass", Type = "[String]" },
                new ResponseField { Name = "MaterialGroup", Type = "[String]" },
                new ResponseField { Name = "HistoricalPCS", Type = "[String]" },
                new ResponseField { Name = "Delta", Type = "[String]" }
            }
        },
        
        
        
        new EndpointConfiguration
        {
            Key = "sc_references",
            Name = "Get SC references",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantid}/issues/rev/{issuerev}/sc",
            TableName = "sc_references",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter
                {
                    Name = "ISSUEREV",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "issues",
                    ValueField = "IssueRevision",
                    DisplayField = "IssueRevision",
                    DependsOn = "PLANTID"
                }
            },
            Description = "Retrieve SC (Special Component) references for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "SC", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "OfficialRevision", Type = "[String]" },
                new ResponseField { Name = "Delta", Type = "[String]" }
            }
        },
        
        
        
        new EndpointConfiguration
        {
            Key = "vsm_references",
            Name = "Get VSM references",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantid}/issues/rev/{issuerev}/vsm",
            TableName = "vsm_references",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter
                {
                    Name = "ISSUEREV",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "issues",
                    ValueField = "IssueRevision",
                    DisplayField = "IssueRevision",
                    DependsOn = "PLANTID"
                }
            },
            Description = "Retrieve VSM (Valve Specification Manual) references for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "VSM", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "OfficialRevision", Type = "[String]" },
                new ResponseField { Name = "Delta", Type = "[String]" }
            }
        },
        
        
        
        new EndpointConfiguration
        {
            Key = "vds_references",
            Name = "Get VDS references",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantid}/issues/rev/{issuerev}/vds",
            TableName = "vds_references",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter
                {
                    Name = "ISSUEREV",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "issues",
                    ValueField = "IssueRevision",
                    DisplayField = "IssueRevision",
                    DependsOn = "PLANTID"
                }
            },
            Description = "Retrieve VDS (Valve Datasheet) references for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "VDS", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "OfficialRevision", Type = "[String]" },
                new ResponseField { Name = "Delta", Type = "[String]" }
            }
        },
        
        
        
        new EndpointConfiguration
        {
            Key = "eds_references",
            Name = "Get EDS references",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantid}/issues/rev/{issuerev}/eds",
            TableName = "eds_references",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter
                {
                    Name = "ISSUEREV",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "issues",
                    ValueField = "IssueRevision",
                    DisplayField = "IssueRevision",
                    DependsOn = "PLANTID"
                }
            },
            Description = "Retrieve EDS (Equipment Datasheet) references for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "EDS", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "OfficialRevision", Type = "[String]" },
                new ResponseField { Name = "Delta", Type = "[String]" }
            }
        },
        
        
        
        new EndpointConfiguration
        {
            Key = "mds_references",
            Name = "Get MDS references",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantid}/issues/rev/{issuerev}/mds",
            TableName = "mds_references",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter
                {
                    Name = "ISSUEREV",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "issues",
                    ValueField = "IssueRevision",
                    DisplayField = "IssueRevision",
                    DependsOn = "PLANTID"
                }
            },
            Description = "Retrieve MDS (Material Datasheet) references for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "MDS", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "Area", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "OfficialRevision", Type = "[String]" },
                new ResponseField { Name = "Delta", Type = "[String]" }
            }
        },
        
        
        
        new EndpointConfiguration
        {
            Key = "vsk_references",
            Name = "Get VSK references",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantid}/issues/rev/{issuerev}/vsk",
            TableName = "vsk_references",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter
                {
                    Name = "ISSUEREV",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "issues",
                    ValueField = "IssueRevision",
                    DisplayField = "IssueRevision",
                    DependsOn = "PLANTID"
                }
            },
            Description = "Retrieve VSK (Valve Spares Kit) references for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "VSK", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "OfficialRevision", Type = "[String]" },
                new ResponseField { Name = "Delta", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "esk_references",
            Name = "Get ESK references",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantid}/issues/rev/{issuerev}/esk",
            TableName = "esk_references",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter
                {
                    Name = "ISSUEREV",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "issues",
                    ValueField = "IssueRevision",
                    DisplayField = "IssueRevision",
                    DependsOn = "PLANTID"
                }
            },
            Description = "Retrieve ESK (Equipment Spares Kit) references for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "ESK", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "OfficialRevision", Type = "[String]" },
                new ResponseField { Name = "Delta", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pipe_element_references",
            Name = "Get Pipe Element references",
            Section = "Issues - Collection of datasheets",
            Endpoint = "plants/{plantid}/issues/rev/{issuerev}/pipe-elements",
            TableName = "pipe_element_references",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter
                {
                    Name = "ISSUEREV",
                    DisplayName = "Issue Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "issues",
                    ValueField = "IssueRevision",
                    DisplayField = "IssueRevision",
                    DependsOn = "PLANTID"
                }
            },
            Description = "Retrieve pipe element references for an issue",
            ResponseFields = new()
            {
                new ResponseField { Name = "ElementGroup", Type = "[String]" },
                new ResponseField { Name = "DimensionStandard", Type = "[String]" },
                new ResponseField { Name = "ProductForm", Type = "[String]" },
                new ResponseField { Name = "MaterialGrade", Type = "[String]" },
                new ResponseField { Name = "MDS", Type = "[String]" },
                new ResponseField { Name = "MDSRevision", Type = "[String]" },
                new ResponseField { Name = "Area", Type = "[String]" },
                new ResponseField { Name = "ElementID", Type = "[Int32]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "Delta", Type = "[String]" }
            }
        },
        
        
        // PCS Section  
        new EndpointConfiguration
        {
            Key = "plant_pcs",
            Name = "Get PCS list",
            Section = "PCS",
            Endpoint = "plants/{plantid}/pcs",
            TableName = "pcs",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter 
                { 
                    Name = "NAMEFILTER", 
                    DisplayName = "Name Filter", 
                    IsRequired = false, 
                    Type = "string",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "STATUSFILTER", 
                    DisplayName = "Status Filter", 
                    IsRequired = false, 
                    Type = "string",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "NOTEID", 
                    DisplayName = "Note ID", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "VDS", 
                    DisplayName = "VDS", 
                    IsRequired = false, 
                    Type = "string",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "ELEMENTID", 
                    DisplayName = "Element ID", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
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
        },
        
        // PCS detail endpoints - each has its own specific API path
        new EndpointConfiguration
        {
            Key = "pcs_details",
            Name = "Get header and properties",
            Section = "PCS",
            Endpoint = "plants/{plantid}/pcs/{pcsname}/rev/{revision}",
            TableName = "pcs_details",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter 
                { 
                    Name = "PCSNAME", 
                    DisplayName = "PCS Name", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "PCSName",
                    DisplayField = "PCSName",
                    DependsOn = "PLANTID"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Select Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "Revision",
                    DisplayField = "Revision",
                    DependsOn = "PCSNAME"
                }
            },
            Description = "Retrieve complete details for a specific PCS revision",
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
                new ResponseField { Name = "SC", Type = "[String]" },
                new ResponseField { Name = "VSM", Type = "[String]" },
                new ResponseField { Name = "DesignCodeRevMark", Type = "[String]" },
                new ResponseField { Name = "CorrAllowance", Type = "[Int32]" },
                new ResponseField { Name = "CorrAllowanceRevMark", Type = "[String]" },
                new ResponseField { Name = "LongWeldEff", Type = "[String]" },
                new ResponseField { Name = "LongWeldEffRevMark", Type = "[String]" },
                new ResponseField { Name = "WallThkTol", Type = "[String]" },
                new ResponseField { Name = "WallThkTolRevMark", Type = "[String]" },
                new ResponseField { Name = "ServiceRemark", Type = "[String]" },
                new ResponseField { Name = "ServiceRemarkRevMark", Type = "[String]" },
                new ResponseField { Name = "DesignPress01", Type = "[String]" },
                new ResponseField { Name = "DesignPress02", Type = "[String]" },
                new ResponseField { Name = "DesignPress03", Type = "[String]" },
                new ResponseField { Name = "DesignPress04", Type = "[String]" },
                new ResponseField { Name = "DesignPress05", Type = "[String]" },
                new ResponseField { Name = "DesignPress06", Type = "[String]" },
                new ResponseField { Name = "DesignPress07", Type = "[String]" },
                new ResponseField { Name = "DesignPress08", Type = "[String]" },
                new ResponseField { Name = "DesignPress09", Type = "[String]" },
                new ResponseField { Name = "DesignPress10", Type = "[String]" },
                new ResponseField { Name = "DesignPress11", Type = "[String]" },
                new ResponseField { Name = "DesignPress12", Type = "[String]" },
                new ResponseField { Name = "DesignPressRevMark", Type = "[String]" },
                new ResponseField { Name = "DesignTemp01", Type = "[String]" },
                new ResponseField { Name = "DesignTemp02", Type = "[String]" },
                new ResponseField { Name = "DesignTemp03", Type = "[String]" },
                new ResponseField { Name = "DesignTemp04", Type = "[String]" },
                new ResponseField { Name = "DesignTemp05", Type = "[String]" },
                new ResponseField { Name = "DesignTemp06", Type = "[String]" },
                new ResponseField { Name = "DesignTemp07", Type = "[String]" },
                new ResponseField { Name = "DesignTemp08", Type = "[String]" },
                new ResponseField { Name = "DesignTemp09", Type = "[String]" },
                new ResponseField { Name = "DesignTemp10", Type = "[String]" },
                new ResponseField { Name = "DesignTemp11", Type = "[String]" },
                new ResponseField { Name = "DesignTemp12", Type = "[String]" },
                new ResponseField { Name = "DesignTempRevMark", Type = "[String]" },
                new ResponseField { Name = "NoteIDCorrAllowance", Type = "[String]" },
                new ResponseField { Name = "NoteIDServiceCode", Type = "[String]" },
                new ResponseField { Name = "NoteIDWallThkTol", Type = "[String]" },
                new ResponseField { Name = "NoteIDLongWeldEff", Type = "[String]" },
                new ResponseField { Name = "NoteIDGeneralPCS", Type = "[String]" },
                new ResponseField { Name = "NoteIDDesignCode", Type = "[String]" },
                new ResponseField { Name = "NoteIDPressTempTable", Type = "[String]" },
                new ResponseField { Name = "NoteIDPipeSizeWthTable", Type = "[String]" },
                new ResponseField { Name = "PressElementChange", Type = "[String]" },
                new ResponseField { Name = "TempElementChange", Type = "[String]" },
                new ResponseField { Name = "MaterialGroupID", Type = "[Int32]" },
                new ResponseField { Name = "SpecialReqID", Type = "[Int32]" },
                new ResponseField { Name = "SpecialReq", Type = "[String]" },
                new ResponseField { Name = "NewVDSSection", Type = "[String]" },
                new ResponseField { Name = "TubePCS", Type = "[String]" },
                new ResponseField { Name = "EDSMJMatrix", Type = "[String]" },
                new ResponseField { Name = "MJReductionFactor", Type = "[Int32]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pcs_temperature_pressure",
            Name = "Get temperature and pressure",
            Section = "PCS",
            Endpoint = "plants/{plantid}/pcs/{pcsname}/rev/{revision}/temp-pressures",
            TableName = "pcs_temperature_pressure",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter 
                { 
                    Name = "PCSNAME", 
                    DisplayName = "PCS Name", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "PCSName",
                    DisplayField = "PCSName",
                    DependsOn = "PLANTID"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Select Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "Revision",
                    DisplayField = "Revision",
                    DependsOn = "PCSNAME"
                }
            },
            Description = "Temperature and pressure endpoint",
            ResponseFields = new()
            {
                new ResponseField { Name = "Temperature", Type = "[String]" },
                new ResponseField { Name = "Pressure", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pcs_pipe_size",
            Name = "Get pipe size",
            Section = "PCS",
            Endpoint = "plants/{plantid}/pcs/{pcsname}/rev/{revision}/pipe-sizes",
            TableName = "pcs_pipe_size",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter 
                { 
                    Name = "PCSNAME", 
                    DisplayName = "PCS Name", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "PCSName",
                    DisplayField = "PCSName",
                    DependsOn = "PLANTID"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Select Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "Revision",
                    DisplayField = "Revision",
                    DependsOn = "PCSNAME"
                }
            },
            Description = "Retrieve pipe sizes for a specific PCS revision",
            ResponseFields = new()
            {
                new ResponseField { Name = "PCS", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "NomSize", Type = "[String]" },
                new ResponseField { Name = "OuterDiam", Type = "[String]" },
                new ResponseField { Name = "WallThickness", Type = "[String]" },
                new ResponseField { Name = "Schedule", Type = "[String]" },
                new ResponseField { Name = "UnderTolerance", Type = "[String]" },
                new ResponseField { Name = "CorrosionAllowance", Type = "[String]" },
                new ResponseField { Name = "WeldingFactor", Type = "[String]" },
                new ResponseField { Name = "DimElementChange", Type = "[String]" },
                new ResponseField { Name = "ScheduleInMatrix", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pcs_pipe_element",
            Name = "Get pipe element",
            Section = "PCS",
            Endpoint = "plants/{plantid}/pcs/{pcsname}/rev/{revision}/pipe-elements",
            TableName = "pcs_pipe_element",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter 
                { 
                    Name = "PCSNAME", 
                    DisplayName = "PCS Name", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "PCSName",
                    DisplayField = "PCSName",
                    DependsOn = "PLANTID"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Select Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "Revision",
                    DisplayField = "Revision",
                    DependsOn = "PCSNAME"
                }
            },
            Description = "Retrieve pipe elements for a specific PCS revision",
            ResponseFields = new()
            {
                new ResponseField { Name = "PCS", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "MaterialGroupID", Type = "[Int32]" },
                new ResponseField { Name = "ElementGroupNo", Type = "[Int32]" },
                new ResponseField { Name = "LineNo", Type = "[Int32]" },
                new ResponseField { Name = "Element", Type = "[String]" },
                new ResponseField { Name = "DimStandard", Type = "[String]" },
                new ResponseField { Name = "FromSize", Type = "[String]" },
                new ResponseField { Name = "ToSize", Type = "[String]" },
                new ResponseField { Name = "ProductForm", Type = "[String]" },
                new ResponseField { Name = "Material", Type = "[String]" },
                new ResponseField { Name = "MDS", Type = "[String]" },
                new ResponseField { Name = "EDS", Type = "[String]" },
                new ResponseField { Name = "EDSRevision", Type = "[String]" },
                new ResponseField { Name = "ESK", Type = "[String]" },
                new ResponseField { Name = "Revmark", Type = "[String]" },
                new ResponseField { Name = "Remark", Type = "[String]" },
                new ResponseField { Name = "PageBreak", Type = "[String]" },
                new ResponseField { Name = "ElementID", Type = "[Int32]" },
                new ResponseField { Name = "FreeText", Type = "[String]" },
                new ResponseField { Name = "NoteID", Type = "[String]" },
                new ResponseField { Name = "NewDeletedLine", Type = "[String]" },
                new ResponseField { Name = "InitialInfo", Type = "[String]" },
                new ResponseField { Name = "InitialRevmark", Type = "[String]" },
                new ResponseField { Name = "MDSVariant", Type = "[String]" },
                new ResponseField { Name = "MDSRevision", Type = "[String]" },
                new ResponseField { Name = "Area", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pcs_valve_element",
            Name = "Get valve element",
            Section = "PCS",
            Endpoint = "plants/{plantid}/pcs/{pcsname}/rev/{revision}/valve-elements",
            TableName = "pcs_valve_element",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter 
                { 
                    Name = "PCSNAME", 
                    DisplayName = "PCS Name", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "PCSName",
                    DisplayField = "PCSName",
                    DependsOn = "PLANTID"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Select Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "Revision",
                    DisplayField = "Revision",
                    DependsOn = "PCSNAME"
                }
            },
            Description = "Retrieve valve elements for a specific PCS revision",
            ResponseFields = new()
            {
                new ResponseField { Name = "ValveGroupNo", Type = "[Int32]" },
                new ResponseField { Name = "LineNo", Type = "[Int32]" },
                new ResponseField { Name = "ValveType", Type = "[String]" },
                new ResponseField { Name = "VDS", Type = "[String]" },
                new ResponseField { Name = "ValveDescription", Type = "[String]" },
                new ResponseField { Name = "FromSize", Type = "[String]" },
                new ResponseField { Name = "ToSize", Type = "[String]" },
                new ResponseField { Name = "Revmark", Type = "[String]" },
                new ResponseField { Name = "Remark", Type = "[String]" },
                new ResponseField { Name = "PageBreak", Type = "[String]" },
                new ResponseField { Name = "NoteID", Type = "[String]" },
                new ResponseField { Name = "PreviousVDS", Type = "[String]" },
                new ResponseField { Name = "NewDeletedLine", Type = "[String]" },
                new ResponseField { Name = "InitialInfo", Type = "[String]" },
                new ResponseField { Name = "InitialRevmark", Type = "[String]" },
                new ResponseField { Name = "SizeRange", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pcs_embedded_note",
            Name = "Get embedded note",
            Section = "PCS",
            Endpoint = "plants/{plantid}/pcs/{pcsname}/rev/{revision}/embedded-notes",
            TableName = "pcs_embedded_note",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PLANTID", 
                    DisplayName = "Select Plant", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "plants",
                    ValueField = "PlantID",
                    DisplayField = "LongDescription"
                },
                new EndpointParameter 
                { 
                    Name = "PCSNAME", 
                    DisplayName = "PCS Name", 
                    IsRequired = true, 
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "PCSName",
                    DisplayField = "PCSName",
                    DependsOn = "PLANTID"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Select Revision",
                    IsRequired = true,
                    Type = "dropdown",
                    DropdownSource = "pcs",
                    ValueField = "Revision",
                    DisplayField = "Revision",
                    DependsOn = "PCSNAME"
                }
            },
            Description = "Retrieve embedded notes for a specific PCS revision",
            ResponseFields = new()
            {
                new ResponseField { Name = "PCSName", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "TextSectionID", Type = "[String]" },
                new ResponseField { Name = "TextSectionDescription", Type = "[String]" },
                new ResponseField { Name = "PageBreak", Type = "[String]" },
                new ResponseField { Name = "HTMLCLOB", Type = "[String]" }
            }
        },
        
        // Section 4: VDS (Valve Datasheet)
        new EndpointConfiguration
        {
            Key = "vds_list",
            Name = "Get VDS list",
            Section = "VDS",
            Endpoint = "vds",
            TableName = "vds_list",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "NAMEFILTER", 
                    DisplayName = "Name Filter", 
                    IsRequired = false, 
                    Type = "string",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "STATUSFILTER", 
                    DisplayName = "Status Filter", 
                    IsRequired = false, 
                    Type = "string",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "BASEDONSUBSEGMENT", 
                    DisplayName = "Based On Subsegment", 
                    IsRequired = false, 
                    Type = "string",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "VDS", 
                    DisplayName = "VDS", 
                    IsRequired = false, 
                    Type = "string",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "VALVETYPEID", 
                    DisplayName = "Valve Type ID", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "RATINGCLASSID", 
                    DisplayName = "Rating Class ID", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "MATERIALGROUPID", 
                    DisplayName = "Material Group ID", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "ENDCONNECTIONID", 
                    DisplayName = "End Connection ID", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "BOREID", 
                    DisplayName = "Bore ID", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "VDSSIZEID", 
                    DisplayName = "VDS Size ID", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "SPECIALREQID", 
                    DisplayName = "Special Req ID", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "SUBSEGMENTREF", 
                    DisplayName = "Subsegment Ref", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter 
                { 
                    Name = "TEXTBLOCKID", 
                    DisplayName = "Text Block ID", 
                    IsRequired = false, 
                    Type = "int",
                    ParameterLocation = "query"
                }
            },
            Description = "Retrieve complete list of all VDS (Valve Datasheet) items",
            ResponseFields = new()
            {
                new ResponseField { Name = "VDS", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "Status", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "LastUpdate", Type = "[String]" },
                new ResponseField { Name = "LastUpdateBy", Type = "[String]" },
                new ResponseField { Name = "Description", Type = "[String]" },
                new ResponseField { Name = "Notepad", Type = "[String]" },
                new ResponseField { Name = "SpecialReqID", Type = "[Int32]" },
                new ResponseField { Name = "ValveTypeID", Type = "[Int32]" },
                new ResponseField { Name = "RatingClassID", Type = "[Int32]" },
                new ResponseField { Name = "MaterialGroupID", Type = "[Int32]" },
                new ResponseField { Name = "EndConnectionID", Type = "[Int32]" },
                new ResponseField { Name = "BoreID", Type = "[Int32]" },
                new ResponseField { Name = "VDSSizeID", Type = "[Int32]" },
                new ResponseField { Name = "SizeRange", Type = "[String]" },
                new ResponseField { Name = "CustomName", Type = "[String]" },
                new ResponseField { Name = "SubsegmentList", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "vds_subsegments",
            Name = "Get subsegments and properties",
            Section = "VDS",
            Endpoint = "vds/{vdsname}/rev/{revision}",
            TableName = "vds_subsegments",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "VDSNAME", 
                    DisplayName = "VDS Name", 
                    IsRequired = true, 
                    Type = "text"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Revision",
                    IsRequired = true,
                    Type = "text"
                }
            },
            Description = "Retrieve VDS content details and subsegment information for a specific VDS and revision",
            ResponseFields = new()
            {
                new ResponseField { Name = "ValveTypeID", Type = "[Int32]" },
                new ResponseField { Name = "RatingClassID", Type = "[Int32]" },
                new ResponseField { Name = "MaterialTypeID", Type = "[Int32]" },
                new ResponseField { Name = "EndConnectionID", Type = "[Int32]" },
                new ResponseField { Name = "FullReducedBoreIndicator", Type = "[String]" },
                new ResponseField { Name = "BoreID", Type = "[Int32]" },
                new ResponseField { Name = "VDSSizeID", Type = "[Int32]" },
                new ResponseField { Name = "HousingDesignIndicator", Type = "[String]" },
                new ResponseField { Name = "HousingDesignID", Type = "[Int32]" },
                new ResponseField { Name = "SpecialReqID", Type = "[Int32]" },
                new ResponseField { Name = "MinOperatingTemperature", Type = "[Int32]" },
                new ResponseField { Name = "MaxOperatingTemperature", Type = "[Int32]" },
                new ResponseField { Name = "VDSDescription", Type = "[String]" },
                new ResponseField { Name = "Notepad", Type = "[String]" },
                new ResponseField { Name = "RevDate", Type = "[String]" },
                new ResponseField { Name = "LastUpdate", Type = "[String]" },
                new ResponseField { Name = "LastUpdateBy", Type = "[String]" },
                new ResponseField { Name = "SubsegmentID", Type = "[Int32]" },
                new ResponseField { Name = "SubsegmentName", Type = "[String]" },
                new ResponseField { Name = "Sequence", Type = "[Int32]" }
            }
        },
        
        // ===== BOLT TENSION SECTION =====
        new EndpointConfiguration
        {
            Key = "bolt_tension_flange_type",
            Name = "Get Flange Type",
            Section = "BoltTension",
            Endpoint = "BoltTension/getFlangeType/{plantid}/{pcs}/",
            TableName = "bolt_tension_flange_type",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter
                {
                    Name = "PLANTID",
                    DisplayName = "Plant Code",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "plant_codes",
                    ValueField = "PlantCode",
                    DisplayField = "Display"
                },
                new EndpointParameter
                {
                    Name = "PCS",
                    DisplayName = "PCS",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "pcs",
                    ValueField = "PCS",
                    DisplayField = "PCS",
                    DependsOn = "PLANTID"
                },
                new EndpointParameter
                {
                    Name = "FlangeSize",
                    DisplayName = "Flange Size",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "query",
                    DropdownSource = "flange_sizes",  // Special dropdown source for 1-100
                    ValueField = "FlangeSize",
                    DisplayField = "Display"
                }
            },
            Description = "Retrieve flange type information for bolt tension calculations",
            ResponseFields = new()
            {
                new ResponseField { Name = "Display", Type = "[String]" },
                new ResponseField { Name = "FlangeTypeId", Type = "[Int32]" },
                new ResponseField { Name = "ComponentType", Type = "[String]" },
                new ResponseField { Name = "FlangeOrMechjoint", Type = "[String]" },
                new ResponseField { Name = "RatingClass", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "bolt_tension_gasket_type",
            Name = "Get Gasket Type",
            Section = "BoltTension",
            Endpoint = "BoltTension/getGasketType/{plantid}/{pcs}/",
            TableName = "bolt_tension_gasket_type",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter
                {
                    Name = "PLANTID",
                    DisplayName = "Plant Code",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "plant_codes",
                    ValueField = "PlantCode",
                    DisplayField = "Display"
                },
                new EndpointParameter
                {
                    Name = "PCS",
                    DisplayName = "PCS",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "pcs",
                    ValueField = "PCS",
                    DisplayField = "PCS",
                    DependsOn = "PLANTID"
                },
                new EndpointParameter
                {
                    Name = "FlangeTypeId",
                    DisplayName = "Flange Type ID",
                    IsRequired = true,
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter
                {
                    Name = "FlangeSize",
                    DisplayName = "Flange Size",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "query",
                    DropdownSource = "flange_sizes",
                    ValueField = "FlangeSize",
                    DisplayField = "Display"
                }
            },
            Description = "Retrieve gasket type information for bolt tension calculations",
            ResponseFields = new()
            {
                new ResponseField { Name = "GasketId", Type = "[Int32]" },
                new ResponseField { Name = "Display", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "bolt_tension_bolt_material",
            Name = "Get Bolt Material",
            Section = "BoltTension",
            Endpoint = "BoltTension/getBoltMaterial/{plantid}/{pcs}/",
            TableName = "bolt_tension_bolt_material",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter
                {
                    Name = "PLANTID",
                    DisplayName = "Plant Code",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "plant_codes",
                    ValueField = "PlantCode",
                    DisplayField = "Display"
                },
                new EndpointParameter
                {
                    Name = "PCS",
                    DisplayName = "PCS",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "pcs",
                    ValueField = "PCS",
                    DisplayField = "PCS",
                    DependsOn = "PLANTID"
                },
                new EndpointParameter
                {
                    Name = "FlangeTypeId",
                    DisplayName = "Flange Type ID",
                    IsRequired = true,
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter
                {
                    Name = "LubricantId",
                    DisplayName = "Lubricant ID",
                    IsRequired = true,
                    Type = "int",
                    ParameterLocation = "query"
                }
            },
            Description = "Retrieve bolt material information for bolt tension calculations",
            ResponseFields = new()
            {
                new ResponseField { Name = "BoltMaterialId", Type = "[Int32]" },
                new ResponseField { Name = "Display", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "bolt_tension_tension_forces",
            Name = "Get Tension Forces",
            Section = "BoltTension",
            Endpoint = "BoltTension/getTensionForces/{plantid}/{pcs}/",
            TableName = "bolt_tension_tension_forces",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter
                {
                    Name = "PLANTID",
                    DisplayName = "Plant Code",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "plant_codes",
                    ValueField = "PlantCode",
                    DisplayField = "Display"
                },
                new EndpointParameter
                {
                    Name = "PCS",
                    DisplayName = "PCS",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "pcs",
                    ValueField = "PCS",
                    DisplayField = "PCS",
                    DependsOn = "PLANTID"
                },
                new EndpointParameter
                {
                    Name = "FlangeTypeId",
                    DisplayName = "Flange Type ID",
                    IsRequired = true,
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter
                {
                    Name = "GasketTypeId",
                    DisplayName = "Gasket Type ID",
                    IsRequired = true,
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter
                {
                    Name = "BoltMaterialId",
                    DisplayName = "Bolt Material ID",
                    IsRequired = true,
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter
                {
                    Name = "FlangeSize",
                    DisplayName = "Flange Size",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "query",
                    DropdownSource = "flange_sizes",
                    ValueField = "FlangeSize",
                    DisplayField = "Display"
                },
                new EndpointParameter
                {
                    Name = "ComponentType",
                    DisplayName = "Component Type",
                    IsRequired = true,
                    Type = "text",
                    ParameterLocation = "query"
                },
                new EndpointParameter
                {
                    Name = "LubricantId",
                    DisplayName = "Lubricant ID",
                    IsRequired = true,
                    Type = "int",
                    ParameterLocation = "query"
                }
            },
            Description = "Calculate tension forces for bolt tension",
            ResponseFields = new()
            {
                new ResponseField { Name = "NoOfBolts", Type = "[Int32]" },
                new ResponseField { Name = "BoltDiameter", Type = "[String]" },
                new ResponseField { Name = "BoltDiameterDisplay", Type = "[String]" },
                new ResponseField { Name = "NutNomSize", Type = "[String]" },
                new ResponseField { Name = "kn", Type = "[Int32]" },
                new ResponseField { Name = "nm", Type = "[Int32]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "bolt_tension_tool",
            Name = "Get Tool",
            Section = "BoltTension",
            Endpoint = "BoltTension/getTool/{plantid}/",
            TableName = "bolt_tension_tool",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter
                {
                    Name = "PLANTID",
                    DisplayName = "Plant Code",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "plant_codes",
                    ValueField = "PlantCode",
                    DisplayField = "Display"
                },
                new EndpointParameter
                {
                    Name = "BoltDim",
                    DisplayName = "Bolt Dimension",
                    IsRequired = true,
                    Type = "text",
                    ParameterLocation = "query"
                }
            },
            Description = "Retrieve tool information for bolt tension",
            ResponseFields = new()
            {
                new ResponseField { Name = "ToolId", Type = "[Int32]" },
                new ResponseField { Name = "Display", Type = "[String]" },
                new ResponseField { Name = "PlantDefault", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "bolt_tension_tool_pressure",
            Name = "Get Tool Pressure",
            Section = "BoltTension",
            Endpoint = "BoltTension/getToolPressure/",
            TableName = "bolt_tension_tool_pressure",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter
                {
                    Name = "ToolId",
                    DisplayName = "Tool ID",
                    IsRequired = true,
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter
                {
                    Name = "BoltForceKN",
                    DisplayName = "Bolt Force (kN)",
                    IsRequired = true,
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter
                {
                    Name = "TorqueNM",
                    DisplayName = "Torque (Nm)",
                    IsRequired = true,
                    Type = "int",
                    ParameterLocation = "query"
                },
                new EndpointParameter
                {
                    Name = "FlangeOrMechjoint",
                    DisplayName = "Flange or Mech Joint",
                    IsRequired = true,
                    Type = "text",
                    ParameterLocation = "query"
                }
            },
            Description = "Calculate tool pressure for bolt tension",
            ResponseFields = new()
            {
                new ResponseField { Name = "ToolPressureA", Type = "[Int32]" },
                new ResponseField { Name = "ToolPressureB", Type = "[Int32]" },
                new ResponseField { Name = "Unit", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "bolt_tension_plant_info",
            Name = "Get Plant Info",
            Section = "BoltTension",
            Endpoint = "BoltTension/getPlantInfo/{plantid}/",
            TableName = "bolt_tension_plant_info",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter
                {
                    Name = "PLANTID",
                    DisplayName = "Plant Code",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "plant_codes",
                    ValueField = "PlantCode",
                    DisplayField = "Display"
                }
            },
            Description = "Retrieve plant information for bolt tension",
            ResponseFields = new()
            {
                new ResponseField { Name = "PlantName", Type = "[String]" },
                new ResponseField { Name = "ToolSerie", Type = "[String]" },
                new ResponseField { Name = "Lubricant", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "bolt_tension_lubricant",
            Name = "Get Lubricant",
            Section = "BoltTension",
            Endpoint = "BoltTension/getLubricant/{plantid}/",
            TableName = "bolt_tension_lubricant",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter
                {
                    Name = "PLANTID",
                    DisplayName = "Plant Code",
                    IsRequired = true,
                    Type = "dropdown",
                    ParameterLocation = "path",
                    DropdownSource = "plant_codes",
                    ValueField = "PlantCode",
                    DisplayField = "Display"
                }
            },
            Description = "Retrieve lubricant information for bolt tension",
            ResponseFields = new()
            {
                new ResponseField { Name = "LubricantId", Type = "[Int32]" },
                new ResponseField { Name = "Display", Type = "[String]" },
                new ResponseField { Name = "PlantDefault", Type = "[Int32]" }
            }
        }
    };
}
