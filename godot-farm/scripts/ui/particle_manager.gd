class_name ParticleManager
extends Node2D

## Manages particle effects in the farm
## Easy to add/remove different ambient effects

@export var effects: Array[ParticleEffects.EffectType] = [
	ParticleEffects.EffectType.DUST_MOTES
]

var _active_effects: Array[ParticleEffects] = []

func _ready():
	_spawn_effects()

func _spawn_effects():
	print("[ParticleManager] Spawning effects: %s" % str(effects))
	for effect_type in effects:
		var effect = ParticleEffects.new()
		effect.name = "Effect_%s" % _get_effect_name(effect_type)
		effect.effect_type = effect_type
		effect.position = _get_effect_position(effect_type)
		add_child(effect)
		_active_effects.append(effect)
		print("[ParticleManager] Added effect at %s" % str(effect.position))
	
	print("[ParticleManager] Total effects: %d" % _active_effects.size())

func _get_effect_name(type: ParticleEffects.EffectType) -> String:
	match type:
		ParticleEffects.EffectType.MAGIC_SPARKLES: return "Magic"
		ParticleEffects.EffectType.FIRE_FLIES: return "Fireflies"
		ParticleEffects.EffectType.FALLING_LEAVES: return "Leaves"
		ParticleEffects.EffectType.SNOW_GENTLE: return "Snow"
		ParticleEffects.EffectType.DUST_MOTES: return "Dust"
		ParticleEffects.EffectType.BUTTERFLIES: return "Butterflies"
		ParticleEffects.EffectType.PETALS_SAKURA: return "Petals"
		ParticleEffects.EffectType.RAIN_DROPS: return "Rain"
		ParticleEffects.EffectType.STARS_TWINKLE: return "Stars"
		ParticleEffects.EffectType.FOG_MIST: return "Fog"
		_: return "Unknown"

func _get_effect_position(type: ParticleEffects.EffectType) -> Vector2:
	# Center of farm area
	var center = Vector2(3072, 5504)
	
	match type:
		ParticleEffects.EffectType.PETALS_SAKURA, \
		ParticleEffects.EffectType.FALLING_LEAVES, \
		ParticleEffects.EffectType.SNOW_GENTLE, \
		ParticleEffects.EffectType.RAIN_DROPS:
			# These fall from above
			return Vector2(center.x, -200)
		ParticleEffects.EffectType.FOG_MIST:
			# Fog near ground
			return Vector2(center.x, 9000)
		ParticleEffects.EffectType.DUST_MOTES:
			# Dust covers entire farm area
			return center
		_:
			# Others spawn in middle area
			return center

## Add a new effect
func add_effect(type: ParticleEffects.EffectType):
	var effect = ParticleEffects.new()
	effect.name = "Effect_%s" % _get_effect_name(type)
	effect.effect_type = type
	effect.position = _get_effect_position(type)
	add_child(effect)
	_active_effects.append(effect)

## Remove all effects of a type
func remove_effect(type: ParticleEffects.EffectType):
	for effect in _active_effects:
		if effect.effect_type == type:
			effect.queue_free()
			_active_effects.erase(effect)
			break

## Clear all effects
func clear_all():
	for effect in _active_effects:
		effect.queue_free()
	_active_effects.clear()

## Preset combinations
func set_spring():
	clear_all()
	add_effect(ParticleEffects.EffectType.PETALS_SAKURA)
	add_effect(ParticleEffects.EffectType.BUTTERFLIES)
	add_effect(ParticleEffects.EffectType.DUST_MOTES)

func set_autumn():
	clear_all()
	add_effect(ParticleEffects.EffectType.FALLING_LEAVES)
	add_effect(ParticleEffects.EffectType.DUST_MOTES)

func set_winter():
	clear_all()
	add_effect(ParticleEffects.EffectType.SNOW_GENTLE)
	add_effect(ParticleEffects.EffectType.FOG_MIST)

func set_night():
	clear_all()
	add_effect(ParticleEffects.EffectType.FIRE_FLIES)
	add_effect(ParticleEffects.EffectType.STARS_TWINKLE)

func set_magic():
	clear_all()
	add_effect(ParticleEffects.EffectType.MAGIC_SPARKLES)
	add_effect(ParticleEffects.EffectType.STARS_TWINKLE)
	add_effect(ParticleEffects.EffectType.DUST_MOTES)

func set_rainy():
	clear_all()
	add_effect(ParticleEffects.EffectType.RAIN_DROPS)
	add_effect(ParticleEffects.EffectType.FOG_MIST)
