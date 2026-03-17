class_name HUDController
extends CanvasLayer

## HUD Controller - Handles all HUD UI updates

signal inventory_requested
signal shop_requested
signal planting_menu_requested
signal sickle_mode_toggled(active: bool)
signal water_mode_toggled(active: bool)

# UI References
@onready var gold_label: Label = %GoldLabel
@onready var gold_icon: TextureRect = %GoldIcon
@onready var gold_frame: TextureRect = %GoldFrame
@onready var player_title_label: Label = %PlayerTitleLabel
@onready var name_edit: LineEdit = %NameEdit
@onready var growth_info_label: Label = %GrowthInfoLabel
@onready var sickle_button: TextureButton = %SickleButton
@onready var water_button: TextureButton = %WaterButton
@onready var plant_button: TextureButton = %PlantButton
@onready var inventory_button: TextureButton = %InventoryButton
@onready var shop_button: TextureButton = %ShopButton
@onready var toast_container: VBoxContainer = %ToastContainer

# Player Info UI References
@onready var player_name_label: Label = %NameLabel
@onready var player_level_label: Label = %LevelLabel
@onready var player_xp_label: Label = %XPLabel
@onready var player_xp_bar: ProgressBar = %XPBar

# State
var _sickle_active: bool = false
var _water_active: bool = false

# Gold frame positioning (tuned values)
var _gold_frame_offset: Vector2 = Vector2(-26.0, -11.0)
var _gold_frame_scale: Vector2 = Vector2(1.65, 1.65)
var _gold_frame_debug_mode: bool = false

func _ready():
	print("[HUDController] Initializing...")
	
	# Connect button signals
	sickle_button.pressed.connect(_on_sickle_pressed)
	water_button.pressed.connect(_on_water_pressed)
	plant_button.pressed.connect(_on_plant_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	
	# Connect name edit signal
	if name_edit:
		name_edit.text_changed.connect(_on_name_changed)
	
	# Initial UI update
	var state = get_node_or_null("/root/StateManager")
	if state:
		_update_gold_display(state.get_gold())
		_update_player_name(state.get_player_name())
		_update_player_info(state.get_player_name(), state.get_player_level(), state.get_experience(), state.get_xp_for_next_level(), state.get_xp_progress())
		state.state_changed.connect(_on_state_changed)
	else:
		_update_gold_display(300)  # Starting gold
		_update_player_name("农场主")
		_update_player_info("农场主", 1, 0, 100, 0.0)
	
	# Load gold frame texture and apply tuned position
	if gold_frame:
		gold_frame.texture = load("res://assets/ui/gold_frame.png")
		gold_frame.position = _gold_frame_offset
		gold_frame.scale = _gold_frame_scale
		print("[HUDController] Gold frame positioned at %s with scale %s" % [_gold_frame_offset, _gold_frame_scale])
	
	print("[HUDController] Initialized")

## Button Handlers
func _on_sickle_pressed():
	_sickle_active = !_sickle_active
	_water_active = false
	_update_button_states()
	sickle_mode_toggled.emit(_sickle_active)
	print("[HUD] Sickle mode: %s" % _sickle_active)

func _on_water_pressed():
	_water_active = !_water_active
	_sickle_active = false
	_update_button_states()
	water_mode_toggled.emit(_water_active)
	print("[HUD] Water mode: %s" % _water_active)

func _on_plant_pressed():
	_animate_button(plant_button)
	planting_menu_requested.emit()
	print("[HUD] Plant button pressed")

func _on_inventory_pressed():
	_animate_button(inventory_button)
	inventory_requested.emit()

func _on_shop_pressed():
	_animate_button(shop_button)
	shop_requested.emit()

func _update_button_states():
	# Highlight active button
	sickle_button.modulate = Color(1.2, 1.2, 0.8) if _sickle_active else Color.WHITE
	water_button.modulate = Color(0.8, 0.8, 1.2) if _water_active else Color.WHITE

func _animate_button(button: TextureButton):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

## Public Methods
func is_sickle_mode() -> bool:
	return _sickle_active

func is_water_mode() -> bool:
	return _water_active

func deactivate_tools():
	_sickle_active = false
	_water_active = false
	_update_button_states()

## Gold Display
func _update_gold_display(amount: int):
	gold_label.text = str(amount)

func update_gold(amount: int):
	_update_gold_display(amount)

## Day/Season Display
func _update_player_name(name: String):
	if player_title_label:
		player_title_label.text = "农场主：" + name

func _on_name_changed(new_name: String):
	# Update StateManager with new name
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.apply_action({"type": "set_player_name", "name": new_name})
	print("[HUD] Player name changed to: %s" % new_name)

## Toast Notifications
func show_toast(message: String):
	var toast = Label.new()
	toast.text = message
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 18)
	toast.add_theme_color_override("font_color", Color.WHITE)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.set_corner_radius_all(8)
	toast.add_theme_stylebox_override("normal", style)
	
	toast_container.add_child(toast)
	
	# Animate
	toast.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(toast, "modulate:a", 1, 0.2)
	
	await get_tree().create_timer(2.0).timeout
	
	# Remove
	var out_tween = create_tween()
	out_tween.tween_property(toast, "modulate:a", 0, 0.2)
	await out_tween.finished
	toast.queue_free()

## Player Info Display
func _update_player_info(name: String, level: int, xp: int, xp_next: int, xp_progress: float):
	if player_name_label:
		player_name_label.text = name
	if player_level_label:
		player_level_label.text = "Lv.%d" % level
	if player_xp_label:
		player_xp_label.text = "XP: %d/%d" % [xp, xp_next]
	if player_xp_bar:
		# Animate XP bar with tween
		var target_value = xp_progress * 100
		var tween = create_tween()
		tween.tween_property(player_xp_bar, "value", target_value, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## State Change Handler
func _on_state_changed(action: Dictionary):
	var state = get_node_or_null("/root/StateManager")
	if not state:
		return
	
	match action.type:
		"add_gold", "remove_gold":
			_update_gold_display(state.get_gold())
		"add_experience", "harvest_crop":
			_update_player_info(state.get_player_name(), state.get_player_level(), state.get_experience(), state.get_xp_for_next_level(), state.get_xp_progress())
		"set_player_name":
			_update_player_name(state.get_player_name())

## Debug Functions for Gold Frame Positioning
func _input(event):
	# Toggle debug mode with F12
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_gold_frame_debug_mode = !_gold_frame_debug_mode
		print("[HUD] Gold frame debug mode: %s" % _gold_frame_debug_mode)
		if _gold_frame_debug_mode:
			show_toast("Gold Frame Debug: ON (WASD/Arrows to move, +/- to scale, C to copy)")
		else:
			_output_gold_frame_values()
		return
	
	# Output values with F11 or C in debug mode
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11 or (_gold_frame_debug_mode and event.keycode == KEY_C):
			_output_gold_frame_values()
			return
	
	if not _gold_frame_debug_mode or not gold_frame:
		return
	
	var move_speed = 1.0
	var scale_speed = 0.05
	var changed = false
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_W, KEY_UP:
				_gold_frame_offset.y -= move_speed
				changed = true
			KEY_S, KEY_DOWN:
				_gold_frame_offset.y += move_speed
				changed = true
			KEY_A, KEY_LEFT:
				_gold_frame_offset.x -= move_speed
				changed = true
			KEY_D, KEY_RIGHT:
				_gold_frame_offset.x += move_speed
				changed = true
			KEY_EQUAL, KEY_KP_ADD:
				_gold_frame_scale += Vector2(scale_speed, scale_speed)
				changed = true
			KEY_MINUS, KEY_KP_SUBTRACT:
				_gold_frame_scale -= Vector2(scale_speed, scale_speed)
				changed = true
			KEY_R:
				_gold_frame_offset = Vector2(-26.0, -11.0)
				_gold_frame_scale = Vector2(1.65, 1.65)
				changed = true
	
	if changed:
		_update_gold_frame_position()

func _update_gold_frame_position():
	if not gold_frame:
		return
	
	# Apply offset and scale to the gold frame
	gold_frame.position = _gold_frame_offset
	gold_frame.scale = _gold_frame_scale
	
	print("[HUD Debug] Gold frame offset: %s, scale: %s" % [_gold_frame_offset, _gold_frame_scale])

func _output_gold_frame_values():
	if not gold_frame:
		return
	
	var output = """[Gold Frame Values]
Offset: Vector2(%.1f, %.1f)
Scale: Vector2(%.2f, %.2f)

Code to paste:
_gold_frame_offset = Vector2(%.1f, %.1f)
_gold_frame_scale = Vector2(%.2f, %.2f)
""" % [
		_gold_frame_offset.x, _gold_frame_offset.y, _gold_frame_scale.x, _gold_frame_scale.y,
		_gold_frame_offset.x, _gold_frame_offset.y, _gold_frame_scale.x, _gold_frame_scale.y
	]
	
	print(output)
	show_toast("Gold frame values copied to console!")
	
	# Try to copy to clipboard if available
	if OS.has_feature("pc"):
		DisplayServer.clipboard_set("_gold_frame_offset = Vector2(%.1f, %.1f)\n_gold_frame_scale = Vector2(%.2f, %.2f)" % [_gold_frame_offset.x, _gold_frame_offset.y, _gold_frame_scale.x, _gold_frame_scale.y])
		print("[HUD] Values also copied to clipboard!")
