class_name AnimatedLight
extends Node2D

## An animated light source that feels alive
## Combines: sprite glow + PointLight2D + micro-movements

@export var light_color: Color = Color(1.0, 0.9, 0.7, 1.0)
@export var base_energy: float = 1.0
@export var flicker_amount: float = 0.1
@export var breathe_speed: float = 2.0
@export var dust_intensity: float = 0.5

# Components
var _glow_sprite: Sprite2D
var _point_light: PointLight2D
var _dust_particles: GPUParticles2D
var _tween: Tween

# Animation state
var _time: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

func _ready():
	_setup_glow_sprite()
	_setup_point_light()
	_setup_dust_particles()
	# Delay tween creation until node is in tree
	call_deferred("_start_breathing_animation")

func _setup_glow_sprite():
	_glow_sprite = Sprite2D.new()
	_glow_sprite.name = "GlowSprite"
	
	# Create a soft glow texture
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(light_color.r, light_color.g, light_color.b, 1.0))
	gradient.add_point(0.3, Color(light_color.r, light_color.g, light_color.b, 0.5))
	gradient.add_point(1.0, Color(light_color.r, light_color.g, light_color.b, 0.0))
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 128
	gradient_texture.height = 128
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	
	_glow_sprite.texture = gradient_texture
	_glow_sprite.modulate = light_color
	add_child(_glow_sprite)

func _setup_point_light():
	_point_light = PointLight2D.new()
	_point_light.name = "PointLight"
	_point_light.color = light_color
	_point_light.energy = base_energy
	# Note: PointLight2D range is controlled by texture size, not range_max
	
	# Create light texture
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(0.5, Color(1, 1, 1, 0.3))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 256
	gradient_texture.height = 256
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	
	_point_light.texture = gradient_texture
	add_child(_point_light)

func _setup_dust_particles():
	_dust_particles = GPUParticles2D.new()
	_dust_particles.name = "DustParticles"
	_dust_particles.amount = int(20 * dust_intensity)
	_dust_particles.lifetime = 3.0
	_dust_particles.explosiveness = 0.0
	_dust_particles.randomness = 1.0
	_dust_particles.local_coords = true
	_dust_particles.visibility_rect = Rect2(-200, -200, 400, 400)
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 50.0
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.gravity = Vector3(0, -10, 0)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.color = Color(light_color.r, light_color.g, light_color.b, 0.6)
	
	_dust_particles.process_material = material
	
	# Dust texture
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 0.8))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 8
	gradient_texture.height = 8
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	_dust_particles.texture = gradient_texture
	
	add_child(_dust_particles)

func _start_breathing_animation():
	# Energy breathing
	_tween = create_tween()
	_tween.set_loops()
	_tween.tween_property(_point_light, "energy", base_energy + flicker_amount, 1.0 / breathe_speed)
	_tween.tween_property(_point_light, "energy", base_energy - flicker_amount, 1.0 / breathe_speed)

func _process(delta):
	_time += delta
	
	# Subtle scale breathing
	var scale_breath = sin(_time * breathe_speed) * 0.05 + 1.0
	_glow_sprite.scale = Vector2(scale_breath, scale_breath)
	
	# Random flicker
	if randf() < 0.02:
		_point_light.energy = base_energy + randf_range(-flicker_amount * 0.5, flicker_amount * 0.5)

## Public methods
func set_energy(energy: float):
	base_energy = energy
	_point_light.energy = energy

func set_color(color: Color):
	light_color = color
	_point_light.color = color
	_glow_sprite.modulate = color

func start():
	_point_light.enabled = true
	_dust_particles.emitting = true

func stop():
	_point_light.enabled = false
	_dust_particles.emitting = false

func fade_in(duration: float = 1.0):
	_point_light.enabled = true
	_dust_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(_point_light, "energy", base_energy, duration).from(0.0)

func fade_out(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(_point_light, "energy", 0.0, duration)
	tween.tween_callback(func():
		_point_light.enabled = false
		_dust_particles.emitting = false
	)
