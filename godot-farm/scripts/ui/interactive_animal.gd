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
	
	# Start idle
	_start_idle()
	
	# Play initial sound after a short delay
	var timer = get_tree().create_timer(randf_range(0.5, 2.0))
	timer.timeout.connect(_play_initial_sound)

func _play_initial_sound():
	_play_animal_sound("idle")

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
		# Try 1-based naming first (capybara_idle_01.png)
		var frame_num = i + 1
		var path = "res://assets/characters/%s/%s/%s_%s_%02d.png" % [character, folder, character, folder, frame_num]
		if ResourceLoader.exists(path):
			var texture = load(path)
			sprite_frames.add_frame(anim_name, texture)
		else:
			# Fallback to 0-based naming (cow_idle_0.png)
			path = "res://assets/characters/%s/%s/%s_%s_%d.png" % [character, folder, character, folder, i]
			if ResourceLoader.exists(path):
				var texture = load(path)
				sprite_frames.add_frame(anim_name, texture)
			else:
				# Try simple naming without character prefix
				path = "res://assets/characters/%s/%s/%s_%d.png" % [character, folder, folder, i]
				if ResourceLoader.exists(path):
					var texture = load(path)
					sprite_frames.add_frame(anim_name, texture)

func _setup_animation_from_spritesheet(sprite_frames: SpriteFrames, anim_name: String, texture: Texture2D, frames: int, speed: int):
	if not texture:
		return
		
	var frame_width = texture.get_width() / frames
	var frame_height = texture.get_height()
	
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, speed)
	sprite_frames.set_animation_loop(anim_name, true)
	
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
	# Click on animal to pick up
	if not is_being_carried and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
	
	# Occasionally play idle sound
	if randf() < 0.3:
		_play_animal_sound("idle")
	
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
	
	# Play sleep sound if available
	_play_animal_sound("idle")
	
	# Rest for 10 seconds
	change_state_timer.start(10.0)

func _start_walking():
	current_state = State.WALKING
	if sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
	_pick_new_direction()
	
	# Start footstep sounds
	_start_walking_footsteps()
	
	var walk_time = randf_range(2.0, 6.0)
	change_state_timer.start(walk_time)

func _on_change_state():
	if current_state == State.IDLE:
		_start_walking()
	else:
		_start_idle()

# Audio
var _audio_player: AudioStreamPlayer2D
var _footstep_timer: Timer
var _last_footstep_time: float = 0.0

var _drop_hint: Label = null

func _init_audio():
	# Create audio player
	_audio_player = AudioStreamPlayer2D.new()
	_audio_player.name = "AudioPlayer"
	_audio_player.max_distance = 500.0
	_audio_player.attenuation = 1.5
	add_child(_audio_player)
	
	# Create footstep timer
	_footstep_timer = Timer.new()
	_footstep_timer.name = "FootstepTimer"
	_footstep_timer.timeout.connect(_play_footstep)
	add_child(_footstep_timer)

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
	
	if ResourceLoader.exists(sound_path):
		var stream = load(sound_path)
		if stream:
			_audio_player.stream = stream
			_audio_player.volume_db = 0.0  # Full volume for testing
			_audio_player.play()
			print("[InteractiveAnimal] Playing sound: %s" % sound_path)
		else:
			print("[InteractiveAnimal] Failed to load stream: %s" % sound_path)
	else:
		print("[InteractiveAnimal] Sound file not found: %s" % sound_path)

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
