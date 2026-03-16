class_name InventoryController
extends CanvasLayer

## Inventory Controller - Manages inventory UI display and interactions
## Connects to ActionSystem signals for inventory updates

# UI References - updated paths for CanvasLayer structure
@onready var main_container: Panel = $Control
@onready var item_grid: GridContainer = %ItemGrid
@onready var item_detail_panel: Panel = %ItemDetailPanel
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_count_label: Label = %ItemCountLabel
@onready var item_description_label: Label = %ItemDescriptionLabel
@onready var sell_button: Button = %SellButton
@onready var use_button: Button = %UseButton
@onready var close_button: Button = %CloseButton
@onready var empty_label: Label = %EmptyLabel

# Settings
const SLOT_SIZE := 80
const GRID_COLUMNS := 5

# State
var _inventory: Dictionary = {}
var _selected_item_id: String = ""
var _crop_data_cache: Dictionary = {}
var _slot_nodes: Array = []

signal panel_closed

func _ready():
	print("[InventoryController] Initializing...")
	
	# Connect to ActionSystem signals
	var action_sys = get_node_or_null("/root/ActionSystem")
	if action_sys:
		action_sys.inventory_changed.connect(_on_inventory_changed)
	
	# Button connections
	sell_button.pressed.connect(_on_sell_button_pressed)
	use_button.pressed.connect(_on_use_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Setup grid
	item_grid.columns = GRID_COLUMNS
	
	# Initial load
	_refresh_inventory()
	
	# Hide detail panel initially
	item_detail_panel.visible = false
	
	print("[InventoryController] Initialized")

## Signal Handlers
func _on_inventory_changed(item_id: String, inventory: Dictionary):
	_inventory = inventory
	_refresh_inventory()
	
	# Update detail view if currently selected item changed
	if item_id == _selected_item_id:
		_update_detail_view()

## UI Refresh
func _refresh_inventory():
	# Clear existing slots
	for slot in _slot_nodes:
		slot.queue_free()
	_slot_nodes.clear()
	
	# Show empty message if needed
	if _inventory.is_empty():
		empty_label.visible = true
		item_grid.visible = false
		return
	
	empty_label.visible = false
	item_grid.visible = true
	
	# Create slots for each item
	for item_id in _inventory.keys():
		var count = _inventory[item_id]
		var slot = _create_item_slot(item_id, count)
		item_grid.add_child(slot)
		_slot_nodes.append(slot)

func _create_item_slot(item_id: String, count: int) -> Button:
	var slot = Button.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.toggle_mode = true
	slot.name = "Slot_" + item_id
	
	# Load crop data for display
	var crop_data = _get_crop_data(item_id)
	
	# Create slot content
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_child(container)
	
	# Icon
	var icon = _create_item_icon(crop_data)
	container.add_child(icon)
	
	# Count label
	var count_label = Label.new()
	count_label.text = "x" + str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 14)
	container.add_child(count_label)
	
	# Connect selection
	slot.pressed.connect(_on_slot_selected.bind(item_id))
	
	return slot

func _create_item_icon(crop_data: Dictionary) -> TextureRect:
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = 1
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load the mature stage sprite as inventory icon
	var crop_id = crop_data.get("id", "")
	var texture_path = "res://assets/crops/%s/%s_mature.png" % [crop_id, crop_id]
	
	if ResourceLoader.exists(texture_path):
		icon.texture = load(texture_path)
	else:
		# Fallback: colored placeholder
		var color = _get_crop_color(crop_id)
		var image = Image.create(40, 40, false, Image.FORMAT_RGBA8)
		image.fill(color)
		for x in range(40):
			image.set_pixel(x, 0, Color.WHITE)
			image.set_pixel(x, 39, Color.WHITE)
		for y in range(40):
			image.set_pixel(0, y, Color.WHITE)
			image.set_pixel(39, y, Color.WHITE)
		icon.texture = ImageTexture.create_from_image(image)
	
	return icon

func _get_crop_color(crop_id: String) -> Color:
	match crop_id:
		"carrot": return Color(0.9, 0.5, 0.1)
		"tomato": return Color(0.9, 0.2, 0.1)
		"corn": return Color(0.9, 0.8, 0.1)
		"strawberry": return Color(0.9, 0.1, 0.2)
		"wheat": return Color(0.9, 0.7, 0.3)
		_: return Color(0.5, 0.8, 0.3)

func _get_crop_data(crop_id: String) -> Dictionary:
	if _crop_data_cache.has(crop_id):
		return _crop_data_cache[crop_id]
	
	var file_path = "res://data/crops/" + crop_id + ".json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			_crop_data_cache[crop_id] = json.data
			return json.data
	
	return {"id": crop_id, "name": crop_id.capitalize()}

## Slot Selection
func _on_slot_selected(item_id: String):
	_selected_item_id = item_id
	
	# Update slot visuals
	for slot in _slot_nodes:
		slot.button_pressed = slot.name == "Slot_" + item_id
	
	# Show and update detail panel
	_update_detail_view()
	item_detail_panel.visible = true

func _update_detail_view():
	if _selected_item_id.is_empty() or not _inventory.has(_selected_item_id):
		item_detail_panel.visible = false
		return
	
	var crop_data = _get_crop_data(_selected_item_id)
	var count = _inventory[_selected_item_id]
	
	item_name_label.text = crop_data.get("name", _selected_item_id.capitalize())
	item_count_label.text = "Count" + ": " + str(count)
	item_description_label.text = _get_crop_description(crop_data)
	
	# Update button states
	var can_sell = count > 0
	sell_button.disabled = not can_sell
	use_button.disabled = not can_sell

func _get_crop_description(crop_data: Dictionary) -> String:
	var desc = ""
	
	if crop_data.has("sell_price"):
		desc += "Sell Price" + ": " + str(crop_data.sell_price) + "g\n"
	
	if crop_data.has("growth_time"):
		desc += "Growth Time" + ": " + str(crop_data.growth_time) + "s\n"
	
	if crop_data.has("seasons"):
		desc += "Seasons" + ": " + ", ".join(crop_data.seasons)
	
	return desc

## Button Handlers
func _on_sell_button_pressed():
	if _selected_item_id.is_empty():
		return
	
	var crop_data = _get_crop_data(_selected_item_id)
	var price = crop_data.get("sell_price", 10)
	
	ActionSystem.sell_item(_selected_item_id, 1, price)
	
	# Animation feedback
	_animate_button_press(sell_button)

func _on_use_button_pressed():
	# Use item (for seeds, this would select for planting)
	if _selected_item_id.is_empty():
		return
	
	_animate_button_press(use_button)
	
	# TODO: Emit signal to select this crop for planting
	print("[InventoryController] Use item: " + _selected_item_id)

func _on_close_button_pressed():
	_animate_button_press(close_button)
	_hide_panel()

func _animate_button_press(button: Button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(button, "scale", Vector2(1, 1), 0.1)

## Public Methods
func show_panel():
	visible = true
	main_container.modulate.a = 0
	main_container.scale = Vector2(0.95, 0.95)
	
	# Refresh inventory
	_inventory = StateManager.get_inventory()
	_refresh_inventory()
	
	# Animate in
	var tween = create_tween()
	tween.tween_property(main_container, "modulate:a", 1, 0.2)
	tween.parallel().tween_property(main_container, "scale", Vector2(1, 1), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func hide_panel():
	_hide_panel()

func _hide_panel():
	# Animate out
	var tween = create_tween()
	tween.tween_property(main_container, "modulate:a", 0, 0.15)
	tween.parallel().tween_property(main_container, "scale", Vector2(0.95, 0.95), 0.15)
	await tween.finished
	
	visible = false
	panel_closed.emit()
