class_name FarmController
extends Node2D

## Farm Controller - Handles farm interaction with custom plot shapes
## Based on farm_background.png at 1536x2752 resolution, scaled 4x

# Scene references
@export var crop_scene: PackedScene
@onready var crops_container: Node2D = %CropsContainer
@onready var plots_container: Node2D = %PlotsContainer
@onready var farm_camera: Camera2D

# Reference image size (user provided coordinates based on this)
const REF_WIDTH := 1143.0
const REF_HEIGHT := 2048.0

# Actual background image size
const BG_WIDTH := 1536.0
const BG_HEIGHT := 2752.0

# Scale factor to convert reference coordinates to actual image
const SCALE_X := BG_WIDTH / REF_WIDTH   # ~1.344
const SCALE_Y := BG_HEIGHT / REF_HEIGHT # ~1.344

# World scale - background is scaled 4x in the scene
const WORLD_SCALE := 4.0

# Total scale = image_scale * world_scale
const TOTAL_SCALE_X := SCALE_X * WORLD_SCALE  # ~5.376
const TOTAL_SCALE_Y := SCALE_Y * WORLD_SCALE  # ~5.376

# Plot definitions (reference coordinates, will be scaled)
# Format: {id, x, y, w, h, inner_margin}
var PLOT_DEFINITIONS := [
	{"id": "plot_01", "x": 0,   "y": 736,  "w": 128, "h": 170, "margin": 12},
	{"id": "plot_02", "x": 275, "y": 650,  "w": 245, "h": 107, "margin": 12},
	{"id": "plot_03", "x": 655, "y": 652,  "w": 237, "h": 105, "margin": 12},
	{"id": "plot_04", "x": 286, "y": 796,  "w": 224, "h": 103, "margin": 12},
	{"id": "plot_05", "x": 657, "y": 798,  "w": 236, "h": 101, "margin": 12},
	{"id": "plot_06", "x": 305, "y": 1207, "w": 207, "h": 103, "margin": 12},
	{"id": "plot_07", "x": 655, "y": 1208, "w": 197, "h": 100, "margin": 12},
	{"id": "plot_08", "x": 669, "y": 1383, "w": 176, "h": 82,  "margin": 10},
	{"id": "plot_09", "x": 889, "y": 1430, "w": 157, "h": 58,  "margin": 8},
	{"id": "plot_10", "x": 224, "y": 1642, "w": 283, "h": 126, "margin": 12},
	{"id": "plot_11", "x": 664, "y": 1560, "w": 211, "h": 210, "margin": 12},
	{"id": "plot_12", "x": 959, "y": 1570, "w": 184, "h": 198, "margin": 12},
]

# Crop tracking
var _crop_instances: Dictionary = {}  # plot_id -> crop_node
var _selected_crop_id: String = "carrot"
var _plots: Dictionary = {}  # plot_id -> plot_node
var _plot_rects: Dictionary = {}  # plot_id -> Rect2 (scaled coordinates)

func _ready():
	print("[FarmController] Initializing with custom plots...")
	print("[FarmController] Scale factors: X=%.3f, Y=%.3f (4x world)" % [TOTAL_SCALE_X, TOTAL_SCALE_Y])
	
	# Get camera reference
	farm_camera = get_node_or_null("%FarmCamera")
	if not farm_camera:
		farm_camera = get_parent().get_node_or_null("FarmCamera")
	
	# Connect to ActionSystem signals
	var action_sys = get_node_or_null("/root/ActionSystem")
	if action_sys:
		action_sys.crop_planted.connect(_on_crop_planted)
		action_sys.crop_watered.connect(_on_crop_watered)
		action_sys.crop_harvested.connect(_on_crop_harvested)
	
	# Connect to CropManager signals for growth updates
	var crop_mgr = get_node_or_null("/root/CropManager")
	if crop_mgr:
		crop_mgr.crop_stage_changed.connect(_on_crop_stage_changed)
	
	# Build custom farm plots
	_build_custom_plots()
	
	# Load existing crops from state
	_load_existing_crops()
	
	print("[FarmController] Initialized with %d custom plots" % PLOT_DEFINITIONS.size())

## Scale a reference coordinate to actual world coordinate (4x scaled)
func _scale_x(ref_x: float) -> float:
	return ref_x * TOTAL_SCALE_X

func _scale_y(ref_y: float) -> float:
	return ref_y * TOTAL_SCALE_Y

func _scale_size(ref_size: float) -> float:
	# Use average scale for sizes to maintain aspect ratio
	return ref_size * ((TOTAL_SCALE_X + TOTAL_SCALE_Y) / 2.0)

## Build custom farm plots based on background image
func _build_custom_plots():
	for plot_def in PLOT_DEFINITIONS:
		var plot = _create_custom_plot(plot_def)
		plots_container.add_child(plot)
		_plots[plot_def.id] = plot

func _create_custom_plot(plot_def: Dictionary) -> Area2D:
	var plot_id = plot_def.id
	var ref_x = plot_def.x
	var ref_y = plot_def.y
	var ref_w = plot_def.w
	var ref_h = plot_def.h
	var margin = plot_def.margin
	
	# Scale coordinates
	var scaled_x = _scale_x(ref_x)
	var scaled_y = _scale_y(ref_y)
	var scaled_w = _scale_x(ref_w)
	var scaled_h = _scale_y(ref_h)
	var scaled_margin_x = _scale_x(margin)
	var scaled_margin_y = _scale_y(margin)
	
	# Apply inner margin for clickable area
	var inner_x = scaled_x + scaled_margin_x
	var inner_y = scaled_y + scaled_margin_y
	var inner_w = scaled_w - (scaled_margin_x * 2)
	var inner_h = scaled_h - (scaled_margin_y * 2)
	
	# Store the clickable rect
	_plot_rects[plot_id] = Rect2(inner_x, inner_y, inner_w, inner_h)
	
	# Create Area2D for this plot
	var plot = Area2D.new()
	plot.name = plot_id
	
	# Center position for the collision shape
	plot.position = Vector2(inner_x + inner_w/2, inner_y + inner_h/2)
	
	# Connect input event
	plot.input_event.connect(_on_plot_input_event.bind(plot_id))
	
	# Add collision shape for input detection
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(inner_w, inner_h)
	collision.shape = shape
	plot.add_child(collision)
	
	# Add visual soil sprite
	var sprite = Sprite2D.new()
	sprite.name = "SoilSprite"
	sprite.modulate = Color(0.4, 0.25, 0.1, 0.5)  # Semi-transparent warm brown
	
	# Create soil texture sized to the plot
	var texture = _create_soil_texture_scaled(inner_w, inner_h)
	sprite.texture = texture
	plot.add_child(sprite)
	
	# Add highlight effect (hidden by default)
	var highlight = ColorRect.new()
	highlight.name = "Highlight"
	highlight.color = Color(1, 1, 1, 0.2)
	highlight.size = Vector2(inner_w, inner_h)
	highlight.position = Vector2(-inner_w/2, -inner_h/2)
	highlight.visible = false
	plot.add_child(highlight)
	
	return plot

func _create_soil_texture_scaled(width: float, height: float) -> Texture2D:
	var w = int(width)
	var h = int(height)
	if w < 2: w = 2
	if h < 2: h = 2
	
	var image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# Fill with soil color
	image.fill(Color(0.545, 0.353, 0.169, 0.6))  # Warm chocolate brown
	
	# Add darker border
	var border_x = max(2, int(w * 0.03))
	var border_y = max(2, int(h * 0.03))
	
	for x in range(w):
		for y in range(border_y):
			image.set_pixel(x, y, Color(0.4, 0.25, 0.1, 0.6))
			image.set_pixel(x, h - 1 - y, Color(0.4, 0.25, 0.1, 0.6))
	
	for y in range(h):
		for x in range(border_x):
			image.set_pixel(x, y, Color(0.4, 0.25, 0.1, 0.6))
			image.set_pixel(w - 1 - x, y, Color(0.4, 0.25, 0.1, 0.6))
	
	# Add furrow lines
	if h > 30:
		for row in range(1, 4):
			var fy = int(h * row / 4)
			for x in range(border_x, w - border_x):
				if fy < h:
					image.set_pixel(x, fy, Color(0.45, 0.28, 0.12, 0.5))
	
	return ImageTexture.create_from_image(image)

## Input Handling
func _on_plot_input_event(viewport: Node, event: InputEvent, shape_idx: int, plot_id: String):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_plot_tap(plot_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_plot_secondary(plot_id)

func _handle_plot_tap(plot_id: String):
	var crop_entity = _get_crop_at_plot(plot_id)
	
	if crop_entity == null:
		# Empty plot - plant crop
		_try_plant_crop(plot_id)
	else:
		# Check if ready to harvest
		if crop_entity.can_harvest():
			_try_harvest_crop(plot_id)
		else:
			_try_water_crop(plot_id)

func _handle_plot_secondary(plot_id: String):
	var crop_entity = _get_crop_at_plot(plot_id)
	if crop_entity != null:
		_show_crop_info(plot_id, crop_entity)

## Get crop entity at a specific plot
func _get_crop_at_plot(plot_id: String) -> Node:
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return null
	
	# Get plot rect center position
	var rect = _plot_rects.get(plot_id, Rect2())
	var center_pos = Vector2(rect.position.x + rect.size.x/2, rect.position.y + rect.size.y/2)
	
	# Find crop entity by checking which crop is closest to this position
	# Detection distance scaled for 4x world (200px instead of 50px)
	for crop_id in crop_mgr.active_crops.keys():
		var crop = crop_mgr.active_crops[crop_id]
		if crop.position.distance_to(center_pos) < 200:
			return crop
	
	return null

## Action Handlers
func _try_plant_crop(plot_id: String):
	var rect = _plot_rects.get(plot_id, Rect2())
	var coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))  # Use scaled coordinate as grid coord
	
	var success = ActionSystem.plant(coord, _selected_crop_id)
	if success:
		_animate_plot_action(plot_id, "plant")

func _try_water_crop(plot_id: String):
	var rect = _plot_rects.get(plot_id, Rect2())
	var coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))
	
	var success = ActionSystem.water(coord)
	if success:
		_animate_plot_action(plot_id, "water")

func _try_harvest_crop(plot_id: String):
	var rect = _plot_rects.get(plot_id, Rect2())
	var coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))
	
	var success = ActionSystem.harvest(coord)
	if success:
		_animate_plot_action(plot_id, "harvest")

## Signal Handlers
func _on_crop_planted(coord: Vector2i, crop_id: String):
	# Find which plot this crop belongs to based on position
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return
	
	for plot_id in _plot_rects.keys():
		var rect = _plot_rects[plot_id]
		var plot_coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))
		if plot_coord == coord:
			_create_crop_visual(plot_id, crop_id)
			_animate_crop_growth(plot_id, 0)
			return

func _on_crop_watered(coord: Vector2i):
	for plot_id in _plot_rects.keys():
		var rect = _plot_rects[plot_id]
		var plot_coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))
		if plot_coord == coord:
			_animate_water_effect(plot_id)
			return

func _on_crop_harvested(coord: Vector2i, crop_id: String):
	for plot_id in _plot_rects.keys():
		var rect = _plot_rects[plot_id]
		var plot_coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))
		if plot_coord == coord:
			_animate_harvest(plot_id)
			_remove_crop_visual(plot_id)
			return

func _on_crop_stage_changed(crop_id: String, new_stage: int):
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return
	
	var crop_entity = crop_mgr.active_crops.get(crop_id, null)
	if not crop_entity:
		return
	
	# Find plot by position (scaled detection for 4x world)
	for plot_id in _plot_rects.keys():
		var rect = _plot_rects[plot_id]
		var center_pos = Vector2(rect.position.x + rect.size.x/2, rect.position.y + rect.size.y/2)
		if crop_entity.position.distance_to(center_pos) < 200:
			_update_crop_visual_stage(plot_id, new_stage)
			return

## Visual Creation
func _create_crop_visual(plot_id: String, crop_id: String):
	if _crop_instances.has(plot_id):
		return
	
	var rect = _plot_rects.get(plot_id, Rect2())
	var center_pos = Vector2(rect.position.x + rect.size.x/2, rect.position.y + rect.size.y/2)
	
	var crop_node = Node2D.new()
	crop_node.name = "Crop_" + plot_id
	crop_node.position = center_pos
	
	# Create crop sprite
	var sprite = Sprite2D.new()
	sprite.name = "CropSprite"
	sprite.position.y = -10
	
	_update_crop_sprite(sprite, crop_id, 0)
	
	crop_node.add_child(sprite)
	crops_container.add_child(crop_node)
	_crop_instances[plot_id] = crop_node

func _update_crop_sprite(sprite: Sprite2D, crop_id: String, stage: int):
	var stage_name = _get_stage_name(crop_id, stage)
	var texture_path = "res://assets/crops/%s/%s_%s.png" % [crop_id, crop_id, stage_name]
	
	if ResourceLoader.exists(texture_path):
		var tex = load(texture_path)
		sprite.texture = tex
		# Scale to fit plot in 4x world (max 224px = 56 * 4)
		var target_size = 224.0
		if tex.get_width() > 0:
			var scale_factor = target_size / tex.get_width()
			sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		push_warning("[FarmController] Missing sprite: %s" % texture_path)
		var size = 128 + (stage * 32)  # Scaled for 4x world
		var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		image.fill(_get_crop_color(crop_id))
		sprite.texture = ImageTexture.create_from_image(image)

func _update_crop_visual_stage(plot_id: String, new_stage: int):
	if not _crop_instances.has(plot_id):
		return
	
	var crop_node = _crop_instances[plot_id]
	var sprite = crop_node.get_node("CropSprite")
	
	# Get crop ID from CropManager
	var crop_mgr = get_node_or_null("/root/CropManager")
	var crop_id = ""
	if crop_mgr:
		var crop_entity = _get_crop_at_plot(plot_id)
		if crop_entity:
			crop_id = crop_entity.crop_id
	
	_update_crop_sprite(sprite, crop_id, new_stage)
	
	# Add growth animation
	var tween = create_tween()
	tween.tween_property(sprite, "scale", sprite.scale * 1.2, 0.1)
	tween.tween_property(sprite, "scale", sprite.scale, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _remove_crop_visual(plot_id: String):
	if _crop_instances.has(plot_id):
		_crop_instances[plot_id].queue_free()
		_crop_instances.erase(plot_id)

func _get_stage_name(crop_id: String, stage: int) -> String:
	var file_path = "res://data/crops/%s.json" % crop_id
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			var stages = data.get("stages", [])
			if stage >= 0 and stage < stages.size():
				return stages[stage].get("name", "seed")
	
	match stage:
		0: return "seed"
		1: return "sprout"
		2: return "growing"
		_: return "mature"

func _get_crop_color(crop_id: String) -> Color:
	match crop_id:
		"carrot": return Color(0.9, 0.5, 0.1)
		"tomato": return Color(0.9, 0.2, 0.1)
		"corn": return Color(0.9, 0.8, 0.1)
		"strawberry": return Color(0.9, 0.1, 0.2)
		"wheat": return Color(0.9, 0.7, 0.3)
		_: return Color(0.5, 0.8, 0.3)

## Load existing crops
func _load_existing_crops():
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return
	
	for plot_id in _plot_rects.keys():
		var rect = _plot_rects[plot_id]
		var center_pos = Vector2(rect.position.x + rect.size.x/2, rect.position.y + rect.size.y/2)
		
		# Find crop at this position (scaled detection for 4x world)
		for crop_id in crop_mgr.active_crops.keys():
			var crop = crop_mgr.active_crops[crop_id]
			if crop.position.distance_to(center_pos) < 200:
				_create_crop_visual(plot_id, crop.crop_id)
				break

## Animations
func _animate_plot_action(plot_id: String, action_type: String):
	if not _plots.has(plot_id):
		return
	
	var plot = _plots[plot_id]
	var highlight = plot.get_node("Highlight")
	
	var tween = create_tween()
	highlight.visible = true
	
	match action_type:
		"plant":
			highlight.color = Color(0.2, 0.8, 0.3, 0.3)  # Green
		"water":
			highlight.color = Color(0.2, 0.4, 0.8, 0.3)  # Blue
		"harvest":
			highlight.color = Color(0.9, 0.7, 0.2, 0.3)  # Gold
	
	tween.tween_property(highlight, "color:a", 0.0, 0.3)
	tween.finished.connect(func(): highlight.visible = false)

func _animate_crop_growth(plot_id: String, stage: int):
	if not _crop_instances.has(plot_id):
		return
	
	var crop_node = _crop_instances[plot_id]
	var sprite = crop_node.get_node("CropSprite")
	
	var tween = create_tween()
	sprite.scale = Vector2.ZERO
	tween.tween_property(sprite, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _animate_water_effect(plot_id: String):
	var rect = _plot_rects.get(plot_id, Rect2())
	var center_pos = Vector2(rect.position.x + rect.size.x/2, rect.position.y + rect.size.y/2)
	
	for i in range(5):
		var droplet = _create_droplet()
		droplet.position = center_pos + Vector2(randi() % 40 - 20, -20)
		add_child(droplet)
		
		var tween = create_tween()
		tween.tween_property(droplet, "position:y", center_pos.y + 10, 0.3 + (i * 0.05))
		tween.parallel().tween_property(droplet, "modulate:a", 0, 0.3)
		tween.finished.connect(func(): droplet.queue_free())

func _create_droplet() -> Sprite2D:
	var droplet = Sprite2D.new()
	var image = Image.create(4, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.6, 0.9))
	droplet.texture = ImageTexture.create_from_image(image)
	return droplet

func _animate_harvest(plot_id: String):
	if not _crop_instances.has(plot_id):
		return
	
	var crop_node = _crop_instances[plot_id]
	
	var tween = create_tween()
	tween.tween_property(crop_node, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(crop_node, "position:y", crop_node.position.y - 30, 0.2)
	tween.tween_property(crop_node, "modulate:a", 0, 0.2)

func _show_crop_info(plot_id: String, crop_entity: Node):
	print("[FarmController] Crop info at %s: %s, stage=%d" % [plot_id, crop_entity.crop_id, crop_entity.current_stage])

## Public methods
func set_selected_crop(crop_id: String):
	_selected_crop_id = crop_id

func get_plot_position(plot_id: String) -> Vector2:
	if _plot_rects.has(plot_id):
		var rect = _plot_rects[plot_id]
		return Vector2(rect.position.x + rect.size.x/2, rect.position.y + rect.size.y/2)
	return Vector2.ZERO

## Get plot world position by coordinate (used by ActionSystem)
func get_plot_position_by_coord(coord: Vector2i) -> Vector2:
	for plot_id in _plot_rects.keys():
		var rect = _plot_rects[plot_id]
		var plot_coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))
		if plot_coord == coord:
			return Vector2(rect.position.x + rect.size.x/2, rect.position.y + rect.size.y/2)
	return Vector2.ZERO
