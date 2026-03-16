class_name CropEntity
extends Node2D

## Represents a single crop instance in the world

signal stage_changed(new_stage: int)
signal became_harvestable
signal withered

# Crop data
var crop_id: String = ""
var crop_name: String = ""
var sell_price: int = 0
var seed_cost: int = 0
var seasons: Array[String] = []
var regrowable: bool = false

# State
var current_stage: int = 0  # 0=seed, 1=sprout, 2=growing, 3=mature
var is_watered: bool = false
var is_fertilized: bool = false
var is_withered: bool = false
var plant_time: float = 0.0

# Visual
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
var stage_label: Label = null

# Growth timer
var growth_timer: Timer = null
const GROWTH_INTERVAL: float = 10.0  # 10 seconds per stage

func _ready():
	_create_sprite_if_needed()
	_create_label()
	update_visual()

func _create_sprite_if_needed():
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

func _create_label():
	if stage_label == null:
		stage_label = Label.new()
		stage_label.name = "StageLabel"
		stage_label.position = Vector2(-15, -35)
		stage_label.add_theme_font_size_override("font_size", 20)
		add_child(stage_label)

## Initialize crop
func initialize(data: Dictionary) -> void:
	crop_id = data.get("id", "")
	crop_name = data.get("name", "")
	sell_price = data.get("sell_price", 10)
	seed_cost = data.get("seed_cost", 5)
	var raw_seasons = data.get("seasons", ["spring"])
	seasons.assign(raw_seasons)
	regrowable = data.get("tags", []).has("regrowable")
	
	current_stage = 0
	plant_time = Time.get_unix_time_from_system()
	
	# Start growth timer
	_start_growth_timer()
	update_visual()

func _start_growth_timer():
	growth_timer = Timer.new()
	growth_timer.name = "GrowthTimer"
	growth_timer.wait_time = GROWTH_INTERVAL
	growth_timer.one_shot = false
	growth_timer.timeout.connect(_on_growth_timeout)
	add_child(growth_timer)
	growth_timer.start()

func _on_growth_timeout():
	if current_stage < 3 and not is_withered:
		advance_stage()

## Advance to next stage
func advance_stage() -> void:
	if current_stage < 3:
		current_stage += 1
		print("[Crop] %s advanced to stage %d (%s)" % [crop_id, current_stage, _get_stage_name()])
		emit_signal("stage_changed", current_stage)
		update_visual()
		
		if current_stage == 3:
			emit_signal("became_harvestable")

## Get stage name for current stage
func _get_stage_name() -> String:
	match current_stage:
		0: return "seed"
		1: return "sprout"
		2: return "growing"
		3: return "mature"
	return "seed"

## Get image name for current stage (handles crop-specific naming)
func _get_image_name() -> String:
	var stage = _get_stage_name()
	
	# Handle special cases for mature stage
	if current_stage == 3:
		match crop_id:
			"corn": return "mature"
			"wheat": return "mature"
			"tomato": return "mature"
			"strawberry": return "mature"
			_: return "mature"
	
	return stage

## Update visual
func update_visual() -> void:
	_create_sprite_if_needed()
	_create_label()
	
	# Update label
	stage_label.text = "S" + str(current_stage)
	
	# Load texture
	var image_name = _get_image_name()
	var texture_path = "res://assets/crops/%s/%s_%s.png" % [crop_id, crop_id, image_name]
	
	var texture = ResourceLoader.load(texture_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if texture:
		sprite.texture = texture
		# Scale to ~56px
		var target_size = 56.0
		if sprite.texture.get_width() > 0:
			var sf = target_size / sprite.texture.get_width()
			sprite.scale = Vector2(sf, sf)
	else:
		push_error("[Crop] Failed to load: " + texture_path)
	
	# Apply stage colors
	match current_stage:
		0: sprite.modulate = Color(0.9, 0.9, 0.7)  # Yellow-ish seed
		1: sprite.modulate = Color(0.7, 0.9, 0.7)  # Green sprout
		2: sprite.modulate = Color(0.9, 1.0, 0.9)  # Light green growing
		3: sprite.modulate = Color(1.0, 1.0, 1.0)  # White mature

## Check if can harvest
func can_harvest() -> bool:
	return current_stage == 3 and not is_withered

## Harvest
func harvest() -> Dictionary:
	if not can_harvest():
		return {}
	
	var result = {
		"crop_id": crop_id,
		"crop_name": crop_name,
		"sell_price": sell_price,
		"quality": 3
	}
	
	if regrowable:
		current_stage = 2  # Back to growing
		update_visual()
	else:
		queue_free()
	
	return result

## Water
func water() -> void:
	is_watered = true

## Serialize
func serialize() -> Dictionary:
	return {
		"crop_id": crop_id,
		"current_stage": current_stage,
		"is_watered": is_watered,
		"is_fertilized": is_fertilized,
		"is_withered": is_withered
	}

func deserialize(data: Dictionary) -> void:
	crop_id = data.get("crop_id", "")
	current_stage = data.get("current_stage", 0)
	is_watered = data.get("is_watered", false)
	is_fertilized = data.get("is_fertilized", false)
	is_withered = data.get("is_withered", false)
	update_visual()
