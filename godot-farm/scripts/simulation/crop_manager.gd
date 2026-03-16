extends Node

## Manages all crops in the game world
## Handles planting, harvesting, and season effects

const CropEntityScript = preload("res://scripts/entities/Crop.gd")

# Signals
signal crop_planted(crop_id: String, crop_type: String, position: Vector2)
signal crop_harvested(crop_id: String, crop_type: String, quality: int)
signal crop_watered(crop_id: String)
signal all_crops_updated

# Crop data loaded from JSON files
var crop_database: Dictionary = {}

# Active crops: unique_id -> CropEntity
var active_crops: Dictionary = {}

# Position tracking: Vector2i -> crop_id
var crop_positions: Dictionary = {}

# Lazy-loaded references
var _time_manager: Node = null

func _ready():
	print("[CropManager] Initializing...")
	load_crop_database()
	
	# Connect to time manager for day/season updates
	var time_mgr = get_node_or_null("/root/TimeManager")
	if time_mgr:
		time_mgr.day_changed.connect(_on_day_changed)

func _get_time_manager() -> Node:
	if _time_manager == null:
		_time_manager = get_node_or_null("/root/TimeManager")
	return _time_manager

## Load all crop data from JSON files
func load_crop_database() -> void:
	var crop_files = ["carrot", "corn", "strawberry", "tomato", "wheat"]
	
	for crop_id in crop_files:
		var file_path = "res://data/crops/%s.json" % crop_id
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			var error = json.parse(file.get_as_text())
			if error == OK:
				crop_database[crop_id] = json.data
				print("[CropManager] Loaded crop: %s" % crop_id)
			else:
				push_error("[CropManager] Failed to parse %s" % file_path)
			file.close()
		else:
			_load_fallback_data(crop_id)
	
	print("[CropManager] Loaded %d crop types" % crop_database.size())

## Fallback crop data if JSON files are missing
func _load_fallback_data(crop_id: String) -> void:
	var fallbacks = {
		"carrot": {
			"id": "carrot", "name": "Carrot",
			"sell_price": 15, "seed_cost": 5, "seasons": ["spring", "autumn"],
			"water_needs": "medium", "stages": [
				{"stage": 0, "name": "seed", "duration": 0},
				{"stage": 1, "name": "sprout", "duration": 30},
				{"stage": 2, "name": "growing", "duration": 45},
				{"stage": 3, "name": "mature", "duration": 45, "harvestable": true}
			]
		},
		"corn": {
			"id": "corn", "name": "Corn",
			"sell_price": 45, "seed_cost": 15, "seasons": ["summer", "autumn"],
			"water_needs": "medium", "stages": [
				{"stage": 0, "name": "seed", "duration": 0},
				{"stage": 1, "name": "sprout", "duration": 30},
				{"stage": 2, "name": "growing", "duration": 30},
				{"stage": 3, "name": "mature", "duration": 0, "harvestable": true}
			]
		},
		"strawberry": {
			"id": "strawberry", "name": "Strawberry",
			"sell_price": 25, "seed_cost": 10, "seasons": ["spring"],
			"water_needs": "high", "stages": [
				{"stage": 0, "name": "seed", "duration": 0},
				{"stage": 1, "name": "sprout", "duration": 30},
				{"stage": 2, "name": "growing", "duration": 30},
				{"stage": 3, "name": "mature", "duration": 0, "harvestable": true}
			]
		},
		"tomato": {
			"id": "tomato", "name": "Tomato",
			"sell_price": 30, "seed_cost": 12, "seasons": ["summer"],
			"water_needs": "medium", "stages": [
				{"stage": 0, "name": "seed", "duration": 0},
				{"stage": 1, "name": "sprout", "duration": 30},
				{"stage": 2, "name": "growing", "duration": 30},
				{"stage": 3, "name": "mature", "duration": 0, "harvestable": true}
			]
		},
		"wheat": {
			"id": "wheat", "name": "Wheat",
			"sell_price": 12, "seed_cost": 3, "seasons": ["spring", "summer", "autumn"],
			"water_needs": "low", "stages": [
				{"stage": 0, "name": "seed", "duration": 0},
				{"stage": 1, "name": "sprout", "duration": 30},
				{"stage": 2, "name": "growing", "duration": 30},
				{"stage": 3, "name": "mature", "duration": 0, "harvestable": true}
			]
		}
	}
	
	if crop_id in fallbacks:
		crop_database[crop_id] = fallbacks[crop_id]

## Plant a crop at a position
func plant_crop(crop_type: String, position: Vector2i, world_pos: Vector2 = Vector2.ZERO) -> String:
	if not crop_database.has(crop_type):
		push_error("[CropManager] Unknown crop type: %s" % crop_type)
		return ""
	
	if crop_positions.has(position):
		push_warning("[CropManager] Position already occupied: %s" % str(position))
		return ""
	
	# Generate unique ID
	var crop_id = "%s_%d_%d_%d" % [crop_type, position.x, position.y, Time.get_unix_time_from_system()]
	
	# Create crop entity
	var crop_entity = CropEntityScript.new()
	crop_entity.name = crop_id
	crop_entity.position = world_pos
	crop_entity.initialize(crop_database[crop_type])
	
	# Connect signals
	crop_entity.stage_changed.connect(_on_crop_stage_changed.bind(crop_id))
	crop_entity.became_harvestable.connect(_on_crop_harvestable.bind(crop_id))
	
	add_child(crop_entity)
	
	# Track crop
	active_crops[crop_id] = crop_entity
	crop_positions[position] = crop_id
	
	emit_signal("crop_planted", crop_id, crop_type, world_pos)
	print("[CropManager] Planted %s at stage 0" % crop_id)
	
	return crop_id

## Get crop at position
func get_crop_at(position: Vector2i) -> Node2D:
	var crop_id = crop_positions.get(position, "")
	if crop_id and active_crops.has(crop_id):
		return active_crops[crop_id]
	return null

## Water a crop
func water_crop(crop_id: String) -> bool:
	if active_crops.has(crop_id):
		var crop = active_crops[crop_id]
		crop.water()
		emit_signal("crop_watered", crop_id)
		return true
	return false

## Harvest a crop
func harvest_crop(crop_id: String) -> Dictionary:
	if not active_crops.has(crop_id):
		return {}
	
	var crop = active_crops[crop_id]
	if not crop.can_harvest():
		return {}
	
	var harvest_result = crop.harvest()
	
	if harvest_result.is_empty():
		return {}
	
	# Remove from active crops if not regrowable
	if not crop.regrowable:
		_remove_crop(crop_id)
	
	emit_signal("crop_harvested", crop_id, harvest_result.crop_id, harvest_result.get("quality", 3))
	
	return harvest_result

## Remove a crop
func _remove_crop(crop_id: String) -> void:
	if active_crops.has(crop_id):
		var crop = active_crops[crop_id]
		
		# Remove from position tracking
		for pos in crop_positions.keys():
			if crop_positions[pos] == crop_id:
				crop_positions.erase(pos)
				break
		
		# Remove entity
		active_crops.erase(crop_id)
		crop.queue_free()

## Get all harvestable crops
func get_harvestable_crops() -> Array[String]:
	var harvestable: Array[String] = []
	for crop_id in active_crops.keys():
		if active_crops[crop_id].can_harvest():
			harvestable.append(crop_id)
	return harvestable

## Get crop data for UI display
func get_crop_info(crop_id: String) -> Dictionary:
	if active_crops.has(crop_id):
		var crop = active_crops[crop_id]
		return {
			"crop_id": crop.crop_id,
			"crop_name": crop.crop_name,
			"current_stage": crop.current_stage,
			"total_stages": crop.stages.size(),
			"can_harvest": crop.can_harvest(),
			"is_watered": crop.is_watered,
			"is_withered": crop.is_withered,
			"sell_price": crop.sell_price
		}
	return {}

## Signal handlers
func _on_crop_stage_changed(new_stage: int, crop_id: String) -> void:
	print("[CropManager] %s changed to stage %d" % [crop_id, new_stage])

func _on_crop_harvestable(crop_id: String) -> void:
	print("[CropManager] %s is harvestable!" % crop_id)

func _on_day_changed(day: int, season: String) -> void:
	# Reset water status on all crops at day end
	for crop in active_crops.values():
		crop.reset_water()
	emit_signal("all_crops_updated")

## Get all crop types available
func get_available_crops() -> Array[String]:
	var crops: Array[String] = []
	crops.assign(crop_database.keys())
	return crops

## Get crop template data
func get_crop_template(crop_type: String) -> Dictionary:
	return crop_database.get(crop_type, {})

## Save/Load
func get_save_data() -> Dictionary:
	var crops_data = {}
	for crop_id in active_crops.keys():
		crops_data[crop_id] = active_crops[crop_id].serialize()
	
	return {
		"crops": crops_data,
		"positions": crop_positions.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	# Clear existing crops
	for crop_id in active_crops.keys():
		_remove_crop(crop_id)
	
	# Restore positions
	if data.has("positions"):
		for pos_key in data.positions.keys():
			crop_positions[pos_key] = data.positions[pos_key]
