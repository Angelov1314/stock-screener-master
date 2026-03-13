extends Node2D

## Animates all Sprite2D children that have hframes > 1 using the AnimTimer.

func _ready() -> void:
	$AnimTimer.timeout.connect(_on_timer)

func _on_timer() -> void:
	for child in get_children():
		if child is Sprite2D and child.hframes > 1:
			child.frame = (child.frame + 1) % child.hframes
