---
name: spritesheet-to-frames
description: |
  One-shot spritesheet processor. Input a full spritesheet image, get 5 animation folders 
  (idle, walk, happy, sleep, carried) with transparent frames. Combines row detection, 
  cropping, and SAM segmentation in a single command.
  
  Default config: 5 rows × [4,4,4,2,2] frames
---

# Spritesheet to Frames

**One command**: Full spritesheet → 5 animation folders with transparent frames

## Quick Start

```bash
python3 scripts/spritesheet_to_frames.py character_sheet.png -o ./character_output
```

**Output:**
```
character_output/
├── idle/          # 4 frames (standing)
├── walk/          # 4 frames (walking)
├── happy/         # 4 frames (happy animation)
├── sleep/         # 2 frames (sleeping)
└── carried/       # 2 frames (being carried)
```

## Installation

```bash
pip install Pillow numpy opencv-python

# Optional: For SAM segmentation (better quality)
pip install torch torchvision segment-anything

# Download SAM model (auto-downloaded on first run)
# Or manual: curl -L 'https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth' \
#   -o ~/.cache/sam/sam_vit_h.pth
```

## Usage

### Basic (Auto-detect 5 rows)

```bash
python3 scripts/spritesheet_to_frames.py \
  path/to/spritesheet.png \
  -o ./output
```

### Custom Animation Names

```bash
python3 scripts/spritesheet_to_frames.py \
  character.png \
  -o ./output \
  --names idle,run,jump,fall,hurt \
  --frames 4,6,2,2,2
```

### Without SAM (Faster, no transparency)

```bash
python3 scripts/spritesheet_to_frames.py \
  character.png \
  -o ./output \
  --no-sam
```

## Default Configuration

| Row | Animation | Frames | Description |
|-----|-----------|--------|-------------|
| 1 | idle | 4 | Standing pose |
| 2 | walk | 4 | Walking animation |
| 3 | happy | 4 | Happy/excited |
| 4 | sleep | 2 | Sleeping/resting |
| 5 | carried | 2 | Being picked up/carried |

## How It Works

### Stage 1: Row Detection
- Auto-detects 5 equal rows from image height
- Calculates crop coordinates for each animation

### Stage 2: Crop to Strips
- Crops each row into individual strip images
- Saved to `_strips/` temporary folder

### Stage 3: Frame Segmentation

**With SAM (default):**
- Uses Meta's SAM to detect object boundaries
- Removes background, keeps only character
- Outputs transparent PNG (RGBA)

**Without SAM (`--no-sam`):**
- Simple equal-width splitting
- Preserves original background
- Faster but no transparency

### Stage 4: Organize
- Moves frames to final folders
- Naming: `{animation}_{frame_number}.png`
- Cleans up temporary files

## Examples

### Example 1: Farm Animal (5 animations)

```bash
# Process cow spritesheet
python3 scripts/spritesheet_to_frames.py \
  ~/Downloads/cow_spritesheet.png \
  -o ./assets/characters/cow

# Output:
# ./assets/characters/cow/
#   ├── idle/cow_idle_0.png ... cow_idle_3.png
#   ├── walk/cow_walk_0.png ... cow_walk_3.png
#   ├── happy/cow_happy_0.png ... cow_happy_3.png
#   ├── sleep/cow_sleep_0.png ... cow_sleep_1.png
#   └── carried/cow_carried_0.png ... cow_carried_1.png
```

### Example 2: Custom Frame Counts

```bash
# 6-frame walk cycle, 2-frame others
python3 scripts/spritesheet_to_frames.py \
  hero.png \
  -o ./hero \
  --names idle,walk,attack,die,win \
  --frames 4,6,4,4,2
```

### Example 3: Quick Crop (No SAM)

```bash
# Fast processing, keep backgrounds
python3 scripts/spritesheet_to_frames.py \
  ui_icons.png \
  -o ./ui_icons \
  --names play,pause,settings,close,back \
  --frames 1,1,1,1,1 \
  --no-sam
```

## Troubleshooting

### SAM Model Not Found
```bash
# Download manually
curl -L 'https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth' \
  -o ~/.cache/sam/sam_vit_h.pth
```

### Wrong Row Detection
Spritesheet rows must be **equal height**. If your spritesheet has uneven rows, manually specify coordinates.

### Frames Misaligned
Ensure your spritesheet has:
- Equal-width frames within each row
- Consistent spacing
- No extra padding between rows

## Pipeline Comparison

| Feature | With SAM | Without SAM |
|---------|----------|-------------|
| Background removal | ✓ | ✗ |
| Transparency | ✓ (RGBA) | ✗ (RGB) |
| Auto object detection | ✓ | ✗ |
| Speed | Slow (~1-2 min) | Fast (~1 sec) |
| Quality | High | Basic |

## Integration with Godot

After processing, copy to your project:

```bash
# Copy to Godot project
cp -r ./output/* ~/my_godot_project/assets/characters/

# In Godot, sprites will be:
# res://assets/characters/cow/idle/cow_idle_0.png
# res://assets/characters/cow/walk/cow_walk_0.png
```

Use with AnimatedSprite2D:
```gdscript
# Auto-load frames
$AnimatedSprite2D.sprite_frames = load("res://assets/characters/cow/cow_frames.tres")
$AnimatedSprite2D.animation = "walk"
$AnimatedSprite2D.play()
```

## Requirements

- Python 3.8+
- Pillow (PIL)
- NumPy
- OpenCV (optional, for better image handling)
- PyTorch + segment-anything (optional, for SAM)

---

Created: 2026-03-17
Version: 1.0
