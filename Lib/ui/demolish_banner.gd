# demolish_banner.gd
# Top-center banner shown when demolish mode is active.
# Owned and toggled by UIManager via show() / hide().

extends PanelContainer

var font: Font


func setup(p_font: Font) -> void:
	font = p_font
	visible = false
	z_index = 120

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.18, 0.05, 0.05, 0.9)
	style.border_width_left   = 2
	style.border_width_top    = 2
	style.border_width_right  = 2
	style.border_width_bottom = 2
	style.border_color        = Color(0.9, 0.25, 0.25, 0.95)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 16
	style.content_margin_top    = 8
	style.content_margin_right  = 16
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = "MODE BONGKAR  |  Klik: bongkar bangunan  |  Tahan & Geser: bongkar jalan  |  ESC / Klik Kanan: keluar"
	var lbl_set := LabelSettings.new()
	lbl_set.font       = font
	lbl_set.font_size  = 12
	lbl_set.font_color = Color(1.0, 0.4, 0.4)
	lbl.label_settings = lbl_set
	add_child(lbl)

	# Center horizontally at top of screen
	anchor_left   = 0.5
	anchor_right  = 0.5
	anchor_top    = 0.0
	anchor_bottom = 0.0
	offset_top    = 20
	grow_horizontal = Control.GROW_DIRECTION_BOTH
