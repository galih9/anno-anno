# building_modal.gd
# Floating panel anchored to the selected building's world position.
# Displays building name, category, status info, and action buttons.
# Connects to PlacementManager signals; updates every _process frame when visible.

extends PanelContainer

var font: Font

# ─── Tracked state ────────────────────────────────────────────────────────────

var _selected_building_ref: Node2D   = null
var _selected_building_data: BuildingData = null

# Shared with InfoPanel so upgrade requirements can read current log stock.
var _curr_log: int = 0

# ─── Child references ──────────────────────────────────────────────────────────

var _title_label:    Label
var _category_label: Label
var _info_label:     Label
var _toggle_btn:     Button
var _demolish_btn:   Button
var _open_town_btn:  Button

# ─── Signals ──────────────────────────────────────────────────────────────────

## Emitted when the user wants to open the town info panel from inside the modal.
signal open_town_info_requested()

# ─── Setup ────────────────────────────────────────────────────────────────────

func setup(p_font: Font) -> void:
	font = p_font
	visible = false
	z_index = 100
	_build_ui()


func _build_ui() -> void:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color           = Color(0.08, 0.1, 0.14, 0.92)
	style_box.border_width_left  = 2
	style_box.border_width_top   = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color       = Color(0.2, 0.8, 1.0, 0.8)
	style_box.corner_radius_top_left     = 6
	style_box.corner_radius_top_right    = 6
	style_box.corner_radius_bottom_left  = 6
	style_box.corner_radius_bottom_right = 6
	style_box.content_margin_left   = 12
	style_box.content_margin_top    = 10
	style_box.content_margin_right  = 12
	style_box.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style_box)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	add_child(main_vbox)

	# ── Header row ──────────────────────────────────────────────────────────
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var header_left := VBoxContainer.new()
	header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(header_left)

	_title_label = Label.new()
	var title_settings := LabelSettings.new()
	title_settings.font       = font
	title_settings.font_size  = 14
	title_settings.font_color = Color(0.3, 0.9, 1.0)
	_title_label.label_settings = title_settings
	header_left.add_child(_title_label)

	_category_label = Label.new()
	var cat_settings := LabelSettings.new()
	cat_settings.font       = font
	cat_settings.font_size  = 10
	cat_settings.font_color = Color(0.7, 0.7, 0.7)
	_category_label.label_settings = cat_settings
	header_left.add_child(_category_label)

	var close_btn := Button.new()
	close_btn.text = " X "
	close_btn.add_theme_font_override("font", font)
	close_btn.pressed.connect(_on_close_pressed)
	header_hbox.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# ── Info text ────────────────────────────────────────────────────────────
	_info_label = Label.new()
	var info_settings := LabelSettings.new()
	info_settings.font        = font
	info_settings.font_size   = 12
	info_settings.line_spacing = 3
	_info_label.label_settings = info_settings
	main_vbox.add_child(_info_label)

	# ── Open town button (Townhall only) ─────────────────────────────────────
	_open_town_btn = Button.new()
	_open_town_btn.text    = "Kelola Kebijakan Praja"
	_open_town_btn.visible = false
	_open_town_btn.add_theme_font_override("font", font)
	_open_town_btn.pressed.connect(func(): open_town_info_requested.emit())
	main_vbox.add_child(_open_town_btn)

	# ── Action buttons ───────────────────────────────────────────────────────
	var actions_hbox := HBoxContainer.new()
	actions_hbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(actions_hbox)

	_toggle_btn = Button.new()
	_toggle_btn.text = "Hentikan Produksi"
	_toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toggle_btn.add_theme_font_override("font", font)
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	actions_hbox.add_child(_toggle_btn)

	_demolish_btn = Button.new()
	_demolish_btn.text = "Bongkar Bangunan"
	_demolish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_demolish_btn.add_theme_font_override("font", font)
	_demolish_btn.pressed.connect(_on_demolish_pressed)
	actions_hbox.add_child(_demolish_btn)


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _selected_building_ref == null:
		return
	if is_instance_valid(_selected_building_ref) and visible:
		_refresh_content()
		_update_position()
	else:
		deselect()


# ─── Public API ───────────────────────────────────────────────────────────────

func select(building: Node2D, data: BuildingData) -> void:
	_selected_building_ref  = building
	_selected_building_data = data
	visible = true
	_refresh_content()
	_update_position()


func deselect() -> void:
	_selected_building_ref  = null
	_selected_building_data = null
	visible = false


## Forwards current log count so upgrade requirements can be displayed correctly.
func set_current_log(value: int) -> void:
	_curr_log = value

# ─── Internal ─────────────────────────────────────────────────────────────────

func _refresh_content() -> void:
	if _selected_building_ref == null or not is_instance_valid(_selected_building_ref):
		return

	var is_townhall := false

	if _selected_building_data != null:
		_title_label.text = _selected_building_data.display_name
		var type_name := _building_type_label(_selected_building_data.building_type)
		_category_label.text = "[ %s ]" % type_name
		if _selected_building_data.id == "townhall":
			is_townhall = true
	else:
		_title_label.text = _selected_building_ref.name
		_category_label.text = ""
		if _selected_building_ref.name.begins_with("Townhall"):
			is_townhall = true

	_open_town_btn.visible = is_townhall

	# Info text
	if _selected_building_ref.has_method("get_info_text"):
		var info_str: String = _selected_building_ref.get_info_text()
		if _selected_building_ref.has_method("get_upgrade_requirements"):
			var req = _selected_building_ref.get_upgrade_requirements()
			info_str += "\n\n── SYARAT PENINGKATAN TIAR ──"
			if "is_upgrading" in _selected_building_ref and _selected_building_ref.is_upgrading:
				info_str += "\n [ Peningkatan sedang berlangsung... ]"
			elif not req.max_tier_reached:
				var rest_chk := " [V] Pengaruh Gelanggang" if req.has_service_bonus else " [X] Pengaruh Gelanggang"
				var log_chk  := " [V] Kayu: %d/%d Bambu" % [_curr_log, req.log_cost] if req.has_logs else " [X] Kayu: %d/%d Bambu" % [_curr_log, req.log_cost]
				info_str += "\n Target: %s\n%s\n%s" % [req.next_tier_name, rest_chk, log_chk]
			else:
				info_str += "\n [ Tingkat Tertinggi Tercapai ]"
		_info_label.text = info_str
	else:
		_info_label.text = "Status tidak tersedia."

	# Toggle button
	if _selected_building_ref.has_method("toggle_user_active"):
		_toggle_btn.visible = true
		var is_active := true
		if "is_user_active" in _selected_building_ref:
			is_active = _selected_building_ref.is_user_active
		_toggle_btn.text = "Hentikan Produksi" if is_active else "Lanjutkan Produksi"
	else:
		_toggle_btn.visible = false


func _update_position() -> void:
	if _selected_building_ref == null or not is_instance_valid(_selected_building_ref):
		return
	var canvas_transform := get_viewport().get_canvas_transform()
	var screen_pos        := canvas_transform * _selected_building_ref.global_position
	position = screen_pos + Vector2(-size.x / 2.0, -size.y - 25.0)


func _on_close_pressed() -> void:
	var pm := _get_placement_manager()
	if pm and pm.has_method("deselect_building"):
		pm.deselect_building()
	else:
		deselect()


func _on_toggle_pressed() -> void:
	if _selected_building_ref != null and is_instance_valid(_selected_building_ref):
		if _selected_building_ref.has_method("toggle_user_active"):
			_selected_building_ref.toggle_user_active()
			_refresh_content()


func _on_demolish_pressed() -> void:
	if _selected_building_ref != null and is_instance_valid(_selected_building_ref):
		var pm := _get_placement_manager()
		if pm and pm.has_method("remove_building"):
			pm.remove_building(_selected_building_ref)
			pm.deselect_building()


func _get_placement_manager() -> Node:
	return get_parent().get_parent().get_node_or_null("PlacementManager")


func _building_type_label(type: BuildingData.BuildingType) -> String:
	match type:
		BuildingData.BuildingType.CONNECTOR:     return "Penghubung"
		BuildingData.BuildingType.RESIDENT:      return "Pemukiman"
		BuildingData.BuildingType.RESOURCE:      return "Sumber Daya"
		BuildingData.BuildingType.PUBLIC_SERVICE: return "Fasilitas Umum"
		BuildingData.BuildingType.COSMETIC:      return "Dekorasi"
		BuildingData.BuildingType.GOVERNMENT:    return "Pemerintahan"
		_:                                       return "Bangunan"
