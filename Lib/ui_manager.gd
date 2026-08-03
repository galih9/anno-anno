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

var tax_rate_label: Label
var tax_desc_label: Label
var tax_minus_btn: Button
var tax_plus_btn: Button

# Pause Menu UI
var pause_panel: PanelContainer
var edge_pan_checkbox: CheckBox
var rmb_pan_checkbox: CheckBox

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	font_settings.font = font
	font_settings.font_size = 14
	
	_setup_hud_status_bar()
	_setup_toast_container()
	_setup_info_panel()
	_setup_pause_menu()
	_setup_building_modal()
	_setup_demolish_banner()
	_setup_hud_buttons()
	
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
	hud_status_label.text = "Emas: 0 (+0)   Penduduk: 0"
	hud_status_panel.add_child(hud_status_label)
	
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
	lbl.text = "MODE BONGKAR  |  Klik: bongkar bangunan  |  Tahan & Geser: bongkar jalan  |  ESC / Klik Kanan: keluar"
	var banner_font = LabelSettings.new()
	banner_font.font = font
	banner_font.font_size = 12
	banner_font.font_color = Color(1.0, 0.4, 0.4)
	lbl.label_settings = banner_font
	demolish_banner.add_child(lbl)
	
	add_child(demolish_banner)
	
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

	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	modal_info_label = Label.new()
	var info_settings = LabelSettings.new()
	info_settings.font = font
	info_settings.font_size = 12
	info_settings.line_spacing = 3
	modal_info_label.label_settings = info_settings
	main_vbox.add_child(modal_info_label)

	modal_open_town_info_btn = Button.new()
	modal_open_town_info_btn.text = "Kelola Kebijakan Praja"
	modal_open_town_info_btn.visible = false
	modal_open_town_info_btn.add_theme_font_override("font", font)
	modal_open_town_info_btn.pressed.connect(func():
		toggle_info_panel(true)
	)
	main_vbox.add_child(modal_open_town_info_btn)

	var actions_hbox = HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(actions_hbox)

	modal_toggle_active_btn = Button.new()
	modal_toggle_active_btn.text = "Hentikan Produksi"
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
	modal_demolish_btn.text = "Bongkar Bangunan"
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
		var type_name = ""
		match _selected_building_data.building_type:
			BuildingData.BuildingType.CONNECTOR: type_name = "Penghubung"
			BuildingData.BuildingType.RESIDENT: type_name = "Pemukiman"
			BuildingData.BuildingType.RESOURCE: type_name = "Sumber Daya"
			BuildingData.BuildingType.PUBLIC_SERVICE: type_name = "Fasilitas Umum"
			BuildingData.BuildingType.COSMETIC: type_name = "Dekorasi"
			BuildingData.BuildingType.GOVERNMENT: type_name = "Pemerintahan"
			_: type_name = "Bangunan"
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
		if _selected_building_ref.has_method("get_upgrade_requirements"):
			var req = _selected_building_ref.get_upgrade_requirements()
			info_str += "\n\n── SYARAT PENINGKATAN TIAR ──"
			if "is_upgrading" in _selected_building_ref and _selected_building_ref.is_upgrading:
				info_str += "\n [ Peningkatan sedang berlangsung... ]"
			elif not req.max_tier_reached:
				var rest_chk = " [V] Pengaruh Gelanggang" if req.has_service_bonus else " [X] Pengaruh Gelanggang"
				var log_chk = " [V] Kayu: %d/%d Bambu" % [_curr_log, req.log_cost] if req.has_logs else " [X] Kayu: %d/%d Bambu" % [_curr_log, req.log_cost]
				info_str += "\n Target: %s\n%s\n%s" % [req.next_tier_name, rest_chk, log_chk]
			else:
				info_str += "\n [ Tingkat Tertinggi Tercapai ]"
		modal_info_label.text = info_str
	else:
		modal_info_label.text = "Status tidak tersedia."

	if _selected_building_ref.has_method("toggle_user_active"):
		modal_toggle_active_btn.visible = true
		var is_active: bool = true
		if "is_user_active" in _selected_building_ref:
			is_active = _selected_building_ref.is_user_active
		modal_toggle_active_btn.text = "Hentikan Produksi" if is_active else "Lanjutkan Produksi"
	else:
		modal_toggle_active_btn.visible = false

func _update_modal_position() -> void:
	if _selected_building_ref == null or not is_instance_valid(_selected_building_ref):
		return

	var canvas_transform := get_viewport().get_canvas_transform()
	var screen_pos := canvas_transform * _selected_building_ref.global_position
	building_modal.position = screen_pos + Vector2(-building_modal.size.x / 2.0, -building_modal.size.y - 25.0)

func _setup_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.visible = false
	info_panel.z_index = 110
	info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	info_panel.anchor_left = 1.0
	info_panel.anchor_top = 0.0
	info_panel.anchor_right = 1.0
	info_panel.anchor_bottom = 1.0
	info_panel.offset_left = -340
	info_panel.offset_top = 0
	info_panel.offset_right = 0
	info_panel.offset_bottom = 0
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
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
	info_panel.add_theme_stylebox_override("panel", panel_style)
	
	add_child(info_panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	main_vbox.add_theme_constant_override("separation", 10)
	info_panel.add_child(main_vbox)
	
	var header_hbox = HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	main_vbox.add_child(header_hbox)
	
	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	header_hbox.add_child(title_vbox)
	
	var title = Label.new()
	title.text = "PENGELOLAAN PRAJA"
	var t_set = LabelSettings.new()
	t_set.font = font
	t_set.font_size = 16
	t_set.font_color = Color(0.3, 0.9, 1.0)
	title.label_settings = t_set
	title_vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = "Ikhtisar Wilayah, Lumbung & Kebijakan"
	var s_set = LabelSettings.new()
	s_set.font = font
	s_set.font_size = 9
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
	
	var stats_title = Label.new()
	stats_title.text = "── STATISTIK WILAYAH ──"
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
	
	var storage_header = Label.new()
	storage_header.text = "── LUMBUNG & HASIL BUMI ──"
	storage_header.label_settings = st_set
	main_vbox.add_child(storage_header)
	
	var storage_grid = GridContainer.new()
	storage_grid.columns = 4
	storage_grid.add_theme_constant_override("h_separation", 6)
	storage_grid.add_theme_constant_override("v_separation", 6)
	main_vbox.add_child(storage_grid)
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.14, 0.2, 0.85)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.25, 0.6, 0.8, 0.5)
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.content_margin_left = 4
	card_style.content_margin_top = 6
	card_style.content_margin_right = 4
	card_style.content_margin_bottom = 6

	var make_card = func(tex_path: String, title_str: String) -> Dictionary:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(70, 62)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", card_style)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		card.add_child(vbox)
		
		var tex = TextureRect.new()
		tex.texture = load(tex_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(24, 24)
		vbox.add_child(tex)
		
		var amt_lbl = Label.new()
		amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var amt_set = LabelSettings.new()
		amt_set.font = font
		amt_set.font_size = 11
		amt_set.font_color = Color(0.95, 0.95, 0.95)
		amt_lbl.label_settings = amt_set
		vbox.add_child(amt_lbl)
		
		var t_lbl = Label.new()
		t_lbl.text = title_str
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var title_lbl_set = LabelSettings.new()
		title_lbl_set.font = font
		title_lbl_set.font_size = 8
		title_lbl_set.font_color = Color(0.65, 0.75, 0.85)
		t_lbl.label_settings = title_lbl_set
		vbox.add_child(t_lbl)
		
		return {"card": card, "amount_label": amt_lbl}

	# Slot 1: Talas
	var talas_data = make_card.call("res://Assets/render/symbols/talas.png", "Talas")
	info_storage_food_label = talas_data.amount_label
	storage_grid.add_child(talas_data.card)

	# Slot 2: Bambu
	var bambu_data = make_card.call("res://Assets/render/symbols/bambu.png", "Bambu")
	info_storage_log_label = bambu_data.amount_label
	storage_grid.add_child(bambu_data.card)

	# Slot 3: Batu
	var batu_data = make_card.call("res://Assets/render/symbols/batu.png", "Batu")
	batu_data.amount_label.text = "0"
	storage_grid.add_child(batu_data.card)

	# Slot 4: Jati
	var jati_data = make_card.call("res://Assets/render/symbols/jati.png", "Jati")
	jati_data.amount_label.text = "0"
	storage_grid.add_child(jati_data.card)
	
	main_vbox.add_child(HSeparator.new())
	
	var tax_header = Label.new()
	tax_header.text = "── KEBIJAKAN UPETI (PAJAK) ──"
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
	tax_rate_label.text = "Tingkat Upeti: 100%"
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

func _setup_pause_menu() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.z_index = 300
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	pause_panel.anchor_left = 0.5
	pause_panel.anchor_top = 0.5
	pause_panel.anchor_right = 0.5
	pause_panel.anchor_bottom = 0.5
	pause_panel.offset_left = -190
	pause_panel.offset_top = -140
	pause_panel.offset_right = 190
	pause_panel.offset_bottom = 140
	pause_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.8, 1.0, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 16
	style.content_margin_top = 16
	style.content_margin_right = 16
	style.content_margin_bottom = 16
	pause_panel.add_theme_stylebox_override("panel", style)
	add_child(pause_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	pause_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "PERMAINAN DIHENTIKAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t_set = LabelSettings.new()
	t_set.font = font
	t_set.font_size = 15
	t_set.font_color = Color(0.3, 0.9, 1.0)
	title.label_settings = t_set
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	var sub = Label.new()
	sub.text = "Pengaturan Kontrol Kamera:"
	var s_set = LabelSettings.new()
	s_set.font = font
	s_set.font_size = 11
	s_set.font_color = Color(0.85, 0.85, 0.85)
	sub.label_settings = s_set
	vbox.add_child(sub)
	
	edge_pan_checkbox = CheckBox.new()
	edge_pan_checkbox.text = " Move by Edge Cursor"
	edge_pan_checkbox.add_theme_font_override("font", font)
	edge_pan_checkbox.button_pressed = true
	edge_pan_checkbox.toggled.connect(func(toggled_on: bool):
		var cam = get_viewport().get_camera_2d()
		if cam and "enable_edge_pan" in cam:
			cam.enable_edge_pan = toggled_on
	)
	vbox.add_child(edge_pan_checkbox)
	
	rmb_pan_checkbox = CheckBox.new()
	rmb_pan_checkbox.text = " Move by Hold Right Click"
	rmb_pan_checkbox.add_theme_font_override("font", font)
	rmb_pan_checkbox.button_pressed = true
	rmb_pan_checkbox.toggled.connect(func(toggled_on: bool):
		var cam = get_viewport().get_camera_2d()
		if cam and "enable_right_click_pan" in cam:
			cam.enable_right_click_pan = toggled_on
	)
	vbox.add_child(rmb_pan_checkbox)
	
	vbox.add_child(HSeparator.new())
	
	var resume_btn = Button.new()
	resume_btn.text = "LANJUTKAN"
	resume_btn.add_theme_font_override("font", font)
	resume_btn.custom_minimum_size = Vector2(0, 36)
	resume_btn.pressed.connect(func():
		toggle_pause(false)
	)
	vbox.add_child(resume_btn)

func toggle_pause(force_state: int = -1) -> void:
	var new_state: bool
	if force_state == 1:
		new_state = true
	elif force_state == 0:
		new_state = false
	else:
		new_state = !get_tree().paused
		
	get_tree().paused = new_state
	if pause_panel != null:
		pause_panel.visible = new_state
	
	if new_state:
		var cam = get_viewport().get_camera_2d()
		if cam:
			if "enable_edge_pan" in cam and edge_pan_checkbox != null:
				edge_pan_checkbox.button_pressed = cam.enable_edge_pan
			if "enable_right_click_pan" in cam and rmb_pan_checkbox != null:
				rmb_pan_checkbox.button_pressed = cam.enable_right_click_pan

func _adjust_tax(delta_rate: int) -> void:
	var main = get_parent()
	if main and main.has_method("set_tax_rate"):
		main.set_tax_rate(main.tax_rate + delta_rate)

func toggle_info_panel(force_show: bool = false) -> void:
	var should_show: bool
	if force_show:
		should_show = true
	else:
		should_show = not info_panel.visible

	if should_show:
		if build_panel != null:
			build_panel.visible = false
		info_panel.visible = true
		_refresh_info_panel_ui()
	else:
		info_panel.visible = false

func _setup_hud_buttons() -> void:
	var info_btn = Button.new()
	info_btn.text = "PRAJA"
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

	var hud_btn = Button.new()
	hud_btn.text = "PEMBANGUNAN"
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
	
	var header_hbox = HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	main_vbox.add_child(header_hbox)
	
	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	header_hbox.add_child(title_vbox)
	
	var title = Label.new()
	title.text = "MENU PEMBANGUNAN"
	var t_set = LabelSettings.new()
	t_set.font = font
	t_set.font_size = 16
	t_set.font_color = Color(0.3, 0.9, 1.0)
	title.label_settings = t_set
	title_vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Klik Kanan untuk Membuka/Menutup"
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
	
	var demolish_btn = Button.new()
	demolish_btn.text = "MODE BONGKAR"
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
		var type_name = ""
		match b.building_type:
			BuildingData.BuildingType.CONNECTOR: type_name = "PENGHUBUNG"
			BuildingData.BuildingType.RESIDENT: type_name = "PEMUKIMAN"
			BuildingData.BuildingType.RESOURCE: type_name = "SUMBER DAYA"
			BuildingData.BuildingType.PUBLIC_SERVICE: type_name = "FASILITAS UMUM"
			BuildingData.BuildingType.COSMETIC: type_name = "DEKORASI"
			BuildingData.BuildingType.GOVERNMENT: type_name = "PEMERINTAHAN"
			_: type_name = "BANGUNAN"
		if not categories.has(type_name):
			categories[type_name] = []
		categories[type_name].append(b)
		
	for cat in categories.keys():
		var cat_label = Label.new()
		cat_label.text = "── " + cat + " ──"
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
		fallback_lbl.text = ""
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
	
	var cost_str = "%d Emas" % b.cost
	if b.id == "house":
		cost_str += " | 10 Bambu"
	
	if not is_unlocked:
		if b.requires_townhall:
			cost_str = "Membutuhkan Balai Kota"
		elif b.required_population > 0:
			cost_str = "Terbuka pada %d Penduduk" % b.required_population
		else:
			cost_str = "Terkunci"
			
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
		if info_panel != null:
			info_panel.visible = false
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
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("info_btn"):
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

	var sign_str = ("+" if monthly_income >= 0 else "") + str(monthly_income)
	if hud_status_label:
		hud_status_label.text = "Emas: %d (%s)   Penduduk: %d" % [gold, sign_str, population]

	_refresh_info_panel_ui()

func _refresh_info_panel_ui() -> void:
	if info_panel == null or not info_panel.visible:
		return

	var main = get_parent()
	var act_houses = main.active_houses_count if "active_houses_count" in main else 0
	var ab_houses = main.abandoned_houses_count if "abandoned_houses_count" in main else 0

	var gross_tax = main.gross_tax_monthly if "gross_tax_monthly" in main else (_curr_income)
	var total_maint = main.total_maintenance_monthly if "total_maintenance_monthly" in main else 0

	var sign_str = ("+" if _curr_income >= 0 else "") + str(_curr_income)
	if info_gold_label:
		info_gold_label.text = "Perbendaharaan: %d Emas" % _curr_gold
	if info_income_label:
		var maint_str = ""
		if total_maint > 0:
			maint_str = " (Upeti: +%d, Pemeliharaan: -%d)" % [gross_tax, total_maint]
		info_income_label.text = "Pendapatan Bersih: %s Emas / bln%s" % [sign_str, maint_str]
	if info_pop_label:
		info_pop_label.text = "Total Warga: %d Jiwa" % _curr_pop

	if info_happiness_label:
		var hap_pct = int(round(_curr_happiness * 100.0))
		info_happiness_label.text = "Kebahagiaan: %d%%" % hap_pct

	if info_housing_label:
		info_housing_label.text = "Wisma: %d Aktif / %d Ditinggalkan" % [act_houses, ab_houses]

	if info_storage_food_label:
		info_storage_food_label.text = "%d unit" % _curr_food
	if info_storage_log_label:
		info_storage_log_label.text = "%d unit" % _curr_log

	if tax_rate_label:
		var tax_title = "Wajar"
		if _curr_tax > 150: tax_title = "Sangat Tinggi"
		elif _curr_tax > 100: tax_title = "Tinggi"
		elif _curr_tax < 50: tax_title = "Sangat Rendah"
		elif _curr_tax < 100: tax_title = "Rendah"
		tax_rate_label.text = "Tingkat Upeti: %d%% (%s)" % [_curr_tax, tax_title]

	if tax_desc_label:
		if _curr_tax == 100:
			tax_desc_label.text = "Upeti Wajar: Pendapatan emas standar per wisma. Kebahagiaan normal."
		elif _curr_tax > 100:
			var pen = int(round((_curr_tax - 100) * 0.5))
			tax_desc_label.text = "Upeti Tinggi (+%d%% pendapatan): Dikenakan denda kebahagiaan -%d%%! Kebahagiaan rendah berlanjut (<40%%) menyebabkan wisma ditinggalkan." % [_curr_tax - 100, pen]
		else:
			var bon = int(round((100 - _curr_tax) * 0.5))
			tax_desc_label.text = "Upeti Rendah (-%d%% pendapatan): Meningkatkan kebahagiaan warga sebesar +%d%%!" % [100 - _curr_tax, bon]
