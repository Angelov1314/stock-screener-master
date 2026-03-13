class_name DraggableCamera
extends Camera2D

## Camera that can be dragged with mouse/touch
## Designed for 4x zoomed farm background

@export var drag_speed: float = 1.0
@export var edge_scroll_margin: int = 50
@export var edge_scroll_speed: float = 500.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0

var _is_dragging: bool = false
var _last_mouse_pos: Vector2
var _drag_start_pos: Vector2

func _ready():
	print("[DraggableCamera] Initialized")
	print("[DraggableCamera] Limits: %d x %d" % [limit_right, limit_bottom])

func _input(event):
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom += Vector2.ONE * zoom_speed
			_clamp_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom -= Vector2.ONE * zoom_speed
			_clamp_zoom()
		# Mouse drag with left button
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_drag_start_pos = event.position
				_last_mouse_pos = event.position
			else:
				_is_dragging = false
	
	# Touch drag (mobile)
	if event is InputEventScreenTouch:
		if event.pressed:
			_is_dragging = true
			_last_mouse_pos = event.position
		else:
			_is_dragging = false

func _process(delta):
	_handle_drag(delta)
	_handle_edge_scroll(delta)

func _handle_drag(delta: float):
	if not _is_dragging:
		return
	
	var current_mouse_pos = get_viewport().get_mouse_position()
	var delta_pos = current_mouse_pos - _last_mouse_pos
	
	# Invert movement (dragging moves the camera opposite to mouse)
	position -= delta_pos * drag_speed / zoom.x
	
	# Clamp to limits
	_clamp_position()
	
	_last_mouse_pos = current_mouse_pos

func _handle_edge_scroll(delta: float):
	if _is_dragging:
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport().size
	var scroll_dir = Vector2.ZERO
	
	# Check edges
	if mouse_pos.x < edge_scroll_margin:
		scroll_dir.x = -1
	elif mouse_pos.x > viewport_size.x - edge_scroll_margin:
		scroll_dir.x = 1
	
	if mouse_pos.y < edge_scroll_margin:
		scroll_dir.y = -1
	elif mouse_pos.y > viewport_size.y - edge_scroll_margin:
		scroll_dir.y = 1
	
	if scroll_dir != Vector2.ZERO:
		position += scroll_dir * edge_scroll_speed * delta / zoom.x
		_clamp_position()

func _clamp_zoom():
	zoom.x = clamp(zoom.x, min_zoom, max_zoom)
	zoom.y = clamp(zoom.y, min_zoom, max_zoom)

func _clamp_position():
	var viewport_size = Vector2(get_viewport().size) / zoom
	
	# Clamp position considering camera size
	position.x = clamp(position.x, limit_left, limit_right - viewport_size.x)
	position.y = clamp(position.y, limit_top, limit_bottom - viewport_size.y)

## Public methods
func center_on_world():
	var viewport_size = Vector2(get_viewport().size)
	position = Vector2(
		(limit_right - viewport_size.x) / 2,
		(limit_bottom - viewport_size.y) / 2
	)

func center_on_point(world_pos: Vector2):
	var viewport_size = Vector2(get_viewport().size) / zoom
	position = world_pos - viewport_size / 2
	_clamp_position()

func set_zoom_level(zoom_level: float):
	zoom = Vector2.ONE * clamp(zoom_level, min_zoom, max_zoom)
