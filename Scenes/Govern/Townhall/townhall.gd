# townhall.gd
# Government building — acts as the destination/heart of the city and dispatch hub for resource collectors.

extends Node2D

enum Status { ACTIVE, DISCONNECTED }

const MAX_COLLECTORS: int = 4
var collector_scene: PackedScene = preload("res://Scenes/NPCs/Collector/Collector.tscn")

var data: BuildingData
var status: Status = Status.DISCONNECTED

var active_collectors: Array[Node2D] = []
var collection_queue: Array[Node2D] = []
var scan_timer: float = 0.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	scan_timer += delta
	if scan_timer >= 1.0:
		scan_timer = 0.0
		_scan_and_process_resource_collections()

func set_status(status_text: String, _desc: String) -> void:
	if status_text == "Connected":
		status = Status.ACTIVE
	else:
		status = Status.DISCONNECTED

func get_info_text() -> String:
	_cleanup_active_collectors()
	_cleanup_queue()
	var status_str = "Aktif" if status == Status.ACTIVE else "Terputus"
	return "Status: %s\nPengangkut: %d/%d\nDalam Antrean: %d" % [
		status_str,
		active_collectors.size(),
		MAX_COLLECTORS,
		collection_queue.size()
	]

## Request a collector dispatch to [param resource_building].
## Returns true if the collection was accepted (dispatched or queued).
func request_collection(resource_building: Node2D) -> bool:
	if not is_instance_valid(resource_building):
		return false

	# Clean dead references
	_cleanup_active_collectors()
	_cleanup_queue()

	# Check if already targetted by an active collector
	if _is_targeted_by_collector(resource_building):
		if "is_collection_pending" in resource_building:
			resource_building.is_collection_pending = true
		return true

	# Check if already in queue
	if collection_queue.has(resource_building):
		if "is_collection_pending" in resource_building:
			resource_building.is_collection_pending = true
		return true

	# Check path connection
	var path_cells := _get_path_to_building(resource_building)
	if path_cells.is_empty():
		return false # Cannot collect if no path exists

	if "is_collection_pending" in resource_building:
		resource_building.is_collection_pending = true

	if active_collectors.size() < MAX_COLLECTORS:
		_dispatch_collector(resource_building, path_cells)
	else:
		collection_queue.append(resource_building)

	return true

func _scan_and_process_resource_collections() -> void:
	_cleanup_active_collectors()
	_cleanup_queue()

	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var pm = tree.root.find_child("PlacementManager", true, false)
	if pm == null:
		return
	var registry = pm.get_node_or_null("BuildingRegistry")
	if registry == null:
		return

	# Query all resource-type buildings
	var resource_buildings = registry.get_buildings_with_type(BuildingData.BuildingType.RESOURCE)
	for res in resource_buildings:
		if not is_instance_valid(res):
			continue
		
		# Skip field tiles (which have id == "ricefield_field" or "lumberjack_field")
		var is_field: bool = false
		if res.has_meta("data"):
			var d = res.get_meta("data")
			if d is BuildingData and (d.id.ends_with("_field") or d.id == "ricefield_field"):
				is_field = true
		if is_field:
			continue

		var storage_count: int = 0
		if "storage" in res:
			storage_count = res.storage

		if storage_count > 0:
			if not _is_targeted_by_collector(res) and not collection_queue.has(res):
				var path_cells := _get_path_to_building(res)
				if not path_cells.is_empty():
					if "is_collection_pending" in res:
						res.is_collection_pending = true
					collection_queue.append(res)

	_process_queue()

func _dispatch_collector(resource_building: Node2D, path_cells: Array[Vector2i]) -> void:
	var land_layer = _get_land_layer()
	if land_layer == null or path_cells.is_empty():
		return

	var world_points: Array[Vector2] = []
	for cell in path_cells:
		var local_pos: Vector2 = land_layer.map_to_local(cell)
		world_points.append(land_layer.to_global(local_pos))

	var collector_node := collector_scene.instantiate() as Node2D
	get_parent().add_child(collector_node)

	collector_node.setup(self, resource_building, world_points)
	active_collectors.append(collector_node)

## Deposit resources directly into global player inventory.
func deposit_resource(resource_type: String, amount: int) -> void:
	if amount > 0:
		var main_node = _get_main_node()
		if main_node != null:
			if resource_type == "food" and "food" in main_node:
				main_node.food += amount
			elif resource_type == "log" and "log" in main_node:
				main_node.log += amount
			print("Townhall ▸ Deposited %d %s into global inventory." % [amount, resource_type])

## Called by a Collector NPC when it completes its return leg to the Townhall.
func on_collector_returned(collector: Node2D, resource_type: String, amount: int) -> void:
	if active_collectors.has(collector):
		active_collectors.erase(collector)

	_cleanup_active_collectors()
	_cleanup_queue()

	# Deposit any remaining resources directly into global inventory
	if amount > 0:
		deposit_resource(resource_type, amount)

	# Service the next items in the collection queue
	_process_queue()

func _process_queue() -> void:
	_cleanup_active_collectors()
	_cleanup_queue()

	while not collection_queue.is_empty() and active_collectors.size() < MAX_COLLECTORS:
		var next_building = collection_queue.pop_front()
		if is_instance_valid(next_building):
			var storage_count: int = 0
			if "storage" in next_building:
				storage_count = next_building.storage

			if storage_count <= 0:
				if "is_collection_pending" in next_building:
					next_building.is_collection_pending = false
				continue

			var path_cells := _get_path_to_building(next_building)
			if not path_cells.is_empty():
				_dispatch_collector(next_building, path_cells)
			else:
				if "is_collection_pending" in next_building:
					next_building.is_collection_pending = false

func _is_targeted_by_collector(resource_building: Node2D) -> bool:
	for collector in active_collectors:
		if is_instance_valid(collector) and "target_resource_building" in collector:
			if collector.target_resource_building == resource_building:
				return true
	return false

func _cleanup_active_collectors() -> void:
	var valid_collectors: Array[Node2D] = []
	for c in active_collectors:
		if is_instance_valid(c):
			valid_collectors.append(c)
	active_collectors = valid_collectors

func _cleanup_queue() -> void:
	var valid_queue: Array[Node2D] = []
	for b in collection_queue:
		if is_instance_valid(b) and not valid_queue.has(b):
			valid_queue.append(b)
	collection_queue = valid_queue

func _get_path_to_building(target_building: Node2D) -> Array[Vector2i]:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return []
	var pm = tree.root.find_child("PlacementManager", true, false)
	if pm and pm.has_node("ConnectionChecker"):
		var checker = pm.get_node("ConnectionChecker")
		if checker.has_method("find_path"):
			return checker.find_path(self, target_building)
	return []

func _get_land_layer() -> TileMapLayer:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	var layer = tree.root.find_child("LandLayer", true, false)
	return layer as TileMapLayer

func _get_main_node() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.find_child("Main", true, false)

func get_current_warning() -> String:
	if status == Status.DISCONNECTED:
		return "disconnect"
	return ""


