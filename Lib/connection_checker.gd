# connection_checker.gd
# Attach as a child Node under PlacementManager.
#
# Single responsibility: BFS graph traversal to determine whether buildings
# that need a connection (e.g. Houses) are reachable through connector
# tiles (e.g. Paths) to a destination (e.g. Restaurant); and cosmetic
# effect propagation (bench happiness radius).
#
# All game logic lives here.  This file has zero input, zero UI, and zero
# knowledge of scene trees beyond what BuildingRegistry provides.

class_name ConnectionChecker
extends Node

# ─── Dependencies ─────────────────────────────────────────────────────────────

## Assigned by PlacementManager after both nodes exist.
var registry: BuildingRegistry

# ─── Adjacency ────────────────────────────────────────────────────────────────

## Four cardinal directions for grid adjacency checks.
const CARDINAL: Array[Vector2i] = [
	Vector2i( 1,  0),
	Vector2i(-1,  0),
	Vector2i( 0,  1),
	Vector2i( 0, -1),
]

## Four diagonal directions — used for the full 8-neighbour field scan.
const DIAGONAL: Array[Vector2i] = [
	Vector2i( 1,  1),
	Vector2i(-1,  1),
	Vector2i( 1, -1),
	Vector2i(-1, -1),
]

# ─── Data accessor ────────────────────────────────────────────────────────────

## Reads BuildingData from a node regardless of whether it has a script.
## PlacementManager stores it in node metadata; scripted buildings also expose
## it as a property.  Metadata is checked first so scriptless scenes (e.g. Path)
## are handled correctly.
func _get_data(node: Node2D) -> BuildingData:
	if node.has_meta("data"):
		var meta = node.get_meta("data")
		if meta is BuildingData:
			return meta as BuildingData
	var prop = node.get("data")
	if prop is BuildingData:
		return prop as BuildingData
	return null

# ─── Public API ───────────────────────────────────────────────────────────────

## Re-evaluate and update every building that [needs_connection],
## then propagate cosmetic effects (bench happiness).
## Call this after any placement or removal.
func update_all_connections() -> void:
	if registry == null:
		push_error("ConnectionChecker: registry is not assigned.")
		return

	# ── Step 1: path-based connection check ──────────────────────────────────
	for building in registry.get_buildings_with_flag(&"needs_connection"):
		var data := _get_data(building)
		var result: Dictionary
		# Ricefields need a combined path + field-count check.
		if data != null and data.is_ricefield:
			result = check_ricefield_connection(building)
		else:
			result = check_building_connection(building)
		if building.has_method("set_status"):
			building.set_status(result.status, result.desc)

	# ── Step 2: cosmetic effect pass (bench happiness radius) ─────────────────
	update_cosmetic_effects()


## Run a BFS from [param building]'s adjacent connectors and report whether
## any destination is reachable.
##
## Returns a Dictionary with:
##   "status" : String  — "Connected" or "Disconnected"
##   "desc"   : String  — short human-readable reason
func check_building_connection(building: Node2D) -> Dictionary:
	var occupied: Dictionary = registry.get_occupied_dict()
	var building_cells: Array[Vector2i] = registry.get_cells_of(building)

	# ── Step 1: collect connector tiles directly adjacent to this building ──
	var frontier: Array[Node2D] = _get_adjacent_connectors(building_cells, building, occupied)
	if frontier.is_empty():
		return { "status": "Disconnected", "desc": "no path adjacent" }

	# ── Step 2: BFS through the connector network ───────────────────────────
	var visited: Dictionary = {}
	var queue: Array[Node2D] = []

	for connector in frontier:
		if not visited.has(connector):
			visited[connector] = true
			queue.append(connector)

	while not queue.is_empty():
		var current: Node2D = queue.pop_front()
		var current_cells: Array[Vector2i] = registry.get_cells_of(current)

		for cell in current_cells:
			for dir in CARDINAL:
				var neighbor_cell: Vector2i = cell + dir
				if not occupied.has(neighbor_cell):
					continue
				var neighbor: Node2D = occupied[neighbor_cell]
				if neighbor == current or neighbor == building:
					continue

				var data: BuildingData = _get_data(neighbor)
				if data == null:
					continue

				if data.is_destination:
					return { "status": "Connected", "desc": "activated" }

				if data.is_connector and not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)

	return { "status": "Disconnected", "desc": "path not connected to destination" }

# ─── Cosmetic effect propagation ──────────────────────────────────────────────

## Re-apply all cosmetic building effects (e.g. bench happiness bonus).
##
## Flow:
##   1. Reset every resident building's bench bonus to 0.
##   2. For each cosmetic building with influence_radius > 0,
##      find all resident buildings within that radius and call apply_happiness_bonus().
##
## "Within radius" uses Chebyshev distance (max of |Δx|, |Δy|), covering all
## 8 directions uniformly and cheaply.
func update_cosmetic_effects() -> void:
	# ── Reset all bench bonuses ───────────────────────────────────────────────
	for building in registry.get_buildings_with_type(BuildingData.BuildingType.RESIDENT):
		if building.has_method("reset_happiness_bonus"):
			building.reset_happiness_bonus()

	# ── Apply bonuses from every cosmetic building ───────────────────────────
	var cosmetic_buildings: Array[Node2D] = registry.get_buildings_with_type(
		BuildingData.BuildingType.COSMETIC
	)
	for cosmetic in cosmetic_buildings:
		var c_data: BuildingData = _get_data(cosmetic)
		if c_data == null or c_data.influence_radius <= 0:
			continue

		var c_cells: Array[Vector2i] = registry.get_cells_of(cosmetic)

		for resident in registry.get_buildings_with_type(BuildingData.BuildingType.RESIDENT):
			var r_cells: Array[Vector2i] = registry.get_cells_of(resident)
			if _is_within_radius(c_cells, r_cells, c_data.influence_radius):
				if resident.has_method("apply_happiness_bonus"):
					resident.apply_happiness_bonus(0.25)


## Returns true if any cell in [param target_cells] is within [param radius]
## Chebyshev tiles of any cell in [param source_cells].
func _is_within_radius(
	source_cells: Array[Vector2i],
	target_cells: Array[Vector2i],
	radius: int
) -> bool:
	for sc: Vector2i in source_cells:
		for tc: Vector2i in target_cells:
			var dist: int = max(abs(tc.x - sc.x), abs(tc.y - sc.y))
			if dist <= radius:
				return true
	return false

# ─── Private helpers ──────────────────────────────────────────────────────────

func _get_adjacent_connectors(
	building_cells: Array[Vector2i],
	building: Node2D,
	occupied: Dictionary
) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var seen: Dictionary = {}

	for cell in building_cells:
		for dir in CARDINAL:
			var neighbor_cell: Vector2i = cell + dir
			if not occupied.has(neighbor_cell):
				continue
			var neighbor: Node2D = occupied[neighbor_cell]
			if neighbor == building or seen.has(neighbor):
				continue
			var data: BuildingData = _get_data(neighbor)
			if data == null:
				continue
			if data.is_connector:
				seen[neighbor] = true
				result.append(neighbor)

	return result


# ─── Ricefield helpers ────────────────────────────────────────────────────────

## Combined status check for ricefield buildings:
##   1. BFS to verify a path-to-Restaurant connection exists.
##   2. Count tiles with id "ricefield_field" adjacent to the main cell.
## Both conditions must pass for status "Connected / active".
func check_ricefield_connection(building: Node2D) -> Dictionary:
	var path_result: Dictionary = check_building_connection(building)
	var building_cells: Array[Vector2i] = registry.get_cells_of(building)
	var field_count: int = _count_adjacent_fields(building_cells, building)

	var has_path:   bool = path_result.status == "Connected"
	var has_fields: bool = field_count > 0

	if has_path and has_fields:
		return { "status": "Connected", "desc": "active" }
	elif not has_path and not has_fields:
		return { "status": "Disconnected", "desc": "no path, no fields" }
	elif not has_path:
		return { "status": "Disconnected", "desc": "no path" }
	else:
		return { "status": "Disconnected", "desc": "no fields" }


## Count how many registered field tiles (id == "ricefield_field") exist
## in the 8 cells surrounding [param building_cells].
func _count_adjacent_fields(building_cells: Array[Vector2i], building: Node2D) -> int:
	var occupied: Dictionary = registry.get_occupied_dict()
	var seen: Dictionary = {}
	var count: int = 0

	for cell in building_cells:
		for dir in CARDINAL + DIAGONAL:
			var neighbor_cell: Vector2i = cell + dir
			if not occupied.has(neighbor_cell):
				continue
			var neighbor: Node2D = occupied[neighbor_cell]
			if neighbor == building or seen.has(neighbor):
				continue
			seen[neighbor] = true
			var data: BuildingData = _get_data(neighbor)
			if data != null and data.id == "ricefield_field":
				count += 1

	return count
