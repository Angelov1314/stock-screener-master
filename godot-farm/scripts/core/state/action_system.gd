extends Node

## Signals (must be at top of class in GDScript 4.x)
signal gold_changed(new_amount: int)
signal inventory_changed(item_id: String, inventory: Dictionary)
signal crop_planted(coord: Vector2i, crop_id: String)
signal crop_watered(coord: Vector2i)
signal crop_harvested(coord: Vector2i, crop_id: String)

## All state changes MUST go through this system
## NO direct modifications to StateManager allowed

## Action queue for validation
var _pending_actions: Array = []

# Lazy accessor to avoid circular dependency
var _state: Node = null
func _get_state() -> Node:
	if _state == null:
		_state = get_node("/root/StateManager")
	return _state

func execute(action_type: String, params: Dictionary = {}) -> bool:
	var action = _create_action(action_type, params)
	
	# Pre-validation
	if not _validate_preconditions(action):
		print("[ActionSystem] Preconditions failed for: " + action_type)
		return false
	
	# Execute through StateManager
	var success = _get_state().apply_action(action)
	
	if success:
		_on_action_executed(action)
	
	return success

func _create_action(type: String, params: Dictionary) -> Dictionary:
	var action = {"type": type}
	action.merge(params)
	action["timestamp"] = Time.get_unix_time_from_system()
	return action

func _validate_preconditions(action: Dictionary) -> bool:
	var state = _get_state()
	match action.type:
		"remove_gold":
			return state.get_gold() >= action.get("amount", 0)
		"remove_item":
			var inv = state.get_inventory()
			return inv.get(action.get("item_id", ""), 0) >= action.get("amount", 0)
		"harvest_crop":
			var crop = state.get_crop_at(action.get("coord", Vector2i.ZERO))
			# Can only harvest if mature (stage 3)
			return crop.get("growth_stage", 0) >= 3
		_:
			return true

func _on_action_executed(action: Dictionary):
	var state = _get_state()
	# Emit specific signals for UI updates
	match action.type:
		"add_gold", "remove_gold":
			gold_changed.emit(state.get_gold())
		"add_item", "remove_item":
			inventory_changed.emit(action.get("item_id"), state.get_inventory())
		"plant_crop":
			crop_planted.emit(action.coord, action.crop_id)
		"water_crop":
			crop_watered.emit(action.coord)
		"harvest_crop":
			crop_harvested.emit(action.coord, action.get("crop_id", ""))

## Convenience methods
func buy_item(shop_item: Dictionary) -> bool:
	if execute("remove_gold", {"amount": shop_item.price}):
		return execute("add_item", {"item_id": shop_item.item_id, "amount": 1})
	return false

func sell_item(item_id: String, amount: int = 1, price: int = 10) -> bool:
	if execute("remove_item", {"item_id": item_id, "amount": amount}):
		return execute("add_gold", {"amount": price * amount})
	return false

func plant(coord: Vector2i, crop_id: String) -> bool:
	var state = _get_state()
	if state.get_crop_at(coord).is_empty():
		# Get farm controller to calculate proper world position
		var farm_ctrl = get_node_or_null("/root/Main/Farm")
		var world_pos = Vector2.ZERO
		
		if farm_ctrl and farm_ctrl.has_method("get_plot_position_by_coord"):
			world_pos = farm_ctrl.get_plot_position_by_coord(coord)
		else:
			# Fallback: use coord-based position (4x scaled)
			world_pos = Vector2(coord.x * 640 + 500, coord.y * 640 + 500)
		
		# First create the actual crop entity through CropManager
		var crop_mgr = get_node_or_null("/root/CropManager")
		var crop_created = false
		if crop_mgr:
			var planted_id = crop_mgr.plant_crop(crop_id, coord, world_pos)
			crop_created = not planted_id.is_empty()
		
		# Then execute through StateManager (this emits signals)
		if crop_created:
			return execute("plant_crop", {"coord": coord, "crop_id": crop_id})
	return false

func water(coord: Vector2i) -> bool:
	# First water the crop entity through CropManager
	var crop_mgr = get_node_or_null("/root/CropManager")
	if crop_mgr:
		var crop_id = crop_mgr.crop_positions.get(coord, "")
		if crop_id:
			var success = crop_mgr.water_crop(crop_id)
			if success:
				# Then execute through StateManager (this emits signals)
				return execute("water_crop", {"coord": coord})
	return false

func harvest(coord: Vector2i) -> bool:
	var crop_mgr = get_node_or_null("/root/CropManager")
	if not crop_mgr:
		return false
	
	var crop_id = crop_mgr.crop_positions.get(coord, "")
	if not crop_id:
		return false
	
	var crop_entity = crop_mgr.active_crops.get(crop_id, null)
	if not crop_entity or not crop_entity.can_harvest():
		return false
	
	# Harvest through CropManager
	var result = crop_mgr.harvest_crop(crop_id)
	if not result.is_empty():
		# Also update StateManager
		execute("harvest_crop", {"coord": coord, "crop_id": result.crop_id})
		return true
	return false
