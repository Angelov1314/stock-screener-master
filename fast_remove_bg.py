#!/usr/bin/env python3
"""Fast background removal using color keying (green screen)"""
import os
import numpy as np
from PIL import Image

def remove_green_background(input_path, output_path, tolerance=30):
    """Remove green background using color keying."""
    img = Image.open(input_path).convert("RGBA")
    data = np.array(img)
    
    # Green color range (adjustable)
    # Typical green screen: R<100, G>150, B<100
    r, g, b = data[:,:,0], data[:,:,1], data[:,:,2]
    
    # Mask for green pixels
    green_mask = (g > 150) & (r < 100) & (b < 100)
    
    # Also mask very light green
    light_green = (g > 200) & (r > 150) & (b > 150) & (g > r + 20) & (g > b + 20)
    
    # Combine masks
    mask = green_mask | light_green
    
    # Set alpha to 0 for green pixels
    data[mask] = [0, 0, 0, 0]
    
    # Save
    result = Image.fromarray(data)
    result.save(output_path)

def process_strip(strip_path, output_dir, anim_name, num_frames):
    """Process a sprite strip into individual frames."""
    img = Image.open(strip_path)
    width, height = img.size
    frame_width = width // num_frames
    
    print(f"Processing {anim_name}: {num_frames} frames")
    os.makedirs(output_dir, exist_ok=True)
    
    for i in range(num_frames):
        left = i * frame_width
        right = left + frame_width
        frame = img.crop((left, 0, right, height))
        
        # Save temp
        temp_path = f"/tmp/frame_{i}.png"
        frame.save(temp_path)
        
        # Remove green background
        output_path = os.path.join(output_dir, f"{anim_name}_{i}.png")
        remove_green_background(temp_path, output_path)
        print(f"  {output_path}")
        
        # Cleanup
        os.remove(temp_path)

if __name__ == "__main__":
    import sys
    strip_path = sys.argv[1]
    output_dir = sys.argv[2]
    anim_name = sys.argv[3]
    num_frames = int(sys.argv[4])
    
    process_strip(strip_path, output_dir, anim_name, num_frames)
    print(f"✓ Done: {anim_name}")
