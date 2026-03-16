#!/usr/bin/env python3
"""
Quick SAM processor - Process one animation strip at a time with progress
"""
import os
import sys
import json
import argparse
from pathlib import Path
import numpy as np
from PIL import Image

def process_strip_with_sam(strip_path, output_dir, name, num_frames, checkpoint):
    """Process a single strip with SAM"""
    from segment_anything import sam_model_registry, SamAutomaticMaskGenerator
    
    print(f"\n  Loading SAM model...")
    sam = sam_model_registry["vit_h"](checkpoint=checkpoint)
    mask_gen = SamAutomaticMaskGenerator(
        sam,
        points_per_side=32,
        pred_iou_thresh=0.9,
        stability_score_thresh=0.95,
        crop_n_layers=1,
        crop_n_points_downscale_factor=2,
        min_mask_region_area=500,
    )
    
    print(f"  Processing {name} ({num_frames} frames)...")
    img = Image.open(strip_path)
    width, height = img.size
    frame_width = width // num_frames
    
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    for i in range(num_frames):
        print(f"    Frame {i+1}/{num_frames}...", end=" ")
        left = i * frame_width
        right = left + frame_width
        frame = img.crop((left, 0, right, height))
        
        img_rgb = np.array(frame.convert("RGB"))
        
        try:
            masks = mask_gen.generate(img_rgb)
        except Exception as e:
            print(f"SAM error: {e}")
            frame.save(output_dir / f"{name}_{i}.png")
            continue
        
        if not masks:
            print("No masks")
            frame.save(output_dir / f"{name}_{i}.png")
            continue
        
        # Find best mask
        img_area = img_rgb.shape[0] * img_rgb.shape[1]
        valid_masks = [m for m in masks if img_area * 0.15 < m["area"] < img_area * 0.80]
        if not valid_masks:
            valid_masks = sorted(masks, key=lambda m: m["area"], reverse=True)[:3]
        
        center_y, center_x = img_rgb.shape[0] // 2, img_rgb.shape[1] // 2
        best_mask = None
        best_score = float('inf')
        
        for m in valid_masks:
            y_indices, x_indices = np.where(m["segmentation"])
            if len(y_indices) == 0:
                continue
            cy = np.mean(y_indices)
            cx = np.mean(x_indices)
            dist = ((cy - center_y) ** 2 + (cx - center_x) ** 2) ** 0.5
            if dist < best_score:
                best_score = dist
                best_mask = m
        
        if best_mask is None:
            best_mask = max(valid_masks, key=lambda m: m["area"])
        
        mask = best_mask["segmentation"]
        bbox = best_mask["bbox"]
        x, y, w, h = [int(v) for v in bbox]
        
        pad = 15
        x0 = max(0, x - pad)
        y0 = max(0, y - pad)
        x1 = min(frame.width, x + w + pad)
        y1 = min(frame.height, y + h + pad)
        
        img_array = np.array(frame.convert("RGBA"))
        cropped = img_array[y0:y1, x0:x1].copy()
        mask_crop = mask[y0:y1, x0:x1]
        
        alpha = np.where(mask_crop, 255, 0).astype(np.uint8)
        cropped[:, :, 3] = alpha
        
        Image.fromarray(cropped).save(output_dir / f"{name}_{i}.png")
        print(f"✓ ({best_mask['area']} px)")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input_image", help="Spritesheet image")
    parser.add_argument("-o", "--output", default="./output", help="Output directory")
    parser.add_argument("--checkpoint", default=os.path.expanduser("~/.cache/sam/sam_vit_h.pth"))
    args = parser.parse_args()
    
    input_path = Path(args.input_image)
    output_dir = Path(args.output)
    
    print("=" * 60)
    print("SAM SPRITESHEET PROCESSOR")
    print("=" * 60)
    print(f"Input: {input_path}")
    print(f"Output: {output_dir}")
    
    # Detect rows
    print("\n[1/5] Detecting rows...")
    img = Image.open(input_path)
    width, height = img.size
    num_rows = 5
    row_height = height // num_rows
    
    names = ["idle", "walk", "happy", "sleep", "carried"]
    frames = [4, 4, 4, 2, 2]
    
    strips_dir = output_dir / "_strips"
    strips_dir.mkdir(parents=True, exist_ok=True)
    
    # Crop strips
    print("\n[2/5] Cropping to strips...")
    for i, (name, frame_count) in enumerate(zip(names, frames)):
        top = i * row_height
        bottom = (i + 1) * row_height if i < num_rows - 1 else height
        strip = img.crop((0, top, width, bottom))
        strip.save(strips_dir / f"{name}.png")
        print(f"  {name}: {width}x{bottom-top} ({frame_count} frames)")
    
    # Process each strip with SAM
    print("\n[3-7/5] Processing with SAM (one at a time)...")
    for name, frame_count in zip(names, frames):
        strip_path = strips_dir / f"{name}.png"
        out_dir = output_dir / name
        process_strip_with_sam(strip_path, out_dir, name, frame_count, args.checkpoint)
    
    # Cleanup
    import shutil
    if strips_dir.exists():
        shutil.rmtree(strips_dir)
    
    print("\n" + "=" * 60)
    print("✓ DONE!")
    for name in names:
        frame_count = len(list((output_dir / name).glob("*.png")))
        print(f"  {name}/: {frame_count} frames")
    print("=" * 60)

if __name__ == "__main__":
    main()
