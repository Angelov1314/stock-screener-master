extends Node

## Manages gold/money and economic transactions
## Emits signals for UI updates

# Signals
signal gold_changed(new_amount: int)
signal transaction_made(type: String, amount: int, balance: int)
signal purchase_completed(item_id: String, price: int)
signal sale_completed(item_id: String, price: int, quantity: int)
signal not_enough_gold(needed: int, available: int)
signal daily_income_calculated(amount: int)

# Economy configuration
@export var starting_gold: int = 500
@export var daily_upkeep_cost: int = 0
@export var sell_price_multiplier: float = 1.0
@export var buy_price_multiplier: float = 1.0

# Economy state
var current_gold: int = 0
var lifetime_earned: int = 0
var lifetime_spent: int = 0
var transaction_history: Array[Dictionary] = []
var daily_sales: Dictionary = {}  # day -> {total_sales, items_sold}
var daily_expenses: Dictionary = {}  # day -> total_expenses

# Lazy reference
var _time_manager: Node = null

func _ready():
	print("[EconomyManager] Initializing...")
	current_gold = starting_gold
	
	# Connect to time for daily tracking
	var time_mgr = get_node_or_null("/root/TimeManager")
	if time_mgr:
		time_mgr.day_changed.connect(_on_day_changed)

func _get_time_manager() -> Node:
	if _time_manager == null:
		_time_manager = get_node_or_null("/root/TimeManager")
	return _time_manager

## Get current gold
func get_gold() -> int:
	return current_gold

## Add gold
func add_gold(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	
	current_gold += amount
	lifetime_earned += amount
	
	_log_transaction("add", amount, reason)
	
	emit_signal("gold_changed", current_gold)
	emit_signal("transaction_made", "add", amount, current_gold)

## Remove/Spend gold
func remove_gold(amount: int, reason: String = "") -> bool:
	if amount <= 0:
		return true
	
	if current_gold < amount:
		emit_signal("not_enough_gold", amount, current_gold)
		return false
	
	current_gold -= amount
	lifetime_spent += amount
	
	_log_transaction("remove", amount, reason)
	
	emit_signal("gold_changed", current_gold)
	emit_signal("transaction_made", "remove", amount, current_gold)
	
	return true

## Set gold directly (for debug/save load)
func set_gold(amount: int) -> void:
	current_gold = max(0, amount)
	emit_signal("gold_changed", current_gold)

## Check if can afford
func can_afford(amount: int) -> bool:
	return current_gold >= amount

## Calculate buy price with multiplier
func get_buy_price(base_price: int) -> int:
	return int(base_price * buy_price_multiplier)

## Calculate sell price with multiplier
func get_sell_price(base_price: int) -> int:
	return int(base_price * sell_price_multiplier)

## Buy an item
func buy_item(item_id: String, base_price: int, quantity: int = 1) -> bool:
	var total_cost = get_buy_price(base_price) * quantity
	
	if not remove_gold(total_cost, "buy_%s" % item_id):
		return false
	
	emit_signal("purchase_completed", item_id, total_cost)
	
	# Track daily expense
	_track_expense(total_cost)
	
	return true

## Sell an item
func sell_item(item_id: String, base_price: int, quantity: int = 1) -> void:
	var total_value = get_sell_price(base_price) * quantity
	
	add_gold(total_value, "sell_%s" % item_id)
	
	emit_signal("sale_completed", item_id, total_value, quantity)
	
	# Track daily sales
	_track_sale(item_id, total_value, quantity)

## Harvest and sell crop directly
func sell_crop(harvest_result: Dictionary) -> void:
	if harvest_result.is_empty():
		return
	
	var item_id = harvest_result.get("crop_id", "")
	var sell_price = harvest_result.get("sell_price", 0)
	var quantity = harvest_result.get("quantity", 1)
	var quality = harvest_result.get("quality", 3)
	
	if item_id != "" and sell_price > 0:
		add_gold(sell_price, "harvest_%s" % item_id)
		emit_signal("sale_completed", item_id, sell_price, quantity)
		_track_sale(item_id, sell_price, quantity)

## Log transaction
func _log_transaction(type: String, amount: int, reason: String) -> void:
	var entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"type": type,
		"amount": amount,
		"reason": reason,
		"balance": current_gold
	}
	
	transaction_history.append(entry)
	
	# Keep only last 100 transactions
	if transaction_history.size() > 100:
		transaction_history.pop_front()

## Track daily sales
func _track_sale(item_id: String, amount: int, quantity: int) -> void:
	var time_mgr = _get_time_manager()
	var day = 1
	if time_mgr:
		day = time_mgr.current_day
	
	if not daily_sales.has(day):
		daily_sales[day] = {"total": 0, "items": {}}
	
	daily_sales[day].total += amount
	
	if not daily_sales[day].items.has(item_id):
		daily_sales[day].items[item_id] = {"count": 0, "value": 0}
	
	daily_sales[day].items[item_id].count += quantity
	daily_sales[day].items[item_id].value += amount

## Track daily expenses
func _track_expense(amount: int) -> void:
	var time_mgr = _get_time_manager()
	var day = 1
	if time_mgr:
		day = time_mgr.current_day
	
	daily_expenses[day] = daily_expenses.get(day, 0) + amount

## Get daily income
func get_daily_income(day: int = -1) -> int:
	if day == -1:
		var time_mgr = _get_time_manager()
		if time_mgr:
			day = time_mgr.current_day - 1  # Yesterday
		else:
			day = 1
	
	var sales = daily_sales.get(day, {}).get("total", 0)
	var expenses = daily_expenses.get(day, 0)
	
	return sales - expenses

## Day change handler
func _on_day_changed(day: int, season: String) -> void:
	# Process daily upkeep if any
	if daily_upkeep_cost > 0:
		remove_gold(daily_upkeep_cost, "daily_upkeep")
	
	# Calculate and emit yesterday's income
	var yesterday_income = get_daily_income(day - 1)
	emit_signal("daily_income_calculated", yesterday_income)

## Get lifetime stats
func get_lifetime_stats() -> Dictionary:
	return {
		"earned": lifetime_earned,
		"spent": lifetime_spent,
		"net": lifetime_earned - lifetime_spent,
		"current": current_gold
	}

## Get recent transactions
func get_recent_transactions(count: int = 10) -> Array[Dictionary]:
	var start = max(0, transaction_history.size() - count)
	var result: Array[Dictionary] = []
	for i in range(start, transaction_history.size()):
		result.append(transaction_history[i])
	return result

## Get sales report for a day
func get_sales_report(day: int = -1) -> Dictionary:
	if day == -1:
		var time_mgr = _get_time_manager()
		if time_mgr:
			day = time_mgr.current_day - 1
		else:
			day = 1
	
	return daily_sales.get(day, {"total": 0, "items": {}})

## Sell all items of a type from inventory
func sell_all_from_inventory(item_id: String, base_price: int, inventory_manager: Node) -> int:
	if inventory_manager == null:
		return 0
	
	var count = inventory_manager.get_item_count(item_id)
	if count <= 0:
		return 0
	
	if inventory_manager.remove_item(item_id, count):
		var total = get_sell_price(base_price) * count
		add_gold(total, "bulk_sell_%s" % item_id)
		emit_signal("sale_completed", item_id, total, count)
		_track_sale(item_id, total, count)
		return total
	return 0

## Save/Load
func get_save_data() -> Dictionary:
	return {
		"current_gold": current_gold,
		"lifetime_earned": lifetime_earned,
		"lifetime_spent": lifetime_spent,
		"daily_sales": daily_sales.duplicate(),
		"daily_expenses": daily_expenses.duplicate()
	}

func load_save_data(data: Dictionary) -> void:
	current_gold = data.get("current_gold", starting_gold)
	lifetime_earned = data.get("lifetime_earned", 0)
	lifetime_spent = data.get("lifetime_spent", 0)
	
	if data.has("daily_sales"):
		daily_sales = data.daily_sales.duplicate()
	if data.has("daily_expenses"):
		daily_expenses = data.daily_expenses.duplicate()
	
	emit_signal("gold_changed", current_gold)
