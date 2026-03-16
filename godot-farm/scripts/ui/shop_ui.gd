extends CanvasLayer

## Shop UI - Animal and Plant Shop with Refresh Feature

signal shop_closed
signal item_purchased(item_id: String, item_type: String)
signal animal_purchased(animal_id: String)

# UI References
@onready var gold_label: Label = %GoldLabel
@onready var animals_grid: GridContainer = %AnimalsGrid
@onready var plants_grid: GridContainer = %PlantsGrid
@onready var refresh_button: Button = %RefreshButton
@onready var item_panel: Panel = $ItemPanel
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName
@onready var item_desc: Label = %ItemDesc
@onready var item_price: Label = %ItemPrice
@onready var buy_button: Button = %BuyButton

# Shop Data
var shop_data: Dictionary = {}
var current_animals: Array = []
var current_plants: Array = []
var selected_item: Dictionary = {}

# Refresh Cost
const REFRESH_COST: int = 50

func _ready():
	# Connect buttons
	refresh_button.pressed.connect(_on_refresh_pressed)
	$MainContainer/BottomBar/CloseButton.pressed.connect(_on_close_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	
	# Load shop data
	_load_shop_data()
	
	# Initial refresh
	refresh_shop()
	
	# Update gold display
	_update_gold_display()
	
	# Hide item panel
	item_panel.visible = false

func _load_shop_data():
	var file_path = "res://data/shop_items.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			shop_data = json.data
			print("[ShopUI] Loaded shop data: %d animals, %d plants" % [
				shop_data.get("animals", []).size(),
				shop_data.get("plants", []).size()
			])
		else:
			push_error("[ShopUI] Failed to parse shop data")
	else:
		push_error("[ShopUI] Shop data file not found")

func refresh_shop():
	print("[ShopUI] Refreshing shop...")
	
	# Clear existing items
	for child in animals_grid.get_children():
		child.queue_free()
	for child in plants_grid.get_children():
		child.queue_free()
	
	# Randomly select 3-4 animals
	var all_animals = shop_data.get("animals", [])
	current_animals = _get_random_items(all_animals, 4)
	
	# Randomly select 3-4 plants
	var all_plants = shop_data.get("plants", [])
	current_plants = _get_random_items(all_plants, 4)
	
	# Create animal items
	for animal in current_animals:
		_create_shop_item(animals_grid, animal, "animal")
	
	# Create plant items
	for plant in current_plants:
		_create_shop_item(plants_grid, plant, "plant")
	
	print("[ShopUI] Shop refreshed with %d animals, %d plants" % [current_animals.size(), current_plants.size()])

func _get_random_items(source_array: Array, count: int) -> Array:
	if source_array.size() <= count:
		return source_array.duplicate()
	
	var shuffled = source_array.duplicate()
	shuffled.shuffle()
	return shuffled.slice(0, count)

func _create_shop_item(parent: GridContainer, item_data: Dictionary, item_type: String):
	var button = Button.new()
	button.custom_minimum_size = Vector2(120, 150)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Create container for icon and text
	var vbox = VBoxContainer.new()
	button.add_child(vbox)
	
	# Icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
	vbox.add_child(icon)
	
	# Try to load icon
	var icon_path = "res://assets/characters/%s/idle/%s_idle_0.png" % [item_data.id, item_data.id]
	if item_type == "plant":
		icon_path = "res://assets/crops/%s/%s_seed.png" % [item_data.id, item_data.id]
	
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	
	# Name
	var name_label = Label.new()
	name_label.text = item_data.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Price
	var price_label = Label.new()
	price_label.text = "%d💰" % item_data.price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(price_label)
	
	# Connect click
	button.pressed.connect(_on_item_selected.bind(item_data, item_type))
	
	parent.add_child(button)

func _on_item_selected(item_data: Dictionary, item_type: String):
	selected_item = item_data
	selected_item["type"] = item_type
	
	# Update item panel
	item_name.text = item_data.name
	item_desc.text = item_data.description
	item_price.text = "价格: %d金" % item_data.price
	
	# Update icon
	var icon_path = "res://assets/characters/%s/idle/%s_idle_0.png" % [item_data.id, item_data.id]
	if item_type == "plant":
		icon_path = "res://assets/crops/%s/%s_seed.png" % [item_data.id, item_data.id]
	
	if ResourceLoader.exists(icon_path):
		item_icon.texture = load(icon_path)
	else:
		item_icon.texture = null
	
	# Check if affordable
	var current_gold = _get_current_gold()
	buy_button.disabled = current_gold < item_data.price
	if buy_button.disabled:
		buy_button.text = "金币不足"
	else:
		buy_button.text = "购买"
	
	item_panel.visible = true

func _on_buy_pressed():
	if selected_item.is_empty():
		return
	
	var price = selected_item.price
	var current_gold = _get_current_gold()
	
	if current_gold < price:
		print("[ShopUI] Not enough gold!")
		return
	
	# Deduct gold
	var eco_mgr = get_node_or_null("/root/EconomyManager")
	if eco_mgr:
		eco_mgr.remove_gold(price, "shop_purchase")
	
	# Emit signal
	item_purchased.emit(selected_item.id, selected_item.type)
	
	# If animal, emit special signal
	if selected_item.type == "animal":
		animal_purchased.emit(selected_item.id)
		print("[ShopUI] Animal purchased: %s" % selected_item.id)
	
	# Update UI
	_update_gold_display()
	item_panel.visible = false
	
	print("[ShopUI] Purchased %s: %s" % [selected_item.type, selected_item.id])

func _on_refresh_pressed():
	var current_gold = _get_current_gold()
	
	if current_gold < REFRESH_COST:
		print("[ShopUI] Not enough gold to refresh!")
		return
	
	# Deduct refresh cost
	var eco_mgr = get_node_or_null("/root/EconomyManager")
	if eco_mgr:
		eco_mgr.remove_gold(REFRESH_COST, "shop_refresh")
	
	refresh_shop()
	_update_gold_display()
	
	print("[ShopUI] Shop refreshed for %d gold" % REFRESH_COST)

func _on_close_pressed():
	shop_closed.emit()
	queue_free()

func _update_gold_display():
	var gold = _get_current_gold()
	gold_label.text = str(gold)

func _get_current_gold() -> int:
	var state = get_node_or_null("/root/StateManager")
	if state:
		return state.get_gold()
	return 0

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_close_pressed()
