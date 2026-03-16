#!/usr/bin/env python3
"""Segment sprites from row strips using alpha channel connected components."""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

def segment_by_alpha(image_path, output_dir, name_prefix, min_area=2000, padding=5):
    """Find connected non-transparent regions and extract as individual sprites."""
    img = Image.open(image_path).convert("RGBA")
    arr = np.array(img)
    
    # Create binary mask from alpha channel (non-transparent pixels)
    alpha = arr[:, :, 3]
    binary = (alpha > 10).astype(np.uint8)
    
    # Dilate slightly to connect nearby pixels (e.g. shadow beneath sprite)
    struct = ndimage.generate_binary_structure(2, 2)
    dilated = ndimage.binary_dilation(binary, struct, iterations=8)
    
    # Label connected components
    labeled, num_features = ndimage.label(dilated)
    print(f"  Found {num_features} connected regions in {image_path}")
    
    sprites = []
    for i in range(1, num_features + 1):
        component = (labeled == i)
        area = component.sum()
        if area < min_area:
            continue
        
        # Get bounding box
        rows_with = np.any(component, axis=1)
        cols_with = np.any(component, axis=0)
        y_min, y_max = np.where(rows_with)[0][[0, -1]]
        x_min, x_max = np.where(cols_with)[0][[0, -1]]
        
        # Add padding
        y_min = max(0, y_min - padding)
        y_max = min(arr.shape[0], y_max + padding + 1)
        x_min = max(0, x_min - padding)
        x_max = min(arr.shape[1], x_max + padding + 1)
        
        # Crop using original image (not dilated)
        sprite = arr[y_min:y_max, x_min:x_max].copy()
        
        sprites.append((x_min, sprite))
    
    # Sort left to right
    sprites.sort(key=lambda s: s[0])
    
    saved = []
    for j, (x, sprite) in enumerate(sprites):
        h, w = sprite.shape[:2]
        out_path = os.path.join(output_dir, f"{name_prefix}_{j}.png")
        Image.fromarray(sprite).save(out_path)
        saved.append(out_path)
        print(f"    → {out_path} ({w}x{h})")
    
    return saved


if __name__ == "__main__":
    input_dir = sys.argv[1] if len(sys.argv) > 1 else "cow_rows"
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "cow_sprites_alpha"

    rows = ["idle", "walk", "happy", "sleep", "carried"]
    
    total = 0
    for row_name in rows:
        strip_path = os.path.join(input_dir, row_name, f"cow_{row_name}_strip.png")
        if not os.path.exists(strip_path):
            print(f"  Skipping {row_name}")
            continue
        out_folder = os.path.join(output_dir, row_name)
        os.makedirs(out_folder, exist_ok=True)
        saved = segment_by_alpha(strip_path, out_folder, f"cow_{row_name}")
        total += len(saved)
    
    print(f"\nDone! {total} sprites extracted to {output_dir}")
