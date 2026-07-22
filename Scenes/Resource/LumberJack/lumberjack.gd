extends Node2D

enum Status { ACTIVE, INACTIVE, DISCONNECTED }

var data: BuildingData
var status: Status = Status.DISCONNECTED

@onready var label = $Container/Label

func _ready() -> void:
	_refresh_label()

func set_status(status_text: String, desc_text: String) -> void:
	if status_text == "Connected":
		status = Status.ACTIVE
	else:
		if "no path" in desc_text:
			status = Status.DISCONNECTED
		else:
			status = Status.INACTIVE
	_refresh_label()

func _refresh_label() -> void:
	if label == null:
		return
	label.text = "Lumberjack\nStatus: %s" % Status.keys()[status]
