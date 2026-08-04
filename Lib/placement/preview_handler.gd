# preview_handler.gd
# Attach as a child Node under PlacementManager.
#
# Single responsibility: manage the ghost preview sprite in placement mode and the
# isometric red hover highlight in demolish mode.

class_name PreviewHandler
extends Node

# ─── Constants ────────────────────────────────────────────────────────────────

const ALPHA: float = 0.55
const COLOR_VALID:   Color = Color(0.0, 1.0, 0.0, ALPHA)
const COLOR_INVALID: Color = Color(1.0, 0.0, 0.0, ALPHA)

# ─── Internal ─────────────────────────────────────────────────────────────────

var _sprite: Sprite2D
var _highlight_node: Node2D
var _demolish_mode: bool = false
var _visible: bool = false

# ─── Setup ────────────────────────────────────────────────────────────────────

## Create the preview Sprite2D and highlight overlay child nodes on [param scene_parent].
func setup(scene_parent: Node) -> void:
	_sprite = Sprite2D.new()
	_sprite.name     = "PreviewSprite"
	_sprite.modulate = COLOR_VALID
	_sprite.z_index  = 3
	_sprite.visible  = false
	scene_parent.add_child(_sprite)

	_highlight_node = DemolishHighlightOverlay.new()
	_highlight_node.name    = "DemolishHighlightOverlay"
	_highlight_node.z_index = 6
	_highlight_node.visible = false
	scene_parent.add_child(_highlight_node)

# ─── Public API ───────────────────────────────────────────────────────────────

## Swap the preview texture and offset to match [param data].
func set_building(data: BuildingData) -> void:
	if _sprite == null:
		return
	if data != null:
		_sprite.texture = data.preview_texture
		_sprite.offset  = data.sprite_offset
	else:
		_sprite.texture = null


## Move the preview to [param world_pos] (global coordinates).
func update_position(world_pos: Vector2) -> void:
	if _sprite != null:
		_sprite.global_position = world_pos


## Tint the preview green (valid) or red (invalid).
func set_valid(is_valid: bool) -> void:
	if _sprite == null:
		return
	_sprite.modulate = COLOR_VALID if is_valid else COLOR_INVALID


## Show or hide the preview elements.
func set_preview_visible(value: bool) -> void:
	_visible = value
	if _sprite != null:
		_sprite.visible = _visible and not _demolish_mode
	if _highlight_node != null:
		_highlight_node.visible = _visible and _demolish_mode


## Set the ghost sprite rotation in degrees.
func set_rotation_deg(deg: float) -> void:
	if _sprite == null:
		return
	_sprite.rotation_degrees = deg


## Enable or disable demolish mode visuals.
func set_demolish_mode(enabled: bool) -> void:
	_demolish_mode = enabled
	if _sprite != null:
		_sprite.visible = _visible and not _demolish_mode
	if _highlight_node != null:
		_highlight_node.visible = _visible and _demolish_mode
		if not _demolish_mode:
			(_highlight_node as DemolishHighlightOverlay).clear()


## Set the cells to highlight with red demolish indicator.
func set_demolish_highlight(cells: Array[Vector2i], land_layer: TileMapLayer) -> void:
	if _highlight_node != null:
		(_highlight_node as DemolishHighlightOverlay).set_target(cells, land_layer)

# ─── Inner Class for Demolish Highlight ───────────────────────────────────────

class DemolishHighlightOverlay extends Node2D:
	var _cells: Array[Vector2i] = []
	var _land_layer: TileMapLayer = null

	func set_target(cells: Array[Vector2i], land_layer: TileMapLayer) -> void:
		_cells = cells
		_land_layer = land_layer
		queue_redraw()

	func clear() -> void:
		_cells.clear()
		_land_layer = null
		queue_redraw()

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if _cells.is_empty() or _land_layer == null:
			return

		var tile_size := Vector2(32, 16)
		if _land_layer.tile_set != null:
			tile_size = Vector2(_land_layer.tile_set.tile_size)

		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
		var fill_color := Color(1.0, 0.15, 0.15, 0.45 * pulse)
		var stroke_color := Color(1.0, 0.25, 0.25, 0.95 * pulse)

		var half_w := tile_size.x / 2.0
		var half_h := tile_size.y / 2.0

		for cell in _cells:
			var local_cell_center := _land_layer.map_to_local(cell)
			var global_cell_center := _land_layer.to_global(local_cell_center)
			var node_local_pos := to_local(global_cell_center)

			var top := node_local_pos + Vector2(0, -half_h)
			var right := node_local_pos + Vector2(half_w, 0)
			var bottom := node_local_pos + Vector2(0, half_h)
			var left := node_local_pos + Vector2(-half_w, 0)

			var poly := PackedVector2Array([top, right, bottom, left])
			draw_polygon(poly, [fill_color])

			var outline := PackedVector2Array([top, right, bottom, left, top])
			draw_polyline(outline, stroke_color, 2.0)
