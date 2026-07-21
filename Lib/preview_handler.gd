# preview_handler.gd
# Attach as a child Node under PlacementManager.
#
# Single responsibility: manage the ghost Sprite2D that follows the cursor
# in build mode.  Handles texture swaps, position snapping, and valid/invalid
# colour tinting.  Zero input logic and zero placement logic here.

class_name PreviewHandler
extends Node

# ─── Constants ────────────────────────────────────────────────────────────────

const ALPHA: float = 0.55
const COLOR_VALID:   Color = Color(0.0, 1.0, 0.0, ALPHA)
const COLOR_INVALID: Color = Color(1.0, 0.0, 0.0, ALPHA)

# ─── Internal ─────────────────────────────────────────────────────────────────

var _sprite: Sprite2D

# ─── Setup ────────────────────────────────────────────────────────────────────

## Create the preview Sprite2D and add it as a child of [param scene_parent].
## Call once from PlacementManager._setup() after the scene tree is ready.
func setup(scene_parent: Node) -> void:
	_sprite = Sprite2D.new()
	_sprite.name    = "PreviewSprite"
	_sprite.modulate = COLOR_VALID
	_sprite.z_index  = 1
	_sprite.visible  = false
	scene_parent.add_child(_sprite)

# ─── Public API ───────────────────────────────────────────────────────────────

## Swap the preview texture and offset to match [param data].
func set_building(data: BuildingData) -> void:
	if _sprite == null:
		return
	_sprite.texture = data.preview_texture
	_sprite.offset  = data.sprite_offset


## Move the preview to [param world_pos] (global coordinates).
func update_position(world_pos: Vector2) -> void:
	if _sprite == null:
		return
	_sprite.global_position = world_pos


## Tint the preview green (valid) or red (invalid).
func set_valid(is_valid: bool) -> void:
	if _sprite == null:
		return
	_sprite.modulate = COLOR_VALID if is_valid else COLOR_INVALID


## Show or hide the preview sprite.
func set_visible(value: bool) -> void:
	if _sprite == null:
		return
	_sprite.visible = value
