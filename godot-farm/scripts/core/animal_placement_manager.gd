extends Node

## Animal Placement Manager - Handles placing/recalling animals on the farm
## Autoload singleton: AnimalPlacementManager

signal placement_started(animal_id: String)
signal placement_cancelled
signal animal_placed(animal_id: String, instance_id: String, position: Vector2)
signal animal_recalled(animal_id: String, instance_id: String)

# Placement mode state
var is_placing: bool = false
var _placing_animal_id: String = ""
var _ghost_node: Node2D = null
var _placement_label: Label = null

# Placed animal tracking: instance_id -> {animal_id, node, position}
var placed_animals: Dictionary = {}

# Animal type list (for identifying animals in inventory)
const ANIMAL_IDS := ["cow", "pig", "sheep", "zebra", "shiba", "koala", "cat", "capybara", "alpaca"]

func _ready():
	print("[AnimalPlacementManager] Initialized")

func is_animal_item(item_id: String) -> bool:
	return item_id in ANIMAL_IDS

## Start placement mode for an animal from inventory
func start_placement(animal_id: String) -> bool:
	var state = get_node_or_null("/root/StateManager")
	if not state:
		return false
	var inv = state.get_inventory()
	if inv.get(animal_id, 0) <= 0:
		print("[AnimalPlacementManager] No %s in inventory" % animal_id)
		return false

	# Remove from inventory immediately (will add back if cancelled)
	var success = state.apply_action({"type": "remove_item", "item_id": animal_id, "amount": 1})
	if not success:
		return false

	is_placing = true
	_placing_animal_id = animal_id
	_create_ghost(animal_id)
	placement_started.emit(animal_id)
	print("[AnimalPlacementManager] Placement mode started for %s" % animal_id)
	return true

## Cancel placement mode - return animal to inventory
func cancel_placement():
	if not is_placing:
		return
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.apply_action({"type": "add_item", "item_id": _placing_animal_id, "amount": 1})
	_cleanup_ghost()
	is_placing = false
	_placing_animal_id = ""
	placement_cancelled.emit()
	print("[AnimalPlacementManager] Placement cancelled")

## Confirm placement at world position
func confirm_placement(world_pos: Vector2):
	if not is_placing:
		return

	var animal_id = _placing_animal_id
	_cleanup_ghost()
	is_placing = false
	_placing_animal_id = ""

	# Generate unique instance id
	var instance_id = _generate_instance_id()

	# Spawn the actual animal on the farm
	var node = _spawn_animal_at(animal_id, world_pos, instance_id)
	if node:
		placed_animals[instance_id] = {
			"animal_id": animal_id,
			"node": node,
			"position_x": world_pos.x,
			"position_y": world_pos.y,
		}
		animal_placed.emit(animal_id, instance_id, world_pos)
		print("[AnimalPlacementManager] Placed %s at %s (instance: %s)" % [animal_id, str(world_pos), instance_id])

		# Save to Supabase
		_save_placed_animals()

## Recall animal back to inventory
func recall_animal(instance_id: String):
	if not placed_animals.has(instance_id):
		print("[AnimalPlacementManager] Instance %s not found" % instance_id)
		return

	var data = placed_animals[instance_id]
	var animal_id = data.animal_id
	var node = data.node

	# Remove from scene
	if is_instance_valid(node):
		node.queue_free()

	placed_animals.erase(instance_id)

	# Add back to inventory
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.apply_action({"type": "add_item", "item_id": animal_id, "amount": 1})

	animal_recalled.emit(animal_id, instance_id)
	print("[AnimalPlacementManager] Recalled %s (instance: %s)" % [animal_id, instance_id])

	# Save to Supabase
	_save_placed_animals()

## Restore placed animals from Supabase data (called on login)
func restore_animals(animals_data: Array):
	# Clear any existing placed animals first
	for instance_id in placed_animals.keys():
		var data = placed_animals[instance_id]
		if is_instance_valid(data.node):
			data.node.queue_free()
	placed_animals.clear()

	for item in animals_data:
		var animal_id = item.get("animal_type", "")
		var pos_x = float(item.get("position_x", 0))
		var pos_y = float(item.get("position_y", 0))
		var db_id = str(item.get("id", ""))

		if animal_id.is_empty():
			continue

		# Use the database UUID as instance_id for consistency
		var instance_id = db_id if not db_id.is_empty() else _generate_instance_id()

		var node = _spawn_animal_at(animal_id, Vector2(pos_x, pos_y), instance_id)
		if node:
			placed_animals[instance_id] = {
				"animal_id": animal_id,
				"node": node,
				"position_x": pos_x,
				"position_y": pos_y,
			}
			print("[AnimalPlacementManager] Restored %s at (%d, %d)" % [animal_id, int(pos_x), int(pos_y)])

	print("[AnimalPlacementManager] Restored %d animals" % placed_animals.size())

## Get serialized data for Supabase save
func get_animals_for_save() -> Array:
	var result = []
	for instance_id in placed_animals.keys():
		var data = placed_animals[instance_id]
		var node = data.node
		# Use current node position (animal may have walked)
		var pos = node.position if is_instance_valid(node) else Vector2(data.position_x, data.position_y)
		result.append({
			"animal_type": data.animal_id,
			"position_x": pos.x,
			"position_y": pos.y,
		})
	return result

## Input handling for placement mode
func _input(event):
	if not is_placing:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Convert screen click to world position
			var world_pos = _screen_to_world(event.position)
			confirm_placement(world_pos)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
			get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			cancel_placement()
			get_viewport().set_input_as_handled()

func _process(_delta):
	if is_placing and _ghost_node and is_instance_valid(_ghost_node):
		var mouse_screen = get_viewport().get_mouse_position()
		var world_pos = _screen_to_world(mouse_screen)
		_ghost_node.position = world_pos

## Internal helpers

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var viewport = get_viewport()
	var camera = viewport.get_camera_2d()
	if camera:
		return camera.get_canvas_transform().affine_inverse() * screen_pos
	return screen_pos

func _generate_instance_id() -> String:
	return "animal_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]

func _get_animals_container() -> Node:
	var main = get_node_or_null("/root/Main")
	if not main:
		return null
	var farm = main.get("farm")
	if not farm:
		return null
	var animals = farm.get_node_or_null("Animals")
	if not animals:
		# Create it
		animals = Node2D.new()
		animals.name = "Animals"
		farm.add_child(animals)
	return animals

func _spawn_animal_at(animal_id: String, world_pos: Vector2, instance_id: String) -> Node2D:
	var container = _get_animals_container()
	if not container:
		push_error("[AnimalPlacementManager] No Animals container found")
		return null

	# Load animal scene
	var animal_scene = load("res://scenes/characters/alpaca.tscn")
	if not animal_scene:
		push_error("[AnimalPlacementManager] Failed to load animal scene")
		return null

	var animal = animal_scene.instantiate()
	animal.name = "Placed_%s_%s" % [animal_id, instance_id.substr(0, 8)]
	animal.position = world_pos
	animal.animal_name = animal_id
	animal.use_separate_frames = true
	animal.walk_speed = randf_range(20, 35)
	animal.scale_factor = randf_range(0.7, 0.9)

	# Store instance_id on the node for recall
	animal.set_meta("instance_id", instance_id)
	animal.set_meta("is_placed", true)

	container.add_child(animal)
	return animal

func _create_ghost(animal_id: String):
	_cleanup_ghost()

	# Create a simple ghost indicator that follows the mouse
	_ghost_node = Node2D.new()
	_ghost_node.name = "PlacementGhost"
	_ghost_node.z_index = 100
	_ghost_node.modulate = Color(1, 1, 1, 0.5)

	# Try to load icon for ghost
	var tex: Texture2D = null
	for path in [
		"res://assets/characters/%s/idle/%s_idle_01.png" % [animal_id, animal_id],
		"res://assets/characters/%s/idle/idle_01.png" % [animal_id],
		"res://assets/characters/%s/idle/%s_idle_0.png" % [animal_id, animal_id],
		"res://assets/characters/%s/idle/idle_0.png" % [animal_id],
	]:
		if ResourceLoader.exists(path):
			tex = load(path)
			break

	if tex:
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.scale = Vector2(0.8, 0.8)
		_ghost_node.add_child(sprite)

	# Add hint label
	_placement_label = Label.new()
	_placement_label.text = "点击地图放置动物\n右键/ESC取消"
	_placement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placement_label.position = Vector2(-80, -120)
	_placement_label.add_theme_font_size_override("font_size", 18)
	_placement_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_placement_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_placement_label.add_theme_constant_override("outline_size", 4)
	_ghost_node.add_child(_placement_label)

	# Add ghost to the farm scene (world space, not UI)
	var container = _get_animals_container()
	if container:
		container.add_child(_ghost_node)
	else:
		# Fallback: add to root
		get_tree().current_scene.add_child(_ghost_node)

func _cleanup_ghost():
	if _ghost_node and is_instance_valid(_ghost_node):
		_ghost_node.queue_free()
	_ghost_node = null
	_placement_label = null

func _save_placed_animals():
	var supabase = get_node_or_null("/root/SupabaseManager")
	var main = get_node_or_null("/root/Main")
	if not supabase or not main:
		return
	var user_id = main.current_user_id
	if user_id.is_empty():
		return
	var animals_data = get_animals_for_save()
	supabase.save_farm_animals(user_id, animals_data)
