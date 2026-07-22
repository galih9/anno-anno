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
enum Level  { PEASANT }

# ─── Constants ────────────────────────────────────────────────────────────────

## How long (seconds) happiness must stay below ABANDON_THRESHOLD before the
## house is marked abandoned.
const ABANDON_TIME: float      = 30.0
const ABANDON_THRESHOLD: float = 0.4

const POPULATION_CAPACITY: int = 4

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
var _low_happiness_timer: float = 0.0

@onready var label = $Container/Label

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_refresh_label()


func _process(delta: float) -> void:
	# Tick the abandonment timer only when happiness is critically low and the
	# house is not already abandoned.
	if happiness < ABANDON_THRESHOLD and status != Status.ABANDONED:
		_low_happiness_timer += delta
		if _low_happiness_timer >= ABANDON_TIME:
			status = Status.ABANDONED
			_refresh_label()
	else:
		# Reset timer as soon as happiness recovers or house is already abandoned.
		_low_happiness_timer = 0.0

# ─── Public API ───────────────────────────────────────────────────────────────

## Called by ConnectionChecker after every BFS pass.
## Drives the base happiness level from connection state.
func set_status(status_text: String, _desc: String) -> void:
	if status == Status.ABANDONED:
		# Abandoned houses ignore status updates — they stay abandoned.
		return
	if status_text == "Connected":
		status = Status.ACTIVE
		_base_happiness = HAPPINESS_CONNECTED
	else:
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

# ─── Private helpers ──────────────────────────────────────────────────────────

func _recalculate_happiness() -> void:
	happiness = clamp(_base_happiness + _bench_bonus, 0.0, 1.0)
	_refresh_label()


func _refresh_label() -> void:
	if label == null:
		return
	label.text = "Status: %s\nHappiness: %.0f%%\nLevel: %s" % [
		Status.keys()[status], happiness * 100.0, Level.keys()[level]
	]
