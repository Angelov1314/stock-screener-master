extends Node2D

## Background Animal - An NPC that walks around in the background
## Simplified version that auto-configures from textures

@export var walk_texture: Texture2D
@export var idle_texture: Texture2D  
@export var h_frames: int = 4
@export var walk_speed: float = 30.0
@export var scale_factor: float = 0.8
@export var min_idle_time: float = 1.5
@export var max_idle_time: float = 4.0
@export var min_walk_time: float = 2.0
@export var max_walk_time: float = 6.0
@export var boundary_padding: float = 80.0

var sprite: AnimatedSprite2D
var walk_frames: SpriteFrames
var idle_frames: SpriteFrames

enum State { IDLE, WALKING }
var current_state: State = State.IDLE
var move_direction: Vector2 = Vector2.ZERO
var screen_size: Vector2
var change_state_timer: Timer

func _ready():
	# Get screen size for boundaries
	await get_tree().process_frame
	
	# Try to get world bounds from farm scene, fallback to viewport
	var farm = get_node_or_null("/root/Main/Farm")
	if farm:
		# Use farm background size (scaled 4x)
		screen_size = Vector2(6144, 11008)
	else:
		screen_size = get_viewport_rect().size
	
	# Create animated sprite
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	add_child(sprite)
	
	# Apply scale
	sprite.scale = Vector2(scale_factor, scale_factor)
	
	# Setup animations from textures
	_setup_animations()
	
	# Create timer for state changes
	change_state_timer = Timer.new()
	change_state_timer.one_shot = true
	change_state_timer.timeout.connect(_on_change_state)
	add_child(change_state_timer)
	
	# Start idle
	_start_idle()

func _setup_animations():
	var sprite_frames = SpriteFrames.new()
	
	# Setup walk animation
	if walk_texture:
		var frame_width = walk_texture.get_width() / h_frames
		var frame_height = walk_texture.get_height()
		
		sprite_frames.add_animation("walk")
		sprite_frames.set_animation_speed("walk", 8)
		sprite_frames.set_animation_loop("walk", true)
		
		for i in range(h_frames):
			var atlas = AtlasTexture.new()
			atlas.atlas = walk_texture
			atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
			sprite_frames.add_frame("walk", atlas)
	
	# Setup idle animation
	if idle_texture:
		var frame_width = idle_texture.get_width() / h_frames
		var frame_height = idle_texture.get_height()
		
		sprite_frames.add_animation("idle")
		sprite_frames.set_animation_speed("idle", 4)
		sprite_frames.set_animation_loop("idle", true)
		
		for i in range(h_frames):
			var atlas = AtlasTexture.new()
			atlas.atlas = idle_texture
			atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
			sprite_frames.add_frame("idle", atlas)
	
	sprite.sprite_frames = sprite_frames

func _process(delta):
	if current_state == State.WALKING:
		# Move the animal
		position += move_direction * walk_speed * delta
		
		# Check boundaries and bounce
		var bounced = false
		if position.x < boundary_padding:
			position.x = boundary_padding
			move_direction.x = abs(move_direction.x)
			bounced = true
		elif position.x > screen_size.x - boundary_padding:
			position.x = screen_size.x - boundary_padding
			move_direction.x = -abs(move_direction.x)
			bounced = true
		
		if position.y < boundary_padding:
			position.y = boundary_padding
			move_direction.y = abs(move_direction.y)
			bounced = true
		elif position.y > screen_size.y - boundary_padding:
			position.y = screen_size.y - boundary_padding
			move_direction.y = -abs(move_direction.y)
			bounced = true
		
		# Update facing direction
		_update_facing()
		
		# Random direction change on bounce
		if bounced and randf() < 0.4:
			_pick_new_direction()

func _update_facing():
	# Flip sprite based on horizontal movement
	if move_direction.x < -0.1:
		sprite.flip_h = true
	elif move_direction.x > 0.1:
		sprite.flip_h = false

func _pick_new_direction():
	# Pick a random direction, prefer horizontal movement
	var angle = randf() * PI * 0.6 - PI * 0.3  # -30 to 30 degrees from horizontal
	if randf() < 0.5:
		angle += PI  # Face left
	
	move_direction = Vector2(cos(angle), sin(angle) * 0.3).normalized()
	_update_facing()

func _start_idle():
	current_state = State.IDLE
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	else:
		sprite.stop()
	
	# Random idle duration
	var idle_time = randf_range(min_idle_time, max_idle_time)
	change_state_timer.start(idle_time)

func _start_walking():
	current_state = State.WALKING
	if sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
	_pick_new_direction()
	
	# Random walk duration
	var walk_time = randf_range(min_walk_time, max_walk_time)
	change_state_timer.start(walk_time)

func _on_change_state():
	# Switch state
	if current_state == State.IDLE:
		_start_walking()
	else:
		_start_idle()
