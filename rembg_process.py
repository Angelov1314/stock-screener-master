#!/usr/bin/env python3
"""Remove background using rembg (better than color keying)"""
import os
from PIL import Image
from rembg import remove

def process_strip(strip_path, output_dir, anim_name, num_frames):
    """Process a sprite strip into individual frames with background removed."""
    img = Image.open(strip_path)
    width, height = img.size
    frame_width = width // num_frames
    
    print(f"Processing {anim_name}: {num_frames} frames")
    os.makedirs(output_dir, exist_ok=True)
    
    for i in range(num_frames):
        left = i * frame_width
        right = left + frame_width
        frame = img.crop((left, 0, right, height))
        
        # Remove background with rembg
        output = remove(frame)
        
        # Save
        output_path = os.path.join(output_dir, f"{anim_name}_{i}.png")
        output.save(output_path)
        print(f"  {output_path}")

if __name__ == "__main__":
    import sys
    strip_path = sys.argv[1]
    output_dir = sys.argv[2]
    anim_name = sys.argv[3]
    num_frames = int(sys.argv[4])
    
    process_strip(strip_path, output_dir, anim_name, num_frames)
    print(f"✓ Done: {anim_name}")
