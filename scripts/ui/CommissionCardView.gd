extends PanelContainer
class_name CommissionCardView

# File: CommissionCardView.gd
# Lightweight presenter for one commission offer card.
#
# Why this script exists:
# - The visual hierarchy is authored in CommissionCard.tscn so designers can
#   adjust spacing and readability in the editor.
# - This script only binds generated commission data into that authored layout.
# - The card intentionally stays compact/readable for a 3-offer curated board.

signal inspect_requested(offer_id: String)

@onready var _patron_label: Label = $CardMargin/CardColumn/PatronLabel
@onready var _family_label: Label = $CardMargin/CardColumn/FamilyLabel
@onready var _title_label: Label = $CardMargin/CardColumn/TitleLabel
@onready var _region_label: Label = $CardMargin/CardColumn/RegionLabel
@onready var _duration_label: Label = $CardMargin/CardColumn/MetaRow/DurationLabel
@onready var _risk_label: Label = $CardMargin/CardColumn/MetaRow/RiskLabel
@onready var _reward_label: Label = $CardMargin/CardColumn/RewardLabel
@onready var _requirements_label: Label = $CardMargin/CardColumn/RequirementsLabel
@onready var _note_label: Label = $CardMargin/CardColumn/NoteLabel
@onready var _inspect_button: Button = $CardMargin/CardColumn/InspectButton

var _offer_id := ""


func _ready() -> void:
	_configure_drag_passthrough()
	_inspect_button.pressed.connect(func() -> void:
		if _offer_id.is_empty():
			return
		inspect_requested.emit(_offer_id)
	)


func _configure_drag_passthrough() -> void:
	# Cards live inside a horizontal ScrollContainer on the board screen.
	# PASS/IGNORE keeps taps working while allowing swipe drags that start on
	# card content (labels/button) to continue scrolling the parent container.
	mouse_filter = Control.MOUSE_FILTER_PASS
	_set_descendant_mouse_filter(self)


func _set_descendant_mouse_filter(node: Node) -> void:
	for child in node.get_children():
		if not child is Control:
			continue
		var control := child as Control
		if control == _inspect_button:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendant_mouse_filter(control)


func set_offer_data(offer: Dictionary) -> void:
	# Data arrives from CommissionBoardScreenController, which receives board data
	# from CommissionBoardController/CommissionGenerator.
	_offer_id = str(offer.get("offer_id", "")).strip_edges()
	var patron_name := str(offer.get("patron_name", "Unknown Patron"))
	var family_name := str(offer.get("family_name", "Unknown Family"))
	var brief_text := str(offer.get("brief_text", "Untitled Commission"))
	var region_name := _resolve_region_name(offer)
	var duration_minutes := maxi(0, int(offer.get("duration_minutes", 0)))
	var risk_band := str(offer.get("risk_band", "moderate")).capitalize()
	var reward_text := _build_reward_text(offer)
	var crew_needed := maxi(0, int(offer.get("crew_required", 0)))
	var supplies_needed := maxi(0, int(offer.get("supplies_required", 0)))
	var note_text := _build_recommendation_note(offer)

	_patron_label.text = "Patron: %s" % patron_name
	_family_label.text = "Family: %s" % family_name
	_title_label.text = brief_text
	_region_label.text = "Region: %s" % region_name
	_duration_label.text = "Duration: %d min" % duration_minutes if duration_minutes > 0 else "Duration: Unknown"
	_risk_label.text = "Risk: %s" % risk_band
	_reward_label.text = "Reward: %s" % reward_text
	_requirements_label.text = "Crew Needed: %d   Supplies Needed: %d" % [crew_needed, supplies_needed]
	_note_label.text = note_text
	_note_label.visible = not note_text.is_empty()
	_inspect_button.disabled = _offer_id.is_empty()


func set_empty_state(slot_index: int) -> void:
	# Keeps the 3-card board visually finite even before all slots are populated.
	_offer_id = ""
	_patron_label.text = "Patron: --"
	_family_label.text = "Family: --"
	_title_label.text = "No commission in this slot"
	_region_label.text = "Region: --"
	_duration_label.text = "Duration: --"
	_risk_label.text = "Risk: --"
	_reward_label.text = "Reward: --"
	_requirements_label.text = "Crew Needed: --   Supplies Needed: --"
	_note_label.text = "Slot %d is currently empty." % (slot_index + 1)
	_note_label.visible = true
	_inspect_button.disabled = true


func _build_reward_text(offer: Dictionary) -> String:
	var reward := offer.get("reward_scaffold", {}) as Dictionary
	var gold := maxi(0, int(reward.get("base_gold", reward.get("estimated_gold", 0))))
	var relics := maxi(0, int(reward.get("base_relic_fragments", 0)))
	if gold <= 0 and relics <= 0:
		return "Varies"
	if relics <= 0:
		return "%d Gold" % gold
	if gold <= 0:
		return "%d Relic Fragments" % relics
	return "%d Gold + %d Relic Fragments" % [gold, relics]


func _build_recommendation_note(offer: Dictionary) -> String:
	# Optional compact note: preferred tag bias can act as a future officer/knowledge hint.
	var tags: Variant = offer.get("preferred_tags", [])
	if tags is Array and not tags.is_empty():
		return "Recommended knowledge: %s" % str(tags[0]).capitalize()
	return ""


func _resolve_region_name(offer: Dictionary) -> String:
	var metadata := offer.get("metadata", {}) as Dictionary
	var tokens := metadata.get("context_tokens", {}) as Dictionary
	var token_region := str(tokens.get("region_name", "")).strip_edges()
	if not token_region.is_empty():
		return token_region
	return str(offer.get("region_id", "Unknown Region")).capitalize()
