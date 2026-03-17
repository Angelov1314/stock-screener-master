extends Node

## Supabase Database Manager - Handles user data persistence

const SUPABASE_URL := "https://aegjluwadbvxlggzkyxw.supabase.co"
const SUPABASE_KEY := "sb_publishable_u3rMLiZvBYti2cDBVoGBOg_Z-mh3OMG"  # Publishable/Anon key

var http_request: HTTPRequest

# Store access token after login
var access_token: String = ""
var current_user_id: String = ""

# Signals
signal user_data_loaded(user_data: Dictionary)
signal user_data_saved(success: bool)
signal login_success(user_id: String)
signal login_failed(error: String)

func _ready():
	http_request = HTTPRequest.new()
	http_request.request_completed.connect(_on_request_completed)
	add_child(http_request)
	print("[SupabaseManager] Initialized")

## Authentication

func login(email: String, password: String):
	var url = SUPABASE_URL + "/auth/v1/token?grant_type=password"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	]
	var body = JSON.stringify({
		"email": email,
		"password": password
	})
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		login_failed.emit("Request failed")

func signup(email: String, password: String, username: String):
	var url = SUPABASE_URL + "/auth/v1/signup"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json"
	]
	var body = JSON.stringify({
		"email": email,
		"password": password,
		"data": {
			"username": username,
			"gold": 300,
			"level": 1,
			"xp": 0
		}
	})
	
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

## Social Login (OAuth)

func sign_in_with_google():
	var redirect_to = "http://localhost:8080/auth/callback"
	var url = SUPABASE_URL + "/auth/v1/authorize?provider=google&redirect_to=" + redirect_to.uri_encode()
	
	print("[SupabaseManager] Opening Google OAuth: " + url)
	OS.shell_open(url)
	show_toast("请在浏览器中完成登录")

func sign_in_with_facebook():
	var redirect_to = "http://localhost:8080/auth/callback"
	var url = SUPABASE_URL + "/auth/v1/authorize?provider=facebook&redirect_to=" + redirect_to.uri_encode()
	
	print("[SupabaseManager] Opening Facebook OAuth: " + url)
	OS.shell_open(url)
	show_toast("请在浏览器中完成登录")

func show_toast(message: String):
	print("[SupabaseManager] Toast: " + message)

## User Data Operations

func load_user_data(user_id: String):
	var url = SUPABASE_URL + "/rest/v1/user_data?user_id=eq." + user_id + "&limit=1"
	
	# Use access token for RLS if available
	var auth_token = access_token if not access_token.is_empty() else SUPABASE_KEY
	
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + auth_token,
		"Content-Type: application/json"
	]
	
	print("[SupabaseManager] Loading user data with token type: ", "access_token" if not access_token.is_empty() else "anon_key")
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func save_user_data(user_id: String, data: Dictionary):
	# Use upsert with on_conflict parameter
	var url = SUPABASE_URL + "/rest/v1/user_data?on_conflict=user_id"
	
	# Use access token for RLS if available
	var auth_token = access_token if not access_token.is_empty() else SUPABASE_KEY
	
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + auth_token,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates"
	]
	
	var save_data = data.duplicate()
	save_data["user_id"] = user_id
	save_data["updated_at"] = Time.get_datetime_string_from_system()
	
	print("[SupabaseManager] Saving user data with token type: ", "access_token" if not access_token.is_empty() else "anon_key")
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(save_data))

## Inventory Operations

func load_inventory(user_id: String):
	var url = SUPABASE_URL + "/rest/v1/inventory?user_id=eq." + user_id
	
	var auth_token = access_token if not access_token.is_empty() else SUPABASE_KEY
	
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + auth_token
	]
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func save_inventory_item(user_id: String, item_id: String, quantity: int):
	# Use upsert with on_conflict parameter
	var url = SUPABASE_URL + "/rest/v1/inventory?on_conflict=user_id,item_id"
	
	var auth_token = access_token if not access_token.is_empty() else SUPABASE_KEY
	
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + auth_token,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates"
	]
	
	var body = JSON.stringify({
		"user_id": user_id,
		"item_id": item_id,
		"quantity": quantity,
		"updated_at": Time.get_datetime_string_from_system()
	})
	
	print("[SupabaseManager] Saving inventory item: ", item_id, " x", quantity)
	http_request.request(url, headers, HTTPClient.METHOD_POST, body)

## HTTP Response Handler

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[SupabaseManager] Request failed: ", result)
		return
	
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	
	if error != OK:
		print("[SupabaseManager] JSON parse error: ", body.get_string_from_utf8())
		return
	
	var data = json.get_data()
	print("[SupabaseManager] Response: ", data)
	
	match response_code:
		200, 201:
			if data is Array:
				if data.size() > 0:
					user_data_loaded.emit(data[0] if data.size() == 1 else data)
				else:
					# Empty array - no user data found, create default
					print("[SupabaseManager] No user data found, creating default...")
					user_data_loaded.emit({
						"user_id": "",
						"username": "农场主",
						"gold": 300,
						"level": 1,
						"xp": 0
					})
			elif data is Dictionary:
				if data.has("access_token"):
					# Login/signup success - has access token
					access_token = data["access_token"]
					current_user_id = data["user"]["id"]
					var username = data["user"]["user_metadata"].get("username", "农场主") if data["user"].has("user_metadata") else "农场主"
					
					print("[SupabaseManager] Access token saved: ", access_token.substr(0, 20), "...")
					
					login_success.emit(current_user_id)
					print("[SupabaseManager] Login successful: ", current_user_id, " username: ", username)
					
					load_user_data(current_user_id)
				elif data.has("id"):
					# User object directly (may not have access_token in some cases)
					current_user_id = data["id"]
					var username = "农场主"
					if data.has("user_metadata") and data["user_metadata"].has("username"):
						username = data["user_metadata"]["username"]
					
					print("[SupabaseManager] WARNING: No access_token in login response!")
					
					login_success.emit(current_user_id)
					print("[SupabaseManager] Login successful: ", current_user_id, " username: ", username)
					
					load_user_data(current_user_id)
				else:
					user_data_saved.emit(true)
					print("[SupabaseManager] Data saved successfully")
			else:
				print("[SupabaseManager] Unknown data type: ", typeof(data))
		_:
			var error_msg = "未知错误"
			if data.has("msg"):
				error_msg = data["msg"]
			elif data.has("error_description"):
				error_msg = data["error_description"]
			elif data.has("error"):
				error_msg = data["error"]
			
			if "validation_failed" in str(data):
				error_msg = "邮箱格式无效，请使用正确的邮箱地址"
			elif "Invalid login credentials" in error_msg:
				error_msg = "邮箱或密码错误"
			elif "Email not confirmed" in error_msg:
				error_msg = "邮箱未验证，请检查邮件"
			elif "row-level security" in error_msg:
				error_msg = "权限验证失败，请重新登录"
			elif "duplicate key" in error_msg:
				error_msg = "数据已存在，正在更新..."
				# This is actually fine for upsert operations
				print("[SupabaseManager] Duplicate key error (upsert), ignoring...")
				return
			
			login_failed.emit(error_msg)
			print("[SupabaseManager] Error: ", error_msg, " | Raw: ", data)
			user_data_saved.emit(false)
