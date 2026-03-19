extends RefCounted
class_name ExpeditionManager

# ExpeditionManager owns expedition runtime state for the Guild Hall loop.
# In this milestone it supports exactly 2 expedition slots (not more), tracks
# per-slot timer completion, and queues completed reports so they can be opened
# and collected one at a time. It also keeps one-time reward collection rules,
# applies upgrade effects at dispatch time, and exposes save/restore helpers.

const STATUS_IDLE := "idle"
const STATUS_IN_PROGRESS := "in_progress"
const STATUS_COMPLETED := "completed"
const MAX_ACTIVE_SLOTS := 2

var _active_expeditions: Array[Dictionary] = [{}, {}]
var _pending_reports: Array[Dictionary] = []


func has_active_expedition() -> bool:
	_update_runtime_status()
	for slot_data in _active_expeditions:
		if str(slot_data.get("status", STATUS_IDLE)) == STATUS_IN_PROGRESS:
			return true
	return false


func has_pending_report() -> bool:
	return not _pending_reports.is_empty()


func get_pending_report_count() -> int:
	return _pending_reports.size()


func can_start_expedition() -> bool:
	_update_runtime_status()
	# Dispatch always uses the first free slot. Reports in queue do not block dispatch.
	return _find_first_free_slot_index() >= 0


func start_expedition(expedition_offer: Dictionary, upgrade_effects: Dictionary = {}) -> bool:
	_update_runtime_status()
	var slot_index := _find_first_free_slot_index()
	if slot_index < 0:
		return false

	# Always rebuild from canonical base values so dispatch uses the latest
	# upgrade effects even if the selected payload was generated earlier.
	var effective_offer := ExpeditionOfferEffects.build_preview(expedition_offer, upgrade_effects)

	# Clamp duration so malformed content cannot create a zero-length timer.
	var duration_minutes := int(effective_offer.get("duration_minutes", 0))
	if duration_minutes <= 0:
		duration_minutes = 1

	var final_success := clampf(float(effective_offer.get("base_success", 0.75)), 0.05, 0.99)
	var gold_multiplier: float = maxf(0.20, float(upgrade_effects.get("gold_multiplier", 1.0)))

	# Track wall-clock timestamps in unix seconds for cheap runtime checks.
	var start_unix := Time.get_unix_time_from_system()
	var finish_unix := start_unix + (duration_minutes * 60)

	# Slot assignment: first free slot receives the new expedition.
	_active_expeditions[slot_index] = {
		"id": str(effective_offer.get("id", "")),
		"display_name": str(effective_offer.get("display_name", "Unknown Expedition")),
		"duration_minutes": duration_minutes,
		"base_duration_minutes": duration_minutes,
		"risk_label": str(effective_offer.get("risk_label", "Unknown")),
		"site_type": str(effective_offer.get("site_type", "unknown_site")),
		# Store values used by RewardSystem to resolve upgraded outcomes/rewards.
		"base_success": final_success,
		"gold_multiplier": gold_multiplier,
		"start_time_unix": start_unix,
		"expected_finish_time": finish_unix,
		"status": STATUS_IN_PROGRESS,
		"slot_index": slot_index
	}
	return true


func complete_active_expedition() -> bool:
	# Backward-compatible helper: complete the first in-progress slot.
	return complete_next_active_expedition()


func complete_next_active_expedition() -> bool:
	_update_runtime_status()
	for slot_index in range(MAX_ACTIVE_SLOTS):
		var slot_data := _active_expeditions[slot_index]
		if str(slot_data.get("status", STATUS_IDLE)) != STATUS_IN_PROGRESS:
			continue
		return _complete_slot(slot_index)
	return false


func complete_all_active_expeditions_for_debug() -> int:
	# Debug-complete behavior: finish all in-progress expeditions by calling the
	# same slot completion path used by natural timer completion.
	var completed_count := 0
	for slot_index in range(MAX_ACTIVE_SLOTS):
		var slot_data := _active_expeditions[slot_index]
		if str(slot_data.get("status", STATUS_IDLE)) != STATUS_IN_PROGRESS:
			continue
		if _complete_slot(slot_index):
			completed_count += 1
	return completed_count


func collect_pending_report() -> Dictionary:
	# Report collection flow: collect queue head only, then clear that slot.
	if _pending_reports.is_empty():
		return {}
	var head_report := _pending_reports[0]
	if bool(head_report.get("collected", false)):
		return {}

	var rewards: Dictionary = (head_report.get("rewards", {}) as Dictionary).duplicate(true)
	head_report["collected"] = true
	_pending_reports.remove_at(0)

	var slot_index := int(head_report.get("slot_index", -1))
	if slot_index >= 0 and slot_index < MAX_ACTIVE_SLOTS:
		_active_expeditions[slot_index] = {}
	return rewards


func get_pending_report() -> Dictionary:
	if _pending_reports.is_empty():
		return {}
	var report := _pending_reports[0].duplicate(true)
	report["queue_index"] = 0
	report["queue_total"] = _pending_reports.size()
	return report


func get_pending_reports() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for report in _pending_reports:
		snapshot.append(report.duplicate(true))
	return snapshot


func get_active_expedition() -> Dictionary:
	# Backward-compatible accessor for legacy callers. Returns first non-empty slot.
	_update_runtime_status()
	for slot_data in _active_expeditions:
		if slot_data.is_empty():
			continue
		return slot_data.duplicate(true)
	return {}


func get_active_expeditions() -> Array[Dictionary]:
	_update_runtime_status()
	var snapshot: Array[Dictionary] = []
	for slot_data in _active_expeditions:
		snapshot.append(slot_data.duplicate(true))
	return snapshot


func get_status_label() -> String:
	# Backward-compatible helper for legacy single-slot labels.
	_update_runtime_status()
	var first := get_active_expedition()
	if first.is_empty():
		return "No Active Expedition"
	return _to_status_label(str(first.get("status", STATUS_IDLE)))


func get_remaining_seconds() -> int:
	# Backward-compatible helper for legacy single-slot labels.
	_update_runtime_status()
	var first := get_active_expedition()
	if str(first.get("status", STATUS_IDLE)) != STATUS_IN_PROGRESS:
		return 0
	return _compute_remaining_seconds_for(first)


func get_remaining_time_text() -> String:
	var remaining := get_remaining_seconds()
	if remaining <= 0:
		return "00:00"

	# Avoid integer-division warnings during script reload.
	var minutes := int(remaining / 60.0)
	var seconds := remaining % 60
	return "%02d:%02d" % [minutes, seconds]


func get_remaining_time_text_for_slot(slot_index: int) -> String:
	var remaining := get_remaining_seconds_for_slot(slot_index)
	if remaining <= 0:
		return "00:00"
	var minutes := int(remaining / 60.0)
	var seconds := remaining % 60
	return "%02d:%02d" % [minutes, seconds]


func get_remaining_seconds_for_slot(slot_index: int) -> int:
	_update_runtime_status()
	if slot_index < 0 or slot_index >= MAX_ACTIVE_SLOTS:
		return 0
	var slot_data := _active_expeditions[slot_index]
	if str(slot_data.get("status", STATUS_IDLE)) != STATUS_IN_PROGRESS:
		return 0
	return _compute_remaining_seconds_for(slot_data)


func get_dispatch_block_message() -> String:
	_update_runtime_status()
	if can_start_expedition():
		return ""
	return "Dispatch blocked: both expedition slots are full."


func _compute_remaining_seconds_for(expedition_data: Dictionary) -> int:
	var now_unix := Time.get_unix_time_from_system()
	var expected_finish := int(expedition_data.get("expected_finish_time", now_unix))
	return max(0, expected_finish - now_unix)


func _update_runtime_status() -> void:
	# Timer completion path: each slot checks independently.
	for slot_index in range(MAX_ACTIVE_SLOTS):
		var slot_data := _active_expeditions[slot_index]
		if slot_data.is_empty():
			continue
		if str(slot_data.get("status", STATUS_IDLE)) != STATUS_IN_PROGRESS:
			continue
		if _compute_remaining_seconds_for(slot_data) <= 0:
			_complete_slot(slot_index)


func restore_runtime_state(active_expeditions: Variant, pending_reports: Variant) -> void:
	# Save/load restore behavior: sanitize each slot and each queued report.
	_active_expeditions = [{}, {}]
	_pending_reports = []

	# Backward compatibility: accept old single-dictionary fields.
	if active_expeditions is Dictionary:
		var legacy_active := active_expeditions as Dictionary
		if _is_valid_active_expedition(legacy_active):
			legacy_active["slot_index"] = 0
			_active_expeditions[0] = legacy_active.duplicate(true)
	elif active_expeditions is Array:
		var source_slots: Array = active_expeditions as Array
		for slot_index in range(min(MAX_ACTIVE_SLOTS, source_slots.size())):
			if not (source_slots[slot_index] is Dictionary):
				continue
			var slot_data := (source_slots[slot_index] as Dictionary).duplicate(true)
			if slot_data.is_empty():
				continue
			if not _is_valid_active_expedition(slot_data):
				continue
			slot_data["slot_index"] = slot_index
			_active_expeditions[slot_index] = slot_data

	if pending_reports is Dictionary:
		var legacy_report := pending_reports as Dictionary
		if _is_valid_pending_report(legacy_report):
			_pending_reports.append(legacy_report.duplicate(true))
	elif pending_reports is Array:
		for item in (pending_reports as Array):
			if not (item is Dictionary):
				continue
			var report := (item as Dictionary).duplicate(true)
			if not _is_valid_pending_report(report):
				continue
			_pending_reports.append(report)

	# Ensure each report has a safe slot index so collect can clear correct slot.
	for report_index in range(_pending_reports.size()):
		var report := _pending_reports[report_index]
		var slot_index := int(report.get("slot_index", -1))
		if slot_index < 0 or slot_index >= MAX_ACTIVE_SLOTS:
			var guessed_slot := _find_slot_index_for_report(report)
			report["slot_index"] = guessed_slot
		_pending_reports[report_index] = report


func _is_valid_active_expedition(data: Dictionary) -> bool:
	if str(data.get("id", "")).is_empty():
		return false
	if int(data.get("expected_finish_time", 0)) <= 0:
		return false
	var status := str(data.get("status", STATUS_IDLE))
	return status == STATUS_IN_PROGRESS or status == STATUS_COMPLETED


func _is_valid_pending_report(data: Dictionary) -> bool:
	if str(data.get("expedition_id", "")).is_empty():
		return false
	if not (data.get("rewards", {}) is Dictionary):
		return false
	# Restored reports must still be collectable; an already-collected report would
	# block dispatch forever because collect_pending_report() returns early.
	return not bool(data.get("collected", false))


func _find_first_free_slot_index() -> int:
	for slot_index in range(MAX_ACTIVE_SLOTS):
		if _active_expeditions[slot_index].is_empty():
			return slot_index
	return -1


func _complete_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= MAX_ACTIVE_SLOTS:
		return false
	var slot_data := _active_expeditions[slot_index]
	if slot_data.is_empty():
		return false
	if str(slot_data.get("status", STATUS_IDLE)) != STATUS_IN_PROGRESS:
		return false

	slot_data["status"] = STATUS_COMPLETED
	_active_expeditions[slot_index] = slot_data

	# Queueing completed reports: each completion appends one collectable report.
	var report := RewardSystem.create_report_for_expedition(slot_data)
	report["slot_index"] = slot_index
	_pending_reports.append(report)
	return true


func _to_status_label(status: String) -> String:
	match status:
		STATUS_IN_PROGRESS:
			return "In Progress"
		STATUS_COMPLETED:
			return "Completed (Report Queued)"
		_:
			return "Empty"


func _find_slot_index_for_report(report: Dictionary) -> int:
	var expedition_id := str(report.get("expedition_id", ""))
	for slot_index in range(MAX_ACTIVE_SLOTS):
		var slot_data := _active_expeditions[slot_index]
		if str(slot_data.get("id", "")) == expedition_id:
			return slot_index
	return -1
