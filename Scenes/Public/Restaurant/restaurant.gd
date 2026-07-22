# restaurant.gd
# Public service building — acts as the destination/heart of the city.
#
# Status:
#   ACTIVE       — reachable via the path network (houses connect *to* it)
#   DISCONNECTED — not yet connected to any path
#
# Note: ConnectionChecker does NOT call set_status() on restaurants in the
# normal flow because they are is_destination buildings, not consumers.
# The set_status() method is kept for forward compatibility.

extends Node2D

# ─── Types ────────────────────────────────────────────────────────────────────

enum Status { ACTIVE, DISCONNECTED }

# ─── State ────────────────────────────────────────────────────────────────────

## BuildingData resource injected by PlacementManager at placement time.
var data: BuildingData

var status: Status = Status.DISCONNECTED

# ─── Private ──────────────────────────────────────────────────────────────────

@onready var label = $Container/Label

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_refresh_label()

# ─── Public API ───────────────────────────────────────────────────────────────

## Called if the restaurant ever receives an external status update.
func set_status(status_text: String, _desc: String) -> void:
	if status_text == "Connected":
		status = Status.ACTIVE
	else:
		status = Status.DISCONNECTED
	_refresh_label()

# ─── Private helpers ──────────────────────────────────────────────────────────

func _refresh_label() -> void:
	if label == null:
		return
	label.text = "Status: %s" % Status.keys()[status]
