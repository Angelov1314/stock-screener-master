---
name: sam-segmentation
 description: |
  SAM (Segment Anything Model) based image segmentation pipeline.
  Automatically detects and extracts objects from sprite sheets with background removal.
  Outputs centered, transparent PNG sprites ready for game use.

  Features:
  - Automatic object detection using SAM or fallback contour detection
  - Background removal (white/gray to transparent)
  - Auto-centering on canvas
  - Batch processing for sprite sheets
  - Configurable output size and padding
---

# SAM Segmentation Pipeline

Automatic object extraction from sprite sheets using Meta's Segment Anything Model (SAM).

## Features

- 🤖 **SAM-powered detection** - Uses Meta's SAM for precise object segmentation
- 🎯 **Smart fallback** - Falls back to contour detection if SAM unavailable
- 🖼️ **Background removal** - Automatically removes white/gray backgrounds
- 📐 **Auto-centering** - Centers objects on transparent canvas
- 📦 **Batch processing** - Handles multiple sprites in one run

## Requirements

```bash
pip install torch torchvision opencv-python numpy pillow segment-anything
```

## Quick Start

### 1. Basic Usage

```python
from sam_segment import segment_sprite_sheet

# Process a sprite sheet
segment_sprite_sheet(
    input_path="path/to/sheet.jpg",
    output_dir="path/to/output",
    names=["pig", "chick", "sheep"]
)
```

### 2. Command Line

```bash
python3 sam_segment.py \
  --input animals_sheet.jpg \
  --output ./output \
  --names pig,chick,sheep
```

## Pipeline Steps

### Step 1: Load Image
```python
img = Image.open(input_path).convert("RGB")
```

### Step 2: Detect Objects (SAM)
```python
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator

sam = sam_model_registry["vit_h"](checkpoint="sam_vit_h.pth")
mask_generator = SamAutomaticMaskGenerator(sam)
masks = mask_generator.generate(image_np)
```

### Step 3: Filter by Size
```python
# Filter masks by area
valid_masks = [
    m for m in masks 
    if 50000 < m['area'] < 500000  # Adjust thresholds
]
```

### Step 4: Extract with Transparency
```python
# Create RGBA with mask as alpha
rgba = np.zeros((h, w, 4), dtype=np.uint8)
rgba[:, :, :3] = image_np
rgba[:, :, 3] = mask.astype(np.uint8) * 255
```

### Step 5: Center on Canvas
```python
def center_object(img, target_size=256):
    # Find content bounds from alpha
    alpha = np.array(img)[:, :, 3]
    coords = np.where(alpha > 10)
    
    # Crop to content
    y_min, y_max = coords[0].min(), coords[0].max()
    x_min, x_max = coords[1].min(), coords[1].max()
    img = img.crop((x_min, y_min, x_max, y_max))
    
    # Scale to fit with padding
    scale = min((target_size - 60) / img.width, 
                (target_size - 60) / img.height)
    img = img.resize((int(img.width * scale), 
                      int(img.height * scale)))
    
    # Center on canvas
    canvas = Image.new('RGBA', (target_size, target_size), 
                       (0, 0, 0, 0))
    x = (target_size - img.width) // 2
    y = (target_size - img.height) // 2
    canvas.paste(img, (x, y), img)
    
    return canvas
```

## Configuration

### SAM Model Download
```bash
# Auto-downloaded on first run to:
~/.cache/sam/sam_vit_h.pth

# Or manual download:
curl -L 'https://dl.fbaipublicfiles.com/segment_anything/sam_vit_h_4b8939.pth' \
  -o ~/.cache/sam/sam_vit_h.pth
```

### Area Thresholds

| Object Type | Min Area | Max Area |
|-------------|----------|----------|
| Small icons | 10,000 | 50,000 |
| Characters | 50,000 | 200,000 |
| Large props | 100,000 | 500,000 |

### Output Sizes

| Use Case | Size | Padding |
|----------|------|---------|
| UI icons | 128x128 | 20px |
| Game sprites | 256x256 | 30px |
| High-res | 512x512 | 60px |

## Fallback Method

When SAM is unavailable, uses adaptive thresholding:

```python
# Adaptive thresholding
binary = cv2.adaptiveThreshold(
    gray, 255,
    cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
    cv2.THRESH_BINARY_INV,
    11, 2
)

# Morphological cleanup
kernel = np.ones((3, 3), np.uint8)
cleaned = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)

# Contour detection
contours, _ = cv2.findContours(
    cleaned, 
    cv2.RETR_EXTERNAL, 
    cv2.CHAIN_APPROX_SIMPLE
)
```

## Examples

### Example 1: Animal Sprite Sheet
```python
segment_sprite_sheet(
    "animals_sheet.jpg",
    "./output/animals",
    ["pig", "chick", "sheep"],
    min_area=50000,
    max_area=200000
)
```

### Example 2: Props Sheet
```python
segment_sprite_sheet(
    "props_sheet.jpg", 
    "./output/props",
    ["sign", "watering_can", "gift_box"],
    min_area=30000,
    output_size=256
)
```

### Example 3: UI Icons
```python
segment_sprite_sheet(
    "ui_icons.jpg",
    "./output/ui",
    ["play", "pause", "settings"],
    min_area=10000,
    output_size=128,
    padding=20
)
```

## Troubleshooting

### SAM Model Too Slow
- Use `vit_b` instead of `vit_h` for faster inference
- Or use fallback contour detection

### Objects Not Detected
- Adjust `min_area` and `max_area` thresholds
- Check image contrast
- Try fallback method

### Background Not Removed
- Adjust `threshold` in `remove_white_bg()`
- Use color-based masking instead of threshold
- Manual cleanup with image editor

### Objects Off-Center
- Increase `padding` value
- Check alpha channel detection threshold
- Adjust `target_size`

## Advanced: Custom Background Removal

```python
def remove_background_custom(img, bg_color=(255, 255, 255), tolerance=30):
    """Remove specific background color"""
    data = np.array(img)
    r, g, b = data.T[:, :3].T
    
    # Calculate distance from bg_color
    dist = np.sqrt(
        (r - bg_color[0])**2 +
        (g - bg_color[1])**2 +
        (b - bg_color[2])**2
    )
    
    # Set transparent if within tolerance
    data[dist < tolerance, 3] = 0
    return Image.fromarray(data)
```

## References

- [SAM GitHub](https://github.com/facebookresearch/segment-anything)
- [SAM Paper](https://arxiv.org/abs/2304.02643)
- Meta AI Research

---

Created: 2026-03-07
Version: 1.0
Author: OpenClaw
