#!/usr/bin/env python3
"""
Extract UI buttons from a mobile app mockup using SAM.
First crops button regions, then segments each button with transparent background.
"""
import os, sys, json, argparse
import numpy as np
from PIL import Image
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator

def segment_button(mask_generator, button_path, output_path):
    """Segment a single button image and save with transparent background."""
    img = Image.open(button_path).convert("RGBA")
    img_rgb = np.array(img.convert("RGB"))
    
    masks = mask_generator.generate(img_rgb)
    
    # Find the largest mask (should be the button)
    if not masks:
        print(f"  No masks found for {button_path}")
        return
    
    # Sort by area, pick the largest reasonable mask
    img_area = img_rgb.shape[0] * img_rgb.shape[1]
    min_area = img_area * 0.1  # Button should be at least 10% of image
    max_area = img_area * 0.95  # But not more than 95%
    
    good_masks = [m for m in masks if min_area < m["area"] < max_area]
    if not good_masks:
        # Fallback: just use the largest mask
        good_masks = sorted(masks, key=lambda m: m["area"], reverse=True)[:1]
    
    # Pick the largest mask
    best_mask = max(good_masks, key=lambda m: m["area"])
    mask = best_mask["segmentation"]
    bbox = best_mask["bbox"]
    x, y, w, h = [int(v) for v in bbox]
    
    # Add padding
    pad = 10
    x0 = max(0, x - pad)
    y0 = max(0, y - pad)
    x1 = min(img.width, x + w + pad)
    y1 = min(img.height, y + h + pad)
    
    img_array = np.array(img)
    cropped = img_array[y0:y1, x0:x1].copy()
    mask_crop = mask[y0:y1, x0:x1]
    cropped[~mask_crop, 3] = 0  # Make background transparent
    
    Image.fromarray(cropped).save(output_path)
    print(f"  Saved: {output_path} ({cropped.shape[1]}x{cropped.shape[0]})")

def main():
    parser = argparse.ArgumentParser(description="Extract UI buttons using SAM")
    parser.add_argument("input_image", help="Input UI mockup image")
    parser.add_argument("--output-dir", default="./ui_buttons_output", help="Output directory")
    parser.add_argument("--checkpoint", default=os.path.expanduser("~/.cache/sam/sam_vit_h.pth"))
    args = parser.parse_args()
    
    img = Image.open(args.input_image)
    print(f"Image size: {img.size}")
    
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Define button regions (left, top, right, bottom)
    # Based on 1490x2848 image dimensions
    buttons = {
        "start_bot": [94, 625, 1396, 805],      # 绿色 Start Bot
        "wallet": [94, 835, 1396, 1015],        # 蓝色 Wallet
        "invite_friends": [94, 1045, 1396, 1225], # 橙色 Invite Friends
        "tasks": [94, 1255, 1396, 1435],        # 紫色 Tasks
        "upgrade": [94, 1465, 1396, 1645],      # 黄色 Upgrade
        "settings": [94, 1675, 1396, 1855],     # 深灰 Settings
    }
    
    # First, crop each button region
    cropped_paths = []
    for name, coords in buttons.items():
        left, top, right, bottom = coords
        cropped = img.crop((left, top, right, bottom))
        crop_path = os.path.join(args.output_dir, f"{name}_crop.png")
        cropped.save(crop_path)
        cropped_paths.append((name, crop_path))
        print(f"Cropped {name}: {coords}")
    
    # Load SAM model
    print("\nLoading SAM model...")
    sam = sam_model_registry["vit_h"](checkpoint=args.checkpoint)
    mask_generator = SamAutomaticMaskGenerator(
        sam,
        min_mask_region_area=500,
        pred_iou_thresh=0.86,
        stability_score_thresh=0.92,
    )
    
    # Segment each button
    print("\nSegmenting buttons with SAM...")
    for name, crop_path in cropped_paths:
        output_path = os.path.join(args.output_dir, f"{name}.png")
        segment_button(mask_generator, crop_path, output_path)
    
    # Clean up intermediate crops
    for name, crop_path in cropped_paths:
        os.remove(crop_path)
    
    print(f"\nDone! Extracted buttons to: {args.output_dir}")

if __name__ == "__main__":
    main()
