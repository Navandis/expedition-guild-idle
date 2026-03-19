extends RefCounted
class_name RewardSystem

# RewardSystem resolves expedition outcomes and builds report payloads.
# The formulas are intentionally simple for this milestone so the gameplay
# loop is easy to follow and tweak while features are still minimal.
# For day-3 progression, this includes tiny upgrade-aware modifiers for
# success chance and gold rewards.
# It now also forwards minimal expedition identity data so Codex discovery
# tracking can be recorded when players collect finished reports.

const OUTCOME_SUCCESS := "success"
const OUTCOME_PARTIAL_SUCCESS := "partial_success"
const OUTCOME_FAILURE := "failure"


static func create_report_for_expedition(expedition: Dictionary) -> Dictionary:
	var outcome := _roll_outcome(expedition)
	var rewards := _build_rewards(expedition, outcome)

	return {
		"expedition_id": str(expedition.get("id", "")),
		"expedition_display_name": str(expedition.get("display_name", "Unknown Expedition")),
		"site_type": str(expedition.get("site_type", "unknown_site")),
		"outcome": outcome,
		"outcome_label": _to_outcome_label(outcome),
		"rewards": rewards,
		"summary": _build_summary(expedition, outcome),
		"collected": false
	}


static func _roll_outcome(expedition: Dictionary) -> String:
	# Expedition carries an explicit base_success value that may already include
	# upgrade bonuses. Split the remaining probability between partial success and
	# failure so higher tiers still keep meaningful failure risk.
	var success_chance := clampf(float(expedition.get("base_success", 0.50)), 0.05, 0.95)
	var remaining_probability := 1.0 - success_chance
	var partial_cutoff := success_chance + (remaining_probability * 0.50)
	var roll := randf()

	if roll <= success_chance:
		return OUTCOME_SUCCESS
	if roll <= partial_cutoff:
		return OUTCOME_PARTIAL_SUCCESS
	return OUTCOME_FAILURE


static func _build_rewards(expedition: Dictionary, outcome: String) -> Dictionary:
	var duration_minutes: int = int(max(1, int(expedition.get("duration_minutes", 1))))
	var base_gold: int = 20 + (duration_minutes * 4)
	# UpgradeSystem can increase gold with a small multiplier applied here.
	var gold_multiplier: float = maxf(0.20, float(expedition.get("gold_multiplier", 1.0)))
	base_gold = int(round(base_gold * gold_multiplier))

	match outcome:
		OUTCOME_SUCCESS:
			return {
				"gold": base_gold,
				"relic_fragments": 2,
				"codex_entries": 1
			}
		OUTCOME_PARTIAL_SUCCESS:
			return {
				"gold": int(base_gold * 0.55),
				"relic_fragments": 1,
				"codex_entries": 0
			}
		_:
			return {
				"gold": int(base_gold * 0.2),
				"relic_fragments": 0,
				"codex_entries": 0
			}


static func _to_outcome_label(outcome: String) -> String:
	match outcome:
		OUTCOME_SUCCESS:
			return "Success"
		OUTCOME_PARTIAL_SUCCESS:
			return "Partial Success"
		_:
			return "Failure"


static func _build_summary(expedition: Dictionary, outcome: String) -> String:
	var name := str(expedition.get("display_name", "The expedition"))
	match outcome:
		OUTCOME_SUCCESS:
			return "%s returned with strong findings and minimal losses." % name
		OUTCOME_PARTIAL_SUCCESS:
			return "%s returned, but difficult conditions reduced the haul." % name
		_:
			return "%s failed to secure major gains this time." % name
