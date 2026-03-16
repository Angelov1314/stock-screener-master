#!/usr/bin/env python3
"""
Extract individual buttons from a button spritesheet row using SAM.
Each row contains multiple buttons arranged horizontally.
"""
import os, sys, json, argparse
import numpy as np
from PIL import Image
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator

def detect_button_boundaries(img_row, num_expected=None):
    """Detect button boundaries by analyzing horizontal spacing/edges."""
    width, height = img_row.size
    img_gray = img_row.convert('L')
    pixels = np.array(img_gray)
    
    # Calculate vertical projection (average brightness per column)
    projection = np.mean(pixels, axis=0)
    
    # Find gaps (low brightness regions that separate buttons)
    threshold = np.mean(projection) * 0.8
    gaps = projection < threshold
    
    # Find gap boundaries
    boundaries = []
    in_gap = False
    gap_start = 0
    
    for i, is_gap in enumerate(gaps):
        if is_gap and not in_gap:
            gap_start = i
            in_gap = True
        elif not is_gap and in_gap:
            # End of gap
            if i - gap_start > 10:  # Gap must be at least 10px wide
                boundaries.append((gap_start, i))
            in_gap = False
    
    # Convert gaps to button boundaries
    button_bounds = []
    prev_end = 0
    for gap_start, gap_end in boundaries:
        if gap_start - prev_end > 30:  # Button must be at least 30px wide
            button_bounds.append((prev_end, gap_start))
        prev_end = gap_end
    
    # Add last button
    if width - prev_end > 30:
        button_bounds.append((prev_end, width))
    
    return button_bounds

def segment_button(mask_generator, button_img, output_path):
    """Segment a single button and save with transparent background."""
    img_rgb = np.array(button_img.convert("RGB"))
    
    try:
        masks = mask_generator.generate(img_rgb)
    except Exception as e:
        print(f"  SAM error: {e}")
        # Fallback: save as-is
        button_img.save(output_path)
        return
    
    if not masks:
        print(f"  No masks found")
        button_img.save(output_path)
        return
    
    # Find the largest reasonable mask
    img_area = img_rgb.shape[0] * img_rgb.shape[1]
    min_area = img_area * 0.05
    max_area = img_area * 0.98
    
    good_masks = [m for m in masks if min_area < m["area"] < max_area]
    if not good_masks:
        good_masks = sorted(masks, key=lambda m: m["area"], reverse=True)[:1]
    
    best_mask = max(good_masks, key=lambda m: m["area"])
    mask = best_mask["segmentation"]
    bbox = best_mask["bbox"]
    x, y, w, h = [int(v) for v in bbox]
    
    # Add padding
    pad = 8
    x0 = max(0, x - pad)
    y0 = max(0, y - pad)
    x1 = min(button_img.width, x + w + pad)
    y1 = min(button_img.height, y + h + pad)
    
    img_array = np.array(button_img.convert("RGBA"))
    cropped = img_array[y0:y1, x0:x1].copy()
    mask_crop = mask[y0:y1, x0:x1]
    cropped[~mask_crop, 3] = 0  # Transparent background
    
    Image.fromarray(cropped).save(output_path)
    print(f"  Saved: {output_path} ({cropped.shape[1]}x{cropped.shape[0]})")

def process_row(mask_generator, row_path, output_dir, row_name):
    """Process one row of buttons."""
    img = Image.open(row_path)
    print(f"\nProcessing {row_name}: {img.size}")
    
    # Detect button boundaries
    bounds = detect_button_boundaries(img)
    print(f"  Detected {len(bounds)} buttons")
    
    # Create output directory
    row_output_dir = os.path.join(output_dir, row_name)
    os.makedirs(row_output_dir, exist_ok=True)
    
    # Process each button
    for i, (start, end) in enumerate(bounds):
        button_crop = img.crop((start, 0, end, img.height))
        output_path = os.path.join(row_output_dir, f"{row_name}_{i}.png")
        segment_button(mask_generator, button_crop, output_path)

def main():
    parser = argparse.ArgumentParser(description="Extract buttons from spritesheet rows")
    parser.add_argument("input_dir", help="Directory containing row images")
    parser.add_argument("--output-dir", default="./buttons_extracted", help="Output directory")
    parser.add_argument("--checkpoint", default=os.path.expanduser("~/.cache/sam/sam_vit_h.pth"))
    args = parser.parse_args()
    
    # Load SAM model
    print("Loading SAM model...")
    if not os.path.exists(args.checkpoint):
        print(f"ERROR: SAM checkpoint not found: {args.checkpoint}")
        print("Please download it from: https://github.com/facebookresearch/segment-anything#model-checkpoints")
        sys.exit(1)
    
    sam = sam_model_registry["vit_h"](checkpoint=args.checkpoint)
    mask_generator = SamAutomaticMaskGenerator(
        sam,
        min_mask_region_area=300,
        pred_iou_thresh=0.85,
        stability_score_thresh=0.90,
    )
    print("SAM loaded!")
    
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Process each row image
    row_files = sorted([f for f in os.listdir(args.input_dir) if f.endswith('.png')])
    print(f"\nFound {len(row_files)} rows to process")
    
    for row_file in row_files:
        row_path = os.path.join(args.input_dir, row_file)
        row_name = os.path.splitext(row_file)[0]
        process_row(mask_generator, row_path, args.output_dir, row_name)
    
    print(f"\n✓ Done! Extracted buttons to: {args.output_dir}")

if __name__ == "__main__":
    main()
