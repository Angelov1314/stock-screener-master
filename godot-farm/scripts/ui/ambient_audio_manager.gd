class_name AmbientAudioManager
extends Node

## Manages ambient background sounds (wind, leaves, birds)
## Randomly plays sounds at intervals for natural feel

@export var wind_player: AudioStreamPlayer
@export var leaves_player: AudioStreamPlayer
@export var birds_player: AudioStreamPlayer

# Sound intervals (seconds)
@export var wind_interval_min: float = 15.0
@export var wind_interval_max: float = 45.0
@export var leaves_interval_min: float = 10.0
@export var leaves_interval_max: float = 30.0
@export var birds_interval_min: float = 5.0
@export var birds_interval_max: float = 20.0

# Volumes (dB)
@export var wind_volume: float = -10.0
@export var leaves_volume: float = -15.0
@export var birds_volume: float = -12.0

var _wind_timer: Timer
var _leaves_timer: Timer
var _birds_timer: Timer
var _rng = RandomNumberGenerator.new()

func _ready():
	_rng.randomize()
	_setup_players()
	_setup_timers()
	start_ambient_sounds()

func _setup_players():
	# Create players if not assigned
	if not wind_player:
		wind_player = AudioStreamPlayer.new()
		wind_player.name = "WindPlayer"
		add_child(wind_player)
	
	if not leaves_player:
		leaves_player = AudioStreamPlayer.new()
		leaves_player.name = "LeavesPlayer"
		add_child(leaves_player)
	
	if not birds_player:
		birds_player = AudioStreamPlayer.new()
		birds_player.name = "BirdsPlayer"
		add_child(birds_player)
	
	# Load audio files
	_load_audio_streams()
	
	# Set volumes
	wind_player.volume_db = wind_volume
	leaves_player.volume_db = leaves_volume
	birds_player.volume_db = birds_volume

func _load_audio_streams():
	var wind_stream = load("res://assets/audio/sfx/ambient/wind.mp3")
	var leaves_stream = load("res://assets/audio/sfx/ambient/leaves_rustle.mp3")
	var birds_stream = load("res://assets/audio/sfx/ambient/birds.mp3")
	
	if wind_stream:
		wind_player.stream = wind_stream
	if leaves_stream:
		leaves_player.stream = leaves_stream
	if birds_stream:
		birds_player.stream = birds_stream

func _setup_timers():
	# Wind timer
	_wind_timer = Timer.new()
	_wind_timer.name = "WindTimer"
	_wind_timer.one_shot = true
	_wind_timer.timeout.connect(_on_wind_timer)
	add_child(_wind_timer)
	
	# Leaves timer
	_leaves_timer = Timer.new()
	_leaves_timer.name = "LeavesTimer"
	_leaves_timer.one_shot = true
	_leaves_timer.timeout.connect(_on_leaves_timer)
	add_child(_leaves_timer)
	
	# Birds timer
	_birds_timer = Timer.new()
	_birds_timer.name = "BirdsTimer"
	_birds_timer.one_shot = true
	_birds_timer.timeout.connect(_on_birds_timer)
	add_child(_birds_timer)

func start_ambient_sounds():
	print("[AmbientAudioManager] Starting ambient sounds")
	_start_wind_timer()
	_start_leaves_timer()
	_start_birds_timer()

func _start_wind_timer():
	var delay = _rng.randf_range(wind_interval_min, wind_interval_max)
	_wind_timer.wait_time = delay
	_wind_timer.start()

func _start_leaves_timer():
	var delay = _rng.randf_range(leaves_interval_min, leaves_interval_max)
	_leaves_timer.wait_time = delay
	_leaves_timer.start()

func _start_birds_timer():
	var delay = _rng.randf_range(birds_interval_min, birds_interval_max)
	_birds_timer.wait_time = delay
	_birds_timer.start()

func _on_wind_timer():
	if wind_player and wind_player.stream:
		wind_player.play()
		print("[AmbientAudioManager] Playing wind")
	_start_wind_timer()

func _on_leaves_timer():
	if leaves_player and leaves_player.stream:
		leaves_player.play()
		print("[AmbientAudioManager] Playing leaves")
	_start_leaves_timer()

func _on_birds_timer():
	if birds_player and birds_player.stream:
		# Randomly play single bird or chorus
		if _rng.randf() < 0.3:
			# Play single bird chirp
			var single_bird = load("res://assets/audio/sfx/ambient/birds_single.mp3")
			if single_bird:
				birds_player.stream = single_bird
		else:
			# Play bird chorus
			var birds_chorus = load("res://assets/audio/sfx/ambient/birds.mp3")
			if birds_chorus:
				birds_player.stream = birds_chorus
		
		birds_player.play()
		print("[AmbientAudioManager] Playing birds")
	_start_birds_timer()

func stop_ambient_sounds():
	print("[AmbientAudioManager] Stopping ambient sounds")
	_wind_timer.stop()
	_leaves_timer.stop()
	_birds_timer.stop()
	
	if wind_player:
		wind_player.stop()
	if leaves_player:
		leaves_player.stop()
	if birds_player:
		birds_player.stop()

func set_paused(paused: bool):
	if paused:
		_wind_timer.paused = true
		_leaves_timer.paused = true
		_birds_timer.paused = true
	else:
		_wind_timer.paused = false
		_leaves_timer.paused = false
		_birds_timer.paused = false
