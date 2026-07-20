# placement_manager.gd
# Attach to a Node named "PlacementManager" inside Main.tscn.
#
# This version is SELF-CONTAINED: it finds LandLayer automatically,
# and creates BuildingContainer + PreviewSprite at runtime.
# You do NOT need to add extra nodes to the scene manually.
#
# The only things you must do in the Editor:
#   1. Add a Node (type: Node) to Main as a child, name it "PlacementManager"
#   2. Attach this script to it
#   3. Set the export slots for path_scene, house_scene, restaurant_scene
#
# Input Map (defined in project.godot):
#   toggle_build  → E  : toggle build mode on/off
#   building_1    → 1  : switch to Path
#   building_2    → 2  : switch to House
#   building_3    → 3  : switch to Restaurant

extends Node

# ─── Exports ──────────────────────────────────────────────────────────────────

## Path scene (key 1). Drag res://Scenes/Path/path.tscn here.
@export var path_scene: PackedScene

## House scene (key 2). Drag res://Scenes/House/house.tscn here.
@export var house_scene: PackedScene

## Restaurant scene (key 3). Drag res://Scenes/Restaurant/restaurant.tscn here.
@export var restaurant_scene: PackedScene

## Pixel offset applied to preview sprite so it lines up with placed buildings.
## Tweak per-building in _update_preview_for_type() below if needed.
@export var preview_offset: Vector2 = Vector2(0, -8)

# ─── Building type enum ───────────────────────────────────────────────────────

enum BuildingType { PATH = 1, HOUSE = 2, RESTAURANT = 3 }

# ─── Constants ────────────────────────────────────────────────────────────────

const PREVIEW_ALPHA: float = 0.55

# Per-type footprint defined as arrays of Vector2i OFFSETS from the origin cell.
# In the diamond-down isometric layout the clicked cell sits at the BOTTOM of
# the building's isometric diamond.  Multi-tile buildings extend upward (toward
# negative map coordinates) so that the visual sprite and the collision tiles
# overlap perfectly.
#
# Pathway  (1×1)  – single tile, no offset needed.
# House    (2×2)  – 4-tile diamond; origin is the bottom vertex.
# Restaurant (3×2) – 6-tile parallelogram; origin at bottom-center.
const FOOTPRINT_OFFSETS: Dictionary = {
	BuildingType.PATH: [
		Vector2i(0, 0),
	],
	BuildingType.HOUSE: [
		Vector2i( 0,  0),   # bottom
		Vector2i(-1,  0),   # left
		Vector2i( 0, -1),   # right
		Vector2i(-1, -1),   # top
	],
	BuildingType.RESTAURANT: [
		Vector2i(-1,  0),   # bottom-left
		Vector2i( 0,  0),   # bottom-right (origin)
		Vector2i(-1, -1),   # middle-left
		Vector2i( 0, -1),   # middle-right
		Vector2i(-1, -2),   # top-left
		Vector2i( 0, -2),   # top-right
	],
}

# Asset paths for preview textures (one per building type)
const PREVIEW_TEXTURES: Dictionary = {
	BuildingType.PATH:       "res://Assets/pathway.png",
	BuildingType.HOUSE:      "res://Assets/house_sprite.png",
	BuildingType.RESTAURANT: "res://Assets/restaurant.png",
}

# Per-type sprite offsets to match the child Sprite2D LOCAL position in each scene.
# Path:       Sprite2D position = Vector2(0, 0)
# House:      Sprite2D position = Vector2(0, -8)
# Restaurant: Sprite2D position = Vector2(8, -12)  ← includes the X shift
const SPRITE_OFFSETS: Dictionary = {
	BuildingType.PATH:        Vector2(0,   0),
	BuildingType.HOUSE:       Vector2(0,  -8),
	BuildingType.RESTAURANT:  Vector2(8, -12),
}

# ─── Internal node references (resolved in _ready) ────────────────────────────

var _land_layer: TileMapLayer
var _building_container: Node2D
var _preview_sprite: Sprite2D

# ─── Runtime state ────────────────────────────────────────────────────────────

## Key: Vector2i map cell  |  Value: Node2D building that owns it
var occupied: Dictionary = {}

var _hovered_cell: Vector2i   = Vector2i.ZERO
var _placement_valid: bool    = false
var _build_mode: bool         = false
var _current_type: BuildingType = BuildingType.HOUSE

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Defer setup so that add_child() runs AFTER the scene tree is fully built.
	call_deferred("_setup")


func _setup() -> void:
	# ── Find LandLayer ───────────────────────────────────────────────────────
	_land_layer = _find_land_layer()
	if _land_layer == null:
		push_error("PlacementManager: Could not find a TileMapLayer named 'LandLayer'. Make sure it exists as a sibling node.")
		return

	# ── Create BuildingContainer ─────────────────────────────────────────────
	_building_container = Node2D.new()
	_building_container.name = "BuildingContainer"
	_building_container.y_sort_enabled = true
	get_parent().add_child(_building_container)

	# ── Create PreviewSprite ─────────────────────────────────────────────────
	_preview_sprite = Sprite2D.new()
	_preview_sprite.name = "PreviewSprite"
	_preview_sprite.modulate = Color(0.0, 1.0, 0.0, PREVIEW_ALPHA)
	_preview_sprite.z_index  = 1
	_preview_sprite.visible  = false
	get_parent().add_child(_preview_sprite)

	# Load the default building texture into the preview
	_update_preview_for_type(_current_type)

	print("PlacementManager: ready. LandLayer found, BuildingContainer and PreviewSprite created.")
	_print_help()


func _process(_delta: float) -> void:
	if not _land_layer or not _preview_sprite:
		return

	# ── Handle keyboard input for building selection & toggle ─────────────
	if Input.is_action_just_pressed("toggle_build"):
		_build_mode = !_build_mode
		_preview_sprite.visible = _build_mode
		print("PlacementManager ▸ build mode: %s" % ("ON" if _build_mode else "OFF"))

	if Input.is_action_just_pressed("building_1"):
		_set_building_type(BuildingType.PATH)
	if Input.is_action_just_pressed("building_2"):
		_set_building_type(BuildingType.HOUSE)
	if Input.is_action_just_pressed("building_3"):
		_set_building_type(BuildingType.RESTAURANT)

	if not _build_mode:
		return

	# 1. Global mouse → LandLayer local → map cell
	var world_mouse: Vector2 = _land_layer.get_global_mouse_position()
	var local_mouse: Vector2 = _land_layer.to_local(world_mouse)
	var cell: Vector2i       = _land_layer.local_to_map(local_mouse)
	_hovered_cell = cell

	# 2. Footprint
	var footprint: Array[Vector2i] = _get_footprint(cell)

	# 3. Validate
	_placement_valid = _is_footprint_clear(footprint)

	# 4. Snap preview position
	var snapped_local: Vector2 = _land_layer.map_to_local(cell)
	var snapped_world: Vector2 = _land_layer.to_global(snapped_local)
	_preview_sprite.global_position = snapped_world
	_preview_sprite.visible = true

	# 5. Green / Red tint
	if _placement_valid:
		_preview_sprite.modulate = Color(0.0, 1.0, 0.0, PREVIEW_ALPHA)
	else:
		_preview_sprite.modulate = Color(1.0, 0.0, 0.0, PREVIEW_ALPHA)


func _unhandled_input(event: InputEvent) -> void:
	if not _build_mode:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_try_place_building()

# ─── Building-type switching ──────────────────────────────────────────────────

func _set_building_type(type: BuildingType) -> void:
	_current_type = type
	_update_preview_for_type(type)
	var name_map: Dictionary = {
		BuildingType.PATH:        "Path",
		BuildingType.HOUSE:       "House",
		BuildingType.RESTAURANT:  "Restaurant",
	}
	print("PlacementManager ▸ selected: %s" % name_map.get(type, "Unknown"))


func _update_preview_for_type(type: BuildingType) -> void:
	if not _preview_sprite:
		return

	# Load preview texture
	var path: String = PREVIEW_TEXTURES.get(type, "")
	if path != "" and ResourceLoader.exists(path):
		_preview_sprite.texture = load(path) as Texture2D
	else:
		_preview_sprite.texture = null

	# Match sprite offset of each scene's child Sprite2D
	_preview_sprite.offset = SPRITE_OFFSETS.get(type, Vector2.ZERO)

# ─── Placement ────────────────────────────────────────────────────────────────

func _try_place_building() -> void:
	if not _placement_valid:
		return

	var scene: PackedScene = _get_scene_for_type(_current_type)
	if not scene:
		push_warning("PlacementManager: Scene for building type %d is not assigned." % _current_type)
		return

	var footprint: Array[Vector2i] = _get_footprint(_hovered_cell)

	var building: Node2D = scene.instantiate() as Node2D
	if building == null:
		push_error("PlacementManager: Scene root must extend Node2D.")
		return

	_building_container.add_child(building)

	var snapped_local: Vector2 = _land_layer.map_to_local(_hovered_cell)
	building.global_position   = _land_layer.to_global(snapped_local)

	for tile in footprint:
		occupied[tile] = building

	print("PlacementManager ▸ placed %s at %s  footprint: %s" % [BuildingType.keys()[_current_type - 1], _hovered_cell, footprint])


func _get_scene_for_type(type: BuildingType) -> PackedScene:
	match type:
		BuildingType.PATH:        return path_scene
		BuildingType.HOUSE:       return house_scene
		BuildingType.RESTAURANT:  return restaurant_scene
	return null

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _get_footprint(origin: Vector2i) -> Array[Vector2i]:
	# Look up the explicit offsets for the current building type.
	# Uses match to avoid GDScript enum/int type-mismatch on Dictionary lookup.
	var offsets: Array = []
	match _current_type:
		BuildingType.PATH:
			offsets = FOOTPRINT_OFFSETS[BuildingType.PATH]
		BuildingType.HOUSE:
			offsets = FOOTPRINT_OFFSETS[BuildingType.HOUSE]
		BuildingType.RESTAURANT:
			offsets = FOOTPRINT_OFFSETS[BuildingType.RESTAURANT]
	var tiles: Array[Vector2i] = []
	for offset in offsets:
		tiles.append(origin + offset)
	return tiles


func _is_footprint_clear(footprint: Array[Vector2i]) -> bool:
	for tile in footprint:
		if occupied.has(tile):
			return false
	return true


## Walk up the tree from PlacementManager → look in siblings for a TileMapLayer named "LandLayer".
func _find_land_layer() -> TileMapLayer:
	var parent: Node = get_parent()
	if parent == null:
		return null
	# Direct child named "LandLayer"
	var node: Node = parent.get_node_or_null("LandLayer")
	if node is TileMapLayer:
		return node as TileMapLayer
	# Fallback: search all children for any TileMapLayer
	for child in parent.get_children():
		if child is TileMapLayer:
			push_warning("PlacementManager: 'LandLayer' not found by name; using first TileMapLayer found: '%s'" % child.name)
			return child as TileMapLayer
	return null


func _print_help() -> void:
	print("─── PlacementManager controls ───")
	print("  E   → toggle build mode")
	print("  1   → select Path")
	print("  2   → select House")
	print("  3   → select Restaurant")
	print("  LMB → place selected building (in build mode)")
	print("────────────────────────────────")

# ─── Public API ───────────────────────────────────────────────────────────────

func remove_building(building: Node2D) -> void:
	var keys: Array[Vector2i] = []
	for tile: Vector2i in occupied.keys():
		if occupied[tile] == building:
			keys.append(tile)
	for tile in keys:
		occupied.erase(tile)
	building.queue_free()
	print("PlacementManager ▸ removed building, freed %d tiles." % keys.size())

func is_tile_occupied(cell: Vector2i) -> bool:
	return occupied.has(cell)

func get_building_at(cell: Vector2i) -> Node2D:
	return occupied.get(cell, null) as Node2D
