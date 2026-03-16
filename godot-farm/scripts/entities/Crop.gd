class_name CropEntity
extends Node2D

## Represents a single crop instance in the world
## Handles visual state and growth progress

signal growth_advanced(new_stage: int)
signal became_harvestable
signal withered

# Crop data from JSON
var crop_id: String = ""
var crop_name: String = ""
var growth_time: float = 0.0
var sell_price: int = 0
var seed_cost: int = 0
var seasons: Array[String] = []
var water_needs: String = "medium"
var quality_factors: Dictionary = {}
var stages: Array[Dictionary] = []

# Instance state
var current_stage: int = 0
var growth_progress: float = 0.0  # 0.0 to 1.0 within current stage
var total_growth_time: float = 0.0
var is_watered: bool = false
var is_fertilized: bool = false
var plant_time: float = 0.0
var quality_multiplier: float = 1.0
var is_withered: bool = false
var regrowable: bool = false

# Visual
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
var debug_label: Label = null

func _ready():
	var n = name if name else "unnamed"
	var cid = crop_id if crop_id else "no_id"
	print("[Crop DEBUG] " + n + ": _ready() called, crop_id='" + cid + "'")
	update_visual()
	print("[Crop DEBUG] " + n + ": _ready() finished")

## Initialize crop with data
func initialize(data: Dictionary) -> void:
	crop_id = data.get("id", "")
	crop_name = data.get("name", "")
	growth_time = data.get("growth_time", 120.0)
	sell_price = data.get("sell_price", 10)
	seed_cost = data.get("seed_cost", 5)
	var raw_seasons = data.get("seasons", ["spring"])
	seasons.assign(raw_seasons)
	water_needs = data.get("water_needs", "medium")
	quality_factors = data.get("quality_factors", {})
	var raw_stages = data.get("stages", [])
	for stage in raw_stages:
		stages.append(stage)
	regrowable = data.get("tags", []).has("regrowable")
	
	current_stage = 0
	growth_progress = 0.0
	plant_time = Time.get_unix_time_from_system()
	update_quality_multiplier()

## Update growth based on time elapsed
## Each stage takes 60 seconds (1 minute) - reduced to 10 seconds for testing
const STAGE_DURATION_SECONDS := 10.0

func update_growth(delta_time: float, in_correct_season: bool) -> void:
	# Debug: print every frame for first few calls
	if Engine.get_process_frames() % 300 == 0:
		print("[Crop DEBUG] %s: update_growth called, delta=%.3f, stage=%d, progress=%.3f, withered=%s" % [crop_id, delta_time, current_stage, growth_progress, is_withered])
	
	if is_withered:
		if Engine.get_process_frames() % 300 == 0:
			print("[Crop DEBUG] %s: blocked - is_withered" % crop_id)
		return
	
	if can_harvest():
		if Engine.get_process_frames() % 300 == 0:
			print("[Crop DEBUG] %s: blocked - can_harvest=true (stage %d)" % [crop_id, current_stage])
		return
	
	if not in_correct_season:
		if Engine.get_process_frames() % 300 == 0:
			print("[Crop DEBUG] %s: blocked - wrong season" % crop_id)
		return
	
	# Calculate growth speed multiplier
	var speed_mult = 1.0
	if is_watered:
		speed_mult *= 1.5  # 50% faster when watered
	if is_fertilized:
		speed_mult *= 1.3
	
	# Advance growth progress - each stage takes 10 seconds
	var stage_duration = STAGE_DURATION_SECONDS / speed_mult
	growth_progress += delta_time / stage_duration
	
	# Debug output every few seconds
	if Engine.get_process_frames() % 180 == 0:
		print("[Crop] %s growing: stage=%d, progress=%.3f/1.0, watered=%s, speed=%.1fx" % [crop_id, current_stage, growth_progress, is_watered, speed_mult])
	
	if growth_progress >= 1.0:
		print("[Crop] %s: advancing from stage %d to next stage!" % [crop_id, current_stage])
		advance_stage()
	
	total_growth_time += delta_time

## Advance to next growth stage
func advance_stage() -> void:
	var cid = crop_id if crop_id else "no_id"
	print("[Crop DEBUG] " + cid + ": advance_stage() called")
	if current_stage < stages.size() - 1:
		current_stage += 1
		growth_progress = 0.0
		print("[Crop] " + cid + " advanced to stage " + str(current_stage))
		emit_signal("growth_advanced", current_stage)
		update_visual()
		
		# Check if now harvestable
		if can_harvest():
			print("[Crop] %s is now harvestable!" % crop_id)
			emit_signal("became_harvestable")

## Get duration for a specific stage
func get_stage_duration(stage_idx: int) -> float:
	if stage_idx < 0 or stage_idx >= stages.size():
		return 0.0
	return stages[stage_idx].get("duration", 0.0)

## Check if crop can be harvested
func can_harvest() -> bool:
	if current_stage < stages.size():
		return stages[current_stage].get("harvestable", false)
	return false

## Harvest the crop
func harvest() -> Dictionary:
	if not can_harvest():
		return {}
	
	var result = {
		"crop_id": crop_id,
		"crop_name": crop_name,
		"base_price": sell_price,
		"quality": calculate_quality(),
		"quantity": 1
	}
	
	# Calculate final sell price with quality
	result["sell_price"] = int(sell_price * quality_multiplier)
	
	if regrowable:
		# Regrowable crops go back to fruiting stage
		current_stage = max(0, current_stage - 1)
		growth_progress = 0.0
		update_visual()
	else:
		# Non-regrowable crops are removed after harvest
		queue_free()
	
	return result

## Calculate quality (1-5 stars)
func calculate_quality() -> int:
	var base = 3  # Average quality
	if is_watered:
		base += 1
	if is_fertilized:
		base += 1
	# Bonus for optimal growing conditions
	if quality_multiplier >= 1.5:
		base += 1
	return clampi(base, 1, 5)

## Update quality multiplier based on conditions
func update_quality_multiplier() -> void:
	quality_multiplier = 1.0
	
	if is_watered and quality_factors.has("water_bonus"):
		quality_multiplier *= quality_factors.water_bonus
	if is_fertilized and quality_factors.has("fertilizer_bonus"):
		quality_multiplier *= quality_factors.fertilizer_bonus

## Water the crop
func water() -> void:
	if not is_watered:
		is_watered = true
		update_quality_multiplier()

## Fertilize the crop
func fertilize() -> void:
	if not is_fertilized:
		is_fertilized = true
		update_quality_multiplier()

## Reset water status (called at day end)
func reset_water() -> void:
	is_watered = false
	update_quality_multiplier()

## Wither the crop (wrong season for too long, or no water)
func wither() -> void:
	if not is_withered:
		is_withered = true
		emit_signal("withered")
		update_visual()

## Update visual representation
func update_visual() -> void:
	var debug_name = crop_id if crop_id != "" else name
	print("[Crop DEBUG] " + debug_name + ": update_visual() called")
	
	# Check for multiple Sprite2D children
	var sprite_count = 0
	for child in get_children():
		if child is Sprite2D:
			sprite_count += 1
			print("[Crop DEBUG] " + debug_name + ": Found Sprite2D child: " + child.name + ", texture=" + str(child.texture))
	print("[Crop DEBUG] " + debug_name + ": Total Sprite2D children: " + str(sprite_count))
	if sprite == null:
		# Create sprite if missing
		print("[Crop DEBUG] " + debug_name + ": Creating new Sprite2D")
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
		print("[Crop DEBUG] " + debug_name + ": Sprite2D added, path=" + str(sprite.get_path()) + ", parent=" + str(get_path()))
	else:
		print("[Crop DEBUG] " + debug_name + ": Sprite2D exists, path=" + str(sprite.get_path()))
	
	# Create debug label if missing
	if debug_label == null:
		debug_label = Label.new()
		debug_label.name = "DebugLabel"
		debug_label.position = Vector2(-20, -40)  # Above the sprite
		debug_label.add_theme_font_size_override("font_size", 24)
		add_child(debug_label)
	
	# Update debug label
	debug_label.text = "S" + str(current_stage)
	
	# Load the correct stage sprite
	var stage_name = _get_current_stage_name()
	var texture_path = "res://assets/crops/" + crop_id + "/" + crop_id + "_" + stage_name + ".png"
	
	print("[Crop DEBUG] " + debug_name + ": Loading texture: " + texture_path)
	
	# Use ResourceLoader for runtime loading (load() doesn't work at runtime in Godot 4)
	var texture = ResourceLoader.load(texture_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if texture:
		sprite.texture = texture
		# Force update
		sprite.queue_redraw()
		print("[Crop DEBUG] " + debug_name + ": Texture loaded OK, size=" + str(texture.get_size()))
		# Scale from 1024x1024 to game size (~56px)
		var target_size = 56.0
		if sprite.texture.get_width() > 0:
			var sf = target_size / sprite.texture.get_width()
			sprite.scale = Vector2(sf, sf)
			sprite.queue_redraw()  # Force redraw after scale change
			print("[Crop DEBUG] " + debug_name + ": sprite scale=" + str(sprite.scale) + ", visible=" + str(sprite.visible) + ", position=" + str(sprite.position))
		print("[Crop DEBUG] " + debug_name + ": Texture path in sprite: " + str(sprite.texture.resource_path))
	else:
		print("[Crop ERROR] " + debug_name + ": FAILED to load: " + texture_path)
		# Fallback: try to load seed stage
		var fallback_path = "res://assets/crops/" + crop_id + "/" + crop_id + "_seed.png"
		var fallback_texture = ResourceLoader.load(fallback_path, "", ResourceLoader.CACHE_MODE_REUSE)
		if fallback_texture:
			sprite.texture = fallback_texture
			print("[Crop DEBUG] " + debug_name + ": Using fallback texture")
	
	# Apply visual modifiers based on stage
	if is_withered:
		sprite.modulate = Color(0.5, 0.4, 0.3)
	elif can_harvest():
		sprite.modulate = Color(1.0, 1.0, 1.0)  # White - ready to harvest
	else:
		# Different tint for different stages to make growth visible
		match current_stage:
			0: sprite.modulate = Color(1.0, 1.0, 0.8)   # Yellow tint - seed
			1: sprite.modulate = Color(0.8, 1.0, 0.8)   # Green tint - sprout
			2: sprite.modulate = Color(0.9, 1.0, 0.9)   # Light green - growing
			3: sprite.modulate = Color(1.0, 1.0, 1.0)   # Normal - tall
			_: sprite.modulate = Color(0.95, 0.98, 0.95) # Default

## Get stage name from current stage index
func _get_current_stage_name() -> String:
	if current_stage >= 0 and current_stage < stages.size():
		return stages[current_stage].get("name", "seed")
	return "seed"

## Serialization
func serialize() -> Dictionary:
	return {
		"crop_id": crop_id,
		"current_stage": current_stage,
		"growth_progress": growth_progress,
		"total_growth_time": total_growth_time,
		"is_watered": is_watered,
		"is_fertilized": is_fertilized,
		"plant_time": plant_time,
		"quality_multiplier": quality_multiplier,
		"is_withered": is_withered
	}

func deserialize(data: Dictionary) -> void:
	current_stage = data.get("current_stage", 0)
	growth_progress = data.get("growth_progress", 0.0)
	total_growth_time = data.get("total_growth_time", 0.0)
	is_watered = data.get("is_watered", false)
	is_fertilized = data.get("is_fertilized", false)
	plant_time = data.get("plant_time", Time.get_unix_time_from_system())
	quality_multiplier = data.get("quality_multiplier", 1.0)
	is_withered = data.get("is_withered", false)
	update_visual()
