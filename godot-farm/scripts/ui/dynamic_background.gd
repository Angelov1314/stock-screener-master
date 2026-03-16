extends Node2D

## Dynamic Background - Adds subtle movement and life to the farm background

@export var cloud_speed: float = 20.0
@export var particle_count: int = 15

var _clouds: Array[Sprite2D] = []
var _particles: Array[Node2D] = []

func _ready():
	print("[DynamicBackground] Initializing...")
	print("[DynamicBackground] Parent: %s" % str(get_parent()))
	_setup_clouds()
	_setup_particles()
	print("[DynamicBackground] Initialized with %d clouds and %d particles" % [_clouds.size(), _particles.size()])

func _setup_clouds():
	# Create floating clouds - more visible
	for i in range(3):
		var cloud = Sprite2D.new()
		cloud.name = "Cloud_%d" % i
		
		# Create larger, more opaque cloud texture
		var width = 300
		var height = 120
		var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		
		# Draw cloud shape - multiple circles for fluffy look
		var centers = [Vector2(80, 60), Vector2(150, 50), Vector2(220, 65)]
		var radii = [50, 60, 45]
		
		for x in range(width):
			for y in range(height):
				var max_alpha = 0.0
				for ci in range(centers.size()):
					var dist = Vector2(x, y).distance_to(centers[ci])
					if dist < radii[ci]:
						var alpha = 0.5 * (1.0 - dist / radii[ci])  # 更高不透明度
						max_alpha = max(max_alpha, alpha)
				img.set_pixel(x, y, Color(1, 1, 1, max_alpha))
		
		cloud.texture = ImageTexture.create_from_image(img)
		cloud.position = Vector2(randf() * 5000 + 500, randf() * 800 + 300)
		cloud.modulate = Color(1, 1, 1, 0.6)  # 更不透明
		cloud.scale = Vector2(3 + randf() * 2, 2 + randf())
		
		add_child(cloud)
		_clouds.append(cloud)
		
	print("[DynamicBackground] Created %d clouds" % _clouds.size())

func _setup_particles():
	# Create floating dust/pollen particles - make them more visible
	for i in range(particle_count):
		var particle = Sprite2D.new()
		particle.name = "Particle_%d" % i
		
		# Create larger, brighter glowing dot
		var size = 12  # 更大的粒子
		var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 0.8, 0))
		for x in range(size):
			for y in range(size):
				var dist = Vector2(x - size/2, y - size/2).length()
				if dist < size/2 - 1:
					var alpha = 0.8 * (1.0 - dist / (size/2 - 1))  # 更高的不透明度
					img.set_pixel(x, y, Color(1, 1, 0.9, alpha))
		
		particle.texture = ImageTexture.create_from_image(img)
		particle.position = Vector2(randf() * 6000, randf() * 10000)
		particle.modulate = Color(1, 1, 0.6, 0.6 + randf() * 0.4)  # 更亮
		particle.scale = Vector2(2, 2)  # 放大
		
		add_child(particle)
		_particles.append({
			"node": particle,
			"speed": Vector2(randf() * 40 - 20, randf() * 30 - 15),
			"wobble": randf() * 2.0,
			"time_offset": randf() * 10.0
		})
	
	print("[DynamicBackground] Created %d particles" % particle_count)

func _process(delta):
	# Move clouds slowly
	for i in range(_clouds.size()):
		var cloud = _clouds[i]
		cloud.position.x += cloud_speed * delta * (0.5 + i * 0.2)
		
		# Wrap around
		if cloud.position.x > 7000:
			cloud.position.x = -500
	
	# Animate particles
	var time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60
	
	for p in _particles:
		var node = p["node"]
		var speed = p["speed"]
		var wobble = p["wobble"]
		var offset = p["time_offset"]
		
		# Drift with slight wobble
		var wobble_x = sin(time * 0.5 + offset) * 10 * wobble
		var wobble_y = cos(time * 0.3 + offset) * 5 * wobble
		
		node.position += speed * delta
		node.position += Vector2(wobble_x, wobble_y) * delta
		
		# Fade in/out
		var alpha = 0.3 + 0.2 * sin(time * 0.2 + offset)
		node.modulate.a = alpha
		
		# Wrap around
		if node.position.x > 6500:
			node.position.x = -100
		if node.position.x < -100:
			node.position.x = 6500
		if node.position.y > 11000:
			node.position.y = -100
		if node.position.y < -100:
			node.position.y = 11000
