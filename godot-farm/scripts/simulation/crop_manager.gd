extends Node

const CropEntityScript = preload("res://scripts/entities/Crop.gd")

signal crop_planted(crop_id: String, crop_type: String, position: Vector2)
signal crop_harvested(crop_id: String, crop_type: String, quality: int)

var crop_database: Dictionary = {}
var active_crops: Dictionary = {}
var crop_positions: Dictionary = {}

func _ready():
	load_crop_database()

func load_crop_database():
	var files = ["carrot", "corn", "wheat", "tomato", "strawberry"]
	for id in files:
		var path = "res://data/crops/%s.json" % id
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				crop_database[id] = json.data
			file.close()

func plant_crop(crop_type: String, position: Vector2i, world_pos: Vector2 = Vector2.ZERO, plot_w: float = 600, plot_h: float = 400) -> String:
	if not crop_database.has(crop_type):
		return ""
	
	var crop_id = "%s_%d_%d_%d" % [crop_type, position.x, position.y, Time.get_unix_time_from_system()]
	
	var crop = CropEntityScript.new()
	crop.name = crop_id
	crop.position = world_pos
	crop.initialize(crop_database[crop_type], plot_w, plot_h)
	
	add_child(crop)
	crop.start_growth()
	
	active_crops[crop_id] = crop
	crop_positions[position] = crop_id
	
	crop_planted.emit(crop_id, crop_type, world_pos)
	
	# Play planting sound
	var audio = AudioStreamPlayer.new()
	audio.stream = load("res://assets/audio/sfx/planting/Firefly_audio_Create_a_relaxing_sound_for_planting_plants,_for_a_variation2.wav")
	audio.bus = "SFX"
	add_child(audio)
	audio.play()
	audio.finished.connect(func(): audio.queue_free())
	
	return crop_id

func get_crop_at(position: Vector2i) -> Node2D:
	var id = crop_positions.get(position, "")
	return active_crops.get(id, null)

func water_crop(crop_id: String) -> bool:
	if active_crops.has(crop_id):
		var crop = active_crops[crop_id]
		if crop.has_method("can_water") and not crop.can_water():
			print("[CropManager] Crop cannot be watered anymore: %s" % crop_id)
			return false
		crop.water()
		print("[CropManager] Watered %s (%d/5)" % [crop_id, crop.get_water_count()])
		return true
	return false

func harvest_crop(crop_id: String) -> Dictionary:
	if not active_crops.has(crop_id):
		return {}
	
	var crop = active_crops[crop_id]
	if not crop.can_harvest():
		return {}
	
	var result = crop.harvest()
	if not result.is_empty():
		active_crops.erase(crop_id)
		for pos in crop_positions.keys():
			if crop_positions[pos] == crop_id:
				crop_positions.erase(pos)
				break
		
		# Add to inventory via StateManager
		var state = get_node_or_null("/root/StateManager")
		if state:
			state.apply_action({"type": "add_item", "item_id": result.crop_id, "amount": 1})
			# Add experience for harvesting (different crops give different XP)
			var xp_amount = 15  # Base XP for harvesting
			state.apply_action({"type": "add_experience", "amount": xp_amount})
			print("[CropManager] Added %s to inventory, gained %d XP" % [result.crop_id, xp_amount])
		
		crop_harvested.emit(crop_id, result.crop_id, 3)
	
	return result

## Sell crops from inventory
func sell_crop(crop_id: String, amount: int = 1) -> int:
	var state = get_node_or_null("/root/StateManager")
	if not state:
		return 0
	
	# Check if we have the crop
	var inventory = state.get_inventory()
	if inventory.get(crop_id, 0) < amount:
		print("[CropManager] Not enough %s to sell" % crop_id)
		return 0
	
	# Get sell price from database
	var crop_data = crop_database.get(crop_id, {})
	var sell_price = crop_data.get("sell_price", 10)
	var total_gold = sell_price * amount
	
	# Remove from inventory
	var remove_success = state.apply_action({"type": "remove_item", "item_id": crop_id, "amount": amount})
	if not remove_success:
		return 0
	
	# Add gold
	state.apply_action({"type": "add_gold", "amount": total_gold})
	
	print("[CropManager] Sold %d %s for %d gold" % [amount, crop_id, total_gold])
	return total_gold

## Persistence: serialize all active crops for Supabase save
func serialize_crops_for_save() -> Array:
	var result = []
	for crop_id in active_crops.keys():
		var crop = active_crops[crop_id]
		# Find the coord for this crop
		var coord = Vector2i.ZERO
		for pos in crop_positions.keys():
			if crop_positions[pos] == crop_id:
				coord = pos
				break
		result.append({
			"crop_id": crop.crop_id,
			"plot_x": coord.x,
			"plot_y": coord.y,
			"growth_stage": crop.current_stage,
			"planted_at": Time.get_datetime_string_from_datetime_dict(
				Time.get_datetime_dict_from_unix_time(int(crop.planted_at_unix)), true
			),
			"growth_time": crop.total_growth_time,
			"water_count": crop.water_count,
		})
	return result

## Persistence: restore crops from Supabase data using real timestamps
func restore_crops_from_data(crops_data: Array) -> void:
	print("[CropManager] Restoring %d crops from cloud..." % crops_data.size())
	for data in crops_data:
		var crop_type = data.get("crop_id", "")
		if crop_type.is_empty() or not crop_database.has(crop_type):
			print("[CropManager] Skipping unknown crop type: %s" % crop_type)
			continue

		var coord = Vector2i(int(data.get("plot_x", 0)), int(data.get("plot_y", 0)))

		# Skip if already occupied
		if crop_positions.has(coord):
			print("[CropManager] Coord %s already occupied, skipping" % str(coord))
			continue

		# Calculate world position from coord (same logic as ActionSystem)
		var farm_ctrl = get_node_or_null("/root/Main/LevelContainer/Farm")
		if not farm_ctrl:
			farm_ctrl = get_node_or_null("/root/Main/Farm")
		var world_pos = Vector2.ZERO
		var plot_w = 600.0
		var plot_h = 400.0
		if farm_ctrl and farm_ctrl.has_method("get_plot_position_by_coord"):
			world_pos = farm_ctrl.get_plot_position_by_coord(coord)
		else:
			world_pos = Vector2(coord.x * 640 + 500, coord.y * 640 + 500)

		# Parse planted_at timestamp to unix
		var planted_at_str = str(data.get("planted_at", ""))
		var planted_unix = 0.0
		if not planted_at_str.is_empty():
			# Try ISO format from Supabase (e.g. "2026-03-18T01:00:00+00:00")
			# Godot's Time.get_unix_time_from_datetime_string handles ISO 8601
			planted_unix = Time.get_unix_time_from_datetime_string(planted_at_str)

		var saved_growth_time = float(data.get("growth_time", 120.0))
		var saved_water_count = int(data.get("water_count", 0))

		# Create crop entity
		var crop_instance_id = "%s_%d_%d_%d" % [crop_type, coord.x, coord.y, int(planted_unix)]
		var crop = CropEntityScript.new()
		crop.name = crop_instance_id
		crop.position = world_pos
		crop.initialize(crop_database[crop_type], plot_w, plot_h)

		# Override with saved timing data
		crop.total_growth_time = saved_growth_time
		crop.stage_duration = max(saved_growth_time / 4.0, 1.0)
		crop.water_count = saved_water_count
		crop.planted_at_unix = planted_unix

		add_child(crop)

		# Compute current stage from real elapsed time
		crop._sync_stage_from_time()
		crop.update_visual()

		# If not yet mature, start the timer for remaining growth
		if crop.current_stage < 3:
			# Calculate time until next stage
			var elapsed = Time.get_unix_time_from_system() - planted_unix
			var next_stage_time = (crop.current_stage + 1) * crop.stage_duration
			var time_to_next = max(next_stage_time - elapsed, 1.0)
			crop.timer.wait_time = time_to_next
			crop.timer.start()
		else:
			crop.became_harvestable.emit()

		active_crops[crop_instance_id] = crop
		crop_positions[coord] = crop_instance_id

		print("[CropManager] Restored %s at %s, stage=%d (planted %.0fs ago)" % [
			crop_type, str(coord), crop.current_stage,
			Time.get_unix_time_from_system() - planted_unix
		])

	print("[CropManager] Restore complete: %d active crops" % active_crops.size())

func get_available_crops() -> Array[String]:
	var crops: Array[String] = []
	crops.assign(crop_database.keys())
	return crops

func get_harvestable_crops() -> Array[String]:
	var harvestable: Array[String] = []
	for crop_id in active_crops.keys():
		if active_crops[crop_id].can_harvest():
			harvestable.append(crop_id)
	return harvestable
