extends CanvasLayer

## Collection Panel - Food collection gallery with gacha and upgrades

signal collection_closed

# Cozy palette matching shop_ui
const COL_BG := Color(0.26, 0.22, 0.17, 0.95)
const COL_CARD := Color(0.32, 0.27, 0.22, 0.85)
const COL_CARD_LOCKED := Color(0.20, 0.17, 0.14, 0.60)
const COL_CARD_HOVER := Color(0.38, 0.32, 0.26, 0.90)
const COL_BORDER := Color(0.50, 0.42, 0.32, 0.45)
const COL_TEXT := Color(0.94, 0.90, 0.82)
const COL_TEXT_DIM := Color(0.60, 0.54, 0.46)
const COL_ACCENT := Color(0.63, 0.52, 0.39)
const COL_ACCENT_GREEN := Color(0.42, 0.56, 0.36, 0.85)

const RARITY_BORDER_COLORS := {
	"common": Color(0.55, 0.62, 0.76, 0.6),
	"uncommon": Color(0.31, 0.80, 0.77, 0.7),
	"rare": Color(0.66, 0.33, 0.97, 0.8),
	"epic": Color(0.96, 0.62, 0.04, 0.85),
	"legendary": Color(0.94, 0.27, 0.27, 0.9),
}

var collection_mgr: Node
var grid: GridContainer
var stats_label: Label
var filter_current := "all"
var detail_panel: Panel
var detail_item_id := ""

# Gacha UI
var gacha_overlay: ColorRect
var gacha_grid: GridContainer

func _ready():
	collection_mgr = get_node_or_null("/root/CollectionManager")
	if not collection_mgr:
		push_error("[CollectionPanel] CollectionManager not found!")
		return
	_build_ui()
	_refresh_grid()

func _build_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(_on_bg_click)
	add_child(bg)
	
	# Main panel
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30; panel.offset_right = -30
	panel.offset_top = 60; panel.offset_bottom = -40
	var ps = StyleBoxFlat.new()
	ps.bg_color = COL_BG
	ps.set_border_width_all(2)
	ps.border_color = Color(0.46, 0.37, 0.28, 0.65)
	ps.set_corner_radius_all(20)
	ps.shadow_color = Color(0.1, 0.08, 0.05, 0.3)
	ps.shadow_size = 12
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)
	
	# Main VBox
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16; vbox.offset_right = -16
	vbox.offset_top = 16; vbox.offset_bottom = -16
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# Title bar
	var title_bar = HBoxContainer.new()
	vbox.add_child(title_bar)
	
	var title = Label.new()
	title.text = "🍖 食物收藏阁"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COL_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_on_close)
	title_bar.add_child(close_btn)
	
	# Stats
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(stats_label)
	
	# Filter row
	var filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	vbox.add_child(filter_row)
	
	for filter_id in ["all", "owned", "common", "uncommon", "rare", "epic", "legendary"]:
		var names = {"all": "全部", "owned": "已收集", "common": "普通", "uncommon": "优秀", "rare": "稀有", "epic": "史诗", "legendary": "传说"}
		var btn = Button.new()
		btn.text = names[filter_id]
		btn.add_theme_font_size_override("font_size", 12)
		btn.custom_minimum_size = Vector2(48, 28)
		btn.pressed.connect(_set_filter.bind(filter_id))
		filter_row.add_child(btn)
	
	# Tab container with two tabs: Collection + Gacha
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 16)
	vbox.add_child(tabs)
	
	# --- Collection tab ---
	var collection_scroll = ScrollContainer.new()
	collection_scroll.name = "📚 图鉴"
	collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(collection_scroll)
	
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_scroll.add_child(grid)
	
	# --- Gacha tab ---
	var gacha_scroll = ScrollContainer.new()
	gacha_scroll.name = "🎰 抽奖"
	gacha_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(gacha_scroll)
	
	var gacha_vbox = VBoxContainer.new()
	gacha_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gacha_vbox.add_theme_constant_override("separation", 16)
	gacha_scroll.add_child(gacha_vbox)
	
	var gacha_title = Label.new()
	gacha_title.text = "每个宝箱抽取10张图鉴\n重复图鉴自动转化为碎片"
	gacha_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gacha_title.add_theme_font_size_override("font_size", 14)
	gacha_title.add_theme_color_override("font_color", COL_TEXT_DIM)
	gacha_vbox.add_child(gacha_title)
	
	var chest_row = HBoxContainer.new()
	chest_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chest_row.add_theme_constant_override("separation", 12)
	gacha_vbox.add_child(chest_row)
	
	_create_chest_button(chest_row, "bronze", "🟤 铜宝箱", 100, "普通60% 优秀25%\n稀有10% 史诗4% 传说1%")
	_create_chest_button(chest_row, "silver", "⚪ 银宝箱", 500, "普通30% 优秀35%\n稀有20% 史诗10% 传说5%")
	_create_chest_button(chest_row, "gold", "🟡 金宝箱", 2000, "普通10% 优秀20%\n稀有30% 史诗25% 传说15%")
	
	# Gacha result area
	gacha_grid = GridContainer.new()
	gacha_grid.columns = 5
	gacha_grid.add_theme_constant_override("h_separation", 6)
	gacha_grid.add_theme_constant_override("v_separation", 6)
	gacha_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gacha_vbox.add_child(gacha_grid)
	
	# Detail overlay (hidden)
	_build_detail_panel()
	
	# Gacha animation overlay (hidden)
	gacha_overlay = ColorRect.new()
	gacha_overlay.color = Color(0, 0, 0, 0.85)
	gacha_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gacha_overlay.visible = false
	gacha_overlay.gui_input.connect(func(e): 
		if e is InputEventMouseButton and e.pressed:
			gacha_overlay.visible = false
	)
	add_child(gacha_overlay)

func _create_chest_button(parent: HBoxContainer, tier: String, label: String, cost: int, rates: String):
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.custom_minimum_size = Vector2(140, 0)
	parent.add_child(vbox)
	
	var btn = Button.new()
	btn.text = label + "\n🪙 " + str(cost)
	btn.custom_minimum_size = Vector2(130, 80)
	btn.add_theme_font_size_override("font_size", 16)
	
	var tier_colors = {"bronze": Color(0.80, 0.50, 0.20, 0.3), "silver": Color(0.75, 0.75, 0.75, 0.3), "gold": Color(1.0, 0.84, 0.0, 0.3)}
	var style = StyleBoxFlat.new()
	style.bg_color = tier_colors.get(tier, COL_CARD)
	style.set_border_width_all(2)
	style.border_color = tier_colors.get(tier, COL_BORDER) * 2.0
	style.border_color.a = 0.7
	style.set_corner_radius_all(14)
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color.a += 0.15
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", COL_TEXT)
	
	btn.pressed.connect(_on_chest_pressed.bind(tier))
	vbox.add_child(btn)
	
	var rate_label = Label.new()
	rate_label.text = rates
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rate_label.add_theme_font_size_override("font_size", 10)
	rate_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(rate_label)

func _build_detail_panel():
	detail_panel = Panel.new()
	detail_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	detail_panel.custom_minimum_size = Vector2(280, 340)
	detail_panel.offset_left = -140; detail_panel.offset_right = 140
	detail_panel.offset_top = -170; detail_panel.offset_bottom = 170
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.18, 0.15, 0.97)
	style.set_border_width_all(2)
	style.border_color = COL_ACCENT
	style.set_corner_radius_all(18)
	style.shadow_size = 16
	style.shadow_color = Color(0, 0, 0, 0.4)
	detail_panel.add_theme_stylebox_override("panel", style)
	detail_panel.visible = false
	add_child(detail_panel)

# ── Grid Rendering ───────────────────────────────────────────────────────

func _refresh_grid():
	if not grid or not collection_mgr:
		return
	
	for child in grid.get_children():
		child.queue_free()
	
	# Sort: owned first, then by rarity desc
	var items: Array = collection_mgr.all_items.values().duplicate()
	items.sort_custom(func(a, b):
		var a_owned = 1 if collection_mgr.is_owned(a.id) else 0
		var b_owned = 1 if collection_mgr.is_owned(b.id) else 0
		if a_owned != b_owned: return a_owned > b_owned
		var ri_a = collection_mgr.RARITY_ORDER.find(a.rarity)
		var ri_b = collection_mgr.RARITY_ORDER.find(b.rarity)
		return ri_a > ri_b
	)
	
	for item in items:
		var owned = collection_mgr.is_owned(item.id)
		
		# Filter
		if filter_current == "owned" and not owned: continue
		if filter_current in collection_mgr.RARITY_ORDER and item.rarity != filter_current: continue
		
		_create_item_card(item, owned)
	
	_update_stats()

func _create_item_card(item: Dictionary, owned: bool):
	var card = Button.new()
	card.custom_minimum_size = Vector2(130, 140)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var bg_color = COL_CARD if owned else COL_CARD_LOCKED
	var border_color = RARITY_BORDER_COLORS.get(item.rarity, COL_BORDER) if owned else Color(0.25, 0.22, 0.18, 0.3)
	
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(2)
	style.border_color = border_color
	style.set_corner_radius_all(14)
	card.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = COL_CARD_HOVER if owned else COL_CARD_LOCKED
	card.add_theme_stylebox_override("hover", hover_style)
	
	# Inner layout
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4; vbox.offset_right = -4
	vbox.offset_top = 6; vbox.offset_bottom = -4
	card.add_child(vbox)
	
	# Rarity tag
	var tag = Label.new()
	tag.text = collection_mgr.RARITY_NAMES.get(item.rarity, "")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", RARITY_BORDER_COLORS.get(item.rarity, COL_TEXT_DIM))
	vbox.add_child(tag)
	
	# Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(56, 56)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists(item.icon_path):
		icon.texture = load(item.icon_path)
	if not owned:
		icon.modulate = Color(0.3, 0.3, 0.3, 0.5)
	vbox.add_child(icon)
	
	# Name
	var name_lbl = Label.new()
	name_lbl.text = item.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", COL_TEXT if owned else COL_TEXT_DIM)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(name_lbl)
	
	# Level info
	if owned:
		var level = collection_mgr.get_level(item.id)
		var frags = collection_mgr.get_fragments(item.id)
		var level_lbl = Label.new()
		level_lbl.text = "⭐".repeat(level) + "  碎片:%d" % frags
		level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_lbl.add_theme_font_size_override("font_size", 9)
		level_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		vbox.add_child(level_lbl)
		card.pressed.connect(_show_detail.bind(item.id))
	else:
		var lock_lbl = Label.new()
		lock_lbl.text = "🔒 未收集"
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_size_override("font_size", 10)
		lock_lbl.add_theme_color_override("font_color", Color(0.4, 0.35, 0.3, 0.5))
		vbox.add_child(lock_lbl)
	
	grid.add_child(card)

func _update_stats():
	if stats_label and collection_mgr:
		var collected = collection_mgr.get_collected_count()
		var total = collection_mgr.get_total_count()
		var total_level := 0
		var total_frags := 0
		for id in collection_mgr.collection:
			total_level += collection_mgr.collection[id].level
			total_frags += collection_mgr.collection[id].fragments
		stats_label.text = "📖 %d/%d 已收集  ⭐ 总等级:%d  🧩 碎片:%d" % [collected, total, total_level, total_frags]

# ── Detail View ──────────────────────────────────────────────────────────

func _show_detail(item_id: String):
	_play_click()
	detail_item_id = item_id
	var item = collection_mgr.get_item(item_id)
	if item.is_empty(): return
	
	# Clear and rebuild detail content
	for child in detail_panel.get_children():
		child.queue_free()
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16; vbox.offset_right = -16
	vbox.offset_top = 16; vbox.offset_bottom = -16
	detail_panel.add_child(vbox)
	
	# Close button
	var close = Button.new()
	close.text = "✕"
	close.add_theme_font_size_override("font_size", 18)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func(): detail_panel.visible = false)
	vbox.add_child(close)
	
	# Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(80, 80)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists(item.icon_path):
		icon.texture = load(item.icon_path)
	vbox.add_child(icon)
	
	# Name
	var name_lbl = Label.new()
	name_lbl.text = item.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", COL_TEXT)
	vbox.add_child(name_lbl)
	
	# Rarity
	var rarity_lbl = Label.new()
	rarity_lbl.text = collection_mgr.RARITY_NAMES.get(item.rarity, "")
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 14)
	rarity_lbl.add_theme_color_override("font_color", RARITY_BORDER_COLORS.get(item.rarity, COL_TEXT))
	vbox.add_child(rarity_lbl)
	
	var level = collection_mgr.get_level(item_id)
	var frags = collection_mgr.get_fragments(item_id)
	
	# Level
	var level_lbl = Label.new()
	level_lbl.text = "等级: " + "⭐".repeat(level) + " (Lv.%d/%d)" % [level, collection_mgr.MAX_LEVEL]
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 15)
	level_lbl.add_theme_color_override("font_color", COL_TEXT)
	vbox.add_child(level_lbl)
	
	# Fragments
	var frag_lbl = Label.new()
	if level >= collection_mgr.MAX_LEVEL:
		frag_lbl.text = "碎片: %d (已满级)" % frags
	else:
		var cost = collection_mgr.get_upgrade_cost(level)
		frag_lbl.text = "碎片: %d / %d" % [frags, cost]
	frag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frag_lbl.add_theme_font_size_override("font_size", 13)
	frag_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(frag_lbl)
	
	# Upgrade button
	var upgrade_btn = Button.new()
	if level >= collection_mgr.MAX_LEVEL:
		upgrade_btn.text = "已满级 ✨"
		upgrade_btn.disabled = true
	else:
		var cost = collection_mgr.get_upgrade_cost(level)
		upgrade_btn.text = "升级 (需要%d碎片)" % cost
		upgrade_btn.disabled = frags < cost
	upgrade_btn.custom_minimum_size = Vector2(200, 40)
	upgrade_btn.add_theme_font_size_override("font_size", 15)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COL_ACCENT_GREEN if not upgrade_btn.disabled else Color(0.4, 0.35, 0.3, 0.5)
	btn_style.set_corner_radius_all(12)
	upgrade_btn.add_theme_stylebox_override("normal", btn_style)
	upgrade_btn.add_theme_color_override("font_color", COL_TEXT)
	upgrade_btn.pressed.connect(_on_upgrade.bind(item_id))
	vbox.add_child(upgrade_btn)
	
	detail_panel.visible = true

func _on_upgrade(item_id: String):
	_play_click()
	if collection_mgr.upgrade_item(item_id):
		_show_detail(item_id)  # Refresh detail
		_refresh_grid()

# ── Gacha ────────────────────────────────────────────────────────────────

func _on_chest_pressed(tier: String):
	_play_click()
	var results = collection_mgr.open_chest(tier)
	if results.is_empty():
		# Not enough gold - show toast via HUD
		return
	_show_gacha_results(results)
	_refresh_grid()

func _show_gacha_results(results: Array):
	for child in gacha_grid.get_children():
		child.queue_free()
	
	for result in results:
		var item = collection_mgr.get_item(result.id)
		if item.is_empty(): continue
		
		var card = Panel.new()
		card.custom_minimum_size = Vector2(100, 110)
		var style = StyleBoxFlat.new()
		style.bg_color = COL_CARD
		style.set_border_width_all(2)
		style.border_color = RARITY_BORDER_COLORS.get(result.rarity, COL_BORDER)
		style.set_corner_radius_all(10)
		card.add_theme_stylebox_override("panel", style)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.offset_left = 4; vbox.offset_right = -4
		vbox.offset_top = 4; vbox.offset_bottom = -4
		card.add_child(vbox)
		
		var icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if ResourceLoader.exists(item.icon_path):
			icon.texture = load(item.icon_path)
		vbox.add_child(icon)
		
		var name_lbl = Label.new()
		name_lbl.text = result.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", COL_TEXT)
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(name_lbl)
		
		if result.is_dupe:
			var dupe_lbl = Label.new()
			dupe_lbl.text = "+%d碎片" % collection_mgr.FRAGMENTS_PER_DUPE
			dupe_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dupe_lbl.add_theme_font_size_override("font_size", 9)
			dupe_lbl.add_theme_color_override("font_color", Color(0.94, 0.27, 0.27))
			vbox.add_child(dupe_lbl)
		else:
			var new_lbl = Label.new()
			new_lbl.text = "✨ 新!"
			new_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			new_lbl.add_theme_font_size_override("font_size", 10)
			new_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			vbox.add_child(new_lbl)
		
		gacha_grid.add_child(card)

# ── Filters ──────────────────────────────────────────────────────────────

func _set_filter(filter: String):
	_play_click()
	filter_current = filter
	_refresh_grid()

# ── Helpers ──────────────────────────────────────────────────────────────

func _play_click():
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx_path("res://assets/audio/sfx/ui/ui_click.mp3", 0.8)

func _on_close():
	_play_click()
	collection_closed.emit()
	queue_free()

func _on_bg_click(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_on_close()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if detail_panel.visible:
			detail_panel.visible = false
		else:
			_on_close()
