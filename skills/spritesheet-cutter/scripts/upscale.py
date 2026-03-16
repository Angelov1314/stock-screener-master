#!/usr/bin/env python3
"""
Upscale sprite frames by 2x using high-quality resampling.
Run after SAM segmentation to double the resolution of all extracted frames.
"""

import os
import sys
from pathlib import Path
from PIL import Image

def upscale_image(input_path: Path, output_path: Path, scale: int = 2) -> bool:
    """Upscale a single image using Lanczos resampling."""
    try:
        with Image.open(input_path) as img:
            # Convert to RGBA if needed
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            
            # Calculate new size
            new_size = (img.width * scale, img.height * scale)
            
            # Upscale using Lanczos (high quality for pixel art/sprites)
            upscaled = img.resize(new_size, Image.Resampling.LANCZOS)
            
            # Save with original format
            upscaled.save(output_path, 'PNG')
            return True
    except Exception as e:
        print(f"Error upscaling {input_path}: {e}", file=sys.stderr)
        return False

def get_animation_folders(parent_dir: Path) -> list[Path]:
    """Get all animation folders (idle, walk, etc.) excluding _2x variants."""
    folders = []
    if not parent_dir.exists():
        return folders
    
    for item in parent_dir.iterdir():
        if item.is_dir() and not item.name.endswith('_2x'):
            folders.append(item)
    return folders

def upscale_animation_folder(anim_folder: Path, scale: int = 2) -> int:
    """Upscale all frames in an animation folder to a new _2x subfolder."""
    # Create output folder (e.g., idle -> idle_2x)
    output_folder = anim_folder.parent / f"{anim_folder.name}_{scale}x"
    output_folder.mkdir(exist_ok=True)
    
    # Find all PNG files in source folder
    png_files = sorted(anim_folder.glob("*.png"))
    
    if not png_files:
        print(f"  No PNG files in {anim_folder.name}")
        return 0
    
    print(f"\n📁 {anim_folder.name} -> {output_folder.name}")
    
    processed = 0
    for png_file in png_files:
        output_path = output_folder / png_file.name
        
        print(f"  {png_file.name} ({png_file.stat().st_size//1024}KB) -> ", end="")
        
        if upscale_image(png_file, output_path, scale):
            processed += 1
            print(f"{output_path.stat().st_size//1024}KB ✓")
        else:
            print("✗ failed")
    
    return processed

def upscale_character_dir(char_dir: Path, scale: int = 2) -> dict:
    """Upscale all animations for a character directory."""
    results = {"processed": 0, "folders": []}
    
    anim_folders = get_animation_folders(char_dir)
    
    if not anim_folders:
        print(f"No animation folders found in {char_dir}")
        return results
    
    print(f"\n🐮 Processing character: {char_dir.name}")
    print(f"Found {len(anim_folders)} animation folders")
    
    for anim_folder in anim_folders:
        count = upscale_animation_folder(anim_folder, scale)
        if count > 0:
            results["processed"] += count
            results["folders"].append(f"{anim_folder.name}_{scale}x")
    
    return results

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 upscale.py <character_dir> [scale]")
        print("  character_dir: Character folder containing animation subfolders")
        print("                  (e.g., ./cow/ with idle/, walk/, etc.)")
        print("  scale:         Upscaling factor (default: 2)")
        print("\nExamples:")
        print("  # Upscale cow character to 2x")
        print("  python3 upscale.py ./assets/characters/cow")
        print("")
        print("  # Upscale to 4x")
        print("  python3 upscale.py ./assets/characters/cow 4")
        print("")
        print("  # Output structure (Scheme B):")
        print("  cow/")
        print("    ├── idle/          # original 1x frames")
        print("    ├── idle_2x/       # upscaled 2x frames")
        print("    ├── walk/")
        print("    └── walk_2x/")
        sys.exit(1)
    
    char_dir = Path(sys.argv[1])
    scale = int(sys.argv[2]) if len(sys.argv) > 2 else 2
    
    if not char_dir.exists():
        print(f"Error: Directory not found: {char_dir}", file=sys.stderr)
        sys.exit(1)
    
    if not char_dir.is_dir():
        print(f"Error: Not a directory: {char_dir}", file=sys.stderr)
        sys.exit(1)
    
    results = upscale_character_dir(char_dir, scale)
    
    print(f"\n✅ Done: {results['processed']} frames upscaled to {scale}x")
    if results["folders"]:
        print(f"Created folders: {', '.join(results['folders'])}")

if __name__ == "__main__":
    main()
