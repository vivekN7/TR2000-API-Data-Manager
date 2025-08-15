#!/usr/bin/env python3
"""
Script to scrape TR2000 API documentation and compare with our implementation
"""

import requests
from bs4 import BeautifulSoup
import json
import csv
import re

def fetch_api_help():
    """Fetch and parse the API help page"""
    url = "https://tr2000api.equinor.com/Home/Help"
    
    # For now, we'll manually define the endpoints based on what we know
    # In a real scenario, we'd parse the HTML
    
    api_endpoints = [
        # Operators and Plants
        {
            "section": "Operators and Plants",
            "name": "Get operators",
            "url_template": "/operators/",
            "method": "GET",
            "url_params": [],
            "returns": [
                {"name": "OperatorID", "type": "Int32"},
                {"name": "OperatorName", "type": "String"}
            ]
        },
        {
            "section": "Operators and Plants",
            "name": "Get operator plants",
            "url_template": "/operators/{operatorid}/plants/",
            "method": "GET",
            "url_params": [
                {"name": "OPERATORID", "type": "Int32"}
            ],
            "returns": [
                {"name": "OperatorID", "type": "Int32"},
                {"name": "OperatorName", "type": "String"},
                {"name": "PlantID", "type": "String"},
                {"name": "ShortDescription", "type": "String"},
                {"name": "Project", "type": "String"},
                {"name": "LongDescription", "type": "String"},
                {"name": "CommonLibPlantCode", "type": "String"},
                {"name": "InitialRevision", "type": "String"},
                {"name": "AreaID", "type": "Int32"},
                {"name": "Area", "type": "String"}
            ]
        },
        {
            "section": "Operators and Plants",
            "name": "Get plants",
            "url_template": "/plants/",
            "method": "GET",
            "url_params": [],
            "returns": [
                {"name": "OperatorID", "type": "Int32"},
                {"name": "OperatorName", "type": "String"},
                {"name": "PlantID", "type": "String"},
                {"name": "ShortDescription", "type": "String"},
                {"name": "Project", "type": "String"},
                {"name": "LongDescription", "type": "String"},
                {"name": "CommonLibPlantCode", "type": "String"},
                {"name": "InitialRevision", "type": "String"},
                {"name": "AreaID", "type": "Int32"},
                {"name": "Area", "type": "String"}
            ]
        },
        {
            "section": "Operators and Plants",
            "name": "Get plant",
            "url_template": "/plants/{plantid}/",
            "method": "GET",
            "url_params": [
                {"name": "PLANTID", "type": "String"}
            ],
            "returns": [
                {"name": "OperatorID", "type": "Int32"},
                {"name": "OperatorName", "type": "String"},
                {"name": "PlantID", "type": "String"},
                {"name": "ShortDescription", "type": "String"},
                {"name": "Project", "type": "String"},
                {"name": "LongDescription", "type": "String"},
                {"name": "CommonLibPlantCode", "type": "String"},
                {"name": "InitialRevision", "type": "String"},
                {"name": "AreaID", "type": "Int32"},
                {"name": "Area", "type": "String"}
            ]
        },
        
        # Issues Section
        {
            "section": "Issues - Collection of datasheets",
            "name": "Get issue revisions",
            "url_template": "/plants/{plantid}/issues/",
            "method": "GET",
            "url_params": [
                {"name": "PLANTID", "type": "String"}
            ],
            "returns": [
                {"name": "IssueRevision", "type": "String"},
                {"name": "IssueDate", "type": "String"},
                {"name": "RegisteredBy", "type": "String"},
                {"name": "CheckedBy", "type": "String"},
                {"name": "ApprovedBy", "type": "String"}
            ]
        },
        
        # Add more endpoints here...
        # This is a template - we need to add all endpoints
    ]
    
    return api_endpoints

def load_our_implementation():
    """Load our endpoint configuration from the C# file"""
    config_file = "/workspace/TR2000/TR2K/TR2KBlazorLibrary/Models/EndpointConfiguration.cs"
    
    with open(config_file, 'r') as f:
        content = f.read()
    
    # Parse our endpoints (simplified extraction)
    our_endpoints = []
    
    # This is a simplified parser - in reality we'd need more sophisticated parsing
    # For now, let's return a structure we can compare
    
    return our_endpoints

def create_comparison_csv():
    """Create a CSV comparing API docs with our implementation"""
    
    api_endpoints = fetch_api_help()
    our_endpoints = load_our_implementation()
    
    # Create CSV
    with open('/workspace/TR2000/TR2K/Ops/API_Comparison.csv', 'w', newline='') as csvfile:
        fieldnames = [
            'Section', 'Endpoint Name', 'API URL Template', 'Our URL Template',
            'Match Status', 'API Params', 'Our Params', 'Params Match',
            'API Returns', 'Our Returns', 'Returns Match', 'Notes'
        ]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        
        # Write comparison rows
        for api_ep in api_endpoints:
            row = {
                'Section': api_ep['section'],
                'Endpoint Name': api_ep['name'],
                'API URL Template': api_ep['url_template'],
                'Our URL Template': '',  # To be filled from our implementation
                'Match Status': '',
                'API Params': json.dumps([p['name'] + ':' + p['type'] for p in api_ep['url_params']]),
                'Our Params': '',
                'Params Match': '',
                'API Returns': json.dumps([r['name'] + ':' + r['type'] for r in api_ep['returns']]),
                'Our Returns': '',
                'Returns Match': '',
                'Notes': ''
            }
            writer.writerow(row)
    
    print("Created API_Comparison.csv")

if __name__ == "__main__":
    create_comparison_csv()