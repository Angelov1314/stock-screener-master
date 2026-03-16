#!/usr/bin/env python3
"""
Use SAM (Segment Anything Model) to segment individual sprite frames from row strips.
Each strip is processed independently; detected masks are filtered, grouped, and
cropped as individual RGBA PNGs.

Usage:
  python3 sam_segment.py <strips_dir> <strips_json> [--checkpoint PATH] [--model-type TYPE]

  strips_dir:  Directory containing row strip PNGs
  strips_json: JSON dict of folder_name: ["strip_filename.png", expected_frame_count]

Example:
  python3 sam_segment.py ./sheep_rows \
    '{"idle": ["row1_idle.png", 4], "walk": ["row2_walk.png", 4], "sleep": ["row4_sleep.png", 2]}'
"""
import os, sys, json, argparse
import numpy as np
from PIL import Image
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator


def x_center(m):
    bbox = m["bbox"]
    return bbox[0] + bbox[2] / 2


def segment_strip(mask_generator, strip_path, output_folder, prefix, expected_count):
    print(f"\n=== {prefix} ({expected_count} frames) ===", flush=True)
    os.makedirs(output_folder, exist_ok=True)

    img = Image.open(strip_path).convert("RGBA")
    img_rgb = np.array(img.convert("RGB"))

    masks = mask_generator.generate(img_rgb)
    print(f"  SAM found {len(masks)} masks", flush=True)

    img_area = img_rgb.shape[0] * img_rgb.shape[1]
    min_area = img_area * 0.02
    max_area = img_area * 0.6

    good_masks = [m for m in masks if min_area < m["area"] < max_area]
    print(f"  After size filter: {len(good_masks)} masks", flush=True)

    good_masks.sort(key=x_center)

    if len(good_masks) > expected_count:
        groups = []
        for m in good_masks:
            xc = x_center(m)
            merged = False
            for g in groups:
                g_xc = np.mean([x_center(gm) for gm in g])
                if abs(xc - g_xc) < img_rgb.shape[1] / (expected_count * 2):
                    g.append(m)
                    merged = True
                    break
            if not merged:
                groups.append([m])
        good_masks = [max(g, key=lambda m: m["area"]) for g in groups]
        good_masks.sort(key=x_center)
        print(f"  After grouping: {len(good_masks)} masks", flush=True)

    for i, m in enumerate(good_masks[:expected_count]):
        mask = m["segmentation"]
        bbox = m["bbox"]
        x, y, w, h = [int(v) for v in bbox]

        pad = 5
        x0 = max(0, x - pad)
        y0 = max(0, y - pad)
        x1 = min(img.width, x + w + pad)
        y1 = min(img.height, y + h + pad)

        img_array = np.array(img)
        cropped = img_array[y0:y1, x0:x1].copy()
        mask_crop = mask[y0:y1, x0:x1]
        cropped[~mask_crop, 3] = 0

        out_path = os.path.join(output_folder, f"{prefix}_{i}.png")
        Image.fromarray(cropped).save(out_path)
        print(f"  Frame {i}: ({x0},{y0})-({x1},{y1}) {w}x{h} -> {out_path}", flush=True)


def main():
    parser = argparse.ArgumentParser(description="SAM-based sprite frame segmentation")
    parser.add_argument("strips_dir", help="Directory containing row strip PNGs")
    parser.add_argument("strips_json", help='JSON: {"folder": ["strip.png", count]}')
    parser.add_argument("--checkpoint", default=os.path.expanduser("~/.cache/sam/sam_vit_h.pth"),
                        help="Path to SAM checkpoint")
    parser.add_argument("--model-type", default="vit_h", help="SAM model type")
    args = parser.parse_args()

    strips = json.loads(args.strips_json)

    print("Loading SAM model...", flush=True)
    sam = sam_model_registry[args.model_type](checkpoint=args.checkpoint)
    mask_generator = SamAutomaticMaskGenerator(
        sam,
        min_mask_region_area=500,
        pred_iou_thresh=0.86,
        stability_score_thresh=0.92,
    )

    for folder_name, (strip_file, expected_count) in strips.items():
        strip_path = os.path.join(args.strips_dir, strip_file)
        output_folder = os.path.join(args.strips_dir, folder_name)
        segment_strip(mask_generator, strip_path, output_folder, folder_name, expected_count)

    print("\nDone!", flush=True)


if __name__ == "__main__":
    main()
