class_name CropEntity
extends Node2D

signal became_harvestable

var crop_id: String = ""
var crop_name: String = ""
var sell_price: int = 0
var seed_cost: int = 0
var current_stage: int = 0  # 0-3
var is_watered: bool = false

var sprite: Sprite2D = null
var timer: Timer = null

func _ready():
	# Create sprite
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	add_child(sprite)
	
	# Create timer
	timer = Timer.new()
	timer.name = "GrowthTimer"
	timer.wait_time = 10.0
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func initialize(data: Dictionary) -> void:
	crop_id = data.get("id", "")
	crop_name = data.get("name", "")
	sell_price = data.get("sell_price", 10)
	seed_cost = data.get("seed_cost", 5)
	current_stage = 0
	# Don't call update_visual here - _ready() hasn't run yet
	# update_visual() will be called after add_child() in crop_manager

func _on_timer_timeout():
	if current_stage < 3:
		current_stage += 1
		update_visual()
		if current_stage == 3:
			became_harvestable.emit()

func update_visual():
	var stage_names = ["seed", "sprout", "growing", "mature"]
	var stage_name = stage_names[current_stage]
	var path = "res://assets/crops/%s/%s_%s.png" % [crop_id, crop_id, stage_name]
	
	var tex = ResourceLoader.load(path)
	if tex:
		sprite.texture = tex
		sprite.scale = Vector2(0.22, 0.22)  # 56/256
	else:
		push_error("Failed to load: " + path)

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
