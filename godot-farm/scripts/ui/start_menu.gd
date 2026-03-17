extends Control

## Start Menu - Level selection and game entry point

const LOADING_SCENE := "res://scenes/loading_screen.tscn"

@onready var selected_label: Label = %SelectedLevelLabel
@onready var cow_icon: Sprite2D = $Decoration/CowIcon

var selected_level: int = 1
var level_configs = {
	1: {"name": "新手农场", "difficulty": "easy", "starting_gold": 100},
	2: {"name": "阳光牧场", "difficulty": "normal", "starting_gold": 80},
	3: {"name": "高山农庄", "difficulty": "hard", "starting_gold": 50}
}

func _ready():
	print("[StartMenu] Level select ready")
	
	# Ensure visible
	modulate.a = 1.0
	visible = true
	
	# Connect level buttons
	$CenterContainer/VBoxContainer/LevelButtons/Level1.pressed.connect(_on_level_selected.bind(1))
	$CenterContainer/VBoxContainer/LevelButtons/Level2.pressed.connect(_on_level_selected.bind(2))
	$CenterContainer/VBoxContainer/LevelButtons/Level3.pressed.connect(_on_level_selected.bind(3))
	
	# Connect start button
	$CenterContainer/VBoxContainer/StartButton.pressed.connect(_on_start_game)
	
	# Connect login button
	$CenterContainer/VBoxContainer/LoginButton.pressed.connect(_on_login_pressed)
	
	# Animate cow icon
	var anim_timer = Timer.new()
	anim_timer.wait_time = 0.125
	anim_timer.timeout.connect(_on_cow_anim)
	add_child(anim_timer)
	anim_timer.start()

func _on_level_selected(level: int):
	selected_level = level
	var config = level_configs[level]
	selected_label.text = "当前选择：关卡 %d - %s" % [level, config.name]
	print("[StartMenu] Level %d selected: %s" % [level, config.name])

func _on_start_game():
	print("[StartMenu] Starting game with level %d..." % selected_level)
	
	# Save selected level to global state for use in main game
	StateManager.set_data("selected_level", selected_level)
	StateManager.set_data("level_config", level_configs[selected_level])
	
	# Fade out
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await fade_tween.finished
	
	# Go to loading screen
	get_tree().change_scene_to_file(LOADING_SCENE)

func _on_login_pressed():
	print("[StartMenu] Opening login panel...")
	var login_scene = load("res://scenes/ui/login_panel.tscn")
	if login_scene:
		var login_panel = login_scene.instantiate()
		add_child(login_panel)
		login_panel.login_successful.connect(_on_login_successful)
		login_panel.panel_closed.connect(func(): login_panel.queue_free())

func _on_login_successful(username: String):
	print("[StartMenu] Login successful: %s" % username)
	# Update UI or show logged-in state
	$CenterContainer/VBoxContainer/LoginButton.text = "已登录: %s" % username

func _on_cow_anim():
	cow_icon.frame = (cow_icon.frame + 1) % cow_icon.hframes
