extends CanvasLayer

## Seed Toolbar - Bottom bar for selecting which crop to plant

signal seed_selected(crop_id: String)

const CROP_IDS = ["carrot", "corn", "strawberry", "tomato", "wheat"]
const CROP_COSTS = {
	"carrot": 5,
	"corn": 15,
	"strawberry": 10,
	"tomato": 12,
	"wheat": 3
}

@onready var selected_indicator: ColorRect = %SelectedIndicator
@onready var buttons: Array[Button] = []

var selected_crop: String = "carrot"

func _ready():
	print("[SeedToolbar] Initializing...")
	
	# Get buttons - paths updated for CanvasLayer structure
	buttons = [
		$HBoxContainer/CarrotButton,
		$HBoxContainer/CornButton,
		$HBoxContainer/StrawberryButton,
		$HBoxContainer/TomatoButton,
		$HBoxContainer/WheatButton
	]
	
	# Connect button signals
	for i in range(buttons.size()):
		var btn = buttons[i]
		var crop_id = CROP_IDS[i]
		btn.pressed.connect(_on_seed_button_pressed.bind(crop_id, i))
	
	# Set initial selection
	_update_selection(0)
	
	print("[SeedToolbar] Ready with %d seeds" % buttons.size())

func _on_seed_button_pressed(crop_id: String, index: int):
	selected_crop = crop_id
	_update_selection(index)
	emit_signal("seed_selected", crop_id)
	print("[SeedToolbar] Selected: %s" % crop_id)

func _update_selection(index: int):
	# Move indicator to selected button position
	var btn = buttons[index]
	# Position relative to HBoxContainer since we're in CanvasLayer
	selected_indicator.position.x = btn.global_position.x
	selected_indicator.size.x = btn.size.x

func get_selected_crop() -> String:
	return selected_crop

func get_crop_cost(crop_id: String) -> int:
	return CROP_COSTS.get(crop_id, 5)
