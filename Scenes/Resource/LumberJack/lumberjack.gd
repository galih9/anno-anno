# lumberjack.gd
# Resource-type building.
#
# Status:
#   ACTIVE       — connected to destination via path AND has adjacent field tiles
#   INACTIVE     — placed but conditions not yet met (path ok, missing fields) or paused by user
#   DISCONNECTED — missing path connection

extends Node2D

enum Status { ACTIVE, INACTIVE, DISCONNECTED }

# ─── Settings ─────────────────────────────────────────────────────────────────

@export_group("Resource Settings")
@export var ticks_to_seed: int = 1
@export var ticks_to_grow: int = 3
@export var ticks_to_harvest: int = 2
@export var resource_per_harvest: int = 5

# ─── State ────────────────────────────────────────────────────────────────────

## BuildingData resource injected by PlacementManager at placement time.
var data: BuildingData
var status: Status = Status.DISCONNECTED
var is_user_active: bool = true

var storage: int = 0
var max_storage: int = 20
var resource_type: String = "log"
var is_collection_pending: bool = false
var time_since_dispatch: float = 0.0

var worker_count: int = 1
var active_worker_field: FieldTile = null
var last_worked_field: FieldTile = null

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if status == Status.ACTIVE and is_user_active:
		time_since_dispatch += delta
		if not is_collection_pending:
			if storage >= 10 or (time_since_dispatch >= 60.0 and storage > 0):
				check_trigger_collection()

func process_tick() -> void:
	if status != Status.ACTIVE or not is_user_active:
		_clear_worker_work()
		return

	var fields: Array[FieldTile] = _get_adjacent_field_nodes()
	if fields.is_empty():
		_clear_worker_work()
		return

	# Step 1: Advance GROWING fields
	for field in fields:
		if field.status == FieldTile.Status.GROWING:
			field.growing_ticks += 1
			if field.growing_ticks >= ticks_to_grow:
				field.status = FieldTile.Status.HARVESTING
				field.work_ticks = 0

	# Step 2: Advance current worker task if active
	if is_instance_valid(active_worker_field) and fields.has(active_worker_field):
		active_worker_field.work_ticks += 1
		if active_worker_field.status == FieldTile.Status.SEEDING:
			if active_worker_field.work_ticks >= ticks_to_seed:
				active_worker_field.status = FieldTile.Status.GROWING
				active_worker_field.growing_ticks = 0
				active_worker_field.is_worked_on = false
				active_worker_field = null
		elif active_worker_field.status == FieldTile.Status.HARVESTING:
			if active_worker_field.work_ticks >= ticks_to_harvest:
				add_produced_resource(resource_per_harvest)
				active_worker_field.reset_to_empty()
				active_worker_field = null

	# Step 3: Assign worker to next task if free
	if active_worker_field == null:
		var target_field: FieldTile = null
		
		var start_idx: int = 0
		if is_instance_valid(last_worked_field):
			var idx = fields.find(last_worked_field)
			if idx != -1:
				start_idx = (idx + 1) % fields.size()

		# Priority 1: Harvest fields ready for harvesting
		for i in range(fields.size()):
			var idx = (start_idx + i) % fields.size()
			var field = fields[idx]
			if field.status == FieldTile.Status.HARVESTING and not field.is_worked_on:
				target_field = field
				break

		# Priority 2: Empty fields ready for seeding
		if target_field == null:
			for i in range(fields.size()):
				var idx = (start_idx + i) % fields.size()
				var field = fields[idx]
				if field.status == FieldTile.Status.EMPTY and not field.is_worked_on:
					target_field = field
					break

		if target_field != null:
			active_worker_field = target_field
			last_worked_field = target_field
			active_worker_field.is_worked_on = true
			active_worker_field.work_ticks = 1

			# Handle instant completion for 1-tick (or 0-tick) tasks
			if active_worker_field.status == FieldTile.Status.EMPTY:
				active_worker_field.status = FieldTile.Status.SEEDING
				
			if active_worker_field.status == FieldTile.Status.SEEDING and active_worker_field.work_ticks >= ticks_to_seed:
				active_worker_field.status = FieldTile.Status.GROWING
				active_worker_field.growing_ticks = 0
				active_worker_field.is_worked_on = false
				active_worker_field = null
			elif active_worker_field.status == FieldTile.Status.HARVESTING and active_worker_field.work_ticks >= ticks_to_harvest:
				add_produced_resource(resource_per_harvest)
				active_worker_field.reset_to_empty()
				active_worker_field = null

func _clear_worker_work() -> void:
	if is_instance_valid(active_worker_field):
		active_worker_field.is_worked_on = false
		active_worker_field = null

func toggle_user_active() -> void:
	is_user_active = !is_user_active
	if not is_user_active:
		_clear_worker_work()

func add_produced_resource(amount: int) -> void:
	if status == Status.ACTIVE and is_user_active:
		storage = min(max_storage, storage + amount)
		if not is_collection_pending:
			if storage >= 10 or (time_since_dispatch >= 60.0 and storage > 0):
				check_trigger_collection()

func check_trigger_collection() -> void:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return
	var placement_manager = tree.root.find_child("PlacementManager", true, false)
	if not placement_manager:
		return
	var registry = placement_manager.get_node_or_null("BuildingRegistry")
	if not registry:
		return
	var restaurants = registry.get_buildings_by_id("restaurant")
	for rest in restaurants:
		if rest.has_method("request_collection"):
			if rest.request_collection(self):
				is_collection_pending = true
				time_since_dispatch = 0.0
				break

func collect_resources() -> int:
	var collected = storage
	storage = 0
	is_collection_pending = false
	time_since_dispatch = 0.0
	return collected

# ─── Public API ───────────────────────────────────────────────────────────────

func get_info_text() -> String:
	var fields: Array[FieldTile] = _get_adjacent_field_nodes()
	var empty_count: int = 0
	var growing_count: int = 0
	var harvesting_count: int = 0

	for f in fields:
		match f.status:
			FieldTile.Status.EMPTY: empty_count += 1
			FieldTile.Status.GROWING: growing_count += 1
			FieldTile.Status.HARVESTING: harvesting_count += 1

	var effective_status: String
	if not is_user_active:
		effective_status = "INACTIVE (Paused)"
	else:
		effective_status = Status.keys()[status]

	var worker_state: String = "Working" if is_instance_valid(active_worker_field) else "Idle"

	return "Status: %s\nStorage: %d/%d (%s)\nWorker: 1/1 (%s)\nFields: %d (Empty:%d Grow:%d Harvest:%d)" % [
		effective_status,
		storage,
		max_storage,
		resource_type.capitalize(),
		worker_state if (status == Status.ACTIVE and is_user_active) else "Stopped",
		fields.size(),
		empty_count,
		growing_count,
		harvesting_count
	]

func set_status(status_text: String, desc_text: String) -> void:
	if status_text == "Connected":
		status = Status.ACTIVE
	else:
		if "no path" in desc_text:
			status = Status.DISCONNECTED
		else:
			status = Status.INACTIVE

	if status != Status.ACTIVE or not is_user_active:
		_clear_worker_work()

func _get_adjacent_field_nodes() -> Array[FieldTile]:
	var result: Array[FieldTile] = []
	var tree = get_tree()
	if tree == null or tree.root == null:
		return result
	var placement_manager = tree.root.find_child("PlacementManager", true, false)
	if not placement_manager:
		return result
	var registry = placement_manager.get_node_or_null("BuildingRegistry")
	if not registry:
		return result

	var occupied: Dictionary = registry.get_occupied_dict()
	var building_cells: Array[Vector2i] = registry.get_cells_of(self)
	var seen: Dictionary = {}

	# Clockwise order starting from North for diamond-down isometric grid
	const SURROUNDING: Array[Vector2i] = [
		Vector2i(-1, -1), # North
		Vector2i(0, -1),  # North-East
		Vector2i(1, -1),  # East
		Vector2i(1, 0),   # South-East
		Vector2i(1, 1),   # South
		Vector2i(0, 1),   # South-West
		Vector2i(-1, 1),  # West
		Vector2i(-1, 0)   # North-West
	]

	for cell in building_cells:
		for dir in SURROUNDING:
			var neighbor_cell: Vector2i = cell + dir
			if not occupied.has(neighbor_cell):
				continue
			var neighbor: Node2D = occupied[neighbor_cell]
			if neighbor == self or seen.has(neighbor):
				continue
			seen[neighbor] = true
			if neighbor is FieldTile and is_instance_valid(neighbor):
				var field: FieldTile = neighbor as FieldTile
				if field.owner_building == self or field.owner_building == null:
					if field.owner_building == null:
						field.owner_building = self
					result.append(field)

	return result
