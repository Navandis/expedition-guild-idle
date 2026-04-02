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
	# Basic standing/reputation scaffold for future reputation systems.
	"standing": 0,
	# Recovery tracking list for future offline/passive processing.
	# Each row shape:
	# { "crew": int, "ready_at_unix": int, "started_at_unix": int, "source": String }
	"crew_recovery_entries": []
}

var _runtime_state: Dictionary = DEFAULT_RUNTIME_STATE.duplicate(true)

# Outcome bands for v1 commission completion.
const OUTCOME_EXCELLENT := "excellent"
const OUTCOME_SOLID := "solid"
const OUTCOME_STRAINED := "strained"
const OUTCOME_POOR := "poor"

# Tunable thresholds and multipliers live in one place so balancing can happen
# later without touching UI scripts or authored JSON.
const OUTCOME_SCORE_THRESHOLDS := {
	OUTCOME_EXCELLENT: 0.82,
	OUTCOME_SOLID: 0.58,
	OUTCOME_STRAINED: 0.32
}
const OUTCOME_GOLD_MULTIPLIERS := {
	OUTCOME_EXCELLENT: 1.30,
	OUTCOME_SOLID: 1.00,
	OUTCOME_STRAINED: 0.70,
	OUTCOME_POOR: 0.40
}
const OUTCOME_STANDING_DELTA := {
	OUTCOME_EXCELLENT: 2,
	OUTCOME_SOLID: 1,
	OUTCOME_STRAINED: 0,
	OUTCOME_POOR: -1
}
const OUTCOME_SIDE_REWARD_CHANCE := {
	OUTCOME_EXCELLENT: 0.30,
	OUTCOME_SOLID: 0.16,
	OUTCOME_STRAINED: 0.08,
	OUTCOME_POOR: 0.03
}
const OUTCOME_RECOVERY_MULTIPLIERS := {
	OUTCOME_EXCELLENT: 0.75,
	OUTCOME_SOLID: 1.0,
	OUTCOME_STRAINED: 1.2,
	OUTCOME_POOR: 1.45
}


func build_runtime_snapshot() -> Dictionary:
	# Save-safe deep copy for persistence. This contains only player/runtime data.
	return _runtime_state.duplicate(true)


func restore_runtime_snapshot(snapshot: Variant) -> void:
	# Load-safe sanitize path. Missing keys fall back to defaults.
	var source := snapshot as Dictionary if snapshot is Dictionary else {}
	# Optional flag for authored new-game baselines that intentionally start
	# below max crew availability (for early-game pacing/balance).
	var preserve_sparse_crew_state := bool(source.get("preserve_sparse_crew_state", false))
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
		"standing": int(source.get("standing", int(DEFAULT_RUNTIME_STATE.get("standing", 0)))),
		"crew_recovery_entries": _sanitize_recovery_entries(source.get("crew_recovery_entries", []))
	}
	_runtime_state = _normalize_crew_state(state, preserve_sparse_crew_state)


func resolve_commission_completion(offer: Dictionary, prep_tier_id: String, commitment: Dictionary) -> Dictionary:
	# Runtime resolution is intentionally separate from authored commission files.
	# Offer data is read as input, while output values are computed per-run.
	var crew_committed := maxi(0, int(commitment.get("crew_commitment", 0)))
	var prep_modifier := clampf(float(commitment.get("success_weight_modifier", 0.0)), -0.50, 0.50)
	var base_score := _build_base_outcome_score(offer, prep_tier_id)
	var swing := randf_range(-0.16, 0.16)
	var final_score := clampf(base_score + prep_modifier + swing, 0.0, 1.0)
	var outcome_band := _resolve_outcome_band_from_score(final_score)

	# Gold payout is the primary reward channel and scales by outcome band.
	var base_gold := _resolve_base_gold(offer)
	var gold_payout := maxi(0, int(round(float(base_gold) * float(OUTCOME_GOLD_MULTIPLIERS.get(outcome_band, 1.0)))))

	# First-pass standing scaffold: tiny deltas only, so it is safe to keep simple.
	var standing_delta := int(OUTCOME_STANDING_DELTA.get(outcome_band, 0))
	_runtime_state["standing"] = int(_runtime_state.get("standing", 0)) + standing_delta

	# Crew leaves the assigned pool and enters Recovering on completion.
	var recovery_seconds := _resolve_recovery_seconds(offer, outcome_band)
	move_assigned_crew_to_recovering(crew_committed, recovery_seconds, "commission_%s" % outcome_band)

	# Optional side reward chance: small bonus supplies grant to keep v1 light.
	var side_reward := _roll_side_reward(offer, outcome_band)
	if not side_reward.is_empty():
		add_supplies(int(side_reward.get("amount", 0)))

	return {
		"outcome_band": outcome_band,
		"outcome_label": _to_outcome_label(outcome_band),
		"outcome_score": final_score,
		"gold_payout": gold_payout,
		"standing_delta": standing_delta,
		"crew_to_recovering": crew_committed,
		"recovery_seconds": recovery_seconds,
		"side_reward": side_reward,
		"summary": _build_outcome_summary(outcome_band, gold_payout, recovery_seconds)
	}


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


func get_standing() -> int:
	return int(_runtime_state.get("standing", 0))


func _build_base_outcome_score(offer: Dictionary, prep_tier_id: String) -> float:
	# Risk band provides the primary baseline: higher risk starts slightly lower.
	var risk_band := str(offer.get("risk_band", "moderate")).to_lower()
	var risk_base := 0.58
	match risk_band:
		"low":
			risk_base = 0.68
		"high":
			risk_base = 0.48
		_:
			risk_base = 0.58

	# Prep tier contributes a small deterministic nudge for readability in v1.
	var prep_nudge := 0.0
	match prep_tier_id.strip_edges().to_lower():
		"quick":
			prep_nudge = -0.06
		"prepared":
			prep_nudge = 0.0
		"meticulous":
			prep_nudge = 0.06
		_:
			prep_nudge = 0.0

	return clampf(risk_base + prep_nudge, 0.0, 1.0)


func _resolve_outcome_band_from_score(score: float) -> String:
	if score >= float(OUTCOME_SCORE_THRESHOLDS.get(OUTCOME_EXCELLENT, 0.82)):
		return OUTCOME_EXCELLENT
	if score >= float(OUTCOME_SCORE_THRESHOLDS.get(OUTCOME_SOLID, 0.58)):
		return OUTCOME_SOLID
	if score >= float(OUTCOME_SCORE_THRESHOLDS.get(OUTCOME_STRAINED, 0.32)):
		return OUTCOME_STRAINED
	return OUTCOME_POOR


func _resolve_base_gold(offer: Dictionary) -> int:
	var reward_scaffold := offer.get("reward_scaffold", {}) as Dictionary
	var authored_base := maxi(0, int(reward_scaffold.get("base_gold", 0)))
	var authored_estimate := maxi(0, int(reward_scaffold.get("estimated_gold", 0)))
	if authored_base > 0:
		return authored_base
	if authored_estimate > 0:
		return authored_estimate
	# Fallback keeps payout available even if scaffold keys are omitted.
	return 20 + (maxi(1, int(offer.get("duration_hours", 1))) * 14)


func _resolve_recovery_seconds(offer: Dictionary, outcome_band: String) -> int:
	var base_minutes := maxi(1, int(offer.get("duration_minutes", 0)))
	if base_minutes <= 1 and offer.has("duration_hours"):
		base_minutes = maxi(1, int(offer.get("duration_hours", 1)) * 60)
	var base_seconds := base_minutes * 60
	var multiplier := float(OUTCOME_RECOVERY_MULTIPLIERS.get(outcome_band, 1.0))
	return maxi(30, int(round(float(base_seconds) * multiplier)))


func _roll_side_reward(offer: Dictionary, outcome_band: String) -> Dictionary:
	var chance := clampf(float(OUTCOME_SIDE_REWARD_CHANCE.get(outcome_band, 0.0)), 0.0, 1.0)
	if randf() > chance:
		return {}
	var base_supplies := maxi(1, int(offer.get("supplies_required", 1)))
	var amount := maxi(1, int(round(float(base_supplies) * 0.35)))
	return {
		"type": "supplies",
		"amount": amount,
		"label": "+%d Supplies found during completion." % amount
	}


func _to_outcome_label(outcome_band: String) -> String:
	match outcome_band:
		OUTCOME_EXCELLENT:
			return "Excellent"
		OUTCOME_SOLID:
			return "Solid"
		OUTCOME_STRAINED:
			return "Strained"
		_:
			return "Poor"


func _build_outcome_summary(outcome_band: String, gold_payout: int, recovery_seconds: int) -> String:
	var recovery_minutes := maxi(1, int(round(float(recovery_seconds) / 60.0)))
	match outcome_band:
		OUTCOME_EXCELLENT:
			return "Excellent outcome: earned %d gold with quick crew recovery (~%d min)." % [gold_payout, recovery_minutes]
		OUTCOME_SOLID:
			return "Solid outcome: earned %d gold. Crew is recovering (~%d min)." % [gold_payout, recovery_minutes]
		OUTCOME_STRAINED:
			return "Strained outcome: reduced payout (%d gold) and longer recovery (~%d min)." % [gold_payout, recovery_minutes]
		_:
			return "Poor outcome: low payout (%d gold) and heavy recovery burden (~%d min)." % [gold_payout, recovery_minutes]


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


func _normalize_crew_state(state: Dictionary, preserve_sparse_crew_state: bool = false) -> Dictionary:
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
	if total < max_crew and not preserve_sparse_crew_state:
		# Fill idle gap so crew pools always account for max_crew.
		available += (max_crew - total)

	normalized["max_crew"] = max_crew
	normalized["assigned_crew"] = assigned
	normalized["recovering_crew"] = recovering
	normalized["available_crew"] = available
	normalized["supplies"] = maxi(0, int(normalized.get("supplies", 0)))
	normalized["standing"] = int(normalized.get("standing", 0))
	return normalized
