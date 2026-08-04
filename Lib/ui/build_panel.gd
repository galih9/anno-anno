# build_panel.gd
# Right-side slide-in build menu panel.
# Lists all unlocked/locked building types in categorized cards.
# Exposes toggle() and rebuild() for UIManager.

extends PanelContainer

var font: Font

# ─── Setup ────────────────────────────────────────────────────────────────────

func setup(p_font: Font) -> void:
	font = p_font
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	anchor_left   = 1.0
	anchor_top    = 0.0
	anchor_right  = 1.0
	anchor_bottom = 1.0
	offset_left   = -340
	offset_top    = 0
	offset_right  = 0
	offset_bottom = 0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical   = Control.GROW_DIRECTION_BOTH

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color          = Color(0.08, 0.11, 0.16, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_color      = Color(0.2, 0.65, 0.9, 0.6)
	panel_style.corner_radius_top_left    = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.content_margin_left   = 14
	panel_style.content_margin_top    = 14
	panel_style.content_margin_right  = 14
	panel_style.content_margin_bottom = 14
	add_theme_stylebox_override("panel", panel_style)


# ─── Public API ───────────────────────────────────────────────────────────────

## Rebuilds and shows the panel. Call each time the panel is opened so the
## unlocked state reflects the latest game state.
func open() -> void:
	_rebuild()
	visible = true


func close() -> void:
	visible = false


# ─── Build UI ────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	# Remove previous content before rebuilding
	for child in get_children():
		child.queue_free()

	var pm := _get_placement_manager()
	if not pm:
		return

	var main_vbox := VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# ── Header ───────────────────────────────────────────────────────────────
	var header_hbox := HBoxContainer.new()
	header_hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	main_vbox.add_child(header_hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	header_hbox.add_child(title_vbox)

	var title := Label.new()
	title.text = "MENU PEMBANGUNAN"
	var t_set := LabelSettings.new()
	t_set.font       = font
	t_set.font_size  = 16
	t_set.font_color = Color(0.3, 0.9, 1.0)
	title.label_settings = t_set
	title_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Klik Kanan untuk Membuka/Menutup"
	var sub_set := LabelSettings.new()
	sub_set.font       = font
	sub_set.font_size  = 9
	sub_set.font_color = Color(0.6, 0.7, 0.8)
	subtitle.label_settings = sub_set
	title_vbox.add_child(subtitle)

	var close_btn := Button.new()
	close_btn.text = " X "
	close_btn.add_theme_font_override("font", font)
	close_btn.pressed.connect(func(): close())
	header_hbox.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# ── Demolish button ──────────────────────────────────────────────────────
	var demolish_btn := Button.new()
	demolish_btn.text = "MODE BONGKAR"
	demolish_btn.add_theme_font_override("font", font)
	demolish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var d_style := StyleBoxFlat.new()
	d_style.bg_color                 = Color(0.55, 0.12, 0.12, 0.9)
	d_style.corner_radius_top_left   = 6
	d_style.corner_radius_top_right  = 6
	d_style.corner_radius_bottom_left  = 6
	d_style.corner_radius_bottom_right = 6
	d_style.content_margin_top    = 8
	d_style.content_margin_bottom = 8
	demolish_btn.add_theme_stylebox_override("normal", d_style)

	var d_hover := d_style.duplicate() as StyleBoxFlat
	d_hover.bg_color = Color(0.75, 0.18, 0.18, 0.95)
	demolish_btn.add_theme_stylebox_override("hover", d_hover)

	demolish_btn.pressed.connect(func():
		if pm and pm.has_method("start_demolish_mode"):
			pm.start_demolish_mode()
		close()
	)
	main_vbox.add_child(demolish_btn)

	main_vbox.add_child(HSeparator.new())

	# ── Scrollable building list ─────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.mouse_filter          = Control.MOUSE_FILTER_STOP
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size   = Vector2(300, 0)
	main_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.mouse_filter          = Control.MOUSE_FILTER_STOP
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(content_vbox)

	# ── Group buildings by category ──────────────────────────────────────────
	var categories: Dictionary = {}
	for b in pm.buildings:
		if b == null:
			continue
		var type_name := _building_type_label(b.building_type)
		if not categories.has(type_name):
			categories[type_name] = []
		categories[type_name].append(b)

	for cat in categories.keys():
		var cat_label := Label.new()
		cat_label.text = "── " + cat + " ──"
		var c_set := LabelSettings.new()
		c_set.font       = font
		c_set.font_size  = 12
		c_set.font_color = Color(1.0, 0.8, 0.4)
		cat_label.label_settings = c_set
		content_vbox.add_child(cat_label)

		var cat_vbox := VBoxContainer.new()
		cat_vbox.mouse_filter = Control.MOUSE_FILTER_STOP
		cat_vbox.add_theme_constant_override("separation", 6)
		content_vbox.add_child(cat_vbox)

		for b in categories[cat]:
			cat_vbox.add_child(_create_building_card(b, pm))


func _create_building_card(b: BuildingData, pm: Node) -> Button:
	var main := _get_main()
	var is_unlocked := true
	if main and main.has_method("is_building_unlocked"):
		is_unlocked = main.is_building_unlocked(b)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color     = Color(0.12, 0.16, 0.22, 0.85) if is_unlocked else Color(0.06, 0.08, 0.11, 0.7)
	card_style.border_color = Color(0.25, 0.35, 0.45, 0.6)  if is_unlocked else Color(0.18, 0.22, 0.28, 0.4)
	card_style.border_width_left   = 1
	card_style.border_width_top    = 1
	card_style.border_width_right  = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left     = 6
	card_style.corner_radius_top_right    = 6
	card_style.corner_radius_bottom_left  = 6
	card_style.corner_radius_bottom_right = 6
	card_style.content_margin_left   = 8
	card_style.content_margin_top    = 6
	card_style.content_margin_right  = 8
	card_style.content_margin_bottom = 6

	var card_hover := card_style.duplicate() as StyleBoxFlat
	if is_unlocked:
		card_hover.bg_color     = Color(0.18, 0.24, 0.32, 0.95)
		card_hover.border_color = Color(0.3, 0.8, 1.0, 0.9)

	var btn := Button.new()
	btn.mouse_filter          = Control.MOUSE_FILTER_STOP
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size   = Vector2(0, 48)
	btn.add_theme_stylebox_override("normal",  card_style)
	btn.add_theme_stylebox_override("hover",   card_hover)
	btn.add_theme_stylebox_override("pressed", card_hover)
	if not is_unlocked:
		btn.disabled = true

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	btn.add_child(hbox)

	# Preview texture or fallback label
	if b.preview_texture != null:
		var tex_rect := TextureRect.new()
		tex_rect.mouse_filter       = Control.MOUSE_FILTER_IGNORE
		tex_rect.texture            = b.preview_texture
		tex_rect.expand_mode        = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode       = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(36, 36)
		if not is_unlocked:
			tex_rect.modulate = Color(0.4, 0.4, 0.4, 0.6)
		hbox.add_child(tex_rect)
	else:
		var fallback := Label.new()
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback.text = ""
		if not is_unlocked:
			fallback.modulate = Color(0.4, 0.4, 0.4, 0.6)
		hbox.add_child(fallback)

	# Name & cost column
	var info_vbox := VBoxContainer.new()
	info_vbox.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = b.display_name
	var n_set := LabelSettings.new()
	n_set.font       = font
	n_set.font_size  = 12
	n_set.font_color = Color(0.95, 0.95, 0.95) if is_unlocked else Color(0.5, 0.55, 0.6)
	name_lbl.label_settings = n_set
	info_vbox.add_child(name_lbl)

	var cost_str := "%d Emas" % b.cost
	if b.id == "house":
		cost_str += " | 10 Bambu"
	if not is_unlocked:
		if b.requires_townhall:
			cost_str = "Membutuhkan Balai Kota"
		elif b.required_population > 0:
			cost_str = "Terbuka pada %d Penduduk" % b.required_population
		else:
			cost_str = "Terkunci"

	var cost_lbl := Label.new()
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_lbl.text = cost_str
	var c_set := LabelSettings.new()
	c_set.font       = font
	c_set.font_size  = 9
	c_set.font_color = Color(0.85, 0.75, 0.4) if is_unlocked else Color(0.7, 0.4, 0.4)
	cost_lbl.label_settings = c_set
	info_vbox.add_child(cost_lbl)

	if is_unlocked:
		btn.pressed.connect(func():
			pm.start_placement(b)
			close()
		)

	return btn


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _get_placement_manager() -> Node:
	return get_parent().get_parent().get_node_or_null("PlacementManager")


func _get_main() -> Node:
	return get_parent().get_parent()


func _building_type_label(type: BuildingData.BuildingType) -> String:
	match type:
		BuildingData.BuildingType.CONNECTOR:     return "PENGHUBUNG"
		BuildingData.BuildingType.RESIDENT:      return "PEMUKIMAN"
		BuildingData.BuildingType.RESOURCE:      return "SUMBER DAYA"
		BuildingData.BuildingType.PUBLIC_SERVICE: return "FASILITAS UMUM"
		BuildingData.BuildingType.COSMETIC:      return "DEKORASI"
		BuildingData.BuildingType.GOVERNMENT:    return "PEMERINTAHAN"
		_:                                       return "BANGUNAN"
