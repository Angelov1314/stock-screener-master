#!/usr/bin/env python3
"""
Extract buttons using simple image processing (no SAM).
Uses connected component analysis to find button boundaries.
"""
import os
import numpy as np
from PIL import Image

def extract_buttons_simple(row_path, output_dir, row_name):
    """Extract buttons using alpha channel or brightness thresholding."""
    img = Image.open(row_path).convert("RGBA")
    width, height = img.size
    
    # Convert to array
    arr = np.array(img)
    
    # Create mask: non-transparent or non-white pixels
    alpha = arr[:, :, 3]
    mask = (alpha > 10).astype(np.uint8)  # Non-transparent
    
    # Find connected components horizontally
    # Look for vertical gaps between buttons
    vertical_projection = np.sum(mask, axis=0)
    threshold = np.max(vertical_projection) * 0.1
    gaps = vertical_projection < threshold
    
    # Find gap boundaries
    boundaries = []
    in_gap = False
    gap_start = 0
    
    for i, is_gap in enumerate(gaps):
        if is_gap and not in_gap:
            gap_start = i
            in_gap = True
        elif not is_gap and in_gap:
            if i - gap_start > 20:  # Significant gap
                boundaries.append((gap_start, i))
            in_gap = False
    
    # Add start and end
    all_boundaries = [0] + [b[0] for b in boundaries] + [b[1] for b in boundaries] + [width]
    all_boundaries = sorted(set(all_boundaries))
    
    # Extract buttons
    os.makedirs(output_dir, exist_ok=True)
    count = 0
    
    for i in range(len(all_boundaries) - 1):
        left, right = all_boundaries[i], all_boundaries[i + 1]
        if right - left < 50:  # Skip very small segments
            continue
        
        # Crop with some padding
        pad = 5
        left_pad = max(0, left - pad)
        right_pad = min(width, right + pad)
        
        button = img.crop((left_pad, 0, right_pad, height))
        
        # Check if there's actual content
        btn_arr = np.array(button)
        if np.sum(btn_arr[:, :, 3] > 0) < 100:  # Too transparent
            continue
        
        output_path = os.path.join(output_dir, f"{row_name}_{count}.png")
        button.save(output_path)
        print(f"  Saved: {output_path}")
        count += 1
    
    return count

def main():
    input_dir = "assets/ui/buttons_output"
    output_dir = "assets/ui/buttons_extracted"
    
    row_files = sorted([f for f in os.listdir(input_dir) if f.endswith('.png')])
    print(f"Processing {len(row_files)} rows...")
    
    for row_file in row_files:
        row_path = os.path.join(input_dir, row_file)
        row_name = os.path.splitext(row_file)[0]
        
        # Skip if already processed
        row_output = os.path.join(output_dir, row_name)
        if os.path.exists(row_output) and len(os.listdir(row_output)) > 0:
            print(f"Skipping {row_name} (already done)")
            continue
        
        print(f"\nProcessing {row_name}...")
        count = extract_buttons_simple(row_path, row_output, row_name)
        print(f"  Extracted {count} buttons")
    
    print(f"\n✓ Done! Check: {output_dir}")

if __name__ == "__main__":
    main()
