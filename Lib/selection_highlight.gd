# selection_highlight.gd
# Attach to or instantiate inside PlacementManager.
#
# Draws a sleek, pulsing cyan highlight over the tile cells occupied by
# the currently selected building.

class_name SelectionHighlight
extends Node2D

var _target_building: Node2D = null
var _target_cells: Array[Vector2i] = []
var _land_layer: TileMapLayer = null

func setup(land_layer: TileMapLayer) -> void:
	_land_layer = land_layer
	z_index = 5

func set_target(building: Node2D, cells: Array[Vector2i]) -> void:
	_target_building = building
	_target_cells = cells
	queue_redraw()

func clear() -> void:
	_target_building = null
	_target_cells.clear()
	queue_redraw()

func _process(_delta: float) -> void:
	if _target_building != null and visible:
		queue_redraw()

func _draw() -> void:
	if _target_building == null or _target_cells.is_empty() or _land_layer == null:
		return

	var tile_size := Vector2(16, 16)
	if _land_layer.tile_set != null:
		tile_size = Vector2(_land_layer.tile_set.tile_size)

	# Pulse opacity smoothly over time
	var pulse := 0.6 + 0.3 * sin(Time.get_ticks_msec() * 0.006)
	var stroke_color := Color(0.2, 0.85, 1.0, pulse)
	var fill_color   := Color(0.2, 0.85, 1.0, pulse * 0.25)
	var corner_color := Color(1.0, 1.0, 1.0, pulse * 0.9)

	for cell in _target_cells:
		var local_cell_center := _land_layer.map_to_local(cell)
		var global_cell_center := _land_layer.to_global(local_cell_center)
		var node_local_pos := to_local(global_cell_center)

		var rect := Rect2(node_local_pos - tile_size / 2.0, tile_size)
		draw_rect(rect, fill_color, true)
		draw_rect(rect, stroke_color, false, 1.5)

		# Draw subtle white corner indicators for extra polish
		var c_size := 3.0
		# Top-Left corner
		draw_line(rect.position, rect.position + Vector2(c_size, 0), corner_color, 1.5)
		draw_line(rect.position, rect.position + Vector2(0, c_size), corner_color, 1.5)
		# Top-Right corner
		var tr := rect.position + Vector2(rect.size.x, 0)
		draw_line(tr, tr + Vector2(-c_size, 0), corner_color, 1.5)
		draw_line(tr, tr + Vector2(0, c_size), corner_color, 1.5)
		# Bottom-Left corner
		var bl := rect.position + Vector2(0, rect.size.y)
		draw_line(bl, bl + Vector2(c_size, 0), corner_color, 1.5)
		draw_line(bl, bl + Vector2(0, -c_size), corner_color, 1.5)
		# Bottom-Right corner
		var br := rect.position + rect.size
		draw_line(br, br + Vector2(-c_size, 0), corner_color, 1.5)
		draw_line(br, br + Vector2(0, -c_size), corner_color, 1.5)
