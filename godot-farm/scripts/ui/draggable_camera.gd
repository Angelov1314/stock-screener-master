class_name DraggableCamera
extends Camera2D

## Camera that can be dragged with mouse/touch
## Map fills the viewport, no empty space, can drag to see more

@export var drag_speed: float = 1.0
@export var zoom_speed: float = 0.1
@export var max_zoom: float = 3.0

# Map boundaries
var _map_width: float = 6144.0
var _map_height: float = 11008.0

var _is_dragging: bool = false
var _last_mouse_pos: Vector2

func _ready():
	print("[DraggableCamera] Initialized")
	
	# Set initial zoom to fit map height (show full map vertically)
	_fit_map_height()
	
	# Connect to viewport changes
	get_viewport().size_changed.connect(_fit_map_height)

## Fit map to viewport height - fills the screen vertically
func _fit_map_height():
	var viewport_size = Vector2(get_viewport().size)
	
	# Calculate zoom to fit map height exactly
	var target_zoom = viewport_size.y / _map_height
	zoom = Vector2.ONE * target_zoom
	
	# Center horizontally, align top vertically
	position.x = -(_map_width * zoom.x - viewport_size.x) / 2
	position.y = 0
	
	print("[DraggableCamera] Zoom: %.3f, Position: %s" % [zoom.x, str(position)])

## Check if tools are active
func _is_tool_mode_active() -> bool:
	var hud = get_node_or_null("/root/Main/HUD")
	if hud and hud.has_method("is_sickle_mode"):
		return hud.is_sickle_mode() or hud.is_water_mode()
	return false

func _input(event):
	if event is InputEventMouseButton:
		# Mouse wheel zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_camera(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(-zoom_speed)
		
		# Drag start/stop
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not _is_tool_mode_active():
				_is_dragging = event.pressed
				if event.pressed:
					_last_mouse_pos = event.position
					
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
			if event.pressed:
				_last_mouse_pos = event.position

func _zoom_camera(delta: float):
	var new_zoom = clamp(zoom.x + delta, _get_min_zoom(), max_zoom)
	zoom = Vector2.ONE * new_zoom
	_clamp_position()

func _get_min_zoom() -> float:
	var viewport_size = Vector2(get_viewport().size)
	return viewport_size.y / _map_height

func _process(delta: float):
	if _is_dragging:
		var mouse_pos = get_viewport().get_mouse_position()
		var mouse_delta = mouse_pos - _last_mouse_pos
		position -= mouse_delta / zoom.x
		_last_mouse_pos = mouse_pos
		_clamp_position()

## Clamp position so we never see outside the map
func _clamp_position():
	var viewport_size = Vector2(get_viewport().size) / zoom
	
	# Horizontal: can pan if map is wider than viewport
	var min_x = -(_map_width * zoom.x - viewport_size.x) / 2
	var max_x = min_x
	
	if _map_width * zoom.x > viewport_size.x:
		min_x = -(_map_width - viewport_size.x)
		max_x = 0
	
	position.x = clamp(position.x, min_x, max_x)
	
	# Vertical: can pan if map is taller than viewport
	var min_y = 0
	var max_y = _map_height - viewport_size.y
	
	if max_y < 0:
		max_y = 0
	
	position.y = clamp(position.y, min_y, max_y)
