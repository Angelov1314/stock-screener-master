#!/usr/bin/env python3
"""
Generate animal sound effects using ElevenLabs API
"""

import requests
import os
import sys

# ElevenLabs API key - from environment variable
ELEVENLABS_API_KEY = os.environ.get("ELEVENLABS_API_KEY", "")

# Output directory
OUTPUT_DIR = "/Users/jerry/.openclaw/workspace/godot-farm/assets/audio/sfx"

# Animals and their prompts
ANIMALS = {
    "shiba": {
        "idle": "A friendly shiba inu dog barking happily, cheerful bark",
        "walk": "Soft dog paws walking on grass, light footsteps"
    },
    "koala": {
        "idle": "A cute koala bear grunting, gentle marsupial vocalization",
        "walk": "Koala climbing on eucalyptus tree, scratching sounds"
    },
    "cat": {
        "idle": "A domestic cat meowing softly, cute kitten sound",
        "walk": "Cat walking quietly, soft paw steps on floor"
    },
    "capybara": {
        "idle": "A capybara making gentle squeaking and whistling sounds",
        "walk": "Capybara walking through grass, heavy rodent footsteps"
    },
    "alpaca": {
        "idle": "An alpaca humming gently, soft camelid vocalization",
        "walk": "Alpaca walking on grass, gentle hoof steps"
    }
}

def generate_sound_effect(prompt: str, output_path: str):
    """Generate sound effect using ElevenLabs API"""
    
    url = "https://api.elevenlabs.io/v1/text-to-speech/21m00Tcm4TlvDq8ikWAM"  # Using Rachel voice for now
    
    headers = {
        "xi-api-key": ELEVENLABS_API_KEY,
        "Content-Type": "application/json"
    }
    
    # Sound effects API requires different parameters
    # Let's try the correct sound generation endpoint
    url = "https://api.elevenlabs.io/v1/sound-generation"
    
    data = {
        "text": prompt
    }
    
    print(f"Generating: {output_path}")
    print(f"Prompt: {prompt}")
    
    try:
        response = requests.post(url, headers=headers, json=data, timeout=60)
        
        if response.status_code == 200:
            # Save the audio file
            with open(output_path, "wb") as f:
                f.write(response.content)
            print(f"✓ Saved: {output_path}")
            return True
        else:
            print(f"✗ Error: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"✗ Exception: {e}")
        return False

def main():
    if ELEVENLABS_API_KEY == "YOUR_API_KEY_HERE":
        print("ERROR: Please set your ElevenLabs API key in the script")
        print("Get your API key from: https://elevenlabs.io/app/settings/api-keys")
        sys.exit(1)
    
    print("ElevenLabs Animal Sound Generator")
    print("=" * 50)
    
    for animal, sounds in ANIMALS.items():
        animal_dir = os.path.join(OUTPUT_DIR, animal)
        os.makedirs(animal_dir, exist_ok=True)
        
        print(f"\n{animal.upper()}:")
        
        # Generate idle sound (for pickup)
        idle_path = os.path.join(animal_dir, f"{animal}.mp3")
        if not os.path.exists(idle_path) or input(f"Overwrite {animal}.mp3? (y/n): ").lower() == 'y':
            generate_sound_effect(sounds["idle"], idle_path)
        else:
            print(f"Skipping {animal}.mp3 (already exists)")
        
        # Generate walk sound
        walk_path = os.path.join(animal_dir, f"{animal}_walk.mp3")
        if not os.path.exists(walk_path) or input(f"Overwrite {animal}_walk.mp3? (y/n): ").lower() == 'y':
            generate_sound_effect(sounds["walk"], walk_path)
        else:
            print(f"Skipping {animal}_walk.mp3 (already exists)")
    
    print("\n" + "=" * 50)
    print("Done! Refresh Godot to see new audio files.")

if __name__ == "__main__":
    main()
