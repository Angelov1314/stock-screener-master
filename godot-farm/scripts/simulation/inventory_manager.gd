extends Node

## Manages player inventory
## Emits signals for UI updates

# Signals
signal inventory_changed(item_id: String, count: int)
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal inventory_full(item_id: String)
signal slot_changed(slot_index: int, item_id: String, count: int)

# Inventory configuration
@export var max_slots: int = 24
@export var max_stack_size: int = 99

# Inventory state: slot_index -> {item_id, count}
var slots: Array[Dictionary] = []

# Quick lookup: item_id -> list of slot indices
var item_slots: Dictionary = {}

# Lazy reference to state manager
var _state_manager: Node = null

func _ready():
	print("[InventoryManager] Initializing...")
	_initialize_slots()

func _get_state_manager() -> Node:
	if _state_manager == null:
		_state_manager = get_node_or_null("/root/StateManager")
	return _state_manager

## Initialize empty slots
func _initialize_slots() -> void:
	slots.clear()
	item_slots.clear()
	for i in range(max_slots):
		slots.append({"item_id": "", "count": 0})

## Get total count of an item
func get_item_count(item_id: String) -> int:
	var total = 0
	if item_slots.has(item_id):
		for slot_idx in item_slots[item_id]:
			total += slots[slot_idx].count
	return total

## Check if we have enough of an item
func has_item(item_id: String, count: int = 1) -> bool:
	return get_item_count(item_id) >= count

## Check if inventory has space for item
func has_space_for(item_id: String, count: int = 1) -> bool:
	# Check existing stacks first
	if item_slots.has(item_id):
		for slot_idx in item_slots[item_id]:
			var slot = slots[slot_idx]
			var space = max_stack_size - slot.count
			if space >= count:
				return true
			count -= space
	
	# Check empty slots
	for i in range(max_slots):
		if slots[i].item_id == "":
			var can_fit = ceili(float(count) / max_stack_size)
			return can_fit <= _get_empty_slot_count()
	
	return false

## Get number of empty slots
func _get_empty_slot_count() -> int:
	var count = 0
	for slot in slots:
		if slot.item_id == "":
			count += 1
	return count

## Add item to inventory
func add_item(item_id: String, count: int = 1) -> bool:
	if count <= 0 or item_id == "":
		return false
	
	var remaining = count
	
	# First, fill existing stacks
	if item_slots.has(item_id):
		for slot_idx in item_slots[item_id]:
			if remaining <= 0:
				break
			
			var slot = slots[slot_idx]
			var space = max_stack_size - slot.count
			var to_add = min(space, remaining)
			
			slot.count += to_add
			remaining -= to_add
			
			emit_signal("slot_changed", slot_idx, item_id, slot.count)
	
	# Then, use empty slots
	while remaining > 0:
		var empty_slot = _find_empty_slot()
		if empty_slot == -1:
			emit_signal("inventory_full", item_id)
			return false
		
		var to_add = min(max_stack_size, remaining)
		slots[empty_slot] = {"item_id": item_id, "count": to_add}
		remaining -= to_add
		
		# Update lookup
		if not item_slots.has(item_id):
			item_slots[item_id] = []
		item_slots[item_id].append(empty_slot)
		
		emit_signal("slot_changed", empty_slot, item_id, to_add)
	
	var total = get_item_count(item_id)
	emit_signal("item_added", item_id, count)
	emit_signal("inventory_changed", item_id, total)
	
	# Sync with StateManager
	_sync_to_state(item_id)
	
	return true

## Remove item from inventory
func remove_item(item_id: String, count: int = 1) -> bool:
	if count <= 0 or item_id == "" or not has_item(item_id, count):
		return false
	
	var remaining = count
	
	if item_slots.has(item_id):
		# Sort indices in reverse to remove from end first
		var indices = item_slots[item_id].duplicate()
		indices.sort()
		indices.reverse()
		
		for slot_idx in indices:
			if remaining <= 0:
				break
			
			var slot = slots[slot_idx]
			var to_remove = min(slot.count, remaining)
			slot.count -= to_remove
			remaining -= to_remove
			
			if slot.count == 0:
				slot.item_id = ""
				item_slots[item_id].erase(slot_idx)
			
			emit_signal("slot_changed", slot_idx, slot.item_id, slot.count)
		
		# Clean up empty lookup
		if item_slots.has(item_id) and item_slots[item_id].is_empty():
			item_slots.erase(item_id)
	
	var total = get_item_count(item_id)
	emit_signal("item_removed", item_id, count)
	emit_signal("inventory_changed", item_id, total)
	
	# Sync with StateManager
	_sync_to_state(item_id)
	
	return true

## Find first empty slot
func _find_empty_slot() -> int:
	for i in range(max_slots):
		if slots[i].item_id == "":
			return i
	return -1

## Get slot info
func get_slot(index: int) -> Dictionary:
	if index >= 0 and index < max_slots:
		return slots[index].duplicate()
	return {}

## Move item between slots
func move_item(from_slot: int, to_slot: int) -> bool:
	if from_slot < 0 or from_slot >= max_slots or to_slot < 0 or to_slot >= max_slots:
		return false
	if from_slot == to_slot:
		return true
	
	var from_data = slots[from_slot]
	var to_data = slots[to_slot]
	
	# If same item, try to merge
	if from_data.item_id == to_data.item_id and from_data.item_id != "":
		var space = max_stack_size - to_data.count
		var to_move = min(space, from_data.count)
		
		slots[to_slot].count += to_move
		slots[from_slot].count -= to_move
		
		if slots[from_slot].count == 0:
			slots[from_slot].item_id = ""
			item_slots[from_data.item_id].erase(from_slot)
		
		emit_signal("slot_changed", from_slot, slots[from_slot].item_id, slots[from_slot].count)
		emit_signal("slot_changed", to_slot, to_data.item_id, slots[to_slot].count)
		return true
	
	# Swap slots
	slots[from_slot] = to_data
	slots[to_slot] = from_data
	
	# Update lookups
	_update_slot_lookup(from_slot)
	_update_slot_lookup(to_slot)
	
	emit_signal("slot_changed", from_slot, to_data.item_id, to_data.count)
	emit_signal("slot_changed", to_slot, from_data.item_id, from_data.count)
	
	return true

## Update item_slots lookup for a slot
func _update_slot_lookup(slot_idx: int) -> void:
	var item_id = slots[slot_idx].item_id
	
	# Remove from old entries
	for id in item_slots.keys():
		item_slots[id].erase(slot_idx)
		if item_slots[id].is_empty():
			item_slots.erase(id)
	
	# Add to new entry
	if item_id != "":
		if not item_slots.has(item_id):
			item_slots[item_id] = []
		if not item_slots[item_id].has(slot_idx):
			item_slots[item_id].append(slot_idx)

## Sync with StateManager
func _sync_to_state(item_id: String) -> void:
	var state = _get_state_manager()
	if state:
		# StateManager tracks total counts, not slots
		var count = get_item_count(item_id)
		# This would need proper action integration
		pass

## Get all items as flat dictionary
func get_all_items() -> Dictionary:
	var items = {}
	for slot in slots:
		if slot.item_id != "":
			items[slot.item_id] = items.get(slot.item_id, 0) + slot.count
	return items

## Clear inventory
func clear() -> void:
	_initialize_slots()
	for i in range(max_slots):
		emit_signal("slot_changed", i, "", 0)

## Save/Load
func get_save_data() -> Dictionary:
	return {
		"slots": slots.duplicate(),
		"max_slots": max_slots,
		"max_stack_size": max_stack_size
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("max_slots"):
		max_slots = data.max_slots
	if data.has("max_stack_size"):
		max_stack_size = data.max_stack_size
	
	_initialize_slots()
	
	if data.has("slots"):
		for i in range(min(data.slots.size(), max_slots)):
			slots[i] = data.slots[i].duplicate()
			_update_slot_lookup(i)
			emit_signal("slot_changed", i, slots[i].item_id, slots[i].count)
