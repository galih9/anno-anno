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
var demolish_banner: PanelContainer

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
	_setup_demolish_banner()
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
		if pm.has_signal("demolish_mode_changed"):
			pm.demolish_mode_changed.connect(_on_demolish_mode_changed)

func _setup_demolish_banner() -> void:
	demolish_banner = PanelContainer.new()
	demolish_banner.visible = false
	demolish_banner.z_index = 120
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.05, 0.05, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.25, 0.25, 0.95)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_top = 8
	style.content_margin_right = 16
	style.content_margin_bottom = 8
	demolish_banner.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = "🔨 DEMOLISH MODE  |  Click: demolish building  |  Hold & Drag: demolish pathways  |  ESC / RMB: exit"
	var banner_font = LabelSettings.new()
	banner_font.font = font
	banner_font.font_size = 12
	banner_font.font_color = Color(1.0, 0.4, 0.4)
	lbl.label_settings = banner_font
	demolish_banner.add_child(lbl)
	
	add_child(demolish_banner)
	
	# Center top position
	demolish_banner.anchor_left = 0.5
	demolish_banner.anchor_right = 0.5
	demolish_banner.anchor_top = 0.0
	demolish_banner.anchor_bottom = 0.0
	demolish_banner.offset_top = 20
	demolish_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH

func _on_demolish_mode_changed(enabled: bool) -> void:
	if demolish_banner != null:
		demolish_banner.visible = enabled

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
	_setup_hud_build_button()


func _setup_hud_build_button() -> void:
	var hud_btn = Button.new()
	hud_btn.text = "🔨 BUILD MENU"
	hud_btn.add_theme_font_override("font", font)
	hud_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	hud_btn.anchor_left = 1.0
	hud_btn.anchor_top = 1.0
	hud_btn.anchor_right = 1.0
	hud_btn.anchor_bottom = 1.0
	hud_btn.offset_left = -160
	hud_btn.offset_top = -50
	hud_btn.offset_right = -20
	hud_btn.offset_bottom = -15
	hud_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	var style_norm = StyleBoxFlat.new()
	style_norm.bg_color = Color(0.1, 0.14, 0.2, 0.9)
	style_norm.border_width_left = 2
	style_norm.border_width_top = 2
	style_norm.border_width_right = 2
	style_norm.border_width_bottom = 2
	style_norm.border_color = Color(0.2, 0.7, 0.9, 0.8)
	style_norm.corner_radius_top_left = 8
	style_norm.corner_radius_top_right = 8
	style_norm.corner_radius_bottom_left = 8
	style_norm.corner_radius_bottom_right = 8
	style_norm.content_margin_left = 10
	style_norm.content_margin_right = 10
	
	var style_hover = style_norm.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.15, 0.22, 0.3, 0.95)
	style_hover.border_color = Color(0.4, 0.85, 1.0, 1.0)
	
	hud_btn.add_theme_stylebox_override("normal", style_norm)
	hud_btn.add_theme_stylebox_override("hover", style_hover)
	hud_btn.add_theme_stylebox_override("pressed", style_hover)
	
	hud_btn.pressed.connect(func():
		toggle_build_menu()
	)
	add_child(hud_btn)


func _setup_build_panel() -> void:
	build_panel = PanelContainer.new()
	build_panel.visible = false
	build_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(build_panel)
	
	# Dock right side of viewport
	build_panel.anchor_left = 1.0
	build_panel.anchor_top = 0.0
	build_panel.anchor_right = 1.0
	build_panel.anchor_bottom = 1.0
	build_panel.offset_left = -340
	build_panel.offset_top = 0
	build_panel.offset_right = 0
	build_panel.offset_bottom = 0
	build_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	build_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Modern Dark Glassmorphic Style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.11, 0.16, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_color = Color(0.2, 0.65, 0.9, 0.6)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.content_margin_left = 14
	panel_style.content_margin_top = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_bottom = 14
	build_panel.add_theme_stylebox_override("panel", panel_style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	main_vbox.add_theme_constant_override("separation", 10)
	build_panel.add_child(main_vbox)
	
	# Header Row (Title + Subtitle + Close Button)
	var header_hbox = HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	main_vbox.add_child(header_hbox)
	
	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	header_hbox.add_child(title_vbox)
	
	var title = Label.new()
	title.text = "BUILD MENU"
	var t_set = LabelSettings.new()
	t_set.font = font
	t_set.font_size = 16
	t_set.font_color = Color(0.3, 0.9, 1.0)
	title.label_settings = t_set
	title_vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Right-Click to Toggle"
	var sub_set = LabelSettings.new()
	sub_set.font = font
	sub_set.font_size = 9
	sub_set.font_color = Color(0.6, 0.7, 0.8)
	subtitle.label_settings = sub_set
	title_vbox.add_child(subtitle)
	
	var close_btn = Button.new()
	close_btn.text = " X "
	close_btn.add_theme_font_override("font", font)
	close_btn.pressed.connect(func():
		toggle_build_menu(0)
	)
	header_hbox.add_child(close_btn)
	
	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)
	
	var pm = get_parent().get_node_or_null("PlacementManager")
	if not pm: return
	
	# Prominent Demolish Mode button
	var demolish_btn = Button.new()
	demolish_btn.text = "🔨 DEMOLISH MODE"
	demolish_btn.add_theme_font_override("font", font)
	demolish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var d_style = StyleBoxFlat.new()
	d_style.bg_color = Color(0.55, 0.12, 0.12, 0.9)
	d_style.corner_radius_top_left = 6
	d_style.corner_radius_top_right = 6
	d_style.corner_radius_bottom_left = 6
	d_style.corner_radius_bottom_right = 6
	d_style.content_margin_top = 8
	d_style.content_margin_bottom = 8
	demolish_btn.add_theme_stylebox_override("normal", d_style)
	
	var d_hover = d_style.duplicate() as StyleBoxFlat
	d_hover.bg_color = Color(0.75, 0.18, 0.18, 0.95)
	demolish_btn.add_theme_stylebox_override("hover", d_hover)
	
	demolish_btn.pressed.connect(func():
		if pm and pm.has_method("start_demolish_mode"):
			pm.start_demolish_mode()
		build_panel.visible = false
	)
	main_vbox.add_child(demolish_btn)
	
	var sep2 = HSeparator.new()
	main_vbox.add_child(sep2)
	
	# ScrollContainer for building items
	var scroll = ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(300, 0)
	main_vbox.add_child(scroll)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(content_vbox)
	
	var categories = {}
	for b in pm.buildings:
		if b == null:
			continue
		var type_name = BuildingData.BuildingType.keys()[b.building_type]
		if not categories.has(type_name):
			categories[type_name] = []
		categories[type_name].append(b)
		
	for cat in categories.keys():
		var cat_label = Label.new()
		cat_label.text = "── " + cat.capitalize() + " ──"
		var c_set = LabelSettings.new()
		c_set.font = font
		c_set.font_size = 12
		c_set.font_color = Color(1.0, 0.8, 0.4)
		cat_label.label_settings = c_set
		content_vbox.add_child(cat_label)
		
		var cat_vbox = VBoxContainer.new()
		cat_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
		cat_vbox.add_theme_constant_override("separation", 6)
		content_vbox.add_child(cat_vbox)
		
		for b in categories[cat]:
			var card_btn = _create_building_card(b, pm)
			cat_vbox.add_child(card_btn)


func _create_building_card(b: BuildingData, pm: Node) -> Button:
	var btn = Button.new()
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 48)
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.16, 0.22, 0.85)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.25, 0.35, 0.45, 0.6)
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.content_margin_left = 8
	card_style.content_margin_top = 6
	card_style.content_margin_right = 8
	card_style.content_margin_bottom = 6
	
	var card_hover = card_style.duplicate() as StyleBoxFlat
	card_hover.bg_color = Color(0.18, 0.24, 0.32, 0.95)
	card_hover.border_color = Color(0.3, 0.8, 1.0, 0.9)
	
	btn.add_theme_stylebox_override("normal", card_style)
	btn.add_theme_stylebox_override("hover", card_hover)
	btn.add_theme_stylebox_override("pressed", card_hover)
	
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	btn.add_child(hbox)
	
	# Icon display
	if b.preview_texture != null:
		var tex_rect = TextureRect.new()
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.texture = b.preview_texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(36, 36)
		hbox.add_child(tex_rect)
	else:
		var fallback_lbl = Label.new()
		fallback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback_lbl.text = "🏛️" if b.building_type == BuildingData.BuildingType.GOVERNMENT else ("🏠" if b.building_type == BuildingData.BuildingType.RESIDENT else "🏗️")
		hbox.add_child(fallback_lbl)
		
	var info_vbox = VBoxContainer.new()
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_lbl = Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = b.display_name
	var n_set = LabelSettings.new()
	n_set.font = font
	n_set.font_size = 12
	n_set.font_color = Color(0.95, 0.95, 0.95)
	name_lbl.label_settings = n_set
	info_vbox.add_child(name_lbl)
	
	var cost_str = "💰 %d Gold" % b.cost
	if b.id == "house":
		cost_str += " | 🪵 10 Log"
	var cost_lbl = Label.new()
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_lbl.text = cost_str
	var c_set = LabelSettings.new()
	c_set.font = font
	c_set.font_size = 9
	c_set.font_color = Color(0.85, 0.75, 0.4)
	cost_lbl.label_settings = c_set
	info_vbox.add_child(cost_lbl)
	
	btn.pressed.connect(func():
		pm.start_placement(b)
		build_panel.visible = false
	)
	
	return btn


func toggle_build_menu(force_state: int = -1) -> void:
	var pm = get_parent().get_node_or_null("PlacementManager")
	var is_open: bool = build_panel.visible or (pm != null and (pm.is_build_mode() or pm.is_demolish_mode()))
	var should_open: bool
	if force_state != -1:
		should_open = (force_state == 1)
	else:
		should_open = not is_open

	if should_open:
		build_panel.visible = true
	else:
		build_panel.visible = false
		if pm != null:
			if pm.has_method("exit_build_mode"):
				pm.exit_build_mode()
			if pm.has_method("exit_demolish_mode"):
				pm.exit_demolish_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("info_btn"):
		info_panel.visible = !info_panel.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_btn"):
		toggle_build_menu()
		get_viewport().set_input_as_handled()


func _on_resources_updated(gold: int, food: int, log: int, population: int) -> void:
	if always_visible_gold_label: always_visible_gold_label.text = "Gold: " + str(gold)
	if gold_label: gold_label.text = "Gold: " + str(gold)
	if food_label: food_label.text = "Food: " + str(food)
	if log_label: log_label.text = "Lumber: " + str(log)
	if pop_label: pop_label.text = "Population: " + str(population)
