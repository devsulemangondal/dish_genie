#!/usr/bin/env python3
"""
Convert nested JSON localization files to flat ARB format
"""
import json
import os
import sys

def flatten_json(nested_dict, parent_key='', sep='.'):
    """Flatten nested JSON structure"""
    items = []
    for k, v in nested_dict.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_json(v, new_key, sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

def convert_to_arb_key(json_key):
    """Convert JSON key (e.g., 'common.home') to ARB key (e.g., 'commonHome')"""
    parts = json_key.split('.')
    # Capitalize first letter of each part except the first
    if len(parts) == 1:
        return parts[0]
    # First part stays lowercase, rest get capitalized first letter
    result = parts[0]
    for part in parts[1:]:
        if part:
            result += part[0].upper() + part[1:] if len(part) > 1 else part.upper()
    return result

def extract_parameters(text):
    """Extract parameters from text ({{param}} -> {param})"""
    import re
    # Find all {{param}} patterns
    params = re.findall(r'\{\{(\w+)\}\}', text)
    # Replace {{param}} with {param}
    new_text = re.sub(r'\{\{(\w+)\}\}', r'{\1}', text)
    return new_text, params

def create_arb_entry(key, value):
    """Create ARB entry with metadata for parameters"""
    arb_key = convert_to_arb_key(key)
    text, params = extract_parameters(str(value))
    
    entry = {arb_key: text}
    
    # Add parameter metadata if needed
    if params:
        placeholders = {}
        for param in params:
            placeholders[param] = {
                "type": "String",
                "format": "none"
            }
        entry[f"@{arb_key}"] = {
            "placeholders": placeholders
        }
    
    return entry

def convert_json_to_arb(json_file_path, output_arb_path):
    """Convert a JSON file to ARB format"""
    with open(json_file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Flatten the nested structure
    flattened = flatten_json(data)
    
    # Convert to ARB format
    arb_data = {}
    for key, value in flattened.items():
        entries = create_arb_entry(key, value)
        arb_data.update(entries)
    
    # Write ARB file
    with open(output_arb_path, 'w', encoding='utf-8') as f:
        json.dump(arb_data, f, ensure_ascii=False, indent=2)
    
    print(f"Converted {json_file_path} to {output_arb_path}")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python convert_json_to_arb.py <input_json> <output_arb>")
        sys.exit(1)
    
    convert_json_to_arb(sys.argv[1], sys.argv[2])
