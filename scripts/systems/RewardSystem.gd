extends RefCounted
class_name RewardSystem

# RewardSystem resolves expedition outcomes and builds report payloads.
# The formulas are intentionally simple for this milestone so the gameplay
# loop is easy to follow and tweak while features are still minimal.

const OUTCOME_SUCCESS := "success"
const OUTCOME_PARTIAL_SUCCESS := "partial_success"
const OUTCOME_FAILURE := "failure"


static func create_report_for_expedition(expedition: Dictionary) -> Dictionary:
	var outcome := _roll_outcome(expedition)
	var rewards := _build_rewards(expedition, outcome)

	return {
		"expedition_id": str(expedition.get("id", "")),
		"expedition_display_name": str(expedition.get("display_name", "Unknown Expedition")),
		"outcome": outcome,
		"outcome_label": _to_outcome_label(outcome),
		"rewards": rewards,
		"summary": _build_summary(expedition, outcome),
		"collected": false
	}


static func _roll_outcome(expedition: Dictionary) -> String:
	# Risk is currently simple text. We map that label to easy-to-read odds.
	var risk_label := str(expedition.get("risk_label", "")).to_lower()
	var roll := randi_range(1, 100)

	if risk_label == "low":
		if roll <= 70:
			return OUTCOME_SUCCESS
		if roll <= 95:
			return OUTCOME_PARTIAL_SUCCESS
		return OUTCOME_FAILURE

	if risk_label == "high":
		if roll <= 35:
			return OUTCOME_SUCCESS
		if roll <= 75:
			return OUTCOME_PARTIAL_SUCCESS
		return OUTCOME_FAILURE

	# Medium/unknown falls back to balanced odds.
	if roll <= 50:
		return OUTCOME_SUCCESS
	if roll <= 85:
		return OUTCOME_PARTIAL_SUCCESS
	return OUTCOME_FAILURE


static func _build_rewards(expedition: Dictionary, outcome: String) -> Dictionary:
	var duration_minutes: int = int(max(1, int(expedition.get("duration_minutes", 1))))
	var base_gold: int = 20 + (duration_minutes * 4)

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
