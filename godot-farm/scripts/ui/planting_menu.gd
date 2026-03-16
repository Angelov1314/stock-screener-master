extends Control

## Planting Menu - Popup menu for selecting seeds

signal crop_selected(crop_id: String)
signal menu_closed

const CROP_IDS = ["carrot", "corn", "tomato", "strawberry", "wheat"]
const CROP_COSTS = {
	"carrot": 5,
	"corn": 15,
	"tomato": 12,
	"strawberry": 10,
	"wheat": 3
}

@onready var selected_indicator: ColorRect = %SelectedIndicator
@onready var buttons: Array[Button] = []

var selected_crop: String = "carrot"
var _is_open: bool = false

func _ready():
	visible = false
	
	# Get buttons
	buttons = [
		$HBoxContainer/CarrotButton,
		$HBoxContainer/CornButton,
		$HBoxContainer/TomatoButton,
		$HBoxContainer/StrawberryButton,
		$HBoxContainer/WheatButton
	]
	
	# Connect signals
	for i in range(buttons.size()):
		var btn = buttons[i]
		var crop_id = CROP_IDS[i]
		btn.pressed.connect(_on_crop_button_pressed.bind(crop_id, i))
	
	_update_selection(0)

func _on_crop_button_pressed(crop_id: String, index: int):
	selected_crop = crop_id
	_update_selection(index)
	emit_signal("crop_selected", crop_id)
	hide()
	emit_signal("menu_closed")

func _update_selection(index: int):
	var btn = buttons[index]
	selected_indicator.position.x = btn.position.x
	selected_indicator.size.x = btn.size.x

func open():
	visible = true
	_is_open = true

func close():
	visible = false
	_is_open = false
	emit_signal("menu_closed")

func toggle():
	if _is_open:
		close()
	else:
		open()

func is_open() -> bool:
	return _is_open

func get_selected_crop() -> String:
	return selected_crop

func get_crop_cost(crop_id: String) -> int:
	return CROP_COSTS.get(crop_id, 5)
