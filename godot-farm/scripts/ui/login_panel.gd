extends Node

## Login Panel Controller - Supabase Authentication

signal login_successful(username: String, user_id: String)
signal signup_successful(username: String, user_id: String)
signal panel_closed

@onready var username_edit: LineEdit = %UsernameEdit
@onready var password_edit: LineEdit = %PasswordEdit
@onready var email_edit: LineEdit = %EmailEdit
@onready var login_button: Button = %LoginButton
@onready var signup_button: Button = %SignupButton
@onready var close_button: Button = %CloseButton
@onready var status_label: Label = %StatusLabel

var supabase_manager: Node = null

func _ready():
	login_button.pressed.connect(_on_login_pressed)
	signup_button.pressed.connect(_on_signup_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Connect social login buttons
	var google_btn = get_node_or_null("CenterContainer/Panel/VBoxContainer/SocialButtons/GoogleButton")
	var facebook_btn = get_node_or_null("CenterContainer/Panel/VBoxContainer/SocialButtons/FacebookButton")
	if google_btn:
		google_btn.pressed.connect(_on_google_login)
	if facebook_btn:
		facebook_btn.pressed.connect(_on_facebook_login)
	
	# Get SupabaseManager
	supabase_manager = get_node_or_null("/root/SupabaseManager")
	if supabase_manager:
		supabase_manager.login_success.connect(_on_supabase_login_success)
		supabase_manager.login_failed.connect(_on_supabase_login_failed)
		supabase_manager.user_data_loaded.connect(_on_user_data_loaded)
	else:
		print("[LoginPanel] Warning: SupabaseManager not found")
	
	# Focus email on start
	if email_edit:
		email_edit.grab_focus()

func _on_login_pressed():
	var email = email_edit.text.strip_edges()
	var password = password_edit.text
	
	if email.is_empty() or password.is_empty():
		_show_status("请输入邮箱和密码")
		return
	
	_show_status("登录中...")
	
	if supabase_manager:
		supabase_manager.login(email, password)
	else:
		# Fallback to local auth if Supabase not available
		_local_login()

func _on_signup_pressed():
	var email = email_edit.text.strip_edges()
	var password = password_edit.text
	var username = username_edit.text.strip_edges()
	
	if email.is_empty() or password.is_empty() or username.is_empty():
		_show_status("请填写所有字段")
		return
	
	if password.length() < 6:
		_show_status("密码至少需要6个字符")
		return
	
	_show_status("注册中...")
	
	if supabase_manager:
		supabase_manager.signup(email, password, username)
	else:
		_local_login()

func _on_supabase_login_success(user_id: String):
	print("[LoginPanel] Supabase login success: %s" % user_id)
	# Load user data from database
	if supabase_manager:
		supabase_manager.load_user_data(user_id)

func _on_supabase_login_failed(error: String):
	print("[LoginPanel] Supabase login failed: %s" % error)
	_show_status("登录失败: " + error)

func _on_user_data_loaded(user_data: Dictionary):
	print("[LoginPanel] User data loaded: %s" % user_data)
	
	var username = user_data.get("username", "农场主")
	var user_id = user_data.get("user_id", "")
	
	# Save to local state
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.apply_action({"type": "set_player_name", "name": username})
		state.apply_action({"type": "add_gold", "amount": user_data.get("gold", 300) - state.get_gold()})
	
	login_successful.emit(username, user_id)
	_close_panel()

func _local_login():
	# Local fallback without Supabase
	var username = username_edit.text.strip_edges() if username_edit else "农场主"
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.apply_action({"type": "set_player_name", "name": username})
	
	login_successful.emit(username, "local_user")
	_close_panel()

func _show_status(message: String):
	if status_label:
		status_label.text = message

func _on_google_login():
	_show_status("正在打开 Google 登录...")
	if supabase_manager:
		supabase_manager.sign_in_with_google()
	else:
		_show_status("社交登录暂不可用")

func _on_facebook_login():
	_show_status("正在打开 Facebook 登录...")
	if supabase_manager:
		supabase_manager.sign_in_with_facebook()
	else:
		_show_status("社交登录暂不可用")

func _on_close_pressed():
	_close_panel()

func _close_panel():
	panel_closed.emit()
	queue_free()

func _input(event):
	# Close on Escape key
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_panel()
