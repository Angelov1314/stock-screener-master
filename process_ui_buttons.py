#!/usr/bin/env python3
"""
Remove background colors from UI buttons and standardize them.
- Makes solid color backgrounds transparent
- Standardizes output size and format
- Preserves alpha channel for button content
"""
import os
import sys
from PIL import Image
import numpy as np

def remove_solid_background(img, tolerance=30, edge_sample_size=10):
    """
    Remove solid color background by detecting the most common color 
    at the edges of the image.
    """
    # Convert to RGBA if needed
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    data = np.array(img)
    
    # Sample colors from edges to detect background
    edges = []
    h, w = data.shape[:2]
    
    # Top and bottom edges
    for x in range(0, w, max(1, w // edge_sample_size)):
        edges.append(data[0, x][:3])  # Top edge
        edges.append(data[h-1, x][:3])  # Bottom edge
    
    # Left and right edges
    for y in range(0, h, max(1, h // edge_sample_size)):
        edges.append(data[y, 0][:3])  # Left edge
        edges.append(data[y, w-1][:3])  # Right edge
    
    edges = np.array(edges)
    
    # Find most common color (mode) as background
    unique, counts = np.unique(edges, axis=0, return_counts=True)
    bg_color = unique[np.argmax(counts)]
    
    print(f"  Detected background color: RGB{tuple(bg_color)}")
    
    # Create mask: pixels within tolerance of bg_color become transparent
    rgb = data[:, :, :3]
    alpha = data[:, :, 3].copy()
    
    # Calculate distance from background color
    diff = np.abs(rgb.astype(int) - bg_color.astype(int))
    dist = np.max(diff, axis=2)  # Max channel difference
    
    # Make background transparent
    alpha[dist <= tolerance] = 0
    data[:, :, 3] = alpha
    
    return Image.fromarray(data)

def standardize_image(img, target_height=128, padding=10):
    """
    Standardize image: consistent height, add padding, center content.
    """
    # Get bounding box of non-transparent content
    bbox = img.getbbox()
    if bbox:
        # Crop to content
        content = img.crop(bbox)
    else:
        content = img
    
    # Calculate new width maintaining aspect ratio
    orig_w, orig_h = content.size
    if orig_h == 0:
        return img
    
    scale = target_height / orig_h
    new_w = int(orig_w * scale)
    new_h = target_height
    
    # Resize content
    resized = content.resize((new_w, new_h), Image.LANCZOS)
    
    # Create new image with padding
    final_w = new_w + (padding * 2)
    final_h = new_h + (padding * 2)
    
    result = Image.new('RGBA', (final_w, final_h), (0, 0, 0, 0))
    
    # Paste centered
    paste_x = (final_w - new_w) // 2
    paste_y = (final_h - new_h) // 2
    result.paste(resized, (paste_x, paste_y), resized)
    
    return result

def process_image(input_path, output_dir, tolerance=30, target_height=128):
    """Process a single image."""
    filename = os.path.basename(input_path)
    print(f"\nProcessing: {filename}")
    
    # Load image
    img = Image.open(input_path)
    print(f"  Original size: {img.size}")
    
    # Remove background
    img_no_bg = remove_solid_background(img, tolerance=tolerance)
    
    # Standardize
    img_std = standardize_image(img_no_bg, target_height=target_height)
    print(f"  Output size: {img_std.size}")
    
    # Save
    output_path = os.path.join(output_dir, filename)
    img_std.save(output_path, 'PNG')
    print(f"  Saved: {output_path}")
    
    return output_path

def main():
    input_dir = "/Users/jerry/.openclaw/workspace/godot-farm/assets/ui/ui_crops_named"
    output_dir = "/Users/jerry/.openclaw/workspace/godot-farm/assets/ui/ui_crops_named_processed"
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Process all PNG files
    png_files = [f for f in os.listdir(input_dir) if f.endswith('.png') and not f.startswith('.')]
    
    print(f"Found {len(png_files)} PNG files to process")
    print(f"Output directory: {output_dir}")
    
    processed = []
    for filename in sorted(png_files):
        input_path = os.path.join(input_dir, filename)
        try:
            output_path = process_image(input_path, output_dir, tolerance=30, target_height=128)
            processed.append(filename)
        except Exception as e:
            print(f"  ERROR: {e}")
    
    print(f"\n✅ Processed {len(processed)} files")
    print(f"Output: {output_dir}/")

if __name__ == "__main__":
    main()
