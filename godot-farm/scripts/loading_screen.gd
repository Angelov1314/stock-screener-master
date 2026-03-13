extends Control

## Loading Screen - Shows loading progress then transitions to main game

const MAIN_SCENE := "res://scenes/main.tscn"
const LOADING_DURATION := 3.0  # Shorter since we already had level select

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel
@onready var timer: Timer = %Timer

var selected_level: int = 1

func _ready():
	print("[LoadingScreen] Starting load sequence...")
	
	# Get selected level from state
	selected_level = StateManager.get_data("selected_level", 1)
	print("[LoadingScreen] Loading level %d..." % selected_level)
	
	timer.wait_time = LOADING_DURATION
	timer.one_shot = true
	timer.timeout.connect(_on_loading_complete)
	timer.start()
	
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", 100.0, LOADING_DURATION)

func _process(delta):
	var time_left := timer.time_left
	var progress := ((LOADING_DURATION - time_left) / LOADING_DURATION) * 100.0
	status_label.text = _get_loading_text(progress)

func _get_loading_text(progress: float) -> String:
	var level_config = StateManager.get_data("level_config", {})
	var level_name = level_config.get("name", "农场")
	
	if progress < 30.0:
		return "加载 %s..." % level_name
	elif progress < 60.0:
		return "准备农场..."
	elif progress < 90.0:
		return "播种..."
	else:
		return "马上就好..."

func _on_loading_complete():
	print("[LoadingScreen] Loading complete! Transitioning to main...")
	
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await fade_tween.finished
	
	get_tree().change_scene_to_file(MAIN_SCENE)
