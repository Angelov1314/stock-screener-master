extends Node

## Player Progress Manager - Handles XP, Level, and Player Stats

signal xp_changed(current_xp: int, next_level_xp: int)
signal level_up(new_level: int, total_xp: int)
signal player_stats_changed(stats: Dictionary)

# Level configuration
const BASE_XP_REQUIREMENT: int = 100
const XP_MULTIPLIER: float = 1.5
const MAX_LEVEL: int = 50

# XP rewards
const XP_HARVEST_CROP: int = 10
const XP_PLANT_CROP: int = 5
const XP_WATER_CROP: int = 3
const XP_SELL_ITEM: int = 2

# Player state
var current_level: int = 1
var current_xp: int = 0
var total_xp_earned: int = 0
var player_name: String = "农夫"

# Player stats
var stats: Dictionary = {
	"crops_harvested": 0,
	"crops_planted": 0,
	"crops_watered": 0,
	"items_sold": 0,
	"money_earned": 0,
	"play_time": 0  # in seconds
}

# Lazy references
var _state_manager: Node = null
var _economy_manager: Node = null

func _ready():
	print("[PlayerProgress] Initializing...")
	
	# Connect to EconomyManager for tracking
	_economy_manager = get_node_or_null("/root/EconomyManager")
	if _economy_manager:
		_economy_manager.sale_completed.connect(_on_item_sold)
	
	# Connect to CropManager
	var crop_mgr = get_node_or_null("/root/CropManager")
	if crop_mgr:
		crop_mgr.crop_harvested.connect(_on_crop_harvested)
		crop_mgr.crop_planted.connect(_on_crop_planted)
		crop_mgr.crop_watered.connect(_on_crop_watered)

func _process(delta):
	stats.play_time += delta

## Get XP needed for next level
func get_xp_for_next_level() -> int:
	if current_level >= MAX_LEVEL:
		return -1  # Max level
	return int(BASE_XP_REQUIREMENT * pow(XP_MULTIPLIER, current_level - 1))

## Get XP progress as percentage
func get_xp_progress_percent() -> float:
	var next_level_xp = get_xp_for_next_level()
	if next_level_xp < 0:
		return 100.0
	var prev_level_xp = int(BASE_XP_REQUIREMENT * pow(XP_MULTIPLIER, current_level - 2)) if current_level > 1 else 0
	var current_level_xp = current_xp - prev_level_xp
	var level_range = next_level_xp - prev_level_xp
	return (float(current_level_xp) / level_range) * 100.0

## Add XP
func add_xp(amount: int, source: String = "") -> void:
	if amount <= 0:
		return
	
	current_xp += amount
	total_xp_earned += amount
	
	print("[PlayerProgress] Gained %d XP from %s (Total: %d)" % [amount, source, current_xp])
	
	# Check for level up
	_check_level_up()
	
	emit_signal("xp_changed", current_xp, get_xp_for_next_level())

## Check if player leveled up
func _check_level_up() -> void:
	var next_level_xp = get_xp_for_next_level()
	
	while next_level_xp > 0 and current_xp >= next_level_xp and current_level < MAX_LEVEL:
		current_level += 1
		print("[PlayerProgress] LEVEL UP! Now level %d" % current_level)
		emit_signal("level_up", current_level, current_xp)
		next_level_xp = get_xp_for_next_level()
		
		# Could add level-up rewards here (unlock crops, etc.)

## Action XP handlers
func _on_crop_harvested(crop_id: String, crop_type: String, quality: int):
	stats.crops_harvested += 1
	# Bonus XP for higher quality
	var xp_gain = XP_HARVEST_CROP + (quality - 3) * 2
	add_xp(max(xp_gain, 5), "harvest_%s" % crop_type)
	emit_signal("player_stats_changed", stats)

func _on_crop_planted(crop_id: String, crop_type: String, position: Vector2):
	stats.crops_planted += 1
	add_xp(XP_PLANT_CROP, "plant_%s" % crop_type)
	emit_signal("player_stats_changed", stats)

func _on_crop_watered(crop_id: String):
	stats.crops_watered += 1
	add_xp(XP_WATER_CROP, "water_crop")
	emit_signal("player_stats_changed", stats)

func _on_item_sold(item_id: String, price: int, quantity: int):
	stats.items_sold += quantity
	stats.money_earned += price
	add_xp(XP_SELL_ITEM * quantity, "sell_%s" % item_id)
	emit_signal("player_stats_changed", stats)

## Get player title based on level
func get_player_title() -> String:
	match current_level:
		1: return "新手农夫"
		2, 3: return "初级农夫"
		4, 5: return "熟练农夫"
		6, 7, 8: return "资深农夫"
		9, 10: return "农场专家"
		11, 12, 13, 14, 15: return "农场大师"
		_: return "传奇农夫"

## Get unlocks for current level
func get_unlocked_crops() -> Array[String]:
	var crops: Array[String] = ["carrot", "wheat"]  # Always unlocked
	
	if current_level >= 2:
		crops.append("corn")
	if current_level >= 3:
		crops.append("tomato")
	if current_level >= 5:
		crops.append("strawberry")
	
	return crops

## Save/Load
func get_save_data() -> Dictionary:
	return {
		"level": current_level,
		"xp": current_xp,
		"total_xp": total_xp_earned,
		"player_name": player_name,
		"stats": stats.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	current_level = data.get("level", 1)
	current_xp = data.get("xp", 0)
	total_xp_earned = data.get("total_xp", 0)
	player_name = data.get("player_name", "农夫")
	if data.has("stats"):
		stats = data.stats.duplicate()
	
	emit_signal("xp_changed", current_xp, get_xp_for_next_level())
