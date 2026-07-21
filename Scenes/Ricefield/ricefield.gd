# ricefield.gd
# Resource-type building.
#
# Status:
#   ACTIVE       — connected to destination via path AND has adjacent field tiles
#   INACTIVE     — placed but conditions not yet met (path ok, missing fields)
#   DISCONNECTED — missing path connection

extends Node2D

# ─── Types ────────────────────────────────────────────────────────────────────

enum Status { ACTIVE, INACTIVE, DISCONNECTED }

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

## Called by ConnectionChecker after every BFS + field-count pass.
## [param status_text] is "Connected" or "Disconnected".
## [param desc_text] carries the reason (e.g. "no path", "no fields").
func set_status(status_text: String, desc_text: String) -> void:
	if status_text == "Connected":
		status = Status.ACTIVE
	else:
		# "no path" in desc → full disconnect. Fields-only failure → INACTIVE.
		if "no path" in desc_text:
			status = Status.DISCONNECTED
		else:
			status = Status.INACTIVE
	_refresh_label()

# ─── Private helpers ──────────────────────────────────────────────────────────

func _refresh_label() -> void:
	if label == null:
		return
	label.text = "Status: %s" % Status.keys()[status]
