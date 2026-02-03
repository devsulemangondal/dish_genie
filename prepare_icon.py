#!/usr/bin/env python3
"""
Script to add padding around the logo for proper icon display.
This ensures the complete logo is visible without zooming/cropping.
"""

from PIL import Image
import os

def add_padding_to_icon(input_path, output_path, padding_percent=25):
    """
    Add padding around an image for icon use.
    
    Args:
        input_path: Path to input image
        output_path: Path to save padded image
        padding_percent: Percentage of padding to add (default 25%)
    """
    # Open the original image
    img = Image.open(input_path)
    
    # Convert to RGBA if not already
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # Get original dimensions
    orig_width, orig_height = img.size
    
    # Use the larger dimension as base for square output
    max_dimension = max(orig_width, orig_height)
    
    # Calculate padding based on the max dimension (25% on each side)
    padding = int(max_dimension * padding_percent / 100)
    
    # Create square canvas with padding
    square_size = max_dimension + (padding * 2)
    
    # Calculate position to center the image
    offset_x = (square_size - orig_width) // 2
    offset_y = (square_size - orig_height) // 2
    
    # Create new square image with transparent background
    new_img = Image.new('RGBA', (square_size, square_size), (255, 255, 255, 0))
    
    # Paste original image centered
    new_img.paste(img, (offset_x, offset_y), img if img.mode == 'RGBA' else None)
    
    # Save the padded image
    new_img.save(output_path, 'PNG')
    print(f"Created padded icon: {output_path}")
    print(f"Original size: {orig_width}x{orig_height}")
    print(f"New size: {square_size}x{square_size} (square)")
    print(f"Padding: {padding_percent}% ({padding} pixels on each side)")

if __name__ == "__main__":
    input_file = "assets/genie-mascot.png"
    output_file = "assets/genie-mascot-padded.png"
    
    if not os.path.exists(input_file):
        print(f"Error: Input file not found: {input_file}")
        exit(1)
    
    # Add 25% padding to ensure complete logo visibility
    add_padding_to_icon(input_file, output_file, padding_percent=25)
    print("\n✓ Padded icon created successfully!")
    print("Update pubspec.yaml to use 'assets/genie-mascot-padded.png' as image_path")
