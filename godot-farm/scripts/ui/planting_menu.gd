class_name PlantingMenu
extends Control

## Planting menu - single button that opens crop selection

signal crop_selected(crop_id: String)
signal menu_opened
signal menu_closed

@export var button_texture: Texture2D

var _main_button: TextureButton
var _menu_panel: PanelContainer
var _crop_grid: GridContainer
var _is_open: bool = false

# Crop button data
var _crop_buttons: Array[TextureButton] = []

func _ready():
	_setup_main_button()
	_setup_menu_panel()
	visible = true

func _setup_main_button():
	_main_button = TextureButton.new()
	_main_button.name = "PlantingMainButton"
	_main_button.custom_minimum_size = Vector2(80, 80)
	_main_button.ignore_texture_size = true
	_main_button.stretch_mode = TextureButton.STRETCH_SCALE
	
	# Use seed bag texture
	if not button_texture:
		button_texture = load("res://assets/ui/button_seed.png")
	_main_button.texture_normal = button_texture
	
	_main_button.pressed.connect(_toggle_menu)
	add_child(_main_button)

func _setup_menu_panel():
	_menu_panel = PanelContainer.new()
	_menu_panel.name = "PlantingMenuPanel"
	_menu_panel.visible = false
	_menu_panel.custom_minimum_size = Vector2(320, 250)
	
	# Position will be set when opening menu
	_menu_panel.position = Vector2.ZERO
	
	# Make it a popup that shows above everything
	_menu_panel.z_index = 100
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_menu_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "选择种子"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	# Crop grid
	_crop_grid = GridContainer.new()
	_crop_grid.columns = 4
	_crop_grid.add_theme_constant_override("h_separation", 10)
	_crop_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_crop_grid)
	
	# Load available crops
	_load_crops()
	
	add_child(_menu_panel)

func _load_crops():
	# Clear existing
	for btn in _crop_buttons:
		btn.queue_free()
	_crop_buttons.clear()
	
	# Load crop data from files
	var crop_files = ["carrot", "potato", "tomato", "corn", "pumpkin", "strawberry"]
	
	for crop_id in crop_files:
		var crop_data = _load_crop_data(crop_id)
		if crop_data:
			_create_crop_button(crop_id, crop_data)

func _load_crop_data(crop_id: String) -> Dictionary:
	var file_path = "res://data/crops/%s.json" % crop_id
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			return json.data
	
	# Return default data if file doesn't exist
	return {
		"id": crop_id,
		"name": crop_id.capitalize(),
		"icon": "res://assets/crops/%s/icon.png" % crop_id
	}

func _create_crop_button(crop_id: String, crop_data: Dictionary):
	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(60, 60)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	
	# Try to load crop icon
	var icon_path = crop_data.get("icon", "res://assets/crops/%s/icon.png" % crop_id)
	if FileAccess.file_exists(icon_path):
		btn.texture_normal = load(icon_path)
	else:
		# Use placeholder
		btn.texture_normal = load("res://assets/ui/button_seed.png")
	
	btn.tooltip_text = crop_data.get("name", crop_id.capitalize())
	btn.pressed.connect(_on_crop_button_pressed.bind(crop_id))
	
	_crop_grid.add_child(btn)
	_crop_buttons.append(btn)

func _on_crop_button_pressed(crop_id: String):
	crop_selected.emit(crop_id)
	_close_menu()
	print("[PlantingMenu] Selected crop: %s" % crop_id)

func _toggle_menu():
	if _is_open:
		_close_menu()
	else:
		_open_menu()

func _open_menu():
	_is_open = true
	
	# Get button global position and convert to local coordinates
	var button_global_pos = _main_button.global_position
	var button_size = _main_button.size
	var menu_size = _menu_panel.custom_minimum_size
	
	# Calculate position: center horizontally above button
	var menu_x = button_global_pos.x + (button_size.x - menu_size.x) / 2
	var menu_y = button_global_pos.y - menu_size.y - 10  # 10px gap above button
	
	# Clamp to screen bounds
	var screen_size = get_viewport().get_visible_rect().size
	menu_x = clamp(menu_x, 10, screen_size.x - menu_size.x - 10)
	menu_y = clamp(menu_y, 10, screen_size.y - menu_size.y - 10)
	
	# Set global position directly (Control nodes use global_position)
	_menu_panel.global_position = Vector2(menu_x, menu_y)
	
	_menu_panel.visible = true
	_menu_panel.modulate.a = 0
	_menu_panel.scale = Vector2(0.8, 0.8)
	_menu_panel.z_index = 100  # Ensure it's on top
	
	var tween = create_tween()
	tween.tween_property(_menu_panel, "modulate:a", 1, 0.15)
	tween.parallel().tween_property(_menu_panel, "scale", Vector2(1, 1), 0.15)
	
	menu_opened.emit()

func _close_menu():
	_is_open = false
	
	var tween = create_tween()
	tween.tween_property(_menu_panel, "modulate:a", 0, 0.1)
	tween.parallel().tween_property(_menu_panel, "scale", Vector2(0.8, 0.8), 0.1)
	
	await tween.finished
	_menu_panel.visible = false
	
	menu_closed.emit()

func _input(event):
	if not _is_open:
		return
	
	# Close menu when clicking outside
	if event is InputEventMouseButton:
		if event.pressed:
			var local_pos = _menu_panel.get_local_mouse_position()
			var menu_rect = Rect2(Vector2.ZERO, _menu_panel.size)
			if not menu_rect.has_point(local_pos):
				# Also check if not clicking main button
				var btn_rect = Rect2(Vector2.ZERO, _main_button.size)
				var btn_local = _main_button.get_local_mouse_position()
				if not btn_rect.has_point(btn_local):
					_close_menu()

func is_open() -> bool:
	return _is_open
