class_name ParticleEffects
extends Node2D

## Rich collection of particle effects
## All effects are self-contained with embedded textures

enum EffectType {
	MAGIC_SPARKLES,    # Magical golden sparkles
	FIRE_FLIES,        # Glowing fireflies
	FALLING_LEAVES,    # Autumn leaves falling
	SNOW_GENTLE,       # Soft snowfall
	DUST_MOTES,        # Floating dust particles
	BUTTERFLIES,       # Fluttering butterflies
	PETALS_SAKURA,     # Pink cherry blossom petals
	RAIN_DROPS,        # Gentle rain
	STARS_TWINKLE,     # Twinkling stars
	FOG_MIST           # Ground mist
}

@export var effect_type: EffectType = EffectType.MAGIC_SPARKLES
@export var emit: bool = true
@export var intensity: float = 1.0  # 0.0 to 2.0

var _particles: GPUParticles2D
var _material: ParticleProcessMaterial

func _ready():
	_setup()

func _setup():
	_particles = GPUParticles2D.new()
	_particles.name = "ParticleEffect"
	add_child(_particles)
	
	_material = ParticleProcessMaterial.new()
	
	match effect_type:
		EffectType.MAGIC_SPARKLES:
			_setup_magic_sparkles()
		EffectType.FIRE_FLIES:
			_setup_fireflies()
		EffectType.FALLING_LEAVES:
			_setup_falling_leaves()
		EffectType.SNOW_GENTLE:
			_setup_snow()
		EffectType.DUST_MOTES:
			_setup_dust()
		EffectType.BUTTERFLIES:
			_setup_butterflies()
		EffectType.PETALS_SAKURA:
			_setup_petals()
		EffectType.RAIN_DROPS:
			_setup_rain()
		EffectType.STARS_TWINKLE:
			_setup_stars()
		EffectType.FOG_MIST:
			_setup_fog()
	
	_apply_intensity()
	_particles.process_material = _material
	_particles.emitting = true
	_particles.one_shot = false
	
	# Debug
	print("[ParticleEffects] %s: emitting=%s, amount=%d, pos=%s, velocity=%d-%d" % [
		EffectType.keys()[effect_type], 
		_particles.emitting, 
		_particles.amount,
		str(global_position),
		_material.initial_velocity_min,
		_material.initial_velocity_max
	])

func _apply_intensity():
	if not _particles:
		return
	var base_amount = _particles.amount
	_particles.amount = int(base_amount * intensity)

# ============ EFFECTS ============

func _setup_magic_sparkles():
	_particles.amount = 60
	_particles.lifetime = 3.0
	_particles.preprocess = 2.0
	_particles.explosiveness = 0.2
	_particles.randomness = 0.5
	_particles.visibility_rect = Rect2(-2000, -1500, 4000, 3000)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_material.emission_sphere_radius = 500.0
	_material.direction = Vector3(0, -1, 0)
	_material.spread = 60.0
	_material.gravity = Vector3(0, -15, 0)
	_material.initial_velocity_min = 30.0
	_material.initial_velocity_max = 80.0
	_material.angular_velocity_min = -90.0
	_material.angular_velocity_max = 90.0
	
	# Much larger scale for visibility
	_material.scale_min = 3.0
	_material.scale_max = 6.0
	_material.color = Color(1.0, 0.95, 0.5, 1.0)
	
	_particles.texture = _create_sparkle_texture()

func _setup_fireflies():
	_particles.amount = 35
	_particles.lifetime = 10.0
	_particles.preprocess = 5.0
	_particles.randomness = 1.0
	_particles.visibility_rect = Rect2(-3000, -2000, 6000, 4000)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(2500, 1500, 0)
	_material.direction = Vector3(0, 0, 0)
	_material.spread = 180.0
	_material.gravity = Vector3(0, 0, 0)
	_material.initial_velocity_min = 15.0
	_material.initial_velocity_max = 35.0
	
	_material.turbulence_enabled = true
	_material.turbulence_noise_strength = 0.15
	_material.turbulence_noise_scale = 0.5
	_material.turbulence_influence_min = 0.1
	_material.turbulence_influence_max = 0.4
	
	# Much larger and brighter
	_material.scale_min = 4.0
	_material.scale_max = 8.0
	_material.color = Color(0.9, 1.0, 0.4, 1.0)
	
	_particles.texture = _create_glow_texture()

func _setup_falling_leaves():
	_particles.amount = 20
	_particles.lifetime = 10.0
	_particles.preprocess = 5.0
	_particles.randomness = 0.5
	_particles.visibility_rect = Rect2(-1000, -200, 2000, 800)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(800, 100, 0)
	_material.direction = Vector3(0, 1, 0)
	_material.spread = 20.0
	_material.gravity = Vector3(0, 8, 0)
	_material.initial_velocity_min = 15.0
	_material.initial_velocity_max = 35.0
	_material.angular_velocity_min = -45.0
	_material.angular_velocity_max = 45.0
	
	_material.turbulence_enabled = true
	_material.turbulence_noise_strength = 0.15
	_material.turbulence_noise_scale = 1.0
	
	_material.scale_min = 0.8
	_material.scale_max = 1.5
	_material.color = Color(0.9, 0.6, 0.2, 0.9)
	
	_particles.texture = _create_leaf_texture()

func _setup_snow():
	_particles.amount = 60
	_particles.lifetime = 6.0
	_particles.preprocess = 3.0
	_particles.randomness = 0.3
	_particles.visibility_rect = Rect2(-1000, -300, 2000, 1000)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(800, 100, 0)
	_material.direction = Vector3(0, 1, 0)
	_material.spread = 10.0
	_material.gravity = Vector3(0, 15, 0)
	_material.initial_velocity_min = 20.0
	_material.initial_velocity_max = 40.0
	
	_material.turbulence_enabled = true
	_material.turbulence_noise_strength = 0.1
	
	_material.scale_min = 0.5
	_material.scale_max = 1.2
	_material.color = Color(1.0, 1.0, 1.0, 0.8)
	
	_particles.texture = _create_snow_texture()

func _setup_dust():
	_particles.amount = 60
	_particles.lifetime = 8.0
	_particles.preprocess = 0.0
	_particles.randomness = 1.0
	_particles.visibility_rect = Rect2(-4000, -3000, 8000, 6000)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(3000, 2000, 100)
	
	# Simple drifting movement
	_material.direction = Vector3(1, 0.5, 0)
	_material.spread = 90.0
	_material.gravity = Vector3(0, 0, 0)
	_material.initial_velocity_min = 30.0
	_material.initial_velocity_max = 80.0
	
	# Orbit motion for swirling
	_material.orbit_velocity_min = 0.2
	_material.orbit_velocity_max = 0.5
	_material.orbit_velocity_curve = null
	
	_material.scale_min = 2.0
	_material.scale_max = 5.0
	_material.color = Color(1.0, 0.95, 0.7, 0.7)
	
	_particles.texture = _create_dot_texture(8, Color(1, 0.95, 0.7))
	
	print("[ParticleEffects] Dust setup: velocity=%d-%d" % [_material.initial_velocity_min, _material.initial_velocity_max])

func _setup_butterflies():
	_particles.amount = 20
	_particles.lifetime = 10.0
	_particles.preprocess = 5.0
	_particles.randomness = 0.7
	_particles.visibility_rect = Rect2(-3000, -2000, 6000, 4000)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(2000, 1500, 0)
	_material.direction = Vector3(0, 0, 0)
	_material.spread = 180.0
	_material.gravity = Vector3(0, -3, 0)
	_material.initial_velocity_min = 40.0
	_material.initial_velocity_max = 80.0
	
	_material.turbulence_enabled = true
	_material.turbulence_noise_strength = 0.2
	_material.turbulence_noise_scale = 0.8
	
	# Much larger for visibility
	_material.scale_min = 4.0
	_material.scale_max = 7.0
	_material.color = Color(0.5, 0.85, 1.0, 1.0)
	
	_particles.texture = _create_butterfly_texture()

func _setup_petals():
	_particles.amount = 40
	_particles.lifetime = 12.0
	_particles.preprocess = 6.0
	_particles.randomness = 0.4
	_particles.visibility_rect = Rect2(-3000, -1000, 6000, 4000)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(2500, 200, 0)
	_material.direction = Vector3(0, 1, 0)
	_material.spread = 30.0
	_material.gravity = Vector3(0, 8, 0)
	_material.initial_velocity_min = 20.0
	_material.initial_velocity_max = 40.0
	_material.angular_velocity_min = -45.0
	_material.angular_velocity_max = 45.0
	
	_material.turbulence_enabled = true
	_material.turbulence_noise_strength = 0.1
	
	# Much larger petals
	_material.scale_min = 4.0
	_material.scale_max = 8.0
	_material.color = Color(1.0, 0.8, 0.9, 0.95)
	
	_particles.texture = _create_petal_texture()

func _setup_rain():
	_particles.amount = 150
	_particles.lifetime = 1.2
	_particles.preprocess = 0.6
	_particles.randomness = 0.2
	_particles.visibility_rect = Rect2(-1000, -400, 2000, 1200)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(800, 100, 0)
	_material.direction = Vector3(0, 1, 0)
	_material.spread = 5.0
	_material.gravity = Vector3(0, 80, 0)
	_material.initial_velocity_min = 150.0
	_material.initial_velocity_max = 200.0
	
	_material.scale_min = 0.5
	_material.scale_max = 1.0
	_material.color = Color(0.75, 0.85, 1.0, 0.6)
	
	_particles.texture = _create_rain_texture()

func _setup_stars():
	_particles.amount = 30
	_particles.lifetime = 3.0
	_particles.preprocess = 1.5
	_particles.explosiveness = 0.5
	_particles.randomness = 0.8
	_particles.visibility_rect = Rect2(-600, -300, 1200, 600)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_material.emission_sphere_radius = 200.0
	_material.direction = Vector3(0, 0, 0)
	_material.spread = 180.0
	_material.gravity = Vector3(0, 0, 0)
	_material.initial_velocity_min = 5.0
	_material.initial_velocity_max = 15.0
	
	_material.scale_min = 0.5
	_material.scale_max = 2.0
	_material.color = Color(1.0, 1.0, 0.95, 0.9)
	
	_particles.texture = _create_star_texture()

func _setup_fog():
	_particles.amount = 20
	_particles.lifetime = 15.0
	_particles.preprocess = 7.0
	_particles.randomness = 0.3
	_particles.visibility_rect = Rect2(-800, -200, 1600, 400)
	
	_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_material.emission_box_extents = Vector3(600, 100, 0)
	_material.direction = Vector3(1, 0, 0)
	_material.spread = 30.0
	_material.gravity = Vector3(0, 0, 0)
	_material.initial_velocity_min = 10.0
	_material.initial_velocity_max = 25.0
	
	_material.scale_min = 3.0
	_material.scale_max = 6.0
	_material.color = Color(1.0, 1.0, 1.0, 0.2)
	
	_particles.texture = _create_fog_texture()

# ============ TEXTURE HELPERS ============

func _create_sparkle_texture() -> ImageTexture:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center = Vector2(15.5, 15.5)
	for y in range(32):
		for x in range(32):
			var dist = center.distance_to(Vector2(x, y))
			if dist < 12:
				var alpha = pow(1.0 - dist / 12.0, 2)
				# Cross shape for sparkle
				var is_center = abs(x - 15.5) < 2 or abs(y - 15.5) < 2
				var brightness = 1.0 if is_center else alpha * 0.6
				img.set_pixel(x, y, Color(1, 1, 0.8, alpha * brightness))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _create_glow_texture() -> ImageTexture:
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var center = Vector2(23.5, 23.5)
	for y in range(48):
		for x in range(48):
			var dist = center.distance_to(Vector2(x, y))
			if dist < 20:
				var alpha = pow(1.0 - dist / 20.0, 3)
				img.set_pixel(x, y, Color(1, 1, 0.6, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _create_leaf_texture() -> ImageTexture:
	var img = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	var center = Vector2(10, 16)
	for y in range(20):
		for x in range(20):
			var dx = (x - 10) / 8.0
			var dy = (y - 16) / 12.0
			var shape = 1.0 - (dx * dx + dy * dy)
			if shape > 0:
				var alpha = shape * 0.9
				img.set_pixel(x, y, Color(0.9, 0.6, 0.2, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _create_snow_texture() -> ImageTexture:
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	var center = Vector2(4.5, 4.5)
	for y in range(10):
		for x in range(10):
			var dist = center.distance_to(Vector2(x, y))
			if dist < 4:
				var alpha = 1.0 - dist / 4.0
				img.set_pixel(x, y, Color(1, 1, 1, alpha * 0.8))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _create_dot_texture(size: int, color: Color) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0 - 0.5, size / 2.0 - 0.5)
	for y in range(size):
		for x in range(size):
			var dist = center.distance_to(Vector2(x, y))
			if dist < size / 2.0:
				var alpha = 1.0 - dist / (size / 2.0)
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha * color.a))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _create_butterfly_texture() -> ImageTexture:
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var center = Vector2(24, 24)
	for y in range(48):
		for x in range(48):
			var dx = abs(x - 24)
			var dy = abs(y - 24)
			# Wing shape
			var wing = 1.0 - (dx * dx / 196.0 + dy * dy / 144.0)
			if wing > 0 and dx > 3:
				img.set_pixel(x, y, Color(0.5, 0.85, 1.0, wing * 0.95))
			elif dx <= 3 and dy < 16:
				img.set_pixel(x, y, Color(0.3, 0.6, 0.9, 0.95))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _create_petal_texture() -> ImageTexture:
	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var center = Vector2(24, 36)
	for y in range(48):
		for x in range(48):
			var dx = (x - 24) / 18.0
			var dy = (y - 36) / 30.0
			var shape = 1.0 - (dx * dx + dy * dy)
			if shape > 0:
				img.set_pixel(x, y, Color(1, 0.85, 0.9, shape * 0.9))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _create_rain_texture() -> ImageTexture:
	var img = Image.create(4, 12, false, Image.FORMAT_RGBA8)
	for y in range(12):
		var alpha = 1.0 - abs(y - 6) / 6.0
		img.set_pixel(1, y, Color(0.75, 0.85, 1.0, alpha * 0.6))
		img.set_pixel(2, y, Color(0.75, 0.85, 1.0, alpha * 0.6))
	return ImageTexture.create_from_image(img)

func _create_star_texture() -> ImageTexture:
	var img = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	var center = Vector2(9.5, 9.5)
	for y in range(20):
		for x in range(20):
			var dist = center.distance_to(Vector2(x, y))
			var angle = atan2(y - 9.5, x - 9.5)
			var star = cos(angle * 5) * 0.3 + 0.7
			if dist < 8 * star:
				var alpha = pow(1.0 - dist / (8 * star), 2)
				img.set_pixel(x, y, Color(1, 1, 0.95, alpha))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _create_fog_texture() -> ImageTexture:
	var img = Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(64):
			var dx = (x - 32) / 32.0
			var dy = (y - 16) / 16.0
			var shape = 1.0 - (dx * dx + dy * dy)
			if shape > 0:
				img.set_pixel(x, y, Color(1, 1, 1, shape * shape * 0.2))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

# ============ PUBLIC METHODS ============

func start():
	_particles.emitting = true

func stop():
	_particles.emitting = false

func set_intensity(value: float):
	intensity = clamp(value, 0.0, 2.0)
	_apply_intensity()

func fade_in(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(self, "intensity", 1.0, duration).from(0.0)
	_particles.emitting = true

func fade_out(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(self, "intensity", 0.0, duration)
	tween.tween_callback(func(): _particles.emitting = false)
