class_name CropEntity
extends Node2D

signal became_harvestable

var crop_id: String = ""
var crop_name: String = ""
var sell_price: int = 0
var seed_cost: int = 0
var current_stage: int = 0  # 0-3
var is_watered: bool = false

var crop_container: Node2D = null
var sprites: Array[Sprite2D] = []
var timer: Timer = null

# Layout config - 16 crops evenly distributed, slightly larger
var grid_cols: int = 4
var grid_rows: int = 4
var spacing: float = 200.0  # Much wider spacing for large plots

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
	timer.wait_time = 10.0
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func _create_sprites():
	# Calculate starting position to center the grid
	var total_width = (grid_cols - 1) * spacing
	var total_height = (grid_rows - 1) * spacing
	var start_x = -total_width / 2
	var start_y = -total_height / 2
	
	for row in range(grid_rows):
		for col in range(grid_cols):
			var sprite = Sprite2D.new()
			sprite.name = "Crop_%d_%d" % [row, col]
			sprite.position = Vector2(
				start_x + col * spacing,
				start_y + row * spacing
			)
			sprite.z_index = 1001
			crop_container.add_child(sprite)
			sprites.append(sprite)

func initialize(data: Dictionary) -> void:
	crop_id = data.get("id", "")
	crop_name = data.get("name", "")
	sell_price = data.get("sell_price", 10)
	seed_cost = data.get("seed_cost", 5)
	current_stage = 0
	# update_visual will be called after add_child

func start_growth():
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
		tween.tween_property(sprite, "scale", target_scale, 0.4)

func _on_timer_timeout():
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
		tween.tween_property(sprite, "scale", Vector2(0.4, 0.4), 0.3)
		tween.tween_property(sprite, "scale", Vector2(0.35, 0.35), 0.2)
	
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
	is_watered = true
