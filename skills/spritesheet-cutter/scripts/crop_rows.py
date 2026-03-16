#!/usr/bin/env python3
"""
Crop a spritesheet into row strips based on coordinates.
Supports coordinate scaling when the reference size differs from actual image size.

Usage:
  python3 crop_rows.py <input_image> <output_dir> <rows_json> [--ref-size WxH]

  rows_json format: '{"row1_idle": [left, top, right, bottom], ...}'
  --ref-size: Reference image size the coordinates are based on (e.g. "945x2048")
              If provided, coordinates will be scaled to match actual image size.

Example:
  python3 crop_rows.py spritesheet.png ./output \
    '{"row1_idle": [40, 170, 900, 360], "row2_walk": [35, 430, 910, 620]}' \
    --ref-size 945x2048
"""
import os, sys, json, argparse
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description="Crop spritesheet into row strips")
    parser.add_argument("input", help="Path to spritesheet image")
    parser.add_argument("output_dir", help="Output directory for row strips")
    parser.add_argument("rows_json", help="JSON dict of row_name: [left, top, right, bottom]")
    parser.add_argument("--ref-size", help="Reference size WxH the coords are based on (e.g. 945x2048)")
    args = parser.parse_args()

    img = Image.open(args.input)
    w, h = img.size
    print(f"Source: {w}x{h}, mode: {img.mode}")

    rows = json.loads(args.rows_json)

    sx, sy = 1.0, 1.0
    if args.ref_size:
        rw, rh = map(int, args.ref_size.split("x"))
        sx, sy = w / rw, h / rh
        print(f"Scaling from {rw}x{rh} -> {w}x{h} (sx={sx:.3f}, sy={sy:.3f})")

    os.makedirs(args.output_dir, exist_ok=True)

    for name, coords in rows.items():
        l, t, r, b = coords
        box = (int(l * sx), int(t * sy), int(r * sx), int(b * sy))
        cropped = img.crop(box)
        out = os.path.join(args.output_dir, f"{name}.png")
        cropped.save(out)
        print(f"  {name}: box={box} size={cropped.size} -> {out}")

    print("Done!")


if __name__ == "__main__":
    main()
