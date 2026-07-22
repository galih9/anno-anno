extends CanvasLayer

var font = preload("res://Assets/Silkscreen-Regular.ttf")
var font_settings = LabelSettings.new()

var info_panel: PanelContainer
var gold_label: Label
var food_label: Label
var log_label: Label
var pop_label: Label

var always_visible_gold_label: Label

var build_panel: PanelContainer

func _ready() -> void:
	font_settings.font = font
	font_settings.font_size = 16
	
	# Standalone gold label
	always_visible_gold_label = Label.new()
	always_visible_gold_label.position = Vector2(20, 20)
	always_visible_gold_label.label_settings = font_settings
	add_child(always_visible_gold_label)
	
	_setup_info_panel()
	# Defer setup of build panel so PlacementManager has time to setup if needed
	call_deferred("_setup_build_panel")
	
	var main = get_parent()
	if main.has_signal("resources_updated"):
		main.resources_updated.connect(_on_resources_updated)

func _setup_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.visible = false
	info_panel.position = Vector2(20, 50)
	add_child(info_panel)
	
	var vbox = VBoxContainer.new()
	info_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Town Info"
	title.label_settings = font_settings
	vbox.add_child(title)
	
	gold_label = Label.new()
	gold_label.label_settings = font_settings
	vbox.add_child(gold_label)
	
	food_label = Label.new()
	food_label.label_settings = font_settings
	vbox.add_child(food_label)
	
	log_label = Label.new()
	log_label.label_settings = font_settings
	vbox.add_child(log_label)
	
	pop_label = Label.new()
	pop_label.label_settings = font_settings
	vbox.add_child(pop_label)

func _setup_build_panel() -> void:
	build_panel = PanelContainer.new()
	build_panel.visible = false
	add_child(build_panel)
	build_panel.position = Vector2(150, 100)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 400)
	build_panel.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	
	var title = Label.new()
	title.text = "Build Menu"
	title.label_settings = font_settings
	vbox.add_child(title)
	
	var pm = get_parent().get_node_or_null("PlacementManager")
	if not pm: return
	
	var categories = {}
	for b in pm.buildings:
		var type_name = BuildingData.BuildingType.keys()[b.building_type]
		if not categories.has(type_name):
			categories[type_name] = []
		categories[type_name].append(b)
		
	for cat in categories.keys():
		var cat_label = Label.new()
		cat_label.text = "-- " + cat.capitalize() + " --"
		cat_label.label_settings = font_settings
		vbox.add_child(cat_label)
		
		var grid = GridContainer.new()
		grid.columns = 2
		vbox.add_child(grid)
		
		for b in categories[cat]:
			var btn = Button.new()
			btn.text = b.display_name
			btn.add_theme_font_override("font", font)
			btn.pressed.connect(func():
				pm.start_placement(b)
				build_panel.visible = false
			)
			grid.add_child(btn)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("info_btn"):
		info_panel.visible = !info_panel.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_btn"):
		build_panel.visible = !build_panel.visible
		get_viewport().set_input_as_handled()

func _on_resources_updated(gold: int, food: int, log: int, population: int) -> void:
	if always_visible_gold_label: always_visible_gold_label.text = "Gold: " + str(gold)
	if gold_label: gold_label.text = "Gold: " + str(gold)
	if food_label: food_label.text = "Food: " + str(food)
	if log_label: log_label.text = "Lumber: " + str(log)
	if pop_label: pop_label.text = "Population: " + str(population)
