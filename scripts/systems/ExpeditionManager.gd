extends RefCounted
class_name ExpeditionManager

# ExpeditionManager tracks exactly one active expedition for v0.1.
# It stores runtime timing fields and exposes a small read-only API for UI.

const STATUS_IDLE := "idle"
const STATUS_IN_PROGRESS := "in_progress"
const STATUS_COMPLETED := "completed"

var _active_expedition: Dictionary = {}


func has_active_expedition() -> bool:
	_update_runtime_status()
	return str(_active_expedition.get("status", STATUS_IDLE)) == STATUS_IN_PROGRESS


func start_expedition(expedition_offer: Dictionary) -> bool:
	# One active expedition at a time keeps UX/state simple in this milestone.
	if has_active_expedition():
		return false

	# Clamp duration so malformed content cannot create a zero-length timer.
	var duration_minutes := int(expedition_offer.get("duration_minutes", 0))
	if duration_minutes <= 0:
		duration_minutes = 1

	# Track wall-clock timestamps in unix seconds for cheap runtime checks.
	var start_unix := Time.get_unix_time_from_system()
	var finish_unix := start_unix + (duration_minutes * 60)

	_active_expedition = {
		"id": str(expedition_offer.get("id", "")),
		"display_name": str(expedition_offer.get("display_name", "Unknown Expedition")),
		"duration_minutes": duration_minutes,
		"start_time_unix": start_unix,
		"expected_finish_time": finish_unix,
		"status": STATUS_IN_PROGRESS
	}
	return true


func get_active_expedition() -> Dictionary:
	_update_runtime_status()
	# Defensive copy prevents callers from mutating manager-owned state.
	return _active_expedition.duplicate(true)


func get_status_label() -> String:
	_update_runtime_status()
	var status := str(_active_expedition.get("status", STATUS_IDLE))
	match status:
		STATUS_IN_PROGRESS:
			return "In Progress"
		STATUS_COMPLETED:
			return "Completed"
		_:
			return "No Active Expedition"


func get_remaining_seconds() -> int:
	_update_runtime_status()
	if str(_active_expedition.get("status", STATUS_IDLE)) != STATUS_IN_PROGRESS:
		return 0

	return _compute_remaining_seconds()


func get_remaining_time_text() -> String:
	var remaining := get_remaining_seconds()
	if remaining <= 0:
		return "00:00"

	var minutes := remaining / 60
	var seconds := remaining % 60
	return "%02d:%02d" % [minutes, seconds]


func _compute_remaining_seconds() -> int:
	var now_unix := Time.get_unix_time_from_system()
	var expected_finish := int(_active_expedition.get("expected_finish_time", now_unix))
	return max(0, expected_finish - now_unix)


func _update_runtime_status() -> void:
	if _active_expedition.is_empty():
		return

	var status := str(_active_expedition.get("status", STATUS_IDLE))
	if status != STATUS_IN_PROGRESS:
		return

	if _compute_remaining_seconds() <= 0:
		# Completion is auto-derived from time; no explicit "complete" action yet.
		_active_expedition["status"] = STATUS_COMPLETED
