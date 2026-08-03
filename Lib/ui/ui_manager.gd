# ui_manager.gd
# CanvasLayer orchestrator — owns and connects all UI sub-panels.
#
# Sub-panels (each in Lib/ui/):
#   HudStatusBar    → top-left gold / population ticker
#   ToastManager    → top-right animated notifications
#   BuildingModal   → floating panel over selected building
#   InfoPanel       → right-side PRAJA/town statistics panel
#   BuildPanel      → right-side build menu with building cards
#   DemolishBanner  → top-center mode indicator
#   PauseMenu       → centered ESC overlay
#
# This file only wires signals, routes calls, and handles global hotkeys.

extends CanvasLayer

var font := preload("res://Assets/Silkscreen-Regular.ttf")

# ─── Sub-panel node references ────────────────────────────────────────────────

var hud_status_bar: PanelContainer
var toast_manager:  VBoxContainer
var building_modal: PanelContainer
var info_panel:     PanelContainer
var build_panel:    PanelContainer
var demolish_banner: PanelContainer
var pause_menu:     PanelContainer

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_create_hud_status_bar()
	_create_toast_manager()
	_create_building_modal()
	_create_info_panel()
	_create_demolish_banner()
	_create_pause_menu()
	_create_hud_buttons()

	# Build panel and PlacementManager connections are deferred so the scene
	# tree is fully initialised before we query child nodes.
	call_deferred("_create_build_panel")
	call_deferred("_connect_signals")
	call_deferred("_connect_camera_signals")


# ─── Sub-panel creation ───────────────────────────────────────────────────────

func _create_hud_status_bar() -> void:
	hud_status_bar = load("res://Lib/ui/hud_status_bar.gd").new()
	hud_status_bar.name = "HudStatusBar"
	add_child(hud_status_bar)
	hud_status_bar.setup(font)


func _create_toast_manager() -> void:
	toast_manager = load("res://Lib/ui/toast_manager.gd").new()
	toast_manager.name = "ToastManager"
	add_child(toast_manager)
	toast_manager.setup(font)


func _create_building_modal() -> void:
	building_modal = load("res://Lib/ui/building_modal.gd").new()
	building_modal.name = "BuildingModal"
	add_child(building_modal)
	building_modal.setup(font)
	building_modal.open_town_info_requested.connect(func(): toggle_info_panel(true))


func _create_info_panel() -> void:
	info_panel = load("res://Lib/ui/info_panel.gd").new()
	info_panel.name = "InfoPanel"
	add_child(info_panel)
	info_panel.setup(font)


func _create_demolish_banner() -> void:
	demolish_banner = load("res://Lib/ui/demolish_banner.gd").new()
	demolish_banner.name = "DemolishBanner"
	add_child(demolish_banner)
	demolish_banner.setup(font)


func _create_pause_menu() -> void:
	pause_menu = load("res://Lib/ui/pause_menu.gd").new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.setup(font)


func _create_build_panel() -> void:
	if build_panel != null:
		build_panel.queue_free()
	build_panel = load("res://Lib/ui/build_panel.gd").new()
	build_panel.name = "BuildPanel"
	add_child(build_panel)
	build_panel.setup(font)


# ─── HUD shortcut buttons ─────────────────────────────────────────────────────

func _create_hud_buttons() -> void:
	var style_norm := _make_hud_btn_style(Color(0.1, 0.14, 0.2, 0.9), Color(0.2, 0.7, 0.9, 0.8))
	var style_hover := _make_hud_btn_style(Color(0.15, 0.22, 0.3, 0.95), Color(0.4, 0.85, 1.0, 1.0))

	var info_btn := _make_hud_button("PRAJA", style_norm, style_hover,
		-320, -155, func(): toggle_info_panel())
	add_child(info_btn)

	var build_btn := _make_hud_button("PEMBANGUNAN", style_norm, style_hover,
		-155, -15, func(): toggle_build_menu())
	add_child(build_btn)


func _make_hud_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = bg
	s.border_width_left   = 2
	s.border_width_top    = 2
	s.border_width_right  = 2
	s.border_width_bottom = 2
	s.border_color        = border
	s.corner_radius_top_left     = 8
	s.corner_radius_top_right    = 8
	s.corner_radius_bottom_left  = 8
	s.corner_radius_bottom_right = 8
	s.content_margin_left  = 8
	s.content_margin_right = 8
	return s


func _make_hud_button(label: String, norm: StyleBoxFlat, hover: StyleBoxFlat,
		offset_l: int, offset_r: int, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text         = label
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_font_override("font", font)
	btn.anchor_left   = 1.0
	btn.anchor_top    = 1.0
	btn.anchor_right  = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left   = offset_l
	btn.offset_top    = -50
	btn.offset_right  = offset_r
	btn.offset_bottom = -15
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	btn.add_theme_stylebox_override("normal",  norm)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.pressed.connect(callback)
	return btn


# ─── Signal connections ────────────────────────────────────────────────────────

func _connect_signals() -> void:
	var main := get_parent()
	if main.has_signal("resources_updated"):
		main.resources_updated.connect(_on_resources_updated)

	var pm := main.get_node_or_null("PlacementManager")
	if pm:
		if pm.has_signal("building_selected"):
			pm.building_selected.connect(_on_building_selected)
		if pm.has_signal("building_deselected"):
			pm.building_deselected.connect(_on_building_deselected)
		if pm.has_signal("demolish_mode_changed"):
			pm.demolish_mode_changed.connect(_on_demolish_mode_changed)


func _connect_camera_signals() -> void:
	# Connect the camera's tap signal so RMB opens the build menu only when
	# the player did NOT drag the camera.
	var camera := get_parent().get_node_or_null("Camera2D")
	if camera == null:
		# Fall back: search all children for a Camera2D.
		camera = _find_camera(get_parent())
	if camera != null and camera.has_signal("right_click_tapped"):
		camera.right_click_tapped.connect(_on_camera_right_click_tapped)


func _find_camera(node: Node) -> Node:
	for child in node.get_children():
		if child is Camera2D:
			return child
	return null


func _on_camera_right_click_tapped() -> void:
	# Only open if no UI control is hovered (avoids firing over panels).
	if get_viewport().gui_get_hovered_control() != null:
		return
	toggle_build_menu()


# ─── Public API ───────────────────────────────────────────────────────────────

## Displays a timed toast notification.
func show_toast(title_text: String, message_text: String, duration: float = 4.0) -> void:
	if toast_manager != null:
		toast_manager.show_toast(title_text, message_text, duration)


## Toggles or forces the pause state.
## Pass true to pause, false to unpause, or omit to toggle.
func toggle_pause(force_state = null) -> void:
	var new_state: bool
	if force_state != null:
		new_state = bool(force_state)
	else:
		new_state = not get_tree().paused

	get_tree().paused = new_state
	if pause_menu != null:
		pause_menu.visible = new_state
		if new_state:
			pause_menu.sync_camera_toggles()


## Toggles or force-shows the town info panel.
func toggle_info_panel(force_show: bool = false) -> void:
	if force_show:
		if build_panel != null:
			build_panel.close()
		info_panel.toggle(true)
	else:
		if info_panel.visible:
			info_panel.toggle(false)
		else:
			if build_panel != null:
				build_panel.close()
			info_panel.toggle(true)


## Toggles the build menu open/closed.
func toggle_build_menu(force_state: int = -1) -> void:
	var pm := get_parent().get_node_or_null("PlacementManager")
	var is_open: bool = (build_panel != null and build_panel.visible) \
		or (pm != null and (pm.is_build_mode() or pm.is_demolish_mode()))

	var should_open: bool
	if force_state != -1:
		should_open = (force_state == 1)
	else:
		should_open = not is_open

	if should_open:
		if info_panel != null:
			info_panel.visible = false
		if build_panel != null:
			build_panel.open()
	else:
		if build_panel != null:
			build_panel.close()
		if pm != null:
			if pm.has_method("exit_build_mode"):
				pm.exit_build_mode()
			if pm.has_method("exit_demolish_mode"):
				pm.exit_demolish_mode()


# ─── Signal handlers ──────────────────────────────────────────────────────────

func _on_resources_updated(gold: int, food: int, log: int, population: int,
		monthly_income: int = 0, avg_happiness: float = 1.0, tax_rate: int = 100) -> void:

	if hud_status_bar != null:
		hud_status_bar.update(gold, monthly_income, population)

	if building_modal != null:
		building_modal.set_current_log(log)

	if info_panel != null:
		info_panel.refresh(gold, food, log, population, monthly_income, avg_happiness, tax_rate)


func _on_building_selected(building: Node2D, data: BuildingData) -> void:
	if building_modal != null:
		building_modal.select(building, data)


func _on_building_deselected() -> void:
	if building_modal != null:
		building_modal.deselect()


func _on_demolish_mode_changed(enabled: bool) -> void:
	if demolish_banner != null:
		demolish_banner.visible = enabled


# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("info_btn"):
		toggle_info_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_btn"):
		# build_btn is now keyboard-only (B key or similar).
		# RMB tapping is handled via camera.right_click_tapped signal.
		toggle_build_menu()
		get_viewport().set_input_as_handled()
