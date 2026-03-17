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
signal inventory_loaded(inventory_data)
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
	"""Save user data to Supabase with proper RLS authentication"""
	
	if access_token.is_empty():
		print("[SupabaseManager] ERROR: No access token available for saving!")
		user_data_saved.emit(false)
		return
	
	# Prepare save data
	var save_data = data.duplicate()
	save_data["user_id"] = user_id
	save_data["updated_at"] = Time.get_datetime_string_from_system()
	
	# Use POST with on_conflict for upsert
	var url = SUPABASE_URL + "/rest/v1/user_data?on_conflict=user_id"
	var upsert_headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates"
	]
	
	print("[SupabaseManager] Saving user data: gold=", save_data.get("gold"), ", level=", save_data.get("level"), ", xp=", save_data.get("xp"))
	
	# Create new HTTPRequest to avoid conflicts with other operations
	var req = HTTPRequest.new()
	add_child(req)
	
	# Connect response handler
	req.request_completed.connect(func(result, code, hdrs, body):
		if result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201):
			print("[SupabaseManager] User data saved successfully")
			user_data_saved.emit(true)
		else:
			var body_str = body.get_string_from_utf8()
			print("[SupabaseManager] User data save failed: ", code, ", body: ", body_str)
			user_data_saved.emit(false)
		req.queue_free()
	)
	
	req.request(url, upsert_headers, HTTPClient.METHOD_POST, JSON.stringify(save_data))

## Inventory Operations

func load_inventory(user_id: String):
	var url = SUPABASE_URL + "/rest/v1/inventory?user_id=eq." + user_id

	var auth_token = access_token if not access_token.is_empty() else SUPABASE_KEY

	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + auth_token
	]

	http_request.request(url, headers, HTTPClient.METHOD_GET)

func save_inventory_batch(user_id: String, inventory: Dictionary):
	"""Save all inventory items in batch using real upsert"""
	if access_token.is_empty():
		print("[SupabaseManager] ERROR: No access token for saving inventory!")
		return

	# IMPORTANT: on_conflict is required, otherwise batch POST becomes plain INSERT
	var url = SUPABASE_URL + "/rest/v1/inventory?on_conflict=user_id,item_id"

	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: resolution=merge-duplicates"
	]

	# Create array of all inventory items
	var items = []
	var seen_keys = {}
	for item_id in inventory.keys():
		var unique_key = user_id + ":" + str(item_id)
		if seen_keys.has(unique_key):
			print("[SupabaseManager] WARNING duplicate item in same batch: ", unique_key)
			continue
		seen_keys[unique_key] = true

		items.append({
			"user_id": user_id,
			"item_id": item_id,
			"quantity": inventory[item_id],
			"updated_at": Time.get_datetime_string_from_system()
		})

	if items.size() == 0:
		print("[SupabaseManager] Inventory batch empty, nothing to save")
		return

	print("[SupabaseManager] Inventory batch URL: ", url)
	print("[SupabaseManager] Inventory batch Prefer header: resolution=merge-duplicates")
	print("[SupabaseManager] Inventory batch count: ", items.size())
	for item in items:
		print("[SupabaseManager] Inventory batch item: ", item.get("item_id"), " x", item.get("quantity"))
	print("[SupabaseManager] Inventory batch payload: ", JSON.stringify(items))

	# Create a new HTTPRequest for this call to avoid conflicts
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, hdrs, body):
		var body_str = body.get_string_from_utf8()
		if result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201):
			print("[SupabaseManager] Inventory batch saved successfully")
			print("[SupabaseManager] Inventory batch response: ", body_str)
		else:
			print("[SupabaseManager] Inventory batch save failed: ", code, ", body: ", body_str)
		req.queue_free()
	)

	var request_error = req.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(items))
	if request_error != OK:
		print("[SupabaseManager] Inventory batch request failed to start: ", request_error)
		req.queue_free()

func save_inventory_item(user_id: String, item_id: String, quantity: int):
	# DEPRECATED: Use save_inventory_batch instead
	# Keep for compatibility but use batch internally
	var temp_inventory = {item_id: quantity}
	save_inventory_batch(user_id, temp_inventory)

## Farm Crops Operations

signal farm_crops_loaded(crops_data: Array)
signal farm_crops_saved(success: bool)

func load_farm_crops(user_id: String):
	"""Load all planted crops for this user"""
	var url = SUPABASE_URL + "/rest/v1/farm_crops?user_id=eq." + user_id
	var auth_token = access_token if not access_token.is_empty() else SUPABASE_KEY
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + auth_token
	]

	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, hdrs, body):
		var body_str = body.get_string_from_utf8()
		if result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201):
			var json = JSON.new()
			if json.parse(body_str) == OK and json.data is Array:
				print("[SupabaseManager] Farm crops loaded: %d crops" % json.data.size())
				farm_crops_loaded.emit(json.data)
			else:
				print("[SupabaseManager] Farm crops parse error, emitting empty")
				farm_crops_loaded.emit([])
		else:
			print("[SupabaseManager] Farm crops load failed: %d, body: %s" % [code, body_str])
			farm_crops_loaded.emit([])
		req.queue_free()
	)
	req.request(url, headers, HTTPClient.METHOD_GET)

func save_farm_crops(user_id: String, crops: Array):
	"""Save all farm crops via upsert, then delete stale rows"""
	if access_token.is_empty():
		print("[SupabaseManager] ERROR: No access token for saving farm crops!")
		farm_crops_saved.emit(false)
		return

	# First delete all crops for this user, then insert fresh
	# This avoids stale rows from harvested crops
	var delete_url = SUPABASE_URL + "/rest/v1/farm_crops?user_id=eq." + user_id
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	]

	var del_req = HTTPRequest.new()
	add_child(del_req)
	del_req.request_completed.connect(func(result, code, hdrs, body):
		del_req.queue_free()
		# Now insert all current crops
		if crops.size() == 0:
			print("[SupabaseManager] No crops to save (all cleared)")
			farm_crops_saved.emit(true)
			return

		var insert_url = SUPABASE_URL + "/rest/v1/farm_crops"
		var insert_headers = [
			"apikey: " + SUPABASE_KEY,
			"Authorization: Bearer " + access_token,
			"Content-Type: application/json"
		]

		var items = []
		for crop in crops:
			var item = crop.duplicate()
			item["user_id"] = user_id
			item["updated_at"] = Time.get_datetime_string_from_system()
			items.append(item)

		var ins_req = HTTPRequest.new()
		add_child(ins_req)
		ins_req.request_completed.connect(func(r2, c2, h2, b2):
			var b2_str = b2.get_string_from_utf8()
			if r2 == HTTPRequest.RESULT_SUCCESS and (c2 == 200 or c2 == 201):
				print("[SupabaseManager] Farm crops saved: %d crops" % items.size())
				farm_crops_saved.emit(true)
			else:
				print("[SupabaseManager] Farm crops insert failed: %d, body: %s" % [c2, b2_str])
				farm_crops_saved.emit(false)
			ins_req.queue_free()
		)
		ins_req.request(insert_url, insert_headers, HTTPClient.METHOD_POST, JSON.stringify(items))
	)
	del_req.request(delete_url, headers, HTTPClient.METHOD_DELETE)

## =============================================
## Farm Animals Operations
## =============================================

signal farm_animals_loaded(animals_data: Array)
signal farm_animals_saved(success: bool)

func load_farm_animals(user_id: String):
	"""Load all placed animals for this user"""
	var url = SUPABASE_URL + "/rest/v1/farm_animals?user_id=eq." + user_id
	var auth_token = access_token if not access_token.is_empty() else SUPABASE_KEY
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + auth_token
	]

	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, hdrs, body):
		var body_str = body.get_string_from_utf8()
		if result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201):
			var json = JSON.new()
			if json.parse(body_str) == OK and json.data is Array:
				print("[SupabaseManager] Farm animals loaded: %d animals" % json.data.size())
				farm_animals_loaded.emit(json.data)
			else:
				farm_animals_loaded.emit([])
		else:
			print("[SupabaseManager] Farm animals load failed: %d" % code)
			farm_animals_loaded.emit([])
		req.queue_free()
	)
	req.request(url, headers, HTTPClient.METHOD_GET)

func save_farm_animals(user_id: String, animals: Array):
	"""Delete all then insert fresh (same pattern as farm_crops)"""
	if access_token.is_empty():
		print("[SupabaseManager] ERROR: No access token for saving farm animals!")
		farm_animals_saved.emit(false)
		return

	var delete_url = SUPABASE_URL + "/rest/v1/farm_animals?user_id=eq." + user_id
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	]

	var del_req = HTTPRequest.new()
	add_child(del_req)
	del_req.request_completed.connect(func(result, code, hdrs, body):
		del_req.queue_free()
		if animals.size() == 0:
			print("[SupabaseManager] No animals to save (all cleared)")
			farm_animals_saved.emit(true)
			return

		var insert_url = SUPABASE_URL + "/rest/v1/farm_animals"
		var insert_headers = [
			"apikey: " + SUPABASE_KEY,
			"Authorization: Bearer " + access_token,
			"Content-Type: application/json"
		]

		var items = []
		for animal in animals:
			items.append({
				"user_id": user_id,
				"animal_type": animal.get("animal_type", ""),
				"position_x": animal.get("position_x", 0),
				"position_y": animal.get("position_y", 0),
			})

		var ins_req = HTTPRequest.new()
		add_child(ins_req)
		ins_req.request_completed.connect(func(r2, c2, h2, b2):
			if r2 == HTTPRequest.RESULT_SUCCESS and (c2 == 200 or c2 == 201):
				print("[SupabaseManager] Farm animals saved: %d" % items.size())
				farm_animals_saved.emit(true)
			else:
				print("[SupabaseManager] Farm animals insert failed: %d" % c2)
				farm_animals_saved.emit(false)
			ins_req.queue_free()
		)
		ins_req.request(insert_url, insert_headers, HTTPClient.METHOD_POST, JSON.stringify(items))
	)
	del_req.request(delete_url, headers, HTTPClient.METHOD_DELETE)

## =============================================
## Friends & Community API
## =============================================

signal search_results_received(results: Array)
signal friend_requests_loaded(requests: Array)
signal friends_list_loaded(friends: Array)
signal friend_request_sent(success: bool)
signal friend_request_responded(success: bool)
signal community_posts_loaded(posts: Array)
signal community_post_created(success: bool)
signal community_like_toggled(success: bool)
signal community_comments_loaded(comments: Array)
signal community_comment_created(success: bool)

func _make_authed_request(url: String, method: int, body_str: String, callback: Callable, extra_headers: Array = []):
	"""Helper: fire-and-forget authed request with callback(result, code, body_str)"""
	if access_token.is_empty():
		print("[SupabaseManager] ERROR: not authenticated")
		return
	var headers = [
		"apikey: " + SUPABASE_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	] + extra_headers
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result, code, hdrs, body):
		callback.call(result, code, body.get_string_from_utf8())
		req.queue_free()
	)
	if body_str.is_empty():
		req.request(url, headers, method)
	else:
		req.request(url, headers, method, body_str)

## User Search (calls RPC)
func search_users(query: String):
	var url = SUPABASE_URL + "/rest/v1/rpc/search_users"
	var body = JSON.stringify({"query_text": query, "max_results": 20})
	_make_authed_request(url, HTTPClient.METHOD_POST, body, func(result, code, body_str):
		var json = JSON.new()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and json.parse(body_str) == OK and json.data is Array:
			search_results_received.emit(json.data)
		else:
			print("[SupabaseManager] search_users failed: ", code, " ", body_str)
			search_results_received.emit([])
	)

## Friend Requests
func send_friend_request(to_user_id: String):
	var url = SUPABASE_URL + "/rest/v1/friend_requests"
	var body = JSON.stringify({"from_user_id": current_user_id, "to_user_id": to_user_id})
	_make_authed_request(url, HTTPClient.METHOD_POST, body, func(result, code, body_str):
		friend_request_sent.emit(result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201))
	)

func load_friend_requests():
	"""Load pending requests TO current user"""
	var url = SUPABASE_URL + "/rest/v1/friend_requests?to_user_id=eq." + current_user_id + "&status=eq.pending&order=created_at.desc"
	_make_authed_request(url, HTTPClient.METHOD_GET, "", func(result, code, body_str):
		var json = JSON.new()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and json.parse(body_str) == OK and json.data is Array:
			friend_requests_loaded.emit(json.data)
		else:
			friend_requests_loaded.emit([])
	)

func respond_friend_request(request_id: String, accept: bool):
	if accept:
		# Use RPC to accept (creates bidirectional rows)
		var url = SUPABASE_URL + "/rest/v1/rpc/accept_friend_request"
		var body = JSON.stringify({"request_id": request_id})
		_make_authed_request(url, HTTPClient.METHOD_POST, body, func(result, code, body_str):
			friend_request_responded.emit(result == HTTPRequest.RESULT_SUCCESS and code == 200)
		)
	else:
		# Reject: just update status
		var url = SUPABASE_URL + "/rest/v1/friend_requests?id=eq." + request_id
		var body = JSON.stringify({"status": "rejected", "updated_at": Time.get_datetime_string_from_system()})
		_make_authed_request(url, HTTPClient.METHOD_PATCH, body, func(result, code, body_str):
			friend_request_responded.emit(result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 204))
		)

func load_friends_list():
	"""Load friends with profile info via friends table"""
	# TODO: join with user_data for profile info; for now just load friend IDs
	var url = SUPABASE_URL + "/rest/v1/friends?user_id=eq." + current_user_id + "&order=created_at.desc"
	_make_authed_request(url, HTTPClient.METHOD_GET, "", func(result, code, body_str):
		var json = JSON.new()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and json.parse(body_str) == OK and json.data is Array:
			friends_list_loaded.emit(json.data)
		else:
			friends_list_loaded.emit([])
	)

func remove_friend(friend_user_id: String):
	"""Remove both directions of friendship"""
	# Delete my row
	var url1 = SUPABASE_URL + "/rest/v1/friends?user_id=eq." + current_user_id + "&friend_id=eq." + friend_user_id
	_make_authed_request(url1, HTTPClient.METHOD_DELETE, "", func(_r, _c, _b): pass)
	# The other direction is owned by the friend, so RLS won't let us delete it.
	# TODO: Use an RPC or service-role function for full cleanup.

## Community Posts
func load_community_posts(friends_only: bool = false, limit: int = 50):
	var url = SUPABASE_URL + "/rest/v1/community_posts?order=created_at.desc&limit=" + str(limit)
	# TODO: friends_only filter requires a join or RPC; for now load all
	_make_authed_request(url, HTTPClient.METHOD_GET, "", func(result, code, body_str):
		var json = JSON.new()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and json.parse(body_str) == OK and json.data is Array:
			community_posts_loaded.emit(json.data)
		else:
			community_posts_loaded.emit([])
	)

func create_community_post(content: String):
	var url = SUPABASE_URL + "/rest/v1/community_posts"
	var body = JSON.stringify({"author_id": current_user_id, "content": content})
	_make_authed_request(url, HTTPClient.METHOD_POST, body, func(result, code, body_str):
		community_post_created.emit(result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201))
	)

func toggle_like(post_id: String):
	# Try to insert; if conflict, delete
	var url = SUPABASE_URL + "/rest/v1/community_likes"
	var body = JSON.stringify({"post_id": post_id, "user_id": current_user_id})
	_make_authed_request(url, HTTPClient.METHOD_POST, body, func(result, code, body_str):
		if code == 409:
			# Already liked, delete
			var del_url = SUPABASE_URL + "/rest/v1/community_likes?post_id=eq." + post_id + "&user_id=eq." + current_user_id
			_make_authed_request(del_url, HTTPClient.METHOD_DELETE, "", func(_r, _c, _b):
				community_like_toggled.emit(true)
			)
		else:
			community_like_toggled.emit(result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201))
	)

func load_comments(post_id: String):
	var url = SUPABASE_URL + "/rest/v1/community_comments?post_id=eq." + post_id + "&order=created_at.asc"
	_make_authed_request(url, HTTPClient.METHOD_GET, "", func(result, code, body_str):
		var json = JSON.new()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and json.parse(body_str) == OK and json.data is Array:
			community_comments_loaded.emit(json.data)
		else:
			community_comments_loaded.emit([])
	)

func create_comment(post_id: String, content: String):
	var url = SUPABASE_URL + "/rest/v1/community_comments"
	var body = JSON.stringify({"post_id": post_id, "author_id": current_user_id, "content": content})
	_make_authed_request(url, HTTPClient.METHOD_POST, body, func(result, code, body_str):
		community_comment_created.emit(result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201))
	)

func update_last_online():
	"""Heartbeat: update last_online_at for presence"""
	if current_user_id.is_empty() or access_token.is_empty():
		return
	var url = SUPABASE_URL + "/rest/v1/user_data?user_id=eq." + current_user_id
	var body = JSON.stringify({"last_online_at": Time.get_datetime_string_from_system()})
	_make_authed_request(url, HTTPClient.METHOD_PATCH, body, func(_r, _c, _b): pass)

## HTTP Response Handler

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[SupabaseManager] Request failed: ", result)
		return

	var body_string = body.get_string_from_utf8()
	print("[SupabaseManager] Raw response body: ", body_string if body_string.length() < 500 else body_string.substr(0, 500) + "...")

	var json = JSON.new()
	var error = json.parse(body_string)

	if error != OK:
		# Empty response is OK for successful POST/PUT operations
		if body_string.is_empty() and (response_code == 200 or response_code == 201):
			print("[SupabaseManager] Empty response with success code, treating as success")
			user_data_saved.emit(true)
		else:
			print("[SupabaseManager] JSON parse error, body: ", body_string)
			user_data_saved.emit(false)
		return

	var data = json.get_data()
	print("[SupabaseManager] Parsed response: ", data)

	match response_code:
		200, 201:
			if data is Array:
				if data.size() > 0:
					# Check if this is inventory data (has item_id) or user data (has gold)
					var first_item = data[0]
					if first_item is Dictionary and first_item.has("item_id"):
						# This is inventory data
						print("[SupabaseManager] Inventory data loaded: ", data.size(), " items")
						inventory_loaded.emit(data)
					elif first_item is Dictionary and first_item.has("gold"):
						# This is user data
						print("[SupabaseManager] User data loaded from array")
						user_data_loaded.emit(data[0])
					else:
						# Unknown data type, assume user data
						user_data_loaded.emit(data[0])
				else:
					# Empty array - no user data found, emit default
					print("[SupabaseManager] No user data found, emitting default...")
					user_data_loaded.emit({
						"user_id": current_user_id,
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
				elif data.has("id") and data.has("item_id"):
					# Single inventory item
					print("[SupabaseManager] Single inventory item loaded")
					inventory_loaded.emit(data)
				elif data.has("id") and data.has("user_id") and data.has("gold"):
					# This could be user_data from a save response
					# Check if this is a save response (has updated_at)
					if data.has("updated_at"):
						# Likely a save response
						print("[SupabaseManager] User data saved successfully: gold=", data.get("gold"), ", level=", data.get("level"))
						user_data_saved.emit(true)
					else:
						# User data loaded
						user_data_loaded.emit(data)
				elif data.has("id") and data.has("user_id"):
					# Could be user_data without gold field or other data
					print("[SupabaseManager] Data with user_id: ", data)
					if data.has("gold"):
						user_data_loaded.emit(data)
					else:
						user_data_saved.emit(true)
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
