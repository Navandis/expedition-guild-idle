extends RefCounted
class_name SupplyRunRuntimeManager

# -----------------------------------------------------------------------------
# SupplyRunRuntimeManager
# -----------------------------------------------------------------------------
# Purpose:
# - Own runtime state for live Supply Runs that are already dispatched.
# - Keep active timed entries separate from ready-to-claim entries.
#
# Why this exists separately from SupplyBoardController:
# - Supply Board rows are offers ("what can be accepted now").
# - Runtime rows are commitments ("what is already in progress/completed").
# Keeping them separate prevents board rerolls from destroying committed state
# and keeps save/load + offline completion handling explicit and safe.
#
# v1 completion payload rule:
# - Supply payout is pre-rolled at dispatch and stored on the runtime row.
# - Claim reads that stored payload directly; no second roll at claim time.
# -----------------------------------------------------------------------------

const DEFAULT_RUNTIME_STATE := {
	"active_entries": [],
	"ready_to_claim_entries": []
}
const DEFAULT_SUPPLIES_PAYOUT_MIN := 10
const DEFAULT_SUPPLIES_PAYOUT_MAX := 20

var _runtime_state: Dictionary = DEFAULT_RUNTIME_STATE.duplicate(true)
var _next_runtime_id: int = 1
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func build_runtime_snapshot() -> Dictionary:
	return {
		"active_entries": get_active_entries(),
		"ready_to_claim_entries": get_ready_to_claim_entries(),
		"next_runtime_id": _next_runtime_id
	}


func restore_runtime_snapshot(snapshot: Variant) -> void:
	var source := snapshot as Dictionary if snapshot is Dictionary else {}
	_runtime_state = {
		"active_entries": _sanitize_runtime_entries(source.get("active_entries", []), false),
		"ready_to_claim_entries": _sanitize_runtime_entries(source.get("ready_to_claim_entries", []), true)
	}
	_next_runtime_id = maxi(1, int(source.get("next_runtime_id", _derive_next_runtime_id())))


func get_active_entries() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry in _runtime_state.get("active_entries", []):
		rows.append((entry as Dictionary).duplicate(true))
	return rows


func get_ready_to_claim_entries() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry in _runtime_state.get("ready_to_claim_entries", []):
		rows.append((entry as Dictionary).duplicate(true))
	return rows


func get_active_slot_usage() -> int:
	# Slot occupancy is "dispatched but not yet fully cleared."
	# That includes in-progress rows and ready-to-claim rows.
	# A slot only frees after claim removes the ready entry.
	return get_active_entries().size() + get_ready_to_claim_entries().size()


func can_start_supply_run(current_slot_capacity: int) -> bool:
	return get_active_slot_usage() < maxi(0, current_slot_capacity)


func start_supply_run(offer_snapshot: Dictionary, current_slot_capacity: int, now_unix: int = -1) -> Dictionary:
	if not can_start_supply_run(current_slot_capacity):
		return {}

	var now: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var duration_seconds := _resolve_duration_seconds(offer_snapshot)
	var supplies_payout := _roll_supplies_payout(offer_snapshot)
	var runtime_id := _next_runtime_id
	_next_runtime_id += 1

	var row := {
		"runtime_id": runtime_id,
		"state": "active",
		"offer_id": str(offer_snapshot.get("offer_id", "")),
		"run_family_id": str(offer_snapshot.get("run_family_id", "")),
		"region_id": str(offer_snapshot.get("region_id", "")),
		"title": _resolve_title(offer_snapshot),
		"crew_committed": maxi(0, int(offer_snapshot.get("crew_required", 0))),
		"gold_paid_on_dispatch": maxi(0, int(offer_snapshot.get("gold_cost", 0))),
		"started_at_unix": now,
		"ready_at_unix": now + duration_seconds,
		"duration_seconds": duration_seconds,
		# Pre-rolled payload is stored now so claim can be deterministic after
		# save/load/offline progress and never depends on board state surviving.
		"completion_payload": {
			"supplies_payout": supplies_payout
		}
	}

	var active := get_active_entries()
	active.append(row)
	_runtime_state["active_entries"] = active
	return row.duplicate(true)


func process_time_progress(now_unix: int = -1) -> Array[Dictionary]:
	var now: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var active_remaining: Array[Dictionary] = []
	var ready_claimable := get_ready_to_claim_entries()
	var promoted_entries: Array[Dictionary] = []

	for entry in get_active_entries():
		if int(entry.get("ready_at_unix", 0)) <= now:
			# Active -> ready happens here as the timer boundary is crossed.
			# The row still occupies a slot while it waits for claim.
			# It leaves the active bucket, but still counts in slot usage because
			# get_active_slot_usage includes ready-to-claim entries too.
			var completed := entry.duplicate(true)
			completed["state"] = "ready_to_claim"
			completed["completed_at_unix"] = now
			completed["crew_return_applied"] = false
			ready_claimable.append(completed)
			promoted_entries.append(completed.duplicate(true))
		else:
			active_remaining.append(entry)

	_runtime_state["active_entries"] = active_remaining
	_runtime_state["ready_to_claim_entries"] = ready_claimable
	return promoted_entries


func debug_finish_all_active(now_unix: int = -1) -> Array[Dictionary]:
	var now: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var patched_active: Array[Dictionary] = []
	for entry in get_active_entries():
		var patched := entry.duplicate(true)
		patched["ready_at_unix"] = now
		patched_active.append(patched)
	_runtime_state["active_entries"] = patched_active
	return process_time_progress(now)


func claim_ready_entry(runtime_id: int) -> Dictionary:
	var remaining: Array[Dictionary] = []
	var claimed: Dictionary = {}
	for row in get_ready_to_claim_entries():
		if claimed.is_empty() and int(row.get("runtime_id", 0)) == runtime_id:
			claimed = row.duplicate(true)
			continue
		remaining.append(row)
	_runtime_state["ready_to_claim_entries"] = remaining
	return claimed


func mark_ready_entries_crew_return_applied(runtime_ids: Array[int]) -> void:
	if runtime_ids.is_empty():
		return
	var lookup: Dictionary = {}
	for runtime_id in runtime_ids:
		lookup[runtime_id] = true
	var updated: Array[Dictionary] = []
	for row in get_ready_to_claim_entries():
		var patched := row.duplicate(true)
		var runtime_id := int(patched.get("runtime_id", 0))
		if bool(lookup.get(runtime_id, false)):
			patched["crew_return_applied"] = true
		updated.append(patched)
	_runtime_state["ready_to_claim_entries"] = updated


func _sanitize_runtime_entries(entries: Variant, ready_bucket: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not (entries is Array):
		return rows

	for raw in entries:
		if not (raw is Dictionary):
			continue
		var row := raw as Dictionary
		var runtime_id := maxi(1, int(row.get("runtime_id", 0)))
		var started_at := maxi(0, int(row.get("started_at_unix", 0)))
		var ready_at := maxi(started_at, int(row.get("ready_at_unix", started_at)))
		var completion_payload := row.get("completion_payload", {}) as Dictionary
		var payout := maxi(0, int(completion_payload.get("supplies_payout", 0)))
		rows.append({
			"runtime_id": runtime_id,
			"state": "ready_to_claim" if ready_bucket else "active",
			"offer_id": str(row.get("offer_id", "")),
			"run_family_id": str(row.get("run_family_id", "")),
			"region_id": str(row.get("region_id", "")),
			"title": _resolve_title(row),
			"crew_committed": maxi(0, int(row.get("crew_committed", 0))),
			"gold_paid_on_dispatch": maxi(0, int(row.get("gold_paid_on_dispatch", 0))),
			"started_at_unix": started_at,
			"ready_at_unix": ready_at,
			"duration_seconds": maxi(30, int(row.get("duration_seconds", ready_at - started_at))),
			"completed_at_unix": maxi(0, int(row.get("completed_at_unix", 0))),
			"crew_return_applied": bool(row.get("crew_return_applied", false)),
			"completion_payload": {
				"supplies_payout": payout
			}
		})
	return rows


func _derive_next_runtime_id() -> int:
	var max_id := 0
	for row in get_active_entries():
		max_id = maxi(max_id, int(row.get("runtime_id", 0)))
	for row in get_ready_to_claim_entries():
		max_id = maxi(max_id, int(row.get("runtime_id", 0)))
	return max_id + 1


func _resolve_duration_seconds(offer_snapshot: Dictionary) -> int:
	var minutes := maxi(0, int(offer_snapshot.get("duration_minutes", 0)))
	if minutes <= 0:
		minutes = 20
	return maxi(30, minutes * 60)


func _roll_supplies_payout(offer_snapshot: Dictionary) -> int:
	# Dispatch stores final payout immediately so completion/claim remains a
	# simple transfer with no extra random roll during claim.
	var estimate := maxi(0, int(offer_snapshot.get("supplies_yield_estimate", 0)))
	if estimate > 0:
		return estimate
	return _rng.randi_range(DEFAULT_SUPPLIES_PAYOUT_MIN, DEFAULT_SUPPLIES_PAYOUT_MAX)


func _resolve_title(row: Dictionary) -> String:
	var title := str(row.get("title", "")).strip_edges()
	if not title.is_empty():
		return title
	title = str(row.get("brief", "")).strip_edges()
	if not title.is_empty():
		return title
	return "Supply Run"
