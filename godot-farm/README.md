# Cozy Farm - Multi-Agent Godot Project

## Quick Start

```bash
# 1. Initialize project
godot --project . --editor

# 2. Run smoke tests
godot --headless --script tests/smoke_test.gd

# 3. Export debug build
godot --export-debug "Android" builds/cozy-farm.apk
```

## Agent Ownership Rules

| Agent | Can Modify | Cannot Modify |
|-------|-----------|---------------|
| **Simulation** | `scripts/simulation/*`, `scripts/systems/*` | `scenes/*`, `scripts/ui/*` |
| **Content** | `data/**/*` | Any code files |
| **World/UI** | `scenes/**/*`, `scripts/ui/*`, `assets/ui/*` | `scripts/simulation/*`, `scripts/core/*` |
| **Art** | `assets/crops/*`, `assets/environment/*` | Code, scenes |
| **Music** | `assets/audio/**/*` | Everything else |
| **State** | `docs/state/*`, `tests/state/*` | Creates audit reports only |
| **QA** | `tests/**/*`, `docs/bugs/*` | Creates test reports only |

## State Truth Sources

| Data | Source | Access |
|------|--------|--------|
| Inventory | `StateManager.inventory` | Read via `get_inventory()` |
| Gold | `StateManager.gold` | Read via `get_gold()` |
| Crops | `StateManager.planted_crops` | Read via `get_crop_at()` |
| Time | `StateManager.current_time` | Via `ActionSystem` only |

## Critical Rules

1. **NEVER** modify state directly - always use `ActionSystem.execute()`
2. **NEVER** use hardcoded NodePath - use `@onready %NodeName` or signals
3. **ALWAYS** emit signals for state changes
4. **ALWAYS** validate preconditions before actions

## Project Structure

```
├── scripts/
│   ├── core/state/       # State management (truth sources)
│   ├── simulation/       # Gameplay systems
│   ├── systems/          # Audio, Save, Economy
│   ├── ui/              # UI controllers
│   └── entities/        # Crop, Soil, NPC classes
├── scenes/
│   ├── ui/              # Menus, HUD, panels
│   ├── world/           # Farm, environment
│   └── gameplay/        # Interactive scenes
├── data/
│   ├── crops/           # Crop definitions (JSON)
│   ├── shops/           # Shop inventory
│   └── orders/          # Order requirements
├── assets/
│   ├── crops/           # 32x32 sprites
│   ├── ui/              # Icons, buttons
│   ├── environment/     # Tiles, decorations
│   └── audio/           # Music and SFX
└── tests/
    ├── smoke/           # Basic functionality
    ├── state/           # Consistency tests
    └── integration/     # Multi-system tests
```

## Development Workflow

1. **Orchestrator** creates task plan
2. **Content** defines crop/shop data
3. **Simulation** implements core systems
4. **Art** generates sprites (32x32px, transparent)
5. **World/UI** assembles scenes
6. **Music** adds audio
7. **State** reviews all code
8. **QA** runs tests

## Asset Naming Convention

```
assets/crops/{crop_id}_{stage}.png
  - carrot_seed.png
  - carrot_sprout.png
  - carrot_growing.png
  - carrot_mature.png

assets/ui/{category}_{name}.png
  - button_close.png
  - icon_gold.png
  - panel_inventory.png
```

## Handoff Protocol

When an agent completes work, write to `handoff/{agent}_complete.json`:

```json
{
  "agent": "simulation",
  "outputs": [
    "scripts/simulation/crop_manager.gd",
    "scripts/simulation/inventory_manager.gd"
  ],
  "signals": ["crop_matured", "inventory_changed"],
  "handoff_to": ["world_ui"],
  "notes": "Ready for UI integration"
}
```

## Save/Load Format

```json
{
  "version": "1.0",
  "timestamp": 1234567890,
  "state": {
    "inventory": {"carrot": 5, "tomato": 3},
    "gold": 150,
    "current_day": 5,
    "planted_crops": {
      "(2,3)": {"crop_id": "carrot", "stage": 2, "watered": true}
    }
  }
}
```
