#!/usr/bin/env python3
"""Analyze spritesheet using Gemini Vision API to detect row positions"""
import os
import sys
import json
import base64
from PIL import Image

# Default animation configuration for 5-row spritesheet
DEFAULT_CONFIG = {
    "names": ["idle", "walk", "happy", "sleep", "carried"],
    "frames": [4, 4, 4, 2, 2],
    "descriptions": [
        "站立/idle动画",
        "行走/walk动画",
        "开心/happy动画",
        "睡觉/sleep动画",
        "被抱起/carried动画"
    ]
}

def encode_image(image_path):
    """Encode image to base64"""
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode('utf-8')

def analyze_with_gemini(image_path, num_rows=5, names=None, frames=None):
    """Use Gemini Vision to analyze spritesheet rows"""
    
    if names is None:
        names = DEFAULT_CONFIG["names"][:num_rows]
    if frames is None:
        frames = DEFAULT_CONFIG["frames"][:num_rows]
    
    # Get image info
    img = Image.open(image_path)
    width, height = img.size
    print(f"Image size: {width}x{height}")
    print(f"Analyzing {num_rows} rows...")
    
    # Build prompt
    descriptions = DEFAULT_CONFIG["descriptions"][:num_rows]
    rows_desc = "\n".join([
        f"- 第{i+1}行：{desc}，{frame_count}帧"
        for i, (desc, frame_count) in enumerate(zip(descriptions, frames))
    ])
    
    prompt = f"""分析这张精灵图，包含{num_rows}行动画：
{rows_desc}

请检测每行的精确像素坐标，以JSON格式返回：
{{
"rows": {{
"row_name": {{"coords": [left, top, right, bottom], "frames": frame_count}},
...
}}
}}

可用行名：{', '.join(names)}
坐标原点为左上角，格式为 [left, top, right, bottom]。图片总尺寸为 {width}x{height} 像素。
"""
    
    print("\n=== Gemini Vision Prompt ===")
    print(prompt)
    print("\n=== Note ===")
    print("请使用 Gemini Vision API 或类似工具分析此图片")
    print("将返回的坐标保存为 analysis_result.json")
    
    # Fallback: create template
    result = {
        "rows": {},
        "image_size": [width, height],
        "prompt": prompt
    }
    
    row_height = height // num_rows
    for i, (name, frame_count) in enumerate(zip(names, frames)):
        top = i * row_height
        bottom = (i + 1) * row_height if i < num_rows - 1 else height
        result["rows"][name] = {
            "coords": [0, top, width, bottom],
            "frames": frame_count
        }
    
    return result

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Analyze spritesheet using Gemini Vision")
    parser.add_argument("image_path", help="Path to spritesheet image")
    parser.add_argument("--rows", type=int, default=5, help="Number of rows")
    parser.add_argument("--names", type=str, default="idle,walk,happy,sleep,carried",
                        help="Comma-separated animation names")
    parser.add_argument("--frames", type=str, default="4,4,4,2,2",
                        help="Comma-separated frame counts")
    parser.add_argument("--output", "-o", type=str, default="analysis_result.json",
                        help="Output JSON file")
    args = parser.parse_args()
    
    names = args.names.split(",")
    frames = [int(f) for f in args.frames.split(",")]
    
    result = analyze_with_gemini(args.image_path, args.rows, names, frames)
    
    # Save result
    with open(args.output, "w") as f:
        json.dump(result, f, indent=2)
    
    print(f"\n✓ Analysis template saved to {args.output}")
    print(f"  Rows detected: {len(result['rows'])}")
    for name, data in result['rows'].items():
        print(f"    {name}: {data['coords']} ({data['frames']} frames)")

if __name__ == "__main__":
    main()
