#!/usr/bin/env python3
"""
Apply all Phase 1 changes based on Phase1_Comments.txt
"""

import re
import json

# Read the current configuration file
with open('/workspace/TR2000/TR2K/TR2KBlazorLibrary/Models/EndpointConfiguration.cs', 'r') as f:
    content = f.read()

# Store original for comparison
original_content = content

# 1. Remove the duplicate "Get PCS properties" endpoint
# Find and remove the entire pcs_properties configuration block
pattern = r'new EndpointConfiguration\s*\{\s*Key = "pcs_properties"[^}]*?\}\s*\}(?:,\s*)?'
content = re.sub(pattern, '', content, flags=re.DOTALL)

# 2. Update all PCSID to PCSNAME throughout
content = content.replace('Name = "PCSID"', 'Name = "PCSNAME"')
content = content.replace('DisplayName = "Select PCS"', 'DisplayName = "PCS Name"')
content = content.replace('/{pcsid}/', '/{pcsname}/')
content = content.replace('{pcsid}', '{pcsname}')

# 3. Update plant dropdown display format
# Change DisplayField from "ShortDescription" to "LongDescription" for plants
content = re.sub(
    r'(DropdownSource = "plants"[^}]*?DisplayField = )"ShortDescription"',
    r'\1"LongDescription"',
    content,
    flags=re.DOTALL
)

# 4. Fix endpoint names
content = content.replace('Name = "Get PCS details"', 'Name = "Get header and properties"')

print("Changes applied:")
print("1. Removed duplicate 'Get PCS properties' endpoint")
print("2. Updated all PCSID to PCSNAME")
print("3. Updated plant dropdown display to use LongDescription")
print("4. Fixed endpoint names")

# Write the updated content
with open('/workspace/TR2000/TR2K/TR2KBlazorLibrary/Models/EndpointConfiguration.cs', 'w') as f:
    f.write(content)

print("\nEndpointConfiguration.cs has been updated")

# Now let's also create a script to update the missing return fields
print("\nCreating return fields update script...")

# Define all the missing return fields based on Phase1_Comments.txt
missing_fields = {
    "plant": [
        'new ResponseField { Name = "EnableEmbeddedNote", Type = "[String]" }',
        'new ResponseField { Name = "CategoryID", Type = "[String]" }',
        'new ResponseField { Name = "Category", Type = "[String]" }',
        'new ResponseField { Name = "DocumentSpaceLink", Type = "[String]" }',
        'new ResponseField { Name = "EnableCopyPCSFromPlant", Type = "[String]" }',
        'new ResponseField { Name = "OverLength", Type = "[String]" }',
        'new ResponseField { Name = "PCSQA", Type = "[String]" }',
        'new ResponseField { Name = "EDSMJ", Type = "[String]" }',
        'new ResponseField { Name = "CelsiusBar", Type = "[String]" }',
        'new ResponseField { Name = "WebInfoText", Type = "[String]" }',
        'new ResponseField { Name = "BoltTensionText", Type = "[String]" }',
        'new ResponseField { Name = "Visible", Type = "[String]" }',
        'new ResponseField { Name = "WindowsRemarkText", Type = "[String]" }',
        'new ResponseField { Name = "UserProtected", Type = "[String]" }'
    ],
    "plant_issues": [
        'new ResponseField { Name = "UserName", Type = "[String]" }',
        'new ResponseField { Name = "UserEntryTime", Type = "[String]" }',
        'new ResponseField { Name = "UserProtected", Type = "[String]" }'
    ],
    "pipe_element_references": [
        'new ResponseField { Name = "ElementGroup", Type = "[String]" }',
        'new ResponseField { Name = "DimensionStandard", Type = "[String]" }',
        'new ResponseField { Name = "ProductForm", Type = "[String]" }',
        'new ResponseField { Name = "MaterialGrade", Type = "[String]" }',
        'new ResponseField { Name = "MDS", Type = "[String]" }',
        'new ResponseField { Name = "MDSRevision", Type = "[String]" }',
        'new ResponseField { Name = "Area", Type = "[String]" }',
        'new ResponseField { Name = "ElementID", Type = "[Int32]" }',
        'new ResponseField { Name = "Revision", Type = "[String]" }',
        'new ResponseField { Name = "RevDate", Type = "[String]" }',
        'new ResponseField { Name = "Status", Type = "[String]" }',
        'new ResponseField { Name = "Delta", Type = "[String]" }'
    ]
}

print("Missing return fields identified for:")
for key in missing_fields:
    print(f"  - {key}: {len(missing_fields[key])} fields")

print("\nPhase 1 changes preparation complete!")
print("Next steps:")
print("1. Add missing return fields to endpoints")
print("2. Add optional parameters to PCS list and VDS list")
print("3. Update endpoint details display in ApiData.razor")
print("4. Add red asterisk for mandatory parameters")
print("5. Format parameters to display one below the other")