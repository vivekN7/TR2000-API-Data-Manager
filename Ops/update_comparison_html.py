#!/usr/bin/env python3
"""
Script to update the HTML comparison page with better parameter formatting
"""

import re

def format_parameters(params_text):
    """Format parameters to be one per line and sorted"""
    if not params_text or params_text.strip() in ['None', 'none', '-']:
        return '<div class="param-list">None</div>'
    
    # Split parameters by common delimiters
    params = []
    
    # Handle different formats
    if ',' in params_text:
        # Format like "PLANTID (path, String, required), PCS (path, String, required)"
        parts = params_text.split(',')
        current_param = []
        for part in parts:
            if '(' in part and ')' not in part:
                current_param = [part]
            elif ')' in part and '(' not in part:
                current_param.append(part)
                params.append(','.join(current_param))
                current_param = []
            elif '(' in part and ')' in part:
                params.append(part)
            elif current_param:
                current_param.append(part)
            else:
                params.append(part)
    else:
        params = [params_text]
    
    # Clean and format each parameter
    formatted_params = []
    for param in params:
        param = param.strip()
        if param:
            # Extract parameter name for sorting
            match = re.match(r'^(\w+)', param)
            if match:
                param_name = match.group(1)
                formatted_params.append((param_name.upper(), param))
    
    # Sort by parameter name
    formatted_params.sort(key=lambda x: x[0])
    
    # Build HTML
    if formatted_params:
        html_lines = ['<div class="param-list">']
        for _, param in formatted_params:
            html_lines.append(f'  <div class="param-item">{param}</div>')
        html_lines.append('</div>')
        return '\n'.join(html_lines)
    else:
        return '<div class="param-list">None</div>'

def format_returns(returns_text):
    """Format return fields to be one per line and sorted"""
    if not returns_text or returns_text.strip() in ['None', 'none', '-']:
        return '<div class="return-list">None</div>'
    
    # Split return fields
    fields = []
    
    # Handle different formats
    if ':' in returns_text and '[' in returns_text:
        # Format like "OperatorID: [Int32], OperatorName: [String]"
        parts = returns_text.split(',')
        for part in parts:
            part = part.strip()
            if part:
                fields.append(part)
    elif ',' in returns_text:
        # Format like "OperatorID (Int32), OperatorName (String)"
        parts = returns_text.split(',')
        for part in parts:
            part = part.strip()
            if part:
                fields.append(part)
    else:
        fields = [returns_text]
    
    # Sort fields
    fields.sort()
    
    # Build HTML
    if fields:
        html_lines = ['<div class="return-list">']
        for field in fields:
            html_lines.append(f'  <div class="return-item">{field}</div>')
        html_lines.append('</div>')
        return '\n'.join(html_lines)
    else:
        return '<div class="return-list">None</div>'

# Read the original HTML file
with open('/workspace/TR2000/TR2K/Ops/API_Comparison.html', 'r') as f:
    html_content = f.read()

# Add additional CSS for parameter and return lists
additional_css = """
        .param-list, .return-list {
            padding: 5px 0;
        }
        
        .param-item, .return-item {
            padding: 3px 0;
            border-bottom: 1px dotted #e0e0e0;
            font-family: 'Courier New', monospace;
            font-size: 13px;
            line-height: 1.4;
        }
        
        .param-item:last-child, .return-item:last-child {
            border-bottom: none;
        }
        
        .param-list .param-item:hover, .return-list .return-item:hover {
            background-color: #f0f8ff;
        }
        
        /* Make parameter names bold */
        .param-item {
            color: #2c3e50;
        }
        
        .return-item {
            color: #27ae60;
        }
"""

# Insert the additional CSS before the closing </style> tag
html_content = html_content.replace('</style>', additional_css + '\n    </style>')

# Process each row to format parameters and returns
lines = html_content.split('\n')
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    
    # Check if this is a URL Parameters row
    if '<td class="row-label">URL Parameters</td>' in line:
        new_lines.append(line)
        i += 1
        # Process the next two td cells (API doc and Our implementation)
        for _ in range(2):
            if i < len(lines):
                td_line = lines[i]
                # Extract content between <td> tags
                match = re.search(r'<td[^>]*>(.*?)</td>', td_line)
                if match:
                    content = match.group(1)
                    formatted = format_parameters(content)
                    new_td = td_line[:match.start(1)] + formatted + td_line[match.end(1):]
                    new_lines.append(new_td)
                else:
                    new_lines.append(td_line)
                i += 1
    
    # Check if this is a Returns row
    elif '<td class="row-label">Returns</td>' in line:
        new_lines.append(line)
        i += 1
        # Process the next two td cells
        for _ in range(2):
            if i < len(lines):
                td_line = lines[i]
                # Extract content between <td> tags
                match = re.search(r'<td[^>]*>(.*?)</td>', td_line)
                if match:
                    content = match.group(1)
                    formatted = format_returns(content)
                    new_td = td_line[:match.start(1)] + formatted + td_line[match.end(1):]
                    new_lines.append(new_td)
                else:
                    new_lines.append(td_line)
                i += 1
    else:
        new_lines.append(line)
        i += 1

# Write the updated HTML
updated_html = '\n'.join(new_lines)

# Save to a new file
with open('/workspace/TR2000/TR2K/Ops/API_Comparison_Formatted.html', 'w') as f:
    f.write(updated_html)

print("Created API_Comparison_Formatted.html with improved parameter formatting")
print("Parameters and returns are now displayed one per line and sorted alphabetically")