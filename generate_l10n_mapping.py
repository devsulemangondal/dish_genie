#!/usr/bin/env python3
"""
Generate Dart code for mapping old keys to new l10n getters
"""
import json
import re

def convert_to_getter_name(key):
    """Convert ARB key to getter name (already in camelCase)"""
    return key

def convert_to_old_key(key):
    """Convert ARB key (e.g., 'commonHome') back to old format (e.g., 'common.home')"""
    # Insert dots before capital letters (except the first one)
    result = key[0].lower()
    for char in key[1:]:
        if char.isupper():
            result += '.' + char.lower()
        else:
            result += char
    return result

def generate_mapping(arb_file):
    """Generate Dart mapping code from ARB file"""
    with open(arb_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    mappings = []
    for key in data.keys():
        if not key.startswith('@'):  # Skip metadata keys
            old_key = convert_to_old_key(key)
            getter_name = key
            mappings.append((old_key, getter_name))
    
    # Generate Dart code
    dart_code = "  static final Map<String, String Function(AppLocalizations)> _localizationMap = {\n"
    for old_key, getter_name in sorted(mappings):
        dart_code += f"    '{old_key}': (l) => l.{getter_name},\n"
    dart_code += "  };"
    
    return dart_code

if __name__ == '__main__':
    mapping = generate_mapping('lib/l10n/app_en.arb')
    print(mapping)
