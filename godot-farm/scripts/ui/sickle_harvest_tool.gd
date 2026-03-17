class_name SickleHarvestTool
extends Node2D

## Sickle harvest tool - drag to harvest mature crops

signal crop_harvested(crop_id: String, coord: Vector2i)
signal harvest_started
signal harvest_ended

@export var harvest_radius: float = 80.0
@export var harvest_cooldown: float = 0.3

var _is_active: bool = false
var _sickle_sprite: Sprite2D
var _last_harvest_time: float = 0.0
var _harvested_this_drag: Array[Vector2i] = []

func _ready():
	_setup_sickle()
	visible = false

func _setup_sickle():
	_sickle_sprite = Sprite2D.new()
	_sickle_sprite.name = "SickleSprite"
	_sickle_sprite.texture = load("res://assets/ui/button_sickle.png")
	_sickle_sprite.scale = Vector2(0.8, 0.8)
	_sickle_sprite.centered = false
	# Center the sprite
	if _sickle_sprite.texture:
		var size = _sickle_sprite.texture.get_size()
		_sickle_sprite.offset = -size / 2.0
	add_child(_sickle_sprite)

func activate():
	_is_active = true
	visible = true
	z_index = 4000
	_update_position()
	_harvested_this_drag.clear()
	harvest_started.emit()
	print("[SickleTool] Activated - cursor now holds sickle")

func deactivate():
	_is_active = false
	visible = false
	_harvested_this_drag.clear()
	harvest_ended.emit()

func is_active() -> bool:
	return _is_active

func _input(event):
	if not _is_active:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_harvested_this_drag.clear()
				_try_harvest()
			else:
				_harvested_this_drag.clear()

func _process(delta):
	if not _is_active:
		return
	_update_position()
	
	# Continuous harvest while dragging
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var current_time = Time.get_time_dict_from_system()["second"]
		if current_time - _last_harvest_time > harvest_cooldown:
			_try_harvest()

func _update_position():
	# Directly use global mouse position for accurate cursor following
	position = get_global_mouse_position()

func _try_harvest():
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return
	
	var harvestable = crop_mgr.get_harvestable_crops()
	if harvestable.is_empty():
		return
	
	# Find closest crop
	var closest_coord: Vector2i = Vector2i(-1, -1)
	var closest_dist: float = harvest_radius
	
	for crop_id in harvestable:
		for pos in crop_mgr.crop_positions.keys():
			if crop_mgr.crop_positions[pos] == crop_id:
				var world_pos = _grid_to_world(pos)
				var dist = position.distance_to(world_pos)
				if dist < closest_dist and not _harvested_this_drag.has(pos):
					closest_dist = dist
					closest_coord = pos
				break
	
	if closest_coord != Vector2i(-1, -1):
		_harvest_crop(closest_coord)

func _harvest_crop(coord: Vector2i):
	if coord in _harvested_this_drag:
		return
	
	# Get crop_id BEFORE harvesting
	var crop_mgr = get_node_or_null("/root/CropManager")
	var crop_id = ""
	if crop_mgr and coord in crop_mgr.crop_positions:
		crop_id = crop_mgr.crop_positions[coord]
	
	# Harvest through ActionSystem
	if ActionSystem.harvest(coord):
		_harvested_this_drag.append(coord)
		_last_harvest_time = Time.get_time_dict_from_system()["second"]
		
		if not crop_id.is_empty():
			crop_harvested.emit(crop_id, coord)
		
		print("[SickleTool] Harvested crop at %s" % str(coord))

func _grid_to_world(coord: Vector2i) -> Vector2:
	var cell_size = 128
	return Vector2(coord.x * cell_size + cell_size / 2, coord.y * cell_size + cell_size / 2)
