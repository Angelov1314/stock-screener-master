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

### Stage 1: Get Row Coordinates

If the user provides coordinates, use them directly.

Otherwise, use a vision model to analyze the spritesheet. Prompt:

> 这个图含有N行精灵图：[describe rows]. 需要裁剪成N行，请告诉我裁剪的坐标。以整张图像素为基准，原点在左上角，格式是 (left, top) - (right, bottom)。建议按整行裁剪。

Note the **reference size** the coordinates are based on — it may differ from actual image dimensions.

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
