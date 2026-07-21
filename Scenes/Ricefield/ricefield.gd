extends Node2D

## BuildingData resource injected by PlacementManager at placement time.
var data: BuildingData

@onready var label = $Container/Label

func set_status(status_text: String, desc_text: String) -> void:
	if label:
		label.text = "Status: " + status_text + "\nDesc: " + desc_text
