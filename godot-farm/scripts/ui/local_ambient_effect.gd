class_name LocalAmbientEffect
extends Node2D

## Local ambient effects that don't use global particles
## Subtle dust motes around specific areas

@export var effect_radius: float = 200.0
@export var particle_count: int = 15
@export var particle_color: Color = Color(1.0, 0.95, 0.8, 0.3)

var _particles: GPUParticles2D

func _ready():
	_setup_particles()

func _setup_particles():
	_particles = GPUParticles2D.new()
	_particles.name = "LocalDust"
	_particles.amount = particle_count
	_particles.lifetime = 4.0
	_particles.preprocess = 2.0
	_particles.explosiveness = 0.0
	_particles.randomness = 1.0
	_particles.visibility_rect = Rect2(-effect_radius * 2, -effect_radius * 2, effect_radius * 4, effect_radius * 4)
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = effect_radius * 0.5
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.gravity = Vector3(0, 5, 0)
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 8.0
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 0.3
	material.color = particle_color
	
	_particles.process_material = material
	
	# Soft dust texture
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 0.95, 0.4))
	gradient.add_point(0.5, Color(1, 1, 0.9, 0.2))
	gradient.add_point(1.0, Color(1, 1, 1, 0.0))
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 6
	gradient_texture.height = 6
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	_particles.texture = gradient_texture
	
	add_child(_particles)

func start():
	_particles.emitting = true

func stop():
	_particles.emitting = false
