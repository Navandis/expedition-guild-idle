extends RefCounted
class_name ExpeditionManager

# ExpeditionManager owns active-expedition runtime state for this milestone's core loop.
# It now handles completion detection, report creation, and one-time reward collection
# so the UI can stay simple: dispatch -> wait -> report -> collect.

const STATUS_IDLE := "idle"
const STATUS_IN_PROGRESS := "in_progress"
const STATUS_COMPLETED := "completed"

var _active_expedition: Dictionary = {}
var _pending_report: Dictionary = {}


func has_active_expedition() -> bool:
	_update_runtime_status()
	return str(_active_expedition.get("status", STATUS_IDLE)) == STATUS_IN_PROGRESS


func has_pending_report() -> bool:
	return not _pending_report.is_empty()


func can_start_expedition() -> bool:
	# New expeditions are blocked while either a run is active or an uncollected
	# report exists. This keeps the loop linear and easy to reason about.
	_update_runtime_status()
	return _active_expedition.is_empty() and _pending_report.is_empty()


func start_expedition(expedition_offer: Dictionary) -> bool:
	if not can_start_expedition():
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
		"risk_label": str(expedition_offer.get("risk_label", "Unknown")),
		"start_time_unix": start_unix,
		"expected_finish_time": finish_unix,
		"status": STATUS_IN_PROGRESS
	}
	return true


func complete_active_expedition() -> bool:
	# Shared completion entry point used by both normal timer checks and debug button.
	if _active_expedition.is_empty():
		return false
	if not _pending_report.is_empty():
		# Protect against duplicate report generation.
		return false

	_active_expedition["status"] = STATUS_COMPLETED
	_pending_report = RewardSystem.create_report_for_expedition(_active_expedition)
	return true


func collect_pending_report() -> Dictionary:
	# Collection is one-time. After this, both report and active expedition are cleared.
	if _pending_report.is_empty():
		return {}
	if bool(_pending_report.get("collected", false)):
		return {}

	var rewards: Dictionary = (_pending_report.get("rewards", {}) as Dictionary).duplicate(true)
	_pending_report["collected"] = true
	_pending_report = {}
	_active_expedition = {}
	return rewards


func get_pending_report() -> Dictionary:
	return _pending_report.duplicate(true)


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
			return "Awaiting Report Collection"
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

	# Timer completion and debug completion both converge through this method.
	if _compute_remaining_seconds() <= 0:
		complete_active_expedition()
