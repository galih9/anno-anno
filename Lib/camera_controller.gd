# camera_controller.gd
# Attach this script to a Camera2D node in Main.tscn.
#
# Features:
#   - Scroll wheel zooms in / out (clamped between MIN_ZOOM and MAX_ZOOM)
#   - Moving the cursor within EDGE_MARGIN pixels of any viewport edge
#     pans the camera in that direction (speed scales with proximity)
#   - Holding Right Mouse Button (RMB) drags/pans the camera view.
#   - Control toggles for edge pan & RMB drag pan.

extends Camera2D

# ─── Control Toggles ──────────────────────────────────────────────────────────

## Enable or disable edge cursor panning.
@export var enable_edge_pan: bool = true

## Enable or disable holding right click to drag pan camera.
@export var enable_right_click_pan: bool = true

# ─── Zoom ─────────────────────────────────────────────────────────────────────

## How much each scroll-wheel tick changes the zoom level.
@export var zoom_step: float = 0.1

## Smallest zoom (most zoomed-OUT). Zoom values > 1 mean "zoomed in" in Godot.
@export var min_zoom: float = 0.5

## Largest zoom (most zoomed-IN).
@export var max_zoom: float = 3.0

## Smoothing factor for zoom interpolation (0 = instant, higher = smoother).
@export var zoom_smooth: float = 10.0

# ─── Edge Panning ─────────────────────────────────────────────────────────────

## Pixel band at the viewport edge that triggers panning.
@export var edge_margin: int = 20

## Maximum pan speed in pixels/second (at the very edge of the screen).
@export var pan_speed: float = 200.0

# ─── Internal ─────────────────────────────────────────────────────────────────

var _target_zoom: float = 1.0
var _is_dragging_rmb: bool = false

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_target_zoom = zoom.x          # start at whatever zoom is set in the scene


func _process(delta: float) -> void:
	if not get_tree().paused:
		_handle_edge_pan(delta)
	_smooth_zoom(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				if get_viewport().gui_get_hovered_control() == null:
					_is_dragging_rmb = true
			else:
				_is_dragging_rmb = false
		elif mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if get_viewport().gui_get_hovered_control() != null:
					return
				if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					_target_zoom = clamp(_target_zoom + zoom_step, min_zoom, max_zoom)
					get_viewport().set_input_as_handled()
				elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_target_zoom = clamp(_target_zoom - zoom_step, min_zoom, max_zoom)
					get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _is_dragging_rmb:
		if enable_right_click_pan:
			var mm := event as InputEventMouseMotion
			position -= mm.relative / zoom.x
			get_viewport().set_input_as_handled()

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _handle_edge_pan(delta: float) -> void:
	if not enable_edge_pan or _is_dragging_rmb:
		return

	var vp_size: Vector2 = get_viewport_rect().size
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	var direction: Vector2 = Vector2.ZERO

	# Horizontal
	if mouse_pos.x < edge_margin:
		# strength goes from 1.0 (very edge) → 0.0 (at margin boundary)
		direction.x -= 1.0 - (mouse_pos.x / float(edge_margin))
	elif mouse_pos.x > vp_size.x - edge_margin:
		direction.x += 1.0 - ((vp_size.x - mouse_pos.x) / float(edge_margin))

	# Vertical
	if mouse_pos.y < edge_margin:
		direction.y -= 1.0 - (mouse_pos.y / float(edge_margin))
	elif mouse_pos.y > vp_size.y - edge_margin:
		direction.y += 1.0 - ((vp_size.y - mouse_pos.y) / float(edge_margin))

	if direction != Vector2.ZERO:
		# Pan speed is inversely proportional to current zoom so it feels
		# consistent regardless of how far in/out the camera is.
		var effective_speed: float = pan_speed / zoom.x
		position += direction * effective_speed * delta


func _smooth_zoom(delta: float) -> void:
	var current_zoom: float = zoom.x
	if not is_equal_approx(current_zoom, _target_zoom):
		var new_zoom: float = lerp(current_zoom, _target_zoom, zoom_smooth * delta)
		zoom = Vector2(new_zoom, new_zoom)

