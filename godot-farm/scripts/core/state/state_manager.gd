extends Node

## State Authority - Single Source of Truth
## This is the ONLY place where persistent game state lives

## Signals - MUST be declared at top for GDScript
signal state_changed(action: Dictionary)
signal state_loaded

# Truth sources
var player_name: String = "农场主"
var inventory: Dictionary = {}  # item_id -> count
var gold: int = 0
var experience: int = 0
var player_level: int = 1
var current_day: int = 1
var current_time: float = 6.0  # 24h format
var planted_crops: Dictionary = {}  # tile_coord -> crop_data

# Experience required for each level (incremental curve: +25 XP each level)
const BASE_XP_PER_LEVEL := 100
const XP_INCREMENT_PER_LEVEL := 25

# Session data storage (for passing data between scenes)
var _session_data: Dictionary = {}

# State change history (for debugging/rollback)
var _action_history: Array = []

func _ready():
    print("[StateManager] Initialized as truth source")
    # Set initial values
    gold = 300
    player_name = "农场主"
    experience = 0
    player_level = 1

## Session data storage - for passing data between scenes
func set_data(key: String, value) -> void:
    _session_data[key] = value

func get_data(key: String, default_value = null):
    return _session_data.get(key, default_value)

## Getters - these are the ONLY way to read state
func get_player_name() -> String:
    return player_name

func get_inventory() -> Dictionary:
    return inventory.duplicate()

func get_gold() -> int:
    return gold

func get_experience() -> int:
    return experience

func get_player_level() -> int:
    return player_level

func get_crop_at(coord: Vector2i) -> Dictionary:
    return planted_crops.get(coord, {})

func _get_total_xp_required_for_level(level: int) -> int:
    if level <= 1:
        return 0
    var total := 0
    for l in range(1, level):
        total += BASE_XP_PER_LEVEL + (l - 1) * XP_INCREMENT_PER_LEVEL
    return total

func get_xp_for_next_level() -> int:
    return _get_total_xp_required_for_level(player_level + 1)

func get_xp_progress() -> float:
    var current_level_xp = _get_total_xp_required_for_level(player_level)
    var next_level_xp = get_xp_for_next_level()
    var xp_in_level = experience - current_level_xp
    var xp_needed = next_level_xp - current_level_xp
    return float(xp_in_level) / float(xp_needed) if xp_needed > 0 else 1.0

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
        "set_player_name":
            player_name = action.name
        "add_gold":
            gold += action.amount
        "remove_gold":
            if gold >= action.amount:
                gold -= action.amount
            else:
                return false
        "add_experience":
            experience += action.amount
            _check_level_up()
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
                # Add experience for harvesting
                experience += 10
                _check_level_up()
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

func _check_level_up():
    var audio_mgr = get_node_or_null("/root/AudioManager")
    var leveled_up = false
    var next_level_xp = get_xp_for_next_level()
    while experience >= next_level_xp:
        player_level += 1
        leveled_up = true
        print("[StateManager] Level up! Now level %d" % player_level)
        next_level_xp = get_xp_for_next_level()
    if leveled_up and audio_mgr:
        audio_mgr.play_sfx_path("res://assets/audio/sfx/ui/level_up.mp3", 1.0)

func _validate_action(action: Dictionary) -> bool:
    if not action.has("type"):
        return false
    return true

## Serialization for save/load
func serialize() -> Dictionary:
    return {
        "player_name": player_name,
        "inventory": inventory.duplicate(),
        "gold": gold,
        "experience": experience,
        "player_level": player_level,
        "current_day": current_day,
        "current_time": current_time,
        "planted_crops": planted_crops.duplicate()
    }

func deserialize(data: Dictionary) -> bool:
    if not data.has_all(["inventory", "gold", "current_day"]):
        return false
    
    player_name = data.get("player_name", "农场主")
    inventory = data.inventory.duplicate()
    gold = data.gold
    experience = data.get("experience", 0)
    player_level = data.get("player_level", 1)
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
