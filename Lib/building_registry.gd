# building_registry.gd
# Attach to a child Node under PlacementManager (or any persistent Node).
#
# Single responsibility: own the occupied-cell dictionary and expose a
# clean, typed API.  Zero UI, zero input, zero preview logic here.
#
# All placement and removal goes through this class so the rest of the
# codebase always has one authoritative source of truth for what is built.

class_name BuildingRegistry
extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────

## Emitted after a building is successfully registered.
signal building_placed(building: Node2D, cells: Array[Vector2i])

## Emitted after a building is successfully removed.
signal building_removed(building: Node2D, freed_cells: Array[Vector2i])

# ─── Internal state ───────────────────────────────────────────────────────────

## Maps every occupied map cell → the Node2D that owns it.
var _occupied: Dictionary = {}

# ─── Write API ────────────────────────────────────────────────────────────────

## Register [param building] as occupying [param cells].
## Emits [signal building_placed] on success.
func register(cells: Array[Vector2i], building: Node2D) -> void:
	for cell in cells:
		_occupied[cell] = building
	building_placed.emit(building, cells)


## Remove all cells owned by [param building] and call queue_free() on it.
## Returns the list of cells that were freed.
## Emits [signal building_removed] on success.
func unregister(building: Node2D) -> Array[Vector2i]:
	var freed: Array[Vector2i] = []
	for cell: Vector2i in _occupied.keys():
		if _occupied[cell] == building:
			freed.append(cell)
	for cell in freed:
		_occupied.erase(cell)
	building.queue_free()
	building_removed.emit(building, freed)
	return freed

# ─── Query API ────────────────────────────────────────────────────────────────

## Returns true if [param cell] is occupied by any building.
func is_occupied(cell: Vector2i) -> bool:
	return _occupied.has(cell)


## Returns the building occupying [param cell], or null if empty.
func get_building_at(cell: Vector2i) -> Node2D:
	return _occupied.get(cell, null) as Node2D


## Returns every map cell owned by [param building].
func get_cells_of(building: Node2D) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _occupied.keys():
		if _occupied[cell] == building:
			result.append(cell)
	return result


## Returns a deduplicated list of all placed buildings.
func get_all_buildings() -> Array[Node2D]:
	var seen: Dictionary = {}
	for building in _occupied.values():
		seen[building] = true
	var result: Array[Node2D] = []
	for building in seen.keys():
		result.append(building as Node2D)
	return result


## Returns all buildings whose [BuildingData] id matches [param id].
func get_buildings_by_id(id: String) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in get_all_buildings():
		var data := _get_building_data(building)
		if data != null and data.id == id:
			result.append(building)
	return result


## Returns all placed buildings that have [param flag] set to true on their BuildingData.
func get_buildings_with_flag(flag: StringName) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in get_all_buildings():
		var data := _get_building_data(building)
		if data != null and data.get(flag) == true:
			result.append(building)
	return result


## Returns all placed buildings whose BuildingData.building_type matches [param type].
func get_buildings_with_type(type: BuildingData.BuildingType) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in get_all_buildings():
		var data := _get_building_data(building)
		if data != null and data.building_type == type:
			result.append(building)
	return result


## Returns the raw occupied dictionary (read-only view — do not mutate).
func get_occupied_dict() -> Dictionary:
	return _occupied

# ─── Data accessor ───────────────────────────────────────────────────────────────

## Reads BuildingData from a node regardless of whether it has a script.
## Metadata is checked first so scriptless scenes (e.g. Path) work correctly.
func _get_building_data(building: Node2D) -> BuildingData:
	if building.has_meta("data"):
		var meta = building.get_meta("data")
		if meta is BuildingData:
			return meta as BuildingData
	var prop = building.get("data")
	if prop is BuildingData:
		return prop as BuildingData
	return null
