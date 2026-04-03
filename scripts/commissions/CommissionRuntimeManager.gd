extends RefCounted
class_name CommissionRuntimeManager

# -----------------------------------------------------------------------------
# CommissionRuntimeManager
# -----------------------------------------------------------------------------
# Purpose:
# - Own runtime state for dispatched commissions that are still in progress.
# - Move finished runs into a separate ready-to-claim bucket.
#
# Why this is separate from board offers:
# - Commission board offers are "what can be accepted right now".
# - Active/claimable entries are "what the player already committed to".
# Keeping these states separate avoids overwriting committed runtime data when the
# offer board rerolls and keeps save/load behavior predictable.
#
# Runtime shape summary:
# - active_entries: dispatched rows currently consuming commission slots.
# - ready_to_claim_entries: finished rows waiting for a future claim action.
#
# Each row keeps explicit, save-friendly fields so later offline completion and
# claim UI can be added without redesigning authored commission JSON.
# -----------------------------------------------------------------------------

const DEFAULT_RUNTIME_STATE := {
	"active_entries": [],
	"ready_to_claim_entries": []
}

var _runtime_state: Dictionary = DEFAULT_RUNTIME_STATE.duplicate(true)
var _next_runtime_id: int = 1


func build_runtime_snapshot() -> Dictionary:
	# Save-safe deep copy for persistence.
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
	return get_active_entries().size()


func can_start_commission(current_slot_capacity: int) -> bool:
	return get_active_slot_usage() < maxi(0, current_slot_capacity)


func start_commission(
	offer_snapshot: Dictionary,
	prep_tier_id: String,
	commitment: Dictionary,
	completion_payload: Dictionary,
	current_slot_capacity: int,
	now_unix: int = -1
) -> Dictionary:
	# Active-slot limit uses progression-owned commission slot capacity.
	if not can_start_commission(current_slot_capacity):
		return {}

	var now: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var duration_seconds := _resolve_duration_seconds(offer_snapshot)
	var runtime_id := _next_runtime_id
	_next_runtime_id += 1

	var row := {
		"runtime_id": runtime_id,
		"state": "active",
		"offer_id": str(offer_snapshot.get("offer_id", "")),
		"patron_id": str(offer_snapshot.get("patron_id", "")),
		"family_id": str(offer_snapshot.get("family_id", "")),
		"region_id": str(offer_snapshot.get("region_id", "")),
		"title": str(offer_snapshot.get("title", "Commission")),
		"brief": str(offer_snapshot.get("brief", "")),
		"prep_tier_id": prep_tier_id.strip_edges(),
		"crew_committed": maxi(0, int(commitment.get("crew_commitment", 0))),
		"supplies_committed": maxi(0, int(commitment.get("supplies_commitment", 0))),
		"started_at_unix": now,
		"ready_at_unix": now + duration_seconds,
		"duration_seconds": duration_seconds,
		# Completion payload is pre-rolled on dispatch so claim can be deterministic
		# even after app restarts/offline time.
		"completion_payload": completion_payload.duplicate(true)
	}

	var active := get_active_entries()
	active.append(row)
	_runtime_state["active_entries"] = active
	return row.duplicate(true)


func process_time_progress(now_unix: int = -1) -> Array[Dictionary]:
	# Promote finished active entries into ready-to-claim entries.
	# Returns promoted rows so caller systems can run completion side-effects
	# (for example crew transitions) exactly when active -> claimable happens.
	var now: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var active_remaining: Array[Dictionary] = []
	var ready_claimable := get_ready_to_claim_entries()
	var promoted_entries: Array[Dictionary] = []

	for entry in get_active_entries():
		if int(entry.get("ready_at_unix", 0)) <= now:
			var completed := entry.duplicate(true)
			completed["state"] = "ready_to_claim"
			completed["completed_at_unix"] = now
			ready_claimable.append(completed)
			promoted_entries.append(completed.duplicate(true))
		else:
			active_remaining.append(entry)

	_runtime_state["active_entries"] = active_remaining
	_runtime_state["ready_to_claim_entries"] = ready_claimable
	return promoted_entries


func debug_finish_all_active(now_unix: int = -1) -> Array[Dictionary]:
	# Debug helper mirrors expedition debug-finish behavior:
	# force all active commissions to complete through the same promotion logic.
	var now: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var patched_active: Array[Dictionary] = []
	for entry in get_active_entries():
		var patched := entry.duplicate(true)
		patched["ready_at_unix"] = now
		patched_active.append(patched)
	_runtime_state["active_entries"] = patched_active
	return process_time_progress(now)




func claim_ready_entry(runtime_id: int) -> Dictionary:
	# Claim flow endpoint for the next milestone.
	# Removes one ready row and returns it to callers so they can apply rewards.
	var remaining: Array[Dictionary] = []
	var claimed: Dictionary = {}
	for row in get_ready_to_claim_entries():
		if claimed.is_empty() and int(row.get("runtime_id", 0)) == runtime_id:
			claimed = row.duplicate(true)
			continue
		remaining.append(row)
	_runtime_state["ready_to_claim_entries"] = remaining
	return claimed


func _sanitize_runtime_entries(entries: Variant, ready_bucket: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not (entries is Array):
		return rows

	for raw in entries:
		if not (raw is Dictionary):
			continue
		var row := raw as Dictionary
		var runtime_id := maxi(1, int(row.get("runtime_id", 0)))
		var state := "ready_to_claim" if ready_bucket else "active"
		var started_at := maxi(0, int(row.get("started_at_unix", 0)))
		var ready_at := maxi(started_at, int(row.get("ready_at_unix", started_at)))
		var completion_payload := row.get("completion_payload", {}) as Dictionary
		rows.append({
			"runtime_id": runtime_id,
			"state": state,
			"offer_id": str(row.get("offer_id", "")),
			"patron_id": str(row.get("patron_id", "")),
			"family_id": str(row.get("family_id", "")),
			"region_id": str(row.get("region_id", "")),
			"title": str(row.get("title", "Commission")),
			"brief": str(row.get("brief", "")),
			"prep_tier_id": str(row.get("prep_tier_id", "")),
			"crew_committed": maxi(0, int(row.get("crew_committed", 0))),
			"supplies_committed": maxi(0, int(row.get("supplies_committed", 0))),
			"started_at_unix": started_at,
			"ready_at_unix": ready_at,
			"duration_seconds": maxi(30, int(row.get("duration_seconds", ready_at - started_at))),
			"completed_at_unix": maxi(0, int(row.get("completed_at_unix", 0))),
			"completion_payload": completion_payload.duplicate(true)
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
	# Prefer explicit minutes from the offer. Fallback to hours when needed.
	var minutes := maxi(0, int(offer_snapshot.get("duration_minutes", 0)))
	if minutes <= 0:
		minutes = maxi(1, int(offer_snapshot.get("duration_hours", 1)) * 60)
	return maxi(30, minutes * 60)
