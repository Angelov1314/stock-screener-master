extends Node

## Collection Manager - Manages food collection (图鉴), gacha, and upgrades
## Autoload singleton

signal collection_changed
signal gacha_completed(results: Array)

# Collection data: { item_id: { level: int, fragments: int } }
var collection: Dictionary = {}

# All food items with rarity assignments
var all_items: Dictionary = {}  # item_id -> { id, name, rarity, icon_path }

const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_NAMES := {
	"common": "普通", "uncommon": "优秀", "rare": "稀有",
	"epic": "史诗", "legendary": "传说"
}
const RARITY_COLORS := {
	"common": Color(0.55, 0.62, 0.76),
	"uncommon": Color(0.31, 0.80, 0.77),
	"rare": Color(0.66, 0.33, 0.97),
	"epic": Color(0.96, 0.62, 0.04),
	"legendary": Color(0.94, 0.27, 0.27)
}

const MAX_LEVEL := 5
const UPGRADE_COSTS := [5, 10, 20, 50]  # fragments for level 1→2, 2→3, 3→4, 4→5
const FRAGMENTS_PER_DUPE := 3
const GACHA_COUNT := 10  # items per chest

const CHEST_CONFIG := {
	"bronze": { "cost": 100, "rates": {"common": 0.60, "uncommon": 0.25, "rare": 0.10, "epic": 0.04, "legendary": 0.01} },
	"silver": { "cost": 500, "rates": {"common": 0.30, "uncommon": 0.35, "rare": 0.20, "epic": 0.10, "legendary": 0.05} },
	"gold":   { "cost": 2000, "rates": {"common": 0.10, "uncommon": 0.20, "rare": 0.30, "epic": 0.25, "legendary": 0.15} },
}

# Food item list
const FOOD_LIST := [
	"apple_juice","apple_pie","bacon_and_eggs","bean_stew","beehive","blue_flowers",
	"blueberries","bread_loaf","brown_mushroom","brown_onion","butter_block","butter_slices",
	"carrot","chicken_wing","chocolate_cake","coffee_mug","corn","cranberries","creamy_soup",
	"dough_bowl_1","dough_bowl_2","dried_herbs","dried_sauces","egg_half","eggplant",
	"flour_sack","fresh_herbs","green_apple","green_bell_pepper","green_salad","ham",
	"hearty_stew_pot","herb_jar","herb_oil","honey","honey_bottle","honeycomb","hot_cocoa",
	"hot_coffee","hot_sauce","jam","ketchup","milk_bottle","mixed_mushrooms","mixed_salad",
	"mushroom_soup","noodle_soup","orange_juice","orange_pie","orange_tomato","pasta_bowl",
	"pickle_jar","pie","pie_crust","plain_spaghetti","potato","potato_bowl","pumpkin_pie",
	"purple_berries","raspberries","red_apple","red_bell_pepper","red_berries","red_flowers",
	"red_mushroom","rice_bowl","sandwich","sliced_bread","spaghetti_bolognese","steak",
	"stew_pot","strawberry","sugar_bag","teacup","teapot","tomato","tomato_soup","wheat",
	"wheat_stalk","white_cheese_wheel","white_onion","wildflowers","wrap_bowl","yeast",
	"yellow_bell_pepper","yellow_cheese_wheel"
]

func _ready():
	_init_items()
	_load_collection()
	
	# Connect to Supabase for remote sync
	var supabase = get_node_or_null("/root/SupabaseManager")
	if supabase:
		if supabase.has_signal("food_collection_loaded"):
			supabase.food_collection_loaded.connect(_on_remote_collection_loaded)
	
	print("[CollectionManager] Initialized with %d items, %d collected" % [all_items.size(), collection.size()])

func _init_items():
	for id in FOOD_LIST:
		var h := _hash_str(id) % 100
		var rarity: String
		if h < 45: rarity = "common"
		elif h < 70: rarity = "uncommon"
		elif h < 85: rarity = "rare"
		elif h < 95: rarity = "epic"
		else: rarity = "legendary"
		
		var display_name: String = id.replace("_", " ").capitalize()
		all_items[id] = {
			"id": id,
			"name": display_name,
			"rarity": rarity,
			"icon_path": "res://assets/ui/food_collection/%s.png" % id,
		}

func _hash_str(s: String) -> int:
	var h := 0
	for i in s.length():
		h = ((h << 5) - h) + s.unicode_at(i)
	return absi(h)

# ── Getters ──────────────────────────────────────────────────────────────

func get_item(id: String) -> Dictionary:
	return all_items.get(id, {})

func is_owned(id: String) -> bool:
	return id in collection

func get_level(id: String) -> int:
	if id in collection:
		return collection[id].level
	return 0

func get_fragments(id: String) -> int:
	if id in collection:
		return collection[id].fragments
	return 0

func get_collected_count() -> int:
	return collection.size()

func get_total_count() -> int:
	return all_items.size()

func get_items_by_rarity(rarity: String) -> Array:
	var result := []
	for item in all_items.values():
		if item.rarity == rarity:
			result.append(item)
	return result

func get_upgrade_cost(current_level: int) -> int:
	if current_level < 1 or current_level >= MAX_LEVEL:
		return -1
	return UPGRADE_COSTS[current_level - 1]

# ── Actions ──────────────────────────────────────────────────────────────

func open_chest(tier: String) -> Array:
	var config = CHEST_CONFIG.get(tier)
	if not config:
		return []
	
	var state = get_node_or_null("/root/StateManager")
	if not state:
		return []
	
	if state.get_gold() < config.cost:
		return []
	
	state.apply_action({"type": "remove_gold", "amount": config.cost})
	
	var results := []
	for i in GACHA_COUNT:
		var rarity := _roll_rarity(config.rates)
		var pool := get_items_by_rarity(rarity)
		if pool.is_empty():
			pool = get_items_by_rarity("common")
		var item: Dictionary = pool[randi() % pool.size()]
		var is_dupe := is_owned(item.id)
		
		if not is_dupe:
			collection[item.id] = {"level": 1, "fragments": 0}
		else:
			collection[item.id].fragments += FRAGMENTS_PER_DUPE
		
		results.append({"id": item.id, "rarity": item.rarity, "name": item.name, "is_dupe": is_dupe})
	
	_save_collection()
	collection_changed.emit()
	gacha_completed.emit(results)
	
	# Play sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx_path("res://assets/audio/sfx/ui/coin_asmr.mp3", 0.85)
	
	return results

func upgrade_item(id: String) -> bool:
	if not is_owned(id):
		return false
	var data = collection[id]
	if data.level >= MAX_LEVEL:
		return false
	var cost: int = UPGRADE_COSTS[data.level - 1]
	if data.fragments < cost:
		return false
	
	data.fragments -= cost
	data.level += 1
	_save_collection()
	collection_changed.emit()
	return true

func _roll_rarity(rates: Dictionary) -> String:
	var r := randf()
	var cum := 0.0
	for rarity in RARITY_ORDER:
		cum += rates.get(rarity, 0.0)
		if r < cum:
			return rarity
	return "common"

# ── Persistence ──────────────────────────────────────────────────────────

func _save_collection():
	# Save to local StateManager
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.set_data("food_collection", collection.duplicate(true))
	
	# Save to Supabase
	_save_to_supabase()

func _save_to_supabase():
	var supabase = get_node_or_null("/root/SupabaseManager")
	if not supabase:
		return
	var user_id = supabase.current_user_id
	if user_id.is_empty():
		return
	supabase.save_food_collection(user_id, collection)

func load_from_supabase():
	"""Call this after login to load remote collection"""
	var supabase = get_node_or_null("/root/SupabaseManager")
	if not supabase:
		return
	var user_id = supabase.current_user_id
	if user_id.is_empty():
		return
	supabase.load_food_collection(user_id)

func _on_remote_collection_loaded(data: Array):
	"""Merge remote collection data"""
	if data.is_empty():
		print("[CollectionManager] No remote collection data")
		return
	
	for item in data:
		var item_id: String = item.get("item_id", "")
		if item_id.is_empty() or item_id not in all_items:
			continue
		var remote_level: int = item.get("level", 1)
		var remote_frags: int = item.get("fragments", 0)
		
		if item_id in collection:
			# Keep whichever is higher
			if remote_level > collection[item_id].level:
				collection[item_id].level = remote_level
			if remote_frags > collection[item_id].fragments:
				collection[item_id].fragments = remote_frags
		else:
			collection[item_id] = {"level": remote_level, "fragments": remote_frags}
	
	# Save merged result locally
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.set_data("food_collection", collection.duplicate(true))
	
	collection_changed.emit()
	print("[CollectionManager] Remote collection merged: %d items" % collection.size())

func _load_collection():
	var state = get_node_or_null("/root/StateManager")
	if state:
		var saved = state.get_data("food_collection", {})
		if saved is Dictionary:
			collection = saved.duplicate(true)
