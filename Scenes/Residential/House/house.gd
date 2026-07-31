# house.gd
# Resident-type building (Wisma Warga).
#
# Tracks three pieces of state:
#   status    — ACTIVE (connected + productive) | ABANDONED | DISCONNECTED
#   happiness — 0.0–1.0; base set by connection status, modified by nearby cosmetic buildings
#   level     — RAKYAT_JELATA -> RAKYAT_BEBAS -> RAKYAT_TERDIDIK -> PRIYAYI -> NINGRAT -> BANGSAWAN
#
# Pre-Colonial Central Java Resident Hierarchy:
#   • Level 0: Rakyat Jelata
#   • Level 1: Rakyat Bebas
#   • Level 2: Rakyat Terdidik
#   • Level 3: Priyayi
#   • Level 4: Ningrat
#   • Level 5: Bangsawan (Special titles: Raden, Menak, Brahmana)

extends Node2D

# ─── Types ────────────────────────────────────────────────────────────────────

enum Status { ACTIVE, ABANDONED, DISCONNECTED }
enum Level  {
	RAKYAT_JELATA,  # Level 0
	RAKYAT_BEBAS,   # Level 1
	RAKYAT_TERDIDIK,# Level 2
	PRIYAYI,        # Level 3
	NINGRAT,        # Level 4
	BANGSAWAN       # Level 5
}

# ─── Constants ────────────────────────────────────────────────────────────────

const ABANDON_TIME: float      = 30.0
const ABANDON_THRESHOLD: float = 0.4

const UPGRADE_LOG_COST: int   = 5
const UPGRADE_DURATION: float = 5.0

var has_restaurant_bonus: bool = false # Gelanggang influence
var has_townhall_bonus: bool = false   # Balai Kota influence
var is_fed: bool = true
var unfed_months: int = 0
var food_happiness_penalty: float = 0.0

var is_upgrading: bool = false
var upgrade_timer: float = 0.0

static func get_tier_name(lvl: int) -> String:
	match lvl:
		Level.RAKYAT_JELATA:   return "Rakyat Jelata"
		Level.RAKYAT_BEBAS:    return "Rakyat Bebas"
		Level.RAKYAT_TERDIDIK: return "Rakyat Terdidik"
		Level.PRIYAYI:         return "Priyayi"
		Level.NINGRAT:         return "Ningrat"
		Level.BANGSAWAN:       return "Bangsawan"
		_:                     return "Rakyat Jelata"

static func get_tier_title(lvl: int) -> String:
	if lvl == Level.BANGSAWAN:
		return " (Raden / Menak / Brahmana)"
	return ""

func get_monthly_food_cost() -> int:
	match level:
		Level.RAKYAT_JELATA:   return 1
		Level.RAKYAT_BEBAS:    return 3
		Level.RAKYAT_TERDIDIK: return 5
		Level.PRIYAYI:         return 8
		Level.NINGRAT:         return 12
		Level.BANGSAWAN:       return 18
		_:                     return 1

func get_population_capacity() -> int:
	match level:
		Level.RAKYAT_JELATA:
			return 6 if has_restaurant_bonus else 4
		Level.RAKYAT_BEBAS:
			return 20 if happiness >= 0.99 else 10
		Level.RAKYAT_TERDIDIK:
			return 35 if happiness >= 0.99 else 20
		Level.PRIYAYI:
			return 55 if happiness >= 0.99 else 35
		Level.NINGRAT:
			return 80 if happiness >= 0.99 else 55
		Level.BANGSAWAN:
			return 120 if happiness >= 0.99 else 80
		_:
			return 4

const HAPPINESS_CONNECTED: float    = 0.5
const HAPPINESS_DISCONNECTED: float = 0.25

# ─── State ────────────────────────────────────────────────────────────────────

var data: BuildingData

var status:    Status = Status.DISCONNECTED
var happiness: float  = HAPPINESS_DISCONNECTED
var level:     Level  = Level.RAKYAT_JELATA

# ─── Private ──────────────────────────────────────────────────────────────────

var _base_happiness: float      = HAPPINESS_DISCONNECTED
var _bench_bonus:    float      = 0.0
var tax_modifier:    float      = 0.0
var _low_happiness_timer: float = 0.0

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if is_upgrading:
		upgrade_timer += delta
		if upgrade_timer >= UPGRADE_DURATION:
			_finish_upgrade()
	elif level == Level.RAKYAT_JELATA and has_restaurant_bonus and status == Status.ACTIVE and is_fed:
		_try_start_upgrade()

	if happiness < ABANDON_THRESHOLD:
		if status != Status.ABANDONED:
			_low_happiness_timer += delta
			if _low_happiness_timer >= ABANDON_TIME:
				status = Status.ABANDONED
	else:
		if status == Status.ABANDONED:
			status = Status.ACTIVE if _base_happiness == HAPPINESS_CONNECTED else Status.DISCONNECTED
		_low_happiness_timer = 0.0

# ─── Upgrade Requirements API (Extensible) ───────────────────────────────────

func get_upgrade_requirements(target_lvl: int = -1) -> Dictionary:
	if target_lvl == -1:
		target_lvl = level + 1

	var req = {
		"can_upgrade": false,
		"current_tier_name": get_tier_name(level),
		"next_tier_name": get_tier_name(target_lvl),
		"log_cost": 0,
		"has_logs": false,
		"has_service_bonus": false,
		"status_ok": (status == Status.ACTIVE and is_fed),
		"max_tier_reached": (level >= Level.BANGSAWAN)
	}

	if req.max_tier_reached or target_lvl > Level.BANGSAWAN:
		return req

	var main_node = get_tree().root.find_child("Main", true, false) if get_tree() and get_tree().root else null
	var current_logs = main_node.log if (main_node and "log" in main_node) else 0

	match target_lvl:
		Level.RAKYAT_BEBAS:
			req.log_cost = UPGRADE_LOG_COST
			req.has_logs = (current_logs >= UPGRADE_LOG_COST)
			req.has_service_bonus = has_restaurant_bonus
			req.can_upgrade = req.has_logs and req.has_service_bonus and req.status_ok
		Level.RAKYAT_TERDIDIK, Level.PRIYAYI, Level.NINGRAT, Level.BANGSAWAN:
			# Prepared for future tier requirements
			req.log_cost = 10 * target_lvl
			req.has_logs = (current_logs >= req.log_cost)
			req.has_service_bonus = (has_restaurant_bonus and has_townhall_bonus)
			req.can_upgrade = false # Disabled until specific tier mechanics unlocked

	return req

# ─── Public API ───────────────────────────────────────────────────────────────

func get_info_text() -> String:
	var status_str = "Aktif" if status == Status.ACTIVE else ("Ditinggalkan" if status == Status.ABANDONED else "Terputus")
	var lvl_str = "Tingkat %d (%s%s)" % [level + 1, get_tier_name(level), get_tier_title(level)]
	if is_upgrading:
		lvl_str += " [Peningkatan: %d%%]" % int((upgrade_timer / UPGRADE_DURATION) * 100.0)

	var food_str = "%d Talas/bln (%s)" % [
		get_monthly_food_cost(),
		"Disuplai" if is_fed else "⚠️ KELAPARAN (%d bln)" % unfed_months
	]

	var boost_str = " +50% Bonus Upeti" if has_townhall_bonus else " Tidak ada"

	return "Status: %s\nKebahagiaan: %.0f%%\nTingkat Warga: %s\nKapasitas: %d Jiwa\nKebutuhan Talas: %s\nPengaruh Balai Kota:%s" % [
		status_str,
		happiness * 100.0,
		lvl_str,
		get_population_capacity(),
		food_str,
		boost_str
	]

func on_food_supplied() -> void:
	is_fed = true
	unfed_months = 0
	food_happiness_penalty = 0.0
	_recalculate_happiness()

func on_food_deprived() -> void:
	is_fed = false
	unfed_months += 1
	food_happiness_penalty = min(1.0, float(unfed_months) * 0.25)
	_recalculate_happiness()
	if unfed_months >= 1:
		_show_floating_text("Tidak ada Talas! Kelaparan... 🌾❌", Color(1.0, 0.3, 0.3))

func _try_start_upgrade() -> void:
	var req = get_upgrade_requirements(Level.RAKYAT_BEBAS)
	if req.can_upgrade:
		var main_node = get_tree().root.find_child("Main", true, false) if get_tree() and get_tree().root else null
		if main_node != null and "log" in main_node:
			main_node.log -= UPGRADE_LOG_COST
			is_upgrading = true
			upgrade_timer = 0.0
			_show_floating_text("Meningkatkan Wisma (5 Bambu)... 🛠️", Color(0.9, 0.7, 0.2))

func _finish_upgrade() -> void:
	is_upgrading = false
	level = Level.RAKYAT_BEBAS
	var tier_name = get_tier_name(level)
	_show_floating_text("Ditingkatkan ke %s! 🏠✨" % tier_name, Color(0.3, 0.9, 1.0))

	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color(1.15, 1.15, 1.3)

	var tree := get_tree()
	if tree != null and tree.root != null:
		var ui_manager = tree.root.find_child("UIManager", true, false)
		if ui_manager and ui_manager.has_method("show_toast"):
			ui_manager.show_toast("🏠 Wisma Ditingkatkan!", "Ditingkatkan ke Tingkat 2 (%s)! Kapasitas warga bertambah hingga 10-20 jiwa." % tier_name)

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

func reset_happiness_bonus() -> void:
	_bench_bonus = 0.0
	_recalculate_happiness()

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

func reset_townhall_bonus() -> void:
	has_townhall_bonus = false

func apply_townhall_bonus() -> void:
	has_townhall_bonus = true

func _recalculate_happiness() -> void:
	happiness = clamp(_base_happiness + _bench_bonus + tax_modifier - food_happiness_penalty, 0.0, 1.0)
