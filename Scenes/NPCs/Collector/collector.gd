# collector.gd
# NPC collector script.
# Moves along pathway positions to collect resources from a Resource building
# and return them to the Restaurant. Includes transfer rate per tick.

extends Node2D

const SPEED: float = 15.0 # Moderate/slow movement speed in pixels per second

@export_group("Transfer Settings")
@export var items_per_tick: int = 2
@export var transfer_tick_time: float = 1.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var status_label: Label = $StatusLabel if has_node("StatusLabel") else null

var path_world_points: Array[Vector2] = []
var current_waypoint_idx: int = 0

# States: "IDLE", "MOVING_TO_RESOURCE", "TRANSFER_IN", "MOVING_TO_RESTAURANT", "TRANSFER_OUT", "FINISHED"
var state: String = "IDLE"

var target_resource_building: Node2D = null
var home_restaurant: Node2D = null

var carrying_resource_type: String = ""
var carrying_amount: int = 0

var transfer_timer: float = 0.0

func setup(p_restaurant: Node2D, p_target: Node2D, p_path_points: Array[Vector2]) -> void:
	home_restaurant = p_restaurant
	target_resource_building = p_target
	path_world_points = p_path_points
	current_waypoint_idx = 0
	state = "MOVING_TO_RESOURCE"
	transfer_timer = 0.0
	visible = true
	
	if not path_world_points.is_empty():
		global_position = path_world_points[0]
	_update_label()

func _process(delta: float) -> void:
	match state:
		"MOVING_TO_RESOURCE", "MOVING_TO_RESTAURANT":
			_process_movement(delta)
		"TRANSFER_IN":
			_process_transfer_in(delta)
		"TRANSFER_OUT":
			_process_transfer_out(delta)

func process_tick() -> void:
	if state == "TRANSFER_IN":
		_do_transfer_in_tick()
	elif state == "TRANSFER_OUT":
		_do_transfer_out_tick()

func _process_movement(delta: float) -> void:
	if path_world_points.is_empty() or current_waypoint_idx >= path_world_points.size():
		_on_reached_leg_end()
		return

	var target_pos := path_world_points[current_waypoint_idx]
	var to_target := target_pos - global_position
	var dist := to_target.length()

	if dist < 2.0: # Close enough to waypoint
		current_waypoint_idx += 1
		if current_waypoint_idx >= path_world_points.size():
			_on_reached_leg_end()
		return

	var dir := to_target.normalized()
	_update_animation(dir)

	var step := SPEED * delta
	if step >= dist:
		global_position = target_pos
		current_waypoint_idx += 1
		if current_waypoint_idx >= path_world_points.size():
			_on_reached_leg_end()
	else:
		global_position += dir * step

func _update_animation(dir: Vector2) -> void:
	if sprite == null:
		return

	if dir.y < 0:
		sprite.animation = &"move_ne"
		sprite.flip_h = (dir.x < 0)
	else:
		sprite.animation = &"move_se"
		sprite.flip_h = (dir.x < 0)

	if not sprite.is_playing():
		sprite.play()

func _on_reached_leg_end() -> void:
	if state == "MOVING_TO_RESOURCE":
		state = "TRANSFER_IN"
		transfer_timer = 0.0
		visible = false
		if sprite != null:
			sprite.stop()
		if is_instance_valid(target_resource_building) and "resource_type" in target_resource_building:
			carrying_resource_type = target_resource_building.resource_type
		_update_label()
		# Perform initial transfer tick
		_do_transfer_in_tick()

	elif state == "MOVING_TO_RESTAURANT":
		if carrying_amount > 0:
			state = "TRANSFER_OUT"
			transfer_timer = 0.0
			visible = false
			if sprite != null:
				sprite.stop()
			_update_label()
			# Perform initial transfer tick
			_do_transfer_out_tick()
		else:
			_finish_return()

func _process_transfer_in(delta: float) -> void:
	transfer_timer += delta
	if transfer_timer >= transfer_tick_time:
		transfer_timer -= transfer_tick_time
		_do_transfer_in_tick()

func _do_transfer_in_tick() -> void:
	if state != "TRANSFER_IN":
		return

	var transferred_this_tick: int = 0
	if is_instance_valid(target_resource_building):
		var target_storage: int = 0
		if "storage" in target_resource_building:
			target_storage = target_resource_building.storage

		if target_storage > 0:
			var to_collect: int = min(items_per_tick, target_storage)
			if target_resource_building.has_method("collect_resources"):
				transferred_this_tick = target_resource_building.collect_resources(to_collect)
			else:
				target_resource_building.storage -= to_collect
				transferred_this_tick = to_collect
			
			carrying_amount += transferred_this_tick

		if target_storage <= 0 or transferred_this_tick == 0 or target_resource_building.storage <= 0:
			_start_return_leg()
			return
	else:
		_start_return_leg()
		return

	_update_label()

func _start_return_leg() -> void:
	var return_path: Array[Vector2] = path_world_points.duplicate()
	return_path.reverse()
	path_world_points = return_path
	current_waypoint_idx = 0
	state = "MOVING_TO_RESTAURANT"
	visible = true
	if sprite != null:
		sprite.play()
	_update_label()

func _process_transfer_out(delta: float) -> void:
	transfer_timer += delta
	if transfer_timer >= transfer_tick_time:
		transfer_timer -= transfer_tick_time
		_do_transfer_out_tick()

func _do_transfer_out_tick() -> void:
	if state != "TRANSFER_OUT":
		return

	if carrying_amount > 0:
		var to_deposit: int = min(items_per_tick, carrying_amount)
		carrying_amount -= to_deposit
		if is_instance_valid(home_restaurant) and home_restaurant.has_method("deposit_resource"):
			home_restaurant.deposit_resource(carrying_resource_type, to_deposit)
		_update_label()

	if carrying_amount <= 0:
		_finish_return()

func _finish_return() -> void:
	state = "FINISHED"
	if is_instance_valid(home_restaurant) and home_restaurant.has_method("on_collector_returned"):
		home_restaurant.on_collector_returned(self, carrying_resource_type, 0)
	queue_free()

func _update_label() -> void:
	if status_label == null:
		return

	match state:
		"TRANSFER_IN":
			status_label.text = "Loading... (%d)" % carrying_amount
		"TRANSFER_OUT":
			status_label.text = "Unloading... (%d)" % carrying_amount
		"MOVING_TO_RESTAURANT":
			if carrying_amount > 0:
				status_label.text = "%d %s" % [carrying_amount, carrying_resource_type.capitalize()]
			else:
				status_label.text = ""
		_:
			status_label.text = ""
