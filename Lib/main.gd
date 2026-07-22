extends Node2D

var food: int = 100
var log: int = 50
var gold: int = 500:
	set(value):
		gold = value
		_update_gold_label()

@onready var gold_label: Label = %Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_gold_label()

func _update_gold_label() -> void:
	if gold_label != null:
		gold_label.text = "Gold: " + str(gold)
