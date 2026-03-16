extends Node2D

## Firefly Effect - Glowing fireflies for level 3

@export var firefly_count: int = 30
@export var spawn_area: Vector2 = Vector2(6144, 11008)
@export var refresh_interval: float = 30.0  # Refresh every 30 seconds

var _fireflies: Array = []
var _refresh_timer: Timer

func _ready():
	print("[FireflyEffect] Initializing %d fireflies..." % firefly_count)
	_setup_fireflies()
	_setup_refresh_timer()

func _setup_fireflies():
	for i in range(firefly_count):
		var firefly = Sprite2D.new()
		firefly.name = "Firefly_%d" % i
		
		# Create glowing yellow-green firefly texture
		var size = 16
		var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		
		# Draw glowing dot
		for x in range(size):
			for y in range(size):
				var dist = Vector2(x - size/2, y - size/2).length()
				if dist < size/2 - 1:
					var alpha = 1.0 - (dist / (size/2 - 1))
					# Yellow-green color (firefly glow)
					img.set_pixel(x, y, Color(0.9, 1.0, 0.3, alpha))
		
		firefly.texture = ImageTexture.create_from_image(img)
		
		# Random position across the map
		firefly.position = Vector2(
			randf() * spawn_area.x,
			randf() * spawn_area.y
		)
		
		# Scale variation
		var scale = 1.0 + randf() * 1.5
		firefly.scale = Vector2(scale, scale)
		
		add_child(firefly)
		
		_fireflies.append({
			"node": firefly,
			"base_pos": firefly.position,
			"speed": 5.0 + randf() * 15.0,
			"wobble": randf() * 3.0,
			"glow_speed": 1.0 + randf() * 2.0,
			"time_offset": randf() * 100.0,
			"radius": 50.0 + randf() * 100.0
		})
	
	print("[FireflyEffect] Created %d fireflies" % firefly_count)

func _setup_refresh_timer():
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = refresh_interval
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_refresh_fireflies)
	add_child(_refresh_timer)
	print("[FireflyEffect] Refresh timer started (every %.0f seconds)" % refresh_interval)

func _refresh_fireflies():
	print("[FireflyEffect] Refreshing fireflies...")
	for f in _fireflies:
		var node = f["node"]
		# Reset position to random location
		f["base_pos"] = Vector2(randf() * spawn_area.x, randf() * spawn_area.y)
		node.position = f["base_pos"]
		# Ensure visibility
		node.visible = true
		node.modulate.a = 0.5

func _process(delta):
	var time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60.0
	
	for f in _fireflies:
		var node = f["node"]
		var speed = f["speed"]
		var wobble = f["wobble"]
		var glow_speed = f["glow_speed"]
		var offset = f["time_offset"]
		var radius = f["radius"]
		var base_pos = f["base_pos"]
		
		# Gentle floating movement in circles
		var angle = time * speed * 0.01 + offset
		var float_x = cos(angle) * radius * 0.5
		var float_y = sin(angle * 0.7) * radius * 0.3
		
		node.position = base_pos + Vector2(float_x, float_y)
		
		# Pulsing glow effect
		var glow = 0.5 + 0.5 * sin(time * glow_speed + offset)
		node.modulate.a = 0.4 + glow * 0.6
		node.modulate.r = 0.8 + glow * 0.2
		node.modulate.g = 0.9 + glow * 0.1
		
		# Wrap around if too far
		if node.position.x > spawn_area.x:
			f["base_pos"].x -= spawn_area.x
		if node.position.x < 0:
			f["base_pos"].x += spawn_area.x
		if node.position.y > spawn_area.y:
			f["base_pos"].y -= spawn_area.y
		if node.position.y < 0:
			f["base_pos"].y += spawn_area.y
