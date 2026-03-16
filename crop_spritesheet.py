#!/usr/bin/env python3
"""Crop a spritesheet into rows, then into individual frames per row."""
import os
import sys
from PIL import Image

def crop_spritesheet(input_path, output_dir, name, rows_config):
    """
    rows_config: list of (row_name, num_frames) tuples
    """
    img = Image.open(input_path)
    w, h = img.size
    num_rows = len(rows_config)
    row_h = h // num_rows

    for i, (row_name, num_frames) in enumerate(rows_config):
        folder = os.path.join(output_dir, row_name)
        os.makedirs(folder, exist_ok=True)

        # Crop the row
        top = i * row_h
        bottom = top + row_h
        row_img = img.crop((0, top, w, bottom))

        # Crop individual frames
        frame_w = w // num_frames
        for j in range(num_frames):
            left = j * frame_w
            right = left + frame_w
            frame = row_img.crop((left, 0, right, row_h))
            frame.save(os.path.join(folder, f"{name}_{row_name}_{j}.png"))
            print(f"  Saved {folder}/{name}_{row_name}_{j}.png")

    print(f"\nDone! {sum(f for _, f in rows_config)} frames saved to {output_dir}")

if __name__ == "__main__":
    input_path = sys.argv[1] if len(sys.argv) > 1 else "cow_spritesheet.png"
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "cow_sprites"
    name = sys.argv[3] if len(sys.argv) > 3 else "cow"

    rows_config = [
        ("idle", 4),
        ("walk", 4),
        ("happy", 4),
        ("sleep", 2),
        ("carried", 2),
    ]

    crop_spritesheet(input_path, output_dir, name, rows_config)
