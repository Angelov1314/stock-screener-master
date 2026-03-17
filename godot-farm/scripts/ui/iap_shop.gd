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
	
	# Close on escape
	_input_event_check()

func _setup_purchase_grid():
	var grid = get_node_or_null("CenterContainer/Panel/VBoxContainer/ScrollContainer/PurchaseGrid")
	if not grid:
		return
	
	for tier in purchase_tiers:
		var card = _create_purchase_card(tier)
		grid.add_child(card)

func _create_purchase_card(tier: Dictionary) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(150, 180)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override("panel", style)
	
	# Container
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)
	
	# Gold amount
	var gold_label = Label.new()
	gold_label.text = "💰 %d" % tier.gold
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.1))
	vbox.add_child(gold_label)
	
	# Price
	var price_label = Label.new()
	price_label.text = tier.price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 20)
	price_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
	vbox.add_child(price_label)
	
	# Popular badge
	if tier.popular:
		var badge = Label.new()
		badge.text = "🔥 热销"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", Color(0.9, 0.3, 0.1))
		vbox.add_child(badge)
	
	# Buy button
	var buy_btn = Button.new()
	buy_btn.text = "购买"
	buy_btn.custom_minimum_size = Vector2(100, 40)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.3, 0.7, 0.3)
	btn_style.corner_radius_top_left = 5
	btn_style.corner_radius_top_right = 5
	btn_style.corner_radius_bottom_left = 5
	btn_style.corner_radius_bottom_right = 5
	buy_btn.add_theme_stylebox_override("normal", btn_style)
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
