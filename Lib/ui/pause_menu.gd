# pause_menu.gd
# Centered overlay shown when the game is paused (ESC key).
# Includes camera control toggles and a resume button.
# Owned by UIManager; call toggle_pause() to show/hide.

extends PanelContainer

var font: Font

var _edge_pan_checkbox: CheckBox
var _rmb_pan_checkbox:  CheckBox


func setup(p_font: Font) -> void:
	font = p_font
	visible  = false
	z_index  = 300
	mouse_filter = Control.MOUSE_FILTER_STOP

	anchor_left   = 0.5
	anchor_top    = 0.5
	anchor_right  = 0.5
	anchor_bottom = 0.5
	offset_left   = -190
	offset_top    = -140
	offset_right  = 190
	offset_bottom = 140
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical   = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.06, 0.09, 0.14, 0.96)
	style.border_width_left   = 2
	style.border_width_top    = 2
	style.border_width_right  = 2
	style.border_width_bottom = 2
	style.border_color        = Color(0.3, 0.8, 1.0, 0.9)
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left   = 16
	style.content_margin_top    = 16
	style.content_margin_right  = 16
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)

	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := Label.new()
	title.text = "PERMAINAN DIHENTIKAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t_set := LabelSettings.new()
	t_set.font       = font
	t_set.font_size  = 15
	t_set.font_color = Color(0.3, 0.9, 1.0)
	title.label_settings = t_set
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var sub := Label.new()
	sub.text = "Pengaturan Kontrol Kamera:"
	var s_set := LabelSettings.new()
	s_set.font       = font
	s_set.font_size  = 11
	s_set.font_color = Color(0.85, 0.85, 0.85)
	sub.label_settings = s_set
	vbox.add_child(sub)

	_edge_pan_checkbox = CheckBox.new()
	_edge_pan_checkbox.text = " Move by Edge Cursor"
	_edge_pan_checkbox.add_theme_font_override("font", font)
	_edge_pan_checkbox.button_pressed = true
	_edge_pan_checkbox.toggled.connect(func(on: bool):
		var cam := get_viewport().get_camera_2d()
		if cam and "enable_edge_pan" in cam:
			cam.enable_edge_pan = on
	)
	vbox.add_child(_edge_pan_checkbox)

	_rmb_pan_checkbox = CheckBox.new()
	_rmb_pan_checkbox.text = " Move by Hold Right Click"
	_rmb_pan_checkbox.add_theme_font_override("font", font)
	_rmb_pan_checkbox.button_pressed = true
	_rmb_pan_checkbox.toggled.connect(func(on: bool):
		var cam := get_viewport().get_camera_2d()
		if cam and "enable_right_click_pan" in cam:
			cam.enable_right_click_pan = on
	)
	vbox.add_child(_rmb_pan_checkbox)

	vbox.add_child(HSeparator.new())

	var resume_btn := Button.new()
	resume_btn.text = "LANJUTKAN"
	resume_btn.add_theme_font_override("font", font)
	resume_btn.custom_minimum_size = Vector2(0, 36)
	resume_btn.pressed.connect(func(): _get_ui_manager().toggle_pause(false))
	vbox.add_child(resume_btn)


## Sync checkbox states from actual camera state when the menu opens.
func sync_camera_toggles() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if "enable_edge_pan" in cam and _edge_pan_checkbox:
		_edge_pan_checkbox.button_pressed = cam.enable_edge_pan
	if "enable_right_click_pan" in cam and _rmb_pan_checkbox:
		_rmb_pan_checkbox.button_pressed = cam.enable_right_click_pan


func _get_ui_manager() -> Node:
	return get_parent()
