#!/usr/bin/env python3
"""Cut spritesheet into equal frames per row (standard sprite sheet approach)."""
import os
import sys
from PIL import Image

input_path = sys.argv[1] if len(sys.argv) > 1 else "cow_spritesheet.png"
output_dir = sys.argv[2] if len(sys.argv) > 2 else "cow_frames"

# Row config: (name, frames)
rows = [
    ("idle", 4),
    ("walk", 4),
    ("happy", 4),
    ("sleep", 2),
    ("carried", 2),
]

img = Image.open(input_path)
w, h = img.size
row_h = h // len(rows)

os.makedirs(output_dir, exist_ok=True)

total = 0
for i, (name, frames) in enumerate(rows):
    folder = os.path.join(output_dir, name)
    os.makedirs(folder, exist_ok=True)
    
    top = i * row_h
    bottom = top + row_h
    row_img = img.crop((0, top, w, bottom))
    
    frame_w = w // frames
    for j in range(frames):
        left = j * frame_w
        right = left + frame_w
        frame = row_img.crop((left, 0, right, row_h))
        
        # Make background transparent (white/light gray -> transparent)
        rgba = frame.convert("RGBA")
        data = rgba.getdata()
        new_data = []
        for item in data:
            r, g, b, a = item
            # If pixel is very light (white/gray checker), make transparent
            if min(r, g, b) > 200:
                new_data.append((r, g, b, 0))
            else:
                new_data.append(item)
        rgba.putdata(new_data)
        
        out_path = os.path.join(folder, f"cow_{name}_{j}.png")
        rgba.save(out_path)
        print(f"  {out_path}")
        total += 1

print(f"\nDone! {total} frames in {output_dir}")
