# toast_manager.gd
# Self-contained floating toast notification container.
# Sits at the top-right of the screen (z_index 200).
# Call show_toast(title, message, duration) to display a timed notification.
# Add as a child of UIManager (CanvasLayer).

extends VBoxContainer

var font: Font


func setup(p_font: Font) -> void:
	font = p_font
	_build_ui()


func _build_ui() -> void:
	z_index           = 200
	anchor_left       = 1.0
	anchor_top        = 0.0
	anchor_right      = 1.0
	anchor_bottom     = 0.0
	offset_left       = -360
	offset_top        = 20
	offset_right      = -20
	mouse_filter      = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)


## Shows an animated toast notification that fades out after [param duration] seconds.
func show_toast(title_text: String, message_text: String, duration: float = 4.0) -> void:
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color           = Color(0.08, 0.12, 0.18, 0.95)
	style.border_width_left  = 3
	style.border_color       = Color(0.3, 0.85, 1.0, 0.9)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 12
	style.content_margin_top    = 8
	style.content_margin_right  = 12
	style.content_margin_bottom = 8
	toast.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	toast.add_child(vbox)

	var t_lbl := Label.new()
	t_lbl.text = title_text
	var t_set := LabelSettings.new()
	t_set.font       = font
	t_set.font_size  = 12
	t_set.font_color = Color(0.3, 0.9, 1.0)
	t_lbl.label_settings = t_set
	vbox.add_child(t_lbl)

	var m_lbl := Label.new()
	m_lbl.text = message_text
	var m_set := LabelSettings.new()
	m_set.font       = font
	m_set.font_size  = 10
	m_set.font_color = Color(0.9, 0.95, 1.0)
	m_lbl.label_settings = m_set
	vbox.add_child(m_lbl)

	add_child(toast)

	toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duration)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)
