extends CanvasLayer

## Planting Menu - Seed selection with cozy farm theme

signal seed_selected(seed_id: String)
signal menu_closed

@onready var seed_grid: GridContainer = $Panel/VBoxContainer/ScrollContainer/SeedGrid
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

# Cozy farm palette
const COL_BG_DEEP := Color(0.26, 0.22, 0.17, 0.92)
const COL_SEED := Color(0.82, 0.78, 0.66, 0.42)
const COL_SEED_HOVER := Color(0.87, 0.83, 0.72, 0.55)
const COL_SEED_BORDER := Color(0.62, 0.55, 0.40, 0.40)
const COL_TEXT := Color(0.30, 0.24, 0.18)
const COL_TEXT_MUTED := Color(0.48, 0.40, 0.30, 0.85)
const COL_ACCENT_GREEN := Color(0.42, 0.56, 0.36, 0.85)
const COL_BTN := Color(0.58, 0.48, 0.36, 0.72)

var _seeds: Array[Dictionary] = [
	{"id": "carrot", "name": "胡萝卜", "cost": 5},
	{"id": "corn", "name": "玉米", "cost": 15},
	{"id": "tomato", "name": "番茄", "cost": 12},
	{"id": "strawberry", "name": "草莓", "cost": 10},
	{"id": "wheat", "name": "小麦", "cost": 3}
]

func _ready():
	close_button.pressed.connect(_on_close)
	_apply_cozy_theme()
	_create_seed_buttons()

func _apply_cozy_theme():
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

	var title = get_node_or_null("Panel/VBoxContainer/TitleLabel") as Label
	if title:
		title.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))

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

func _create_seed_buttons():
	for seed_data in _seeds:
		var ns = StyleBoxFlat.new()
		ns.bg_color = COL_SEED
		ns.border_color = COL_SEED_BORDER
		ns.set_border_width_all(1)
		ns.border_width_bottom = 2
		ns.set_corner_radius_all(18)
		ns.content_margin_left = 6
		ns.content_margin_right = 6
		ns.content_margin_top = 8
		ns.content_margin_bottom = 8

		var hs = ns.duplicate()
		hs.bg_color = COL_SEED_HOVER
		hs.border_width_bottom = 3

		var card = Button.new()
		card.custom_minimum_size = Vector2(110, 130)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("normal", ns)
		card.add_theme_stylebox_override("hover", hs)
		var ps = hs.duplicate()
		ps.bg_color.a = min(ps.bg_color.a + 0.08, 1.0)
		card.add_theme_stylebox_override("pressed", ps)

		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 6; vbox.offset_right = -6
		vbox.offset_top = 8; vbox.offset_bottom = -8
		card.add_child(vbox)

		# Seed tag
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
		icon.custom_minimum_size = Vector2(48, 48)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for path in [
			"res://assets/crops/%s/%s_seed.png" % [seed_data.id, seed_data.id],
			"res://assets/crops/%s/%s_seeds.png" % [seed_data.id, seed_data.id],
			"res://assets/crops/%s/seed.png" % [seed_data.id],
		]:
			if ResourceLoader.exists(path):
				icon.texture = load(path)
				break
		vbox.add_child(icon)

		# Name
		var name_lbl = Label.new()
		name_lbl.text = seed_data.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", COL_TEXT)
		name_lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(name_lbl)

		# Cost
		var cost_lbl = Label.new()
		cost_lbl.text = "🌱 %d 金" % seed_data.cost
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_color_override("font_color", COL_ACCENT_GREEN)
		cost_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(cost_lbl)

		card.pressed.connect(_on_seed_selected.bind(seed_data.id))
		seed_grid.add_child(card)

func _on_seed_selected(seed_id: String):
	print("[PlantingMenu] Seed selected: %s" % seed_id)
	seed_selected.emit(seed_id)
	queue_free()

func _on_close():
	menu_closed.emit()
	queue_free()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close()
