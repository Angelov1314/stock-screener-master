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
