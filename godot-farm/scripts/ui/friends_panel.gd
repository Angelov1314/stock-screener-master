extends CanvasLayer

## Friends Panel - Search users, manage friend requests, friends list

signal panel_closed

@onready var search_input: LineEdit = %SearchInput
@onready var search_button: Button = %SearchButton
@onready var search_results: VBoxContainer = %SearchResults
@onready var requests_list: VBoxContainer = %RequestsList
@onready var friends_list: VBoxContainer = %FriendsList
@onready var tab_bar: TabBar = %TabBar
@onready var tab_content: TabContainer = %TabContent
@onready var close_button: Button = %CloseButton
@onready var status_label: Label = %StatusLabel

var supabase: Node = null

func _ready():
	supabase = get_node_or_null("/root/SupabaseManager")
	
	close_button.pressed.connect(_on_close)
	search_button.pressed.connect(_on_search)
	search_input.text_submitted.connect(func(_t): _on_search())
	tab_bar.tab_changed.connect(_on_tab_changed)
	
	# Connect Supabase signals
	if supabase:
		supabase.search_results_received.connect(_on_search_results)
		supabase.friend_requests_loaded.connect(_on_requests_loaded)
		supabase.friends_list_loaded.connect(_on_friends_loaded)
		supabase.friend_request_sent.connect(func(ok):
			_set_status("发送好友请求" + ("成功！" if ok else "失败"))
		)
		supabase.friend_request_responded.connect(func(ok):
			_set_status("操作" + ("成功" if ok else "失败"))
			if ok:
				_refresh_requests()
				_refresh_friends()
		)
	
	# Initial load
	_refresh_requests()
	_refresh_friends()

func _on_close():
	panel_closed.emit()
	queue_free()

func _on_tab_changed(idx: int):
	tab_content.current_tab = idx

func _on_search():
	var query = search_input.text.strip_edges()
	if query.is_empty():
		return
	_set_status("搜索中...")
	if supabase:
		supabase.search_users(query)

func _on_search_results(results: Array):
	_clear_container(search_results)
	if results.is_empty():
		_set_status("未找到用户")
		return
	_set_status("找到 %d 个用户" % results.size())
	for r in results:
		var row = _create_user_row(r)
		search_results.add_child(row)

func _create_user_row(data: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	
	var name_label = Label.new()
	name_label.text = "%s (Lv.%s)" % [data.get("username", "?"), str(data.get("level", "?"))]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(name_label)
	
	var add_btn = Button.new()
	add_btn.text = "加好友"
	add_btn.custom_minimum_size = Vector2(100, 36)
	var uid = str(data.get("user_id", ""))
	add_btn.pressed.connect(func():
		if supabase and not uid.is_empty():
			supabase.send_friend_request(uid)
			add_btn.disabled = true
			add_btn.text = "已发送"
	)
	row.add_child(add_btn)
	
	# TODO: placeholder for "visit farm" button
	var visit_btn = Button.new()
	visit_btn.text = "访问农场"
	visit_btn.custom_minimum_size = Vector2(100, 36)
	visit_btn.disabled = true  # TODO: implement farm visiting
	row.add_child(visit_btn)
	
	return row

func _on_requests_loaded(requests: Array):
	_clear_container(requests_list)
	for req in requests:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		
		var label = Label.new()
		label.text = "来自: %s" % req.get("from_user_id", "?").substr(0, 8)
		# TODO: resolve username from user_id
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(label)
		
		var accept_btn = Button.new()
		accept_btn.text = "接受"
		var rid = str(req.get("id", ""))
		accept_btn.pressed.connect(func():
			if supabase:
				supabase.respond_friend_request(rid, true)
		)
		row.add_child(accept_btn)
		
		var reject_btn = Button.new()
		reject_btn.text = "拒绝"
		reject_btn.pressed.connect(func():
			if supabase:
				supabase.respond_friend_request(rid, false)
		)
		row.add_child(reject_btn)
		
		requests_list.add_child(row)
	
	if requests.is_empty():
		var empty = Label.new()
		empty.text = "暂无好友请求"
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		requests_list.add_child(empty)

func _on_friends_loaded(friends: Array):
	_clear_container(friends_list)
	for f in friends:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		
		var label = Label.new()
		label.text = str(f.get("friend_id", "?")).substr(0, 8)
		# TODO: resolve username, show online status via last_online_at
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(label)
		
		# Online indicator placeholder
		var status = Label.new()
		status.text = "●"  # TODO: check last_online_at
		status.add_theme_color_override("font_color", Color.GRAY)
		row.add_child(status)
		
		# Visit farm placeholder
		var visit_btn = Button.new()
		visit_btn.text = "访问农场"
		visit_btn.disabled = true  # TODO
		row.add_child(visit_btn)
		
		friends_list.add_child(row)
	
	if friends.is_empty():
		var empty = Label.new()
		empty.text = "还没有好友，去搜索添加吧！"
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		friends_list.add_child(empty)

func _refresh_requests():
	if supabase:
		supabase.load_friend_requests()

func _refresh_friends():
	if supabase:
		supabase.load_friends_list()

func _set_status(msg: String):
	if status_label:
		status_label.text = msg

func _clear_container(c: Container):
	for child in c.get_children():
		child.queue_free()
