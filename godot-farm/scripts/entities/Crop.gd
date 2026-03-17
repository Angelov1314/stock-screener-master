class_name CropEntity
extends Node2D

signal became_harvestable

var crop_id: String = ""
var crop_name: String = ""
var sell_price: int = 0
var seed_cost: int = 0
var current_stage: int = 0  # 0-3
var is_watered: bool = false
var total_growth_time: float = 120.0
var stage_duration: float = 30.0
var planted_at_unix: float = 0.0
var water_count: int = 0
const MAX_WATER_COUNT := 5
const WATER_GROWTH_BOOST_SECONDS := 5.0

var crop_container: Node2D = null
var sprites: Array[Sprite2D] = []
var timer: Timer = null

# Layout config - dynamically set based on plot size
var grid_cols: int = 4
var grid_rows: int = 4
var plot_width: float = 600.0   # Will be set on init
var plot_height: float = 400.0  # Will be set on init

func _ready():
	z_index = 1000
	
	# Create container
	crop_container = Node2D.new()
	crop_container.name = "CropContainer"
	add_child(crop_container)
	
	# Create 16 sprites in a grid
	_create_sprites()
	
	# Hide initially for planting animation
	for sprite in sprites:
		sprite.scale = Vector2.ZERO
	
	# Create timer
	timer = Timer.new()
	timer.name = "GrowthTimer"
	timer.wait_time = 30.0
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func _create_sprites():
	# Calculate spacing based on plot size (use 70% of plot for crops, 30% margin)
	var usable_width = plot_width * 0.7
	var usable_height = plot_height * 0.7
	var spacing_x = usable_width / (grid_cols - 1) if grid_cols > 1 else 0
	var spacing_y = usable_height / (grid_rows - 1) if grid_rows > 1 else 0
	
	var start_x = -(grid_cols - 1) * spacing_x / 2
	var start_y = -(grid_rows - 1) * spacing_y / 2
	
	for row in range(grid_rows):
		for col in range(grid_cols):
			var sprite = Sprite2D.new()
			sprite.name = "Crop_%d_%d" % [row, col]
			sprite.position = Vector2(
				start_x + col * spacing_x,
				start_y + row * spacing_y
			)
			sprite.z_index = 1001
			crop_container.add_child(sprite)
			sprites.append(sprite)

func initialize(data: Dictionary, plot_w: float = 600, plot_h: float = 400) -> void:
	crop_id = data.get("id", "")
	crop_name = data.get("name", "")
	sell_price = data.get("sell_price", 10)
	seed_cost = data.get("seed_cost", 5)
	total_growth_time = float(data.get("growth_time", 120))
	stage_duration = max(total_growth_time / 4.0, 1.0)
	plot_width = plot_w
	plot_height = plot_h
	current_stage = 0

func start_growth():
	planted_at_unix = Time.get_unix_time_from_system()
	timer.wait_time = stage_duration
	update_visual()
	_plant_animation()
	timer.start()

func _plant_animation():
	# Pop up animation with stagger
	for i in range(sprites.size()):
		var sprite = sprites[i]
		var target_scale = Vector2(0.35, 0.35)
		
		# Random delay for natural look
		await get_tree().create_timer(randf() * 0.3).timeout
		
		# Pop up
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector2(0.455, 0.455), 0.4)

func _on_timer_timeout():
	_sync_stage_from_time()
	if current_stage < 3:
		current_stage += 1
		_growth_animation()

func _growth_animation():
	# Update texture first
	update_visual()
	
	# Bounce animation
	for sprite in sprites:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", Vector2(0.52, 0.52), 0.3)
		tween.tween_property(sprite, "scale", Vector2(0.455, 0.455), 0.2)
	
	if current_stage == 3:
		became_harvestable.emit()

func update_visual():
	var stage_names = ["seed", "sprout", "growing", "mature"]
	var stage_name = stage_names[current_stage]
	var path = "res://assets/crops/%s/%s_%s.png" % [crop_id, crop_id, stage_name]
	
	var tex = ResourceLoader.load(path)
	if tex:
		for sprite in sprites:
			sprite.texture = tex
			sprite.visible = true

func can_harvest() -> bool:
	return current_stage == 3

func harvest() -> Dictionary:
	if not can_harvest():
		return {}
	var result = {"crop_id": crop_id, "crop_name": crop_name, "sell_price": sell_price}
	queue_free()
	return result

func water() -> void:
	if not can_water():
		return
	is_watered = true
	water_count += 1
	planted_at_unix -= WATER_GROWTH_BOOST_SECONDS
	_sync_stage_from_time()
	update_visual()
	if can_harvest():
		became_harvestable.emit()

func can_water() -> bool:
	return not can_harvest() and water_count < MAX_WATER_COUNT

func get_water_count() -> int:
	return water_count

func _sync_stage_from_time() -> void:
	if planted_at_unix <= 0.0:
		return
	var elapsed = max(Time.get_unix_time_from_system() - planted_at_unix, 0.0)
	var computed_stage = int(floor(elapsed / stage_duration))
	computed_stage = clamp(computed_stage, 0, 3)
	if computed_stage != current_stage:
		current_stage = computed_stage
		if current_stage >= 3:
			timer.stop()

func get_remaining_time() -> float:
	if can_harvest():
		return 0.0
	if planted_at_unix <= 0.0:
		return total_growth_time
	var elapsed = Time.get_unix_time_from_system() - planted_at_unix
	return max(total_growth_time - elapsed, 0.0)

func get_countdown_text() -> String:
	var remaining = int(ceil(get_remaining_time()))
	if remaining <= 0:
		return "已成熟"
	var minutes = remaining / 60
	var seconds = remaining % 60
	return "%02d:%02d" % [minutes, seconds]
