# Art Style Reference - Cozy Farm

## Visual Reference Image Analysis

**Based on**: User reference image (mobile farm game screenshot)
**Target Aesthetic**: Hand-drawn storybook / cozy mobile farm game

---

## Style Definition

### Overall Look
- **Hand-drawn illustration** (NOT pixel art)
- **Storybook/cartoon** aesthetic
- **Top-down/bird's eye view** with slight perspective
- **Warm, cozy, vintage** feeling

### Line Work
- **Dark warm-brown outlines** (#3B2B1A) - NOT pure black
- **Consistent 2-3px weight**, slightly irregular/hand-drawn
- **Organic, slightly wobbly** lines for charm
- Thicker on large objects, thinner on details

### Coloring
- **Flat color fills** - minimal to no gradients
- **Muted, desaturated** palette
- **Warm tones** throughout

---

## Color Palette

| Element | Hex Code | Description |
|---------|----------|-------------|
| **Outline** | #3B2B1A | Dark warm brown |
| **Grass** | #7A9E7E | Sage/muted olive green |
| **Soil** | #8B5A3C | Warm chocolate brown |
| **Path** | #D4C4A8 | Sandy khaki beige |
| **Carrot** | #E8913A | Muted orange |
| **Tomato** | #C94C4C | Warm red |
| **Wheat** | #D4A84B | Golden yellow |
| **Strawberry** | #E85D5D | Soft red-pink |
| **Corn** | #F4D03F | Rich golden |
| **Green leaves** | #6B8E6B | Sage green |
| **Barn red** | #A54A4A | Muted barn red |
| **Wood** | #C4A77D | Light warm tan |

**Rule**: All colors should feel slightly "vintage" or "washed in warm sunlight"

---

## Crop Sprite Specifications

### Dimensions
- **Base size**: 64x64px (or 128x128 for high-res)
- **Format**: PNG with transparency
- **Pivot**: Bottom-center for ground placement

### Growth Stages (4 stages)

#### Stage 1: Seed
- Small mound of soil
- Tiny sprout barely visible
- Mostly brown (soil) with hint of green

#### Stage 2: Sprout  
- Visible seedling with 2-4 small leaves
- Stem is thin and delicate
- About 1/4 of final height

#### Stage 3: Growing
- Bushy, full foliage
- Crop body forming but not ripe
- About 3/4 of final size
- Leaves are prominent

#### Stage 4: Mature
- Fully formed crop body (fruit/vegetable visible)
- Rich, saturated colors (within muted palette)
- Maximum size
- Ready to harvest appearance

---

## Crop-Specific Details

### Carrot
- **Top**: Feathery green leaves (like dill)
- **Body**: Tapered orange cone, mostly hidden underground
- **Visible**: Orange top peeking from soil

### Wheat
- **Stalks**: Golden-yellow, tall and thin
- **Heads**: Wheat grain clusters at top
- **Movement**: Slight sway in wind (if animated)

### Tomato
- **Plant**: Bushy green with small yellow flowers
- **Fruit**: Round red tomatoes clustered on vine
- **Stages**: Green → Yellow → Red (in mature stage)

### Strawberry
- **Plant**: Low-growing with trifoliate leaves
- **Fruit**: Red, conical, with green leafy cap
- **Feature**: Small white/yellow seeds on surface
- **Special**: Can show multiple berry sizes

### Corn
- **Stalk**: Tall green with visible nodes
- **Leaves**: Long, arching green blades
- **Ears**: Yellow corn with green husks partially peeled
- **Height**: Tallest crop

---

## Background/Environment Elements

### Ground Tiles
- **Grass**: Soft sage green, slightly textured
- **Soil**: Warm brown, may show subtle furrow lines
- **Path**: Sandy beige, could have stone/pebble details

### Fences
- **Style**: Wooden post-and-rail
- **Color**: Light warm tan
- **Detail**: Visible wood grain, slightly weathered
- **Corner posts**: Thicker with visible post caps

### Barn (if included)
- **Color**: Classic muted red
- **Roof**: Blue-gray or slate
- **Details**: White X-pattern doors

---

## UI Elements

### Frame/Border
- **Texture**: Wood grain texture
- **Color**: Warm brown family
- **Style**: Hand-drawn, slightly rustic

### Buttons/Icons
- **Shape**: Rounded rectangles or circles
- **Style**: Skeuomorphic (look like real objects)
- **Examples**: Watering can, shovel, seed bag, coin stack

### Font Pairing (if text)
- **Style**: Rounded, friendly, slightly handwritten
- **Examples**: Nunito, Quicksand, or custom hand-drawn

---

## Animation Style

Since this is illustration-based (not pixel art):

### Subtle Animations
- **Idle bounce**: Gentle up-down bob (2-3 pixels)
- **Sway**: Wheat/corn leaves sway slightly
- **Sparkle**: Occasional sparkle on mature crops
- **Growth**: Frame-based or smooth tween between stages

### No Pixel Animation
- Use **tweening** and **transformation**
- **Scale, rotate, position** changes
- **Opacity fades** for sparkles

---

## Reference Games

Closest aesthetic matches:
1. **Tsuki Adventure / Tsuki's Odyssey** - Exact match
2. **Cats & Soup** - Similar cozy hand-drawn style
3. **Adorable Home** - Same warmth and simplicity
4. **Story of Seasons: Pioneers of Olive Town** (mobile) - Farm layout
5. **Harvest Town** - Top-down farm structure

---

## Prompt Template for Image Generation

```
{crop_name} at {growth_stage} stage of growth, 
hand-drawn cartoon illustration for mobile farm game,
dark warm-brown outlines (#3B2B1A), 
flat muted colors with sage green and soft orange tones,
top-down view with slight perspective,
cozy storybook children's book aesthetic,
reference: Tsuki Adventure art style,
transparent background, centered composition,
64x64px sprite, single object, no ground plane
```

---

## Quality Checklist

Before approving any art asset:

- [ ] Has warm-brown outline (not pure black)
- [ ] Colors are muted/desaturated (not neon/bright)
- [ ] Flat coloring (no gradients or minimal)
- [ ] Hand-drawn feel (not geometric/perfect)
- [ ] Consistent with other crop sprites
- [ ] Properly sized (64x64 or 128x128)
- [ ] Transparent background
- [ ] Pivot point at bottom-center
- [ ] Matches reference aesthetic
