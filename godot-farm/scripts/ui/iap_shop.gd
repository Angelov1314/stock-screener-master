extends CanvasLayer

## IAP Shop - In-app purchase for gold (cozy farm theme)

signal shop_closed
signal gold_purchased(amount: int)

@onready var close_button: Button = %CloseButton

# Cozy farm palette (shared with shop_ui)
const COL_BG_DEEP := Color(0.26, 0.22, 0.17, 0.92)
const COL_PAPER := Color(0.88, 0.83, 0.74, 0.45)
const COL_PAPER_HOVER := Color(0.92, 0.87, 0.78, 0.55)
const COL_BORDER := Color(0.50, 0.42, 0.32, 0.45)
const COL_TEXT := Color(0.30, 0.24, 0.18)
const COL_TEXT_MUTED := Color(0.48, 0.40, 0.30, 0.85)
const COL_BTN := Color(0.58, 0.48, 0.36, 0.72)
const COL_ACCENT_GOLD := Color(0.72, 0.60, 0.32, 0.90)

# Purchase tiers
var purchase_tiers = [
	{"price": "$1.99", "gold": 1000, "popular": false},
	{"price": "$4.99", "gold": 2500, "popular": false},
	{"price": "$9.99", "gold": 5500, "popular": true},
	{"price": "$19.99", "gold": 12000, "popular": false},
	{"price": "$29.99", "gold": 20000, "popular": false},
	{"price": "$49.99", "gold": 35000, "popular": false},
	{"price": "$99.99", "gold": 50000, "popular": false}
]

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	_apply_cozy_theme()
	_setup_purchase_grid()

func _apply_cozy_theme():
	# Background overlay
	var bg = get_node_or_null("Background") as ColorRect
	if bg:
		bg.color = Color(0.12, 0.10, 0.07, 0.75)

	# Main panel
	var panel = get_node_or_null("CenterContainer/Panel") as Panel
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

	# Title label
	var title = get_node_or_null("CenterContainer/Panel/VBoxContainer/TitleLabel") as Label
	if title:
		title.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))

	# Subtitle
	var sub = get_node_or_null("CenterContainer/Panel/VBoxContainer/SubtitleLabel") as Label
	if sub:
		sub.add_theme_color_override("font_color", COL_TEXT_MUTED)

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

func _setup_purchase_grid():
	var grid = get_node_or_null("CenterContainer/Panel/VBoxContainer/ScrollContainer/PurchaseGrid")
	if not grid:
		return
	for tier in purchase_tiers:
		var card = _create_purchase_card(tier)
		grid.add_child(card)

func _create_purchase_card(tier: Dictionary) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(155, 195)

	var style = StyleBoxFlat.new()
	if tier.popular:
		style.bg_color = Color(0.82, 0.76, 0.64, 0.72)
		style.border_color = COL_ACCENT_GOLD
		style.set_border_width_all(2)
		style.border_width_bottom = 3
	else:
		style.bg_color = COL_PAPER
		style.border_color = COL_BORDER
		style.set_border_width_all(1)
		style.border_width_bottom = 2
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.14, 0.10, 0.06, 0.18)
	style.shadow_size = 6
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8; vbox.offset_right = -8
	vbox.offset_top = 10; vbox.offset_bottom = -10
	card.add_child(vbox)

	# Popular badge
	if tier.popular:
		var badge = Label.new()
		badge.text = "✦ 热销"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", COL_ACCENT_GOLD)
		vbox.add_child(badge)
	else:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 16)
		vbox.add_child(spacer)

	# Gold amount
	var gold_label = Label.new()
	gold_label.text = "💰 %d" % tier.gold
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", COL_TEXT)
	vbox.add_child(gold_label)

	# Price
	var price_label = Label.new()
	price_label.text = tier.price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 18)
	price_label.add_theme_color_override("font_color", COL_TEXT_MUTED)
	vbox.add_child(price_label)

	# Spacer
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(sp)

	# Buy button
	var buy_btn = Button.new()
	buy_btn.text = "购买"
	buy_btn.custom_minimum_size = Vector2(90, 38)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_button(buy_btn, COL_BTN)
	buy_btn.add_theme_font_size_override("font_size", 15)
	buy_btn.pressed.connect(_on_purchase_pressed.bind(tier.gold, tier.price))
	vbox.add_child(buy_btn)

	return card

func _on_purchase_pressed(gold_amount: int, price: String):
	print("[IAPShop] Purchase requested: %s for %d gold" % [price, gold_amount])
	var confirmed = await _show_confirm_dialog(price, gold_amount)
	if confirmed:
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr:
			audio_mgr.play_sfx_path("res://assets/audio/sfx/ui/coin_asmr.mp3", 0.85)
		var state = get_node_or_null("/root/StateManager")
		if state:
			state.apply_action({"type": "add_gold", "amount": gold_amount})
		gold_purchased.emit(gold_amount)
		_show_success_message(gold_amount)

func _show_confirm_dialog(price: String, gold: int) -> bool:
	print("[IAPShop] Confirm purchase: %s -> %d gold" % [price, gold])
	await get_tree().create_timer(0.5).timeout
	return true

func _show_success_message(gold: int):
	var toast = Label.new()
	toast.text = "✓ 成功购买 %d 金币!" % gold
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.position = Vector2(get_viewport().size.x / 2 - 150, 100)
	toast.size = Vector2(300, 50)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.42, 0.56, 0.36, 0.88)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	toast.add_theme_stylebox_override("normal", style)
	toast.add_theme_font_size_override("font_size", 18)
	toast.add_theme_color_override("font_color", Color(0.96, 0.93, 0.88))
	add_child(toast)
	var tween = create_tween()
	tween.tween_property(toast, "modulate:a", 0, 2.0)
	await tween.finished
	toast.queue_free()

func _on_close_pressed():
	shop_closed.emit()
	queue_free()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
