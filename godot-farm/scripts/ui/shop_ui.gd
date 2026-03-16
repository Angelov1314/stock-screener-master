extends CanvasLayer

## Shop UI - Animal and Plant Shop with Card Design

signal shop_closed
signal item_purchased(item_id: String, item_type: String)
signal animal_purchased(animal_id: String)

# UI References - all initialized manually in _ready
var gold_label: Label
var animals_grid: GridContainer
var plants_grid: GridContainer
var refresh_button: Button
var item_panel: Panel
var item_icon: TextureRect
var item_name: Label
var item_desc: Label
var item_price: Label
var buy_button: Button

# Shop Data
var shop_data: Dictionary = {}
var selected_item: Dictionary = {}

const REFRESH_COST: int = 50

func _ready():
	# Manually get all nodes
	gold_label = get_node_or_null("%GoldLabel")
	animals_grid = get_node_or_null("%AnimalsGrid")
	plants_grid = get_node_or_null("%PlantsGrid")
	refresh_button = get_node_or_null("%RefreshButton")
	item_panel = get_node_or_null("MainContainer/ItemPanel")
	
	print("[ShopUI] Nodes: gold=%s, animals=%s, plants=%s, refresh=%s, panel=%s" % [
		gold_label != null, animals_grid != null, plants_grid != null, 
		refresh_button != null, item_panel != null])
	
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	
	var close_button = get_node_or_null("MainContainer/BottomBar/CloseButton")
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Initialize item panel children
	if item_panel:
		var item_vbox = item_panel.get_node_or_null("ItemVBox")
		if item_vbox:
			item_icon = item_vbox.get_node_or_null("ItemIcon")
			item_name = item_vbox.get_node_or_null("ItemName")
			item_desc = item_vbox.get_node_or_null("ItemDesc")
			item_price = item_vbox.get_node_or_null("ItemPrice")
			buy_button = item_vbox.get_node_or_null("BuyButton")
			
			print("[ShopUI] Item panel children: icon=%s, name=%s, desc=%s, price=%s, buy=%s" % [
				item_icon != null, item_name != null, item_desc != null,
				item_price != null, buy_button != null])
			
			if buy_button:
				buy_button.pressed.connect(_on_buy_pressed)
		else:
			print("[ShopUI] ERROR: ItemVBox not found")
	else:
		print("[ShopUI] ERROR: ItemPanel not found")
	
	_load_shop_data()
	_populate_shop()
	_update_gold_display()
	
	if item_panel:
		item_panel.visible = false
	
	# Ensure first tab (animals) is active
	var tab_container = get_node_or_null("MainContainer/TabContainer")
	if tab_container:
		print("[ShopUI] TabContainer current_tab: %d" % tab_container.current_tab)
		print("[ShopUI] TabContainer tab count: %d" % tab_container.get_tab_count())

func _load_shop_data():
	var file_path = "res://data/shop_items.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			shop_data = json.data
			print("[ShopUI] Loaded: %d animals, %d plants" % [
				shop_data.get("animals", []).size(),
				shop_data.get("plants", []).size()
			])

func _populate_shop():
	print("[ShopUI] Populating shop...")
	
	# Ensure grids have proper sizing and visibility
	animals_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	animals_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	animals_grid.z_index = 10
	animals_grid.visible = true
	
	plants_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plants_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plants_grid.z_index = 10
	plants_grid.visible = true
	
	# DEBUG: Make cards very visible
	print("[ShopUI] DEBUG: Setting bright red background on next card")
	
	print("[ShopUI] animals_grid visible: %s, z_index: %d, size: %s" % [animals_grid.visible, animals_grid.z_index, str(animals_grid.size)])
	print("[ShopUI] plants_grid visible: %s, z_index: %d, size: %s" % [plants_grid.visible, plants_grid.z_index, str(plants_grid.size)])
	
	# Check parent ScrollContainer sizes
	var animals_scroll = animals_grid.get_parent()
	var plants_scroll = plants_grid.get_parent()
	if animals_scroll:
		print("[ShopUI] Animals ScrollContainer size: %s" % str(animals_scroll.size))
	if plants_scroll:
		print("[ShopUI] Plants ScrollContainer size: %s" % str(plants_scroll.size))
	
	# Clear
	for child in animals_grid.get_children():
		child.queue_free()
	for child in plants_grid.get_children():
		child.queue_free()
	
	var animals = shop_data.get("animals", [])
	var plants = shop_data.get("plants", [])
	print("[ShopUI] Creating %d animal cards" % animals.size())
	print("[ShopUI] Creating %d plant cards" % plants.size())
	
	# All animals
	for animal in animals:
		print("[ShopUI] Creating card for: %s" % animal.get("name", "unknown"))
		_create_card(animals_grid, animal, "animal")
	
	# All plants
	for plant in plants:
		_create_card(plants_grid, plant, "plant")
	
	print("[ShopUI] animals_grid children: %d" % animals_grid.get_child_count())
	print("[ShopUI] plants_grid children: %d" % plants_grid.get_child_count())
	
	# Delayed position check after layout
	await get_tree().create_timer(0.5).timeout
	for i in range(animals_grid.get_child_count()):
		var child = animals_grid.get_child(i)
		print("[ShopUI] Animal card %d: pos=%s, global_pos=%s, size=%s, visible=%s" % [i, str(child.position), str(child.global_position), str(child.size), child.visible])

func _create_card(parent: GridContainer, item: Dictionary, item_type: String):
	print("[ShopUI] _create_card: %s, parent=%s, parent_child_count=%d" % [item.get("name", "unknown"), parent.name, parent.get_child_count()])
	
	var card = Button.new()
	card.custom_minimum_size = Vector2(140, 180)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.z_index = 100
	card.visible = true
	
	# DEBUG: First card gets bright red background
	if parent.get_child_count() == 0:
		print("[ShopUI] DEBUG: Creating RED card for visibility test")
		var debug_style = StyleBoxFlat.new()
		debug_style.bg_color = Color(1, 0, 0)
		card.add_theme_stylebox_override("normal", debug_style)
	
	# Card style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.9)
	style.border_color = Color(0.7, 0.6, 0.4)
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(1, 1, 0.95)
	hover_style.border_width_bottom = 5
	card.add_theme_stylebox_override("hover", hover_style)
	
	# Container - fill the entire card
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(vbox)
	
	# Icon background
	var icon_bg = ColorRect.new()
	icon_bg.custom_minimum_size = Vector2(80, 80)
	icon_bg.color = Color(0.9, 0.9, 0.85)
	vbox.add_child(icon_bg)
	
	# Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(70, 70)
	
	var icon_path = _get_icon_path(item.id, item_type)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	
	icon_bg.add_child(icon)
	icon.position = Vector2(5, 5)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)
	
	# Name
	var name_label = Label.new()
	name_label.text = item.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	vbox.add_child(name_label)
	
	# Price tag
	var price_container = Panel.new()
	price_container.custom_minimum_size = Vector2(80, 24)
	
	var price_style = StyleBoxFlat.new()
	price_style.bg_color = Color(1, 0.85, 0.3)
	price_style.corner_radius_top_left = 12
	price_style.corner_radius_top_right = 12
	price_style.corner_radius_bottom_left = 12
	price_style.corner_radius_bottom_right = 12
	price_container.add_theme_stylebox_override("panel", price_style)
	vbox.add_child(price_container)
	
	var price_label = Label.new()
	price_label.text = "💰 %d" % item.price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 12)
	price_label.add_theme_color_override("font_color", Color(0.4, 0.25, 0))
	price_container.add_child(price_label)
	price_label.size = Vector2(80, 24)
	
	# Click
	card.pressed.connect(_on_card_clicked.bind(item, item_type))
	
	parent.add_child(card)
	print("[ShopUI] Card added to %s" % parent.name)

func _get_icon_path(id: String, item_type: String) -> String:
	if item_type == "animal":
		# Try multiple naming conventions
		var paths = [
			"res://assets/characters/%s/idle/%s_idle_01.png" % [id, id],
			"res://assets/characters/%s/idle/%s_idle_0.png" % [id, id],
			"res://assets/characters/%s/idle/%s_idle_1.png" % [id, id],
		]
		for path in paths:
			if ResourceLoader.exists(path):
				return path
	else:
		var path = "res://assets/crops/%s/%s_seed.png" % [id, id]
		if ResourceLoader.exists(path):
			return path
	return ""

func _on_card_clicked(item: Dictionary, item_type: String):
	if not item_name or not item_desc or not item_price or not item_icon or not buy_button:
		print("[ShopUI] ERROR: Item panel children not initialized")
		return
	
	selected_item = item.duplicate()
	selected_item["type"] = item_type
	
	item_name.text = item.name
	item_desc.text = item.description
	item_price.text = "💰 %d" % item.price
	
	var icon_path = _get_icon_path(item.id, item_type)
	if ResourceLoader.exists(icon_path):
		item_icon.texture = load(icon_path)
	else:
		item_icon.texture = null
	
	var gold = _get_current_gold()
	buy_button.disabled = gold < item.price
	buy_button.text = "金币不足" if buy_button.disabled else "购买"
	
	item_panel.visible = true

func _on_buy_pressed():
	if selected_item.is_empty():
		return
	
	var price = selected_item.price
	var gold = _get_current_gold()
	
	if gold < price:
		return
	
	var eco_mgr = get_node_or_null("/root/EconomyManager")
	if eco_mgr:
		eco_mgr.remove_gold(price, "shop_purchase")
	
	item_purchased.emit(selected_item.id, selected_item.type)
	
	if selected_item.type == "animal":
		animal_purchased.emit(selected_item.id)
		_spawn_animal(selected_item.id)
	elif selected_item.type == "plant":
		_give_seed(selected_item.id)
	
	_update_gold_display()
	item_panel.visible = false

func _spawn_animal(animal_id: String):
	# Spawn animal in farm
	var farm = get_node_or_null("/root/Main/Farm")
	if farm and farm.has_method("spawn_animal"):
		farm.spawn_animal(animal_id)
		print("[Shop] Spawned animal: %s" % animal_id)

func _give_seed(plant_id: String):
	# Add seed to inventory
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.add_item_to_inventory(plant_id + "_seed", 1)
		print("[Shop] Gave seed: %s" % plant_id)

func _on_refresh_pressed():
	var gold = _get_current_gold()
	if gold < REFRESH_COST:
		return
	
	var eco_mgr = get_node_or_null("/root/EconomyManager")
	if eco_mgr:
		eco_mgr.remove_gold(REFRESH_COST, "shop_refresh")
	
	_populate_shop()
	_update_gold_display()

func _on_close_pressed():
	shop_closed.emit()
	queue_free()

func _update_gold_display():
	var gold = _get_current_gold()
	gold_label.text = "💰 %d" % gold

func _get_current_gold() -> int:
	var state = get_node_or_null("/root/StateManager")
	if state:
		return state.get_gold()
	return 0

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
