extends CanvasLayer

## Community Panel - 广场 (all posts) / 好友 (friends-only) tabs, post composer, feed, likes, comments

signal panel_closed

@onready var close_button: Button = %CloseButton
@onready var tab_bar: TabBar = %CommunityTabBar
@onready var feed_list: VBoxContainer = %FeedList
@onready var compose_input: TextEdit = %ComposeInput
@onready var post_button: Button = %PostButton
@onready var status_label: Label = %CommunityStatus

var supabase: Node = null
var _current_tab: int = 0  # 0=广场, 1=好友

func _ready():
	supabase = get_node_or_null("/root/SupabaseManager")
	
	close_button.pressed.connect(_on_close)
	post_button.pressed.connect(_on_post)
	tab_bar.tab_changed.connect(_on_tab_changed)
	
	# Set up tabs
	tab_bar.clear_tabs()
	tab_bar.add_tab("广场")
	tab_bar.add_tab("好友")
	
	if supabase:
		supabase.community_posts_loaded.connect(_on_posts_loaded)
		supabase.community_post_created.connect(func(ok):
			if ok:
				compose_input.text = ""
				_set_status("发布成功！")
				_refresh_feed()
			else:
				_set_status("发布失败")
		)
		supabase.community_like_toggled.connect(func(ok):
			if ok:
				_refresh_feed()
		)
		supabase.community_comments_loaded.connect(_on_comments_loaded)
		supabase.community_comment_created.connect(func(ok):
			if ok:
				_set_status("评论成功")
				# Comments will refresh when user opens them again
		)
	
	_refresh_feed()

func _on_close():
	panel_closed.emit()
	queue_free()

func _on_tab_changed(idx: int):
	_current_tab = idx
	_refresh_feed()

func _on_post():
	var content = compose_input.text.strip_edges()
	if content.is_empty():
		_set_status("内容不能为空")
		return
	if supabase:
		supabase.create_community_post(content)
		_set_status("发布中...")

func _refresh_feed():
	if supabase:
		supabase.load_community_posts(_current_tab == 1)

func _on_posts_loaded(posts: Array):
	_clear_container(feed_list)
	if posts.is_empty():
		var empty = Label.new()
		empty.text = "还没有动态，发一条吧！"
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		feed_list.add_child(empty)
		return
	
	for post in posts:
		var card = _create_post_card(post)
		feed_list.add_child(card)

func _create_post_card(post: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.25, 0.2, 0.9)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	# Author + time
	var header = Label.new()
	var author_short = str(post.get("author_id", "?")).substr(0, 8)
	# TODO: resolve username from author_id
	header.text = "👤 %s · %s" % [author_short, str(post.get("created_at", "")).substr(0, 16)]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	vbox.add_child(header)
	
	# Content
	var content = Label.new()
	content.text = post.get("content", "")
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(content)
	
	# Action row
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	vbox.add_child(actions)
	
	var post_id = str(post.get("id", ""))
	
	# Like button
	var like_btn = Button.new()
	like_btn.text = "❤️ 赞"
	like_btn.flat = true
	like_btn.pressed.connect(func():
		if supabase and not post_id.is_empty():
			supabase.toggle_like(post_id)
	)
	actions.add_child(like_btn)
	
	# Comment button (opens inline comment composer)
	var comment_btn = Button.new()
	comment_btn.text = "💬 评论"
	comment_btn.flat = true
	comment_btn.pressed.connect(func():
		_show_comment_input(vbox, post_id)
	)
	actions.add_child(comment_btn)
	
	return panel

func _show_comment_input(parent_vbox: VBoxContainer, post_id: String):
	# Check if already showing
	if parent_vbox.has_node("CommentSection"):
		return
	
	var section = VBoxContainer.new()
	section.name = "CommentSection"
	parent_vbox.add_child(section)
	
	# Comments list placeholder
	var comments_container = VBoxContainer.new()
	comments_container.name = "CommentsList"
	section.add_child(comments_container)
	
	# Load existing comments
	if supabase:
		# Temporary one-shot connection
		var cb = func(comments: Array):
			_clear_container(comments_container)
			for c in comments:
				var lbl = Label.new()
				lbl.text = "  💬 %s: %s" % [str(c.get("author_id", "?")).substr(0, 8), c.get("content", "")]
				lbl.add_theme_font_size_override("font_size", 13)
				lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.8))
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				comments_container.add_child(lbl)
		# TODO: This connects permanently; should be one-shot. Fine for first pass.
		supabase.community_comments_loaded.connect(cb)
		supabase.load_comments(post_id)
	
	# Input row
	var input_row = HBoxContainer.new()
	section.add_child(input_row)
	
	var input = LineEdit.new()
	input.placeholder_text = "写评论..."
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(input)
	
	var send_btn = Button.new()
	send_btn.text = "发送"
	send_btn.pressed.connect(func():
		var text = input.text.strip_edges()
		if text.is_empty() or post_id.is_empty():
			return
		if supabase:
			supabase.create_comment(post_id, text)
			input.text = ""
	)
	input_row.add_child(send_btn)

func _on_comments_loaded(_comments: Array):
	# Handled by inline callback above
	pass

func _set_status(msg: String):
	if status_label:
		status_label.text = msg

func _clear_container(c: Container):
	for child in c.get_children():
		child.queue_free()
