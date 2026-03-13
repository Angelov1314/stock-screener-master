extends Node

## State Authority - Single Source of Truth
## This is the ONLY place where persistent game state lives

## Signals - MUST be declared at top for GDScript
signal state_changed(action: Dictionary)
signal state_loaded

# Truth sources
var inventory: Dictionary = {}  # item_id -> count
var gold: int = 0
var current_day: int = 1
var current_time: float = 6.0  # 24h format
var planted_crops: Dictionary = {}  # tile_coord -> crop_data

# Session data storage (for passing data between scenes)
var _session_data: Dictionary = {}

# State change history (for debugging/rollback)
var _action_history: Array = []

func _ready():
    print("[StateManager] Initialized as truth source")

## Session data storage - for passing data between scenes
func set_data(key: String, value) -> void:
    _session_data[key] = value

func get_data(key: String, default_value = null):
    return _session_data.get(key, default_value)

## Getters - these are the ONLY way to read state
func get_inventory() -> Dictionary:
    return inventory.duplicate()

func get_gold() -> int:
    return gold

func get_crop_at(coord: Vector2i) -> Dictionary:
    return planted_crops.get(coord, {})

## State modification - ONLY through ActionSystem
func apply_action(action: Dictionary) -> bool:
    # Validate action
    if not _validate_action(action):
        push_error("[StateManager] Invalid action: " + str(action))
        return false
    
    # Create backup for rollback
    var backup = serialize()
    
    # Apply based on action type
    var success = _apply_internal(action)
    
    if success:
        _action_history.append(action)
        emit_signal("state_changed", action)
        return true
    else:
        # Rollback on failure
        deserialize(backup)
        return false

func _apply_internal(action: Dictionary) -> bool:
    match action.type:
        "add_gold":
            gold += action.amount
        "remove_gold":
            if gold >= action.amount:
                gold -= action.amount
            else:
                return false
        "add_item":
            inventory[action.item_id] = inventory.get(action.item_id, 0) + action.amount
        "remove_item":
            if inventory.get(action.item_id, 0) >= action.amount:
                inventory[action.item_id] -= action.amount
            else:
                return false
        "plant_crop":
            planted_crops[action.coord] = {
                "crop_id": action.crop_id,
                "planted_day": current_day,
                "planted_time": current_time,
                "growth_stage": 0,
                "watered": false
            }
        "water_crop":
            if action.coord in planted_crops:
                planted_crops[action.coord].watered = true
        "advance_growth":
            if action.coord in planted_crops:
                planted_crops[action.coord].growth_stage += 1
        "harvest_crop":
            if action.coord in planted_crops:
                var crop_data = planted_crops[action.coord]
                # Check if mature (growth_stage >= 3)
                if crop_data.growth_stage < 3:
                    return false
                # Add harvest result to inventory
                inventory[crop_data.crop_id] = inventory.get(crop_data.crop_id, 0) + 1
                planted_crops.erase(action.coord)
            else:
                return false
        "advance_time":
            current_time += action.hours
            if current_time >= 24.0:
                current_time -= 24.0
                current_day += 1
        _:
            push_error("[StateManager] Unknown action type: " + action.type)
            return false
    
    return true

func _validate_action(action: Dictionary) -> bool:
    if not action.has("type"):
        return false
    return true

## Serialization for save/load
func serialize() -> Dictionary:
    return {
        "inventory": inventory.duplicate(),
        "gold": gold,
        "current_day": current_day,
        "current_time": current_time,
        "planted_crops": planted_crops.duplicate()
    }

func deserialize(data: Dictionary) -> bool:
    if not data.has_all(["inventory", "gold", "current_day"]):
        return false
    
    inventory = data.inventory.duplicate()
    gold = data.gold
    current_day = data.current_day
    current_time = data.get("current_time", 6.0)
    planted_crops = data.get("planted_crops", {}).duplicate()
    
    emit_signal("state_loaded")
    return true

## Utility: Create snapshot for undo
func create_snapshot() -> Dictionary:
    return serialize()

## Utility: Restore snapshot
func restore_snapshot(data: Dictionary) -> bool:
    return deserialize(data)
