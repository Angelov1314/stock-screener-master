extends Node

## Supabase Database Manager - Handles user data persistence

const SUPABASE_URL := "https://your-project.supabase.co"
const SUPABASE_KEY := "your-anon-key"  # Use anon key for client-side

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

## User Data Operations

func load_user_data(user_id: String):
	var url = SUPABASE_URL + "/rest/v1/user_data?user_id=eq." + user_id + "&limit=1"
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + SUPABASE_KEY,
		"Content-Type: application/json"
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
		print("[SupabaseManager] JSON parse error")
		return
	
	var data = json.get_data()
	
	match response_code:
		200, 201:
			if data is Array and data.size() > 0:
				user_data_loaded.emit(data[0] if data.size() == 1 else data)
			elif data is Dictionary:
				if data.has("access_token"):
					# Login success
					login_success.emit(data["user"]["id"])
					# Save token for future requests
					print("[SupabaseManager] Login successful: ", data["user"]["id"])
				else:
					user_data_saved.emit(true)
					print("[SupabaseManager] Data saved successfully")
		else:
			if data.has("error"):
				login_failed.emit(data["error_description"])
				print("[SupabaseManager] Error: ", data["error_description"])
			user_data_saved.emit(false)
