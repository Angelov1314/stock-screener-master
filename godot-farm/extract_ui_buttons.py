#!/usr/bin/env python3
"""
Extract UI buttons from spritesheet using SAM
"""

import sys
import os
from PIL import Image
import json

# Input/output paths
input_image = "/Users/jerry/.openclaw/workspace/godot-farm/assets/ui/ui_buttons_spritesheet.png"
output_dir = "/Users/jerry/.openclaw/workspace/godot-farm/assets/ui/buttons_extracted"

# Create output directory
os.makedirs(output_dir, exist_ok=True)

# Load image
img = Image.open(input_image)
width, height = img.size
print(f"Image size: {width}x{height}")

# Analyze image to find button rows
# We'll use a simple approach: detect horizontal gaps between buttons

def find_button_rows(img):
    """Find button row boundaries by detecting content"""
    pixels = img.load()
    width, height = img.size
    
    # Check each row for content (non-transparent or non-white pixels)
    row_has_content = []
    for y in range(height):
        has_content = False
        for x in range(width):
            r, g, b, a = pixels[x, y] if img.mode == 'RGBA' else (*pixels[x, y], 255)
            # Consider pixel as content if not fully transparent and not pure white
            if a > 10 and not (r > 240 and g > 240 and b > 240):
                has_content = True
                break
        row_has_content.append(has_content)
    
    # Find row boundaries (transitions from no-content to content and vice versa)
    rows = []
    in_button = False
    start_y = 0
    
    for y, has_content in enumerate(row_has_content):
        if has_content and not in_button:
            # Start of button
            start_y = y
            in_button = True
        elif not has_content and in_button:
            # End of button (with some gap)
            # Check if there's enough empty space or we've reached min button height
            if y - start_y > 50:  # Min button height
                rows.append((start_y, y))
                in_button = False
    
    # Handle last button
    if in_button:
        rows.append((start_y, height))
    
    return rows

# Find button rows
print("Analyzing image for button rows...")
rows = find_button_rows(img)
print(f"Found {len(rows)} button rows")

# Crop each row
row_files = []
for i, (start_y, end_y) in enumerate(rows):
    # Add some padding
    crop_top = max(0, start_y - 10)
    crop_bottom = min(height, end_y + 10)
    
    cropped = img.crop((0, crop_top, width, crop_bottom))
    row_file = os.path.join(output_dir, f"row_{i:02d}.png")
    cropped.save(row_file)
    row_files.append(row_file)
    print(f"Row {i}: y={start_y}-{end_y}, saved to {row_file}")

print(f"\nCropped {len(row_files)} rows to {output_dir}")
print("\nNext step: Run SAM segmentation on each row")
