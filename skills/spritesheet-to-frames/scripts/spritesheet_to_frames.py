#!/usr/bin/env python3
"""
Spritesheet to Frames - One-shot pipeline
Input: Full spritesheet image
Output: 5 folders (idle, walk, happy, sleep, carried) with transparent frames
"""
import os
import sys
import json
import argparse
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image

def main():
    parser = argparse.ArgumentParser(
        description="Convert spritesheet to 5 animation folders with transparent frames"
    )
    parser.add_argument("input_image", help="Path to spritesheet image")
    parser.add_argument("-o", "--output", default="./output", help="Output directory")
    parser.add_argument("--names", default="idle,walk,happy,sleep,carried",
                        help="Animation names (comma-separated)")
    parser.add_argument("--frames", default="4,4,4,2,2",
                        help="Frame counts (comma-separated)")
    parser.add_argument("--no-sam", action="store_true",
                        help="Skip SAM segmentation (just crop to strips)")
    parser.add_argument("--sam-checkpoint",
                        default=os.path.expanduser("~/.cache/sam/sam_vit_h.pth"),
                        help="SAM model checkpoint path")
    args = parser.parse_args()
    
    # Parse config
    names = args.names.split(",")
    frames = [int(f) for f in args.frames.split(",")]
    
    if len(names) != len(frames):
        print("Error: names and frames must have same count")
        sys.exit(1)
    
    input_path = Path(args.input_image)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print("=" * 60)
    print("SPRITESHEET TO FRAMES - One Shot Pipeline")
    print("=" * 60)
    print(f"Input: {input_path}")
    print(f"Output: {output_dir}")
    print(f"Animations: {list(zip(names, frames))}")
    print()
    
    # Stage 1: Detect rows (auto-estimate for now)
    print("[Stage 1] Detecting row positions...")
    img = Image.open(input_path)
    width, height = img.size
    num_rows = len(names)
    row_height = height // num_rows
    
    rows_config = {}
    for i, (name, frame_count) in enumerate(zip(names, frames)):
        top = i * row_height
        bottom = (i + 1) * row_height if i < num_rows - 1 else height
        rows_config[name] = [0, top, width, bottom]
        print(f"  {name}: [0, {top}, {width}, {bottom}] ({frame_count} frames)")
    
    # Stage 2: Crop to strips
    print("\n[Stage 2] Cropping to strips...")
    strips_dir = output_dir / "_strips"
    strips_dir.mkdir(exist_ok=True)
    
    for name, coords in rows_config.items():
        strip_img = img.crop(coords)
        strip_path = strips_dir / f"{name}.png"
        strip_img.save(strip_path)
        print(f"  Saved: {strip_path}")
    
    # Stage 3: Segment with SAM (or simple split)
    if args.no_sam:
        print("\n[Stage 3] Splitting frames (no SAM)...")
        _simple_split(strips_dir, names, frames)
    else:
        print("\n[Stage 3] Segmenting with SAM...")
        _sam_segment(strips_dir, names, frames, args.sam_checkpoint)
    
    # Stage 4: Organize final output
    print("\n[Stage 4] Organizing output...")
    for name in names:
        # Find the output folder (SAM creates subfolders)
        src_folder = strips_dir / name
        if not src_folder.exists():
            # Try alternative naming
            for folder in strips_dir.iterdir():
                if folder.is_dir() and name in folder.name.lower():
                    src_folder = folder
                    break
        
        dst_folder = output_dir / name
        dst_folder.mkdir(exist_ok=True)
        
        if src_folder.exists():
            # Move PNG files
            for png_file in src_folder.glob("*.png"):
                dst_file = dst_folder / png_file.name
                png_file.rename(dst_file)
            print(f"  {name}/: {len(list(dst_folder.glob('*.png')))} frames")
    
    # Cleanup
    import shutil
    if strips_dir.exists():
        shutil.rmtree(strips_dir)
    
    print("\n" + "=" * 60)
    print("✓ DONE!")
    print(f"Output: {output_dir}")
    for name in names:
        frame_count = len(list((output_dir / name).glob("*.png")))
        print(f"  {name}/: {frame_count} frames")
    print("=" * 60)

def _simple_split(strips_dir, names, frames):
    """Simple frame splitting without SAM"""
    for name, frame_count in zip(names, frames):
        strip_path = strips_dir / f"{name}.png"
        if not strip_path.exists():
            continue
        
        img = Image.open(strip_path)
        width, height = img.size
        frame_width = width // frame_count
        
        output_folder = strips_dir / name
        output_folder.mkdir(exist_ok=True)
        
        for i in range(frame_count):
            left = i * frame_width
            right = left + frame_width
            frame = img.crop((left, 0, right, height))
            
            # Convert to RGBA
            frame = frame.convert("RGBA")
            frame.save(output_folder / f"{name}_{i}.png")
        
        print(f"  {name}: {frame_count} frames (simple split)")

def _sam_segment(strips_dir, names, frames, checkpoint):
    """Segment using SAM"""
    try:
        from segment_anything import sam_model_registry, SamAutomaticMaskGenerator
    except ImportError:
        print("  Warning: segment-anything not installed, falling back to simple split")
        _simple_split(strips_dir, names, frames)
        return
    
    # Load SAM
    print("  Loading SAM model...")
    if not os.path.exists(checkpoint):
        print(f"  SAM checkpoint not found: {checkpoint}")
        print("  Falling back to simple split")
        _simple_split(strips_dir, names, frames)
        return
    
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
    
    for name, frame_count in zip(names, frames):
        strip_path = strips_dir / f"{name}.png"
        if not strip_path.exists():
            continue
        
        img = Image.open(strip_path)
        width, height = img.size
        frame_width = width // frame_count
        
        output_folder = strips_dir / name
        output_folder.mkdir(exist_ok=True)
        
        for i in range(frame_count):
            left = i * frame_width
            right = left + frame_width
            frame = img.crop((left, 0, right, height))
            
            # SAM segmentation
            img_rgb = np.array(frame.convert("RGB"))
            try:
                masks = mask_gen.generate(img_rgb)
            except Exception as e:
                print(f"    SAM error on {name}_{i}: {e}")
                frame.save(output_folder / f"{name}_{i}.png")
                continue
            
            if not masks:
                frame.save(output_folder / f"{name}_{i}.png")
                continue
            
            # Find best mask (centered, medium size)
            img_area = img_rgb.shape[0] * img_rgb.shape[1]
            valid_masks = [m for m in masks if img_area * 0.15 < m["area"] < img_area * 0.80]
            
            if not valid_masks:
                valid_masks = sorted(masks, key=lambda m: m["area"], reverse=True)[:3]
            
            # Pick closest to center
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
            
            # Apply mask
            mask = best_mask["segmentation"]
            bbox = best_mask["bbox"]
            x, y, w, h = [int(v) for v in bbox]
            
            # Add padding
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
            
            Image.fromarray(cropped).save(output_folder / f"{name}_{i}.png")
        
        print(f"  {name}: {frame_count} frames (SAM segmented)")

if __name__ == "__main__":
    main()
