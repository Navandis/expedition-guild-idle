extends PanelContainer
class_name CommissionDetailPanelController

# File: CommissionDetailPanelController.gd
# Commission confirmation panel shown before dispatching a board offer.
#
# Temporary readability pass notes:
# - The old TitleLabel and DispatchHintLabel were removed from the scene because
#   the panel is now opened from clear card buttons and no longer needs extra
#   duplicate instruction text.
# - Dispatch behavior itself is unchanged: confirm still dispatches immediately.

signal closed
signal dispatch_pressed(offer: Dictionary, prep_tier_id: String, commitment: Dictionary)

@onready var _offer_name_label: Label = $DetailMargin/DetailColumn/OfferNameLabel
@onready var _region_label: Label = $DetailMargin/DetailColumn/RegionLabel
@onready var _reward_label: Label = $DetailMargin/DetailColumn/RewardLabel
@onready var _risk_label: Label = $DetailMargin/DetailColumn/RiskLabel
@onready var _suitability_label: Label = $DetailMargin/DetailColumn/SuitabilityLabel
@onready var _operational_label: Label = $DetailMargin/DetailColumn/OperationalInputsLabel
@onready var _status_label: Label = $DetailMargin/DetailColumn/StatusLabel
@onready var _prep_selector: PrepTierSelector = $DetailMargin/DetailColumn/PrepTierSelector
@onready var _cancel_button: Button = $DetailMargin/DetailColumn/ButtonsRow/CancelButton
@onready var _dispatch_button: Button = $DetailMargin/DetailColumn/ButtonsRow/DispatchButton

var _selected_offer: Dictionary = {}
var _available_crew := 0
var _available_supplies := 0


func _ready() -> void:
	visible = false
	_cancel_button.pressed.connect(func() -> void:
		hide_panel()
		closed.emit()
	)
	_dispatch_button.pressed.connect(_on_dispatch_button_pressed)
	_prep_selector.tier_selected.connect(func(_tier_id: String) -> void:
		_refresh_view()
	)


func show_offer(offer: Dictionary, available_crew: int, available_supplies: int) -> void:
	_selected_offer = offer.duplicate(true)
	_available_crew = maxi(0, available_crew)
	_available_supplies = maxi(0, available_supplies)
	_status_label.visible = false
	_prep_selector.select_tier("prepared")
	_refresh_view()
	visible = true


func hide_panel() -> void:
	visible = false
	_selected_offer = {}
	_status_label.visible = false


func set_status_message(text: String, is_error: bool) -> void:
	_status_label.visible = true
	_status_label.modulate = Color(0.95, 0.45, 0.40) if is_error else Color(0.55, 0.9, 0.55)
	_status_label.text = text


func _on_dispatch_button_pressed() -> void:
	if _selected_offer.is_empty():
		return
	# No manual crew/supplies entry: commitment is derived from selected tier.
	var commitment := _build_commitment_for_current_tier(_selected_offer)
	dispatch_pressed.emit(_selected_offer.duplicate(true), _prep_selector.get_selected_tier_id(), commitment)


func _refresh_view() -> void:
	if _selected_offer.is_empty():
		return

	var tier := _prep_selector.get_selected_tier_data()
	var commitment := _build_commitment_for_tier(_selected_offer, tier)
	var reward_text := _build_reward_text(_selected_offer)
	var risk_text := _build_risk_text(_selected_offer, tier)
	var suitability_text := _build_suitability_text(_selected_offer)

	_offer_name_label.text = str(_selected_offer.get("brief_text", "Untitled Commission"))
	_region_label.text = "Region: %s" % _resolve_region_name(_selected_offer)
	_reward_label.text = "Reward: %s" % reward_text
	_risk_label.text = "Risk Outlook: %s" % risk_text
	_suitability_label.text = suitability_text
	_operational_label.text = "Dispatch Commitment: Crew %d / %d · Supplies %d / %d" % [
		int(commitment.get("crew_commitment", 0)),
		_available_crew,
		int(commitment.get("supplies_commitment", 0)),
		_available_supplies
	]

	var can_dispatch := bool(commitment.get("has_enough_resources", false))
	_dispatch_button.disabled = not can_dispatch
	if not can_dispatch:
		set_status_message("Not enough Crew or Supplies for this prep tier.", true)
	elif _status_label.visible and _status_label.modulate == Color(0.95, 0.45, 0.40):
		_status_label.visible = false


func _build_commitment_for_current_tier(offer: Dictionary) -> Dictionary:
	return _build_commitment_for_tier(offer, _prep_selector.get_selected_tier_data())


func _build_commitment_for_tier(offer: Dictionary, tier: Dictionary) -> Dictionary:
	var base_crew := maxi(1, int(offer.get("crew_required", 1)))
	var base_supplies := maxi(1, int(offer.get("supplies_required", 1)))
	var crew_commitment := maxi(1, int(ceil(float(base_crew) * float(tier.get("crew_multiplier", 1.0)))))
	var supplies_commitment := maxi(1, int(ceil(float(base_supplies) * float(tier.get("supplies_multiplier", 1.0)))))
	var has_enough := crew_commitment <= _available_crew and supplies_commitment <= _available_supplies
	# Outcome weighting is represented as a simple modifier for v1 readability.
	return {
		"crew_commitment": crew_commitment,
		"supplies_commitment": supplies_commitment,
		"success_weight_modifier": float(tier.get("success_weight_modifier", 0.0)),
		"has_enough_resources": has_enough
	}


func _build_reward_text(offer: Dictionary) -> String:
	var reward := offer.get("reward_scaffold", {}) as Dictionary
	var gold := maxi(0, int(reward.get("estimated_gold", reward.get("base_gold", 0))))
	if gold <= 0:
		return "Contract payout varies"
	return "%d Gold (est.)" % gold


func _build_risk_text(offer: Dictionary, tier: Dictionary) -> String:
	var base_risk := str(offer.get("risk_band", "moderate")).capitalize()
	var tier_label := str(tier.get("risk_shift", "Base Risk"))
	var outcome_pct := int(round(float(tier.get("success_weight_modifier", 0.0)) * 100.0))
	return "%s · %s · Outcome Weight %+.0f%%" % [base_risk, tier_label, float(outcome_pct)]


func _build_suitability_text(offer: Dictionary) -> String:
	# Optional recommendation remains compact so this panel stays readable.
	var tags := offer.get("preferred_tags", []) as Array
	if tags.is_empty():
		return "Suitability: No specific recommendation available yet."
	return "Suitability: Recommended knowledge - %s" % str(tags[0]).capitalize()


func _resolve_region_name(offer: Dictionary) -> String:
	var metadata := offer.get("metadata", {}) as Dictionary
	var tokens := metadata.get("context_tokens", {}) as Dictionary
	var token_region := str(tokens.get("region_name", "")).strip_edges()
	if not token_region.is_empty():
		return token_region
	return str(offer.get("region_id", "Unknown Region")).capitalize()
