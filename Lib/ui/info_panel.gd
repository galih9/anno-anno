# info_panel.gd
# Right-side slide-in panel: "PENGELOLAAN PRAJA"
# Shows territory statistics, storage resource cards, and tax policy controls.
# Exposes toggle() and refresh() for the UIManager orchestrator.

extends PanelContainer

var font: Font

# ─── Child label references ───────────────────────────────────────────────────

var _gold_label:     Label
var _income_label:   Label
var _pop_label:      Label
var _happiness_label: Label
var _housing_label:  Label

var _storage_food_label: Label
var _storage_log_label:  Label

var _tax_rate_label: Label
var _tax_desc_label: Label
var _tax_minus_btn:  Button
var _tax_plus_btn:   Button

# ─── Cached values ────────────────────────────────────────────────────────────

var _curr_gold:      int   = 0
var _curr_food:      int   = 0
var _curr_log:       int   = 0
var _curr_pop:       int   = 0
var _curr_income:    int   = 0
var _curr_happiness: float = 1.0
var _curr_tax:       int   = 100

# ─── Setup ────────────────────────────────────────────────────────────────────

func setup(p_font: Font) -> void:
	font = p_font
	visible = false
	z_index = 110
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

	_build_ui()


func _build_ui() -> void:
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
	title.text = "PENGELOLAAN PRAJA"
	var t_set := LabelSettings.new()
	t_set.font       = font
	t_set.font_size  = 16
	t_set.font_color = Color(0.3, 0.9, 1.0)
	title.label_settings = t_set
	title_vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Ikhtisar Wilayah, Lumbung & Kebijakan"
	var s_set := LabelSettings.new()
	s_set.font       = font
	s_set.font_size  = 9
	s_set.font_color = Color(0.65, 0.75, 0.85)
	sub.label_settings = s_set
	title_vbox.add_child(sub)

	var close_btn := Button.new()
	close_btn.text = " X "
	close_btn.add_theme_font_override("font", font)
	close_btn.pressed.connect(func(): visible = false)
	header_hbox.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# ── Section label style (reused) ─────────────────────────────────────────
	var st_set := LabelSettings.new()
	st_set.font       = font
	st_set.font_size  = 11
	st_set.font_color = Color(1.0, 0.8, 0.4)

	var font_settings := LabelSettings.new()
	font_settings.font      = font
	font_settings.font_size = 14

	# ── Statistics section ───────────────────────────────────────────────────
	var stats_title := Label.new()
	stats_title.text = "── STATISTIK WILAYAH ──"
	stats_title.label_settings = st_set
	main_vbox.add_child(stats_title)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 5)
	main_vbox.add_child(stats_vbox)

	_gold_label      = _make_stat_label(font_settings, stats_vbox)
	_income_label    = _make_stat_label(font_settings, stats_vbox)
	_pop_label       = _make_stat_label(font_settings, stats_vbox)
	_happiness_label = _make_stat_label(font_settings, stats_vbox)
	_housing_label   = _make_stat_label(font_settings, stats_vbox)

	main_vbox.add_child(HSeparator.new())

	# ── Storage section ──────────────────────────────────────────────────────
	var storage_header := Label.new()
	storage_header.text = "── LUMBUNG & HASIL BUMI ──"
	storage_header.label_settings = st_set
	main_vbox.add_child(storage_header)

	var storage_grid := GridContainer.new()
	storage_grid.columns = 4
	storage_grid.add_theme_constant_override("h_separation", 6)
	storage_grid.add_theme_constant_override("v_separation", 6)
	main_vbox.add_child(storage_grid)

	var card_style := _make_card_style()

	var talas_result := _make_resource_card("res://Assets/render/symbols/talas.png", "Talas", card_style)
	_storage_food_label = talas_result.amount_label
	storage_grid.add_child(talas_result.card)

	var bambu_result := _make_resource_card("res://Assets/render/symbols/bambu.png", "Bambu", card_style)
	_storage_log_label = bambu_result.amount_label
	storage_grid.add_child(bambu_result.card)

	var batu_result := _make_resource_card("res://Assets/render/symbols/batu.png", "Batu", card_style)
	batu_result.amount_label.text = "0"
	storage_grid.add_child(batu_result.card)

	var jati_result := _make_resource_card("res://Assets/render/symbols/jati.png", "Jati", card_style)
	jati_result.amount_label.text = "0"
	storage_grid.add_child(jati_result.card)

	main_vbox.add_child(HSeparator.new())

	# ── Tax policy section ───────────────────────────────────────────────────
	var tax_header := Label.new()
	tax_header.text = "── KEBIJAKAN UPETI (PAJAK) ──"
	tax_header.label_settings = st_set
	main_vbox.add_child(tax_header)

	var tax_hbox := HBoxContainer.new()
	tax_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tax_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(tax_hbox)

	_tax_minus_btn = Button.new()
	_tax_minus_btn.text = "  -  "
	_tax_minus_btn.add_theme_font_override("font", font)
	_tax_minus_btn.pressed.connect(func(): _adjust_tax(-10))
	tax_hbox.add_child(_tax_minus_btn)

	_tax_rate_label = Label.new()
	_tax_rate_label.text = "Tingkat Upeti: 100%"
	_tax_rate_label.label_settings = font_settings
	tax_hbox.add_child(_tax_rate_label)

	_tax_plus_btn = Button.new()
	_tax_plus_btn.text = "  +  "
	_tax_plus_btn.add_theme_font_override("font", font)
	_tax_plus_btn.pressed.connect(func(): _adjust_tax(+10))
	tax_hbox.add_child(_tax_plus_btn)

	_tax_desc_label = Label.new()
	var desc_set := LabelSettings.new()
	desc_set.font        = font
	desc_set.font_size   = 10
	desc_set.font_color  = Color(0.8, 0.85, 0.9)
	desc_set.line_spacing = 2
	_tax_desc_label.label_settings = desc_set
	_tax_desc_label.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_tax_desc_label)


# ─── Public API ───────────────────────────────────────────────────────────────

## Toggle visibility. Force-shows when [param force_show] is true.
func toggle(force_show: bool = false) -> void:
	var should_show := force_show or not visible
	visible = should_show
	if visible:
		_refresh_display()


## Update cached resource values and redraw if visible.
func refresh(gold: int, food: int, log: int, population: int,
		monthly_income: int, avg_happiness: float, tax_rate: int) -> void:
	_curr_gold      = gold
	_curr_food      = food
	_curr_log       = log
	_curr_pop       = population
	_curr_income    = monthly_income
	_curr_happiness = avg_happiness
	_curr_tax       = tax_rate
	if visible:
		_refresh_display()


## Returns the current cached log amount (used by BuildingModal for upgrade UI).
func get_curr_log() -> int:
	return _curr_log


# ─── Internal ─────────────────────────────────────────────────────────────────

func _refresh_display() -> void:
	var main := _get_main()

	var act_houses: int  = main.active_houses_count       if (main and "active_houses_count"       in main) else 0
	var ab_houses: int   = main.abandoned_houses_count    if (main and "abandoned_houses_count"    in main) else 0
	var gross_tax: int   = main.gross_tax_monthly         if (main and "gross_tax_monthly"         in main) else _curr_income
	var total_maint: int = main.total_maintenance_monthly if (main and "total_maintenance_monthly" in main) else 0

	var sign_str := ("+" if _curr_income >= 0 else "") + str(_curr_income)

	if _gold_label:
		_gold_label.text = "Perbendaharaan: %d Emas" % _curr_gold
	if _income_label:
		var maint_str := ""
		if total_maint > 0:
			maint_str = " (Upeti: +%d, Pemeliharaan: -%d)" % [gross_tax, total_maint]
		_income_label.text = "Pendapatan Bersih: %s Emas / bln%s" % [sign_str, maint_str]
	if _pop_label:
		_pop_label.text = "Total Warga: %d Jiwa" % _curr_pop
	if _happiness_label:
		var hap_pct := int(round(_curr_happiness * 100.0))
		_happiness_label.text = "Kebahagiaan: %d%%" % hap_pct
	if _housing_label:
		_housing_label.text = "Wisma: %d Aktif / %d Ditinggalkan" % [act_houses, ab_houses]

	if _storage_food_label:
		_storage_food_label.text = "%d unit" % _curr_food
	if _storage_log_label:
		_storage_log_label.text = "%d unit" % _curr_log

	if _tax_rate_label:
		var tax_title := _tax_label(_curr_tax)
		_tax_rate_label.text = "Tingkat Upeti: %d%% (%s)" % [_curr_tax, tax_title]

	if _tax_desc_label:
		if _curr_tax == 100:
			_tax_desc_label.text = "Upeti Wajar: Pendapatan emas standar per wisma. Kebahagiaan normal."
		elif _curr_tax > 100:
			var pen := int(round((_curr_tax - 100) * 0.5))
			_tax_desc_label.text = "Upeti Tinggi (+%d%% pendapatan): Dikenakan denda kebahagiaan -%d%%! Kebahagiaan rendah berlanjut (<40%%) menyebabkan wisma ditinggalkan." % [_curr_tax - 100, pen]
		else:
			var bon := int(round((100 - _curr_tax) * 0.5))
			_tax_desc_label.text = "Upeti Rendah (-%d%% pendapatan): Meningkatkan kebahagiaan warga sebesar +%d%%!" % [100 - _curr_tax, bon]


func _adjust_tax(delta: int) -> void:
	var main := _get_main()
	if main and main.has_method("set_tax_rate"):
		main.set_tax_rate(main.tax_rate + delta)


func _get_main() -> Node:
	# UIManager (CanvasLayer) → Main (Node2D)
	return get_parent().get_parent()


func _tax_label(rate: int) -> String:
	if rate > 150: return "Sangat Tinggi"
	if rate > 100: return "Tinggi"
	if rate < 50:  return "Sangat Rendah"
	if rate < 100: return "Rendah"
	return "Wajar"


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_stat_label(settings: LabelSettings, parent: VBoxContainer) -> Label:
	var lbl := Label.new()
	lbl.label_settings = settings
	parent.add_child(lbl)
	return lbl


func _make_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.1, 0.14, 0.2, 0.85)
	style.border_width_left   = 1
	style.border_width_top    = 1
	style.border_width_right  = 1
	style.border_width_bottom = 1
	style.border_color        = Color(0.25, 0.6, 0.8, 0.5)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 4
	style.content_margin_top    = 6
	style.content_margin_right  = 4
	style.content_margin_bottom = 6
	return style


func _make_resource_card(tex_path: String, title_str: String, card_style: StyleBoxFlat) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size       = Vector2(70, 62)
	card.size_flags_horizontal     = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var tex := TextureRect.new()
	tex.texture          = load(tex_path)
	tex.expand_mode      = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode     = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(24, 24)
	vbox.add_child(tex)

	var amt_lbl := Label.new()
	amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var amt_set := LabelSettings.new()
	amt_set.font       = font
	amt_set.font_size  = 11
	amt_set.font_color = Color(0.95, 0.95, 0.95)
	amt_lbl.label_settings = amt_set
	vbox.add_child(amt_lbl)

	var t_lbl := Label.new()
	t_lbl.text = title_str
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_lbl_set := LabelSettings.new()
	title_lbl_set.font       = font
	title_lbl_set.font_size  = 8
	title_lbl_set.font_color = Color(0.65, 0.75, 0.85)
	t_lbl.label_settings = title_lbl_set
	vbox.add_child(t_lbl)

	return {"card": card, "amount_label": amt_lbl}
