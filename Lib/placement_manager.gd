# placement_manager.gd
# Attach to a Node named "PlacementManager" inside Main.tscn.
#
# ── Responsibilities ───────────────────────────────────────────────────────────
#   • Handle keyboard/mouse input for build mode, building selection, rotation, and demolition
#   • Resolve the LandLayer reference and create the BuildingContainer
#   • Delegate each concern to its dedicated helper:
#       BuildingRegistry   → occupied-cell tracking
#       ConnectionChecker  → BFS path connectivity + cosmetic effects
#       PreviewHandler     → ghost sprite / demolish highlight
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

# ─── Signals ──────────────────────────────────────────────────────────────────

signal building_selected(building: Node2D, data: BuildingData)
signal building_deselected()
signal demolish_mode_changed(enabled: bool)

# ─── Exports ──────────────────────────────────────────────────────────────────

## All building types available in this scene.
## Order determines which key (building_1, building_2 …) selects each type.
## To add a new building: create a BuildingData .tres and append it here.
@export var buildings: Array[BuildingData] = []

# ─── Child node references ────────────────────────────────────────────────────

@onready var registry: Node            = $BuildingRegistry
@onready var connection_checker: Node = $ConnectionChecker
@onready var preview: Node               = $PreviewHandler

# ─── Internal state ───────────────────────────────────────────────────────────

var _land_layer: TileMapLayer
var _building_container: Node2D

var _build_mode: bool           = false
var _demolish_mode: bool        = false
var _is_drag_demolishing: bool  = false
var _hovered_cell: Vector2i     = Vector2i.ZERO
var _placement_valid: bool      = false

var _selected_building: Node2D = null
var _selection_highlight: SelectionHighlight = null

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
	print("PlacementManager _ready")
	print("$BuildingRegistry is: ", $BuildingRegistry)
	print("registry variable is: ", registry)
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
	_building_container.z_index = 1
	_building_container.y_sort_enabled = true
	get_parent().add_child(_building_container)

	# ── Create Selection Highlight ───────────────────────────────────────────
	_selection_highlight = SelectionHighlight.new()
	_selection_highlight.name = "SelectionHighlight"
	get_parent().add_child(_selection_highlight)
	_selection_highlight.setup(_land_layer)

	# ── Wire up helpers ──────────────────────────────────────────────────────
	connection_checker.registry = registry
	preview.setup(get_parent())

	# Add lumberjack dynamically so it shows up
	var lj_data = load("res://Scenes/Resource/LumberJack/lumberjack_data.tres")
	if lj_data and not buildings.has(lj_data):
		buildings.append(lj_data)

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

	if not _build_mode and not _demolish_mode:
		return

	if _build_mode:
		_handle_rotation()

	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if _demolish_mode:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_is_drag_demolishing = true
					_try_demolish_at_cell(_hovered_cell, false)
					get_viewport().set_input_as_handled()
				else:
					_is_drag_demolishing = false
					get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				exit_demolish_mode()
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			_update_hover()
			if _is_drag_demolishing or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_try_demolish_at_cell(_hovered_cell, true)
	elif _build_mode:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_try_place_building()
		elif event is InputEventMouseMotion:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				if _current_data != null and _current_data.is_connector:
					_update_hover()
					_try_place_building()
	else:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var world_mouse: Vector2 = _land_layer.get_global_mouse_position()
				var local_mouse: Vector2 = _land_layer.to_local(world_mouse)
				var cell: Vector2i = _land_layer.local_to_map(local_mouse)
				var building: Node2D = registry.get_building_at(cell)
				if building != null:
					select_building(building)
					get_viewport().set_input_as_handled()
				else:
					deselect_building()

# ─── Demolish Mode API ─────────────────────────────────────────────────────────

func start_demolish_mode() -> void:
	if _demolish_mode:
		return
	deselect_building()
	_demolish_mode = true
	_build_mode = false
	_base_data = null
	_current_data = null
	preview.set_demolish_mode(true)
	preview.set_preview_visible(true)
	_update_hover()
	demolish_mode_changed.emit(true)
	print("PlacementManager ▸ Demolish mode ON")


func exit_demolish_mode() -> void:
	if not _demolish_mode:
		return
	_demolish_mode = false
	_is_drag_demolishing = false
	preview.set_demolish_mode(false)
	preview.set_preview_visible(false)
	demolish_mode_changed.emit(false)
	print("PlacementManager ▸ Demolish mode OFF")


func is_demolish_mode() -> bool:
	return _demolish_mode


func _try_demolish_at_cell(cell: Vector2i, is_drag: bool) -> void:
	var building: Node2D = registry.get_building_at(cell)
	if building == null or not is_instance_valid(building):
		return

	if is_drag:
		# Drag demolish mode: ONLY demolish pathways (connectors). Regular buildings are excluded!
		if _is_pathway(building):
			remove_building(building)
			_update_hover()
	else:
		# Single click demolish mode: Demolish ANY building or pathway in one click!
		remove_building(building)
		_update_hover()


func _is_pathway(building: Node2D) -> bool:
	if building == null or not is_instance_valid(building):
		return false
	var data: BuildingData = null
	if building.has_meta("data"):
		var meta = building.get_meta("data")
		if meta is BuildingData:
			data = meta as BuildingData
	if data == null:
		var prop = building.get("data")
		if prop is BuildingData:
			data = prop as BuildingData
	if data != null:
		return data.is_connector or data.building_type == BuildingData.BuildingType.CONNECTOR
	return false

# ─── Input handlers ───────────────────────────────────────────────────────────

func _handle_build_toggle() -> void:
	if not Input.is_action_just_pressed("toggle_build"):
		return
	if _demolish_mode:
		exit_demolish_mode()
		return
	_build_mode = !_build_mode
	if _build_mode:
		deselect_building()
		if _current_data == null and buildings.size() > 0:
			_select_building(0)
		else:
			preview.set_preview_visible(true)
	else:
		preview.set_preview_visible(false)
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
	start_placement(buildings[index])

## Public API to start placing a specific BuildingData (called by UI)
func start_placement(data: BuildingData) -> void:
	if data == null:
		push_warning("PlacementManager: Cannot place null BuildingData.")
		return
	if _demolish_mode:
		exit_demolish_mode()
	deselect_building()
	_base_data      = data
	_current_data   = data
	_rotation_index = -1
	_build_mode = true
	preview.set_demolish_mode(false)
	preview.set_preview_visible(true)
	preview.set_building(_current_data)
	preview.set_rotation_deg(0.0)
	print("PlacementManager ▸ selected: %s" % _current_data.display_name)

# ─── Selection Public API ──────────────────────────────────────────────────────

func select_building(building: Node2D) -> void:
	if building == null:
		deselect_building()
		return
	if _demolish_mode:
		return
	_selected_building = building
	var cells: Array[Vector2i] = registry.get_cells_of(building)
	var data: BuildingData = null
	if building.has_meta("data"):
		var meta = building.get_meta("data")
		if meta is BuildingData: data = meta
	if data == null and "data" in building and building.data is BuildingData:
		data = building.data

	_selection_highlight.set_target(building, cells)
	building_selected.emit(building, data)
	print("PlacementManager ▸ selected building: %s" % (data.display_name if data else building.name))


func deselect_building() -> void:
	if _selected_building != null:
		_selected_building = null
		if _selection_highlight != null:
			_selection_highlight.clear()
		building_deselected.emit()
		print("PlacementManager ▸ building deselected")


func get_selected_building() -> Node2D:
	return _selected_building


func _handle_rotation() -> void:
	if not Input.is_action_just_pressed("rotate"):
		return
	if _base_data == null or not _base_data.can_rotate():
		return
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

	var snapped_world: Vector2 = _land_layer.to_global(_land_layer.map_to_local(_hovered_cell))
	preview.update_position(snapped_world)

	if _demolish_mode:
		var target_building: Node2D = registry.get_building_at(_hovered_cell)
		if target_building != null and is_instance_valid(target_building):
			var cells: Array[Vector2i] = registry.get_cells_of(target_building)
			preview.set_demolish_highlight(cells, _land_layer)
		else:
			var single_cell: Array[Vector2i] = [_hovered_cell]
			preview.set_demolish_highlight(single_cell, _land_layer)
		preview.set_preview_visible(true)
		return

	if _current_data == null:
		preview.set_preview_visible(false)
		_placement_valid = false
		return

	var footprint: Array[Vector2i] = _current_data.get_footprint(_hovered_cell)
	_placement_valid = _is_footprint_placeable(footprint)

	preview.set_preview_visible(true)
	preview.set_valid(_placement_valid)

# ─── Placement ────────────────────────────────────────────────────────────────

func _try_place_building() -> void:
	if not _placement_valid or _current_data == null:
		return
	if _current_data.scene == null:
		push_warning("PlacementManager: BuildingData '%s' has no scene assigned." % _current_data.display_name)
		return

	if _current_data.is_ricefield:
		_try_place_ricefield()
		return

	var footprint: Array[Vector2i] = _current_data.get_footprint(_hovered_cell)
	var building: Node2D = _current_data.scene.instantiate() as Node2D
	if building == null:
		push_error("PlacementManager: Scene root must extend Node2D.")
		return

	building.set_meta("data", _current_data)
	if "data" in building:
		building.data = _current_data

	_building_container.add_child(building)
	building.global_position = _land_layer.to_global(_land_layer.map_to_local(_hovered_cell))

	_displace_fields_in_footprint(footprint)
	registry.register(footprint, building)
	connection_checker.update_all_connections()

	var main_node = get_parent()
	if "gold" in main_node:
		main_node.gold -= _current_data.cost
	if _current_data.id == "house" and "log" in main_node:
		main_node.log -= 10
		print("PlacementManager ▸ deducted 10 log. Current log: %d" % main_node.log)

	print("PlacementManager ▸ placed '%s' at %s  footprint: %s" % [
		_current_data.display_name, _hovered_cell, footprint
	])

	_handle_post_placement()


func _handle_post_placement() -> void:
	if _current_data == null:
		return
	var type = _current_data.building_type
	if type != BuildingData.BuildingType.CONNECTOR and type != BuildingData.BuildingType.RESIDENT and type != BuildingData.BuildingType.COSMETIC:
		_build_mode = false
		preview.set_preview_visible(false)
		_base_data = null
		_current_data = null


func _try_place_ricefield() -> void:
	var building: Node2D = _current_data.scene.instantiate() as Node2D
	if building == null:
		push_error("PlacementManager: Ricefield scene root must extend Node2D.")
		return

	building.set_meta("data", _current_data)
	if "data" in building:
		building.data = _current_data

	_building_container.add_child(building)
	building.global_position = _land_layer.to_global(_land_layer.map_to_local(_hovered_cell))

	_displace_fields_in_footprint([_hovered_cell])
	var main_cells: Array[Vector2i] = [_hovered_cell]
	registry.register(main_cells, building)

	var fields_placed: int = 0
	if _current_data.field_scene != null:
		for offset: Vector2i in _current_data.field_footprint_offsets:
			var field_cell: Vector2i = _hovered_cell + offset

			if registry.is_occupied(field_cell):
				continue

			var tile_data: TileData = _land_layer.get_cell_tile_data(field_cell)
			if tile_data == null or tile_data.terrain != 0:
				continue

			var field_node: Node2D = _current_data.field_scene.instantiate() as Node2D
			if field_node == null:
				continue

			if _current_data.field_building_data != null:
				field_node.set_meta("data", _current_data.field_building_data)

			if "owner_building" in field_node:
				field_node.owner_building = building

			_building_container.add_child(field_node)
			field_node.global_position = _land_layer.to_global(_land_layer.map_to_local(field_cell))

			var field_cells: Array[Vector2i] = [field_cell]
			registry.register(field_cells, field_node)
			fields_placed += 1

	connection_checker.update_all_connections()

	var main_node = get_parent()
	if "gold" in main_node:
		main_node.gold -= _current_data.cost
		print("PlacementManager ▸ deducted %d gold. Current gold: %d" % [_current_data.cost, main_node.gold])

	print("PlacementManager ▸ placed 'Ricefield' at %s with %d field(s) stamped" % [
		_hovered_cell, fields_placed
	])

	_handle_post_placement()

# ─── Placement validation ─────────────────────────────────────────────────────

func _is_footprint_placeable(footprint: Array[Vector2i]) -> bool:
	var main_node = get_parent()
	if _current_data != null:
		if "gold" in main_node and main_node.gold < _current_data.cost:
			return false
		if _current_data.id == "house" and "log" in main_node and main_node.log < 10:
			return false

	for cell in footprint:
		if registry.is_occupied(cell):
			if not _is_ricefield_field(registry.get_building_at(cell)):
				return false
		var tile_data: TileData = _land_layer.get_cell_tile_data(cell)
		if tile_data == null or tile_data.terrain != 0:
			return false
	return true


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
	if building == null or not is_instance_valid(building):
		return

	# Also remove dependent nodes (such as field tiles owned by this building)
	var all_buildings = registry.get_all_buildings()
	for b in all_buildings:
		if is_instance_valid(b) and "owner_building" in b and b.owner_building == building:
			registry.unregister(b)

	var freed: Array[Vector2i] = registry.unregister(building)
	connection_checker.update_all_connections()
	print("PlacementManager ▸ removed building, freed %d tile(s)." % freed.size())


func is_tile_occupied(cell: Vector2i) -> bool:
	return registry.is_occupied(cell)


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
	print("  E   → toggle build / exit demolish mode")
	for i in buildings.size():
		if buildings[i] != null:
			print("  %d   → select %s" % [i + 1, buildings[i].display_name])
		else:
			print("  %d   → select [null building data]" % [i + 1])
	print("  R   → cycle rotation variant (if building supports it)")
	print("  LMB → place selected building (in build mode) / demolish (in demolish mode)")
	print("  RMB → cancel / exit demolish mode")
	print("────────────────────────────────")
