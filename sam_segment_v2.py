#!/usr/bin/env python3
"""Segment animal sprites - keep animal, remove green background"""
import os, sys, json, argparse
import numpy as np
from PIL import Image
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator

def segment_strip(mask_gen, strip_path, output_dir, anim_name, num_frames):
    """Segment a strip into individual frames, keeping the animal (not background)."""
    img = Image.open(strip_path)
    width, height = img.size
    frame_width = width // num_frames
    
    print(f"\nProcessing {anim_name}: {img.size}, frame_width={frame_width}")
    os.makedirs(output_dir, exist_ok=True)
    
    for i in range(num_frames):
        left = i * frame_width
        right = left + frame_width
        frame = img.crop((left, 0, right, height))
        
        # SAM segmentation
        img_rgb = np.array(frame.convert("RGB"))
        
        try:
            masks = mask_gen.generate(img_rgb)
        except Exception as e:
            print(f"  SAM error on frame {i}: {e}")
            frame.save(os.path.join(output_dir, f"{anim_name}_{i}.png"))
            continue
        
        if not masks:
            print(f"  No masks for frame {i}")
            frame.save(os.path.join(output_dir, f"{anim_name}_{i}.png"))
            continue
        
        # Find mask that covers the animal (not background)
        # Strategy: look for mask that's in the center and has reasonable size
        img_area = img_rgb.shape[0] * img_rgb.shape[1]
        
        # Filter masks by size (animal should be 15%-80% of image)
        valid_masks = [m for m in masks if img_area * 0.15 < m["area"] < img_area * 0.80]
        
        if not valid_masks:
            # Fallback: use largest mask
            valid_masks = sorted(masks, key=lambda m: m["area"], reverse=True)[:3]
        
        # Pick the mask closest to center (animal is usually centered)
        center_y, center_x = img_rgb.shape[0] // 2, img_rgb.shape[1] // 2
        best_mask = None
        best_score = float('inf')
        
        for m in valid_masks:
            # Calculate mask centroid
            y_indices, x_indices = np.where(m["segmentation"])
            if len(y_indices) == 0:
                continue
            cy = np.mean(y_indices)
            cx = np.mean(x_indices)
            # Distance to center
            dist = ((cy - center_y) ** 2 + (cx - center_x) ** 2) ** 0.5
            if dist < best_score:
                best_score = dist
                best_mask = m
        
        if best_mask is None:
            best_mask = max(valid_masks, key=lambda m: m["area"])
        
        mask = best_mask["segmentation"]
        bbox = best_mask["bbox"]
        x, y, w, h = [int(v) for v in bbox]
        
        # Add padding
        pad = 15
        x0 = max(0, x - pad)
        y0 = max(0, y - pad)
        x1 = min(frame.width, x + w + pad)
        y1 = min(frame.height, y + h + pad)
        
        # Apply mask
        img_array = np.array(frame.convert("RGBA"))
        cropped = img_array[y0:y1, x0:x1].copy()
        mask_crop = mask[y0:y1, x0:x1]
        
        # Make background transparent
        alpha = np.where(mask_crop, 255, 0).astype(np.uint8)
        cropped[:, :, 3] = alpha
        
        output_path = os.path.join(output_dir, f"{anim_name}_{i}.png")
        Image.fromarray(cropped).save(output_path)
        print(f"  Saved: {output_path} ({cropped.shape[1]}x{cropped.shape[0]}, area={best_mask['area']})")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("strips_dir", help="Directory with strip images")
    parser.add_argument("strips_json", help='JSON like {"idle": ["file.png", 4]}')
    parser.add_argument("--checkpoint", default=os.path.expanduser("~/.cache/sam/sam_vit_h.pth"))
    args = parser.parse_args()
    
    print("Loading SAM...")
    sam = sam_model_registry["vit_h"](checkpoint=args.checkpoint)
    mask_gen = SamAutomaticMaskGenerator(
        sam,
        points_per_side=32,
        pred_iou_thresh=0.9,
        stability_score_thresh=0.95,
        crop_n_layers=1,
        crop_n_points_downscale_factor=2,
        min_mask_region_area=500,
    )
    print("SAM loaded!")
    
    strips_config = json.loads(args.strips_json)
    
    for anim_name, (strip_file, num_frames) in strips_config.items():
        strip_path = os.path.join(args.strips_dir, strip_file)
        output_dir = args.strips_dir
        segment_strip(mask_gen, strip_path, output_dir, anim_name, num_frames)
    
    print(f"\n✓ Done!")

if __name__ == "__main__":
    main()
