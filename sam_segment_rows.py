#!/usr/bin/env python3
"""Step 2: Use SAM to segment individual sprites from row strips."""
import os
import sys
import numpy as np
from PIL import Image
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator

SAM_CHECKPOINT = os.path.expanduser("~/.cache/sam/sam_vit_h.pth")
MODEL_TYPE = "vit_h"
DEVICE = "cpu"  # MPS doesn't support float64, fallback to CPU

def segment_row(image_path, output_dir, name_prefix, min_area=500):
    """Segment sprites from a row strip using SAM."""
    img = Image.open(image_path).convert("RGBA")
    img_rgb = np.array(img.convert("RGB"))

    # Generate masks
    sam = sam_model_registry[MODEL_TYPE](checkpoint=SAM_CHECKPOINT)
    sam.to(DEVICE)
    mask_gen = SamAutomaticMaskGenerator(
        sam,
        min_mask_region_area=min_area,
        pred_iou_thresh=0.86,
        stability_score_thresh=0.92,
    )
    masks = mask_gen.generate(img_rgb)
    print(f"  Found {len(masks)} masks in {image_path}")

    # Sort masks left-to-right by bbox x position
    masks.sort(key=lambda m: m['bbox'][0])

    # Filter: keep only reasonably sized masks (likely individual sprites)
    img_area = img_rgb.shape[0] * img_rgb.shape[1]
    filtered = []
    for m in masks:
        area_ratio = m['area'] / img_area
        # Keep masks that are roughly sprite-sized (1% - 40% of image)
        if 0.01 < area_ratio < 0.40:
            filtered.append(m)

    print(f"  Filtered to {len(filtered)} sprite candidates")

    # Extract each sprite with tight bounding box
    img_rgba = np.array(img)
    saved = []
    for i, m in enumerate(filtered):
        mask = m['segmentation']
        x, y, w, h = m['bbox']

        # Create RGBA sprite with mask as alpha
        sprite = img_rgba[y:y+h, x:x+w].copy()
        mask_crop = mask[y:y+h, x:x+w]

        # Apply mask to alpha channel
        sprite[:, :, 3] = sprite[:, :, 3] * mask_crop.astype(np.uint8)

        out_path = os.path.join(output_dir, f"{name_prefix}_{i}.png")
        Image.fromarray(sprite).save(out_path)
        saved.append(out_path)
        print(f"    → {out_path} ({w}x{h})")

    return saved


if __name__ == "__main__":
    input_dir = sys.argv[1] if len(sys.argv) > 1 else "cow_rows"
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "cow_sprites"

    rows = ["idle", "walk", "happy", "sleep", "carried"]

    print("Loading SAM model...")
    total = 0
    for row_name in rows:
        strip_path = os.path.join(input_dir, row_name, f"cow_{row_name}_strip.png")
        if not os.path.exists(strip_path):
            print(f"  Skipping {row_name}: strip not found")
            continue
        out_folder = os.path.join(output_dir, row_name)
        os.makedirs(out_folder, exist_ok=True)
        saved = segment_row(strip_path, out_folder, f"cow_{row_name}")
        total += len(saved)

    print(f"\nDone! {total} sprites extracted to {output_dir}")
