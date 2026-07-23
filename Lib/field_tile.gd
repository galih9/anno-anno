# field_tile.gd
# Represents a field tile associated with a resource generator building (e.g. Ricefield, Lumberjack).
#
# Statuses cycle: EMPTY -> SEEDING -> GROWING -> HARVESTING -> EMPTY
# Durations are now controlled by the parent building's export variables:
#   ticks_to_seed, ticks_to_grow, ticks_to_harvest

class_name FieldTile
extends Node2D

enum Status { EMPTY, SEEDING, GROWING, HARVESTING }

var status: Status = Status.EMPTY:
	set(value):
		status = value
		_update_visuals()

var growing_ticks: int = 0
var work_ticks: int = 0
var owner_building: Node2D = null

var is_worked_on: bool = false:
	set(value):
		is_worked_on = value
		queue_redraw()

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	z_index = 1
	_update_visuals()

func _process(_delta: float) -> void:
	if is_worked_on:
		queue_redraw()

func _update_visuals() -> void:
	if sprite == null and has_node("Sprite2D"):
		sprite = get_node("Sprite2D") as Sprite2D
	
	if sprite != null:
		match status:
			Status.EMPTY:
				sprite.modulate = Color(0.85, 0.75, 0.65) # Bare earth tint
			Status.SEEDING:
				sprite.modulate = Color(0.75, 0.92, 0.55) # Sprout tint
			Status.GROWING:
				sprite.modulate = Color(0.35, 0.85, 0.3) # Lush green growing tint
			Status.HARVESTING:
				sprite.modulate = Color(0.98, 0.85, 0.2) # Ripe golden harvest tint

func reset_to_empty() -> void:
	status = Status.EMPTY
	growing_ticks = 0
	work_ticks = 0
	is_worked_on = false

func _draw() -> void:
	if not is_worked_on:
		return

	# Draw animated/pulsing worker highlight frame around the field tile
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
	var stroke_color := Color(1.0, 0.9, 0.2, pulse) # Bright golden highlight
	var fill_color := Color(1.0, 0.85, 0.1, pulse * 0.35)
	
	var rect_size := Vector2(16, 16)
	if sprite != null and sprite.texture != null:
		rect_size = sprite.texture.get_size()
	
	var rect := Rect2(-rect_size / 2.0, rect_size)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, stroke_color, false, 2.0)

	# Corner accents
	var c_len := 4.0
	var c_color := Color(1.0, 1.0, 1.0, pulse * 0.9)
	# TL
	draw_line(rect.position, rect.position + Vector2(c_len, 0), c_color, 2.0)
	draw_line(rect.position, rect.position + Vector2(0, c_len), c_color, 2.0)
	# TR
	var tr := rect.position + Vector2(rect.size.x, 0)
	draw_line(tr, tr + Vector2(-c_len, 0), c_color, 2.0)
	draw_line(tr, tr + Vector2(0, c_len), c_color, 2.0)
	# BL
	var bl := rect.position + Vector2(0, rect.size.y)
	draw_line(bl, bl + Vector2(c_len, 0), c_color, 2.0)
	draw_line(bl, bl + Vector2(0, -c_len), c_color, 2.0)
	# BR
	var br := rect.position + rect.size
	draw_line(br, br + Vector2(-c_len, 0), c_color, 2.0)
	draw_line(br, br + Vector2(0, -c_len), c_color, 2.0)
