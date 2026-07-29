# house.gd
# Resident-type building.
#
# Tracks three pieces of state:
#   status    — ACTIVE (connected + productive) | ABANDONED | DISCONNECTED
#   happiness — 0.0–1.0; base set by connection status, modified by nearby cosmetic buildings
#   level     — PEASANT (only tier for now)
#
# Happiness rules:
#   • Connected to a destination via path → base 0.5 (50%)
#   • Disconnected                        → base 0.25 (25%)
#   • Each bench within influence radius  → +0.25 per bench (capped at 1.0)
#   • Happiness < 0.4 for ABANDON_TIME seconds → house becomes ABANDONED

extends Node2D

# ─── Types ────────────────────────────────────────────────────────────────────

enum Status { ACTIVE, ABANDONED, DISCONNECTED }
enum Level  { PEASANT, CITIZEN }

# ─── Constants ────────────────────────────────────────────────────────────────

## How long (seconds) happiness must stay below ABANDON_THRESHOLD before the
## house is marked abandoned.
const ABANDON_TIME: float      = 30.0
const ABANDON_THRESHOLD: float = 0.4

const UPGRADE_LOG_COST: int  = 5
const UPGRADE_DURATION: float = 5.0

var has_restaurant_bonus: bool = false
var is_upgrading: bool = false
var upgrade_timer: float = 0.0

func get_population_capacity() -> int:
	if level == Level.CITIZEN:
		return 20 if happiness >= 0.99 else 10
	else:
		return 6 if has_restaurant_bonus else 4

## Base happiness when connected to a destination via path.
const HAPPINESS_CONNECTED: float    = 0.5
## Base happiness when NOT connected (no path or no destination reachable).
const HAPPINESS_DISCONNECTED: float = 0.25

# ─── State ────────────────────────────────────────────────────────────────────

## BuildingData resource injected by PlacementManager at placement time.
var data: BuildingData

var status:    Status = Status.DISCONNECTED
var happiness: float  = HAPPINESS_DISCONNECTED
var level:     Level  = Level.PEASANT

# ─── Private ──────────────────────────────────────────────────────────────────

var _base_happiness: float      = HAPPINESS_DISCONNECTED
var _bench_bonus:    float      = 0.0
var tax_modifier:    float      = 0.0
var _low_happiness_timer: float = 0.0

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	# Handle Upgrade Progress
	if is_upgrading:
		upgrade_timer += delta
		if upgrade_timer >= UPGRADE_DURATION:
			_finish_upgrade()
	elif level == Level.PEASANT and has_restaurant_bonus and status == Status.ACTIVE:
		_try_start_upgrade()

	# Tick the abandonment timer only when happiness is critically low and the
	# house is not already abandoned.
	if happiness < ABANDON_THRESHOLD:
		if status != Status.ABANDONED:
			_low_happiness_timer += delta
			if _low_happiness_timer >= ABANDON_TIME:
				status = Status.ABANDONED
	else:
		# If happiness recovers to >= 40% while house was abandoned, residents move back!
		if status == Status.ABANDONED:
			status = Status.ACTIVE if _base_happiness == HAPPINESS_CONNECTED else Status.DISCONNECTED
		_low_happiness_timer = 0.0

# ─── Public API ───────────────────────────────────────────────────────────────

func get_info_text() -> String:
	var lvl_str = "Citizen (Level 2)" if level == Level.CITIZEN else "Peasant (Level 1)"
	if is_upgrading:
		lvl_str += " [Upgrading: %d%%]" % int((upgrade_timer / UPGRADE_DURATION) * 100.0)
	elif level == Level.PEASANT and has_restaurant_bonus:
		lvl_str += " (Req: 5 Logs to Upgrade)"

	return "Status: %s\nHappiness: %.0f%%\nLevel: %s\nCapacity: %d People" % [
		Status.keys()[status],
		happiness * 100.0,
		lvl_str,
		get_population_capacity()
	]

func _try_start_upgrade() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var main_node = tree.root.find_child("Main", true, false)
	if main_node != null and "log" in main_node:
		if main_node.log >= UPGRADE_LOG_COST:
			main_node.log -= UPGRADE_LOG_COST
			is_upgrading = true
			upgrade_timer = 0.0
			_show_floating_text("Upgrading House (5 Logs)... 🛠️", Color(0.9, 0.7, 0.2))

func _finish_upgrade() -> void:
	is_upgrading = false
	level = Level.CITIZEN
	_show_floating_text("Upgraded to Citizen House! 🏠✨", Color(0.3, 0.9, 1.0))

	# Modulate visual sprite to indicate tier 2
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(1.15, 1.15, 1.3)

	var tree := get_tree()
	if tree != null and tree.root != null:
		var ui_manager = tree.root.find_child("UIManager", true, false)
		if ui_manager and ui_manager.has_method("show_toast"):
			ui_manager.show_toast("🏠 House Upgraded!", "Upgraded to Level 2 (Citizen House)! Population capacity expanded to 10-20.")

func _show_floating_text(text: String, text_color: Color = Color(0.2, 1.0, 0.2)) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	label.position = Vector2(-40, -45)
	label.z_index = 100
	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -35), 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)

## Called by ConnectionChecker after every BFS pass.
## Drives the base happiness level from connection state.
func set_status(status_text: String, _desc: String) -> void:
	if status_text == "Connected":
		if status != Status.ABANDONED or happiness >= ABANDON_THRESHOLD:
			status = Status.ACTIVE
		_base_happiness = HAPPINESS_CONNECTED
	else:
		if status != Status.ABANDONED or happiness >= ABANDON_THRESHOLD:
			status = Status.DISCONNECTED
		_base_happiness = HAPPINESS_DISCONNECTED
	_recalculate_happiness()


## Called by ConnectionChecker before applying cosmetic effects.
## Clears all bench bonuses so they can be re-applied from scratch each tick.
func reset_happiness_bonus() -> void:
	_bench_bonus = 0.0
	_recalculate_happiness()


## Called by ConnectionChecker for each cosmetic building within influence radius.
func apply_happiness_bonus(amount: float) -> void:
	_bench_bonus += amount
	_recalculate_happiness()

func set_tax_modifier(amount: float) -> void:
	tax_modifier = amount
	_recalculate_happiness()

func reset_restaurant_bonus() -> void:
	has_restaurant_bonus = false

func apply_restaurant_bonus() -> void:
	has_restaurant_bonus = true

# ─── Private helpers ──────────────────────────────────────────────────────────

func _recalculate_happiness() -> void:
	happiness = clamp(_base_happiness + _bench_bonus + tax_modifier, 0.0, 1.0)

