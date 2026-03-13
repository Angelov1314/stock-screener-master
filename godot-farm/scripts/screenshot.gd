extends Node

func _ready():
	await get_tree().create_timer(3.0).timeout
	var image = get_viewport().get_texture().get_image()
	image.save_png("/tmp/godot_internal_screenshot.png")
	print("Screenshot saved!")
	get_tree().quit()
