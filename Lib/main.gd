extends Node2D

signal resources_updated(gold, food, log, population)

var food: int = 100:
	set(value):
		food = value
		_update_ui()

var log: int = 50:
	set(value):
		log = value
		_update_ui()

var gold: int = 500:
	set(value):
		gold = value
		_update_ui()

var population: int = 0:
	set(value):
		population = value
		_update_ui()

func _ready() -> void:
	# Create and add a Timer dynamically for resource generation
	var timer = Timer.new()
	timer.name = "ResourceTimer"
	timer.wait_time = 5.0
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_on_resource_tick)
	
	var ui = load("res://Lib/ui_manager.gd").new()
	add_child(ui)
	
	_update_ui()

func _update_ui() -> void:
	resources_updated.emit(gold, food, log, population)

func _on_resource_tick() -> void:
	var current_population = 0
	var gen_gold = 0
	var gen_food = 0
	var gen_log = 0
	
	var placement_manager = get_node_or_null("PlacementManager")
	if not placement_manager:
		return
	
	var registry = placement_manager.get_node_or_null("BuildingRegistry")
	if not registry:
		return
		
	# Process residents (population and gold)
	var residents = registry.get_buildings_with_type(BuildingData.BuildingType.RESIDENT)
	for house in residents:
		if "status" in house and house.status == 0: # ACTIVE
			var cap = house.POPULATION_CAPACITY if "POPULATION_CAPACITY" in house else 4
			current_population += cap
			gen_gold += 2 # Gold generation per house
			
	# Process resources (food and log)
	var resources = registry.get_buildings_with_type(BuildingData.BuildingType.RESOURCE)
	for res in resources:
		if "status" in res and res.status == 0: # ACTIVE
			if "data" in res and res.data:
				if res.data.id == "lumberjack":
					gen_log += 5
				elif res.data.is_ricefield:
					gen_food += 5
					
	# Apply calculated values
	population = current_population
	gold += gen_gold
	food += gen_food
	log += gen_log
