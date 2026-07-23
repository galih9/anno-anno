# restaurant.gd
# Public service building — acts as the destination/heart of the city and dispatch hub for resource collectors.

extends Node2D

enum Status { ACTIVE, DISCONNECTED }

const MAX_COLLECTORS: int = 4
var collector_scene: PackedScene = preload("res://Scenes/NPCs/Collector/Collector.tscn")

var data: BuildingData
var status: Status = Status.DISCONNECTED

var active_collectors: Array[Node2D] = []
var collection_queue: Array[Node2D] = []

func _ready() -> void:
	pass

func set_status(status_text: String, _desc: String) -> void:
	if status_text == "Connected":
		status = Status.ACTIVE
	else:
		status = Status.DISCONNECTED

func get_info_text() -> String:
	var active_count: int = 0
	for c in active_collectors:
		if is_instance_valid(c):
			active_count += 1
	return "Status: %s\nCollectors: %d/%d\nQueued: %d" % [
		Status.keys()[status],
		active_count,
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

	# Check if already targetted by an active collector
	for collector in active_collectors:
		if "target_resource_building" in collector and collector.target_resource_building == resource_building:
			return true

	# Check if already in queue
	if collection_queue.has(resource_building):
		return true

	# Check path connection
	var path_cells := _get_path_to_building(resource_building)
	if path_cells.is_empty():
		return false # Cannot collect if no path exists

	if active_collectors.size() < MAX_COLLECTORS:
		_dispatch_collector(resource_building, path_cells)
	else:
		collection_queue.append(resource_building)

	return true

func _dispatch_collector(resource_building: Node2D, path_cells: Array[Vector2i]) -> void:
	var land_layer = _get_land_layer()
	if land_layer == null:
		return

	var world_points: Array[Vector2] = []
	world_points.append(global_position)
	for cell in path_cells:
		var local_pos: Vector2 = land_layer.map_to_local(cell)
		world_points.append(land_layer.to_global(local_pos))
	world_points.append(resource_building.global_position)

	var collector_node := collector_scene.instantiate() as Node2D
	get_parent().add_child(collector_node)

	collector_node.setup(self, resource_building, world_points)
	active_collectors.append(collector_node)

## Called by a Collector NPC when it completes its return leg to the Restaurant.
func on_collector_returned(collector: Node2D, resource_type: String, amount: int) -> void:
	if active_collectors.has(collector):
		active_collectors.erase(collector)

	_cleanup_active_collectors()

	# Deposit resources directly into global player inventory
	if amount > 0:
		var main_node = _get_main_node()
		if main_node != null:
			if resource_type == "food" and "food" in main_node:
				main_node.food += amount
			elif resource_type == "log" and "log" in main_node:
				main_node.log += amount
			print("Restaurant ▸ Collected %d %s into global inventory." % [amount, resource_type])

	# Service the next item in the collection queue
	_process_queue()

func _process_queue() -> void:
	while not collection_queue.is_empty() and active_collectors.size() < MAX_COLLECTORS:
		var next_building = collection_queue.pop_front()
		if is_instance_valid(next_building):
			var path_cells := _get_path_to_building(next_building)
			if not path_cells.is_empty():
				_dispatch_collector(next_building, path_cells)
				break

func _cleanup_active_collectors() -> void:
	var valid_collectors: Array[Node2D] = []
	for c in active_collectors:
		if is_instance_valid(c):
			valid_collectors.append(c)
	active_collectors = valid_collectors

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
