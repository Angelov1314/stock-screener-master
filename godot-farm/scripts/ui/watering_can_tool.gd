class_name WateringCanTool
extends Node2D

## Watering can tool - click to water crops

signal crop_watered(coord: Vector2i)
signal watering_started
signal watering_ended

@export var water_radius: float = 100.0
@export var water_cooldown: float = 0.5

var _is_active: bool = false
var _watering_can_sprite: Sprite2D
var _last_water_time: float = 0.0

func _ready():
	_setup_watering_can()
	visible = false

func _setup_watering_can():
	_watering_can_sprite = Sprite2D.new()
	_watering_can_sprite.name = "WateringCanSprite"
	_watering_can_sprite.texture = load("res://assets/ui/button_water.png")
	_watering_can_sprite.scale = Vector2(0.8, 0.8)
	_watering_can_sprite.centered = false
	# Center the sprite
	if _watering_can_sprite.texture:
		var size = _watering_can_sprite.texture.get_size()
		_watering_can_sprite.offset = -size / 2.0
	add_child(_watering_can_sprite)

func activate():
	_is_active = true
	visible = true
	z_index = 4000
	_update_position()
	watering_started.emit()
	print("[WateringCanTool] Activated - cursor now holds watering can")

func deactivate():
	_is_active = false
	visible = false
	watering_ended.emit()

func is_active() -> bool:
	return _is_active

func _input(event):
	if not _is_active:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_water()

func _process(delta):
	if not _is_active:
		return
	_update_position()

func _update_position():
	# Directly use global mouse position for accurate cursor following
	position = get_global_mouse_position()

func _try_water():
	var current_time = Time.get_time_dict_from_system()["second"]
	if current_time - _last_water_time < water_cooldown:
		return
	
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return
	
	# Find closest crop
	var closest_coord: Vector2i = Vector2i(-1, -1)
	var closest_dist: float = water_radius
	
	for pos in crop_mgr.crop_positions.keys():
		var world_pos = _grid_to_world(pos)
		var dist = position.distance_to(world_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_coord = pos
	
	if closest_coord != Vector2i(-1, -1):
		_water_crop(closest_coord)

func _water_crop(coord: Vector2i):
	if ActionSystem.water(coord):
		_last_water_time = Time.get_time_dict_from_system()["second"]
		crop_watered.emit(coord)
		print("[WateringCanTool] Watered crop at %s" % str(coord))

func _grid_to_world(coord: Vector2i) -> Vector2:
	var cell_size = 128
	return Vector2(coord.x * cell_size + cell_size / 2, coord.y * cell_size + cell_size / 2)
