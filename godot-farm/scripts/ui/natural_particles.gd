class_name NaturalParticles
extends Node2D

## More natural ambient particle effects

enum ParticleType {
	PETALS,      # Gentle falling petals
	DUST,        # Floating golden dust
	FIREFLIES,   # Slow glowing orbs
	SPARKLES     # Magical sparkles
}

@export var particle_type: ParticleType = ParticleType.PETALS
@export var emit: bool = true

var _particles: GPUParticles2D
var _material: ParticleProcessMaterial

func _ready():
	_setup()

func _setup():
	_particles = GPUParticles2D.new()
	_particles.name = "NaturalParticles"
	add_child(_particles)
	
	_material = ParticleProcessMaterial.new()
	
	match particle_type:
		ParticleType.PETALS:
			_setup_petals()
		ParticleType.DUST:
			_setup_dust()
		ParticleType.FIREFLIES:
			_setup_fireflies()
		ParticleType.SPARKLES:
			_setup_sparkles()
	
	_particles.process_material = _material
	_particles.emitting = emit

func _setup_petals():
	# Gentle falling petals - slow, swaying
	_particles.amount = 15
	_particles.lifetime = 12.0
	_particles.preprocess = 8.0
	_particles.explosiveness = 0.0
	_particles.randomness = 0.5
	_particles.visibility_rect = Rect2(-3000, -1000, 6000, 4000)
	
	# Spawn from top
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(2000, 50, 0)
	
	# Slow fall with slight drift
	_material.direction = Vector3(0, 1, 0)
	_material.spread = 15.0
	_material.gravity = Vector3(0, 5, 0)  # Very light gravity
	_material.initial_velocity_min = 10.0
	_material.initial_velocity_max = 25.0
	
	# Gentle rotation
	_material.angular_velocity_min = -20.0
	_material.angular_velocity_max = 20.0
	
	# Slight turbulence for swaying
	_material.turbulence_enabled = true
	_material.turbulence_noise_strength = 0.1  # Very subtle
	_material.turbulence_noise_scale = 0.5
	_material.turbulence_influence_min = 0.0
	_material.turbulence_influence_max = 0.3
	
	# Color - soft pink
	_material.color = Color(1.0, 0.85, 0.9, 0.8)
	
	# Scale curve - start small, grow slightly, fade
	_material.scale_min = 0.8
	_material.scale_max = 1.2
	
	# Texture
	var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in range(12):
		for x in range(12):
			var dx = x - 5.5
			var dy = y - 5.5
			var dist = sqrt(dx*dx + dy*dy)
			if dist < 5:
				var alpha = 1.0 - (dist / 5.0)
				img.set_pixel(x, y, Color(1, 0.85, 0.9, alpha * 0.8))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_particles.texture = ImageTexture.create_from_image(img)

func _setup_dust():
	# Golden dust - floating, very slow, subtle
	_particles.amount = 30
	_particles.lifetime = 15.0
	_particles.preprocess = 10.0
	_particles.explosiveness = 0.0
	_particles.randomness = 0.3
	_particles.visibility_rect = Rect2(-2000, -1000, 4000, 3000)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(1500, 800, 0)
	
	# Float upward very slowly
	_material.direction = Vector3(0, -1, 0)
	_material.spread = 180.0
	_material.gravity = Vector3(0, -3, 0)  # Negative gravity (float up)
	_material.initial_velocity_min = 2.0
	_material.initial_velocity_max = 8.0
	
	# Subtle drift
	_material.turbulence_enabled = true
	_material.turbulence_noise_strength = 0.08
	_material.turbulence_noise_scale = 1.0
	_material.turbulence_influence_min = 0.0
	_material.turbulence_influence_max = 0.2
	
	_material.color = Color(1.0, 0.95, 0.7, 0.5)
	
	# Very small particles
	_material.scale_min = 0.3
	_material.scale_max = 0.8
	
	# Texture
	var img = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	for y in range(6):
		for x in range(6):
			var dx = x - 2.5
			var dy = y - 2.5
			var dist = sqrt(dx*dx + dy*dy)
			if dist < 2.5:
				var alpha = 1.0 - (dist / 2.5)
				img.set_pixel(x, y, Color(1, 0.95, 0.7, alpha * 0.6))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_particles.texture = ImageTexture.create_from_image(img)

func _setup_fireflies():
	# Fireflies - slow, organic movement
	_particles.amount = 20
	_particles.lifetime = 10.0
	_particles.preprocess = 6.0
	_particles.explosiveness = 0.0
	_particles.randomness = 0.5
	_particles.visibility_rect = Rect2(-2500, -800, 5000, 2500)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(2000, 600, 0)
	
	# Random slow movement
	_material.direction = Vector3(0, 0, 0)
	_material.spread = 180.0
	_material.gravity = Vector3(0, 0, 0)
	_material.initial_velocity_min = 8.0
	_material.initial_velocity_max = 20.0
	
	# Orbit-like motion
	_material.turbulence_enabled = true
	_material.turbulence_noise_strength = 0.15
	_material.turbulence_noise_scale = 0.8
	_material.turbulence_influence_min = 0.1
	_material.turbulence_influence_max = 0.4
	
	_material.color = Color(0.9, 1.0, 0.4, 0.9)
	
	_material.scale_min = 1.0
	_material.scale_max = 2.0
	
	# Glow texture
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var dx = x - 7.5
			var dy = y - 7.5
			var dist = sqrt(dx*dx + dy*dy)
			if dist < 7:
				var alpha = pow(1.0 - (dist / 7.0), 2)
				img.set_pixel(x, y, Color(1, 1, 0.6, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_particles.texture = ImageTexture.create_from_image(img)

func _setup_sparkles():
	# Tiny sparkles
	_particles.amount = 25
	_particles.lifetime = 3.0
	_particles.preprocess = 2.0
	_particles.explosiveness = 0.2
	_particles.randomness = 0.5
	_particles.visibility_rect = Rect2(-1500, -500, 3000, 2000)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(1000, 400, 0)
	
	_material.direction = Vector3(0, -1, 0)
	_material.spread = 30.0
	_material.gravity = Vector3(0, -10, 0)
	_material.initial_velocity_min = 15.0
	_material.initial_velocity_max = 40.0
	
	_material.color = Color(1.0, 1.0, 0.9, 0.7)
	
	_material.scale_min = 0.2
	_material.scale_max = 0.6
	
	# Tiny dot
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.set_pixel(1, 1, Color(1, 1, 1, 0.8))
	img.set_pixel(2, 1, Color(1, 1, 1, 0.8))
	img.set_pixel(1, 2, Color(1, 1, 1, 0.8))
	img.set_pixel(2, 2, Color(1, 1, 1, 0.8))
	_particles.texture = ImageTexture.create_from_image(img)

func start():
	_particles.emitting = true

func stop():
	_particles.emitting = false
