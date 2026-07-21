# placement_manager.gd
# Attach to a Node named "PlacementManager" inside Main.tscn.
#
# ── Responsibilities ───────────────────────────────────────────────────────────
#   • Handle keyboard/mouse input for build mode, building selection, and rotation
#   • Resolve the LandLayer reference and create the BuildingContainer
#   • Delegate each concern to its dedicated helper:
#       BuildingRegistry   → occupied-cell tracking
#       ConnectionChecker  → BFS path connectivity + cosmetic effects
#       PreviewHandler     → ghost sprite
#
# ── Setup ──────────────────────────────────────────────────────────────────────
#   1. Add a Node to Main as a child, name it "PlacementManager"
#   2. Attach this script
#   3. Add BuildingRegistry, ConnectionChecker, PreviewHandler as child nodes
#      with those exact names (or adjust @onready paths below)
#   4. In the Inspector, fill the `buildings` Array with your BuildingData .tres files
#
# ── Input Map (Project Settings → Input Map) ──────────────────────────────────
#   toggle_build  → E   : toggle build mode on/off
#   building_1    → 1   : select buildings[0]  (Path)
#   building_2    → 2   : select buildings[1]  (House)
#   building_3    → 3   : select buildings[2]  (Ricefield)
#   building_4    → 4   : select buildings[3]  (Restaurant)
#   building_5    → 5   : select buildings[4]  (Bench)
#   rotate        → R   : cycle rotation variant (for buildings that support it)

extends Node

# ─── Exports ──────────────────────────────────────────────────────────────────

## All building types available in this scene.
## Order determines which key (building_1, building_2 …) selects each type.
## To add a new building: create a BuildingData .tres and append it here.
@export var buildings: Array[BuildingData] = []

# ─── Child node references ────────────────────────────────────────────────────

@onready var registry: BuildingRegistry            = $BuildingRegistry
@onready var connection_checker: ConnectionChecker = $ConnectionChecker
@onready var preview: PreviewHandler               = $PreviewHandler

# ─── Internal state ───────────────────────────────────────────────────────────

var _land_layer: TileMapLayer
var _building_container: Node2D

var _build_mode: bool       = false
var _hovered_cell: Vector2i = Vector2i.ZERO
var _placement_valid: bool  = false

## The root BuildingData selected by the player (from buildings[]).
## Never changes until the player presses a building_N key.
var _base_data: BuildingData

## The currently active BuildingData — either _base_data or one of its
## rotation_variants.  This is what gets previewed and placed.
var _current_data: BuildingData

## Current rotation variant index.
## -1 = base orientation (_base_data itself).
##  0..N-1 = index into _base_data.rotation_variants[].
var _rotation_index: int = -1

## Input action name → buildings[] index mapping.
const ACTION_TO_INDEX: Array[String] = [
	"building_1",  # 0 — Path
	"building_2",  # 1 — House
	"building_3",  # 2 — Ricefield
	"building_4",  # 3 — Restaurant
	"building_5",  # 4 — Bench
]

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	# ── Resolve LandLayer ────────────────────────────────────────────────────
	_land_layer = _find_land_layer()
	if _land_layer == null:
		push_error("PlacementManager: Could not find a TileMapLayer named 'LandLayer'.")
		return

	# ── Create BuildingContainer ─────────────────────────────────────────────
	_building_container = Node2D.new()
	_building_container.name = "BuildingContainer"
	_building_container.y_sort_enabled = true
	get_parent().add_child(_building_container)

	# ── Wire up helpers ──────────────────────────────────────────────────────
	connection_checker.registry = registry
	preview.setup(get_parent())

	# ── Default selection ────────────────────────────────────────────────────
	if buildings.is_empty():
		push_warning("PlacementManager: No BuildingData assigned. Assign at least one in the Inspector.")
	else:
		_select_building(0)

	_print_help()


func _process(_delta: float) -> void:
	if not _land_layer:
		return

	_handle_build_toggle()
	_handle_building_selection()

	if not _build_mode:
		return

	_handle_rotation()
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if not _build_mode:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_try_place_building()

# ─── Input handlers ───────────────────────────────────────────────────────────

func _handle_build_toggle() -> void:
	if not Input.is_action_just_pressed("toggle_build"):
		return
	_build_mode = !_build_mode
	preview.set_visible(_build_mode)
	print("PlacementManager ▸ build mode: %s" % ("ON" if _build_mode else "OFF"))


func _handle_building_selection() -> void:
	for i in ACTION_TO_INDEX.size():
		if Input.is_action_just_pressed(ACTION_TO_INDEX[i]):
			_select_building(i)
			break


func _select_building(index: int) -> void:
	if index < 0 or index >= buildings.size():
		push_warning("PlacementManager: No building at index %d." % index)
		return
	_base_data      = buildings[index]
	_current_data   = _base_data
	_rotation_index = -1
	preview.set_building(_current_data)
	preview.set_rotation_deg(0.0)
	print("PlacementManager ▸ selected: %s" % _current_data.display_name)


## Cycle to the next rotation variant for the current building.
## If the building has no rotation_variants, pressing R does nothing.
##
## Cycle order: base (-1) → variant[0] → variant[1] → … → base (-1) → …
func _handle_rotation() -> void:
	if not Input.is_action_just_pressed("rotate"):
		return
	if _base_data == null or not _base_data.can_rotate():
		return
	# Shift _rotation_index from [-1..N-1] into [0..N], step, mod back to [0..N],
	# then shift back to [-1..N-1].
	var variant_count: int = _base_data.rotation_variants.size()
	_rotation_index = ((_rotation_index + 1 + 1) % (variant_count + 1)) - 1
	if _rotation_index < 0:
		_current_data = _base_data
	else:
		_current_data = _base_data.rotation_variants[_rotation_index]
	preview.set_building(_current_data)
	print("PlacementManager ▸ rotation variant: %s" % _current_data.display_name)

# ─── Hover / preview update ───────────────────────────────────────────────────

func _update_hover() -> void:
	var world_mouse: Vector2 = _land_layer.get_global_mouse_position()
	var local_mouse: Vector2 = _land_layer.to_local(world_mouse)
	_hovered_cell = _land_layer.local_to_map(local_mouse)

	var footprint: Array[Vector2i] = _current_data.get_footprint(_hovered_cell)
	_placement_valid = _is_footprint_placeable(footprint)

	var snapped_world: Vector2 = _land_layer.to_global(_land_layer.map_to_local(_hovered_cell))
	preview.update_position(snapped_world)
	preview.set_visible(true)
	preview.set_valid(_placement_valid)

# ─── Placement ────────────────────────────────────────────────────────────────

func _try_place_building() -> void:
	if not _placement_valid or _current_data == null:
		return
	if _current_data.scene == null:
		push_warning("PlacementManager: BuildingData '%s' has no scene assigned." % _current_data.display_name)
		return

	# Ricefield has its own placement flow (main + surrounding field tiles).
	if _current_data.is_ricefield:
		_try_place_ricefield()
		return

	var footprint: Array[Vector2i] = _current_data.get_footprint(_hovered_cell)
	var building: Node2D = _current_data.scene.instantiate() as Node2D
	if building == null:
		push_error("PlacementManager: Scene root must extend Node2D.")
		return

	# Attach the BuildingData reference so registry and checkers can read it.
	building.set_meta("data", _current_data)
	# Also expose via property if the building script declares a `data` var.
	if "data" in building:
		building.data = _current_data

	_building_container.add_child(building)
	building.global_position = _land_layer.to_global(_land_layer.map_to_local(_hovered_cell))

	# Remove any field tiles that occupy this footprint before claiming the cells.
	_displace_fields_in_footprint(footprint)
	registry.register(footprint, building)
	connection_checker.update_all_connections()

	print("PlacementManager ▸ placed '%s' at %s  footprint: %s" % [
		_current_data.display_name, _hovered_cell, footprint
	])


## Place the main Ricefield building at the hovered cell, then stamp RicefieldField
## tiles on every surrounding cell that is empty and on valid Land terrain.
## Fields that would overlap an existing building are silently skipped.
func _try_place_ricefield() -> void:
	# ── Place main building ───────────────────────────────────────────────────
	var building: Node2D = _current_data.scene.instantiate() as Node2D
	if building == null:
		push_error("PlacementManager: Ricefield scene root must extend Node2D.")
		return

	building.set_meta("data", _current_data)
	if "data" in building:
		building.data = _current_data

	_building_container.add_child(building)
	building.global_position = _land_layer.to_global(_land_layer.map_to_local(_hovered_cell))

	# A ricefield's main cell might land on another ricefield's field — displace it.
	_displace_fields_in_footprint([_hovered_cell])
	var main_cells: Array[Vector2i] = [_hovered_cell]
	registry.register(main_cells, building)

	# ── Stamp surrounding field tiles ─────────────────────────────────────────
	var fields_placed: int = 0
	if _current_data.field_scene != null:
		for offset: Vector2i in _current_data.field_footprint_offsets:
			var field_cell: Vector2i = _hovered_cell + offset

			# Skip occupied cells — fields never overwrite existing buildings.
			if registry.is_occupied(field_cell):
				continue

			# Fields must be on valid Land terrain, same rule as any other building.
			var tile_data: TileData = _land_layer.get_cell_tile_data(field_cell)
			if tile_data == null or tile_data.terrain != 0:
				continue

			var field_node: Node2D = _current_data.field_scene.instantiate() as Node2D
			if field_node == null:
				continue

			# Store field BuildingData in metadata so ConnectionChecker can identify it.
			if _current_data.field_building_data != null:
				field_node.set_meta("data", _current_data.field_building_data)

			_building_container.add_child(field_node)
			field_node.global_position = _land_layer.to_global(_land_layer.map_to_local(field_cell))

			var field_cells: Array[Vector2i] = [field_cell]
			registry.register(field_cells, field_node)
			fields_placed += 1

	connection_checker.update_all_connections()
	print("PlacementManager ▸ placed 'Ricefield' at %s with %d field(s) stamped" % [
		_hovered_cell, fields_placed
	])

# ─── Placement validation ─────────────────────────────────────────────────────

func _is_footprint_placeable(footprint: Array[Vector2i]) -> bool:
	for cell in footprint:
		if registry.is_occupied(cell):
			# Ricefield field tiles act as soft obstacles — any new building may
			# displace them, so treat them as empty for validation purposes.
			if not _is_ricefield_field(registry.get_building_at(cell)):
				return false
		var tile_data: TileData = _land_layer.get_cell_tile_data(cell)
		# terrain 0 = "Land" in terrain_set 0 (see land_tile.tres)
		if tile_data == null or tile_data.terrain != 0:
			return false
	return true


## Returns true if [param node] is a RicefieldField tile, identified by its
## BuildingData id.  Reads metadata first (scriptless scenes), then property.
func _is_ricefield_field(node: Node2D) -> bool:
	if node == null:
		return false
	var data: BuildingData = null
	if node.has_meta("data"):
		var meta = node.get_meta("data")
		if meta is BuildingData:
			data = meta as BuildingData
	if data == null:
		var prop = node.get("data")
		if prop is BuildingData:
			data = prop as BuildingData
	return data != null and data.id == "ricefield_field"


## Remove every RicefieldField tile occupying any cell in [param cells].
## Call this before registering a new building so field nodes are freed cleanly
## and ConnectionChecker's subsequent field count stays accurate.
func _displace_fields_in_footprint(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if not registry.is_occupied(cell):
			continue
		var occupant: Node2D = registry.get_building_at(cell)
		if _is_ricefield_field(occupant):
			registry.unregister(occupant)

# ─── Public API ───────────────────────────────────────────────────────────────

## Remove [param building] from the scene and free all its tiles.
func remove_building(building: Node2D) -> void:
	var freed: Array[Vector2i] = registry.unregister(building)
	connection_checker.update_all_connections()
	print("PlacementManager ▸ removed building, freed %d tile(s)." % freed.size())


## Returns true if [param cell] is occupied.
func is_tile_occupied(cell: Vector2i) -> bool:
	return registry.is_occupied(cell)


## Returns the building at [param cell], or null.
func get_building_at(cell: Vector2i) -> Node2D:
	return registry.get_building_at(cell)

# ─── Tree helpers ─────────────────────────────────────────────────────────────

func _find_land_layer() -> TileMapLayer:
	var parent: Node = get_parent()
	if parent == null:
		return null
	var node: Node = parent.get_node_or_null("LandLayer")
	if node is TileMapLayer:
		return node as TileMapLayer
	for child in parent.get_children():
		if child is TileMapLayer:
			push_warning("PlacementManager: 'LandLayer' not found by name; using '%s'." % child.name)
			return child as TileMapLayer
	return null


func _print_help() -> void:
	print("─── PlacementManager controls ───")
	print("  E   → toggle build mode")
	for i in buildings.size():
		print("  %d   → select %s" % [i + 1, buildings[i].display_name])
	print("  R   → cycle rotation variant (if building supports it)")
	print("  LMB → place selected building (in build mode)")
	print("────────────────────────────────")
