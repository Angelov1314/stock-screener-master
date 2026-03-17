extends CanvasLayer

## Settings Panel UI
## Controls: master/bgm/sfx volume sliders, screen shake toggle, language switch

signal panel_closed

@onready var master_slider: HSlider = %MasterSlider
@onready var bgm_slider: HSlider = %BGMSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var master_label: Label = %MasterValueLabel
@onready var bgm_label: Label = %BGMValueLabel
@onready var sfx_label: Label = %SFXValueLabel
@onready var shake_toggle: CheckButton = %ShakeToggle
@onready var lang_button: Button = %LangButton
@onready var close_button: TextureButton = %CloseButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var panel_bg: Panel = %PanelBG

var settings_mgr: Node = null

func _ready():
	settings_mgr = get_node_or_null("/root/SettingsManager")
	if not settings_mgr:
		push_error("[SettingsPanel] SettingsManager not found!")
		return
	
	# Initialize slider values from current settings
	master_slider.value = settings_mgr.master_volume
	bgm_slider.value = settings_mgr.bgm_volume
	sfx_slider.value = settings_mgr.sfx_volume
	shake_toggle.button_pressed = settings_mgr.screen_shake
	_update_lang_button()
	_update_value_labels()
	
	# Connect signals
	master_slider.value_changed.connect(_on_master_changed)
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	shake_toggle.toggled.connect(_on_shake_toggled)
	lang_button.pressed.connect(_on_lang_pressed)
	close_button.pressed.connect(_on_close)
	main_menu_button.pressed.connect(_on_main_menu)
	
	# Animate in
	var bg = get_node_or_null("DimOverlay")
	if bg:
		bg.modulate.a = 0
		var tw = create_tween()
		tw.tween_property(bg, "modulate:a", 1.0, 0.2)

func _on_master_changed(val: float):
	settings_mgr.set_master_volume(val)
	_update_value_labels()

func _on_bgm_changed(val: float):
	settings_mgr.set_bgm_volume(val)
	_update_value_labels()

func _on_sfx_changed(val: float):
	settings_mgr.set_sfx_volume(val)
	_update_value_labels()

func _on_shake_toggled(pressed: bool):
	settings_mgr.set_screen_shake(pressed)

func _on_lang_pressed():
	var new_lang = "en" if settings_mgr.language == "zh" else "zh"
	settings_mgr.set_language(new_lang)
	_update_lang_button()

func _update_lang_button():
	if not settings_mgr:
		return
	lang_button.text = "English" if settings_mgr.language == "zh" else "中文"
	# Show what it will switch TO

func _update_value_labels():
	if master_label:
		master_label.text = "%d%%" % int(master_slider.value * 100)
	if bgm_label:
		bgm_label.text = "%d%%" % int(bgm_slider.value * 100)
	if sfx_label:
		sfx_label.text = "%d%%" % int(sfx_slider.value * 100)

func _on_close():
	# Save settings on close
	if settings_mgr:
		settings_mgr.save_to_supabase()
	panel_closed.emit()
	queue_free()

func _on_main_menu():
	# Save settings then go to main menu
	if settings_mgr:
		settings_mgr.save_to_supabase()
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")

func _input(event):
	# Close on ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close()
		get_viewport().set_input_as_handled()
