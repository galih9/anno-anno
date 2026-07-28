extends Node2D

signal resources_updated(gold, food, log, population, monthly_income, avg_happiness, tax_rate)

var food: int = 100:
	set(value):
		food = value
		_update_ui()

var log: int = 50:
	set(value):
		log = value
		_update_ui()

var gold: int = 55500:
	set(value):
		gold = value
		_update_ui()

var population: int = 0:
	set(value):
		population = value
		_update_ui()

var tax_rate: int = 100:
	set(value):
		tax_rate = clamp(value, 0, 200)
		_update_ui()

var monthly_income: int = 0
var avg_happiness: float = 1.0
var active_houses_count: int = 0
var abandoned_houses_count: int = 0

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
	
	_on_resource_tick()

func set_tax_rate(new_rate: int) -> void:
	tax_rate = clamp(new_rate, 0, 200)
	var pm = get_node_or_null("PlacementManager")
	if pm and pm.has_node("ConnectionChecker"):
		pm.get_node("ConnectionChecker").update_all_connections()
	_on_resource_tick()

func _update_ui() -> void:
	resources_updated.emit(gold, food, log, population, monthly_income, avg_happiness, tax_rate)

func _on_resource_tick() -> void:
	var current_population = 0
	var gen_gold = 0
	var total_happiness: float = 0.0
	active_houses_count = 0
	abandoned_houses_count = 0
	
	var placement_manager = get_node_or_null("PlacementManager")
	if not placement_manager:
		_update_ui()
		return
	
	var registry = placement_manager.get_node_or_null("BuildingRegistry")
	if not registry:
		_update_ui()
		return
		
	var tax_factor: float = tax_rate / 100.0
	var gold_per_house: int = int(round(2.0 * tax_factor))

	# Process residents (population, gold, happiness tracking)
	var residents = registry.get_buildings_with_type(BuildingData.BuildingType.RESIDENT)
	for house in residents:
		if "happiness" in house:
			total_happiness += house.happiness
		if "status" in house:
			if house.status == 0: # ACTIVE
				active_houses_count += 1
				var cap = house.get_population_capacity() if house.has_method("get_population_capacity") else 4
				current_population += cap
				gen_gold += gold_per_house
			elif house.status == 1: # ABANDONED
				abandoned_houses_count += 1

	if residents.size() > 0:
		avg_happiness = total_happiness / residents.size()
	else:
		avg_happiness = 1.0

	# 1 minute = 12 ticks of 5s
	monthly_income = gen_gold * 12
			
	# Process resources (food and log into building local storage)
	var resources = registry.get_buildings_with_type(BuildingData.BuildingType.RESOURCE)
	for res in resources:
		if "status" in res and res.status == 0: # ACTIVE
			if res.has_method("process_tick"):
				res.process_tick()
			elif res.has_method("add_produced_resource"):
				res.add_produced_resource(5)

	# Apply calculated values
	population = current_population
	gold += gen_gold
	_update_ui()

