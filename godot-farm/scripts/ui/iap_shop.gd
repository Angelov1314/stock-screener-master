extends CanvasLayer

## Shop Panel - In-app purchase for gold

signal shop_closed
signal gold_purchased(amount: int)

@onready var close_button: Button = %CloseButton

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
	_setup_purchase_grid()
	
	# Close on escape - handled by _input() function

func _setup_purchase_grid():
	var grid = get_node_or_null("CenterContainer/Panel/VBoxContainer/ScrollContainer/PurchaseGrid")
	if not grid:
		return
	
	for tier in purchase_tiers:
		var card = _create_purchase_card(tier)
		grid.add_child(card)

func _create_purchase_card(tier: Dictionary) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(160, 200)
	
	# Card Style - 低饱和高级感配色
	var style = StyleBoxFlat.new()
	if tier.popular:
		# 热销卡片 - 暖灰色调
		style.bg_color = Color(0.88, 0.85, 0.80, 0.98)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.75, 0.70, 0.60, 0.8)
	else:
		# 普通卡片 - 冷灰色调
		style.bg_color = Color(0.92, 0.92, 0.94, 0.95)
	
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_size = 3
	style.shadow_color = Color(0, 0, 0, 0.15)
	card.add_theme_stylebox_override("panel", style)
	
	# Container
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)
	
	# Spacer
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(top_spacer)
	
	# Gold amount - 深棕色，低饱和
	var gold_label = Label.new()
	gold_label.text = "💰 %d" % tier.gold
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 26)
	gold_label.add_theme_color_override("font_color", Color(0.55, 0.45, 0.30))
	vbox.add_child(gold_label)
	
	# Price - 深灰蓝色，低饱和
	var price_label = Label.new()
	price_label.text = tier.price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 22)
	price_label.add_theme_color_override("font_color", Color(0.35, 0.38, 0.45))
	vbox.add_child(price_label)
	
	# Popular badge - 柔和的暖色调
	if tier.popular:
		var badge_bg = Panel.new()
		badge_bg.custom_minimum_size = Vector2(80, 26)
		
		var badge_style = StyleBoxFlat.new()
		badge_style.bg_color = Color(0.85, 0.60, 0.35, 0.9)
		badge_style.corner_radius_top_left = 13
		badge_style.corner_radius_top_right = 13
		badge_style.corner_radius_bottom_left = 13
		badge_style.corner_radius_bottom_right = 13
		badge_bg.add_theme_stylebox_override("panel", badge_style)
		
		var badge_label = Label.new()
		badge_label.text = "✦ 热销"
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_font_size_override("font_size", 13)
		badge_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.94))
		badge_bg.add_child(badge_label)
		
		vbox.add_child(badge_bg)
	else:
		# Spacer for non-popular items
		var badge_spacer = Control.new()
		badge_spacer.custom_minimum_size = Vector2(0, 26)
		vbox.add_child(badge_spacer)
	
	# Buy button - 低饱和高级感配色
	var buy_btn = Button.new()
	buy_btn.text = "购买"
	buy_btn.custom_minimum_size = Vector2(100, 44)
	
	# Normal state - 深灰蓝色，低饱和
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.25, 0.28, 0.35, 0.95)
	btn_normal.corner_radius_top_left = 8
	btn_normal.corner_radius_top_right = 8
	btn_normal.corner_radius_bottom_left = 8
	btn_normal.corner_radius_bottom_right = 8
	btn_normal.shadow_size = 2
	btn_normal.shadow_color = Color(0, 0, 0, 0.3)
	buy_btn.add_theme_stylebox_override("normal", btn_normal)
	
	# Hover state - 稍亮的灰蓝色
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.32, 0.35, 0.42, 0.98)
	btn_hover.corner_radius_top_left = 8
	btn_hover.corner_radius_top_right = 8
	btn_hover.corner_radius_bottom_left = 8
	btn_hover.corner_radius_bottom_right = 8
	btn_hover.shadow_size = 4
	btn_hover.shadow_color = Color(0, 0, 0, 0.4)
	buy_btn.add_theme_stylebox_override("hover", btn_hover)
	
	# Pressed state - 更深的灰蓝色
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.18, 0.21, 0.28, 1.0)
	btn_pressed.corner_radius_top_left = 8
	btn_pressed.corner_radius_top_right = 8
	btn_pressed.corner_radius_bottom_left = 8
	btn_pressed.corner_radius_bottom_right = 8
	buy_btn.add_theme_stylebox_override("pressed", btn_pressed)
	
	# 文字颜色 - 米白色
	buy_btn.add_theme_color_override("font_color", Color(0.95, 0.94, 0.92))
	buy_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	buy_btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.84, 0.82))
	buy_btn.add_theme_font_size_override("font_size", 16)
	
	buy_btn.pressed.connect(_on_purchase_pressed.bind(tier.gold, tier.price))
	vbox.add_child(buy_btn)
	
	return card

func _on_purchase_pressed(gold_amount: int, price: String):
	print("[IAPShop] Purchase requested: %s for %d gold" % [price, gold_amount])
	
	# Simulate purchase (in real app, integrate with App Store/Google Play)
	var confirmed = await _show_confirm_dialog(price, gold_amount)
	
	if confirmed:
		# Add gold to player
		var state = get_node_or_null("/root/StateManager")
		if state:
			state.apply_action({"type": "add_gold", "amount": gold_amount})
			print("[IAPShop] Added %d gold to player" % gold_amount)
		
		gold_purchased.emit(gold_amount)
		_show_success_message(gold_amount)

func _show_confirm_dialog(price: String, gold: int) -> bool:
	# Simple confirmation (in real app, show proper dialog)
	print("[IAPShop] Confirm purchase: %s -> %d gold" % [price, gold])
	# For now, auto-confirm in development
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
	style.bg_color = Color(0.2, 0.8, 0.2, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	toast.add_theme_stylebox_override("normal", style)
	toast.add_theme_font_size_override("font_size", 20)
	
	add_child(toast)
	
	# Animate and remove
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
