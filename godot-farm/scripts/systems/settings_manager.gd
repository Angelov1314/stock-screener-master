extends Node

## SettingsManager - Global settings singleton
## Manages volume, screen shake, language preferences
## Persists to Supabase via user_data table

signal settings_changed(key: String, value)
signal language_changed(lang: String)

# Default settings
var master_volume: float = 1.0
var bgm_volume: float = 0.8
var sfx_volume: float = 1.0
var screen_shake: bool = true
var language: String = "zh"  # "zh" or "en"

# Track if loaded from remote
var _loaded_from_remote: bool = false

func _ready():
	print("[SettingsManager] Initialized")
	_apply_all()

## Apply all current settings to the engine
func _apply_all():
	_apply_master_volume()
	_apply_bgm_volume()
	_apply_sfx_volume()
	_apply_language()

func _apply_master_volume():
	var idx = AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))
	settings_changed.emit("master_volume", master_volume)

func _apply_bgm_volume():
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.music_volume = bgm_volume
	settings_changed.emit("bgm_volume", bgm_volume)

func _apply_sfx_volume():
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.sfx_volume = sfx_volume
	settings_changed.emit("sfx_volume", sfx_volume)

func _apply_language():
	TranslationServer.set_locale("zh_CN" if language == "zh" else "en")
	language_changed.emit(language)
	settings_changed.emit("language", language)

## Public setters (apply immediately)
func set_master_volume(val: float):
	master_volume = clampf(val, 0.0, 1.0)
	_apply_master_volume()

func set_bgm_volume(val: float):
	bgm_volume = clampf(val, 0.0, 1.0)
	_apply_bgm_volume()

func set_sfx_volume(val: float):
	sfx_volume = clampf(val, 0.0, 1.0)
	_apply_sfx_volume()

func set_screen_shake(val: bool):
	screen_shake = val
	settings_changed.emit("screen_shake", screen_shake)

func set_language(val: String):
	language = val
	_apply_language()

## Serialize for Supabase save
func to_dict() -> Dictionary:
	return {
		"master_volume": master_volume,
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"screen_shake": screen_shake,
		"language": language,
	}

## Load from Supabase data
func from_dict(data: Dictionary):
	master_volume = data.get("master_volume", 1.0)
	bgm_volume = data.get("bgm_volume", 0.8)
	sfx_volume = data.get("sfx_volume", 1.0)
	screen_shake = data.get("screen_shake", true)
	language = data.get("language", "zh")
	_loaded_from_remote = true
	_apply_all()
	print("[SettingsManager] Settings loaded: %s" % to_dict())

## Save settings to Supabase (called externally)
func save_to_supabase():
	var supabase = get_node_or_null("/root/SupabaseManager")
	if not supabase or supabase.access_token.is_empty() or supabase.current_user_id.is_empty():
		print("[SettingsManager] Cannot save - not logged in")
		return
	
	var user_id = supabase.current_user_id
	# We save settings as a JSON string in the settings column of user_data
	var settings_json = JSON.stringify(to_dict())
	
	var data = {
		"user_id": user_id,
		"settings": settings_json,
		"updated_at": Time.get_datetime_string_from_system()
	}
	
	supabase.save_user_data(user_id, data)
	print("[SettingsManager] Saving settings to Supabase")
