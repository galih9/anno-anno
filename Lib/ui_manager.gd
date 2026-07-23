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

# Building info modal UI
var building_modal: PanelContainer
var modal_title_label: Label
var modal_category_label: Label
var modal_info_label: Label
var modal_toggle_active_btn: Button
var modal_demolish_btn: Button

var _selected_building_ref: Node2D = null
var _selected_building_data: BuildingData = null

func _ready() -> void:
	font_settings.font = font
	font_settings.font_size = 16
	
	# Standalone gold label
	always_visible_gold_label = Label.new()
	always_visible_gold_label.position = Vector2(20, 20)
	always_visible_gold_label.label_settings = font_settings
	add_child(always_visible_gold_label)
	
	_setup_info_panel()
	_setup_building_modal()
	# Defer setup of build panel so PlacementManager has time to setup if needed
	call_deferred("_setup_build_panel")
	call_deferred("_connect_placement_manager")
	
	var main = get_parent()
	if main.has_signal("resources_updated"):
		main.resources_updated.connect(_on_resources_updated)

func _process(_delta: float) -> void:
	if _selected_building_ref != null:
		if is_instance_valid(_selected_building_ref) and building_modal != null and building_modal.visible:
			_update_modal_content()
			_update_modal_position()
		else:
			_on_building_deselected()

func _connect_placement_manager() -> void:
	var pm = get_parent().get_node_or_null("PlacementManager")
	if pm:
		if pm.has_signal("building_selected"):
			pm.building_selected.connect(_on_building_selected)
		if pm.has_signal("building_deselected"):
			pm.building_deselected.connect(_on_building_deselected)

func _setup_building_modal() -> void:
	building_modal = PanelContainer.new()
	building_modal.visible = false
	building_modal.z_index = 100
	add_child(building_modal)

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.2, 0.8, 1.0, 0.8)
	style_box.corner_radius_top_left = 6
	style_box.corner_radius_top_right = 6
	style_box.corner_radius_bottom_left = 6
	style_box.corner_radius_bottom_right = 6
	style_box.content_margin_left = 12
	style_box.content_margin_top = 10
	style_box.content_margin_right = 12
	style_box.content_margin_bottom = 10
	building_modal.add_theme_stylebox_override("panel", style_box)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	building_modal.add_child(main_vbox)

	# Header row (Title + Close Button)
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var header_left = VBoxContainer.new()
	header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_left)

	modal_title_label = Label.new()
	var title_settings = LabelSettings.new()
	title_settings.font = font
	title_settings.font_size = 14
	title_settings.font_color = Color(0.3, 0.9, 1.0)
	modal_title_label.label_settings = title_settings
	header_left.add_child(modal_title_label)

	modal_category_label = Label.new()
	var cat_settings = LabelSettings.new()
	cat_settings.font = font
	cat_settings.font_size = 10
	cat_settings.font_color = Color(0.7, 0.7, 0.7)
	modal_category_label.label_settings = cat_settings
	header_left.add_child(modal_category_label)

	var close_btn = Button.new()
	close_btn.text = " X "
	close_btn.add_theme_font_override("font", font)
	close_btn.pressed.connect(func():
		var pm = get_parent().get_node_or_null("PlacementManager")
		if pm and pm.has_method("deselect_building"):
			pm.deselect_building()
		else:
			_on_building_deselected()
	)
	header_hbox.add_child(close_btn)

	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	# Info body
	modal_info_label = Label.new()
	var info_settings = LabelSettings.new()
	info_settings.font = font
	info_settings.font_size = 12
	info_settings.line_spacing = 3
	modal_info_label.label_settings = info_settings
	main_vbox.add_child(modal_info_label)

	# Action buttons row
	var actions_hbox = HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(actions_hbox)

	modal_toggle_active_btn = Button.new()
	modal_toggle_active_btn.text = "Pause Production"
	modal_toggle_active_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_toggle_active_btn.add_theme_font_override("font", font)
	modal_toggle_active_btn.pressed.connect(func():
		if _selected_building_ref != null and is_instance_valid(_selected_building_ref):
			if _selected_building_ref.has_method("toggle_user_active"):
				_selected_building_ref.toggle_user_active()
				_update_modal_content()
	)
	actions_hbox.add_child(modal_toggle_active_btn)

	modal_demolish_btn = Button.new()
	modal_demolish_btn.text = "Demolish"
	modal_demolish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_demolish_btn.add_theme_font_override("font", font)
	modal_demolish_btn.pressed.connect(func():
		if _selected_building_ref != null and is_instance_valid(_selected_building_ref):
			var pm = get_parent().get_node_or_null("PlacementManager")
			if pm and pm.has_method("remove_building"):
				pm.remove_building(_selected_building_ref)
				pm.deselect_building()
	)
	actions_hbox.add_child(modal_demolish_btn)

func _on_building_selected(building: Node2D, data: BuildingData) -> void:
	_selected_building_ref = building
	_selected_building_data = data
	building_modal.visible = true
	_update_modal_content()
	_update_modal_position()

func _on_building_deselected() -> void:
	_selected_building_ref = null
	_selected_building_data = null
	if building_modal != null:
		building_modal.visible = false

func _update_modal_content() -> void:
	if _selected_building_ref == null or not is_instance_valid(_selected_building_ref):
		return

	if _selected_building_data != null:
		modal_title_label.text = _selected_building_data.display_name
		var type_name = BuildingData.BuildingType.keys()[_selected_building_data.building_type].capitalize()
		modal_category_label.text = "[ %s ]" % type_name
	else:
		modal_title_label.text = _selected_building_ref.name
		modal_category_label.text = ""

	if _selected_building_ref.has_method("get_info_text"):
		modal_info_label.text = _selected_building_ref.get_info_text()
	else:
		modal_info_label.text = "No detailed status available."

	if _selected_building_ref.has_method("toggle_user_active"):
		modal_toggle_active_btn.visible = true
		var is_active: bool = true
		if "is_user_active" in _selected_building_ref:
			is_active = _selected_building_ref.is_user_active
		modal_toggle_active_btn.text = "Pause Production" if is_active else "Resume Production"
	else:
		modal_toggle_active_btn.visible = false

func _update_modal_position() -> void:
	if _selected_building_ref == null or not is_instance_valid(_selected_building_ref):
		return

	var canvas_transform := get_viewport().get_canvas_transform()
	var screen_pos := canvas_transform * _selected_building_ref.global_position
	# Offset to float above building center
	building_modal.position = screen_pos + Vector2(-building_modal.size.x / 2.0, -building_modal.size.y - 25.0)

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
