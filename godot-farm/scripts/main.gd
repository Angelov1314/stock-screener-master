extends Node

## Main Game Scene - Coordinates all game components

@onready var farm: Node2D = $Farm
@onready var hud: CanvasLayer = $HUD
@onready var inventory_panel: CanvasLayer = $InventoryPanel
@onready var seed_toolbar: CanvasLayer = $SeedToolbar

func _ready():
	# Set fullscreen on start
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	print("[Main] Initializing game...")
	
	# Get level config
	var level_config = StateManager.get_data("level_config", {})
	print("[Main] Level: %s" % level_config.get("name", "Unknown"))
	
	# Connect HUD signals
	hud.inventory_requested.connect(_on_inventory_requested)
	hud.shop_requested.connect(_on_shop_requested)
	hud.sickle_mode_toggled.connect(_on_sickle_mode_toggled)
	hud.water_mode_toggled.connect(_on_water_mode_toggled)
	
	# Connect inventory panel close
	inventory_panel.panel_closed.connect(_on_inventory_closed)
	
	# Connect seed toolbar
	seed_toolbar.seed_selected.connect(_on_seed_selected)
	
	# Hide panels initially
	inventory_panel.visible = false
	
	# Pass initial seed selection to farm
	if farm.has_method("set_selected_crop"):
		farm.set_selected_crop(seed_toolbar.get_selected_crop())
	
	print("[Main] Game initialized")

func _on_inventory_requested():
	print("[Main] Opening inventory...")
	inventory_panel.show_panel()

func _on_shop_requested():
	print("[Main] Shop requested")

func _on_sickle_mode_toggled(active: bool):
	print("[Main] Sickle mode: %s" % active)
	if farm.has_method("set_sickle_mode"):
		farm.set_sickle_mode(active)

func _on_water_mode_toggled(active: bool):
	print("[Main] Water mode: %s" % active)
	if farm.has_method("set_water_mode"):
		farm.set_water_mode(active)

func _on_inventory_closed():
	print("[Main] Inventory closed")

func _on_seed_selected(crop_id: String):
	print("[Main] Seed selected: %s" % crop_id)
	if farm.has_method("set_selected_crop"):
		farm.set_selected_crop(crop_id)
	# Deactivate tools when selecting seed
	hud.deactivate_tools()
