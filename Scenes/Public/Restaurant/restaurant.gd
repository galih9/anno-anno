# restaurant.gd
# Public service building — acts as a necessity for houses, providing a population boost within its influence radius.

extends Node2D

enum Status { ACTIVE, DISCONNECTED }

var data: BuildingData
var status: Status = Status.DISCONNECTED

func _ready() -> void:
	pass

func set_status(status_text: String, _desc: String) -> void:
	if status_text == "Connected":
		status = Status.ACTIVE
	else:
		status = Status.DISCONNECTED

func get_info_text() -> String:
	var status_str = "Aktif" if status == Status.ACTIVE else "Terputus"
	return "Status: %s\nJangkauan Pengaruh: %d" % [
		status_str,
		data.influence_radius if data else 5
	]
