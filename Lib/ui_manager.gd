extends CanvasLayer

var font = preload("res://Assets/Silkscreen-Regular.ttf")
var font_settings = LabelSettings.new()

# UI labels & panels
var hud_status_panel: PanelContainer
var hud_status_label: Label

var info_panel: PanelContainer
var info_gold_label: Label
var info_income_label: Label
var info_pop_label: Label
var info_happiness_label: Label
var info_housing_label: Label

var info_storage_food_label: Label
var info_storage_log_label: Label
var info_storage_gold_label: Label

var tax_rate_label: Label
var tax_desc_label: Label
var tax_minus_btn: Button
var tax_plus_btn: Button

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
var modal_open_town_info_btn: Button

var _selected_building_ref: Node2D = null
var _selected_building_data: BuildingData = null

# Toast notification system
var toast_container: VBoxContainer

# Cached UI state
var _curr_gold: int = 0
var _curr_food: int = 0
var _curr_log: int = 0
var _curr_pop: int = 0
var _curr_income: int = 0
var _curr_happiness: float = 1.0
var _curr_tax: int = 100

func _ready() -> void:
	font_settings.font = font
	font_settings.font_size = 14
	
	_setup_hud_status_bar()
	_setup_toast_container()
	_setup_info_panel()
	_setup_building_modal()
	_setup_demolish_banner()
	_setup_hud_buttons()
	
	# Defer setup of build panel so PlacementManager has time to setup if needed
	call_deferred("_setup_build_panel")
	call_deferred("_connect_placement_manager")
	
	var main = get_parent()
	if main.has_signal("resources_updated"):
		main.resources_updated.connect(_on_resources_updated)

func _setup_toast_container() -> void:
	toast_container = VBoxContainer.new()
	toast_container.z_index = 200
	toast_container.anchor_left = 1.0
	toast_container.anchor_top = 0.0
	toast_container.anchor_right = 1.0
	toast_container.anchor_bottom = 0.0
	toast_container.offset_left = -360
	toast_container.offset_top = 20
	toast_container.offset_right = -20
	toast_container.add_theme_constant_override("separation", 8)
	toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_container)

func show_toast(title_text: String, message_text: String, duration: float = 4.0) -> void:
	if toast_container == null:
		return

	var toast = PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	style.border_width_left = 3
	style.border_color = Color(0.3, 0.85, 1.0, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	toast.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	toast.add_child(vbox)

	var t_lbl = Label.new()
	t_lbl.text = title_text
	var t_set = LabelSettings.new()
	t_set.font = font
	t_set.font_size = 12
	t_set.font_color = Color(0.3, 0.9, 1.0)
	t_lbl.label_settings = t_set
	vbox.add_child(t_lbl)

	var m_lbl = Label.new()
	m_lbl.text = message_text
	var m_set = LabelSettings.new()
	m_set.font = font
	m_set.font_size = 10
	m_set.font_color = Color(0.9, 0.95, 1.0)
	m_lbl.label_settings = m_set
	vbox.add_child(m_lbl)

	toast_container.add_child(toast)

	# Fade / slide in animation
	toast.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duration)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)

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

func _setup_hud_status_bar() -> void:
	hud_status_panel = PanelContainer.new()
	hud_status_panel.position = Vector2(20, 20)
	hud_status_panel.z_index = 90
	add_child(hud_status_panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.11, 0.16, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.2, 0.7, 0.9, 0.6)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 14
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 14
	panel_style.content_margin_bottom = 8
	hud_status_panel.add_theme_stylebox_override("panel", panel_style)
	
	hud_status_label = Label.new()
	hud_status_label.label_settings = font_settings
	hud_status_label.text = "Gold: 0 (+0)   Population: 0"
	hud_status_panel.add_child(hud_status_label)
	
	# Compatibility alias
	always_visible_gold_label = hud_status_label

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

	# Town Info trigger for Townhall
	modal_open_town_info_btn = Button.new()
	modal_open_town_info_btn.text = "🏛️ Manage Town Policy"
	modal_open_town_info_btn.visible = false
	modal_open_town_info_btn.add_theme_font_override("font", font)
	modal_open_town_info_btn.pressed.connect(func():
		toggle_info_panel(true)
	)
	main_vbox.add_child(modal_open_town_info_btn)

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

	var is_townhall: bool = false
	if _selected_building_data != null:
		modal_title_label.text = _selected_building_data.display_name
		var type_name = BuildingData.BuildingType.keys()[_selected_building_data.building_type].capitalize()
		modal_category_label.text = "[ %s ]" % type_name
		if _selected_building_data.id == "townhall":
			is_townhall = true
	else:
		modal_title_label.text = _selected_building_ref.name
		modal_category_label.text = ""
		if _selected_building_ref.name.begins_with("Townhall"):
			is_townhall = true

	modal_open_town_info_btn.visible = is_townhall

	if _selected_building_ref.has_method("get_info_text"):
		var info_str = _selected_building_ref.get_info_text()
		if "level" in _selected_building_ref and "has_restaurant_bonus" in _selected_building_ref:
			info_str += "\n\n── UPGRADE REQUIREMENTS ──"
			if "is_upgrading" in _selected_building_ref and _selected_building_ref.is_upgrading:
				info_str += "\n [ 🛠️ Upgrading in progress... ]"
			elif _selected_building_ref.level == 0: # PEASANT (Level 1)
				var has_rest = _selected_building_ref.has_restaurant_bonus
				var main_node = get_parent()
				var current_logs = main_node.log if (main_node and "log" in main_node) else 0
				var has_logs = current_logs >= 5

				var rest_chk = " [✓] Restaurant Influence" if has_rest else " [✗] Restaurant Influence"
				var log_chk = " [✓] Wood: %d/5 Logs" % current_logs if has_logs else " [✗] Wood: %d/5 Logs" % current_logs

				info_str += "\n%s\n%s" % [rest_chk, log_chk]
			else:
				info_str += "\n [ Max Tier Reached ✨ ]"
		modal_info_label.text = info_str
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
	info_panel.z_index = 110
	
	# Centered overlay panel layout
	info_panel.anchor_left = 0.5
	info_panel.anchor_top = 0.5
	info_panel.anchor_right = 0.5
	info_panel.anchor_bottom = 0.5
	info_panel.offset_left = -240
	info_panel.offset_top = -270
	info_panel.offset_right = 240
	info_panel.offset_bottom = 270
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	info_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.1, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.85, 1.0, 0.85)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 18
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 18
	panel_style.content_margin_bottom = 16
	info_panel.add_theme_stylebox_override("panel", panel_style)
	
	add_child(info_panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	info_panel.add_child(main_vbox)
	
	# Header Row
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_vbox)
	
	var title = Label.new()
	title.text = "🏛️ TOWN MANAGEMENT"
	var t_set = LabelSettings.new()
	t_set.font = font
	t_set.font_size = 15
	t_set.font_color = Color(0.3, 0.9, 1.0)
	title.label_settings = t_set
	title_vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = "City Overview, Storage & Policy"
	var s_set = LabelSettings.new()
	s_set.font = font
	s_set.font_size = 10
	s_set.font_color = Color(0.65, 0.75, 0.85)
	sub.label_settings = s_set
	title_vbox.add_child(sub)
	
	var close_btn = Button.new()
	close_btn.text = " X "
	close_btn.add_theme_font_override("font", font)
	close_btn.pressed.connect(func():
		info_panel.visible = false
	)
	header_hbox.add_child(close_btn)
	
	main_vbox.add_child(HSeparator.new())
	
	# Stats Section
	var stats_title = Label.new()
	stats_title.text = "── CITY STATISTICS ──"
	var st_set = LabelSettings.new()
	st_set.font = font
	st_set.font_size = 11
	st_set.font_color = Color(1.0, 0.8, 0.4)
	stats_title.label_settings = st_set
	main_vbox.add_child(stats_title)
	
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 5)
	main_vbox.add_child(stats_vbox)
	
	info_gold_label = Label.new()
	info_gold_label.label_settings = font_settings
	stats_vbox.add_child(info_gold_label)
	
	info_income_label = Label.new()
	info_income_label.label_settings = font_settings
	stats_vbox.add_child(info_income_label)
	
	info_pop_label = Label.new()
	info_pop_label.label_settings = font_settings
	stats_vbox.add_child(info_pop_label)
	
	info_happiness_label = Label.new()
	info_happiness_label.label_settings = font_settings
	stats_vbox.add_child(info_happiness_label)
	
	info_housing_label = Label.new()
	info_housing_label.label_settings = font_settings
	stats_vbox.add_child(info_housing_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# Storage / Item Info Section
	var storage_header = Label.new()
	storage_header.text = "── ITEM STORAGE ──"
	storage_header.label_settings = st_set
	main_vbox.add_child(storage_header)
	
	var storage_vbox = VBoxContainer.new()
	storage_vbox.add_theme_constant_override("separation", 5)
	main_vbox.add_child(storage_vbox)
	
	info_storage_food_label = Label.new()
	info_storage_food_label.label_settings = font_settings
	storage_vbox.add_child(info_storage_food_label)
	
	info_storage_log_label = Label.new()
	info_storage_log_label.label_settings = font_settings
	storage_vbox.add_child(info_storage_log_label)
	
	info_storage_gold_label = Label.new()
	info_storage_gold_label.label_settings = font_settings
	storage_vbox.add_child(info_storage_gold_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# Tax Section
	var tax_header = Label.new()
	tax_header.text = "── TAXATION POLICY ──"
	tax_header.label_settings = st_set
	main_vbox.add_child(tax_header)
	
	var tax_hbox = HBoxContainer.new()
	tax_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tax_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(tax_hbox)
	
	tax_minus_btn = Button.new()
	tax_minus_btn.text = "  -  "
	tax_minus_btn.add_theme_font_override("font", font)
	tax_minus_btn.pressed.connect(func():
		_adjust_tax(-10)
	)
	tax_hbox.add_child(tax_minus_btn)
	
	tax_rate_label = Label.new()
	tax_rate_label.text = "Tax Rate: 100%"
	tax_rate_label.label_settings = font_settings
	tax_hbox.add_child(tax_rate_label)
	
	tax_plus_btn = Button.new()
	tax_plus_btn.text = "  +  "
	tax_plus_btn.add_theme_font_override("font", font)
	tax_plus_btn.pressed.connect(func():
		_adjust_tax(+10)
	)
	tax_hbox.add_child(tax_plus_btn)
	
	tax_desc_label = Label.new()
	var desc_set = LabelSettings.new()
	desc_set.font = font
	desc_set.font_size = 10
	desc_set.font_color = Color(0.8, 0.85, 0.9)
	desc_set.line_spacing = 2
	tax_desc_label.label_settings = desc_set
	tax_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(tax_desc_label)

func _adjust_tax(delta_rate: int) -> void:
	var main = get_parent()
	if main and main.has_method("set_tax_rate"):
		main.set_tax_rate(main.tax_rate + delta_rate)

func toggle_info_panel(force_show: bool = false) -> void:
	if force_show:
		info_panel.visible = true
	else:
		info_panel.visible = not info_panel.visible
	if info_panel.visible:
		_refresh_info_panel_ui()

func _setup_hud_buttons() -> void:
	# Town Info button
	var info_btn = Button.new()
	info_btn.text = "🏛️ TOWN INFO"
	info_btn.add_theme_font_override("font", font)
	info_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	info_btn.anchor_left = 1.0
	info_btn.anchor_top = 1.0
	info_btn.anchor_right = 1.0
	info_btn.anchor_bottom = 1.0
	info_btn.offset_left = -320
	info_btn.offset_top = -50
	info_btn.offset_right = -170
	info_btn.offset_bottom = -15
	info_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
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
	style_norm.content_margin_left = 8
	style_norm.content_margin_right = 8
	
	var style_hover = style_norm.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.15, 0.22, 0.3, 0.95)
	style_hover.border_color = Color(0.4, 0.85, 1.0, 1.0)
	
	info_btn.add_theme_stylebox_override("normal", style_norm)
	info_btn.add_theme_stylebox_override("hover", style_hover)
	info_btn.add_theme_stylebox_override("pressed", style_hover)
	
	info_btn.pressed.connect(func():
		toggle_info_panel()
	)
	add_child(info_btn)

	# Build Menu button
	var hud_btn = Button.new()
	hud_btn.text = "🔨 BUILD MENU"
	hud_btn.add_theme_font_override("font", font)
	hud_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	hud_btn.anchor_left = 1.0
	hud_btn.anchor_top = 1.0
	hud_btn.anchor_right = 1.0
	hud_btn.anchor_bottom = 1.0
	hud_btn.offset_left = -155
	hud_btn.offset_top = -50
	hud_btn.offset_right = -15
	hud_btn.offset_bottom = -15
	hud_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	hud_btn.add_theme_stylebox_override("normal", style_norm)
	hud_btn.add_theme_stylebox_override("hover", style_hover)
	hud_btn.add_theme_stylebox_override("pressed", style_hover)
	
	hud_btn.pressed.connect(func():
		toggle_build_menu()
	)
	add_child(hud_btn)


func _setup_build_panel() -> void:
	if build_panel != null:
		build_panel.queue_free()

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
	
	var main = get_parent()
	var is_unlocked: bool = true
	if main != null and main.has_method("is_building_unlocked"):
		is_unlocked = main.is_building_unlocked(b)

	var card_style = StyleBoxFlat.new()
	if is_unlocked:
		card_style.bg_color = Color(0.12, 0.16, 0.22, 0.85)
		card_style.border_color = Color(0.25, 0.35, 0.45, 0.6)
	else:
		card_style.bg_color = Color(0.06, 0.08, 0.11, 0.7)
		card_style.border_color = Color(0.18, 0.22, 0.28, 0.4)
	
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.content_margin_left = 8
	card_style.content_margin_top = 6
	card_style.content_margin_right = 8
	card_style.content_margin_bottom = 6
	
	var card_hover = card_style.duplicate() as StyleBoxFlat
	if is_unlocked:
		card_hover.bg_color = Color(0.18, 0.24, 0.32, 0.95)
		card_hover.border_color = Color(0.3, 0.8, 1.0, 0.9)
	
	btn.add_theme_stylebox_override("normal", card_style)
	btn.add_theme_stylebox_override("hover", card_hover)
	btn.add_theme_stylebox_override("pressed", card_hover)
	if not is_unlocked:
		btn.disabled = true
	
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
		if not is_unlocked:
			tex_rect.modulate = Color(0.4, 0.4, 0.4, 0.6)
		hbox.add_child(tex_rect)
	else:
		var fallback_lbl = Label.new()
		fallback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback_lbl.text = "🏛️" if b.building_type == BuildingData.BuildingType.GOVERNMENT else ("🏠" if b.building_type == BuildingData.BuildingType.RESIDENT else "🏗️")
		if not is_unlocked:
			fallback_lbl.modulate = Color(0.4, 0.4, 0.4, 0.6)
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
	n_set.font_color = Color(0.95, 0.95, 0.95) if is_unlocked else Color(0.5, 0.55, 0.6)
	name_lbl.label_settings = n_set
	info_vbox.add_child(name_lbl)
	
	var cost_str = "💰 %d Gold" % b.cost
	if b.id == "house":
		cost_str += " | 🪵 10 Log"
	
	if not is_unlocked:
		if b.requires_townhall:
			cost_str = "🔒 Requires Townhall"
		elif b.required_population > 0:
			cost_str = "🔒 Unlocks at %d Pop" % b.required_population
		else:
			cost_str = "🔒 Locked"
			
	var cost_lbl = Label.new()
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_lbl.text = cost_str
	var c_set = LabelSettings.new()
	c_set.font = font
	c_set.font_size = 9
	c_set.font_color = Color(0.85, 0.75, 0.4) if is_unlocked else Color(0.7, 0.4, 0.4)
	cost_lbl.label_settings = c_set
	info_vbox.add_child(cost_lbl)
	
	if is_unlocked:
		btn.pressed.connect(func():
			pm.start_placement(b)
			build_panel.visible = false
		)
	
	return btn


func toggle_build_menu(force_state: int = -1) -> void:
	var pm = get_parent().get_node_or_null("PlacementManager")
	var is_open: bool = (build_panel != null and build_panel.visible) or (pm != null and (pm.is_build_mode() or pm.is_demolish_mode()))
	var should_open: bool
	if force_state != -1:
		should_open = (force_state == 1)
	else:
		should_open = not is_open

	if should_open:
		_setup_build_panel()
		build_panel.visible = true
	else:
		if build_panel != null:
			build_panel.visible = false
		if pm != null:
			if pm.has_method("exit_build_mode"):
				pm.exit_build_mode()
			if pm.has_method("exit_demolish_mode"):
				pm.exit_demolish_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("info_btn"):
		toggle_info_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_btn"):
		toggle_build_menu()
		get_viewport().set_input_as_handled()


func _on_resources_updated(gold: int, food: int, log: int, population: int, monthly_income: int = 0, avg_happiness: float = 1.0, tax_rate: int = 100) -> void:
	_curr_gold = gold
	_curr_food = food
	_curr_log = log
	_curr_pop = population
	_curr_income = monthly_income
	_curr_happiness = avg_happiness
	_curr_tax = tax_rate

	# Gameplay View HUD format: Gold: 50000 (+30) Population: 125
	var sign_str = ("+" if monthly_income >= 0 else "") + str(monthly_income)
	if hud_status_label:
		hud_status_label.text = "Gold: %d (%s)   Population: %d" % [gold, sign_str, population]

	_refresh_info_panel_ui()

func _refresh_info_panel_ui() -> void:
	if info_panel == null or not info_panel.visible:
		return

	var main = get_parent()
	var act_houses = main.active_houses_count if "active_houses_count" in main else 0
	var ab_houses = main.abandoned_houses_count if "abandoned_houses_count" in main else 0

	# Query pending uncollected items in production buildings
	var pending_food: int = 0
	var pending_log: int = 0
	var pm = main.get_node_or_null("PlacementManager")
	if pm and pm.has_node("BuildingRegistry"):
		var reg = pm.get_node("BuildingRegistry")
		var res_buildings = reg.get_buildings_with_type(BuildingData.BuildingType.RESOURCE)
		for b in res_buildings:
			if is_instance_valid(b):
				if "resource_type" in b and "produced_resource" in b:
					if b.resource_type == "food":
						pending_food += b.produced_resource
					elif b.resource_type == "log":
						pending_log += b.produced_resource

	var gross_tax = main.gross_tax_monthly if "gross_tax_monthly" in main else (_curr_income)
	var total_maint = main.total_maintenance_monthly if "total_maintenance_monthly" in main else 0

	var sign_str = ("+" if _curr_income >= 0 else "") + str(_curr_income)
	if info_gold_label:
		info_gold_label.text = "💰 Treasury: %d Gold" % _curr_gold
	if info_income_label:
		var maint_str = ""
		if total_maint > 0:
			maint_str = " (Tax: +%d, Maint: -%d)" % [gross_tax, total_maint]
		info_income_label.text = "📈 Net Monthly Income: %s Gold / mo%s" % [sign_str, maint_str]
	if info_pop_label:
		info_pop_label.text = "👥 Total Population: %d" % _curr_pop

	if info_happiness_label:
		var hap_pct = int(round(_curr_happiness * 100.0))
		info_happiness_label.text = "😊 Happiness: %d%%" % hap_pct

	if info_housing_label:
		info_housing_label.text = "🏠 Houses: %d Active / %d Abandoned" % [act_houses, ab_houses]

	# Item storage breakdown
	if info_storage_food_label:
		info_storage_food_label.text = "🌾 Food Crops: %d units  (Uncollected: %d)" % [_curr_food, pending_food]
	if info_storage_log_label:
		info_storage_log_label.text = "🪵 Lumber (Log): %d units  (Uncollected: %d)" % [_curr_log, pending_log]
	if info_storage_gold_label:
		if total_maint > 0:
			info_storage_gold_label.text = "💰 Gold Treasury: %d Gold  (Maint Cost: -%d/mo)" % [_curr_gold, total_maint]
		else:
			info_storage_gold_label.text = "💰 Gold Treasury: %d Gold" % _curr_gold

	if tax_rate_label:
		var tax_title = "Normal"
		if _curr_tax > 150: tax_title = "Very High"
		elif _curr_tax > 100: tax_title = "High"
		elif _curr_tax < 50: tax_title = "Very Low"
		elif _curr_tax < 100: tax_title = "Low"
		tax_rate_label.text = "Tax Rate: %d%% (%s)" % [_curr_tax, tax_title]

	if tax_desc_label:
		if _curr_tax == 100:
			tax_desc_label.text = "Neutral Tax: Standard gold revenue per house. Normal happiness."
		elif _curr_tax > 100:
			var pen = int(round((_curr_tax - 100) * 0.5))
			tax_desc_label.text = "Higher Tax (+%d%% revenue): Apply -%d%% happiness penalty! Long-term low happiness (<40%%) causes abandonment." % [_curr_tax - 100, pen]
		else:
			var bon = int(round((100 - _curr_tax) * 0.5))
			tax_desc_label.text = "Lower Tax (-%d%% revenue): Boosts citizen happiness by +%d%%!" % [100 - _curr_tax, bon]
