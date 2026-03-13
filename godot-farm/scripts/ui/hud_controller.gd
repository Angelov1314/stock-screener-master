class_name HUDController
extends CanvasLayer

## HUD Controller - Handles all HUD UI updates
## Connects to ActionSystem signals for state changes

# UI References - using unique names for safety
@onready var gold_label: Label = %GoldLabel
@onready var gold_icon: TextureRect = %GoldIcon
@onready var day_label: Label = %DayLabel
@onready var season_label: Label = %SeasonLabel
@onready var growth_info_label: Label = %GrowthInfoLabel
@onready var inventory_button: Button = %InventoryButton
@onready var shop_button: Button = %ShopButton
@onready var settings_button: Button = %SettingsButton
@onready var toast_container: VBoxContainer = %ToastContainer

# Animation settings
const BUTTON_PRESS_SCALE := 0.95
const BUTTON_ANIMATION_TIME := 0.1
const TOAST_DURATION := 2.0

func _ready():
	print("[HUDController] Initializing...")
	
	# Connect to ActionSystem signals (deferred to ensure autoloads are ready)
	var action_sys = get_node_or_null("/root/ActionSystem")
	if action_sys:
		action_sys.gold_changed.connect(_on_gold_changed)
		action_sys.inventory_changed.connect(_on_inventory_changed)
		action_sys.crop_planted.connect(_on_crop_planted)
		action_sys.crop_harvested.connect(_on_crop_harvested)
	else:
		push_warning("[HUDController] ActionSystem not found, connecting deferred")
		call_deferred("_connect_action_system")
	
	# Button connections with animation
	inventory_button.pressed.connect(_on_inventory_button_pressed)
	shop_button.pressed.connect(_on_shop_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	
	# Initial UI update
	var state = get_node_or_null("/root/StateManager")
	if state:
		_update_gold_display(state.get_gold())
		_update_day_display(state.current_day)
	else:
		_update_gold_display(0)
		_update_day_display(1)
	_update_season_display("Spring")
	
	# Start growth info update timer
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_growth_info)
	add_child(timer)
	timer.start()
	
	print("[HUDController] Initialized successfully")

func _connect_action_system():
	var action_sys = get_node_or_null("/root/ActionSystem")
	if action_sys:
		action_sys.gold_changed.connect(_on_gold_changed)
		action_sys.inventory_changed.connect(_on_inventory_changed)
		action_sys.crop_planted.connect(_on_crop_planted)
		action_sys.crop_harvested.connect(_on_crop_harvested)

## Gold Display
func _on_gold_changed(new_amount: int):
	_animate_gold_change(new_amount)

func _update_gold_display(amount: int):
	gold_label.text = str(amount)

func _animate_gold_change(new_amount: int):
	var old_amount = int(gold_label.text) if gold_label.text.is_valid_int() else 0
	
	# Create count-up animation
	var tween = create_tween()
	tween.tween_method(
		func(val): gold_label.text = str(int(val)),
		old_amount,
		new_amount,
		0.5
	)
	
	# Add a little bounce to the gold icon
	var icon_tween = create_tween()
	icon_tween.tween_property(gold_icon, "scale", Vector2(1.2, 1.2), 0.1)
	icon_tween.tween_property(gold_icon, "scale", Vector2(1.0, 1.0), 0.2)

## Day/Season Display
func _update_day_display(day: int):
	day_label.text = "Day " + str(day)

func _update_season_display(season: String):
	season_label.text = season

## Growth Info Display
func _update_growth_info():
	# Count active crops
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return
	
	var active_count = crop_mgr.active_crops.size()
	var harvestable_count = crop_mgr.get_harvestable_crops().size()
	
	if active_count == 0:
		growth_info_label.text = ""
	elif harvestable_count > 0:
		growth_info_label.text = " | %d ready!" % harvestable_count
	else:
		growth_info_label.text = " | %d growing" % active_count

## Inventory Updates
func _on_inventory_changed(item_id: String, inventory: Dictionary):
	# Could show inventory count or recent items here
	pass

## Crop Notifications
func _on_crop_planted(coord: Vector2i, crop_id: String):
	var crop_name = _get_crop_name(crop_id)
	_show_toast("Planted %s!" % crop_name)

func _on_crop_harvested(coord: Vector2i, crop_id: String):
	var crop_name = _get_crop_name(crop_id)
	_show_toast("Harvested %s!" % crop_name)

func _get_crop_name(crop_id: String) -> String:
	# Try to load crop data
	var crop_data = _load_crop_data(crop_id)
	if crop_data and crop_data.has("name"):
		return crop_data.name
	return crop_id.capitalize()

func _load_crop_data(crop_id: String) -> Dictionary:
	var file_path = "res://data/crops/" + crop_id + ".json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			return json.data
	return {}

## Toast Notifications
func _show_toast(message: String):
	var toast = _create_toast_label(message)
	toast_container.add_child(toast)
	
	# Animate in
	toast.modulate.a = 0
	toast.position.y = 20
	var tween = create_tween()
	tween.tween_property(toast, "modulate:a", 1, 0.2)
	tween.parallel().tween_property(toast, "position:y", 0, 0.2)
	
	# Remove after delay
	await get_tree().create_timer(TOAST_DURATION).timeout
	
	# Animate out
	var out_tween = create_tween()
	out_tween.tween_property(toast, "modulate:a", 0, 0.2)
	await out_tween.finished
	
	toast.queue_free()

func _create_toast_label(message: String) -> Label:
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	return label

## Button Handlers
func _on_inventory_button_pressed():
	_animate_button_press(inventory_button)
	_show_inventory_panel()

func _on_shop_button_pressed():
	_animate_button_press(shop_button)
	_show_shop_panel()

func _on_settings_button_pressed():
	_animate_button_press(settings_button)
	_show_settings_panel()

func _animate_button_press(button: Button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(BUTTON_PRESS_SCALE, BUTTON_PRESS_SCALE), BUTTON_ANIMATION_TIME)
	tween.tween_property(button, "scale", Vector2(1, 1), BUTTON_ANIMATION_TIME)

## Panel Management (emit signals for main scene to handle)
signal inventory_requested
signal shop_requested
signal settings_requested

func _show_inventory_panel():
	inventory_requested.emit()

func _show_shop_panel():
	shop_requested.emit()

func _show_settings_panel():
	settings_requested.emit()
