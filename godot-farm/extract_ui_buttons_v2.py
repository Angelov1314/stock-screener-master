#!/usr/bin/env python3
"""
Extract UI buttons from spritesheet using SAM - Manual row detection
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

# Based on visual inspection, manually define row coordinates
# These are approximate - adjust based on actual image

# Common UI button heights - estimate based on image proportions
# If image is 2848px tall and has ~10 buttons, each is ~285px

# Let's use a smarter approach: detect gaps by looking at horizontal projection

def get_horizontal_projection(img):
    """Get sum of pixel values for each row"""
    import numpy as np
    
    # Convert to grayscale
    if img.mode == 'RGBA':
        # Use alpha channel
        gray = img.split()[-1]
    else:
        gray = img.convert('L')
    
    arr = np.array(gray)
    # Sum across width
    projection = np.sum(arr, axis=1)
    return projection

def find_gaps(projection, threshold_factor=0.1):
    """Find gap rows (low content)"""
    max_val = np.max(projection)
    threshold = max_val * threshold_factor
    
    gaps = []
    in_gap = False
    gap_start = 0
    
    for i, val in enumerate(projection):
        if val < threshold and not in_gap:
            gap_start = i
            in_gap = True
        elif val >= threshold and in_gap:
            # End of gap
            if i - gap_start > 5:  # Min gap size
                gaps.append((gap_start, i))
            in_gap = False
    
    if in_gap:
        gaps.append((gap_start, len(projection)))
    
    return gaps

import numpy as np

print("Analyzing horizontal projection...")
projection = get_horizontal_projection(img)
gaps = find_gaps(projection)

print(f"Found {len(gaps)} potential gaps between buttons")
for i, (start, end) in enumerate(gaps[:20]):  # Show first 20
    print(f"  Gap {i}: rows {start}-{end} (height: {end-start})")

# Use gaps to determine button boundaries
# Buttons are regions between gaps
boundaries = [0]
for start, end in gaps:
    mid = (start + end) // 2
    boundaries.append(mid)
boundaries.append(height)

print(f"\nButton boundaries: {boundaries}")

# Crop each button
row_files = []
for i in range(len(boundaries) - 1):
    start_y = boundaries[i]
    end_y = boundaries[i + 1]
    
    # Skip if too small
    if end_y - start_y < 50:
        continue
    
    # Add padding
    crop_top = max(0, start_y)
    crop_bottom = min(height, end_y)
    
    cropped = img.crop((0, crop_top, width, crop_bottom))
    row_file = os.path.join(output_dir, f"button_{i:02d}.png")
    cropped.save(row_file)
    row_files.append((f"button_{i:02d}", row_file))
    print(f"Button {i}: y={crop_top}-{crop_bottom}, height={crop_bottom-crop_top}px")

print(f"\nCropped {len(row_files)} buttons to {output_dir}")

# Save config for SAM segmentation
strips_config = {name: [os.path.basename(path), 1] for name, path in row_files}
config_path = os.path.join(output_dir, "strips_config.json")
with open(config_path, 'w') as f:
    json.dump(strips_config, f, indent=2)

print(f"\nConfig saved to {config_path}")
print("\nTo segment with SAM, run:")
print(f"python3 -u scripts/sam_segment.py {output_dir} '{json.dumps(strips_config)}'")
