#!/usr/bin/env python3
"""
Example: Using SAM Segmentation Pipeline
"""
import sys
sys.path.insert(0, '/Users/jerry/.openclaw/workspace/skills/sam-segmentation')

from sam_segment import SAMSegmenter

# Example 1: Basic usage
print("=" * 60)
print("Example 1: Segment animal sprite sheet")
print("=" * 60)

segmenter = SAMSegmenter(use_sam=True)  # Try SAM first, fallback to contours

saved = segmenter.segment(
    image_path="/Users/jerry/.openclaw/workspace/godot-farm/assets/characters/animals_sheet.jpg",
    output_dir="/tmp/example_output/animals",
    names=["pig", "chick", "sheep"],
    min_area=50000,
    max_area=200000,
    output_size=256,
    padding=30
)

print(f"\n✅ Saved {len(saved)} files:")
for f in saved:
    print(f"  - {f}")

# Example 2: UI icons (smaller size)
print("\n" + "=" * 60)
print("Example 2: Segment UI icons")
print("=" * 60)

saved = segmenter.segment(
    image_path="/Users/jerry/.openclaw/workspace/godot-farm/assets/props/props_sheet.jpg",
    output_dir="/tmp/example_output/props",
    names=["sign", "watering_can", "gift_box", "basket", "crate", "barrel"],
    min_area=30000,
    output_size=256,
    padding=25
)

print(f"\n✅ Saved {len(saved)} files")

# Example 3: Using without SAM (contour only)
print("\n" + "=" * 60)
print("Example 3: Contour detection only (no SAM)")
print("=" * 60)

contour_segmenter = SAMSegmenter(use_sam=False)

saved = contour_segmenter.segment(
    image_path="/Users/jerry/.openclaw/workspace/godot-farm/assets/characters/animals_sheet.jpg",
    output_dir="/tmp/example_output/contour_only",
    names=["pig", "chick", "sheep"],
    min_area=50000,
    output_size=256
)

print(f"\n✅ Saved {len(saved)} files using contour detection")
