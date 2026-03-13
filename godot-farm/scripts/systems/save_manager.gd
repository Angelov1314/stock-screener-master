extends Node

## Manages game save/load using StateManager as truth source
## Uses JSON files in user:// directory

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(reason: String)
signal load_failed(reason: String)

const SAVE_DIR := "user://saves/"
const SAVE_VERSION := "1.0"
const MAX_SLOTS := 3

var _auto_save_timer: Timer = null
@export var auto_save_interval: float = 300.0  # 5 minutes

func _ready():
	print("[SaveManager] Initialized")
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	
	# Setup auto-save timer
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = auto_save_interval
	_auto_save_timer.timeout.connect(_on_auto_save)
	_auto_save_timer.autostart = true
	add_child(_auto_save_timer)

## Save game to slot
func save_game(slot: int = 0) -> bool:
	var state_mgr = get_node_or_null("/root/StateManager")
	var economy_mgr = get_node_or_null("/root/EconomyManager")
	var time_mgr = get_node_or_null("/root/TimeManager")
	
	if state_mgr == null:
		emit_signal("save_failed", "StateManager not found")
		return false
	
	var save_data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"slot": slot,
		"state": state_mgr.serialize(),
	}
	
	# Add economy data if available
	if economy_mgr and economy_mgr.has_method("get_save_data"):
		save_data["economy"] = economy_mgr.get_save_data()
	
	# Add time data if available
	if time_mgr and time_mgr.has_method("get_save_data"):
		save_data["time"] = time_mgr.get_save_data()
	
	var path = _get_save_path(slot)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err = FileAccess.get_open_error()
		emit_signal("save_failed", "Cannot open file: %s" % error_string(err))
		return false
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	
	print("[SaveManager] Game saved to slot %d" % slot)
	emit_signal("save_completed", slot)
	return true

## Load game from slot
func load_game(slot: int = 0) -> bool:
	var path = _get_save_path(slot)
	
	if not FileAccess.file_exists(path):
		emit_signal("load_failed", "Save file not found")
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		emit_signal("load_failed", "Cannot open save file")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_string)
	if err != OK:
		emit_signal("load_failed", "Invalid save data")
		return false
	
	var save_data: Dictionary = json.data
	
	# Version check
	if save_data.get("version", "") != SAVE_VERSION:
		push_warning("[SaveManager] Save version mismatch, attempting load anyway")
	
	# Restore state
	var state_mgr = get_node_or_null("/root/StateManager")
	if state_mgr and save_data.has("state"):
		if not state_mgr.deserialize(save_data.state):
			emit_signal("load_failed", "Failed to restore state")
			return false
	
	# Restore economy
	var economy_mgr = get_node_or_null("/root/EconomyManager")
	if economy_mgr and save_data.has("economy") and economy_mgr.has_method("load_save_data"):
		economy_mgr.load_save_data(save_data.economy)
	
	# Restore time
	var time_mgr = get_node_or_null("/root/TimeManager")
	if time_mgr and save_data.has("time") and time_mgr.has_method("load_save_data"):
		time_mgr.load_save_data(save_data.time)
	
	print("[SaveManager] Game loaded from slot %d" % slot)
	emit_signal("load_completed", slot)
	return true

## Check if save exists
func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))

## Delete a save
func delete_save(slot: int = 0) -> bool:
	var path = _get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return true
	return false

## Get save info without loading
func get_save_info(slot: int = 0) -> Dictionary:
	var path = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	
	var data: Dictionary = json.data
	return {
		"slot": slot,
		"timestamp": data.get("timestamp", 0),
		"day": data.get("state", {}).get("current_day", 0),
		"gold": data.get("state", {}).get("gold", 0),
	}

func _get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.json" % slot

func _on_auto_save() -> void:
	save_game(0)
