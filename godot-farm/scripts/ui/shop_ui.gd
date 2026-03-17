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
var sell_mode: bool = false

const REFRESH_COST: int = 50

# Cozy farm palette - soft, low-contrast, warm
const COL_BG_DEEP := Color(0.26, 0.22, 0.17, 0.92)
const COL_PAPER := Color(0.88, 0.83, 0.74, 0.45)
const COL_PAPER_HOVER := Color(0.92, 0.87, 0.78, 0.55)
const COL_SEED := Color(0.82, 0.78, 0.66, 0.42)
const COL_SEED_HOVER := Color(0.87, 0.83, 0.72, 0.55)
const COL_SEED_BORDER := Color(0.62, 0.55, 0.40, 0.40)
const COL_BORDER := Color(0.50, 0.42, 0.32, 0.45)
const COL_TEXT := Color(0.30, 0.24, 0.18)
const COL_TEXT_MUTED := Color(0.48, 0.40, 0.30, 0.85)
const COL_ACCENT := Color(0.63, 0.52, 0.39)
const COL_ACCENT_GREEN := Color(0.42, 0.56, 0.36, 0.85)
const COL_BTN := Color(0.58, 0.48, 0.36, 0.72)
const COL_BTN_SELL := Color(0.52, 0.46, 0.38, 0.72)

func _ready():
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

	_apply_cozy_theme()
	_load_shop_data()
	_populate_shop()
	_update_gold_display()

# ── Theme ────────────────────────────────────────────────────────────────

func _apply_cozy_theme():
	# Main container panel
	var main_container = get_node_or_null("MainContainer") as Panel
	if main_container:
		var s = StyleBoxFlat.new()
		s.bg_color = COL_BG_DEEP
		s.border_color = Color(0.46, 0.37, 0.28, 0.65)
		s.set_border_width_all(2)
		s.border_width_bottom = 3
		s.set_corner_radius_all(22)
		s.shadow_color = Color(0.14, 0.10, 0.06, 0.22)
		s.shadow_size = 14
		main_container.add_theme_stylebox_override("panel", s)

	# Item detail panel
	var ip = get_node_or_null("MainContainer/ItemPanel") as Panel
	if ip:
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.82, 0.76, 0.66, 0.78)
		s.border_color = COL_BORDER
		s.set_border_width_all(1)
		s.border_width_bottom = 2
		s.set_corner_radius_all(18)
		s.shadow_color = Color(0.18, 0.12, 0.06, 0.25)
		s.shadow_size = 8
		ip.add_theme_stylebox_override("panel", s)

	# Title & gold label colours
	for path in [
		"MainContainer/VBoxContainer/TitleLabel",
		"MainContainer/VBoxContainer/GoldDisplay/GoldLabel",
	]:
		var lbl = get_node_or_null(path) as Label
		if lbl:
			lbl.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))

	# Item panel labels
	for path in [
		"MainContainer/ItemPanel/ItemVBox/ItemName",
		"MainContainer/ItemPanel/ItemVBox/ItemDesc",
		"MainContainer/ItemPanel/ItemVBox/ItemPrice"
	]:
		var lbl = get_node_or_null(path) as Label
		if lbl:
			lbl.add_theme_color_override("font_color", COL_TEXT)

	# Buttons
	for btn_path in [
		"MainContainer/VBoxContainer/BottomBar/RefreshButton",
		"MainContainer/VBoxContainer/BottomBar/CloseButton",
		"MainContainer/ItemPanel/ItemVBox/BuyButton"
	]:
		var btn = get_node_or_null(btn_path) as Button
		if btn:
			_style_button(btn, COL_BTN)

	# Tab container styling
	_style_tab_container()

func _style_tab_container():
	var tc = get_node_or_null("MainContainer/VBoxContainer/TabContainer") as TabContainer
	if not tc:
		return

	# Tab panel (content area) – transparent so scroll containers show cards nicely
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.22, 0.18, 0.14, 0.35)
	panel_style.set_corner_radius_all(0)
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.set_border_width_all(0)
	tc.add_theme_stylebox_override("panel", panel_style)

	# Tab bar styles
	var tab_sel = StyleBoxFlat.new()
	tab_sel.bg_color = Color(0.72, 0.64, 0.50, 0.65)
	tab_sel.set_corner_radius_all(0)
	tab_sel.corner_radius_top_left = 12
	tab_sel.corner_radius_top_right = 12
	tab_sel.set_border_width_all(0)
	tab_sel.content_margin_left = 14
	tab_sel.content_margin_right = 14
	tab_sel.content_margin_top = 6
	tab_sel.content_margin_bottom = 6
	tc.add_theme_stylebox_override("tab_selected", tab_sel)

	var tab_unsel = StyleBoxFlat.new()
	tab_unsel.bg_color = Color(0.42, 0.36, 0.28, 0.40)
	tab_unsel.set_corner_radius_all(0)
	tab_unsel.corner_radius_top_left = 10
	tab_unsel.corner_radius_top_right = 10
	tab_unsel.content_margin_left = 12
	tab_unsel.content_margin_right = 12
	tab_unsel.content_margin_top = 5
	tab_unsel.content_margin_bottom = 5
	tc.add_theme_stylebox_override("tab_unselected", tab_unsel)

	var tab_hover = tab_unsel.duplicate()
	tab_hover.bg_color = Color(0.52, 0.44, 0.34, 0.50)
	tc.add_theme_stylebox_override("tab_hovered", tab_hover)

	tc.add_theme_color_override("font_selected_color", Color(0.96, 0.93, 0.86))
	tc.add_theme_color_override("font_unselected_color", Color(0.78, 0.72, 0.62))
	tc.add_theme_color_override("font_hovered_color", Color(0.90, 0.85, 0.76))

func _style_button(btn: Button, base: Color = COL_BTN):
	var normal = StyleBoxFlat.new()
	normal.bg_color = base
	normal.border_color = Color(base.r - 0.12, base.g - 0.12, base.b - 0.12, 0.40)
	normal.border_width_bottom = 2
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover = normal.duplicate()
	hover.bg_color = Color(base.r + 0.06, base.g + 0.06, base.b + 0.06, base.a)
	var pressed = normal.duplicate()
	pressed.bg_color = Color(base.r - 0.05, base.g - 0.05, base.b - 0.05, base.a)
	pressed.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.88))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.90, 0.86, 0.78))

# ── Card helpers ─────────────────────────────────────────────────────────

func _make_card_style(bg: Color, border: Color, radius: int = 18) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.border_width_bottom = 2
	s.set_corner_radius_all(radius)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _make_card_base(min_size: Vector2, normal_style: StyleBoxFlat, hover_style: StyleBoxFlat) -> Button:
	var card = Button.new()
	card.custom_minimum_size = min_size
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("normal", normal_style)
	card.add_theme_stylebox_override("hover", hover_style)
	# Pressed = slightly darker hover
	var ps = hover_style.duplicate()
	ps.bg_color.a = min(ps.bg_color.a + 0.08, 1.0)
	card.add_theme_stylebox_override("pressed", ps)
	return card

# ── Data ─────────────────────────────────────────────────────────────────

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
	for child in animals_grid.get_children():
		child.queue_free()
	for child in plants_grid.get_children():
		child.queue_free()
	for child in inventory_grid.get_children():
		child.queue_free()
	for animal in shop_data.get("animals", []):
		_create_card(animals_grid, animal, "animal")
	for plant in shop_data.get("plants", []):
		_create_card(plants_grid, plant, "plant")
	_populate_inventory()

# ── Shop cards ───────────────────────────────────────────────────────────

func _create_card(parent: GridContainer, item: Dictionary, item_type: String):
	var is_seed = item_type == "plant"

	var bg = COL_SEED if is_seed else COL_PAPER
	var bg_h = COL_SEED_HOVER if is_seed else COL_PAPER_HOVER
	var bdr = COL_SEED_BORDER if is_seed else COL_BORDER
	var radius = 22 if is_seed else 18

	var ns = _make_card_style(bg, bdr, radius)
	var hs = _make_card_style(bg_h, bdr, radius)
	hs.border_width_bottom = 3

	var card = _make_card_base(Vector2(140, 185), ns, hs)

	# Inner vbox
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 6; vbox.offset_right = -6
	vbox.offset_top = 8; vbox.offset_bottom = -8
	card.add_child(vbox)

	# Seed packet label at top
	if is_seed:
		var tag = Label.new()
		tag.text = "🌱 SEED"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_color_override("font_color", COL_ACCENT_GREEN)
		tag.add_theme_font_size_override("font_size", 11)
		vbox.add_child(tag)

	# Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(68, 68)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon_path = _get_icon_path(item.id, item_type)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	vbox.add_child(icon)

	# Divider line for seeds
	if is_seed:
		var sep = HSeparator.new()
		sep.add_theme_stylebox_override("separator", _thin_separator())
		vbox.add_child(sep)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = item.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	name_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(name_lbl)

	# Price
	var price_lbl = Label.new()
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 13)
	if is_seed:
		price_lbl.text = "🌱 %d 金" % item.price
		price_lbl.add_theme_color_override("font_color", COL_ACCENT_GREEN)
	else:
		price_lbl.text = "💰 %d" % item.price
		price_lbl.add_theme_color_override("font_color", COL_TEXT_MUTED)
	vbox.add_child(price_lbl)

	card.pressed.connect(_on_card_clicked.bind(item, item_type))
	parent.add_child(card)

func _thin_separator() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = COL_SEED_BORDER
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	return s

# ── Inventory cards ──────────────────────────────────────────────────────

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
	var ns = _make_card_style(COL_PAPER, COL_BORDER, 18)
	var hs = _make_card_style(COL_PAPER_HOVER, COL_BORDER, 18)
	hs.border_width_bottom = 3
	var card = _make_card_base(Vector2(140, 185), ns, hs)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 6; vbox.offset_right = -6
	vbox.offset_top = 8; vbox.offset_bottom = -8
	card.add_child(vbox)

	# Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(64, 64)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon_path = "res://assets/crops/%s/%s_mature.png" % [item.id, item.id]
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	vbox.add_child(icon)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = item.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_lbl)

	# Count
	var count_lbl = Label.new()
	count_lbl.text = "× %d" % item.count
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_color_override("font_color", COL_TEXT_MUTED)
	count_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(count_lbl)

	# Sell price
	var price_lbl = Label.new()
	price_lbl.text = "💰 %d / 个" % item.sell_price
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_color_override("font_color", COL_ACCENT_GREEN)
	price_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(price_lbl)

	# Action buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_hbox)

	if item.id in ["cow", "pig", "sheep", "zebra", "shiba", "koala", "cat", "capybara", "alpaca"]:
		var place_btn = Button.new()
		place_btn.text = "放置"
		place_btn.custom_minimum_size = Vector2(52, 28)
		_style_button(place_btn, Color(0.50, 0.48, 0.40, 0.72))
		place_btn.add_theme_font_size_override("font_size", 12)
		place_btn.pressed.connect(_place_animal.bind(item))
		btn_hbox.add_child(place_btn)

	var sell_btn = Button.new()
	sell_btn.text = "出售"
	sell_btn.custom_minimum_size = Vector2(52, 28)
	_style_button(sell_btn, COL_BTN_SELL)
	sell_btn.add_theme_font_size_override("font_size", 12)
	sell_btn.pressed.connect(_sell_item_direct.bind(item))
	btn_hbox.add_child(sell_btn)

	card.pressed.connect(_on_inventory_card_clicked.bind(item))
	inventory_grid.add_child(card)

# ── Icon path resolution ────────────────────────────────────────────────

func _get_icon_path(id: String, item_type: String) -> String:
	if item_type == "animal":
		for path in [
			"res://assets/characters/%s/idle/%s_idle_01.png" % [id, id],
			"res://assets/characters/%s/idle/%s_idle_0.png" % [id, id],
			"res://assets/characters/%s/idle/%s_idle_1.png" % [id, id],
			"res://assets/characters/%s/idle/idle_01.png" % [id],
			"res://assets/characters/%s/idle/idle_0.png" % [id],
			"res://assets/characters/%s/idle/idle_1.png" % [id],
			"res://assets/characters/%s/idle/01.png" % [id],
		]:
			if ResourceLoader.exists(path):
				return path
	else:
		# Prefer seed image for shop plant cards
		for path in [
			"res://assets/crops/%s/%s_seed.png" % [id, id],
			"res://assets/crops/%s/%s_seeds.png" % [id, id],
			"res://assets/crops/%s/seed.png" % [id],
			"res://assets/crops/%s/%s_mature.png" % [id, id]
		]:
			if ResourceLoader.exists(path):
				return path
	return ""

# ── Card click handlers ─────────────────────────────────────────────────

func _on_card_clicked(item: Dictionary, item_type: String):
	_play_ui_click()
	if not item_name or not buy_button:
		return
	selected_item = item.duplicate()
	selected_item["type"] = item_type
	sell_mode = false

	item_name.text = item.name
	if item_desc:
		item_desc.text = item.description
	if item_price:
		item_price.text = "💰 %d 金" % item.price

	var icon_path = _get_icon_path(item.id, item_type)
	if item_icon:
		item_icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null

	var gold = _get_current_gold()
	buy_button.disabled = gold < item.price
	buy_button.text = "金币不足" if buy_button.disabled else "购买"
	_style_button(buy_button, COL_ACCENT_GREEN if not buy_button.disabled else Color(0.5, 0.45, 0.38, 0.6))

	if item_panel:
		item_panel.visible = true

func _on_inventory_card_clicked(item: Dictionary):
	_play_ui_click()
	selected_item = item.duplicate()
	sell_mode = true

	if item_name:
		item_name.text = item.name
	if item_desc:
		item_desc.text = "拥有数量: %d" % item.count
	if item_price:
		item_price.text = "出售价: 💰 %d / 个" % item.sell_price

	var icon_path = "res://assets/crops/%s/%s_mature.png" % [item.id, item.id]
	if item_icon:
		item_icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null

	if buy_button:
		buy_button.disabled = false
		buy_button.text = "出售"
		_style_button(buy_button, COL_BTN_SELL)

	if item_panel:
		item_panel.visible = true

# ── Buy / sell ───────────────────────────────────────────────────────────

func _on_buy_pressed():
	_play_ui_click()
	if selected_item.is_empty():
		return

	if sell_mode:
		_sell_crop(selected_item.id, 1)
	else:
		var price = selected_item.price
		var state = get_node_or_null("/root/StateManager")
		if not state:
			return
		var gold = state.get_gold()
		if gold < price:
			return
		var success = state.apply_action({"type": "remove_gold", "amount": price})
		if not success:
			return

		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr:
			audio_mgr.play_sfx_path("res://assets/audio/sfx/ui/coin_asmr.mp3", 0.85)
		item_purchased.emit(selected_item.id, selected_item.type)

		if selected_item.type == "animal":
			animal_purchased.emit(selected_item.id)
			state.apply_action({"type": "add_item", "item_id": selected_item.id, "amount": 1})
			state.apply_action({"type": "add_experience", "amount": 25})
			if audio_mgr:
				audio_mgr.play_sfx_path("res://assets/audio/sfx/ui/xp_gain.mp3", 0.9)
		elif selected_item.type == "plant":
			_give_seed(selected_item.id)

	_update_gold_display()
	_populate_shop()
	item_panel.visible = false
	sell_mode = false

func _sell_crop(crop_id: String, amount: int):
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return
	var gold_earned = crop_mgr.sell_crop(crop_id, amount)
	if gold_earned > 0:
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr:
			audio_mgr.play_sfx_path("res://assets/audio/sfx/ui/coin_asmr.mp3", 0.85)

func _give_seed(plant_id: String):
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.apply_action({"type": "add_item", "item_id": plant_id + "_seed", "amount": 1})
		state.apply_action({"type": "add_experience", "amount": 10})

func _place_animal(item: Dictionary):
	_play_ui_click()
	var placement_mgr = get_node_or_null("/root/AnimalPlacementManager")
	if not placement_mgr:
		return
	var success = placement_mgr.start_placement(item.id)
	if success:
		# Close shop to let user click on the map
		_on_close_pressed()

func _sell_item_direct(item: Dictionary):
	_play_ui_click()
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return
	var gold_earned = crop_mgr.sell_crop(item.id, 1)
	if gold_earned > 0:
		_update_gold_display()
		_populate_inventory()

# ── Misc ─────────────────────────────────────────────────────────────────

func _play_ui_click():
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx_path("res://assets/audio/sfx/ui/ui_click.mp3", 0.8)

func _on_refresh_pressed():
	_play_ui_click()
	var gold = _get_current_gold()
	if gold < REFRESH_COST:
		return
	var eco_mgr = get_node_or_null("/root/EconomyManager")
	if eco_mgr:
		eco_mgr.remove_gold(REFRESH_COST, "shop_refresh")
	_populate_shop()
	_update_gold_display()

func _on_close_pressed():
	_play_ui_click()
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
