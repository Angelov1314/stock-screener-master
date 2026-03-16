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

func plant_crop(crop_type: String, position: Vector2i, world_pos: Vector2 = Vector2.ZERO) -> String:
	print("[CropManager] plant_crop: type=%s, pos=%s, world=%s" % [crop_type, str(position), str(world_pos)])
	
	if not crop_database.has(crop_type):
		print("[CropManager] ERROR: crop not in database")
		return ""
	
	var crop_id = "%s_%d_%d_%d" % [crop_type, position.x, position.y, Time.get_unix_time_from_system()]
	print("[CropManager] Creating crop: %s" % crop_id)
	
	var crop = CropEntityScript.new()
	crop.name = crop_id
	crop.position = world_pos
	crop.initialize(crop_database[crop_type])
	
	add_child(crop)
	print("[CropManager] Added to tree, child count: %d" % get_child_count())
	
	# Check if _ready was called
	if crop.sprites.is_empty():
		print("[CropManager] ERROR: sprites not created!")
	else:
		print("[CropManager] Created %d sprites" % crop.sprites.size())
	
	crop.start_growth()
	
	active_crops[crop_id] = crop
	crop_positions[position] = crop_id
	
	crop_planted.emit(crop_id, crop_type, world_pos)
	print("[CropManager] Plant success: %s" % crop_id)
	return crop_id

func get_crop_at(position: Vector2i) -> Node2D:
	var id = crop_positions.get(position, "")
	return active_crops.get(id, null)

func water_crop(crop_id: String) -> bool:
	if active_crops.has(crop_id):
		active_crops[crop_id].water()
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
		crop_harvested.emit(crop_id, result.crop_id, 3)
	
	return result

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
