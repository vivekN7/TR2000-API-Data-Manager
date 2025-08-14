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
                    DisplayName = "Plant ID (numeric or alphanumeric)", 
                    IsRequired = true, 
                    Type = "string"
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
                new ResponseField { Name = "Area", Type = "[String]" }
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
                    DisplayField = "ShortDescription"
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
                    DisplayField = "ShortDescription"
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
                    DisplayField = "ShortDescription"
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
                    DisplayField = "ShortDescription"
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
                    DisplayField = "ShortDescription"
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
                    DisplayField = "ShortDescription"
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
                    DisplayField = "ShortDescription"
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
                    DisplayField = "ShortDescription"
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
                    DisplayField = "ShortDescription"
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
        },
        
        // Additional PCS endpoints
        new EndpointConfiguration
        {
            Key = "pcs_header",
            Name = "Get header and properties",
            Section = "PCS",
            Endpoint = "pcs/{pcsid}/rev/{revision}/header",
            TableName = "pcs_header",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PCSID", 
                    DisplayName = "PCS ID", 
                    IsRequired = true, 
                    Type = "string"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Revision",
                    IsRequired = true,
                    Type = "string"
                }
            },
            Description = "Retrieve header and properties for a specific PCS",
            ResponseFields = new()
            {
                new ResponseField { Name = "PCS", Type = "[String]" },
                new ResponseField { Name = "Revision", Type = "[String]" },
                new ResponseField { Name = "Properties", Type = "[Object]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pcs_temperature_pressure",
            Name = "Get temperature and pressure",
            Section = "PCS",
            Endpoint = "pcs/{pcsid}/rev/{revision}/temperature-pressure",
            TableName = "pcs_temperature_pressure",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PCSID", 
                    DisplayName = "PCS ID", 
                    IsRequired = true, 
                    Type = "string"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Revision",
                    IsRequired = true,
                    Type = "string"
                }
            },
            Description = "Retrieve temperature and pressure data for a specific PCS",
            ResponseFields = new()
            {
                new ResponseField { Name = "Temperature", Type = "[String]" },
                new ResponseField { Name = "Pressure", Type = "[String]" },
                new ResponseField { Name = "DesignTemperature", Type = "[String]" },
                new ResponseField { Name = "DesignPressure", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pcs_pipe_size",
            Name = "Get pipe size",
            Section = "PCS",
            Endpoint = "pcs/{pcsid}/rev/{revision}/pipe-size",
            TableName = "pcs_pipe_size",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PCSID", 
                    DisplayName = "PCS ID", 
                    IsRequired = true, 
                    Type = "string"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Revision",
                    IsRequired = true,
                    Type = "string"
                }
            },
            Description = "Retrieve pipe size data for a specific PCS",
            ResponseFields = new()
            {
                new ResponseField { Name = "NominalSize", Type = "[String]" },
                new ResponseField { Name = "OutsideDiameter", Type = "[String]" },
                new ResponseField { Name = "WallThickness", Type = "[String]" },
                new ResponseField { Name = "Schedule", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pcs_pipe_element",
            Name = "Get pipe element",
            Section = "PCS",
            Endpoint = "pcs/{pcsid}/rev/{revision}/pipe-element",
            TableName = "pcs_pipe_element",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PCSID", 
                    DisplayName = "PCS ID", 
                    IsRequired = true, 
                    Type = "string"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Revision",
                    IsRequired = true,
                    Type = "string"
                }
            },
            Description = "Retrieve pipe element data for a specific PCS",
            ResponseFields = new()
            {
                new ResponseField { Name = "ElementID", Type = "[String]" },
                new ResponseField { Name = "ElementType", Type = "[String]" },
                new ResponseField { Name = "Material", Type = "[String]" },
                new ResponseField { Name = "Specification", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pcs_valve_element",
            Name = "Get valve element",
            Section = "PCS",
            Endpoint = "pcs/{pcsid}/rev/{revision}/valve-element",
            TableName = "pcs_valve_element",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PCSID", 
                    DisplayName = "PCS ID", 
                    IsRequired = true, 
                    Type = "string"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Revision",
                    IsRequired = true,
                    Type = "string"
                }
            },
            Description = "Retrieve valve element data for a specific PCS",
            ResponseFields = new()
            {
                new ResponseField { Name = "ValveType", Type = "[String]" },
                new ResponseField { Name = "ValveClass", Type = "[String]" },
                new ResponseField { Name = "EndConnection", Type = "[String]" },
                new ResponseField { Name = "Material", Type = "[String]" }
            }
        },
        
        new EndpointConfiguration
        {
            Key = "pcs_embedded_note",
            Name = "Get embedded note",
            Section = "PCS",
            Endpoint = "pcs/{pcsid}/rev/{revision}/embedded-note",
            TableName = "pcs_embedded_note",
            HttpMethod = "GET",
            Parameters = new()
            {
                new EndpointParameter 
                { 
                    Name = "PCSID", 
                    DisplayName = "PCS ID", 
                    IsRequired = true, 
                    Type = "string"
                },
                new EndpointParameter
                {
                    Name = "REVISION",
                    DisplayName = "Revision",
                    IsRequired = true,
                    Type = "string"
                }
            },
            Description = "Retrieve embedded notes for a specific PCS",
            ResponseFields = new()
            {
                new ResponseField { Name = "NoteID", Type = "[String]" },
                new ResponseField { Name = "NoteText", Type = "[String]" },
                new ResponseField { Name = "CreatedDate", Type = "[String]" },
                new ResponseField { Name = "CreatedBy", Type = "[String]" }
            }
        }
    };
}