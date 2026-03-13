# Agent System Diagram - Art Specification

## Overview
Hand-drawn storybook style diagram showing the 8-agent farm game system architecture.

## Style Requirements
- **Style**: Hand-drawn illustration (NOT pixel art)
- **Outlines**: Dark warm-brown (#3B2B1A), slightly irregular
- **Colors**: Flat muted, warm palette
- **Aesthetic**: Tsuki Adventure, cozy, nostalgic
- **Background**: Soft cream/beige paper texture

## Layout (512x512px canvas)

### Center Node (Largest)
- **Label**: "Orchestrator"
- **Icon**: Conductor's baton or central hub symbol
- **Size**: ~80x80px
- **Color**: Warm orange/peach

### Surrounding Nodes (7 smaller nodes, ~50x50px each)

Arranged in circle around center:

1. **Content** (Top)
   - Icon: Seed packet or document
   - Color: Sage green
   - Label: "Content"

2. **Simulation** (Top-Right)
   - Icon: Gear or clock
   - Color: Soft blue
   - Label: "Sim"

3. **Art** (Right)
   - Icon: Paintbrush or palette
   - Color: Warm pink
   - Label: "Art"

4. **Music** (Bottom-Right)
   - Icon: Musical note
   - Color: Soft purple
   - Label: "Music"

5. **World/UI** (Bottom)
   - Icon: Window or screen
   - Color: Soft yellow
   - Label: "UI"

6. **State** (Bottom-Left)
   - Icon: Shield or checkmark
   - Color: Warm brown
   - Label: "State"

7. **QA** (Left)
   - Icon: Magnifying glass
   - Color: Soft teal
   - Label: "QA"

### Connections

**Solid Arrows** (from Orchestrator to each agent):
- Thick warm-brown lines
- Arrow points from center to each node
- Shows command/control flow

**Dotted Lines** (collaboration):
- Dotted warm-brown lines between:
  - Content ↔ Simulation
  - Art → World/UI
  - Simulation → World/UI
  - World/UI → State
  - All → QA

### Decorative Elements
- Small carrots at corners
- Wheat stalks as dividers
- Tiny stars/sparkles around connections
- Hand-drawn "paper" texture background

## Text Labels
- All text hand-drawn style
- Friendly rounded lettering
- Dark brown color

## Color Palette

| Element | Hex |
|---------|-----|
| Outlines | #3B2B1A |
| Orchestrator | #F4D03F (golden) |
| Content | #7A9E7E (sage) |
| Simulation | #85C1E9 (soft blue) |
| Art | #F5B7B1 (soft pink) |
| Music | #D7BDE2 (soft purple) |
| World/UI | #F9E79F (soft yellow) |
| State | #D35400 (warm brown) |
| QA | #76D7C4 (soft teal) |
| Background | #F5F5DC (cream) |

## Generation Prompt

```
Multi-agent system diagram for farm game, hand-drawn storybook illustration,
central "Orchestrator" node with 7 surrounding nodes (Content, Sim, Art, Music, UI, State, QA),
warm-brown outlines (#3B2B1A), flat muted colors, cozy cottagecore aesthetic,
Tsuki Adventure art style, paper texture background,
arrow connections between nodes, small farm decorations (carrots, wheat),
children's book illustration style, charming and cozy
```

## Output
Save as: `assets/ui/agent_system_diagram.png`
Size: 512x512px
Format: PNG with transparency (if needed) or solid cream background
