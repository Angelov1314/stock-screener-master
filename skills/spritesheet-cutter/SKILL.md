---
name: spritesheet-cutter
description: >
  Cut spritesheets into individual animation frames using SAM (Segment Anything Model).
  Use when a user provides a spritesheet image and wants to extract individual sprite frames,
  split animation rows, or segment game character sprites. Handles coordinate-based row cropping,
  automatic scaling, and SAM-powered per-frame segmentation with transparent backgrounds.
  Triggers on spritesheet cutting, sprite extraction, animation frame splitting, game asset cropping.
---

# Spritesheet Cutter

Two-stage pipeline to extract individual sprite frames from a spritesheet image.

## Prerequisites

- Python 3 with `Pillow` and `segment-anything` installed
- SAM checkpoint (default: `~/.cache/sam/sam_vit_h.pth`)

## Pipeline

### Stage 1: AI-Powered Row Detection

Automatically detect row positions using AI analysis.

#### 1.1 Analyze with Gemini Vision

```bash
python3 scripts/analyze_with_gemini.py <image_path> --rows 5
```

**For 5-animation spritesheet (idle/walk/happy/sleep/carried):**

```bash
python3 scripts/analyze_with_gemini.py \
  character_spritesheet.png \
  --rows 5 \
  --names idle,walk,happy,sleep,carried \
  --frames 4,4,4,2,2
```

**Gemini Vision Prompt:**
```
分析这张精灵图，包含5行动画：
- 第1行：站立/idle动画，4帧
- 第2行：行走/walk动画，4帧  
- 第3行：开心/happy动画，4帧
- 第4行：睡觉/sleep动画，2帧
- 第5行：被抱起/carried动画，2帧

请检测每行的精确像素坐标，以JSON格式返回：
{
  "idle": {"coords": [left, top, right, bottom], "frames": 4},
  "walk": {"coords": [left, top, right, bottom], "frames": 4},
  "happy": {"coords": [left, top, right, bottom], "frames": 4},
  "sleep": {"coords": [left, top, right, bottom], "frames": 2},
  "carried": {"coords": [left, top, right, bottom], "frames": 2}
}

坐标原点为左上角，格式为 [left, top, right, bottom]。
```

**Output:** `analysis_result.json`

#### 1.2 Fallback: Auto-Estimate Rows

If AI analysis unavailable, use automatic row estimation:

```bash
python3 scripts/analyze_spritesheet.py \
  character_spritesheet.png \
  --rows 5 \
  --names idle,walk,happy,sleep,carried \
  --frames 4,4,4,2,2
```

This divides the image into 5 equal rows and outputs estimated coordinates.

### Stage 2: Crop Rows

```bash
python3 scripts/crop_rows.py <input_image> <output_dir> '<rows_json>' [--ref-size WxH]
```

- `rows_json`: `{"row1_idle": [left, top, right, bottom], ...}`
- `--ref-size`: If coordinates are based on a different size than the actual image, pass the reference size (e.g. `945x2048`). The script auto-scales.

### Stage 3: SAM Segmentation

```bash
python3 -u scripts/sam_segment.py <strips_dir> '<strips_json>' [--checkpoint PATH]
```

- `strips_json`: `{"idle": ["row1_idle.png", 4], "walk": ["row2_walk.png", 4]}`
- Each strip is segmented into individual frames sorted left-to-right
- Output: `<strips_dir>/<folder>/<folder>_0.png`, `<folder>_1.png`, etc.
- Backgrounds are removed using SAM masks (RGBA with transparent bg)

**Note:** SAM vit_h on CPU takes ~1-2 min per strip. Run with `python3 -u` to avoid buffered output.

### Stage 4: Upscale (Optional)

Upscale all animation frames by 2x using high-quality Lanczos resampling.
Creates `_2x` subfolders for each animation (Scheme B).

```bash
python3 scripts/upscale.py <character_dir> [scale]
```

- `character_dir`: Character folder with animation subfolders (e.g., `./cow/`)
- `scale`: Upscaling factor (default: 2)

**Output structure (Scheme B):**
```
cow/
├── idle/              # original 1x frames
├── idle_2x/           # upscaled 2x frames
├── walk/
├── walk_2x/
├── happy/
├── happy_2x/
└── ...
```

**Examples:**
```bash
# Upscale cow to 2x
python3 scripts/upscale.py ./assets/characters/cow

# Upscale sheep to 4x
python3 scripts/upscale.py ./assets/characters/sheep 4
```

### Full Example: 5-Row Character (idle/walk/happy/sleep/carried)

```bash
# Complete pipeline for 5-animation character
# Animation config: idle×4, walk×4, happy×4, sleep×2, carried×2

# 1. AI Analysis (or manual coordinates)
python3 scripts/analyze_with_gemini.py \
  character.png \
  --rows 5 \
  --names idle,walk,happy,sleep,carried \
  --frames 4,4,4,2,2

# 2. Crop to strips  
python3 scripts/crop_rows.py \
  character.png \
  ./strips/ \
  '<coords_from_step_1>'

# 3. Segment frames
python3 -u scripts/sam_segment.py \
  ./strips/ \
  '{"idle": ["idle.png", 4], "walk": ["walk.png", 4], "happy": ["happy.png", 4], "sleep": ["sleep.png", 2], "carried": ["carried.png", 2]}'

# 4. Upscale
python3 scripts/upscale.py ./strips/

# 5. Move to project
mv ./strips/*/ ./assets/characters/character/
```

### Stage 5: Organize

Move results to the project's asset directory. Typical structure:

```
assets/characters/<animal>/
├── idle/
│   ├── <animal>_idle_0.png
│   └── ...
├── walk/
├── happy/
├── sleep/
└── carried/
```

## Tips

- Always check actual image dimensions with PIL before cropping — vision models often report wrong sizes
- When coordinates come from a reference size, scale with `--ref-size`
- After SAM segmentation, spot-check a few frames to verify quality
