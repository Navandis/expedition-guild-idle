extends Node
class_name CommissionResolver

# -----------------------------------------------------------------------------
# CommissionResolver
# -----------------------------------------------------------------------------
# Purpose:
# - Own runtime commission-operation resources that belong to the player state.
# - Keep Crew and Supplies separate from authored JSON in res://data/commissions/.
#
# Why this lives here:
# - Commission authored files define templates/rules only.
# - Crew/Supplies are mutable runtime values, so they must be save data.
#
# Crew model summary:
# - max_crew: hard cap for the current account/profile.
# - available_crew: idle pool ready to assign to commissions.
# - assigned_crew: currently reserved by in-progress commissions.
# - recovering_crew: temporarily unavailable and expected to return later.
#
# This model treats crew as a recoverable operational pool (not permanently
# consumed), which cleanly supports passive, offline, and accelerated recovery.
# -----------------------------------------------------------------------------

const DEFAULT_RUNTIME_STATE := {
	# Crew v1 defaults
	"max_crew": 10,
	"available_crew": 10,
	"assigned_crew": 0,
	"recovering_crew": 0,
	# Supplies v1 intentionally stays as one single resource bucket.
	"supplies": 50,
	# Recovery tracking list for future offline/passive processing.
	# Each row shape:
	# { "crew": int, "ready_at_unix": int, "started_at_unix": int, "source": String }
	"crew_recovery_entries": []
}

var _runtime_state: Dictionary = DEFAULT_RUNTIME_STATE.duplicate(true)


func build_runtime_snapshot() -> Dictionary:
	# Save-safe deep copy for persistence. This contains only player/runtime data.
	return _runtime_state.duplicate(true)


func restore_runtime_snapshot(snapshot: Variant) -> void:
	# Load-safe sanitize path. Missing keys fall back to defaults.
	var source := snapshot as Dictionary if snapshot is Dictionary else {}
	var max_crew := maxi(0, int(source.get("max_crew", int(DEFAULT_RUNTIME_STATE.get("max_crew", 10)))))
	var assigned_crew := maxi(0, int(source.get("assigned_crew", 0)))
	var recovering_crew := maxi(0, int(source.get("recovering_crew", 0)))
	var supplies := maxi(0, int(source.get("supplies", int(DEFAULT_RUNTIME_STATE.get("supplies", 0)))))
	var available_crew := maxi(0, int(source.get("available_crew", max_crew - assigned_crew - recovering_crew)))

	var state := {
		"max_crew": max_crew,
		"available_crew": available_crew,
		"assigned_crew": assigned_crew,
		"recovering_crew": recovering_crew,
		"supplies": supplies,
		"crew_recovery_entries": _sanitize_recovery_entries(source.get("crew_recovery_entries", []))
	}
	_runtime_state = _normalize_crew_state(state)


func assign_crew_to_commission(crew_amount: int) -> bool:
	# Reserve crew into assigned pool when a commission starts.
	var amount := maxi(0, crew_amount)
	if amount == 0:
		return true
	if amount > get_available_crew():
		return false
	_runtime_state["assigned_crew"] = get_assigned_crew() + amount
	_runtime_state = _normalize_crew_state(_runtime_state)
	return true


func move_assigned_crew_to_recovering(crew_amount: int, recovery_seconds: int, source_tag: String = "commission_complete") -> bool:
	# Crew is not consumed on completion; it enters recovering then returns.
	var amount := maxi(0, crew_amount)
	if amount == 0:
		return true
	if amount > get_assigned_crew():
		return false

	var now := Time.get_unix_time_from_system()
	var seconds := maxi(0, recovery_seconds)
	_runtime_state["assigned_crew"] = get_assigned_crew() - amount
	_runtime_state["recovering_crew"] = get_recovering_crew() + amount

	var entries := _runtime_state.get("crew_recovery_entries", []) as Array
	entries.append({
		"crew": amount,
		"ready_at_unix": now + seconds,
		"started_at_unix": now,
		"source": source_tag
	})
	_runtime_state["crew_recovery_entries"] = entries
	_runtime_state = _normalize_crew_state(_runtime_state)
	return true


func process_crew_recovery(now_unix: int = -1) -> int:
	# Passive/offline-ready endpoint:
	# - Call during runtime ticks for passive recovery.
	# - Call on app launch/load to capture offline elapsed time.
	var now: int = now_unix if now_unix >= 0 else Time.get_unix_time_from_system()
	var entries := _runtime_state.get("crew_recovery_entries", []) as Array
	var remaining_entries: Array[Dictionary] = []
	var recovered_total := 0
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var row := entry as Dictionary
		var ready_at := int(row.get("ready_at_unix", 0))
		var crew := maxi(0, int(row.get("crew", 0)))
		if crew <= 0:
			continue
		if ready_at <= now:
			recovered_total += crew
		else:
			remaining_entries.append({
				"crew": crew,
				"ready_at_unix": ready_at,
				"started_at_unix": int(row.get("started_at_unix", now)),
				"source": str(row.get("source", "commission_complete"))
			})

	if recovered_total > 0:
		_runtime_state["recovering_crew"] = maxi(0, get_recovering_crew() - recovered_total)
		_runtime_state["available_crew"] = get_available_crew() + recovered_total

	_runtime_state["crew_recovery_entries"] = remaining_entries
	_runtime_state = _normalize_crew_state(_runtime_state)
	return recovered_total


func spend_supplies(amount: int) -> bool:
	# Supplies v1 is one global number (no typed categories yet).
	var spend := maxi(0, amount)
	if spend == 0:
		return true
	if spend > get_supplies():
		return false
	_runtime_state["supplies"] = get_supplies() - spend
	return true


func add_supplies(amount: int) -> void:
	_runtime_state["supplies"] = maxi(0, get_supplies() + maxi(0, amount))


func get_max_crew() -> int:
	return int(_runtime_state.get("max_crew", 0))


func get_available_crew() -> int:
	return int(_runtime_state.get("available_crew", 0))


func get_assigned_crew() -> int:
	return int(_runtime_state.get("assigned_crew", 0))


func get_recovering_crew() -> int:
	return int(_runtime_state.get("recovering_crew", 0))


func get_supplies() -> int:
	return int(_runtime_state.get("supplies", 0))


func _sanitize_recovery_entries(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not (value is Array):
		return output

	for item in value:
		if not (item is Dictionary):
			continue
		var row := item as Dictionary
		var crew := maxi(0, int(row.get("crew", 0)))
		if crew <= 0:
			continue
		output.append({
			"crew": crew,
			"ready_at_unix": maxi(0, int(row.get("ready_at_unix", 0))),
			"started_at_unix": maxi(0, int(row.get("started_at_unix", 0))),
			"source": str(row.get("source", "commission_complete"))
		})
	return output


func _normalize_crew_state(state: Dictionary) -> Dictionary:
	# Keep pools coherent so later systems can trust this shape.
	var normalized := state.duplicate(true)
	var max_crew := maxi(0, int(normalized.get("max_crew", 0)))
	var assigned := maxi(0, int(normalized.get("assigned_crew", 0)))
	var recovering := maxi(0, int(normalized.get("recovering_crew", 0)))
	var available := maxi(0, int(normalized.get("available_crew", 0)))
	var total := assigned + recovering + available

	# Clamp overflow to max first from available, then recovering, then assigned.
	if total > max_crew:
		var overflow := total - max_crew
		var reduce_from_available := mini(overflow, available)
		available -= reduce_from_available
		overflow -= reduce_from_available
		if overflow > 0:
			var reduce_from_recovering := mini(overflow, recovering)
			recovering -= reduce_from_recovering
			overflow -= reduce_from_recovering
		if overflow > 0:
			assigned = maxi(0, assigned - overflow)

	total = assigned + recovering + available
	if total < max_crew:
		# Fill idle gap so crew pools always account for max_crew.
		available += (max_crew - total)

	normalized["max_crew"] = max_crew
	normalized["assigned_crew"] = assigned
	normalized["recovering_crew"] = recovering
	normalized["available_crew"] = available
	normalized["supplies"] = maxi(0, int(normalized.get("supplies", 0)))
	return normalized
