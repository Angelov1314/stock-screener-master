extends Node

## Manages all game audio: music and SFX
## Uses audio buses: Master, Music, SFX

signal music_changed(track_name: String)
signal volume_changed(bus: String, volume: float)

# Audio bus names
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

# Music player
var _music_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 8

# Settings
var music_volume: float = 0.8:
	set(val):
		music_volume = clampf(val, 0.0, 1.0)
		_apply_bus_volume(BUS_MUSIC, music_volume)
		emit_signal("volume_changed", BUS_MUSIC, music_volume)

var sfx_volume: float = 1.0:
	set(val):
		sfx_volume = clampf(val, 0.0, 1.0)
		_apply_bus_volume(BUS_SFX, sfx_volume)
		emit_signal("volume_changed", BUS_SFX, sfx_volume)

var music_enabled: bool = true
var sfx_enabled: bool = true

# Current track
var _current_track: String = ""

func _ready():
	print("[AudioManager] Initialized")
	
	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC if AudioServer.get_bus_index(BUS_MUSIC) >= 0 else BUS_MASTER
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	
	# Create SFX player pool
	for i in MAX_SFX_PLAYERS:
		var player = AudioStreamPlayer.new()
		player.bus = BUS_SFX if AudioServer.get_bus_index(BUS_SFX) >= 0 else BUS_MASTER
		add_child(player)
		_sfx_players.append(player)
	
	# Apply initial volumes
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	
	# Start background music
	play_background_music()

## Play the default background music
func play_background_music() -> void:
	var music_path = "res://assets/audio/music/background_music.mp3"
	if ResourceLoader.exists(music_path):
		var stream = load(music_path) as AudioStream
		if stream:
			print("[AudioManager] Playing background music: " + music_path)
			play_music(stream, 2.0)
	else:
		push_warning("[AudioManager] Background music not found: " + music_path)

## Play background music
func play_music(stream: AudioStream, fade_in: float = 1.0) -> void:
	if not music_enabled or stream == null:
		return
	
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player.play()
	_current_track = stream.resource_path.get_file()
	emit_signal("music_changed", _current_track)

## Stop music
func stop_music(fade_out: float = 1.0) -> void:
	_music_player.stop()
	_current_track = ""

## Play a sound effect
func play_sfx(stream: AudioStream, volume_scale: float = 1.0) -> void:
	if not sfx_enabled or stream == null:
		return
	
	# Find an available player
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume * volume_scale)
			player.play()
			return
	
	# All busy - steal the first one
	_sfx_players[0].stop()
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = linear_to_db(sfx_volume * volume_scale)
	_sfx_players[0].play()

## Play SFX from path
func play_sfx_path(path: String, volume_scale: float = 1.0) -> void:
	if ResourceLoader.exists(path):
		var stream = load(path) as AudioStream
		if stream:
			play_sfx(stream, volume_scale)

## Toggle music
func toggle_music() -> void:
	music_enabled = !music_enabled
	if not music_enabled:
		_music_player.stop()

## Toggle SFX
func toggle_sfx() -> void:
	sfx_enabled = !sfx_enabled

## Apply volume to audio bus
func _apply_bus_volume(bus_name: String, volume: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(volume))

## Music loop
func _on_music_finished() -> void:
	if music_enabled and _music_player.stream:
		_music_player.play()

## Get save data
func get_save_data() -> Dictionary:
	return {
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"music_enabled": music_enabled,
		"sfx_enabled": sfx_enabled,
	}

## Load save data
func load_save_data(data: Dictionary) -> void:
	music_volume = data.get("music_volume", 0.8)
	sfx_volume = data.get("sfx_volume", 1.0)
	music_enabled = data.get("music_enabled", true)
	sfx_enabled = data.get("sfx_enabled", true)
