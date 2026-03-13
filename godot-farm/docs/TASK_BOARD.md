# Farm Game Development - Task Board

## Sprint 1: Core Loop (Week 1)

### Task 1.1: Crop Data Definition
**Agent**: Content/Data
**Priority**: High
**Dependencies**: None

Create crop definitions for 5 starter crops:
- Carrot (3 days, 15 gold sell price) - Beginner friendly
- Wheat (2 days, 10 gold sell price) - Fast growing
- Tomato (5 days, 30 gold sell price) - High value
- Strawberry (4 days, 25 gold sell price) - Multi-harvest
- Corn (6 days, 40 gold sell price) - Premium crop

**Output**:
- `data/crops/carrot.json`
- `data/crops/wheat.json`
- `data/crops/tomato.json`
- `data/crops/strawberry.json`
- `data/crops/corn.json`

**Acceptance Criteria**:
- [ ] Each crop has 5 growth stages
- [ ] Prices balanced (seed cost < sell price)
- [ ] All fields validated against schema

---

### Task 1.2: Core State System
**Agent**: State Authority + Simulation
**Priority**: Critical
**Dependencies**: None

Implement the state management foundation.

**Output**:
- `scripts/core/state/state_manager.gd` (truth source)
- `scripts/core/state/action_system.gd` (action queue)

**Acceptance Criteria**:
- [ ] StateManager is singleton
- [ ] All state changes go through ActionSystem
- [ ] Save/load serializes all state
- [ ] State Authority approves architecture

---

### Task 1.3: Time & Growth System
**Agent**: Simulation
**Priority**: High
**Dependencies**: 1.2

Implement day/night cycle and crop growth.

**Output**:
- `scripts/simulation/time_manager.gd`
- `scripts/simulation/crop_manager.gd`

**Acceptance Criteria**:
- [ ] Time advances when player sleeps
- [ ] Crops grow based on time + water
- [ ] Growth stages sync with art assets

---

### Task 1.4: Inventory & Economy
**Agent**: Simulation
**Priority**: High
**Dependencies**: 1.2

Implement inventory and gold management.

**Output**:
- `scripts/simulation/inventory_manager.gd`
- `scripts/systems/economy_manager.gd`

**Acceptance Criteria**:
- [ ] Can add/remove items
- [ ] Inventory has capacity limit
- [ ] Gold transactions validated
- [ ] Shop prices loaded from data

---

### Task 1.5: Crop Sprites
**Agent**: Art Pipeline
**Priority**: High
**Dependencies**: 1.1

Generate hand-drawn illustration sprites for 5 crops (4 stages each = 20 sprites).

**Output**:
- `assets/crops/carrot_{stage}.png` (4 files: seed, sprout, growing, mature)
- `assets/crops/wheat_{stage}.png` (4 files)
- `assets/crops/tomato_{stage}.png` (4 files)
- `assets/crops/strawberry_{stage}.png` (4 files)
- `assets/crops/corn_{stage}.png` (4 files)
- `data/asset_manifest.json`

**Style Reference**: Hand-drawn storybook/cartoon style like Tsuki Adventure, Cats & Soup

**Acceptance Criteria**:
- [ ] 64x64px (or 128x128 for hi-res) transparent PNG
- [ ] Dark warm-brown outlines (#3B2B1A), hand-drawn feel
- [ ] Flat muted colors, warm palette (sage green, soft orange, warm brown)
- [ ] Pivot at bottom-center
- [ ] Consistent storybook aesthetic across all crops
- [ ] Manifest includes all metadata

---

### Task 1.6: Farm Scene
**Agent**: World/UI
**Priority**: High
**Dependencies**: 1.3, 1.5

Create the main farm scene with interactable tiles.

**Output**:
- `scenes/world/farm.tscn`
- `scripts/ui/farm_controller.gd`

**Acceptance Criteria**:
- [ ] Grid of plantable tiles
- [ ] Click to plant/water/harvest
- [ ] Visual feedback on hover
- [ ] Syncs with CropManager state

---

### Task 1.7: HUD & Inventory UI
**Agent**: World/UI
**Priority**: Medium
**Dependencies**: 1.4

Create heads-up display and inventory panel.

**Output**:
- `scenes/ui/hud.tscn`
- `scenes/ui/inventory_panel.tscn`
- `scripts/ui/hud_controller.gd`

**Acceptance Criteria**:
- [ ] Gold display updates in real-time
- [ ] Inventory button opens panel
- [ ] Item counts accurate
- [ ] Mobile-friendly touch targets

---

### Task 1.8: Audio System
**Agent**: Music/Sound
**Priority**: Medium
**Dependencies**: None

Create background ambience and SFX.

**Output**:
- `assets/audio/music/ambient_farm.ogg`
- `assets/audio/sfx/plant.wav`
- `assets/audio/sfx/water.wav`
- `assets/audio/sfx/harvest.wav`
- `assets/audio/sfx/sell.wav`
- `scripts/systems/audio_manager.gd`

**Acceptance Criteria**:
- [ ] Background music loops seamlessly
- [ ] SFX trigger at correct moments
- [ ] Volume levels balanced (BGM 40%, SFX 60%)
- [ ] ASMR-quality (soft, satisfying)

---

### Task 1.9: State Review
**Agent**: State Authority
**Priority**: Critical
**Dependencies**: 1.2, 1.3, 1.4

Review all code for state consistency.

**Output**:
- `docs/state/audit_report_sprint1.md`
- `docs/state/BLOCKING_ISSUES.md` (if any)

**Acceptance Criteria**:
- [ ] No direct state modifications found
- [ ] All actions validated
- [ ] Save/load tested
- [ ] Truth sources documented

---

### Task 1.10: QA & Smoke Tests
**Agent**: QA/Debug
**Priority**: Critical
**Dependencies**: 1.6, 1.7, 1.8

Run smoke tests and validate build.

**Output**:
- `tests/smoke/core_loop.test.gd`
- `docs/qa/sprint1_report.md`

**Test Cases**:
- [ ] Plant → Water → Wait → Harvest → Sell
- [ ] Inventory full blocks new items
- [ ] Save → Quit → Load (state identical)
- [ ] No console errors
- [ ] 60 FPS on target device

---

## Definition of Done

Sprint 1 is complete when:
1. Player can plant, water, harvest, sell 5 crop types
2. Inventory and gold persist correctly
3. All scenes open without errors
4. State Authority approves architecture
5. QA passes all smoke tests
6. Runs at 60 FPS on target mobile device

## Next Sprint Preview

**Sprint 2**: Polish & Progression
- Shop system
- Tool upgrades
- More crops
- Basic tutorial
- Settings menu
