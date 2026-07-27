class_name InfluenceHighlightOverlay
extends Node2D

var _active: bool = false
var _bounds_min: Vector2 = Vector2.ZERO
var _bounds_max: Vector2 = Vector2.ZERO
var _land_layer: TileMapLayer = null

func _ready() -> void:
	z_index = 2
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 bounds_min;
uniform vec2 bounds_max;
uniform float darken_alpha = 0.55;
uniform vec4 highlight_color = vec4(1.0, 1.0, 1.0, 0.05);
uniform bool active = false;

uniform vec2 trans_x;
uniform vec2 trans_y;
uniform vec2 trans_origin;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (!active) {
		COLOR = vec4(0.0);
	} else {
		vec2 map_pos = vec2(
			world_pos.x * trans_x.x + world_pos.y * trans_y.x + trans_origin.x,
			world_pos.x * trans_x.y + world_pos.y * trans_y.y + trans_origin.y
		);
		
		vec2 center = (bounds_min + bounds_max) * 0.5;
		vec2 half_size = (bounds_max - bounds_min) * 0.5;
		
		vec2 d = abs(map_pos - center) - half_size;
		float dist = max(d.x, d.y);
		
		float t = smoothstep(0.0, 0.05, dist);
		
		vec4 outside_color = vec4(0.0, 0.0, 0.0, darken_alpha);
		COLOR = mix(highlight_color, outside_color, t);
	}
}
"""
	material = ShaderMaterial.new()
	material.shader = shader
	set_process(true)

func set_target(cells: Array[Vector2i], radius: int, land_layer: TileMapLayer) -> void:
	_land_layer = land_layer
	if cells.is_empty() or land_layer == null:
		_active = false
		if material:
			material.set_shader_parameter("active", false)
		return
		
	var min_x = 9999999
	var max_x = -9999999
	var min_y = 9999999
	var max_y = -9999999
	
	for c in cells:
		if c.x < min_x: min_x = c.x
		if c.x > max_x: max_x = c.x
		if c.y < min_y: min_y = c.y
		if c.y > max_y: max_y = c.y
		
	_bounds_min = Vector2(min_x - radius - 0.5, min_y - radius - 0.5)
	_bounds_max = Vector2(max_x + radius + 0.5, max_y + radius + 0.5)
	_active = true
	
	if material:
		material.set_shader_parameter("active", true)
		material.set_shader_parameter("bounds_min", _bounds_min)
		material.set_shader_parameter("bounds_max", _bounds_max)
		
		var p0 = land_layer.map_to_local(Vector2i(0, 0))
		var px = land_layer.map_to_local(Vector2i(1, 0))
		var py = land_layer.map_to_local(Vector2i(0, 1))
		
		var m_to_l = Transform2D(px - p0, py - p0, p0)
		var local_to_map = m_to_l.affine_inverse()
		
		var world_to_map = local_to_map * land_layer.global_transform.affine_inverse()
		material.set_shader_parameter("trans_x", world_to_map.x)
		material.set_shader_parameter("trans_y", world_to_map.y)
		material.set_shader_parameter("trans_origin", world_to_map.origin)

func deactivate() -> void:
	_active = false
	if material:
		material.set_shader_parameter("active", false)
	queue_redraw()

func _process(_delta: float) -> void:
	if _active:
		queue_redraw()

func _draw() -> void:
	if not _active:
		return
		
	var cam = get_viewport().get_camera_2d()
	if cam:
		var canvas_transform = get_viewport().get_canvas_transform()
		var inverse_transform = canvas_transform.affine_inverse()
		var vrect = get_viewport().get_visible_rect()
		
		var top_left = inverse_transform * vrect.position
		var bottom_right = inverse_transform * (vrect.position + vrect.size)
		
		var rect = Rect2(to_local(top_left), to_local(bottom_right) - to_local(top_left))
		rect = rect.grow(200) # Overshoot safely
		
		draw_rect(rect, Color.WHITE)
