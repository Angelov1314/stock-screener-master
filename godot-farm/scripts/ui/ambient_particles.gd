class_name AmbientParticles
extends Node2D

## Ambient particle effects for farm atmosphere
## Includes: petals, dust, fireflies, light particles

enum ParticleType {
	PETALS,      # Falling flower petals
	DUST,        # Floating dust motes
	FIREFLIES,   # Glowing fireflies
	LIGHT_SPOTS, # Soft light particles
	SNOW,        # Falling snow
	RAIN         # Rain drops
}

@export var particle_type: ParticleType = ParticleType.PETALS:
	set(value):
		particle_type = value
		_setup_particles()

@export var emit: bool = true:
	set(value):
		emit = value
		if _particles:
			_particles.emitting = value

@export var intensity: float = 1.0:
	set(value):
		intensity = value
		_update_intensity()

var _particles: GPUParticles2D
var _particle_material: ParticleProcessMaterial

func _ready():
	_setup_particles()

func _setup_particles():
	# Remove existing particles
	if _particles:
		_particles.queue_free()
	
	# Create new particles node
	_particles = GPUParticles2D.new()
	_particles.name = "Particles_%s" % ParticleType.keys()[particle_type]
	add_child(_particles)
	
	# Setup based on type
	match particle_type:
		ParticleType.PETALS:
			_setup_petals()
		ParticleType.DUST:
			_setup_dust()
		ParticleType.FIREFLIES:
			_setup_fireflies()
		ParticleType.LIGHT_SPOTS:
			_setup_light_spots()
		ParticleType.SNOW:
			_setup_snow()
		ParticleType.RAIN:
			_setup_rain()
	
	_particles.emitting = emit
	_update_intensity()

func _setup_petals():
	_particles.amount = 20
	_particles.lifetime = 8.0
	_particles.preprocess = 5.0
	_particles.explosiveness = 0.0
	_particles.randomness = 1.0
	_particles.fixed_fps = 30
	_particles.visibility_rect = Rect2(-4000, -2000, 8000, 6000)
	
	# Create particle material
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particle_material.emission_box_extents = Vector3(3000, 100, 0)
	
	# Fall down slowly with drift
	_particle_material.direction = Vector3(0, 1, 0)
	_particle_material.spread = 30.0
	_particle_material.gravity = Vector3(0, 10, 0)
	_particle_material.initial_velocity_min = 20.0
	_particle_material.initial_velocity_max = 50.0
	_particle_material.angular_velocity_min = -30.0
	_particle_material.angular_velocity_max = 30.0
	
	# Swaying motion
	_particle_material.turbulence_enabled = true
	_particle_material.turbulence_noise_strength = 0.5
	_particle_material.turbulence_noise_scale = 2.0
	
	# Color - soft pink/white petals
	_particle_material.color = Color(1.0, 0.8, 0.85, 0.7)
	
	_particles.process_material = _particle_material
	
	# Create simple petal texture (using a gradient for now)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 0.7, 0.75, 1.0))
	gradient.add_point(1.0, Color(1, 0.9, 0.95, 0.0))
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 8
	gradient_texture.height = 8
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	_particles.texture = gradient_texture

func _setup_dust():
	_particles.amount = 50
	_particles.lifetime = 10.0
	_particles.preprocess = 5.0
	_particles.randomness = 1.0
	_particles.visibility_rect = Rect2(-4000, -2000, 8000, 6000)
	
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particle_material.emission_box_extents = Vector3(3000, 2000, 0)
	
	# Float in all directions
	_particle_material.direction = Vector3(0, -1, 0)
	_particle_material.spread = 180.0
	_particle_material.gravity = Vector3(0, 2, 0)
	_particle_material.initial_velocity_min = 5.0
	_particle_material.initial_velocity_max = 15.0
	
	_particle_material.turbulence_enabled = true
	_particle_material.turbulence_noise_strength = 1.0
	
	# Subtle white/yellow dust
	_particle_material.color = Color(1.0, 0.95, 0.8, 0.4)
	
	_particles.process_material = _particle_material
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 0.9, 0.6))
	gradient.add_point(1.0, Color(1, 1, 1, 0.0))
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 4
	gradient_texture.height = 4
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	_particles.texture = gradient_texture

func _setup_fireflies():
	_particles.amount = 30
	_particles.lifetime = 6.0
	_particles.preprocess = 3.0
	_particles.randomness = 1.0
	_particles.visibility_rect = Rect2(-4000, -1000, 8000, 4000)
	
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particle_material.emission_box_extents = Vector3(3000, 1500, 0)
	
	# Random movement
	_particle_material.direction = Vector3(0, 0, 0)
	_particle_material.spread = 180.0
	_particle_material.gravity = Vector3(0, 0, 0)
	_particle_material.initial_velocity_min = 20.0
	_particle_material.initial_velocity_max = 40.0
	
	# Orbit-like motion using turbulence
	_particle_material.turbulence_enabled = true
	_particle_material.turbulence_noise_strength = 2.0
	_particle_material.turbulence_noise_scale = 1.0
	
	# Yellow-green glow
	_particle_material.color = Color(0.9, 1.0, 0.3, 0.9)
	_particle_material.color_ramp = _create_firefly_gradient()
	
	_particles.process_material = _particle_material
	
	# Glowing dot texture
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 0.8, 1.0))
	gradient.add_point(0.5, Color(1, 1, 0.5, 0.8))
	gradient.add_point(1.0, Color(1, 1, 1, 0.0))
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 12
	gradient_texture.height = 12
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	_particles.texture = gradient_texture

func _create_firefly_gradient() -> GradientTexture1D:
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.5, 1.0))
	gradient.add_point(0.3, Color(1.0, 1.0, 0.3, 0.8))
	gradient.add_point(0.7, Color(1.0, 1.0, 0.5, 0.4))
	gradient.add_point(1.0, Color(1.0, 1.0, 0.5, 0.0))
	var texture = GradientTexture1D.new()
	texture.gradient = gradient
	return texture

func _setup_light_spots():
	_particles.amount = 15
	_particles.lifetime = 5.0
	_particles.preprocess = 3.0
	_particles.randomness = 1.0
	_particles.visibility_rect = Rect2(-4000, -1000, 8000, 4000)
	
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particle_material.emission_box_extents = Vector3(3000, 1000, 0)
	
	_particle_material.direction = Vector3(0, -1, 0)
	_particle_material.spread = 45.0
	_particle_material.gravity = Vector3(0, -5, 0)
	_particle_material.initial_velocity_min = 10.0
	_particle_material.initial_velocity_max = 25.0
	
	# Soft light color
	_particle_material.color = Color(1.0, 1.0, 0.9, 0.5)
	
	_particles.process_material = _particle_material
	
	# Large soft circle
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 0.95, 0.3))
	gradient.add_point(0.5, Color(1, 1, 0.9, 0.1))
	gradient.add_point(1.0, Color(1, 1, 1, 0.0))
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 32
	gradient_texture.height = 32
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	_particles.texture = gradient_texture

func _setup_snow():
	_particles.amount = 100
	_particles.lifetime = 6.0
	_particles.preprocess = 3.0
	_particles.randomness = 1.0
	_particles.visibility_rect = Rect2(-4000, -2000, 8000, 6000)
	
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particle_material.emission_box_extents = Vector3(3000, 100, 0)
	
	_particle_material.direction = Vector3(0, 1, 0)
	_particle_material.spread = 20.0
	_particle_material.gravity = Vector3(0, 30, 0)
	_particle_material.initial_velocity_min = 50.0
	_particle_material.initial_velocity_max = 100.0
	
	_particle_material.color = Color(1.0, 1.0, 1.0, 0.8)
	
	_particles.process_material = _particle_material
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 0.9))
	gradient.add_point(1.0, Color(1, 1, 1, 0.0))
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 6
	gradient_texture.height = 6
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	_particles.texture = gradient_texture

func _setup_rain():
	_particles.amount = 200
	_particles.lifetime = 1.0
	_particles.preprocess = 1.0
	_particles.randomness = 0.5
	_particles.visibility_rect = Rect2(-4000, -2000, 8000, 6000)
	
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particle_material.emission_box_extents = Vector3(3000, 100, 0)
	
	_particle_material.direction = Vector3(0, 1, 0)
	_particle_material.spread = 5.0
	_particle_material.gravity = Vector3(0, 100, 0)
	_particle_material.initial_velocity_min = 200.0
	_particle_material.initial_velocity_max = 300.0
	
	# Blue-ish rain
	_particle_material.color = Color(0.7, 0.8, 1.0, 0.6)
	_particle_material.scale_min = 0.5
	_particle_material.scale_max = 1.0
	
	_particles.process_material = _particle_material
	
	# Rain streak
	var img = Image.create(2, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.7, 0.8, 1.0, 0.6))
	var texture = ImageTexture.create_from_image(img)
	_particles.texture = texture

func _update_intensity():
	if not _particles or not _particle_material:
		return
	
	_particles.amount = int(_get_base_amount() * intensity)

func _get_base_amount() -> int:
	match particle_type:
		ParticleType.PETALS: return 20
		ParticleType.DUST: return 50
		ParticleType.FIREFLIES: return 30
		ParticleType.LIGHT_SPOTS: return 15
		ParticleType.SNOW: return 100
		ParticleType.RAIN: return 200
		_: return 20

## Public methods
func set_type(type: ParticleType):
	particle_type = type

func start():
	emit = true

func stop():
	emit = false

func fade_in(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(self, "intensity", 1.0, duration)
	emit = true

func fade_out(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(self, "intensity", 0.0, duration)
	tween.tween_callback(func(): emit = false)
