extends CanvasLayer

## Planting Menu - Seed selection for planting

signal seed_selected(seed_id: String)
signal menu_closed

@onready var seed_grid: GridContainer = $Panel/VBoxContainer/ScrollContainer/SeedGrid
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

var _seeds: Array[Dictionary] = [
	{"id": "carrot", "name": "胡萝卜", "icon": "carrot", "cost": 5},
	{"id": "corn", "name": "玉米", "icon": "corn", "cost": 15},
	{"id": "tomato", "name": "番茄", "icon": "tomato", "cost": 12},
	{"id": "strawberry", "name": "草莓", "icon": "strawberry", "cost": 10},
	{"id": "wheat", "name": "小麦", "icon": "wheat", "cost": 3}
]

func _ready():
	close_button.pressed.connect(_on_close)
	_create_seed_buttons()

func _create_seed_buttons():
	for seed in _seeds:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		btn.text = seed.name + "\n" + str(seed.cost) + "金币"
		
		# Style
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.3, 0.25, 0.2, 0.8)
		normal_style.corner_radius_all = 8
		btn.add_theme_stylebox_override("normal", normal_style)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.4, 0.35, 0.25, 0.9)
		hover_style.corner_radius_all = 8
		btn.add_theme_stylebox_override("hover", hover_style)
		
		btn.pressed.connect(_on_seed_selected.bind(seed.id))
		seed_grid.add_child(btn)

func _on_seed_selected(seed_id: String):
	print("[PlantingMenu] Seed selected: %s" % seed_id)
	seed_selected.emit(seed_id)
	queue_free()

func _on_close():
	menu_closed.emit()
	queue_free()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close()
