extends Node2D

signal resources_updated(gold, food, log, population, monthly_income, avg_happiness, tax_rate)
signal building_unlocked(building_data: BuildingData)

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
var gross_tax_monthly: int = 0
var total_maintenance_monthly: int = 0
var building_maintenance_breakdown: Dictionary = {}

var avg_happiness: float = 1.0
var active_houses_count: int = 0
var abandoned_houses_count: int = 0
var tick_counter: int = 0

var unlocked_building_ids: Array[String] = ["townhall", "path"]
var townhall_placed: bool = false

func _ready() -> void:
	# Create and add a Timer dynamically for resource generation
	var timer = Timer.new()
	timer.name = "ResourceTimer"
	timer.wait_time = 5.0
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_on_resource_tick)

	var ui = load("res://Lib/ui_manager.gd").new()
	ui.name = "UIManager"
	add_child(ui)

	_on_resource_tick()

func is_building_unlocked(b_data: BuildingData) -> bool:
	if b_data == null:
		return false
	if b_data.id in unlocked_building_ids:
		return true
	return false

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

	var townhalls = registry.get_buildings_with_type(BuildingData.BuildingType.GOVERNMENT)
	townhall_placed = not townhalls.is_empty()

	var tax_factor: float = tax_rate / 100.0
	var gold_per_house: int = int(round(2.0 * tax_factor))

	tick_counter += 1
	var is_monthly_tick: bool = (tick_counter >= 12)
	if is_monthly_tick:
		tick_counter = 0

	# Process residents (population, gold, happiness tracking, monthly food consumption)
	var residents = registry.get_buildings_with_type(BuildingData.BuildingType.RESIDENT)
	for house in residents:
		if is_monthly_tick:
			var food_cost = house.get_monthly_food_cost() if house.has_method("get_monthly_food_cost") else 1
			if food >= food_cost:
				food -= food_cost
				if house.has_method("on_food_supplied"):
					house.on_food_supplied()
			else:
				if house.has_method("on_food_deprived"):
					house.on_food_deprived()

		if "happiness" in house:
			total_happiness += house.happiness
		if "status" in house:
			if house.status == 0: # ACTIVE
				active_houses_count += 1
				var cap = house.get_population_capacity() if house.has_method("get_population_capacity") else 4
				current_population += cap
				var house_lvl = house.level if "level" in house else 0
				var base_tax = int(round(gold_per_house * (2.5 if house_lvl == 1 else 1.0)))
				var boost_mult: float = 1.5 if ("has_townhall_bonus" in house and house.has_townhall_bonus) else 1.0
				var house_tax = int(round(float(base_tax) * boost_mult))
				gen_gold += house_tax
			elif house.status == 1: # ABANDONED
				abandoned_houses_count += 1

	if residents.size() > 0:
		avg_happiness = total_happiness / residents.size()
	else:
		avg_happiness = 1.0

	# Process resource buildings (ticks + maintenance tracking)
	var resources = registry.get_buildings_with_type(BuildingData.BuildingType.RESOURCE)
	total_maintenance_monthly = 0
	building_maintenance_breakdown.clear()

	for res in resources:
		var data: BuildingData = null
		if res.has_meta("data"):
			data = res.get_meta("data") as BuildingData
		elif "data" in res:
			data = res.data as BuildingData

		if data != null and data.maintenance_cost > 0:
			var b_name = data.display_name
			total_maintenance_monthly += data.maintenance_cost
			building_maintenance_breakdown[b_name] = building_maintenance_breakdown.get(b_name, 0) + data.maintenance_cost

		if "status" in res and res.status == 0: # ACTIVE
			if res.has_method("process_tick"):
				res.process_tick()
			elif res.has_method("add_produced_resource"):
				res.add_produced_resource(5)

	# 1 minute = 12 ticks of 5s
	gross_tax_monthly = gen_gold * 12
	monthly_income = gross_tax_monthly - total_maintenance_monthly

	# Apply calculated net gold per tick
	var tick_maintenance = float(total_maintenance_monthly) / 12.0
	var net_tick_gold = int(round(float(gen_gold) - tick_maintenance))

	population = current_population
	gold = max(0, gold + net_tick_gold)

	_check_progression_unlocks(current_population, placement_manager)
	_update_ui()

func _check_progression_unlocks(curr_pop: int, pm: Node) -> void:
	if pm == null or not ("buildings" in pm):
		return

	for b_data in pm.buildings:
		if b_data == null or b_data.id in unlocked_building_ids:
			continue

		var should_unlock: bool = false
		if b_data.requires_townhall:
			if townhall_placed:
				should_unlock = true
		elif b_data.required_population > 0:
			if curr_pop >= b_data.required_population:
				should_unlock = true
		elif b_data.id == "bench" and townhall_placed:
			should_unlock = true

		if should_unlock:
			unlocked_building_ids.append(b_data.id)
			building_unlocked.emit(b_data)

			var ui_manager = get_node_or_null("UIManager")
			if ui_manager and ui_manager.has_method("show_toast"):
				var desc = "New building available in Build Menu!"
				if b_data.required_population > 0:
					desc = "Reached %d Population milestone!" % b_data.required_population
				elif b_data.requires_townhall:
					desc = "Unlocked after constructing Townhall!"
				ui_manager.show_toast("🎉 UNLOCKED: %s" % b_data.display_name, desc)

