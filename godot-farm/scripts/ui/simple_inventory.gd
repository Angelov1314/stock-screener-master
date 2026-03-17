extends CanvasLayer

## Simple Inventory UI - Cozy farm themed backpack

@onready var item_grid: GridContainer = $Panel/VBoxContainer/ScrollContainer/ItemGrid
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

signal panel_closed

# Cozy farm palette
const COL_BG_DEEP := Color(0.26, 0.22, 0.17, 0.92)
const COL_PAPER := Color(0.88, 0.83, 0.74, 0.45)
const COL_PAPER_HOVER := Color(0.92, 0.87, 0.78, 0.55)
const COL_BORDER := Color(0.50, 0.42, 0.32, 0.45)
const COL_TEXT := Color(0.30, 0.24, 0.18)
const COL_TEXT_MUTED := Color(0.48, 0.40, 0.30, 0.85)
const COL_BTN := Color(0.58, 0.48, 0.36, 0.72)

func _ready():
	close_button.pressed.connect(_on_close)
	_apply_cozy_theme()
	_refresh_items()

func _apply_cozy_theme():
	# Main panel
	var panel = get_node_or_null("Panel") as Panel
	if panel:
		var s = StyleBoxFlat.new()
		s.bg_color = COL_BG_DEEP
		s.border_color = Color(0.46, 0.37, 0.28, 0.65)
		s.set_border_width_all(2)
		s.border_width_bottom = 3
		s.set_corner_radius_all(22)
		s.shadow_color = Color(0.14, 0.10, 0.06, 0.22)
		s.shadow_size = 14
		panel.add_theme_stylebox_override("panel", s)

	# Title if exists
	var title = get_node_or_null("Panel/VBoxContainer/TitleLabel") as Label
	if title:
		title.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))

	# Close button
	_style_button(close_button, COL_BTN)

func _style_button(btn: Button, base: Color):
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

func _make_card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.border_width_bottom = 2
	s.set_corner_radius_all(16)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _refresh_items():
	for child in item_grid.get_children():
		child.queue_free()

	var state = get_node_or_null("/root/StateManager")
	if not state:
		return

	var inventory = state.get_inventory()
	if inventory.is_empty():
		var label = Label.new()
		label.text = "🎒 背包是空的"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", COL_TEXT_MUTED)
		label.add_theme_font_size_override("font_size", 16)
		item_grid.add_child(label)
		return

	for item_id in inventory.keys():
		var count = inventory[item_id]
		if count <= 0:
			continue
		_create_item_card(item_id, count)

func _create_item_card(item_id: String, count: int):
	var ns = _make_card_style(COL_PAPER, COL_BORDER)
	var hs = _make_card_style(COL_PAPER_HOVER, COL_BORDER)
	hs.border_width_bottom = 3

	var card = Button.new()
	card.custom_minimum_size = Vector2(100, 110)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("normal", ns)
	card.add_theme_stylebox_override("hover", hs)
	var ps = hs.duplicate()
	ps.bg_color.a = min(ps.bg_color.a + 0.08, 1.0)
	card.add_theme_stylebox_override("pressed", ps)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4; vbox.offset_right = -4
	vbox.offset_top = 6; vbox.offset_bottom = -6
	card.add_child(vbox)

	# Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon_path = _resolve_icon(item_id)
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	vbox.add_child(icon)

	# Name (clean up _seed suffix for display)
	var display_name = item_id.replace("_seed", " 种子").replace("_", " ")
	var name_lbl = Label.new()
	name_lbl.text = display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	name_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_lbl)

	# Count
	var count_lbl = Label.new()
	count_lbl.text = "× %d" % count
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_color_override("font_color", COL_TEXT_MUTED)
	count_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(count_lbl)

	item_grid.add_child(card)

func _resolve_icon(item_id: String) -> String:
	# Try crop icons
	for path in [
		"res://assets/crops/%s/%s_mature.png" % [item_id, item_id],
		"res://assets/crops/%s/%s_seed.png" % [item_id, item_id],
	]:
		if ResourceLoader.exists(path):
			return path
	# Try seed variant (item_id might be "tomato_seed")
	var base = item_id.replace("_seed", "")
	for path in [
		"res://assets/crops/%s/%s_seed.png" % [base, base],
		"res://assets/crops/%s/seed.png" % [base],
		"res://assets/crops/%s/%s_mature.png" % [base, base],
	]:
		if ResourceLoader.exists(path):
			return path
	# Try animal icons
	for path in [
		"res://assets/characters/%s/idle/%s_idle_01.png" % [item_id, item_id],
		"res://assets/characters/%s/idle/idle_01.png" % [item_id],
		"res://assets/characters/%s/idle/idle_0.png" % [item_id],
		"res://assets/characters/%s/idle/01.png" % [item_id],
	]:
		if ResourceLoader.exists(path):
			return path
	return ""

func _on_close():
	panel_closed.emit()
	queue_free()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close()
