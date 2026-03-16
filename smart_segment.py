#!/usr/bin/env python3
"""Segment sprites by detecting vertical gaps (background-only columns)."""
import os
import sys
import numpy as np
from PIL import Image

def is_background_pixel(rgb, threshold=30):
    """Check if pixel is close to white/light gray (background)."""
    r, g, b = int(rgb[0]), int(rgb[1]), int(rgb[2])
    # Background is white-ish or light gray checker pattern
    return min(r, g, b) > 200

def find_sprites_in_row(image_path, output_dir, name_prefix, min_width=50, gap_threshold=0.90):
    """Find sprites by looking for vertical columns that are mostly background."""
    img = Image.open(image_path).convert("RGB")
    arr = np.array(img)
    h, w, _ = arr.shape
    
    # For each column, calculate fraction of background pixels
    bg_fraction = np.zeros(w)
    for x in range(w):
        col = arr[:, x, :]
        bg_count = sum(1 for y in range(h) if min(col[y]) > 200)
        bg_fraction[x] = bg_count / h
    
    # Find sprite regions (columns where bg_fraction < threshold)
    is_sprite = bg_fraction < gap_threshold
    
    # Find contiguous sprite regions
    regions = []
    in_region = False
    start = 0
    for x in range(w):
        if is_sprite[x] and not in_region:
            start = x
            in_region = True
        elif not is_sprite[x] and in_region:
            if x - start >= min_width:
                regions.append((start, x))
            in_region = False
    if in_region and w - start >= min_width:
        regions.append((start, w))
    
    print(f"  Found {len(regions)} sprites in {os.path.basename(image_path)}")
    
    # Extract and save
    saved = []
    padding = 5
    for j, (x_start, x_end) in enumerate(regions):
        x_s = max(0, x_start - padding)
        x_e = min(w, x_end + padding)
        
        # Also trim top/bottom
        crop = arr[:, x_s:x_e, :]
        row_has_content = np.array([not all(min(crop[y, x]) > 200 for x in range(crop.shape[1])) for y in range(h)])
        
        if not row_has_content.any():
            continue
            
        y_min = np.where(row_has_content)[0][0]
        y_max = np.where(row_has_content)[0][-1] + 1
        y_min = max(0, y_min - padding)
        y_max = min(h, y_max + padding)
        
        sprite = arr[y_min:y_max, x_s:x_e]
        
        # Make background transparent
        sprite_rgba = np.dstack([sprite, np.full(sprite.shape[:2], 255, dtype=np.uint8)])
        for y in range(sprite_rgba.shape[0]):
            for x in range(sprite_rgba.shape[1]):
                if min(sprite_rgba[y, x, :3]) > 215:
                    sprite_rgba[y, x, 3] = 0
        
        out_path = os.path.join(output_dir, f"{name_prefix}_{j}.png")
        Image.fromarray(sprite_rgba).save(out_path)
        sw, sh = sprite_rgba.shape[1], sprite_rgba.shape[0]
        saved.append(out_path)
        print(f"    → {out_path} ({sw}x{sh})")
    
    return saved


if __name__ == "__main__":
    input_dir = sys.argv[1] if len(sys.argv) > 1 else "cow_rows"
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "cow_sprites_final"

    rows = ["idle", "walk", "happy", "sleep", "carried"]
    
    total = 0
    for row_name in rows:
        strip_path = os.path.join(input_dir, row_name, f"cow_{row_name}_strip.png")
        if not os.path.exists(strip_path):
            print(f"  Skipping {row_name}")
            continue
        out_folder = os.path.join(output_dir, row_name)
        os.makedirs(out_folder, exist_ok=True)
        saved = find_sprites_in_row(strip_path, out_folder, f"cow_{row_name}")
        total += len(saved)
    
    print(f"\nDone! {total} sprites extracted to {output_dir}")
