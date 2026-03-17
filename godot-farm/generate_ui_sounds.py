#!/usr/bin/env python3
import os, requests
from pathlib import Path
API_KEY = os.environ.get("ELEVENLABS_API_KEY", "")
OUT = Path("/Users/jerry/.openclaw/workspace/godot-farm/assets/audio/sfx/ui")
SOUNDS = {
    "xp_gain.mp3": "Short magical game UI sound for gaining experience points after buying an animal, warm sparkle, soft reward chime, under 1 second",
    "gold_gain.mp3": "Short game reward sound for gaining gold coins from selling crops, soft coin shimmer, cozy farm game, under 1 second",
    "level_up.mp3": "Short satisfying level up sound for a cozy farm game, uplifting magical chime, warm and rewarding, under 2 seconds",
    "paper_open.mp3": "Short paper rustle ASMR sound for opening a shop menu or backpack in a cozy farm game, soft parchment flip, under 1 second"
}

def gen(name, prompt):
    if not API_KEY:
        print('Missing ELEVENLABS_API_KEY')
        return False
    r = requests.post('https://api.elevenlabs.io/v1/sound-generation', headers={'xi-api-key': API_KEY, 'Content-Type': 'application/json'}, json={'text': prompt}, timeout=90)
    print(name, r.status_code)
    if r.status_code == 200:
        (OUT/name).write_bytes(r.content)
        return True
    print(r.text)
    return False

OUT.mkdir(parents=True, exist_ok=True)
for n,prompt in SOUNDS.items():
    gen(n, prompt)
