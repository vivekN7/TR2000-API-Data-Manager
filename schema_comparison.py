#!/usr/bin/env python3
import sqlite3
import json
import urllib.request
import urllib.error
import sys
from typing import Dict, List, Tuple

def main():
    print("=== TR2000 API vs SQLite Schema Comparison ===\n")
    
    # TR2000 API endpoints to analyze
    endpoints = [
        "operators",
        "plants", 
        "plants/1/pcs",
        "plants/1/issues",
        "plants/2/pcs",
        "plants/2/issues"
    ]
    
    api_base_url = "https://tr2000api.equinor.com"
    db_path = "/workspace/TR2000/TR2K/TR2KBlazorUI/TR2KBlazorUI/Data/tr2000_api_data.db"
    
    print("🔍 STEP 1: Analyzing TR2000 API Response Structure")
    print("=================================================")
    
    api_structures = {}
    
    for endpoint in endpoints:
        try:
            print(f"\n📡 Analyzing endpoint: {endpoint}")
            
            url = f"{api_base_url}/{endpoint}"
            
            # Create request with timeout
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'TR2000-Schema-Comparator/1.0')
            
            with urllib.request.urlopen(req, timeout=30) as response:
                data = response.read().decode('utf-8')
                
            print(f"✅ Response received ({len(data)} characters)")
            
            # Parse the JSON to extract property names
            properties = extract_properties_from_json(data)
            api_structures[endpoint] = properties
            
            print(f"🔑 Properties found: {', '.join(properties)}")
            
            # Show a sample of the data
            sample_data = extract_sample_data(data)
            if sample_data:
                print(f"📋 Sample data: {sample_data}")
                
        except Exception as ex:
            print(f"❌ Error accessing {endpoint}: {str(ex)}")
            api_structures[endpoint] = [f"ERROR: {str(ex)}"]
    
    print("\n\n🗃️  STEP 2: Analyzing SQLite Database Schema")
    print("=============================================")
    
    db_structures = {}
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        tables = ["operators", "plants", "pcs", "issues"]
        
        for table in tables:
            print(f"\n📊 Analyzing table: {table}")
            
            cursor.execute(f"PRAGMA table_info([{table}])")
            rows = cursor.fetchall()
            
            columns = []
            
            for row in rows:
                name = row[1]  # column name
                col_type = row[2]  # column type
                not_null = row[3] == 1
                pk = row[5] == 1
                
                # Skip auto-generated columns for comparison
                if name not in ["Id", "CreatedDate", "ModifiedDate"]:
                    type_info = f"{col_type}"
                    if not_null:
                        type_info += " NOT NULL"
                    if pk:
                        type_info += " PK"
                    columns.append((name, type_info))
            
            db_structures[table] = columns
            
            col_display = ", ".join([f"{c[0]}({c[1]})" for c in columns])
            print(f"🏗️  Columns: {col_display}")
        
        conn.close()
        
    except Exception as ex:
        print(f"❌ Error reading database: {str(ex)}")
    
    print("\n\n⚖️  STEP 3: COMPARISON RESULTS")
    print("===============================")
    
    # Map endpoints to table names
    endpoint_to_table = {
        "operators": "operators",
        "plants": "plants",
        "plants/1/pcs": "pcs",
        "plants/2/pcs": "pcs",
        "plants/1/issues": "issues",
        "plants/2/issues": "issues"
    }
    
    for endpoint in endpoints:
        if endpoint in endpoint_to_table:
            table_name = endpoint_to_table[endpoint]
            print(f"\n🔍 Comparing {endpoint} ↔️ {table_name}")
            
            api_props = api_structures.get(endpoint, [])
            db_cols = db_structures.get(table_name, [])
            db_col_names = [col[0] for col in db_cols]
            
            print(f"   API Properties ({len(api_props)}): {', '.join(api_props)}")
            print(f"   DB Columns ({len(db_cols)}): {', '.join(db_col_names)}")
            
            # Find matches
            matches = [prop for prop in api_props if prop in db_col_names]
            missing_in_db = [prop for prop in api_props if prop not in db_col_names]
            missing_in_api = [col[0] for col in db_cols if col[0] not in api_props]
            
            if matches:
                print(f"   ✅ Matches: {', '.join(matches)}")
                
            if missing_in_db:
                print(f"   ⚠️  Missing in DB: {', '.join(missing_in_db)}")
                
            if missing_in_api:
                print(f"   ⚠️  Missing in API: {', '.join(missing_in_api)}")
            
            match_percentage = (len(matches) * 100.0 / len(api_props)) if api_props else 0
            print(f"   📊 Match Rate: {match_percentage:.1f}%")
    
    print("\n\n📋 FINAL SUMMARY")
    print("================")
    
    # Group endpoints by table
    table_endpoints = {}
    for endpoint, table in endpoint_to_table.items():
        if table not in table_endpoints:
            table_endpoints[table] = []
        table_endpoints[table].append(endpoint)
    
    for table_name, related_endpoints in table_endpoints.items():
        print(f"\n🏗️  Table: {table_name}")
        print(f"   🔗 Related endpoints: {', '.join(related_endpoints)}")
        
        if table_name in db_structures:
            cols = db_structures[table_name]
            schema_display = ", ".join([f"{col[0]} {col[1]}" for col in cols])
            print(f"   📋 Schema: {schema_display}")

def extract_properties_from_json(json_str: str) -> List[str]:
    properties = set()
    
    try:
        data = json.loads(json_str)
        
        # Handle different JSON structures
        if isinstance(data, list) and len(data) > 0:
            first_item = data[0]
            add_properties_from_element(first_item, properties)
        elif isinstance(data, dict):
            # Look for arrays in wrapper objects
            array_found = False
            for key, value in data.items():
                if isinstance(value, list) and len(value) > 0:
                    first_item = value[0]
                    add_properties_from_element(first_item, properties)
                    array_found = True
                    break
            
            # If no arrays found, use root object properties
            if not array_found:
                add_properties_from_element(data, properties)
                
    except Exception as ex:
        properties.add(f"JSON_PARSE_ERROR: {str(ex)}")
    
    return list(properties)

def add_properties_from_element(element, properties: set):
    if isinstance(element, dict):
        for key in element.keys():
            properties.add(key)

def extract_sample_data(json_str: str) -> str:
    try:
        data = json.loads(json_str)
        
        first_item = None
        
        if isinstance(data, list) and len(data) > 0:
            first_item = data[0]
        elif isinstance(data, dict):
            for key, value in data.items():
                if isinstance(value, list) and len(value) > 0:
                    first_item = value[0]
                    break
        
        if first_item and isinstance(first_item, dict):
            sample_props = []
            for key, value in first_item.items():
                if isinstance(value, str):
                    sample_props.append(f"{key}='{value}'")
                elif isinstance(value, (int, float)):
                    sample_props.append(f"{key}={value}")
                elif isinstance(value, bool):
                    sample_props.append(f"{key}={str(value).lower()}")
                elif value is None:
                    sample_props.append(f"{key}=null")
                else:
                    sample_props.append(f"{key}={str(value)}")
            return ", ".join(sample_props)
    except:
        pass
    
    return ""

if __name__ == "__main__":
    main()