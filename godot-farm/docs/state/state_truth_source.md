# State Truth Source - Single Source of Truth Reference

> **Rule**: Every piece of game state has exactly ONE owner. All reads go through getters. All writes go through `ActionSystem.execute()`.

## Truth Source Table

| State | Truth Source | Access Pattern | Modification Pattern |
|-------|-------------|----------------|---------------------|
| Gold | `StateManager.gold` | `StateManager.get_gold()` | `ActionSystem.execute("add_gold", {...})` |
| Inventory | `StateManager.inventory` | `StateManager.get_inventory()` | `ActionSystem.execute("add_item", {...})` |
| Planted Crops | `StateManager.planted_crops` | `StateManager.get_crop_at(coord)` | `ActionSystem.execute("plant_crop", {...})` |
| Current Day | `StateManager.current_day` | Direct read (autoload) | `ActionSystem.execute("advance_time", {...})` |
| Current Time | `StateManager.current_time` | Direct read (autoload) | `ActionSystem.execute("advance_time", {...})` |

## Autoload Order (Critical)

1. **StateManager** — Must load first. Holds all persistent state.
2. **ActionSystem** — Depends on StateManager. Routes all mutations.
3. **TimeManager** — Depends on ActionSystem for time advancement.
4. **EconomyManager** — Depends on StateManager for gold reads.
5. **InventoryManager** — Depends on StateManager for inventory reads.
6. **CropManager** — Depends on StateManager + ActionSystem.
7. **AudioManager** — No state dependencies, listens to signals.
8. **SaveManager** — Depends on StateManager for serialize/deserialize.

## Forbidden Patterns

```gdscript
# ❌ Direct state mutation
StateManager.gold += 100

# ❌ UI writing state
func _on_button():
    StateManager.inventory["seed"] = 5

# ❌ Bypassing ActionSystem
StateManager.apply_action({"type": "add_gold", "amount": 100})  # Only ActionSystem calls this
```

## Correct Pattern

```gdscript
# ✅ All mutations through ActionSystem
ActionSystem.execute("add_gold", {"amount": 100})

# ✅ UI reads state, never writes
var gold = StateManager.get_gold()
label.text = str(gold)

# ✅ UI listens to signals for updates
ActionSystem.gold_changed.connect(_on_gold_changed)
```

## Save/Load Flow

1. `SaveManager` calls `StateManager.serialize()` → Dictionary
2. Dictionary written to disk as JSON
3. On load: JSON → Dictionary → `StateManager.deserialize(data)`
4. `StateManager` emits `state_loaded` signal
5. All systems refresh from StateManager getters
