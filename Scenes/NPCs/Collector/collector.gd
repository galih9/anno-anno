# collector.gd
# NPC collector script.
# Moves along pathway positions to collect resources from a Resource building
# and return them to the Restaurant.

extends Node2D

const SPEED: float = 45.0 # Moderate/slow movement speed in pixels per second

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var path_world_points: Array[Vector2] = []
var current_waypoint_idx: int = 0
var state: String = "IDLE" # "MOVING_TO_RESOURCE", "COLLECTING", "MOVING_TO_RESTAURANT", "FINISHED"

var target_resource_building: Node2D = null
var home_restaurant: Node2D = null

var carrying_resource_type: String = ""
var carrying_amount: int = 0

func setup(p_restaurant: Node2D, p_target: Node2D, p_path_points: Array[Vector2]) -> void:
	home_restaurant = p_restaurant
	target_resource_building = p_target
	path_world_points = p_path_points
	current_waypoint_idx = 0
	state = "MOVING_TO_RESOURCE"
	
	if not path_world_points.is_empty():
		global_position = path_world_points[0]

func _process(delta: float) -> void:
	if state == "MOVING_TO_RESOURCE" or state == "MOVING_TO_RESTAURANT":
		_process_movement(delta)

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

	# Determine direction based on 2D screen movement vector
	# North/Up: dir.y < 0
	# South/Down: dir.y >= 0
	if dir.y < 0:
		sprite.animation = &"move_ne"
		sprite.flip_h = (dir.x < 0) # NW if flip_h is true, NE if false
	else:
		sprite.animation = &"move_se"
		sprite.flip_h = (dir.x < 0) # SW if flip_h is true, SE if false

	if not sprite.is_playing():
		sprite.play()

func _on_reached_leg_end() -> void:
	if state == "MOVING_TO_RESOURCE":
		state = "COLLECTING"
		if is_instance_valid(target_resource_building):
			if "resource_type" in target_resource_building:
				carrying_resource_type = target_resource_building.resource_type
			if target_resource_building.has_method("collect_resources"):
				carrying_amount = target_resource_building.collect_resources()

		# Prepare return path to Restaurant
		var return_path: Array[Vector2] = path_world_points.duplicate()
		return_path.reverse()
		path_world_points = return_path
		current_waypoint_idx = 0
		state = "MOVING_TO_RESTAURANT"

	elif state == "MOVING_TO_RESTAURANT":
		state = "FINISHED"
		if is_instance_valid(home_restaurant) and home_restaurant.has_method("on_collector_returned"):
			home_restaurant.on_collector_returned(self, carrying_resource_type, carrying_amount)
		queue_free()
