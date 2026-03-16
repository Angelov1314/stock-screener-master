extends Node

## Manages user data persistence - gold, level, inventory, etc.

const SAVE_FILE_PATH = "user://user_data.save"

# User data structure
var user_data: Dictionary = {
	"username": "Player",
	"level": 1,
	"experience": 0,
	"gold": 100,  # Initial gold
	"inventory": {},
	"unlocked_crops": ["carrot"],  # Starting crop
	"total_play_time": 0.0,
	"crops_harvested": 0,
	"crops_planted": 0,
	"last_save_time": 0
}

# Seed prices for planting costs
const SEED_PRICES: Dictionary = {
	"carrot": 5,
	"potato": 8,
	"tomato": 12,
	"corn": 15,
	"pumpkin": 20,
	"strawberry": 25
}

signal data_loaded
signal data_saved
signal gold_changed(new_amount: int)
signal level_changed(new_level: int)
signal experience_changed(new_exp: int)

func _ready():
	print("[UserDataManager] Initializing...")
	load_data()
	# Sync initial gold to StateManager and EconomyManager
	_sync_to_managers()

func _sync_to_managers():
	var state_mgr = get_node_or_null("/root/StateManager")
	if state_mgr:
		# Directly set gold variable since there's no setter
		state_mgr.gold = user_data.gold
	
	var eco_mgr = get_node_or_null("/root/EconomyManager")
	if eco_mgr:
		eco_mgr.set_gold(user_data.gold)

## Gold Management
func get_gold() -> int:
	return user_data.gold

func add_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	
	user_data.gold += amount
	user_data.last_save_time = Time.get_unix_time_from_system()
	
	# Sync to other managers
	_sync_to_managers()
	
	gold_changed.emit(user_data.gold)
	print("[UserDataManager] Added %d gold. Total: %d" % [amount, user_data.gold])
	return true

func subtract_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	if user_data.gold < amount:
		print("[UserDataManager] Not enough gold. Have: %d, Need: %d" % [user_data.gold, amount])
		return false
	
	user_data.gold -= amount
	user_data.last_save_time = Time.get_unix_time_from_system()
	
	# Sync to other managers
	_sync_to_managers()
	
	gold_changed.emit(user_data.gold)
	print("[UserDataManager] Subtracted %d gold. Remaining: %d" % [amount, user_data.gold])
	return true

func can_afford(amount: int) -> bool:
	return user_data.gold >= amount

## Seed/Purchase Costs
func get_seed_price(crop_id: String) -> int:
	return SEED_PRICES.get(crop_id, 10)

func can_plant_crop(crop_id: String) -> bool:
	var price = get_seed_price(crop_id)
	return can_afford(price)

func pay_for_planting(crop_id: String) -> bool:
	var price = get_seed_price(crop_id)
	if subtract_gold(price):
		user_data.crops_planted += 1
		return true
	return false

## Experience & Leveling
func add_experience(amount: int):
	if amount <= 0:
		return
	
	user_data.experience += amount
	experience_changed.emit(user_data.experience)
	
	# Check for level up
	var exp_for_next = get_exp_for_next_level()
	while user_data.experience >= exp_for_next:
		user_data.experience -= exp_for_next
		user_data.level += 1
		level_changed.emit(user_data.level)
		print("[UserDataManager] Level up! Now level %d" % user_data.level)
		exp_for_next = get_exp_for_next_level()

func get_exp_for_next_level() -> int:
	# Exp curve: 100 * level
	return 100 * user_data.level

## Inventory Management
func add_to_inventory(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	
	if not user_data.inventory.has(item_id):
		user_data.inventory[item_id] = 0
	
	user_data.inventory[item_id] += quantity
	print("[UserDataManager] Added %d %s to inventory" % [quantity, item_id])
	return true

func remove_from_inventory(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	if not user_data.inventory.has(item_id):
		return false
	if user_data.inventory[item_id] < quantity:
		return false
	
	user_data.inventory[item_id] -= quantity
	if user_data.inventory[item_id] <= 0:
		user_data.inventory.erase(item_id)
	
	print("[UserDataManager] Removed %d %s from inventory" % [quantity, item_id])
	return true

func get_inventory_count(item_id: String) -> int:
	return user_data.inventory.get(item_id, 0)

func get_all_inventory() -> Dictionary:
	return user_data.inventory.duplicate()

## Crop Harvesting
func on_crop_harvested(crop_id: String, quantity: int = 1):
	user_data.crops_harvested += quantity
	add_to_inventory(crop_id, quantity)
	
	# Add experience
	var crop_data = _get_crop_data(crop_id)
	var exp_gain = crop_data.get("exp_value", 10)
	add_experience(exp_gain)
	
	print("[UserDataManager] Harvested %d %s" % [quantity, crop_id])

func _get_crop_data(crop_id: String) -> Dictionary:
	var file_path = "res://data/crops/%s.json" % crop_id
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			return json.data
	return {}

## Save/Load
func save_data() -> bool:
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[UserDataManager] Failed to open save file for writing")
		return false
	
	user_data.last_save_time = Time.get_unix_time_from_system()
	file.store_var(user_data)
	file.close()
	
	data_saved.emit()
	print("[UserDataManager] Data saved to %s" % SAVE_FILE_PATH)
	return true

func load_data() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[UserDataManager] No save file found, using defaults")
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("[UserDataManager] Failed to open save file for reading")
		return false
	
	var loaded_data = file.get_var()
	file.close()
	
	if loaded_data is Dictionary:
		# Merge with defaults to ensure all keys exist
		for key in loaded_data:
			if user_data.has(key):
				user_data[key] = loaded_data[key]
		
		data_loaded.emit()
		print("[UserDataManager] Data loaded. Gold: %d, Level: %d" % [user_data.gold, user_data.level])
		return true
	
	return false

func reset_data():
	user_data = {
		"username": "Player",
		"level": 1,
		"experience": 0,
		"gold": 100,
		"inventory": {},
		"unlocked_crops": ["carrot"],
		"total_play_time": 0.0,
		"crops_harvested": 0,
		"crops_planted": 0,
		"last_save_time": 0
	}
	save_data()
	print("[UserDataManager] Data reset to defaults")

## Auto-save on quit
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_data()
