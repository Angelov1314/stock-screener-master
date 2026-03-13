# 🚫 BLOCKING ISSUES - QA Phase Halted

**Date:** 2025-01-15  
**Severity:** CRITICAL  
**Status:** Must be resolved before QA

---

## Issue #1: InventoryManager Direct State Violation

**Severity:** 🔴 CRITICAL  
**File:** `scripts/simulation/inventory_manager.gd`

### Problem
InventoryManager maintains its own `slots` array as a separate source of truth, bypassing both StateManager and ActionSystem. This creates a dual-source-of-truth scenario where inventory state exists in two places.

### Evidence
```gdscript
# Line 23-26 - Own state storage
var slots: Array[Dictionary] = []
var item_slots: Dictionary = {}

# Line 89-92 - Direct modification
slot.count += to_add

# Line 130-133 - Direct modification  
slots[from_slot].count -= to_move

# Line 215-220 - Empty sync
func _sync_to_state(item_id: String) -> void:
    pass  # NO-OP
```

### Impact
- Save games may not restore correct inventory state
- UI may display different values than actual game state
- Potential for inventory duplication or loss bugs

### Required Fix
```gdscript
# OPTION A: Remove internal state, delegate to StateManager
func add_item(item_id: String, count: int = 1) -> bool:
    # Route through ActionSystem
    return ActionSystem.execute("add_item", {"item_id": item_id, "amount": count})

# OPTION B: Make InventoryManager UI-only
# Rename to InventoryDisplay and remove all state
```

---

## Issue #2: CropManager Direct State Violation

**Severity:** 🔴 CRITICAL  
**File:** `scripts/simulation/crop_manager.gd`

### Problem
CropManager maintains parallel crop tracking dictionaries that bypass StateManager:

### Evidence
```gdscript
# Line 16-20 - Parallel state storage
var active_crops: Dictionary = {}  # crop_id -> CropEntity
var crop_positions: Dictionary = {}  # Vector2i -> crop_id

# Line 88-92 - Direct entity creation without StateManager
var crop_entity = CropEntity.new()
active_crops[crop_id] = crop_entity
crop_positions[position] = crop_id

# Line 165 - Direct harvest without ActionSystem
var harvest_result = crop.harvest()
```

### Impact
- Crop state in save games may not match visual state
- Harvesting may not properly update StateManager
- Crop growth timers may reset incorrectly on load

### Required Fix
```gdscript
# All crop operations must go through ActionSystem
func plant_crop(crop_type: String, position: Vector2i) -> String:
    # Use ActionSystem instead of direct creation
    var success = ActionSystem.plant(position, crop_type)
    if success:
        # Create visual only, no state storage
        return _create_crop_visual(position)
    return ""

func harvest_crop(crop_id: String) -> Dictionary:
    # Use ActionSystem instead of direct harvest
    var coord = _get_coord_for_crop(crop_id)
    if ActionSystem.harvest(coord):
        return StateManager.get_crop_at(coord)
    return {}
```

---

## Issue #3: Missing StateValidator

**Severity:** 🔴 CRITICAL  
**File:** N/A (missing)

### Problem
No StateValidator exists to validate save data on load. As per system requirements, all save data must be validated before deserialization.

### Required Implementation
Create `scripts/core/state/state_validator.gd`:

```gdscript
class_name StateValidator
extends RefCounted

const REQUIRED_FIELDS = ["inventory", "gold", "current_day"]
const MAX_GOLD = 999999
const MAX_DAY = 9999

static func is_valid(save_data: Dictionary) -> bool:
    # Check required fields
    for field in REQUIRED_FIELDS:
        if not save_data.has(field):
            push_error("Missing required field: " + field)
            return false
    
    # Validate gold
    var gold = save_data.get("gold", 0)
    if gold < 0 or gold > MAX_GOLD:
        push_error("Invalid gold amount: " + str(gold))
        return false
    
    # Validate day
    var day = save_data.get("current_day", 1)
    if day < 1 or day > MAX_DAY:
        push_error("Invalid day: " + str(day))
        return false
    
    # Validate inventory
    var inventory = save_data.get("inventory", {})
    for item_id in inventory.keys():
        if inventory[item_id] < 0:
            push_error("Negative inventory count for: " + item_id)
            return false
    
    return true

static func sanitize(save_data: Dictionary) -> Dictionary:
    # Remove invalid entries
    var cleaned = save_data.duplicate()
    # ... sanitization logic
    return cleaned
```

---

## Issue #4: Hardcoded NodePath Strings

**Severity:** 🟡 HIGH (could cause crashes)  
**Files:** 
- `scripts/core/state/action_system.gd:27`
- `scripts/simulation/inventory_manager.gd:31-33`
- `scripts/simulation/crop_manager.gd:45-47, 53-55`

### Problem
Using string-based NodePath lookup instead of typed autoload references:

```gdscript
# ❌ Fragile
_state = get_node("/root/StateManager")
_time_manager = get_node_or_null("/root/TimeManager")
```

### Required Fix
```gdscript
# ✅ Typed autoload reference (Godot 4.x)
# In project settings, ensure StateManager is registered as autoload
# Then use:
@onready var state_manager: StateManager = StateManager

# Or for lazy access with type safety:
func _get_state() -> StateManager:
    if _state == null:
        _state = StateManager  # Direct autoload reference
    return _state
```

---

## Resolution Checklist

Before QA can proceed, the following must be completed:

- [ ] **InventoryManager** refactored to use ActionSystem
- [ ] **CropManager** refactored to use ActionSystem for state changes
- [ ] **StateValidator** created and integrated into load flow
- [ ] All hardcoded NodePaths replaced with typed references
- [ ] Unit tests pass for save/load cycle
- [ ] Manual test: Plant crop → Save → Load → Verify crop exists
- [ ] Manual test: Add item → Save → Load → Verify item exists

---

## Handoff Instructions

**From:** State Authority Agent  
**To:** Simulation Agent, World/UI Agent  

### Simulation Agent Tasks:
1. Refactor `inventory_manager.gd` to remove direct state
2. Refactor `crop_manager.gd` to use ActionSystem
3. Create `state_validator.gd`

### World/UI Agent Tasks:
1. Fix hardcoded NodePaths in `farm_controller.gd`
2. Verify UI still works after simulation refactoring
3. Test save/load with new state flow

---

**DO NOT PROCEED TO QA UNTIL ALL CHECKBOXES ARE CHECKED.**
