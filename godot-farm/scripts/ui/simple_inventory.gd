extends CanvasLayer

## Simple Inventory UI

@onready var item_grid: GridContainer = $Panel/VBoxContainer/ScrollContainer/ItemGrid
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

signal panel_closed

func _ready():
	close_button.pressed.connect(_on_close)
	_refresh_items()

func _refresh_items():
	# Clear
	for child in item_grid.get_children():
		child.queue_free()
	
	# Get inventory
	var state = get_node_or_null("/root/StateManager")
	if not state:
		return
	
	var inventory = state.get_inventory()
	if inventory.is_empty():
		var label = Label.new()
		label.text = "背包是空的"
		item_grid.add_child(label)
		return
	
	# Show items
	for item_id in inventory.keys():
		var count = inventory[item_id]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.text = item_id + "\nx" + str(count)
		item_grid.add_child(btn)

func _on_close():
	panel_closed.emit()
	queue_free()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close()
