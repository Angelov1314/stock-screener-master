extends Node

## Manages game time, day/night cycle, and seasons
## Emits signals for time-based game events

# Signals - emitted for UI and other systems to react to
signal time_changed(hour: int, minute: int)
signal day_changed(day: int, season: String)
signal season_changed(season: String)
signal time_loaded

# Time configuration
@export var seconds_per_real_second: float = 60.0  # 1 real sec = 1 game minute
@export var day_length_minutes: float = 20.0  # Real-time minutes per game day

# Season configuration
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const DAYS_PER_SEASON: int = 28
const DAYS_PER_YEAR: int = 112  # 28 * 4 seasons

# Current time state
var total_seconds: float = 0.0
var current_day: int = 1
var current_season_index: int = 0
var time_scale: float = 1.0

# Cached values for performance
var _current_hour: int = 6
var _current_minute: int = 0
var _is_paused: bool = false

func _ready():
	print("[TimeManager] Initialized")
	# Start at 6:00 AM on day 1
	set_time(6, 0, 1, 0)

func _process(delta: float):
	if _is_paused:
		return
	
	# Advance game time
	var game_seconds = delta * seconds_per_real_second * time_scale
	advance_time(game_seconds)

## Advance time by game seconds
func advance_time(seconds: float) -> void:
	var old_hour = _current_hour
	var old_day = current_day
	var old_season = get_current_season()
	
	total_seconds += seconds
	
	# Calculate time of day (24 hour cycle)
	var day_seconds = fmod(total_seconds, 86400.0)  # 86400 = 24 * 60 * 60
	_current_hour = int(day_seconds / 3600.0)
	_current_minute = int(fmod(day_seconds, 3600.0) / 60.0)
	
	# Calculate day and season
	var total_days = int(total_seconds / 86400.0) + 1
	if total_days != current_day:
		current_day = total_days
		current_season_index = ((current_day - 1) / DAYS_PER_SEASON) % 4
		
		# Emit day changed signal
		emit_signal("day_changed", current_day, get_current_season())
		
		# Check for season change
		var new_season = get_current_season()
		if new_season != old_season:
			emit_signal("season_changed", new_season)
	
	# Emit time changed if hour or minute changed
	if _current_hour != old_hour or int(fmod(total_seconds - seconds, 3600.0) / 60.0) != _current_minute:
		emit_signal("time_changed", _current_hour, _current_minute)

## Set time directly (for save loading or debugging)
func set_time(hour: int, minute: int, day: int, season_idx: int) -> void:
	current_day = max(1, day)
	current_season_index = wrapi(season_idx, 0, 4)
	_current_hour = clampi(hour, 0, 23)
	_current_minute = clampi(minute, 0, 59)
	
	# Recalculate total seconds
	total_seconds = float((current_day - 1) * 86400 + _current_hour * 3600 + _current_minute * 60)
	
	emit_signal("time_changed", _current_hour, _current_minute)
	emit_signal("day_changed", current_day, get_current_season())

## Pause/unpause time
func set_paused(paused: bool) -> void:
	_is_paused = paused

func is_paused() -> bool:
	return _is_paused

## Get current time
func get_hour() -> int:
	return _current_hour

func get_minute() -> int:
	return _current_minute

func get_formatted_time() -> String:
	return "%02d:%02d" % [_current_hour, _current_minute]

## Season helpers
func get_current_season() -> String:
	return SEASONS[current_season_index]

func get_season_index() -> int:
	return current_season_index

func is_season(season: String) -> bool:
	return get_current_season() == season.to_lower()

## Day helpers
func get_day_of_season() -> int:
	return ((current_day - 1) % DAYS_PER_SEASON) + 1

func get_year() -> int:
	return (current_day - 1) / DAYS_PER_YEAR + 1

## Check if crop can grow in current season
func can_crop_grow(seasons: Array[String]) -> bool:
	return get_current_season() in seasons

## Time scale for speed control
func set_time_scale(scale: float) -> void:
	time_scale = max(0.0, scale)

func get_time_scale() -> float:
	return time_scale

## Save/Load
func get_save_data() -> Dictionary:
	return {
		"total_seconds": total_seconds,
		"current_day": current_day,
		"current_season_index": current_season_index,
		"time_scale": time_scale
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("total_seconds"):
		total_seconds = data.total_seconds
		current_day = data.get("current_day", 1)
		current_season_index = data.get("current_season_index", 0)
		time_scale = data.get("time_scale", 1.0)
		
		# Recalculate derived values
		var day_seconds = fmod(total_seconds, 86400.0)
		_current_hour = int(day_seconds / 3600.0)
		_current_minute = int(fmod(day_seconds, 3600.0) / 60.0)
		
		emit_signal("time_loaded")
		emit_signal("time_changed", _current_hour, _current_minute)
		emit_signal("day_changed", current_day, get_current_season())
