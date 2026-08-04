# building_warning_overlay.gd
# Single responsibility: Displays floating warning symbols above buildings in isometric view.
# Attach as a child of any building Node2D, or it will be auto-attached by PlacementManager.

class_name BuildingWarningOverlay
extends Node2D

# ─── Textures ─────────────────────────────────────────────────────────────────

const TEX_SLEEP       = preload("res://Assets/render/symbols/sleep.png")
const TEX_DISCONNECT  = preload("res://Assets/render/symbols/disconnect-warn.png")
const TEX_STORAGE     = preload("res://Assets/render/symbols/storage-warn.png")
const TEX_TALAS       = preload("res://Assets/render/symbols/talas.png")
const TEX_BAMBU       = preload("res://Assets/render/symbols/bambu.png")
const TEX_POPULASI    = preload("res://Assets/render/symbols/populasi.png")
const TEX_WARN        = preload("res://Assets/render/symbols/warn.png")

# ─── Node References ──────────────────────────────────────────────────────────

var icon_sprite: Sprite2D
var _time: float = 0.0
@export var base_offset: Vector2 = Vector2(0, -42)
@export var bob_amplitude: float = 3.0
@export var bob_speed: float = 3.5

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	z_index = 100
	_setup_sprite()

func _setup_sprite() -> void:
	if icon_sprite == null:
		icon_sprite = Sprite2D.new()
		icon_sprite.name = "WarningIconSprite"
		icon_sprite.position = base_offset
		add_child(icon_sprite)

func _process(delta: float) -> void:
	_time += delta
	if icon_sprite != null and visible:
		# Subtle bobbing animation
		var y_off = sin(_time * bob_speed) * bob_amplitude
		icon_sprite.position = base_offset + Vector2(0, y_off)

	update_warning_state()

# ─── Warning Evaluation ───────────────────────────────────────────────────────

## Evaluates the parent building's state and updates the overhead icon.
func update_warning_state() -> void:
	var parent_building = get_parent()
	if not is_instance_valid(parent_building) or not (parent_building is Node2D):
		visible = false
		return

	# Check if building is in build mode preview (hidden)
	if parent_building.has_method("is_preview") and parent_building.is_preview():
		visible = false
		return

	var warning_type: String = _determine_warning_type(parent_building)

	if warning_type.is_empty():
		visible = false
	else:
		visible = true
		_apply_texture(warning_type)

func _determine_warning_type(building: Node2D) -> String:
	# 1. Custom explicit warning from building method if available
	if building.has_method("get_current_warning"):
		var custom_warn: String = building.get_current_warning()
		if not custom_warn.is_empty():
			return custom_warn

	# 2. Check Disconnected status across building types
	var status_val = building.get("status")
	var status_str = str(status_val) if status_val != null else ""
	
	# Enum check or string check for disconnected
	if status_str == "DISCONNECTED" or status_str == "2" or status_str == "1" and building.get_script() and "Restaurant" in building.get_script().resource_path:
		# Check specific building script enum values
		if _is_disconnected(building, status_val):
			return "disconnect"

	# 3. Check Inactive / Sleep status
	if "is_user_active" in building and not building.is_user_active:
		return "sleep"
	if status_str == "INACTIVE" or (typeof(status_val) == TYPE_INT and status_val == 1 and not ("House" in building.name or building.has_method("on_food_supplied"))):
		return "sleep"

	# 4. Check Storage Full
	if "storage" in building and "max_storage" in building:
		var storage: int = building.storage
		var max_storage: int = building.max_storage
		if storage >= max_storage and max_storage > 0:
			return "storage"
		if status_str == "HALTED" or (typeof(status_val) == TYPE_INT and status_val == 3):
			return "storage"

	# 5. Check Disconnected explicitly again via building status enum
	if _is_disconnected(building, status_val):
		return "disconnect"

	# 6. Check House specific warnings (Starving -> Talas, Abandoned -> Populasi)
	if building.has_method("on_food_supplied"): # House check
		if "is_fed" in building and not building.is_fed:
			return "talas"
		if status_str == "ABANDONED" or (typeof(status_val) == TYPE_INT and status_val == 1):
			return "populasi"

	return ""

func _is_disconnected(building: Node2D, status_val) -> bool:
	if status_val == null:
		return false
	# Check script specific Status enum
	var script = building.get_script()
	if script == null:
		return false

	# Match building types by class or property
	if "house.gd" in script.resource_path:
		return typeof(status_val) == TYPE_INT and status_val == 2 # House Status.DISCONNECTED = 2
	elif "lumberjack.gd" in script.resource_path or "ricefield.gd" in script.resource_path:
		return typeof(status_val) == TYPE_INT and status_val == 2 # Resource Status.DISCONNECTED = 2
	elif "restaurant.gd" in script.resource_path or "townhall.gd" in script.resource_path:
		return typeof(status_val) == TYPE_INT and status_val == 1 # Restaurant/Townhall Status.DISCONNECTED = 1

	return str(status_val) == "DISCONNECTED"

func _apply_texture(warning_type: String) -> void:
	if icon_sprite == null:
		_setup_sprite()

	match warning_type:
		"sleep":
			icon_sprite.texture = TEX_SLEEP
		"disconnect":
			icon_sprite.texture = TEX_DISCONNECT
		"storage":
			icon_sprite.texture = TEX_STORAGE
		"talas":
			icon_sprite.texture = TEX_TALAS
		"bambu":
			icon_sprite.texture = TEX_BAMBU
		"populasi":
			icon_sprite.texture = TEX_POPULASI
		"warn":
			icon_sprite.texture = TEX_WARN
		_:
			icon_sprite.texture = TEX_WARN
