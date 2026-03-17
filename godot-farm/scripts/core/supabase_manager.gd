extends Node

## Supabase Database Manager - Handles user data persistence

const SUPABASE_URL := "https://aegjluwadbvxlggzkyxw.supabase.co"
const SUPABASE_KEY := "sb_publishable_u3rMLiZvBYti2cDBVoGBOg_Z-mh3OMG"  # Publishable/Anon key

var http_request: HTTPRequest

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
# Note: For mobile/desktop games, you need to configure OAuth providers in Supabase Dashboard
# and set up deep linking or a local redirect URL

func sign_in_with_google():
	# For web builds, this redirects to Google OAuth
	# For mobile/desktop, you need to configure deep linking
	var redirect_to = "http://localhost:8080/auth/callback"  # Change to your game URL
	var url = SUPABASE_URL + "/auth/v1/authorize?provider=google&redirect_to=" + redirect_to.uri_encode()
	
	print("[SupabaseManager] Opening Google OAuth: " + url)
	OS.shell_open(url)
	
	# Show instructions to user
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
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + SUPABASE_KEY,
		"Content-Type: " + "application/json"
	]
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func save_user_data(user_id: String, data: Dictionary):
	var url = SUPABASE_URL + "/rest/v1/user_data"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates"
	]
	
	var save_data = data.duplicate()
	save_data["user_id"] = user_id
	save_data["updated_at"] = Time.get_datetime_string_from_system()
	
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(save_data))

## Inventory Operations

func load_inventory(user_id: String):
	var url = SUPABASE_URL + "/rest/v1/inventory?user_id=eq." + user_id
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + SUPABASE_KEY
	]
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func save_inventory_item(user_id: String, item_id: String, quantity: int):
	var url = SUPABASE_URL + "/rest/v1/inventory"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates"
	]
	
	var body = JSON.stringify({
		"user_id": user_id,
		"item_id": item_id,
		"quantity": quantity,
		"updated_at": Time.get_datetime_string_from_system()
	})
	
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
				if data.has("id"):
					# Login/signup success - data contains user object directly
					var user_id = data["id"]
					var username = "农场主"
					if data.has("user_metadata") and data["user_metadata"].has("username"):
						username = data["user_metadata"]["username"]
					
					login_success.emit(user_id)
					print("[SupabaseManager] Login successful: ", user_id, " username: ", username)
					
					# Auto-create user_data if not exists (trigger should handle this, but backup here)
					load_user_data(user_id)
				elif data.has("access_token"):
					# Alternative format with access_token
					var user_id = data["user"]["id"]
					var username = data["user"]["user_metadata"].get("username", "农场主") if data["user"].has("user_metadata") else "农场主"
					
					login_success.emit(user_id)
					print("[SupabaseManager] Login successful: ", user_id)
					
					load_user_data(user_id)
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
			
			# 友好的错误提示
			if "validation_failed" in str(data):
				error_msg = "邮箱格式无效，请使用正确的邮箱地址"
			elif "Invalid login credentials" in error_msg:
				error_msg = "邮箱或密码错误"
			elif "Email not confirmed" in error_msg:
				error_msg = "邮箱未验证，请检查邮件"
			
			login_failed.emit(error_msg)
			print("[SupabaseManager] Error: ", error_msg, " | Raw: ", data)
			user_data_saved.emit(false)
