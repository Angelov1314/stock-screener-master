extends Node2D

## Interactive Animal - Can be picked up and carried by player

@export var walk_texture: Texture2D
@export var idle_texture: Texture2D  
@export var carried_texture: Texture2D  # Optional: different sprite when carried
@export var h_frames: int = 4
@export var use_separate_frames: bool = false  # If true, load frames from folder
@export var animal_name: String = ""  # Folder name for separate frames
@export var walk_speed: float = 30.0
@export var scale_factor: float = 0.8
@export var interaction_radius: float = 150.0
@export var pickup_offset: Vector2 = Vector2(0, -80)

var sprite: AnimatedSprite2D
var click_area: Area2D

enum State { IDLE, WALKING, CARRIED, DROPPED }
var current_state: State = State.IDLE
var move_direction: Vector2 = Vector2.ZERO
var world_bounds: Vector2 = Vector2(6144, 11008)
var change_state_timer: Timer

# Carrying
var is_being_carried: bool = false
var carry_target: Node2D = null
var original_parent: Node = null

# Bounce animation when dropped
var bounce_velocity: Vector2 = Vector2.ZERO
var gravity: float = 1000.0

# Production system
var _production_timer: Timer = null
var _production_ready: bool = false
var _production_gold: int = 0
var _production_xp: int = 0
var _collectible_indicator: Node2D = null

func _ready():
	# Set the Node2D scale (affects all children)
	self.scale = Vector2(scale_factor, scale_factor)
	
	# Create animated sprite
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	add_child(sprite)
	
	# Setup animations
	_setup_animations()
	
	# Create click area for interaction
	_setup_click_area()
	
	# Create timer for state changes
	change_state_timer = Timer.new()
	change_state_timer.one_shot = true
	change_state_timer.timeout.connect(_on_change_state)
	add_child(change_state_timer)
	
	# Setup audio
	_init_audio()
	
	# Setup production system
	_init_production()
	
	# Start idle
	_start_idle()

func _setup_click_area():
	click_area = Area2D.new()
	click_area.name = "ClickArea"
	click_area.input_pickable = true
	click_area.input_event.connect(_on_input_event)
	add_child(click_area)
	
	# Collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = interaction_radius
	collision.shape = shape
	click_area.add_child(collision)
	
	# Add visual debug circle (optional, remove in production)
	# var debug_circle = TextureRect.new()
	# debug_circle.modulate = Color(1, 0, 0, 0.3)
	# add_child(debug_circle)

func _setup_animations():
	var sprite_frames = SpriteFrames.new()
	
	if use_separate_frames and animal_name != "":
		# Load frames from separate files
		_setup_animation_from_frames(sprite_frames, "idle", animal_name, "idle", 4)
		_setup_animation_from_frames(sprite_frames, "walk", animal_name, "walk", 4)
		_setup_animation_from_frames(sprite_frames, "happy", animal_name, "happy", 4)
		_setup_animation_from_frames(sprite_frames, "sleep", animal_name, "sleep", 2)
		_setup_animation_from_frames(sprite_frames, "carried", animal_name, "carried", 2)
	else:
		# Use spritesheet
		_setup_animation_from_spritesheet(sprite_frames, "walk", walk_texture, h_frames, 8)
		_setup_animation_from_spritesheet(sprite_frames, "idle", idle_texture, h_frames, 4)
		
		# Setup carried animation
		if carried_texture:
			_setup_animation_from_spritesheet(sprite_frames, "carried", carried_texture, h_frames, 8)
		elif idle_texture:
			sprite_frames.add_animation("carried")
			sprite_frames.set_animation_speed("carried", 8)
			sprite_frames.set_animation_loop("carried", true)
			for i in range(sprite_frames.get_frame_count("idle")):
				sprite_frames.add_frame("carried", sprite_frames.get_frame_texture("idle", i))
	
	sprite.sprite_frames = sprite_frames

func _setup_animation_from_frames(sprite_frames: SpriteFrames, anim_name: String, character: String, folder: String, frame_count: int):
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, 8 if anim_name in ["walk", "carried"] else 4)
	sprite_frames.set_animation_loop(anim_name, true)
	
	for i in range(frame_count):
		var texture = null
		var frame_num = i + 1
		
		# Try 1-based naming with prefix (capybara_idle_01.png)
		var path = "res://assets/characters/%s/%s/%s_%s_%02d.png" % [character, folder, character, folder, frame_num]
		if ResourceLoader.exists(path):
			texture = load(path)
		else:
			# Try 0-based naming with prefix (cow_idle_0.png)
			path = "res://assets/characters/%s/%s/%s_%s_%d.png" % [character, folder, character, folder, i]
			if ResourceLoader.exists(path):
				texture = load(path)
			else:
				# Try 1-based naming without prefix (idle_01.png)
				path = "res://assets/characters/%s/%s/%s_%02d.png" % [character, folder, folder, frame_num]
				if ResourceLoader.exists(path):
					texture = load(path)
				else:
					# Try 0-based naming without prefix (idle_0.png)
					path = "res://assets/characters/%s/%s/%s_%d.png" % [character, folder, folder, i]
					if ResourceLoader.exists(path):
						texture = load(path)
		
		if texture:
			sprite_frames.add_frame(anim_name, texture)

func _setup_animation_from_spritesheet(sprite_frames: SpriteFrames, anim_name: String, texture: Texture2D, frames: int, speed: int):
	if not texture:
		return
	
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, speed)
	sprite_frames.set_animation_loop(anim_name, true)
	
	# If only 1 frame, use the whole texture
	if frames <= 1:
		sprite_frames.add_frame(anim_name, texture)
		return
	
	# Multiple frames - use atlas
	var frame_width = texture.get_width() / frames
	var frame_height = texture.get_height()
	
	for i in range(frames):
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		sprite_frames.add_frame(anim_name, atlas)

func _input(event):
	# Global input - drop when clicking anywhere or pressing space
	if is_being_carried:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_drop()
		elif event is InputEventKey:
			if event.pressed and event.keycode == KEY_SPACE:
				_drop()

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	# Click on animal
	if not is_being_carried and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if there's production to collect first
			if _production_ready:
				var collected = collect_production()
				if not collected.is_empty():
					print("[InteractiveAnimal] Collected %d gold and %d XP from %s" % [collected.gold, collected.xp, animal_name])
					# Play collect sound
					_play_animal_sound("happy")
					return
			# Pick up the animal (placed or not)
			_try_pickup()

func _try_pickup():
	# Check if player is close enough (optional, can pick up from anywhere for now)
	_pickup()

func _pickup():
	is_being_carried = true
	current_state = State.CARRIED
	
	# Bring to front
	z_index = 100
	
	# Stop walking
	change_state_timer.stop()
	_stop_walking_footsteps()
	
	# Play carried animation
	if sprite.sprite_frames.has_animation("carried"):
		sprite.play("carried")
	
	# Play pickup sound (animal idle sound)
	_play_animal_sound("idle")
	
	# Visual feedback - bounce up and add glow
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(scale_factor * 1.2, scale_factor * 1.2), 0.1)
	
	# Add drop hint
	_show_drop_hint()
	
	print("[InteractiveAnimal] Picked up! Press SPACE or Click to drop")

func _drop():
	if not is_being_carried:
		return
		
	is_being_carried = false
	current_state = State.DROPPED
	
	# Reset z-index
	z_index = 0
	
	# Hide drop hint
	_hide_drop_hint()
	
	# Bounce animation
	bounce_velocity = Vector2(randf() * 200 - 100, -300)
	
	# Play drop sound
	_play_animal_sound("idle")
	
	# Visual feedback - scale back to normal
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(scale_factor, scale_factor), 0.2)
	
	# Resume normal behavior after a moment
	await get_tree().create_timer(0.5).timeout
	_start_idle()
	
	print("[InteractiveAnimal] Dropped!")

func _process(delta):
	if is_being_carried:
		_follow_mouse()
	elif current_state == State.WALKING:
		_walk(delta)
	elif current_state == State.DROPPED:
		_apply_bounce(delta)

func _follow_mouse():
	# Get mouse position in world coordinates
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	# Get mouse position in screen coordinates
	var mouse_screen_pos = get_viewport().get_mouse_position()
	
	# Convert screen to world - simpler and more accurate
	var mouse_world_pos = camera.get_canvas_transform().affine_inverse() * mouse_screen_pos
	
	# Apply pickup offset (above mouse cursor)
	position = mouse_world_pos + pickup_offset
	
	# Update hint position relative to animal
	if _drop_hint and _drop_hint.visible:
		_drop_hint.position = Vector2(-_drop_hint.size.x / 2, -80)
	
	# Flip based on mouse movement direction
	var velocity = Input.get_last_mouse_velocity()
	if velocity.x < -30:
		sprite.flip_h = true
	elif velocity.x > 30:
		sprite.flip_h = false

func _walk(delta):
	# Move the animal
	position += move_direction * walk_speed * delta
	
	# Check boundaries and bounce
	var bounced = false
	var padding = 100.0
	
	if position.x < padding:
		position.x = padding
		move_direction.x = abs(move_direction.x)
		bounced = true
	elif position.x > world_bounds.x - padding:
		position.x = world_bounds.x - padding
		move_direction.x = -abs(move_direction.x)
		bounced = true
	
	if position.y < padding:
		position.y = padding
		move_direction.y = abs(move_direction.y)
		bounced = true
	elif position.y > world_bounds.y - padding:
		position.y = world_bounds.y - padding
		move_direction.y = -abs(move_direction.y)
		bounced = true
	
	# Update facing
	_update_facing()
	
	# Random direction change on bounce
	if bounced and randf() < 0.4:
		_pick_new_direction()

func _apply_bounce(delta):
	position += bounce_velocity * delta
	bounce_velocity.y += gravity * delta
	
	# Stop bouncing when hitting "ground"
	if position.y > world_bounds.y - 100:
		position.y = world_bounds.y - 100
		bounce_velocity = Vector2.ZERO
		current_state = State.IDLE

func _update_facing():
	if move_direction.x < -0.1:
		sprite.flip_h = true
	elif move_direction.x > 0.1:
		sprite.flip_h = false

func _pick_new_direction():
	var angle = randf() * PI * 0.6 - PI * 0.3
	if randf() < 0.5:
		angle += PI
	move_direction = Vector2(cos(angle), sin(angle) * 0.3).normalized()
	_update_facing()

func _start_idle():
	# Small chance (10%) to rest for 10 seconds
	if randf() < 0.1 and sprite.sprite_frames.has_animation("sleep"):
		_start_resting()
		return
	
	current_state = State.IDLE
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	
	# Stop footsteps
	_stop_walking_footsteps()
	
	var idle_time = randf_range(1.5, 4.0)
	change_state_timer.start(idle_time)

func _start_resting():
	current_state = State.IDLE  # Use IDLE state but with sleep animation
	if sprite.sprite_frames.has_animation("sleep"):
		sprite.play("sleep")
		print("[InteractiveAnimal] %s is taking a 10-second nap!" % animal_name)
	elif sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	
	# Stop footsteps
	_stop_walking_footsteps()
	
	# Rest for 10 seconds
	change_state_timer.start(10.0)

func _start_walking():
	current_state = State.WALKING
	if sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
	_pick_new_direction()
	
	# No automatic footstep sounds (only when picked up)
	
	var walk_time = randf_range(2.0, 6.0)
	change_state_timer.start(walk_time)

func _on_change_state():
	if current_state == State.IDLE:
		_start_walking()
	else:
		_start_idle()

# Audio
var _audio_player: AudioStreamPlayer
var _footstep_timer: Timer
var _last_footstep_time: float = 0.0

var _drop_hint: Label = null

func _init_audio():
	# Create audio player (non-positional for consistent volume)
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "AudioPlayer"
	add_child(_audio_player)
	
	# Create footstep timer
	_footstep_timer = Timer.new()
	_footstep_timer.name = "FootstepTimer"
	_footstep_timer.timeout.connect(_play_footstep)
	add_child(_footstep_timer)

func _init_production():
	# Create production timer (1-5 minutes)
	_production_timer = Timer.new()
	_production_timer.name = "ProductionTimer"
	_production_timer.one_shot = true
	_production_timer.timeout.connect(_on_production_ready)
	add_child(_production_timer)
	
	# Start first production cycle
	_start_production_timer()

func _start_production_timer():
	if not _production_timer:
		return
	
	# Random time between 1-5 minutes (60-300 seconds)
	var wait_time = randf_range(60.0, 300.0)
	_production_timer.start(wait_time)

func _on_production_ready():
	if current_state == State.CARRIED:
		# Don't produce while being carried
		_start_production_timer()
		return
	
	# Calculate production based on animal type
	var base_gold = 5
	var base_xp = 3
	
	# Different animals give different rewards
	match animal_name:
		"cow": 
			_production_gold = base_gold * 3
			_production_xp = base_xp * 3
		"pig", "sheep":
			_production_gold = base_gold * 2
			_production_xp = base_xp * 2
		"zebra", "alpaca":
			_production_gold = base_gold * 4
			_production_xp = base_xp * 4
		_:
			_production_gold = base_gold
			_production_xp = base_xp
	
	_production_ready = true
	_show_collectible_indicator()

func _show_collectible_indicator():
	if _collectible_indicator:
		return
	
	# Create a floating coin/exclamation indicator
	_collectible_indicator = Node2D.new()
	_collectible_indicator.name = "CollectibleIndicator"
	_collectible_indicator.position = Vector2(0, -60)
	add_child(_collectible_indicator)
	
	# Add a sprite or shape to indicate collectibility
	var indicator = ColorRect.new()
	indicator.size = Vector2(30, 30)
	indicator.position = Vector2(-15, -15)
	indicator.color = Color(1, 0.85, 0, 0.9)
	_collectible_indicator.add_child(indicator)
	
	# Add label
	var label = Label.new()
	label.text = "💰"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-15, -15)
	label.size = Vector2(30, 30)
	_collectible_indicator.add_child(label)
	
	# Animate floating
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(_collectible_indicator, "position:y", -70, 0.5)
	tween.tween_property(_collectible_indicator, "position:y", -60, 0.5)

func _hide_collectible_indicator():
	if _collectible_indicator:
		_collectible_indicator.queue_free()
		_collectible_indicator = null

func collect_production() -> Dictionary:
	"""Collect produced resources. Returns dictionary with gold and xp, or empty if not ready."""
	if not _production_ready:
		return {}
	
	var result = {
		"gold": _production_gold,
		"xp": _production_xp
	}
	
	# Add to player via StateManager
	var state = get_node_or_null("/root/StateManager")
	if state:
		state.apply_action({"type": "add_gold", "amount": _production_gold})
		state.apply_action({"type": "add_experience", "amount": _production_xp})
	
	_production_ready = false
	_production_gold = 0
	_production_xp = 0
	_hide_collectible_indicator()
	
	# Start next production cycle
	_start_production_timer()
	
	return result

func _play_animal_sound(sound_type: String = "idle"):
	if not _audio_player:
		print("[InteractiveAnimal] No audio player!")
		return
	
	if animal_name == "":
		print("[InteractiveAnimal] No animal_name set!")
		return
	
	var sound_path = ""
	if sound_type == "idle":
		sound_path = "res://assets/audio/sfx/%s/%s.mp3" % [animal_name, animal_name]
	elif sound_type == "walk":
		sound_path = "res://assets/audio/sfx/%s/%s_walk.mp3" % [animal_name, animal_name]
	
	print("[InteractiveAnimal] Trying to play: %s" % sound_path)
	
	# Check if file exists
	if not FileAccess.file_exists(sound_path):
		print("[InteractiveAnimal] File does not exist: %s" % sound_path)
		# Fallback to generic animal sound
		if sound_type == "idle":
			sound_path = "res://assets/audio/sfx/cow/cow.mp3"
		else:
			sound_path = "res://assets/audio/sfx/cow/cow_walk.mp3"
		print("[InteractiveAnimal] Using fallback: %s" % sound_path)
	
	# Try to load the sound file
	var stream = load(sound_path)
	if stream:
		_audio_player.stream = stream
		_audio_player.volume_db = -10.0  #  louder volume
		_audio_player.bus = "Master"
		_audio_player.play()
		print("[InteractiveAnimal] Playing sound: %s (volume: %f, bus: %s)" % [sound_path, _audio_player.volume_db, _audio_player.bus])
	else:
		print("[InteractiveAnimal] Failed to load stream: %s" % sound_path)

func _play_footstep():
	if current_state != State.WALKING:
		return
	_play_animal_sound("walk")

func _start_walking_footsteps():
	# Play footstep sound every 0.4 seconds while walking
	_footstep_timer.wait_time = 0.4
	_footstep_timer.start()

func _stop_walking_footsteps():
	_footstep_timer.stop()

func _show_drop_hint():
	if _drop_hint == null:
		_drop_hint = Label.new()
		_drop_hint.text = "点击或按空格放下"
		_drop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_drop_hint.add_theme_font_size_override("font_size", 14)
		_drop_hint.modulate = Color(1, 1, 1, 0.8)
		add_child(_drop_hint)
	_drop_hint.visible = true
	_drop_hint.position = Vector2(-_drop_hint.size.x / 2, -sprite.scale.y * 100 - 20)

func _hide_drop_hint():
	if _drop_hint:
		_drop_hint.visible = false

## Recall menu for placed animals
var _recall_menu: PanelContainer = null

func _show_recall_menu():
	if _recall_menu and is_instance_valid(_recall_menu):
		_recall_menu.queue_free()
		_recall_menu = null
		return

	_recall_menu = PanelContainer.new()
	_recall_menu.z_index = 200

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.26, 0.22, 0.17, 0.92)
	style.border_color = Color(0.50, 0.42, 0.32, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_recall_menu.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_recall_menu.add_child(vbox)

	# Animal name label
	var name_lbl = Label.new()
	name_lbl.text = animal_name.capitalize()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82))
	name_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_lbl)

	# Recall button
	var recall_btn = Button.new()
	recall_btn.text = "📦 收回仓库"
	recall_btn.add_theme_font_size_override("font_size", 16)
	recall_btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.88))
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.58, 0.48, 0.36, 0.72)
	btn_style.set_corner_radius_all(10)
	btn_style.content_margin_left = 10
	btn_style.content_margin_right = 10
	btn_style.content_margin_top = 6
	btn_style.content_margin_bottom = 6
	recall_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.64, 0.54, 0.42, 0.82)
	recall_btn.add_theme_stylebox_override("hover", btn_hover)
	recall_btn.pressed.connect(_on_recall_pressed)
	vbox.add_child(recall_btn)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62))
	var close_style = btn_style.duplicate()
	close_style.bg_color = Color(0.42, 0.36, 0.28, 0.60)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(func(): _recall_menu.queue_free(); _recall_menu = null)
	vbox.add_child(close_btn)

	_recall_menu.position = Vector2(-60, -180)
	add_child(_recall_menu)

	# Auto-close after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if _recall_menu and is_instance_valid(_recall_menu):
		_recall_menu.queue_free()
		_recall_menu = null

func _on_recall_pressed():
	if _recall_menu and is_instance_valid(_recall_menu):
		_recall_menu.queue_free()
		_recall_menu = null

	var instance_id = get_meta("instance_id") if has_meta("instance_id") else ""
	if instance_id.is_empty():
		print("[InteractiveAnimal] No instance_id, cannot recall")
		return

	var placement_mgr = get_node_or_null("/root/AnimalPlacementManager")
	if placement_mgr:
		_play_animal_sound("idle")
		placement_mgr.recall_animal(instance_id)
	else:
		print("[InteractiveAnimal] AnimalPlacementManager not found")
