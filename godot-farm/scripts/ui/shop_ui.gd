extends CanvasLayer

signal shop_closed
signal item_purchased(item_id: String, item_type: String)
signal animal_purchased(animal_id: String)

var gold_label: Label
var animals_grid: GridContainer
var plants_grid: GridContainer
var inventory_grid: GridContainer
var refresh_button: Button
var item_panel: Panel
var item_icon: TextureRect
var item_name: Label
var item_desc: Label
var item_price: Label
var buy_button: Button

var shop_data: Dictionary = {}
var selected_item: Dictionary = {}
var sell_mode: bool = false  # true when viewing inventory to sell

const REFRESH_COST: int = 50

func _ready():
	# Get nodes
	gold_label = get_node_or_null("%GoldLabel")
	animals_grid = get_node_or_null("%AnimalsGrid")
	plants_grid = get_node_or_null("%PlantsGrid")
	inventory_grid = get_node_or_null("%InventoryGrid")
	refresh_button = get_node_or_null("%RefreshButton")
	item_panel = get_node_or_null("MainContainer/ItemPanel")
	
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	
	var close_button = get_node_or_null("MainContainer/BottomBar/CloseButton")
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Item panel children
	if item_panel:
		var item_vbox = item_panel.get_node_or_null("ItemVBox")
		if item_vbox:
			item_icon = item_vbox.get_node_or_null("ItemIcon")
			item_name = item_vbox.get_node_or_null("ItemName")
			item_desc = item_vbox.get_node_or_null("ItemDesc")
			item_price = item_vbox.get_node_or_null("ItemPrice")
			buy_button = item_vbox.get_node_or_null("BuyButton")
			if buy_button:
				buy_button.pressed.connect(_on_buy_pressed)
		item_panel.visible = false
	
	_load_shop_data()
	_populate_shop()
	_update_gold_display()

func _load_shop_data():
	var file_path = "res://data/shop_items.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			shop_data = json.data

func _populate_shop():
	if not animals_grid or not plants_grid or not inventory_grid:
		return
	
	# Clear
	for child in animals_grid.get_children():
		child.queue_free()
	for child in plants_grid.get_children():
		child.queue_free()
	for child in inventory_grid.get_children():
		child.queue_free()
	
	# Create animal cards
	for animal in shop_data.get("animals", []):
		_create_card(animals_grid, animal, "animal")
	
	# Create plant cards
	for plant in shop_data.get("plants", []):
		_create_card(plants_grid, plant, "plant")
	
	# Populate inventory
	_populate_inventory()

func _populate_inventory():
	var state = get_node_or_null("/root/StateManager")
	if not state:
		return
	
	var inventory = state.get_inventory()
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return
	
	for item_id in inventory.keys():
		var count = inventory[item_id]
		if count <= 0:
			continue
		
		# Get crop data for sell price
		var crop_data = crop_mgr.crop_database.get(item_id, {})
		var sell_price = crop_data.get("sell_price", 10)
		var display_name = crop_data.get("name", item_id)
		
		var item = {
			"id": item_id,
			"name": display_name,
			"count": count,
			"sell_price": sell_price
		}
		_create_inventory_card(item)

func _create_inventory_card(item: Dictionary):
	var card = Button.new()
	card.custom_minimum_size = Vector2(140, 180)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.95, 0.9)
	style.border_color = Color(0.4, 0.7, 0.4)
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.95, 1, 0.95)
	hover_style.border_width_bottom = 5
	card.add_theme_stylebox_override("hover", hover_style)
	
	# Container
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)
	
	# Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(80, 80)
	
	var icon_path = "res://assets/crops/%s/%s_mature.png" % [item.id, item.id]
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	
	vbox.add_child(icon)
	
	# Name
	var name_label = Label.new()
	name_label.text = item.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Count
	var count_label = Label.new()
	count_label.text = "拥有: %d" % item.count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count_label)
	
	# Sell price
	var price_label = Label.new()
	price_label.text = "出售 💰 %d" % item.sell_price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
	vbox.add_child(price_label)
	
	# Buttons container
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)
	
	# Place button (for animals)
	if item.id in ["cow", "pig", "sheep", "zebra", "shiba", "koala", "cat", "capybara", "alpaca"]:
		var place_btn = Button.new()
		place_btn.text = "放置"
		place_btn.custom_minimum_size = Vector2(60, 30)
		var place_style = StyleBoxFlat.new()
		place_style.bg_color = Color(0.3, 0.6, 0.9)
		place_style.corner_radius_top_left = 5
		place_style.corner_radius_top_right = 5
		place_style.corner_radius_bottom_left = 5
		place_style.corner_radius_bottom_right = 5
		place_btn.add_theme_stylebox_override("normal", place_style)
		place_btn.pressed.connect(_place_animal.bind(item))
		btn_hbox.add_child(place_btn)
	
	# Sell button
	var sell_btn = Button.new()
	sell_btn.text = "出售"
	sell_btn.custom_minimum_size = Vector2(60, 30)
	var sell_style = StyleBoxFlat.new()
	sell_style.bg_color = Color(0.3, 0.7, 0.3)
	sell_style.corner_radius_top_left = 5
	sell_style.corner_radius_top_right = 5
	sell_style.corner_radius_bottom_left = 5
	sell_style.corner_radius_bottom_right = 5
	sell_btn.add_theme_stylebox_override("normal", sell_style)
	sell_btn.pressed.connect(_sell_item_direct.bind(item))
	btn_hbox.add_child(sell_btn)
	
	# Click card for details
	card.pressed.connect(_on_inventory_card_clicked.bind(item))
	
	inventory_grid.add_child(card)

func _place_animal(item: Dictionary):
	"""Place animal from inventory onto the farm map"""
	var state = get_node_or_null("/root/StateManager")
	if not state:
		return
	
	# Check if we have the animal
	var inventory = state.get_inventory()
	if inventory.get(item.id, 0) <= 0:
		print("[ShopUI] No %s to place" % item.id)
		return
	
	# Remove from inventory
	var success = state.apply_action({"type": "remove_item", "item_id": item.id, "amount": 1})
	if not success:
		return
	
	# Spawn animal on farm
	var farm = get_node_or_null("/root/Main/Farm")
	if farm and farm.has_method("spawn_animal"):
		farm.spawn_animal(item.id)
		print("[ShopUI] Placed %s on farm" % item.id)
		_populate_inventory()  # Refresh display
	else:
		print("[ShopUI] ERROR: Cannot spawn animal, farm not found")

func _on_inventory_card_clicked(item: Dictionary):
	selected_item = item.duplicate()
	sell_mode = true
	
	if item_name:
		item_name.text = item.name
	if item_desc:
		item_desc.text = "拥有数量: %d" % item.count
	if item_price:
		item_price.text = "出售价格: 💰 %d/个" % item.sell_price
	
	var icon_path = "res://assets/crops/%s/%s_mature.png" % [item.id, item.id]
	if item_icon:
		if ResourceLoader.exists(icon_path):
			item_icon.texture = load(icon_path)
		else:
			item_icon.texture = null
	
	if buy_button:
		buy_button.disabled = false
		buy_button.text = "出售"
	
	if item_panel:
		item_panel.visible = true

func _create_card(parent: GridContainer, item: Dictionary, item_type: String):
	var card = Button.new()
	card.custom_minimum_size = Vector2(140, 180)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Style
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
	
	# Container
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)
	
	# Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(80, 80)
	
	var icon_path = _get_icon_path(item.id, item_type)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	
	vbox.add_child(icon)
	
	# Name
	var name_label = Label.new()
	name_label.text = item.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Price
	var price_label = Label.new()
	price_label.text = "💰 %d" % item.price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(price_label)
	
	# Click
	card.pressed.connect(_on_card_clicked.bind(item, item_type))
	
	parent.add_child(card)

func _get_icon_path(id: String, item_type: String) -> String:
	if item_type == "animal":
		var paths = [
			"res://assets/characters/%s/idle/%s_idle_01.png" % [id, id],  # capybara_idle_01.png
			"res://assets/characters/%s/idle/%s_idle_0.png" % [id, id],   # cow_idle_0.png
			"res://assets/characters/%s/idle/%s_idle_1.png" % [id, id],   # cow_idle_1.png
			"res://assets/characters/%s/idle/idle_0.png" % [id],          # pig/idle_0.png (no prefix)
			"res://assets/characters/%s/idle/idle_1.png" % [id],          # pig/idle_1.png (no prefix)
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
	if not item_name or not buy_button:
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
	
	if sell_mode:
		# Sell the crop
		_sell_crop(selected_item.id, 1)
	else:
		# Buy from shop
		var price = selected_item.price
		var state = get_node_or_null("/root/StateManager")
		
		if not state:
			return
		
		var gold = state.get_gold()
		if gold < price:
			return
		
		# Deduct gold via StateManager
		var success = state.apply_action({"type": "remove_gold", "amount": price})
		if not success:
			print("[ShopUI] Failed to deduct gold")
			return
		
		print("[ShopUI] Bought %s for %d gold" % [selected_item.id, price])
		item_purchased.emit(selected_item.id, selected_item.type)
		
		if selected_item.type == "animal":
			animal_purchased.emit(selected_item.id)
			# Add animal to inventory
			state.apply_action({"type": "add_item", "item_id": selected_item.id, "amount": 1})
			# Add experience for purchasing animal
			state.apply_action({"type": "add_experience", "amount": 25})
			print("[ShopUI] Added animal to inventory: %s" % selected_item.id)
		elif selected_item.type == "plant":
			_give_seed(selected_item.id)
	
	_update_gold_display()
	_populate_shop()  # Refresh inventory display
	item_panel.visible = false
	
	# Reset sell mode
	sell_mode = false

func _sell_crop(crop_id: String, amount: int):
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return
	
	var gold_earned = crop_mgr.sell_crop(crop_id, amount)
	if gold_earned > 0:
		print("[ShopUI] Sold %s for %d gold" % [crop_id, gold_earned])

func _spawn_animal(animal_id: String):
	var farm = get_node_or_null("/root/Main/Farm")
	if farm and farm.has_method("spawn_animal"):
		farm.spawn_animal(animal_id)

func _give_seed(plant_id: String):
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.apply_action({"type": "add_item", "item_id": plant_id + "_seed", "amount": 1})
		# Add experience for purchasing seeds
		var xp_amount = 10  # XP for buying seeds
		state.apply_action({"type": "add_experience", "amount": xp_amount})
		print("[ShopUI] Added seed to inventory: %s, gained %d XP" % [plant_id, xp_amount])

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
	if gold_label:
		gold_label.text = "💰 %d" % gold

func _get_current_gold() -> int:
	var state = get_node_or_null("/root/StateManager")
	if state:
		return state.get_gold()
	return 0

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
