extends Node

## Main Game Scene - Coordinates all game components

@onready var level_manager: Node = $LevelManager
@onready var level_container: Node = $LevelContainer
@onready var hud: CanvasLayer = $HUD
@onready var inventory_panel: CanvasLayer = $InventoryPanel
@onready var planting_menu: Control = $PlantingMenu

var farm: Node2D = null

var supabase_manager: Node = null
var current_user_id: String = ""
var _game_initialized: bool = false

func _ready():
	# Set fullscreen on start
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	print("[Main] Initializing game...")
	
	# Get SupabaseManager
	supabase_manager = get_node_or_null("/root/SupabaseManager")
	
	# Check if user is logged in (from start menu)
	current_user_id = StateManager.get_data("current_user_id", "")
	var current_username = StateManager.get_data("current_username", "农场主")
	
	if current_user_id.is_empty():
		print("[Main] No user logged in, using local data")
		# Initialize game immediately for local play
		_initialize_game()
	else:
		print("[Main] User logged in: %s (%s)" % [current_username, current_user_id])
		# Load user data from Supabase first, then initialize
		if supabase_manager:
			# Connect signals BEFORE loading data
			if not supabase_manager.user_data_loaded.is_connected(_on_user_data_loaded):
				supabase_manager.user_data_loaded.connect(_on_user_data_loaded)
				print("[Main] Connected user_data_loaded signal")
			
			# Load user data
			supabase_manager.load_user_data(current_user_id)
			print("[Main] Loading user data from Supabase for user: %s" % current_user_id)
			
			# Set a timeout to initialize game even if data loading fails
			await get_tree().create_timer(5.0).timeout
			if not _game_initialized:
				print("[Main] Data loading timeout, initializing with defaults...")
				_initialize_game()
		else:
			print("[Main] SupabaseManager not found, using local data")
			_initialize_game()

func _initialize_game():
	"""Initialize game after user data is loaded (or for local play)"""
	
	# Prevent double initialization
	if _game_initialized:
		return
	_game_initialized = true
	
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
	hud.home_requested.connect(_on_home_requested)
	hud.iap_requested.connect(_on_iap_requested)
	hud.settings_requested.connect(_on_settings_requested)
	hud.friends_requested.connect(_on_friends_requested)
	hud.community_requested.connect(_on_community_requested)
	
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
	
	# Connect auto-save on state changes
	StateManager.state_changed.connect(_on_state_changed)
	print("[Main] Auto-save enabled")
	
	print("[Main] Game initialized")

func _on_state_changed(action: Dictionary):
	"""Auto-save to Supabase when game state changes"""
	# Only save if user is logged in
	if current_user_id.is_empty() or not supabase_manager:
		return
	
	match action.type:
		"add_gold", "remove_gold":
			_save_user_data()
		"add_experience", "harvest_crop":
			_save_user_data()
			_save_farm_crops()
		"add_item", "remove_item":
			_save_inventory()
		"set_player_name":
			_save_user_data()
		"plant_crop":
			_save_farm_crops()

func _save_user_data():
	"""Save user data to Supabase"""
	var state = get_node_or_null("/root/StateManager")
	if not state:
		return
	
	var settings_mgr = get_node_or_null("/root/SettingsManager")
	var settings_str = ""
	if settings_mgr:
		settings_str = JSON.stringify(settings_mgr.to_dict())
	
	var data = {
		"user_id": current_user_id,
		"username": state.get_player_name(),
		"gold": state.get_gold(),
		"level": state.get_player_level(),
		"xp": state.get_experience(),
		"settings": settings_str
	}
	
	print("[Main] Auto-saving user data...")
	supabase_manager.save_user_data(current_user_id, data)

func _save_farm_crops():
	"""Save all active crops to Supabase"""
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr or not supabase_manager:
		return
	var crops_data = crop_mgr.serialize_crops_for_save()
	print("[Main] Auto-saving farm crops: %d crops" % crops_data.size())
	supabase_manager.save_farm_crops(current_user_id, crops_data)

func _save_farm_animals():
	"""Save placed animals to Supabase"""
	var placement_mgr = get_node_or_null("/root/AnimalPlacementManager")
	if not placement_mgr or not supabase_manager:
		return
	var animals_data = placement_mgr.get_animals_for_save()
	print("[Main] Auto-saving farm animals: %d animals" % animals_data.size())
	supabase_manager.save_farm_animals(current_user_id, animals_data)

func _save_inventory():
	"""Save inventory to Supabase"""
	var state = get_node_or_null("/root/StateManager")
	if not state:
		return
	
	var inventory = state.get_inventory()
	print("[Main] Auto-saving inventory: ", inventory.keys().size(), " items")
	
	# Use batch save for all items at once
	supabase_manager.save_inventory_batch(current_user_id, inventory)

func _on_user_data_loaded(user_data: Dictionary):
	print("[Main] Data loaded from Supabase: %s" % user_data)
	
	# Check if this is inventory data (has item_id) or user data (has gold)
	if user_data.has("item_id"):
		# This is inventory data - add to StateManager
		print("[Main] Processing inventory data: %s x%d" % [user_data.get("item_id"), user_data.get("quantity", 0)])
		var state = get_node_or_null("/root/StateManager")
		if state:
			state.apply_action({
				"type": "add_item",
				"item_id": user_data.get("item_id"),
				"amount": int(user_data.get("quantity", 0))
			})
		return
	
	# This is user data (gold, level, xp)
	var state = get_node_or_null("/root/StateManager")
	if state:
		var username = user_data.get("username", "农场主")
		var remote_gold = user_data.get("gold", 300)
		var remote_level = user_data.get("level", 1)
		var remote_xp = user_data.get("xp", 0)
		
		print("[Main] Processing user data - Gold: %d, Level: %d, XP: %d" % [remote_gold, remote_level, remote_xp])
		
		# Update state
		state.apply_action({"type": "set_player_name", "name": username})
		
		# Reset and set gold
		var current_gold = state.get_gold()
		if current_gold > 0:
			state.apply_action({"type": "remove_gold", "amount": current_gold})
		state.apply_action({"type": "add_gold", "amount": remote_gold})
		
		# IMPORTANT: Apply level and XP to state
		# Store in session data first
		StateManager.set_data("remote_level", remote_level)
		StateManager.set_data("remote_xp", remote_xp)
		
		# Directly set the level and experience in StateManager
		state.player_level = remote_level
		state.experience = remote_xp
		
		print("[Main] Updated local state - Gold: %d, Level: %d, XP: %d" % [remote_gold, remote_level, remote_xp])
		
		# Load settings if present
		var settings_json = user_data.get("settings", "")
		if settings_json is String and not settings_json.is_empty():
			var json = JSON.new()
			if json.parse(settings_json) == OK and json.data is Dictionary:
				var settings_mgr = get_node_or_null("/root/SettingsManager")
				if settings_mgr:
					settings_mgr.from_dict(json.data)
					print("[Main] Settings loaded from Supabase")
	
	# Now initialize the game with loaded data
	_initialize_game()
	
	# After game is initialized, update HUD with correct values
	if state and hud:
		hud._update_gold_display(state.get_gold())
		hud._update_player_name(state.get_player_name())
		var xp_progress = state.get_xp_progress()
		hud._update_player_info(state.get_player_name(), state.get_player_level(), state.get_experience(), state.get_xp_for_next_level(), xp_progress)
	
	# If we used default data (no record in database), save it now
	if not user_data.has("id"):
		print("[Main] No existing user data record, saving default data to database...")
		_save_user_data()
	
	# Load inventory from Supabase after user data is loaded
	if supabase_manager:
		if not supabase_manager.inventory_loaded.is_connected(_on_inventory_loaded):
			supabase_manager.inventory_loaded.connect(_on_inventory_loaded)
		supabase_manager.load_inventory(current_user_id)

	# Load farm crops from Supabase
	if supabase_manager:
		if not supabase_manager.farm_crops_loaded.is_connected(_on_farm_crops_loaded):
			supabase_manager.farm_crops_loaded.connect(_on_farm_crops_loaded)
		supabase_manager.load_farm_crops(current_user_id)

	# Load placed animals from Supabase
	if supabase_manager:
		if not supabase_manager.farm_animals_loaded.is_connected(_on_farm_animals_loaded):
			supabase_manager.farm_animals_loaded.connect(_on_farm_animals_loaded)
		supabase_manager.load_farm_animals(current_user_id)

func _on_inventory_loaded(inventory_data):
	print("[Main] Inventory loaded from Supabase: %s" % [str(inventory_data)])
	
	var state = get_node_or_null("/root/StateManager")
	if not state:
		return
	
	# inventory_data could be an array or a single item
	var items = inventory_data if inventory_data is Array else [inventory_data]
	
	for item in items:
		if item.has("item_id") and item.has("quantity"):
			var item_id = item["item_id"]
			var quantity = int(item["quantity"])
			print("[Main] Adding to inventory: %s x%d" % [item_id, quantity])
			state.apply_action({
				"type": "add_item",
				"item_id": item_id,
				"amount": quantity
			})

func _on_farm_crops_loaded(crops_data: Array):
	print("[Main] Farm crops loaded from Supabase: %d crops" % crops_data.size())
	if crops_data.size() == 0:
		return
	var crop_mgr = get_node_or_null("/root/CropManager")
	if crop_mgr and crop_mgr.has_method("restore_crops_from_data"):
		crop_mgr.restore_crops_from_data(crops_data)

func _on_farm_animals_loaded(animals_data: Array):
	print("[Main] Farm animals loaded from Supabase: %d animals" % animals_data.size())
	var placement_mgr = get_node_or_null("/root/AnimalPlacementManager")
	if placement_mgr:
		placement_mgr.restore_animals(animals_data)

func _load_level(level_id: int):
	# Stop all current music before switching
	_stop_all_music()
	
	# Handle global AudioManager music
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		if level_id in [2, 3]:
			# Stop global music for level 2 and 3 (they have their own music)
			audio_mgr.stop_music()
			print("[Main] Stopped global music for level %d" % level_id)
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
		3:
			level_scene = level_manager.level3_scene
		_:
			level_scene = level_manager.level1_scene
	
	if level_scene:
		farm = level_scene.instantiate()
		level_container.add_child(farm)
		print("[Main] Level %d instantiated" % level_id)
	else:
		push_error("[Main] Failed to load level %d scene!" % level_id)

func _on_inventory_requested():
	print("[Main] Opening simple inventory...")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx_path("res://assets/audio/sfx/ui/paper_open.mp3", 0.9)
	var inv_scene = load("res://scenes/ui/simple_inventory.tscn")
	if inv_scene:
		var inv = inv_scene.instantiate()
		add_child(inv)
		inv.panel_closed.connect(func(): inv.queue_free())

func _on_planting_menu_requested():
	print("[Main] Opening planting menu...")
	var plant_scene = load("res://scenes/ui/planting_menu_new.tscn")
	if plant_scene:
		var menu = plant_scene.instantiate()
		add_child(menu)
		menu.seed_selected.connect(_on_seed_selected)
		menu.menu_closed.connect(func(): menu.queue_free())

func _on_shop_requested():
	print("[Main] Opening shop...")
	_open_shop()

func _open_shop():
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx_path("res://assets/audio/sfx/ui/paper_open.mp3", 0.9)
	var shop_scene = load("res://scenes/ui/shop_ui.tscn")
	if shop_scene:
		var shop = shop_scene.instantiate()
		add_child(shop)
		
		# Connect signals
		shop.shop_closed.connect(_on_shop_closed)
		shop.item_purchased.connect(_on_item_purchased)
		shop.animal_purchased.connect(_on_animal_purchased)
		
		print("[Main] Shop opened")

func _on_shop_closed():
	print("[Main] Shop closed")

func _on_item_purchased(item_id: String, item_type: String):
	print("[Main] Item purchased: %s (%s)" % [item_id, item_type])

func _on_animal_purchased(animal_id: String):
	print("[Main] Animal purchased: %s (added to inventory, use backpack to place)" % animal_id)
	# Animal is already added to inventory by shop_ui.gd via add_item
	# Do NOT spawn on farm directly - user places from inventory

func _add_animal_to_farm(animal_id: String):
	if not farm:
		push_error("[Main] No farm to add animal to!")
		return
	
	# Find Animals container
	var animals_container = farm.get_node_or_null("Animals")
	if not animals_container:
		push_error("[Main] Animals container not found!")
		return
	
	# Load animal scene
	var animal_scene = load("res://scenes/characters/alpaca.tscn")
	if not animal_scene:
		push_error("[Main] Failed to load animal scene!")
		return
	
	# Create animal instance
	var animal = animal_scene.instantiate()
	animal.name = animal_id.capitalize() + str(randi() % 1000)
	
	# Random position within farm bounds
	var random_x = randf_range(500, 6000)
	var random_y = randf_range(500, 10500)
	animal.position = Vector2(random_x, random_y)
	
	# Configure the animal
	animal.animal_name = animal_id
	animal.walk_speed = randf_range(20, 35)
	animal.scale_factor = randf_range(0.7, 0.9)
	
	# Add to scene
	animals_container.add_child(animal)
	
	print("[Main] Added %s to farm at position (%d, %d)" % [animal_id, int(random_x), int(random_y)])

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

func _on_home_requested():
	print("[Main] Returning to start menu...")
	# Save farm crops and animals before leaving
	if not current_user_id.is_empty() and supabase_manager:
		_save_farm_crops()
		_save_farm_animals()
	# Return to level select screen
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")

func _on_settings_requested():
	print("[Main] Opening settings panel...")
	var settings_scene = load("res://scenes/ui/settings_panel.tscn")
	if settings_scene:
		var panel = settings_scene.instantiate()
		add_child(panel)
		panel.panel_closed.connect(func(): pass)

func _on_iap_requested():
	print("[Main] Opening IAP shop...")
	var iap_scene = load("res://scenes/ui/iap_shop.tscn")
	if iap_scene:
		var iap_shop = iap_scene.instantiate()
		add_child(iap_shop)
		iap_shop.shop_closed.connect(func(): iap_shop.queue_free())
		iap_shop.gold_purchased.connect(_on_gold_purchased)

func _on_friends_requested():
	print("[Main] Opening friends panel...")
	var scene = load("res://scenes/ui/friends_panel.tscn")
	if scene:
		var panel = scene.instantiate()
		add_child(panel)
		panel.panel_closed.connect(func(): pass)

func _on_community_requested():
	print("[Main] Opening community panel...")
	var scene = load("res://scenes/ui/community_panel.tscn")
	if scene:
		var panel = scene.instantiate()
		add_child(panel)
		panel.panel_closed.connect(func(): pass)

func _on_gold_purchased(amount: int):
	print("[Main] Gold purchased: %d" % amount)
	# Update HUD gold display
	if hud:
		hud.update_gold(StateManager.get_gold())

func _on_seed_selected(seed_id: String):
	print("[Main] Seed selected: %s" % seed_id)
	if farm and farm.has_method("set_selected_crop"):
		farm.set_selected_crop(seed_id)
	# Deactivate tools when selecting seed
	hud.deactivate_tools()
	# Show toast notification
	hud.show_toast("已选择: %s" % seed_id)

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
