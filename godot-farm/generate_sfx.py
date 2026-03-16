#!/usr/bin/env python3
"""
ElevenLabs Sound Effects Generator for Godot Farm Game
Generates animal sounds and ambient background sounds
"""

import requests
import os
from pathlib import Path

# ElevenLabs API Key
API_KEY = "sk_bf38f4f460d87ed4122131967cd327eac5d5089bc5336601"
BASE_URL = "https://api.elevenlabs.io/v1/sound-generation"

# Output directory
OUTPUT_DIR = Path("/Users/jerry/.openclaw/workspace/godot-farm/assets/audio/sfx")

# Sound definitions
SOUNDS = {
    # Animal sounds
    "cow": {
        "prompt": "A happy cow mooing softly, farm animal vocalization, gentle and calm",
        "duration": 2.0,
        "prompt_influence": 0.7
    },
    "cow_walk": {
        "prompt": "Cow hoof steps on grass and dirt, heavy footsteps, farm animal walking",
        "duration": 1.5,
        "prompt_influence": 0.8
    },
    "sheep": {
        "prompt": "A sheep baaing gently, soft woolly animal vocalization, pastoral farm sound",
        "duration": 1.5,
        "prompt_influence": 0.7
    },
    "sheep_walk": {
        "prompt": "Sheep walking on grass, light hoof steps, gentle footfall",
        "duration": 1.2,
        "prompt_influence": 0.8
    },
    "zebra": {
        "prompt": "Zebra vocalization, braying sound similar to donkey but unique, safari animal call",
        "duration": 2.0,
        "prompt_influence": 0.7
    },
    "zebra_walk": {
        "prompt": "Zebra walking on grass, medium hoof beats, steady rhythm",
        "duration": 1.5,
        "prompt_influence": 0.8
    },
    "pig": {
        "prompt": "A pig oinking and snorting happily, farm pig vocalization, content animal sound",
        "duration": 1.8,
        "prompt_influence": 0.7
    },
    "pig_walk": {
        "prompt": "Pig trottering on dirt and grass, quick light footsteps, farm animal movement",
        "duration": 1.2,
        "prompt_influence": 0.8
    },
    
    # Ambient background sounds
    "wind": {
        "prompt": "Gentle wind blowing through trees, soft breeze rustling leaves, peaceful nature ambiance",
        "duration": 10.0,
        "prompt_influence": 0.6
    },
    "leaves_rustle": {
        "prompt": "Leaves rustling in the wind, tree branches swaying, forest foliage movement",
        "duration": 5.0,
        "prompt_influence": 0.6
    },
    "birds": {
        "prompt": "Peaceful birds chirping in the distance, morning songbirds, nature ambient bird calls",
        "duration": 8.0,
        "prompt_influence": 0.5
    },
    "birds_single": {
        "prompt": "Single bird chirping, short tweet, cheerful bird call",
        "duration": 1.5,
        "prompt_influence": 0.7
    }
}


def generate_sound(name: str, config: dict) -> bool:
    """Generate a single sound effect using ElevenLabs API"""
    
    # Determine subdirectory
    if name in ["cow", "cow_walk"]:
        subdir = "cow"
    elif name in ["sheep", "sheep_walk"]:
        subdir = "sheep"
    elif name in ["zebra", "zebra_walk"]:
        subdir = "zebra"
    elif name in ["pig", "pig_walk"]:
        subdir = "pig"
    else:
        subdir = "ambient"
    
    # Create output path
    output_path = OUTPUT_DIR / subdir
    output_path.mkdir(parents=True, exist_ok=True)
    
    file_path = output_path / f"{name}.mp3"
    
    if file_path.exists():
        print(f"⚠️  Skipping {name} - already exists at {file_path}")
        return True
    
    print(f"🎵 Generating: {name} ({config['duration']}s)")
    print(f"   Prompt: {config['prompt'][:60]}...")
    
    headers = {
        "xi-api-key": API_KEY,
        "Content-Type": "application/json"
    }
    
    payload = {
        "text": config["prompt"],
        "duration_seconds": config["duration"],
        "prompt_influence": config.get("prompt_influence", 0.7)
    }
    
    try:
        response = requests.post(BASE_URL, headers=headers, json=payload)
        
        if response.status_code == 200:
            with open(file_path, "wb") as f:
                f.write(response.content)
            print(f"   ✅ Saved to {file_path}")
            return True
        else:
            print(f"   ❌ Error: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"   ❌ Exception: {e}")
        return False


def main():
    print("=" * 60)
    print("🎮 Godot Farm - ElevenLabs Sound Effects Generator")
    print("=" * 60)
    print()
    
    success_count = 0
    total_count = len(SOUNDS)
    
    for name, config in SOUNDS.items():
        if generate_sound(name, config):
            success_count += 1
        print()
    
    print("=" * 60)
    print(f"✅ Complete: {success_count}/{total_count} sounds generated")
    print("=" * 60)
    
    # List generated files
    print("\n📁 Generated files:")
    for subdir in OUTPUT_DIR.iterdir():
        if subdir.is_dir():
            files = list(subdir.glob("*.mp3"))
            if files:
                print(f"   {subdir.name}/:")
                for f in sorted(files):
                    size = f.stat().st_size / 1024
                    print(f"      - {f.name} ({size:.1f} KB)")


if __name__ == "__main__":
    main()
