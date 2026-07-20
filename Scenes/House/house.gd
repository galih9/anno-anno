extends Node2D

@onready var label = $Container/Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_status(status_text: String, desc_text: String) -> void:
	if label:
		label.text = "Status: " + status_text + "\nDesc: " + desc_text
