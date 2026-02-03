#!/usr/bin/env python3
"""
Script to sync translations from web app to Flutter app.
Converts web app JSON files to Flutter ARB format.
"""

import json
import os
import sys
import re

WEB_APP_I18N = r"F:\Projects\dish-genie-visions\src\i18n\locales"
FLUTTER_ARB_DIR = "lib/l10n"

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
    if not parts:
        return ""
    
    # First part stays lowercase, subsequent parts are capitalized
    result = parts[0]
    for part in parts[1:]:
        if part:
            result += part[0].upper() + part[1:]
    return result

def extract_parameters(text):
    """Extract parameters from text ({{param}} -> {param})"""
    params = re.findall(r'\{\{(\w+)\}\}', str(text))
    new_text = re.sub(r'\{\{(\w+)\}\}', r'{\1}', str(text))
    return new_text, params

def create_arb_entry(key, value):
    """Create ARB entry with metadata for parameters"""
    arb_key = convert_to_arb_key(key)
    text, params = extract_parameters(value)
    
    entry = {arb_key: text}
    
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
    """Convert a JSON file from web app to ARB format for Flutter"""
    try:
        with open(json_file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        flattened = flatten_json(data)
        
        arb_data = {}
        for key, value in flattened.items():
            entries = create_arb_entry(key, value)
            arb_data.update(entries)
        
        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_arb_path), exist_ok=True)
        
        with open(output_arb_path, 'w', encoding='utf-8') as f:
            json.dump(arb_data, f, ensure_ascii=False, indent=2)
        
        print(f"[OK] Converted {os.path.basename(json_file_path)} -> {os.path.basename(output_arb_path)}")
        return True
    except Exception as e:
        print(f"[ERROR] Error converting {json_file_path}: {e}")
        return False

def main():
    if not os.path.exists(WEB_APP_I18N):
        print(f"Error: Web app i18n directory not found: {WEB_APP_I18N}")
        sys.exit(1)
    
    # Get all JSON files from web app
    web_json_files = [f for f in os.listdir(WEB_APP_I18N) if f.endswith('.json')]
    
    if not web_json_files:
        print(f"Error: No JSON files found in {WEB_APP_I18N}")
        sys.exit(1)
    
    print(f"Found {len(web_json_files)} language files in web app")
    print(f"Syncing to Flutter ARB files...\n")
    
    success_count = 0
    for json_file in sorted(web_json_files):
        lang_code = json_file.replace('.json', '')
        web_path = os.path.join(WEB_APP_I18N, json_file)
        arb_path = os.path.join(FLUTTER_ARB_DIR, f"app_{lang_code}.arb")
        
        if convert_json_to_arb(web_path, arb_path):
            success_count += 1
    
    print(f"\n[SUCCESS] Successfully synced {success_count}/{len(web_json_files)} language files")
    print(f"\nNext steps:")
    print(f"1. Run: flutter pub get")
    print(f"2. Run: flutter gen-l10n")
    print(f"3. Verify all translations are working correctly")

if __name__ == '__main__':
    main()
