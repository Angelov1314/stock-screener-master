#!/usr/bin/env python3
"""Convert checker-pattern background to true transparency, then segment sprites."""
import os
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

def detect_checker_bg(arr):
    """Detect the two checker colors from corners."""
    h, w = arr.shape[:2]
    # Sample corner pixels to determine checker colors
    corners = [arr[0,0], arr[0,1], arr[1,0], arr[1,1],
               arr[0,w-1], arr[0,w-2], arr[h-1,0], arr[h-1,w-1]]
    colors = set()
    for c in corners:
        colors.add(tuple(c[:3]))
    return colors

def is_checker_color(pixel, checker_colors, tolerance=15):
    """Check if pixel matches any checker background color."""
    for cc in checker_colors:
        if all(abs(int(pixel[i]) - int(cc[i])) < tolerance for i in range(3)):
            return True
    return False

def remove_checker_bg(image_path):
    """Remove checker background and return RGBA image."""
    img = Image.open(image_path).convert("RGB")
    arr = np.array(img)
    h, w, _ = arr.shape
    
    # Detect checker colors
    checker_colors = detect_checker_bg(arr)
    print(f"  Detected checker colors: {checker_colors}")
    
    # Create alpha mask - vectorized approach
    rgba = np.dstack([arr, np.full((h, w), 255, dtype=np.uint8)])
    
    for cc in checker_colors:
        cc_arr = np.array(cc, dtype=np.int16)
        diff = np.abs(arr.astype(np.int16) - cc_arr)
        mask = np.all(diff < 15, axis=2)
        rgba[mask, 3] = 0
    
    return Image.fromarray(rgba)

def segment_sprites(rgba_img, output_dir, name_prefix, min_area=3000, padding=8):
    """Segment individual sprites using alpha-based connected components."""
    arr = np.array(rgba_img)
    alpha = arr[:, :, 3]
    binary = (alpha > 0).astype(np.uint8)
    
    # Dilate to connect nearby pixels
    struct = ndimage.generate_binary_structure(2, 2)
    dilated = ndimage.binary_dilation(binary, struct, iterations=5)
    
    labeled, num_features = ndimage.label(dilated)
    
    sprites = []
    for i in range(1, num_features + 1):
        component = (labeled == i)
        area = component.sum()
        if area < min_area:
            continue
        
        rows_with = np.any(component, axis=1)
        cols_with = np.any(component, axis=0)
        y_min, y_max = np.where(rows_with)[0][[0, -1]]
        x_min, x_max = np.where(cols_with)[0][[0, -1]]
        
        y_min = max(0, y_min - padding)
        y_max = min(arr.shape[0], y_max + padding + 1)
        x_min = max(0, x_min - padding)
        x_max = min(arr.shape[1], x_max + padding + 1)
        
        sprite = arr[y_min:y_max, x_min:x_max].copy()
        sprites.append((x_min, sprite))
    
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
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "cow_final"

    rows = ["idle", "walk", "happy", "sleep", "carried"]
    
    total = 0
    for row_name in rows:
        strip_path = os.path.join(input_dir, row_name, f"cow_{row_name}_strip.png")
        if not os.path.exists(strip_path):
            print(f"  Skipping {row_name}")
            continue
        
        print(f"\nProcessing {row_name}...")
        rgba = remove_checker_bg(strip_path)
        
        out_folder = os.path.join(output_dir, row_name)
        os.makedirs(out_folder, exist_ok=True)
        saved = segment_sprites(rgba, out_folder, f"cow_{row_name}")
        total += len(saved)
    
    print(f"\nDone! {total} sprites extracted to {output_dir}")
