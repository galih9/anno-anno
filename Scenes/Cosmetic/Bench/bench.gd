# bench.gd
# Cosmetic-type building.
#
# The bench itself is stateless from a game-logic perspective.
# Its happiness effect on nearby resident buildings is computed externally
# by ConnectionChecker.update_cosmetic_effects() every time the map changes.
#
# A debug label shows the influence radius so it is visible during development.

extends Node2D

# ─── State ────────────────────────────────────────────────────────────────────

## BuildingData resource injected by PlacementManager at placement time.
## PlacementManager assigns this BEFORE add_child(), so _ready() can read it.
var data: BuildingData

# ─── Private ──────────────────────────────────────────────────────────────────

@onready var _sprite: Sprite2D = $Sprite2D
@onready var label = $Container/Label

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_apply_orientation()
	_refresh_label()

# ─── Private helpers ──────────────────────────────────────────────────────────

## Apply the correct sprite texture and position offset from the injected
## BuildingData.  This fixes the rotation bug where the placed building always
## rendered as horizontal even when the vertical variant was selected:
## bench.tscn hardcodes bench-h.png, so we swap it here at runtime based on
## whichever BuildingData orientation was injected before _ready() fired.
func _apply_orientation() -> void:
	if data == null or _sprite == null:
		return
	# Swap texture to match the placed orientation (H or V).
	if data.preview_texture != null:
		_sprite.texture = data.preview_texture
	# Apply the sprite_offset defined in BuildingData so the sprite sits
	# correctly over the tile origin (same offset used by the ghost preview).
	_sprite.position = data.sprite_offset


func _refresh_label() -> void:
	if label == null:
		return
	var radius: int = data.influence_radius if data != null else 0
	label.text = "Bench\nRadius: %d" % radius
