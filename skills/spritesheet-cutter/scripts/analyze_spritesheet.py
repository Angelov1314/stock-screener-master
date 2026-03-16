#!/usr/bin/env python3
"""Analyze spritesheet using AI to detect row positions"""
import sys
import json
from PIL import Image

def analyze_spritesheet(image_path, num_rows=5):
    """Use Gemini to analyze spritesheet and detect row coordinates"""
    img = Image.open(image_path)
    width, height = img.size
    
    print(f"Image size: {width}x{height}")
    print(f"Expected rows: {num_rows}")
    
    # Estimate row height
    row_height = height // num_rows
    print(f"Estimated row height: {row_height}")
    
    # Create row definitions
    rows = {}
    row_names = ["idle", "walk", "happy", "sleep", "carried"]
    frames_per_row = [4, 4, 4, 2, 2]
    
    for i, (name, frames) in enumerate(zip(row_names[:num_rows], frames_per_row[:num_rows])):
        top = i * row_height
        bottom = (i + 1) * row_height if i < num_rows - 1 else height
        rows[name] = {
            "coords": [0, top, width, bottom],
            "frames": frames
        }
    
    return rows, (width, height)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_spritesheet.py <image_path> [num_rows]")
        sys.exit(1)
    
    image_path = sys.argv[1]
    num_rows = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    
    rows, size = analyze_spritesheet(image_path, num_rows)
    
    print("\n=== Detected Row Coordinates ===")
    for name, data in rows.items():
        print(f"{name}: {data['coords']} (frames: {data['frames']})")
    
    # Output JSON for next step
    output = {
        "rows": {name: data["coords"] for name, data in rows.items()},
        "frames": {name: data["frames"] for name, data in rows.items()},
        "image_size": size
    }
    
    print("\n=== JSON Output ===")
    print(json.dumps(output, indent=2))
