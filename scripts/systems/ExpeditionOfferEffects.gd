extends RefCounted
class_name ExpeditionOfferEffects

# ExpeditionOfferEffects builds a UI-facing projection of an expedition offer
# after guild upgrade effects are applied. The original offer remains untouched
# so dispatch/runtime systems can keep using canonical values.

const MIN_MULTIPLIER := 0.20


static func build_preview(expedition_offer: Dictionary, upgrade_effects: Dictionary) -> Dictionary:
	var preview := expedition_offer.duplicate(true)

	_apply_duration_preview(preview, upgrade_effects)
	_apply_risk_preview(preview, upgrade_effects)
	return preview


static func _apply_duration_preview(preview: Dictionary, upgrade_effects: Dictionary) -> void:
	var base_duration := int(preview.get("duration_minutes", 0))
	if base_duration <= 0:
		return

	var duration_multiplier := maxf(MIN_MULTIPLIER, float(upgrade_effects.get("duration_multiplier", 1.0)))
	var adjusted_duration := int(round(base_duration * duration_multiplier))
	preview["duration_minutes"] = max(1, adjusted_duration)


static func _apply_risk_preview(preview: Dictionary, upgrade_effects: Dictionary) -> void:
	var base_success := clampf(float(preview.get("base_success", 0.75)), 0.05, 0.99)
	var success_bonus := float(upgrade_effects.get("success_bonus", 0.0))
	var effective_success := clampf(base_success + success_bonus, 0.05, 0.99)

	preview["base_success"] = effective_success
	preview["risk_label"] = _risk_label_from_success(effective_success)


static func _risk_label_from_success(success_chance: float) -> String:
	# Thresholds are chosen around the current content anchors:
	# low=0.85, medium=0.75, high=0.65.
	if success_chance >= 0.80:
		return "Low"
	if success_chance >= 0.70:
		return "Medium"
	return "High"
