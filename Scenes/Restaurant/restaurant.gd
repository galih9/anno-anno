extends Node2D

@onready var label = $Container/Label

func set_status(status_text: String, desc_text: String) -> void:
	if label:
		label.text = "Status: " + status_text + "\nDesc: " + desc_text
