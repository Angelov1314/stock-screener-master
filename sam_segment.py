#!/usr/bin/env python3
"""SAM segmentation for sprite strips"""
import os, sys, json, argparse
import numpy as np
from PIL import Image
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator

def segment_strip(mask_gen, strip_path, output_dir, anim_name, num_frames):
    """Segment a strip into individual frames."""
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
        masks = mask_gen.generate(img_rgb)
        
        if not masks:
            print(f"  No masks for frame {i}, saving as-is")
            frame.save(os.path.join(output_dir, f"{anim_name}_{i}.png"))
            continue
        
        # Find largest mask
        img_area = img_rgb.shape[0] * img_rgb.shape[1]
        good_masks = [m for m in masks if img_area * 0.05 < m["area"] < img_area * 0.95]
        if not good_masks:
            good_masks = sorted(masks, key=lambda m: m["area"], reverse=True)[:1]
        
        best = max(good_masks, key=lambda m: m["area"])
        mask = best["segmentation"]
        x, y, w, h = [int(v) for v in best["bbox"]]
        
        # Add padding
        pad = 10
        x0, y0 = max(0, x - pad), max(0, y - pad)
        x1 = min(frame.width, x + w + pad)
        y1 = min(frame.height, y + h + pad)
        
        # Apply mask
        img_array = np.array(frame.convert("RGBA"))
        cropped = img_array[y0:y1, x0:x1].copy()
        mask_crop = mask[y0:y1, x0:x1]
        cropped[~mask_crop, 3] = 0
        
        output_path = os.path.join(output_dir, f"{anim_name}_{i}.png")
        Image.fromarray(cropped).save(output_path)
        print(f"  Saved: {output_path} ({cropped.shape[1]}x{cropped.shape[0]})")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("strips_dir", help="Directory with strip images")
    parser.add_argument("strips_json", help='JSON like {"idle": ["file.png", 4]}')
    parser.add_argument("--checkpoint", default=os.path.expanduser("~/.cache/sam/sam_vit_h.pth"))
    args = parser.parse_args()
    
    print("Loading SAM...")
    sam = sam_model_registry["vit_h"](checkpoint=args.checkpoint)
    mask_gen = SamAutomaticMaskGenerator(sam, min_mask_region_area=300, 
                                         pred_iou_thresh=0.85, stability_score_thresh=0.90)
    print("SAM loaded!")
    
    strips_config = json.loads(args.strips_json)
    
    for anim_name, (strip_file, num_frames) in strips_config.items():
        strip_path = os.path.join(args.strips_dir, strip_file)
        output_dir = args.strips_dir
        segment_strip(mask_gen, strip_path, output_dir, anim_name, num_frames)
    
    print(f"\n✓ Stage 3 complete - SAM segmentation done")

if __name__ == "__main__":
    main()
