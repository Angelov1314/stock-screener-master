extends Node

## Main Game Scene - Coordinates all game components

@onready var level_manager: Node = $LevelManager
@onready var level_container: Node = $LevelContainer
@onready var hud: CanvasLayer = $HUD
@onready var inventory_panel: CanvasLayer = $InventoryPanel
@onready var planting_menu: Control = $PlantingMenu

var farm: Node2D = null

func _ready():
	# Set fullscreen on start
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	print("[Main] Initializing game...")
	
	# Get selected level from StateManager (set by start menu)
	var selected_level = StateManager.get_data("selected_level", 1)
	print("[Main] Loading level %d..." % selected_level)
	
	# Load the appropriate level
	_load_level(selected_level)
	
	# Connect HUD signals
	hud.inventory_requested.connect(_on_inventory_requested)
	hud.shop_requested.connect(_on_shop_requested)
	hud.planting_menu_requested.connect(_on_planting_menu_requested)
	hud.sickle_mode_toggled.connect(_on_sickle_mode_toggled)
	hud.water_mode_toggled.connect(_on_water_mode_toggled)
	
	# Connect inventory panel close
	inventory_panel.panel_closed.connect(_on_inventory_closed)
	
	# Connect planting menu
	planting_menu.crop_selected.connect(_on_seed_selected)
	
	# Hide panels initially
	inventory_panel.visible = false
	planting_menu.visible = false
	
	# Pass initial seed selection to farm
	if farm and farm.has_method("set_selected_crop"):
		farm.set_selected_crop(planting_menu.get_selected_crop())
	
	print("[Main] Game initialized - Level %d loaded" % selected_level)

func _load_level(level_id: int):
	# Stop all current music before switching
	_stop_all_music()
	
	# Handle global AudioManager music
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		if level_id == 2:
			# Stop global music for level 2 (has its own music)
			audio_mgr.stop_music()
			print("[Main] Stopped global music for level 2")
		else:
			# Ensure music is playing for level 1
			audio_mgr.play_background_music()
			print("[Main] Started global music for level 1")
	
	# Clear existing level
	for child in level_container.get_children():
		child.queue_free()
	
	# Load new level
	var level_scene: PackedScene
	match level_id:
		1:
			level_scene = level_manager.level1_scene
		2:
			level_scene = level_manager.level2_scene
		_:
			level_scene = level_manager.level1_scene
	
	if level_scene:
		farm = level_scene.instantiate()
		level_container.add_child(farm)
		print("[Main] Level %d instantiated" % level_id)
	else:
		push_error("[Main] Failed to load level %d scene!" % level_id)

func _on_inventory_requested():
	print("[Main] Opening inventory...")
	inventory_panel.show_panel()

func _on_planting_menu_requested():
	print("[Main] Toggling planting menu...")
	if not planting_menu.is_open():
		# Position menu above the inventory button
		var inventory_btn = hud.get_node("MarginContainer/VBoxContainer/BottomBar/InventoryButton")
		if inventory_btn:
			var btn_pos = inventory_btn.global_position
			planting_menu.position = Vector2(btn_pos.x - 150, btn_pos.y - 110)
	planting_menu.toggle()

func _on_shop_requested():
	print("[Main] Shop requested")

func _on_sickle_mode_toggled(active: bool):
	print("[Main] Sickle mode: %s" % active)
	if farm and farm.has_method("set_sickle_mode"):
		farm.set_sickle_mode(active)

func _on_water_mode_toggled(active: bool):
	print("[Main] Water mode: %s" % active)
	if farm and farm.has_method("set_water_mode"):
		farm.set_water_mode(active)

func _on_inventory_closed():
	print("[Main] Inventory closed")

func _on_seed_selected(crop_id: String):
	print("[Main] Seed selected: %s" % crop_id)
	if farm and farm.has_method("set_selected_crop"):
		farm.set_selected_crop(crop_id)
	# Deactivate tools when selecting seed
	hud.deactivate_tools()
	# Close planting menu
	planting_menu.close()

func _stop_all_music():
	print("[Main] Stopping all music and ambient sounds...")
	
	# Stop all AudioStreamPlayer nodes in the Music group
	var music_players = get_tree().get_nodes_in_group("Music")
	for player in music_players:
		if player is AudioStreamPlayer:
			player.stop()
		# Also stop AmbientAudioManager if it has the method
		if player.has_method("stop_ambient_sounds"):
			player.stop_ambient_sounds()
	
	# Also check current level for any music players
	if farm:
		for child in farm.get_children():
			if child is AudioStreamPlayer:
				child.stop()
			# Check for AmbientAudioManager
			if child.has_method("stop_ambient_sounds"):
				child.stop_ambient_sounds()
			# Check nested children too
			for grandchild in child.get_children():
				if grandchild is AudioStreamPlayer:
					grandchild.stop()
