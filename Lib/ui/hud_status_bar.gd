# hud_status_bar.gd
# Top-left always-visible ticker: Emas (gold + income) and Penduduk (population).
# Single responsibility: own the panel and update its text.
# Add as a child of UIManager (CanvasLayer).

extends PanelContainer

var font: Font

var _label: Label

func setup(p_font: Font) -> void:
	font = p_font
	_build_ui()


func _build_ui() -> void:
	z_index = 90
	position = Vector2(20, 20)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.11, 0.16, 0.9)
	panel_style.border_width_left   = 2
	panel_style.border_width_top    = 2
	panel_style.border_width_right  = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.2, 0.7, 0.9, 0.6)
	panel_style.corner_radius_top_left     = 8
	panel_style.corner_radius_top_right    = 8
	panel_style.corner_radius_bottom_left  = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left   = 14
	panel_style.content_margin_top    = 8
	panel_style.content_margin_right  = 14
	panel_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", panel_style)

	_label = Label.new()
	var lbl_settings := LabelSettings.new()
	lbl_settings.font      = font
	lbl_settings.font_size = 14
	_label.label_settings  = lbl_settings
	_label.text = "Emas: 0 (+0)   Penduduk: 0"
	add_child(_label)


## Called by UIManager whenever resources change.
func update(gold: int, monthly_income: int, population: int) -> void:
	if _label == null:
		return
	var sign_str := ("+" if monthly_income >= 0 else "") + str(monthly_income)
	_label.text = "Emas: %d (%s)   Penduduk: %d" % [gold, sign_str, population]
