class_name LightManager
extends Node2D

## Manages animated lights across the farm
## Creates atmospheric lighting at key locations

@export var num_lights: int = 5
@export var light_color: Color = Color(1.0, 0.85, 0.6, 1.0)  # Warm lantern color

# Predefined positions for lights (you can adjust these)
@export var light_positions: Array[Vector2] = [
	Vector2(1000, 1000),
	Vector2(3000, 2000),
	Vector2(5000, 1500),
	Vector2(2000, 4000),
	Vector2(4500, 5000)
]

var _lights: Array[AnimatedLight] = []

func _ready():
	_spawn_lights()

func _spawn_lights():
	for i in range(min(num_lights, light_positions.size())):
		var light = AnimatedLight.new()
		light.name = "Light_%d" % i
		light.position = light_positions[i]
		
		# Vary the color slightly for each light
		var color_variation = light_color
		color_variation.h += randf_range(-0.05, 0.05)
		color_variation.s += randf_range(-0.1, 0.1)
		light.light_color = color_variation
		
		# Vary the breathing speed
		light.breathe_speed = randf_range(1.5, 3.0)
		
		add_child(light)
		_lights.append(light)
	
	print("[LightManager] Spawned %d animated lights" % _lights.size())

## Toggle all lights
func set_all_lights(enabled: bool):
	for light in _lights:
		if enabled:
			light.start()
		else:
			light.stop()

## Fade all lights
func fade_all_in(duration: float = 1.0):
	for light in _lights:
		light.fade_in(duration)

func fade_all_out(duration: float = 1.0):
	for light in _lights:
		light.fade_out(duration)

## Day/Night cycle
func set_night_mode():
	# Brighter, warmer lights at night
	for light in _lights:
		light.set_energy(1.5)
		light.set_color(Color(1.0, 0.8, 0.5))

func set_day_mode():
	# Dimmer lights during day
	for light in _lights:
		light.set_energy(0.5)
		light.set_color(Color(1.0, 0.9, 0.8))
