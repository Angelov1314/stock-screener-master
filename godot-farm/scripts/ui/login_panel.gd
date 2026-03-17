extends Node

## Login Panel Controller

signal login_successful(username: String)
signal panel_closed

@onready var username_edit: LineEdit = %UsernameEdit
@onready var password_edit: LineEdit = %PasswordEdit
@onready var login_button: Button = %LoginButton
@onready var close_button: Button = %CloseButton

func _ready():
	login_button.pressed.connect(_on_login_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Focus username on start
	if username_edit:
		username_edit.grab_focus()

func _on_login_pressed():
	var username = username_edit.text.strip_edges()
	var password = password_edit.text
	
	if username.is_empty():
		print("[LoginPanel] Username is empty")
		return
	
	print("[LoginPanel] Login attempt: %s" % username)
	
	# TODO: Implement actual authentication here
	# For now, just save the username and emit success
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.apply_action({"type": "set_player_name", "name": username})
	
	login_successful.emit(username)
	_close_panel()

func _on_close_pressed():
	_close_panel()

func _close_panel():
	panel_closed.emit()
	queue_free()

func _input(event):
	# Close on Escape key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_panel()
