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

# ===== GLOBAL OFFSET (moves all plots together) =====
const GLOBAL_OFFSET_X := 0.0  # Positive = right, Negative = left
const GLOBAL_OFFSET_Y := 0.0  # Positive = down, Negative = up
# ====================================================

# Plot definitions (reference coordinates, will be scaled)
# Format: {id, x, y, w, h, inner_margin, offset_x, offset_y, scale_w, scale_h}
# - offset_x, offset_y: optional per-plot position fine-tuning
# - scale_w, scale_h: optional size multipliers (1.0 = default size)
var PLOT_DEFINITIONS := [
	{
		"h": 170,
		"id": "plot_01",
		"margin": 12,
		"offset_x": 365.5,
		"offset_y": 65.0,
		"scale_h": 1.195,
		"scale_w": 1.65499999999999,
		"w": 128,
		"x": 0,
		"y": 736
	},
	{
		"h": 107,
		"id": "plot_02",
		"margin": 12,
		"offset_x": 107.5,
		"offset_y": -172.0,
		"scale_h": 1.50999999999999,
		"w": 245,
		"x": 275,
		"y": 650
	},
	{
		"h": 105,
		"id": "plot_03",
		"margin": 12,
		"offset_x": -236.5,
		"offset_y": -172.0,
		"scale_h": 1.52499999999999,
		"scale_w": 1.035,
		"w": 237,
		"x": 655,
		"y": 652
	},
	{
		"h": 103,
		"id": "plot_04",
		"margin": 12,
		"offset_x": 172.0,
		"offset_y": -64.5,
		"scale_h": 1.44999999999999,
		"scale_w": 1.11,
		"w": 224,
		"x": 286,
		"y": 796
	},
	{
		"h": 101,
		"id": "plot_05",
		"margin": 12,
		"offset_x": -236.5,
		"offset_y": -43.0,
		"scale_h": 1.49499999999999,
		"scale_w": 1.015,
		"w": 236,
		"x": 657,
		"y": 798
	},
	{
		"h": 103,
		"id": "plot_06",
		"margin": 12,
		"offset_x": 172.0,
		"offset_y": -107.5,
		"scale_h": 1.47999999999999,
		"scale_w": 1.175,
		"w": 207,
		"x": 305,
		"y": 1207
	},
	{
		"h": 100,
		"id": "plot_07",
		"margin": 12,
		"offset_x": -21.5,
		"offset_y": -86.0,
		"scale_h": 1.45499999999999,
		"scale_w": 1.24499999999999,
		"w": 197,
		"x": 655,
		"y": 1208
	},
	{
		"h": 82,
		"id": "plot_08",
		"margin": 10,
		"offset_x": 43.0,
		"offset_y": -150.5,
		"scale_h": 1.58499999999999,
		"scale_w": 1.41499999999999,
		"w": 176,
		"x": 669,
		"y": 1383
	},
	{
		"h": 58,
		"id": "plot_09",
		"margin": 8,
		"offset_x": -129.0,
		"offset_y": 43.0,
		"w": 157,
		"x": 889,
		"y": 1430
	},
	{
		"h": 126,
		"id": "plot_10",
		"margin": 12,
		"w": 283,
		"x": 224,
		"y": 1642
	},
	{
		"h": 210,
		"id": "plot_11",
		"margin": 12,
		"w": 211,
		"x": 664,
		"y": 1560
	},
	{
		"h": 198,
		"id": "plot_12",
		"margin": 12,
		"w": 184,
		"x": 959,
		"y": 1570
	}
]

# Crop tracking
var _crop_instances: Dictionary = {}  # plot_id -> crop_node
var _selected_crop_id: String = "carrot"
var _plots: Dictionary = {}  # plot_id -> plot_node
var _plot_rects: Dictionary = {}  # plot_id -> Rect2 (scaled coordinates)

# ===== PLOT ALIGNMENT DEBUG MODE =====
var _debug_selected_plot: String = ""  # Currently selected plot for adjustment
var _debug_plot_offsets: Dictionary = {}  # plot_id -> {offset_x, offset_y}
var _debug_move_speed: float = 2.0  # 上下左右移动速度
var _debug_scale_speed: float = 0.005  # 放大缩小速度
var _last_key_check: Dictionary = {}  # For tracking key press state
# =====================================

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
	
	# Build custom farm plots
	_build_custom_plots()
	
	# Load existing crops from state
	_load_existing_crops()
	
	print("[FarmController] Initialized with %d custom plots" % PLOT_DEFINITIONS.size())
	
	# Initialize debug offsets from plot definitions
	for plot_def in PLOT_DEFINITIONS:
		_debug_plot_offsets[plot_def.id] = {
			"offset_x": plot_def.get("offset_x", 0.0),
			"offset_y": plot_def.get("offset_y", 0.0),
			"scale_w": plot_def.get("scale_w", 1.0),  # Width scale multiplier
			"scale_h": plot_def.get("scale_h", 1.0)   # Height scale multiplier
		}
	
	print("[FarmController] DEBUG MODE:")
	print("  1-9,0: Select | Arrows: Move(fast) | [/]: Width(slow) | +/-: Height(slow)")
	print("  ': Reset | ,/.: MoveSpeed | R: Rebuild | S: Save to Code")

func _process(delta):
	_handle_debug_input()

## Handle debug input for plot alignment
func _handle_debug_input():
	# Number keys 1-9 to select plots (use KEY_1 - KEY_9)
	if _is_key_just_pressed(KEY_1):
		_select_plot_for_debug(1)
	elif _is_key_just_pressed(KEY_2):
		_select_plot_for_debug(2)
	elif _is_key_just_pressed(KEY_3):
		_select_plot_for_debug(3)
	elif _is_key_just_pressed(KEY_4):
		_select_plot_for_debug(4)
	elif _is_key_just_pressed(KEY_5):
		_select_plot_for_debug(5)
	elif _is_key_just_pressed(KEY_6):
		_select_plot_for_debug(6)
	elif _is_key_just_pressed(KEY_7):
		_select_plot_for_debug(7)
	elif _is_key_just_pressed(KEY_8):
		_select_plot_for_debug(8)
	elif _is_key_just_pressed(KEY_9):
		_select_plot_for_debug(9)
	elif _is_key_just_pressed(KEY_0):
		_select_plot_for_debug(10)
	
	# Handle plot adjustment
	_handle_plot_adjustment()

func _is_key_just_pressed(key: int) -> bool:
	var is_pressed: bool = Input.is_key_pressed(key)
	var was_pressed: bool = _last_key_check.get(key, false) if _last_key_check.has(key) else false
	_last_key_check[key] = is_pressed
	return is_pressed and not was_pressed

func _handle_plot_adjustment():
	if _debug_selected_plot.is_empty():
		return
	
	var adjusted = false
	
	# Arrow keys to adjust position (上下左右移动) - 使用更快的速度
	if _is_key_just_pressed(KEY_LEFT):
		_debug_plot_offsets[_debug_selected_plot].offset_x -= _debug_move_speed
		adjusted = true
	if _is_key_just_pressed(KEY_RIGHT):
		_debug_plot_offsets[_debug_selected_plot].offset_x += _debug_move_speed
		adjusted = true
	if _is_key_just_pressed(KEY_UP):
		_debug_plot_offsets[_debug_selected_plot].offset_y -= _debug_move_speed
		adjusted = true
	if _is_key_just_pressed(KEY_DOWN):
		_debug_plot_offsets[_debug_selected_plot].offset_y += _debug_move_speed
		adjusted = true
	
	# ] 键：增加宽度 (右侧放大) - 使用更慢的缩放速度
	if Input.is_key_pressed(KEY_BRACKETRIGHT):
		_debug_plot_offsets[_debug_selected_plot].scale_w += _debug_scale_speed
		adjusted = true
	
	# [ 键：减少宽度 (右侧缩小)
	if Input.is_key_pressed(KEY_BRACKETLEFT):
		_debug_plot_offsets[_debug_selected_plot].scale_w = max(0.1, _debug_plot_offsets[_debug_selected_plot].scale_w - _debug_scale_speed)
		adjusted = true
	
	# = 键：增加高度 (向下放大)
	if Input.is_key_pressed(KEY_EQUAL):
		_debug_plot_offsets[_debug_selected_plot].scale_h += _debug_scale_speed
		adjusted = true
	
	# - 键：减少高度 (向下缩小)
	if Input.is_key_pressed(KEY_MINUS):
		_debug_plot_offsets[_debug_selected_plot].scale_h = max(0.1, _debug_plot_offsets[_debug_selected_plot].scale_h - _debug_scale_speed)
		adjusted = true
	
	# ' 键：重置当前土地到默认状态
	if _is_key_just_pressed(KEY_APOSTROPHE):
		_debug_plot_offsets[_debug_selected_plot].offset_x = 0.0
		_debug_plot_offsets[_debug_selected_plot].offset_y = 0.0
		_debug_plot_offsets[_debug_selected_plot].scale_w = 1.0
		_debug_plot_offsets[_debug_selected_plot].scale_h = 1.0
		adjusted = true
		print("[FarmController] %s reset to default" % _debug_selected_plot)
	
	# . / , 键调整移动速度 (不影响缩放速度)
	if Input.is_key_pressed(KEY_PERIOD):
		_debug_move_speed += 0.5
		print("[FarmController] Move speed: %.1f, Scale speed: %.3f" % [_debug_move_speed, _debug_scale_speed])
	if Input.is_key_pressed(KEY_COMMA):
		_debug_move_speed = max(0.5, _debug_move_speed - 0.5)
		print("[FarmController] Move speed: %.1f, Scale speed: %.3f" % [_debug_move_speed, _debug_scale_speed])
	
	# Print current offsets and scales
	if adjusted:
		var offset = _debug_plot_offsets[_debug_selected_plot]
		print("[FarmController] %s: offset_x=%.1f, offset_y=%.1f, scale_w=%.2f, scale_h=%.2f" % [
			_debug_selected_plot, offset.offset_x, offset.offset_y, offset.scale_w, offset.scale_h
		])
		_rebuild_selected_plot(_debug_selected_plot)
	
	# R key to rebuild all plots
	if _is_key_just_pressed(KEY_R):
		_rebuild_all_plots()
		print("[FarmController] All plots rebuilt")
	
	# S key to save all plot adjustments to code
	if _is_key_just_pressed(KEY_S):
		_save_plot_adjustments()

func _save_plot_adjustments():
	# Save to JSON file
	var save_data = []
	for plot_def in PLOT_DEFINITIONS:
		var plot_id = plot_def.id
		var offset = _debug_plot_offsets.get(plot_id, {"offset_x": 0.0, "offset_y": 0.0, "scale_w": 1.0, "scale_h": 1.0})
		
		var plot_data = {
			"id": plot_id,
			"x": plot_def.x,
			"y": plot_def.y,
			"w": plot_def.w,
			"h": plot_def.h,
			"margin": plot_def.margin
		}
		
		# Only add non-default values
		if abs(offset.offset_x) > 0.01:
			plot_data["offset_x"] = offset.offset_x
		if abs(offset.offset_y) > 0.01:
			plot_data["offset_y"] = offset.offset_y
		if abs(offset.scale_w - 1.0) > 0.01:
			plot_data["scale_w"] = offset.scale_w
		if abs(offset.scale_h - 1.0) > 0.01:
			plot_data["scale_h"] = offset.scale_h
		
		save_data.append(plot_data)
	
	# Save to file
	var json_string = JSON.stringify(save_data, "\t")
	var file_path = "res://data/plot_adjustments.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[FarmController] Plot adjustments saved to: %s" % file_path)
	else:
		push_error("[FarmController] Failed to save plot adjustments!")
		return
	
	# Also print to console for easy copy-paste
	print("\n========== PLOT DEFINITIONS (COPY TO CODE) ==========\n")
	print("var PLOT_DEFINITIONS := [")
	for plot_data in save_data:
		var line = '\t{'
		var parts = []
		parts.append('"id": "%s"' % plot_data.id)
		parts.append('"x": %d' % plot_data.x)
		parts.append('"y": %d' % plot_data.y)
		parts.append('"w": %d' % plot_data.w)
		parts.append('"h": %d' % plot_data.h)
		parts.append('"margin": %d' % plot_data.margin)
		if plot_data.has("offset_x"):
			parts.append('"offset_x": %.1f' % plot_data.offset_x)
		if plot_data.has("offset_y"):
			parts.append('"offset_y": %.1f' % plot_data.offset_y)
		if plot_data.has("scale_w"):
			parts.append('"scale_w": %.2f' % plot_data.scale_w)
		if plot_data.has("scale_h"):
			parts.append('"scale_h": %.2f' % plot_data.scale_h)
		line += ", ".join(parts)
		line += "},"
		print(line)
	print("]")
	print("\n===================================================\n")

func _select_plot_for_debug(index: int):
	if index <= PLOT_DEFINITIONS.size():
		_debug_selected_plot = PLOT_DEFINITIONS[index - 1].id
		var offset = _debug_plot_offsets[_debug_selected_plot]
		print("[FarmController] Selected %s:" % _debug_selected_plot)
		print("  Position: offset_x=%.1f, offset_y=%.1f" % [offset.offset_x, offset.offset_y])
		print("  Size: scale_w=%.2f, scale_h=%.2f ([/]=width, +/-=height, '=reset)" % [offset.scale_w, offset.scale_h])
		_highlight_selected_plot()

func _highlight_selected_plot():
	# Reset all highlights
	for plot_id in _plots:
		var plot = _plots[plot_id]
		var highlight = plot.get_node_or_null("Highlight")
		if highlight:
			highlight.color = Color(0.2, 0.8, 0.3, 0.3)
	
	# Highlight selected
	if _plots.has(_debug_selected_plot):
		var selected_plot = _plots[_debug_selected_plot]
		var highlight = selected_plot.get_node_or_null("Highlight")
		if highlight:
			highlight.color = Color(1.0, 0.2, 0.2, 0.5)  # Red highlight

func _rebuild_selected_plot(plot_id: String):
	# Find plot definition
	for i in range(PLOT_DEFINITIONS.size()):
		if PLOT_DEFINITIONS[i].id == plot_id:
			# Update the offset and scale in plot definition
			var offset = _debug_plot_offsets[plot_id]
			PLOT_DEFINITIONS[i]["offset_x"] = offset.offset_x
			PLOT_DEFINITIONS[i]["offset_y"] = offset.offset_y
			PLOT_DEFINITIONS[i]["scale_w"] = offset.scale_w
			PLOT_DEFINITIONS[i]["scale_h"] = offset.scale_h
			
			# Remove old plot
			if _plots.has(plot_id):
				_plots[plot_id].queue_free()
				_plots.erase(plot_id)
			
			# Create new plot with updated offset and scale
			var new_plot = _create_custom_plot(PLOT_DEFINITIONS[i])
			plots_container.add_child(new_plot)
			_plots[plot_id] = new_plot
			
			_highlight_selected_plot()
			break

func _rebuild_all_plots():
	# Clear all plots
	for plot_id in _plots:
		_plots[plot_id].queue_free()
	_plots.clear()
	_plot_rects.clear()
	
	# Rebuild all
	_build_custom_plots()

## Scale a reference coordinate to actual world coordinate (4x scaled)
## Includes global offset and per-plot offset
func _scale_x(ref_x: float, plot_offset_x: float = 0.0) -> float:
	return ref_x * TOTAL_SCALE_X + GLOBAL_OFFSET_X + plot_offset_x

func _scale_y(ref_y: float, plot_offset_y: float = 0.0) -> float:
	return ref_y * TOTAL_SCALE_Y + GLOBAL_OFFSET_Y + plot_offset_y

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
	
	# Get per-plot offset and scale (if defined)
	var plot_offset_x = plot_def.get("offset_x", 0.0)
	var plot_offset_y = plot_def.get("offset_y", 0.0)
	var scale_w = plot_def.get("scale_w", 1.0)
	var scale_h = plot_def.get("scale_h", 1.0)
	
	# Calculate base scaled dimensions (without scale multipliers)
	var base_scaled_x = _scale_x(ref_x, plot_offset_x)
	var base_scaled_y = _scale_y(ref_y, plot_offset_y)
	var base_scaled_w = _scale_x(ref_w)
	var base_scaled_h = _scale_y(ref_h)
	
	# Apply scale multipliers
	var scaled_w = base_scaled_w * scale_w
	var scaled_h = base_scaled_h * scale_h
	
	# Anchor scaling from TOP-RIGHT corner
	# Right edge stays fixed, so x position shifts left when width increases
	# Top edge stays fixed, so y position stays the same when height increases
	var scaled_x = base_scaled_x + base_scaled_w - scaled_w
	var scaled_y = base_scaled_y
	
	var scaled_margin_x = _scale_x(margin) * scale_w
	var scaled_margin_y = _scale_y(margin) * scale_h
	
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
	# Check if tool mode is active - if so, let tools handle it
	if _sickle_tool and _sickle_tool.is_active():
		return
	if _water_tool and _water_tool.is_active():
		return
	
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
		_play_sfx("plant")

func _try_water_crop(plot_id: String):
	var rect = _plot_rects.get(plot_id, Rect2())
	var coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))
	
	var success = ActionSystem.water(coord)
	if success:
		_animate_plot_action(plot_id, "water")
		_play_sfx("water")

func _try_harvest_crop(plot_id: String):
	var rect = _plot_rects.get(plot_id, Rect2())
	var coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))
	
	var success = ActionSystem.harvest(coord)
	if success:
		_animate_plot_action(plot_id, "harvest")
		_play_sfx("harvest")

## Signal Handlers
func _on_crop_planted(coord: Vector2i, crop_id: String):
	# Visual is now handled by CropEntity itself
	# Just play growth animation at the plot position
	for plot_id in _plot_rects.keys():
		var rect = _plot_rects[plot_id]
		var plot_coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))
		if plot_coord == coord:
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
	print("[FarmController] Crop harvested at coord: %s" % str(coord))
	for plot_id in _plot_rects.keys():
		var rect = _plot_rects[plot_id]
		var plot_coord = Vector2i(int(rect.position.x / 100), int(rect.position.y / 100))
		if plot_coord == coord:
			_animate_harvest(plot_id)
			# Remove visual after animation completes
			var timer = get_tree().create_timer(0.5)
			timer.timeout.connect(func(): _remove_crop_visual(plot_id))
			return

## Visual Creation
func _create_crop_visual(plot_id: String, crop_id: String):
	if _crop_instances.has(plot_id):
		return
	
	var rect = _plot_rects.get(plot_id, Rect2())
	
	# Create a container node for all crops in this plot
	var crop_container = Node2D.new()
	crop_container.name = "Crop_" + plot_id
	crop_container.position = Vector2(rect.position.x + rect.size.x/2, rect.position.y + rect.size.y/2)
	
	# Calculate how many crops fit in this plot based on ACTUAL size (after adjustments)
	# Use the actual rect size to determine crop count and spacing
	var available_w = rect.size.x * 0.8  # Use 80% of width to avoid edge
	var available_h = rect.size.y * 0.8  # Use 80% of height to avoid edge
	var plot_area = rect.size.x * rect.size.y
	
	# Determine crop count based on actual plot size
	var total_crops: int
	if plot_area < 60000:  # Small plot
		total_crops = 8
	elif plot_area < 100000:  # Medium plot
		total_crops = 12
	else:  # Large plot
		total_crops = 16
	
	# Calculate optimal grid based on aspect ratio
	var plot_ratio = rect.size.x / rect.size.y
	var cols: int
	var rows: int
	
	if total_crops == 8:
		if plot_ratio > 1.5:
			cols = 4
			rows = 2
		elif plot_ratio < 0.7:
			cols = 2
			rows = 4
		else:
			cols = 3
			rows = 3
	elif total_crops == 12:
		if plot_ratio > 1.5:
			cols = 4
			rows = 3
		elif plot_ratio < 0.7:
			cols = 3
			rows = 4
		else:
			cols = 3
			rows = 4
	else:  # 16
		cols = 4
		rows = 4
	
	# Calculate spacing to evenly fill the available space
	var crop_spacing_x = available_w / max(1, cols - 1) if cols > 1 else 0
	var crop_spacing_y = available_h / max(1, rows - 1) if rows > 1 else 0
	
	# Calculate starting position (centered in plot)
	var start_x = -(cols - 1) * crop_spacing_x / 2
	var start_y = -(rows - 1) * crop_spacing_y / 2
	
	# Create individual crops in a grid
	var crop_count = 0
	for row in range(rows):
		for col in range(cols):
			if crop_count >= total_crops:
				break
			
			var crop = Node2D.new()
			crop.name = "Crop_%d_%d" % [row, col]
			crop.position = Vector2(start_x + col * crop_spacing_x, start_y + row * crop_spacing_y)
			
			# Even distribution - small random variation for natural look (±5 pixels)
			crop.position += Vector2(randf() * 10 - 5, randf() * 10 - 5)
			
			# Create crop sprite
			var sprite = Sprite2D.new()
			sprite.name = "CropSprite"
			sprite.position.y = -10
			
			_update_crop_sprite(sprite, crop_id, 0, 0.45)  # Balanced scale for 8-16 plants
			
			crop.add_child(sprite)
			crop_container.add_child(crop)
			crop_count += 1
	
	crops_container.add_child(crop_container)
	_crop_instances[plot_id] = crop_container
	
	print("[FarmController] Created %d crops in %s (%dx%d grid)" % [crop_count, plot_id, cols, rows])

func _update_crop_sprite(sprite: Sprite2D, crop_id: String, stage: int, base_scale: float = 1.0):
	var stage_name = _get_stage_name(crop_id, stage)
	var texture_path = "res://assets/crops/%s/%s_%s.png" % [crop_id, crop_id, stage_name]
	
	print("[FarmController] Updating sprite: crop=%s, stage=%d, stage_name=%s, path=%s" % [crop_id, stage, stage_name, texture_path])
	
	if ResourceLoader.exists(texture_path):
		var tex = load(texture_path)
		sprite.texture = tex
		print("[FarmController] Sprite loaded successfully: %s" % texture_path)
		# Scale to fit plot in 4x world (max 224px = 56 * 4) * base_scale * 1.5 magnitude
		var target_size = 224.0 * base_scale * 1.5  # 1.5x magnitude increase
		if tex.get_width() > 0:
			var scale_factor = target_size / tex.get_width()
			sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		push_warning("[FarmController] Missing sprite: %s" % texture_path)
		print("[FarmController] Using fallback color block for: %s" % crop_id)
		var size = int((128 + (stage * 32)) * base_scale * 1.5)  # Scaled for 4x world * 1.5x magnitude
		var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		image.fill(_get_crop_color(crop_id))
		sprite.texture = ImageTexture.create_from_image(image)

func _update_crop_visual_stage(plot_id: String, new_stage: int):
	print("[FarmController] _update_crop_visual_stage called: plot_id=%s, new_stage=%d" % [plot_id, new_stage])
	
	if not _crop_instances.has(plot_id):
		print("[FarmController] ERROR: plot_id %s not found in _crop_instances" % plot_id)
		return
	
	var crop_container = _crop_instances[plot_id]
	print("[FarmController] Found crop container with %d children" % crop_container.get_child_count())
	
	# Get crop ID from CropManager
	var crop_mgr = get_node_or_null("/root/CropManager")
	var crop_id = ""
	if crop_mgr:
		var crop_entity = _get_crop_at_plot(plot_id)
		if crop_entity:
			crop_id = crop_entity.crop_id
			print("[FarmController] Got crop_id from CropManager: %s" % crop_id)
		else:
			print("[FarmController] WARNING: Could not get crop entity from CropManager for plot %s" % plot_id)
	else:
		print("[FarmController] WARNING: CropManager not found")
	
	# Update all crop sprites in the container
	var updated_count = 0
	for crop in crop_container.get_children():
		var sprite = crop.get_node_or_null("CropSprite")
		if sprite:
			_update_crop_sprite(sprite, crop_id, new_stage, 0.45)
			updated_count += 1
			
			# Add growth animation with slight delay for each crop
			var tween = create_tween()
			var delay = randf() * 0.1  # Random delay for natural look
			tween.tween_interval(delay)
			tween.tween_property(sprite, "scale", sprite.scale * 1.2, 0.1)
			tween.tween_property(sprite, "scale", sprite.scale, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	print("[FarmController] Updated %d crop sprites for plot %s" % [updated_count, plot_id])

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
		
		# Find crop at this position - visual handled by CropEntity
		for crop_id in crop_mgr.active_crops.keys():
			var crop = crop_mgr.active_crops[crop_id]
			if crop.position.distance_to(center_pos) < 200:
				# CropEntity handles its own visual
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
	
	var crop_container = _crop_instances[plot_id]
	
	# Animate all crops with staggered timing
	var crop_index = 0
	for crop in crop_container.get_children():
		var sprite = crop.get_node_or_null("CropSprite")
		if sprite:
			var tween = create_tween()
			var target_scale = sprite.scale
			sprite.scale = Vector2.ZERO
			tween.tween_interval(crop_index * 0.05)  # Staggered animation
			tween.tween_property(sprite, "scale", target_scale, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			crop_index += 1

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

func _animate_growth_effect(plot_id: String, stage: int):
	if not _crop_instances.has(plot_id):
		return
	
	var crop_container = _crop_instances[plot_id]
	
	# Create growth particles
	for i in range(5):
		var particle = _create_growth_particle()
		var rect = _plot_rects.get(plot_id, Rect2())
		particle.position = Vector2(
			rect.position.x + rect.size.x/2 + randf() * 60 - 30,
			rect.position.y + rect.size.y/2 + randf() * 40 - 20
		)
		add_child(particle)
		
		var tween = create_tween()
		tween.tween_interval(randf() * 0.3)
		tween.tween_property(particle, "position:y", particle.position.y - 50, 0.8)
		tween.parallel().tween_property(particle, "modulate:a", 0, 0.8)
		tween.finished.connect(func(): particle.queue_free())
	
	# Animate crops with bounce effect
	for crop in crop_container.get_children():
		var sprite = crop.get_node_or_null("CropSprite")
		if sprite:
			var tween = create_tween()
			var delay = randf() * 0.15
			tween.tween_interval(delay)
			# Pop up animation
			tween.tween_property(sprite, "scale", sprite.scale * 1.4, 0.15).set_ease(Tween.EASE_OUT)
			tween.tween_property(sprite, "scale", sprite.scale, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			
			# Add sparkle effect for stage 3+
			if stage >= 3:
				var sparkle = _create_sparkle()
				sparkle.position = crop.position
				crop_container.add_child(sparkle)
				
				var s_tween = create_tween()
				s_tween.tween_interval(delay + 0.2)
				s_tween.tween_property(sparkle, "scale", Vector2(1.5, 1.5), 0.3)
				s_tween.parallel().tween_property(sparkle, "modulate:a", 0, 0.3)
				s_tween.finished.connect(func(): sparkle.queue_free())

func _create_growth_particle() -> Sprite2D:
	var particle = Sprite2D.new()
	var size = 8
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Draw plus sign
	var color = Color(0.4, 0.9, 0.3, 0.8)
	for x in range(size):
		img.set_pixel(x, size/2, color)
	for y in range(size):
		img.set_pixel(size/2, y, color)
	
	particle.texture = ImageTexture.create_from_image(img)
	particle.modulate = Color(0.5, 1.0, 0.4, 0.9)
	return particle

func _create_sparkle() -> Sprite2D:
	var sparkle = Sprite2D.new()
	var size = 16
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Draw star shape
	var color = Color(1, 1, 0.6, 0.9)
	var center = size / 2
	for r in range(4):
		for i in range(center):
			img.set_pixel(center, i, color)
			img.set_pixel(center, size - 1 - i, color)
			img.set_pixel(i, center, color)
			img.set_pixel(size - 1 - i, center, color)
	
	sparkle.texture = ImageTexture.create_from_image(img)
	sparkle.modulate = Color(1, 1, 0.5, 1)
	return sparkle

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

## Play sound effect for actions
func _play_sfx(action: String):
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if not audio_mgr:
		return
	
	var sfx_path: String
	match action:
		"plant":
			sfx_path = "res://assets/audio/sfx/planting/Firefly_audio_Create_a_relaxing_sound_for_planting_plants,_for_a_variation2.wav"
		"water":
			sfx_path = "res://assets/audio/sfx/watering/Firefly_audio_Create_a_relaxing_sound_for_watering_plants,_for_a_variation4.wav"
		"harvest":
			sfx_path = "res://assets/audio/sfx/cropping/Firefly_audio_Create_a_relaxing_sound_for_harvesting_crops,_for__variation4.wav"
		_:
			return
	
	if ResourceLoader.exists(sfx_path):
		audio_mgr.play_sfx_path(sfx_path)
		print("[FarmController] Playing SFX: %s" % action)

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

## Tool Mode Management
var _sickle_tool: Node2D = null
var _water_tool: Node2D = null

func set_sickle_mode(active: bool):
	if not _sickle_tool:
		_sickle_tool = get_node_or_null("SickleTool")
	if _sickle_tool:
		if active:
			_sickle_tool.activate()
		else:
			_sickle_tool.deactivate()

func set_water_mode(active: bool):
	if not _water_tool:
		_water_tool = get_node_or_null("WateringCanTool")
	if _water_tool:
		if active:
			_water_tool.activate()
		else:
			_water_tool.deactivate()
