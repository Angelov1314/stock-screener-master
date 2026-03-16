#!/usr/bin/env python3
"""
Segment animal animation strips into individual frames using SAM.
"""
import os, sys
import numpy as np
from PIL import Image
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator

def segment_strip(mask_generator, strip_path, output_dir, anim_name, num_frames=4):
    """Segment a strip into individual frames."""
    img = Image.open(strip_path)
    width, height = img.size
    
    # Calculate frame width
    frame_width = width // num_frames
    
    print(f"\nProcessing {anim_name}: {img.size}, frame_width={frame_width}")
    
    os.makedirs(output_dir, exist_ok=True)
    
    for i in range(num_frames):
        # Crop frame
        left = i * frame_width
        right = left + frame_width
        frame = img.crop((left, 0, right, height))
        
        # Segment with SAM
        img_rgb = np.array(frame.convert("RGB"))
        
        try:
            masks = mask_generator.generate(img_rgb)
        except Exception as e:
            print(f"  SAM error on frame {i}: {e}")
            # Save as-is
            output_path = os.path.join(output_dir, f"{anim_name}_{i}.png")
            frame.save(output_path)
            continue
        
        if not masks:
            print(f"  No masks for frame {i}")
            output_path = os.path.join(output_dir, f"{anim_name}_{i}.png")
            frame.save(output_path)
            continue
        
        # Find largest mask
        img_area = img_rgb.shape[0] * img_rgb.shape[1]
        min_area = img_area * 0.1
        max_area = img_area * 0.95
        
        good_masks = [m for m in masks if min_area < m["area"] < max_area]
        if not good_masks:
            good_masks = sorted(masks, key=lambda m: m["area"], reverse=True)[:1]
        
        best_mask = max(good_masks, key=lambda m: m["area"])
        mask = best_mask["segmentation"]
        bbox = best_mask["bbox"]
        x, y, w, h = [int(v) for v in bbox]
        
        # Add padding
        pad = 10
        x0 = max(0, x - pad)
        y0 = max(0, y - pad)
        x1 = min(frame.width, x + w + pad)
        y1 = min(frame.height, y + h + pad)
        
        # Apply mask
        img_array = np.array(frame.convert("RGBA"))
        cropped = img_array[y0:y1, x0:x1].copy()
        mask_crop = mask[y0:y1, x0:x1]
        cropped[~mask_crop, 3] = 0  # Transparent background
        
        output_path = os.path.join(output_dir, f"{anim_name}_{i}.png")
        Image.fromarray(cropped).save(output_path)
        print(f"  Saved: {output_path} ({cropped.shape[1]}x{cropped.shape[0]})")

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dir", help="Directory with strip images")
    parser.add_argument("--checkpoint", default=os.path.expanduser("~/.cache/sam/sam_vit_h.pth"))
    args = parser.parse_args()
    
    print("Loading SAM...")
    sam = sam_model_registry["vit_h"](checkpoint=args.checkpoint)
    mask_generator = SamAutomaticMaskGenerator(
        sam,
        min_mask_region_area=300,
        pred_iou_thresh=0.85,
        stability_score_thresh=0.90,
    )
    print("SAM loaded!")
    
    # Process all strips in directory
    strip_files = sorted([f for f in os.listdir(args.input_dir) if f.endswith('_strip.png')])
    
    for strip_file in strip_files:
        strip_path = os.path.join(args.input_dir, strip_file)
        anim_name = os.path.splitext(strip_file)[0].replace('_strip', '')
        output_dir = args.input_dir  # Save frames in same directory
        segment_strip(mask_generator, strip_path, output_dir, anim_name, 4)
    
    print(f"\n✓ Done! Frames saved to: {args.input_dir}")

if __name__ == "__main__":
    main()
