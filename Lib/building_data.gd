# building_data.gd
# A Resource that fully describes one building type.
#
# Create one .tres file per building type (e.g. house_data.tres) and assign
# them to PlacementManager.buildings[] in the Inspector.  Adding a new
# building never requires editing any script — just create a new resource.

class_name BuildingData
extends Resource

# ─── Identity ─────────────────────────────────────────────────────────────────

## Machine-readable key used for matching (e.g. "house", "path", "restaurant").
## Must be unique across all registered building types.
@export var id: String = ""

## Human-readable label shown in debug output and future UI.
@export var display_name: String = ""

# ─── Scene ────────────────────────────────────────────────────────────────────

## The PackedScene to instantiate when this building is placed.
@export var scene: PackedScene

# ─── Preview ──────────────────────────────────────────────────────────────────

## Ghost texture shown while hovering in build mode.
@export var preview_texture: Texture2D

## Pixel offset applied to the preview Sprite2D so it aligns with the
## placed building's child Sprite2D.  Match the child Sprite2D.position
## inside the scene.
@export var sprite_offset: Vector2 = Vector2.ZERO

# ─── Footprint ────────────────────────────────────────────────────────────────

## Tile cells this building occupies, expressed as offsets from the origin
## cell (the tile the player clicked).  Origin is always Vector2i(0,0).
##
## Diamond-down isometric convention: the origin is the BOTTOM vertex of the
## building's isometric shape; multi-tile buildings extend upward (negative
## map Y) and to the left (negative map X).
##
## Examples:
##   Path (1×1)   → [ (0,0) ]
##   House (2×2)  → [ (0,0), (-1,0), (0,-1), (-1,-1) ]
@export var footprint_offsets: Array[Vector2i] = [Vector2i(0, 0)]

# ─── Connection role ──────────────────────────────────────────────────────────

## Marks this building as a road/path connector for the BFS connection check.
@export var is_connector: bool = false

## Marks this building as a destination that satisfies a house connection.
@export var is_destination: bool = false

## Marks this building as a consumer that needs a path connection to a destination.
@export var needs_connection: bool = false

# ─── Ricefield ────────────────────────────────────────────────────────────────

## Marks this building as a ricefield that stamps surrounding field tiles on placement.
## When true, PlacementManager uses the special ricefield placement flow.
@export var is_ricefield: bool = false

## The PackedScene to instantiate for each surrounding field tile.
## Only used when [member is_ricefield] is true.
@export var field_scene: PackedScene

## BuildingData resource describing each field tile.
## Stored in field node metadata so ConnectionChecker can identify field tiles by id.
@export var field_building_data: BuildingData

## Tile offsets (relative to origin) where field tiles may be stamped.
## Only empty tiles with valid Land terrain will receive a field.
## Typically the 8 cells surrounding the origin: all cardinal + diagonal neighbours.
@export var field_footprint_offsets: Array[Vector2i] = []

# ─── Helpers ──────────────────────────────────────────────────────────────────

## Returns the full list of map cells this building occupies when placed
## with its origin at [param origin].
func get_footprint(origin: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset: Vector2i in footprint_offsets:
		cells.append(origin + offset)
	return cells
