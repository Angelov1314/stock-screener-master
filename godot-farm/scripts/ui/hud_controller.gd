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
@onready var day_label: Label = %DayLabel
@onready var season_label: Label = %SeasonLabel
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

func _ready():
	print("[HUDController] Initializing...")
	
	# Connect button signals
	sickle_button.pressed.connect(_on_sickle_pressed)
	water_button.pressed.connect(_on_water_pressed)
	plant_button.pressed.connect(_on_plant_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	
	# Initial UI update
	var state = get_node_or_null("/root/StateManager")
	if state:
		_update_gold_display(state.get_gold())
		_update_day_display(state.current_day)
		_update_player_info(state.get_player_name(), state.get_player_level(), state.get_experience(), state.get_xp_for_next_level(), state.get_xp_progress())
		state.state_changed.connect(_on_state_changed)
	else:
		_update_gold_display(100)  # Starting gold
		_update_day_display(1)
		_update_player_info("农场主", 1, 0, 100, 0.0)
	_update_season_display("Spring")
	
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
func _update_day_display(day: int):
	day_label.text = "Day " + str(day)

func _update_season_display(season: String):
	season_label.text = season

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
		player_xp_bar.value = xp_progress * 100

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
		"advance_time":
			_update_day_display(state.current_day)
